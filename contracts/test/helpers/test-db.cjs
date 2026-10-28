const { PGlite } = require("@electric-sql/pglite");
const { ensureSchema, wrapClient } = require("../../lib/db.cjs");

async function createTestDb() {
  const pg = new PGlite();
  const db = wrapClient(pg);
  await ensureSchema(db);
  return db;
}

module.exports = { createTestDb };
