import postgres from "postgres";

let _sql: ReturnType<typeof postgres> | null = null;

export function db() {
  if (_sql) return _sql;
  const url = process.env.DATABASE_URL;
  if (!url) throw new Error("Missing DATABASE_URL");

  _sql = postgres(url, {
    // Keep it simple; rely on Postgres defaults.
    max: 10
  });
  return _sql;
}

