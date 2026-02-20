import { readFile } from "node:fs/promises";
import { db } from "./db";

async function main() {
  const sql = db();
  const path = new URL("../migrations/001_init.sql", import.meta.url);
  const migration = await readFile(path, "utf8");
  await sql.unsafe(migration);
  await sql.end();
  // Minimal output for scripts.
  console.log("migrated");
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});

