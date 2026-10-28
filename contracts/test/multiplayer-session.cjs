const { expect } = require("chai");
const { chatKey, createChatLimiter, resolvePlayer } = require("../lib/multiplayer-service.cjs");

const WALLET = "0x3333333333333333333333333333333333333333";

describe("Multiplayer joins and chat", function () {
  const lookup = async (token) => (token === "good" ? { wallet: WALLET } : null);

  it("names guests Tamu-xxxx and ignores a claimed wallet", async function () {
    const player = await resolvePlayer({ wallet: WALLET, name: "Admin" }, lookup);
    expect(player.name).to.match(/^Tamu-[0-9A-F]{4}$/);
    expect(player.wallet).to.equal("");
    expect(player.verified).to.equal(false);
  });

  it("takes the wallet from a valid session, not from the payload", async function () {
    const player = await resolvePlayer({
      session: "good",
      wallet: "0x4444444444444444444444444444444444444444",
      name: "  Pak\u0000Budi  "
    }, lookup);
    expect(player.wallet).to.equal(WALLET);
    expect(player.verified).to.equal(true);
    expect(player.name).to.equal("Pak Budi");
  });

  it("treats a session lookup failure as a guest", async function () {
    const player = await resolvePlayer({ session: "good" }, async () => { throw new Error("db down"); });
    expect(player.verified).to.equal(false);
  });

  it("drops a second chat inside two seconds", function () {
    const limiter = createChatLimiter(2000);
    expect(limiter.allow("s1", 1000)).to.equal(true);
    expect(limiter.allow("s1", 1999)).to.equal(false);
    expect(limiter.allow("s2", 1999)).to.equal(true);
    expect(limiter.allow("s1", 3000)).to.equal(true);
  });

  it("rate limits chat per wallet or per visitor IP, not per socket", function () {
    expect(chatKey({ verified: true, wallet: WALLET }, { headers: {}, address: "1.1.1.1" })).to.equal(`w:${WALLET}`);
    expect(chatKey({ verified: false }, { headers: { "cf-connecting-ip": "9.9.9.9" }, address: "127.0.0.1" })).to.equal("ip:9.9.9.9");
    expect(chatKey(undefined, { headers: {}, address: "8.8.8.8" })).to.equal("ip:8.8.8.8");
  });
});
