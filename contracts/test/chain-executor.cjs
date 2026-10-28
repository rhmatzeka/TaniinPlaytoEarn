const { expect } = require("chai");
const { executeChainOps, setGameServiceForTests } = require("../lib/game-action-service.cjs");

const PLAYER = "0x6666666666666666666666666666666666666666";
const SIGNER = "0x7777777777777777777777777777777777777777";

function fakeService(receiptFor) {
  let n = 0;
  const tx = () => ({ hash: `0x${String(++n).padStart(64, "0")}` });
  return {
    wallet: { address: SIGNER },
    signer: { reset() {}, sendTransaction: async () => tx() },
    provider: {
      waitForTransaction: async (hash) => receiptFor(hash),
      getBalance: async () => 10n ** 19n
    },
    contracts: {
      coin: { balanceOf: async () => 0n, mint: async () => tx(), gameSpend: async () => tx() },
      land: {
        playerPlotLandId: async () => 0n,
        planted: async () => false,
        mintLandFor: async () => tx(),
        sellLandFor: async () => tx(),
        plantFor: async () => tx(),
        harvestFor: async () => tx()
      },
      items: { balanceOf: async () => 0n, mint: async () => tx(), burn: async () => tx() }
    },
    addresses: {}
  };
}

describe("Chain executor confirmations", function () {
  afterEach(() => setGameServiceForTests(null));

  it("fails the action when a sent transaction reverts", async function () {
    setGameServiceForTests(fakeService(() => ({ status: 0 })));
    let caught;
    try {
      await executeChainOps(PLAYER, [{ kind: "mintTani", amount: 10 }]);
    } catch (error) {
      caught = error;
    }
    expect(caught?.statusCode).to.equal(409);
  });

  it("treats a slow confirmation as sent, not failed", async function () {
    setGameServiceForTests(fakeService(() => null));
    const result = await executeChainOps(PLAYER, [{ kind: "mintTani", amount: 10 }]);
    expect(result.txHash).to.match(/^0x0+1$/);
  });

  it("returns every hash when all transactions succeed", async function () {
    setGameServiceForTests(fakeService(() => ({ status: 1 })));
    const result = await executeChainOps(PLAYER, [{ kind: "plant", plotId: 1 }, { kind: "mintCrop", amount: 3 }]);
    expect(result.txHashes).to.have.length(2);
  });
});
