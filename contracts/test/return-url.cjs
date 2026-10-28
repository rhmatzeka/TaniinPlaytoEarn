const { expect } = require("chai");
const { buildReturnUrl, safeReturnUrl } = require("../masuk/return-url.cjs");

describe("Login page return URL", function () {
  it("allows the Android deep link", function () {
    expect(safeReturnUrl("taniin://auth")).to.equal("taniin://auth");
  });

  it("allows same-origin game paths", function () {
    expect(safeReturnUrl("/main/")).to.equal("/main/");
    expect(safeReturnUrl("/main/?x=1")).to.equal("/main/?x=1");
  });

  it("falls back to the game for anything else", function () {
    for (const value of ["https://jahat.example/main/", "//jahat.example", "/main/../../x", "javascript:alert(1)", "", null]) {
      expect(safeReturnUrl(value), String(value)).to.equal("/main/");
    }
  });

  it("puts the result in the fragment, never the query", function () {
    const url = buildReturnUrl("/main/?x=1", { session: "ab", wallet: "0x1" });
    expect(url).to.equal("/main/?x=1#session=ab&wallet=0x1");
  });
});
