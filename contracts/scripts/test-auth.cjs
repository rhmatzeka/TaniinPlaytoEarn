const { ethers } = require("ethers");

process.env.TANIIN_REQUIRE_AUTH = "true";

const {
  createNonce,
  requireSession,
  verifySignature,
  withIdempotency
} = require("../lib/auth-service.cjs");

async function main() {
  const wallet = ethers.Wallet.createRandom();
  const nonce = createNonce(wallet.address, "test");
  assert(nonce.ok, "nonce should be created");
  assert(nonce.message.includes(wallet.address), "message should include wallet");

  const signature = await wallet.signMessage(nonce.message);
  const verified = verifySignature({
    wallet: wallet.address,
    nonce: nonce.nonce,
    signature
  }, "test");
  assert(verified.ok && verified.verified, "signature should verify");
  assert(verified.session, "session should be returned");

  const req = {
    headers: {
      authorization: `Bearer ${verified.session}`,
      "idempotency-key": "auth-test-1"
    }
  };
  const session = requireSession(req, wallet.address);
  assert(session.verified, "session should be verified");

  let runs = 0;
  const first = await withIdempotency(req, wallet.address, async () => {
    runs += 1;
    return { ok: true, value: runs };
  });
  const second = await withIdempotency(req, wallet.address, async () => {
    runs += 1;
    return { ok: true, value: runs };
  });
  assert(first.value === 1, "first action should run");
  assert(second.value === 1 && second.idempotentReplay === true, "second action should replay cached result");
  assert(runs === 1, "idempotent action should only run once");
}

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

main()
  .then(() => console.log("auth-service ok"))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
