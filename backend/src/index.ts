import { db } from "./db";
import { displayNameForUser, requireSupabaseUser } from "./auth";
import { generateCourseFromChat, type ChatMessage } from "./ai";

// This project runs on Bun; we keep types local to avoid requiring extra @types deps.
declare const Bun: any;
declare const process: { env: Record<string, string | undefined> };

type DbUser = { id: string; name: string };
type DbCourse = { id: string; ownerId: string; name: string };
type DbModule = {
  id: string;
  courseId: string;
  type: "info" | "test";
  content: unknown;
};

function normalizeModuleContent(m: DbModule): DbModule {
  // Bun + postgres-js can surface jsonb columns as strings. The mobile app expects an object.
  if (typeof m.content !== "string") return m;
  try {
    return { ...m, content: JSON.parse(m.content) };
  } catch {
    return m;
  }
}

function corsHeaders() {
  return {
    "access-control-allow-origin": "*",
    "access-control-allow-methods": "GET,POST,OPTIONS",
    "access-control-allow-headers": "authorization,content-type,apikey",
  };
}

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "content-type": "application/json", ...corsHeaders() },
  });
}

function isUuid(value: string) {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(
    value,
  );
}

async function requireJson<T>(req: Request): Promise<T> {
  try {
    return (await req.json()) as T;
  } catch {
    throw json({ error: "invalid_json" }, 400);
  }
}

async function upsertUser(userId: string, name: string): Promise<DbUser> {
  const sql = db();
  const rows = await sql<DbUser[]>`
    insert into users (id, name)
    values (${userId}::uuid, ${name})
    on conflict (id) do update set name = excluded.name
    returning id, name
  `;
  return rows[0]!;
}

async function requireCourseOwner(
  courseId: string,
  userId: string,
): Promise<void> {
  const sql = db();
  const rows = await sql<{ owner_id: string }[]>`
    select owner_id from courses where id = ${courseId}::uuid
  `;
  if (rows.length === 0) throw json({ error: "course_not_found" }, 404);
  if (rows[0]!.owner_id !== userId) throw json({ error: "forbidden" }, 403);
}

async function requireCourseAccess(
  courseId: string,
  userId: string,
): Promise<void> {
  const sql = db();
  const courseRows = await sql<{ owner_id: string }[]>`
    select owner_id from courses where id = ${courseId}::uuid
  `;
  if (courseRows.length === 0) throw json({ error: "course_not_found" }, 404);
  if (courseRows[0]!.owner_id === userId) return;

  const learnerRows = await sql<{ ok: number }[]>`
    select 1 as ok
    from learners
    where course_id = ${courseId}::uuid and user_id = ${userId}::uuid
    limit 1
  `;
  if (learnerRows.length === 0) throw json({ error: "forbidden" }, 403);
}

Bun.serve({
  port: Number(process.env.PORT ?? 3000),
  fetch: async (req: Request) => {
    if (req.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: corsHeaders() });
    }

    try {
      const url = new URL(req.url);
      const path = url.pathname;
      const method = req.method.toUpperCase();

      // All routes require real Supabase auth.
      const sbUser = await requireSupabaseUser(req);
      const me = await upsertUser(sbUser.id, displayNameForUser(sbUser));

      if (method === "GET" && path === "/me") {
        return json(me);
      }

      if (method === "GET" && path === "/users") {
        const sql = db();
        const rows = await sql<
          DbUser[]
        >`select id, name from users order by name`;
        return json(rows);
      }

      if (method === "POST" && path === "/courses/generate") {
        const body = await requireJson<{ messages?: ChatMessage[] }>(req);
        const messages = Array.isArray(body.messages) ? body.messages : [];
        const generated = await generateCourseFromChat(messages);

        const sql = db();
        const result = await sql.begin(async (tx) => {
          const courseId = crypto.randomUUID();
          const courseRows = await tx<
            { id: string; ownerId: string; name: string }[]
          >`
            insert into courses (id, owner_id, name)
            values (${courseId}::uuid, ${me.id}::uuid, ${generated.courseName})
            returning id, owner_id as "ownerId", name
          `;

          const modulesOut: DbModule[] = [];
          for (const m of generated.modules) {
            const moduleId = crypto.randomUUID();
            const moduleRows = await tx<DbModule[]>`
              insert into modules (id, course_id, type, content)
              values (
                ${moduleId}::uuid,
                ${courseId}::uuid,
                ${m.type},
                ${JSON.stringify(m.content)}::jsonb
              )
              returning id, course_id as "courseId", type, content
            `;
            modulesOut.push(normalizeModuleContent(moduleRows[0]!));
          }

          return { course: courseRows[0] as DbCourse, modules: modulesOut };
        });

        return json(result, 201);
      }

      if (method === "GET" && path === "/courses/owned") {
        const sql = db();
        const rows = await sql<DbCourse[]>`
          select id, owner_id as "ownerId", name
          from courses
          where owner_id = ${me.id}::uuid
          order by name
        `;
        return json(rows);
      }

      if (method === "GET" && path === "/courses/enrolled") {
        const sql = db();
        const rows = await sql<DbCourse[]>`
          select c.id, c.owner_id as "ownerId", c.name
          from courses c
          join learners l on l.course_id = c.id
          where l.user_id = ${me.id}::uuid
          order by c.name
        `;
        return json(rows);
      }

      {
        const addLearnerMatch = path.match(/^\/courses\/([^/]+)\/learners$/);
        if (method === "POST" && addLearnerMatch) {
          const courseId = addLearnerMatch[1]!;
          if (!isUuid(courseId))
            return json({ error: "invalid_course_id" }, 400);
          await requireCourseOwner(courseId, me.id);

          const body = await requireJson<{ userId?: string }>(req);
          if (
            !body.userId ||
            typeof body.userId !== "string" ||
            !isUuid(body.userId)
          ) {
            return json({ error: "invalid_user_id" }, 400);
          }

          const sql = db();
          await sql`
            insert into learners (user_id, course_id)
            values (${body.userId}::uuid, ${courseId}::uuid)
            on conflict (user_id, course_id) do nothing
          `;
          return json({ ok: true }, 201);
        }
      }

      {
        const modulesMatch = path.match(/^\/courses\/([^/]+)\/modules$/);
        if (method === "GET" && modulesMatch) {
          const courseId = modulesMatch[1]!;
          if (!isUuid(courseId))
            return json({ error: "invalid_course_id" }, 400);
          await requireCourseAccess(courseId, me.id);

          const sql = db();
          const rows = await sql<DbModule[]>`
            select id, course_id as "courseId", type, content
            from modules
            where course_id = ${courseId}::uuid
            order by id
          `;
          return json(rows.map(normalizeModuleContent));
        }
      }

      return json({ error: "not_found" }, 404);
    } catch (err) {
      if (err instanceof Response) {
        // Ensure CORS headers are present.
        const body = await err.text();
        const headers: Record<string, string> = { ...corsHeaders() };
        // Preserve existing content-type when present (otherwise default to JSON).
        headers["content-type"] =
          err.headers.get("content-type") ?? "application/json";
        return new Response(body, { status: err.status, headers });
      }
      return json({ error: "internal_error" }, 500);
    }
  },
});
