const fs = require("fs");
const path = require("path");

const SCHEMA_SQL = fs.readFileSync(path.join(__dirname, "..", "db", "schema.sql"), "utf8");

let sharedDb;
let schemaReady;

// Wraps a pg.Pool or a PGlite instance in the small interface the services use.
function wrapClient(client) {
  const isPool = typeof client.connect === "function" && typeof client.transaction !== "function";
  const db = {
    query: (sql, params = []) => client.query(sql, params),
    async transaction(run) {
      if (!isPool) {
        return client.transaction((tx) => run(wrapTransaction(tx)));
      }
      const connection = await client.connect();
      try {
        await connection.query("BEGIN");
        const result = await run(wrapTransaction(connection));
        await connection.query("COMMIT");
        return result;
      } catch (error) {
        await connection.query("ROLLBACK").catch(() => undefined);
        throw error;
      } finally {
        connection.release();
      }
    },
    exec: (sql) => (typeof client.exec === "function" ? client.exec(sql) : client.query(sql))
  };
  return db;
}

function wrapTransaction(tx) {
  return {
    query: (sql, params = []) => tx.query(sql, params),
    transaction: (run) => run(wrapTransaction(tx))
  };
}

async function ensureSchema(db) {
  await db.exec(SCHEMA_SQL);
}

function getDb() {
  if (sharedDb) return sharedDb;
  // Neon hands out sslmode=require; pg treats it as verify-full anyway, so say so.
  const connectionString = String(process.env.DATABASE_URL || "").trim()
    .replace(/sslmode=(require|prefer|verify-ca)/, "sslmode=verify-full");
  if (!connectionString) {
    const error = new Error("DATABASE_URL belum diset.");
    error.statusCode = 503;
    throw error;
  }
  const { Pool } = require("pg");
  // Reused across warm serverless invocations; small pool keeps Neon connections low.
  sharedDb = wrapClient(new Pool({
    connectionString,
    max: 3,
    idleTimeoutMillis: 10_000,
    ssl: connectionString.includes("localhost") ? false : { rejectUnauthorized: true }
  }));
  return sharedDb;
}

async function getReadyDb() {
  const db = getDb();
  if (!schemaReady) {
    schemaReady = ensureSchema(db).catch((error) => {
      schemaReady = undefined;
      throw error;
    });
  }
  await schemaReady;
  return db;
}

function setDbForTests(db) {
  sharedDb = db;
  schemaReady = db ? Promise.resolve() : undefined;
}

module.exports = {
  ensureSchema,
  getDb,
  getReadyDb,
  setDbForTests,
  wrapClient
};
