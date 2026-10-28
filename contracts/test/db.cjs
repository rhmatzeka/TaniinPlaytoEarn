const { expect } = require("chai");
const { ensureSchema } = require("../lib/db.cjs");
const { createTestDb } = require("./helpers/test-db.cjs");

describe("Postgres storage layer", function () {
  it("applies the schema idempotently", async function () {
    const db = await createTestDb();
    await ensureSchema(db);
    const { rows } = await db.query("SELECT count(*)::int AS n FROM players");
    expect(rows[0].n).to.equal(0);
  });

  it("rolls back a failed transaction", async function () {
    const db = await createTestDb();
    let caught;
    try {
      await db.transaction(async (tx) => {
        await tx.query("INSERT INTO players (wallet, state) VALUES ($1, $2)", ["0xabc", {}]);
        throw new Error("boom");
      });
    } catch (error) {
      caught = error;
    }
    expect(caught.message).to.equal("boom");
    const { rows } = await db.query("SELECT count(*)::int AS n FROM players");
    expect(rows[0].n).to.equal(0);
  });
});
