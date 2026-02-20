export type SupabaseUser = {
  id: string;
  email?: string | null;
  user_metadata?: Record<string, unknown> | null;
};

function getBearerToken(req: Request): string | null {
  const auth = req.headers.get("authorization");
  if (!auth) return null;
  const m = auth.match(/^Bearer\s+(.+)$/i);
  return m ? m[1] : null;
}

export async function requireSupabaseUser(req: Request): Promise<SupabaseUser> {
  const token = getBearerToken(req);
  if (!token) throw new Response(JSON.stringify({ error: "missing_bearer_token" }), { status: 401 });

  const supabaseUrl = process.env.SUPABASE_URL;
  const supabaseAnonKey = process.env.SUPABASE_ANON_KEY;
  if (!supabaseUrl) throw new Error("Missing SUPABASE_URL");
  if (!supabaseAnonKey) throw new Error("Missing SUPABASE_ANON_KEY");

  const res = await fetch(`${supabaseUrl.replace(/\/+$/, "")}/auth/v1/user`, {
    method: "GET",
    headers: {
      apikey: supabaseAnonKey,
      authorization: `Bearer ${token}`
    }
  });

  if (!res.ok) {
    // Avoid leaking details.
    throw new Response(JSON.stringify({ error: "invalid_token" }), { status: 401 });
  }

  const data = (await res.json()) as unknown;
  if (!data || typeof data !== "object") {
    throw new Response(JSON.stringify({ error: "invalid_supabase_response" }), { status: 401 });
  }

  const user = data as SupabaseUser;
  if (!user.id || typeof user.id !== "string") {
    throw new Response(JSON.stringify({ error: "invalid_supabase_user" }), { status: 401 });
  }
  return user;
}

export function displayNameForUser(user: SupabaseUser): string {
  const md = user.user_metadata ?? {};
  const nameRaw = (md as any).name;
  if (typeof nameRaw === "string" && nameRaw.trim()) return nameRaw.trim();
  if (typeof user.email === "string" && user.email.trim()) return user.email.trim();
  return "User";
}

