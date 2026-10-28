import React, { useCallback, useEffect, useRef, useState } from "react";
import { createRoot } from "react-dom/client";
import { PrivyProvider, usePrivy, useSendTransaction } from "@privy-io/react-auth";
import { sepolia } from "viem/chains";
import { buildReturnUrl, safeReturnUrl } from "./return-url.cjs";

const APP_ID = process.env.PRIVY_APP_ID;
const params = new URLSearchParams(window.location.search);
const returnUrl = safeReturnUrl(params.get("return"));
const mode = params.get("aksi") === "isi-eth" ? "isi-eth" : "masuk";
const coinAmount = Number.parseInt(params.get("jumlah") || "0", 10);
// The Android app sends a PKCE challenge; it then receives a one-time code, not a session.
const codeChallenge = /^[A-Za-z0-9_-]{43}$/.test(params.get("challenge") || "") ? params.get("challenge") : undefined;
const WALLET_WAIT_MS = 15_000;

function Card({ children }) {
  return (
    <main className="card">
      <a className="brand" href="/">
        <img src="/img/logo.webp" width="56" height="56" alt="" />
        <span>Taniin</span>
      </a>
      {children}
    </main>
  );
}

function Status({ text, tone = "info" }) {
  return <p className={`status status-${tone}`} role={tone === "error" ? "alert" : "status"}>{text}</p>;
}

async function postJson(path, body) {
  const response = await fetch(path, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body)
  });
  const json = await response.json().catch(() => ({}));
  if (!response.ok || json.ok === false) throw new Error(json.error || `Server menjawab ${response.status}.`);
  return json;
}

function goBack(values) {
  window.location.replace(buildReturnUrl(returnUrl, values));
}

function LoginFlow() {
  const { ready, authenticated, login, logout, getAccessToken, user } = usePrivy();
  const [status, setStatus] = useState({ text: "", tone: "info" });
  const exchanging = useRef(false);
  const latestUser = useRef(user);
  latestUser.current = user;

  useEffect(() => {
    if (!ready || !authenticated || exchanging.current) return;
    exchanging.current = true;
    (async () => {
      setStatus({ text: "Menyiapkan wallet kamu...", tone: "info" });
      const started = Date.now();
      // The embedded wallet is created right after the first login; give it a moment.
      while (!latestUser.current?.wallet?.address && Date.now() - started < WALLET_WAIT_MS) {
        await new Promise((resolve) => setTimeout(resolve, 500));
      }
      const accessToken = await getAccessToken();
      const result = await postJson("/auth/privy", { accessToken, codeChallenge });
      setStatus({ text: "Berhasil! Kembali ke game...", tone: "ok" });
      if (result.code) {
        goBack({ code: result.code });
        return;
      }
      goBack({
        session: result.session,
        wallet: result.wallet,
        expires: result.expiresAt,
        method: result.loginMethod
      });
    })().catch((error) => {
      exchanging.current = false;
      setStatus({ text: error.message || "Gagal masuk. Coba lagi.", tone: "error" });
    });
  }, [ready, authenticated, getAccessToken]);

  return (
    <Card>
      <h1>Masuk ke Taniin</h1>
      <p className="lead">
        Masuk pakai email, Google, atau wallet. Wallet Sepolia dibuat otomatis kalau kamu belum punya,
        jadi panen dan penjualanmu tercatat on-chain.
      </p>
      {!authenticated && (
        <button className="btn" type="button" disabled={!ready} onClick={login}>
          {ready ? "Masuk" : "Memuat..."}
        </button>
      )}
      {authenticated && (
        <button className="btn btn-ghost" type="button" onClick={() => { exchanging.current = false; logout(); }}>
          Ganti akun
        </button>
      )}
      {status.text && <Status {...status} />}
      <a className="back" href={returnUrl.startsWith("/") ? returnUrl : "/main/"}>Main sebagai tamu</a>
    </Card>
  );
}

function FundFlow() {
  const { ready, authenticated, login } = usePrivy();
  const { sendTransaction } = useSendTransaction();
  const [status, setStatus] = useState({ text: "", tone: "info" });
  const [busy, setBusy] = useState(false);
  const validAmount = Number.isSafeInteger(coinAmount) && coinAmount >= 100 && coinAmount <= 10_000;

  const pay = useCallback(async () => {
    setBusy(true);
    try {
      const health = await fetch("/health").then((response) => response.json());
      if (!health.signer || !health.ethWeiPerCoin) throw new Error("Server Sepolia belum siap. Coba lagi nanti.");
      const value = BigInt(health.ethWeiPerCoin) * BigInt(coinAmount);
      setStatus({ text: "Konfirmasi transfer di jendela Privy...", tone: "info" });
      const { hash } = await sendTransaction({ to: health.signer, value, chainId: sepolia.id });
      setStatus({ text: "Terkirim! Kembali ke game...", tone: "ok" });
      goBack({ fundTx: hash, jumlah: String(coinAmount) });
    } catch (error) {
      setStatus({ text: error.message || "Transfer dibatalkan.", tone: "error" });
      setBusy(false);
    }
  }, [sendTransaction]);

  return (
    <Card>
      <h1>Isi Game Coin dari ETH</h1>
      {validAmount
        ? <p className="lead">Kirim Sepolia ETH dari wallet kamu untuk mendapat <strong>{coinAmount} Game Coin</strong>.</p>
        : <Status text="Jumlah coin harus 100 sampai 10.000." tone="error" />}
      {!authenticated
        ? <button className="btn" type="button" disabled={!ready} onClick={login}>Masuk dulu</button>
        : <button className="btn" type="button" disabled={!validAmount || busy} onClick={pay}>Kirim ETH</button>}
      {status.text && <Status {...status} />}
      <a className="back" href={returnUrl.startsWith("/") ? returnUrl : "/main/"}>Batal</a>
    </Card>
  );
}

function App() {
  if (!APP_ID) {
    return (
      <Card>
        <h1>Login belum tersedia</h1>
        <Status text="Login Privy belum dikonfigurasi. Kamu tetap bisa main sebagai tamu." tone="error" />
        <a className="btn" href="/main/">Main sebagai tamu</a>
      </Card>
    );
  }
  return (
    <PrivyProvider
      appId={APP_ID}
      config={{
        loginMethods: ["email", "google", "wallet"],
        appearance: { theme: "light", accentColor: "#2F7D45", logo: "/img/logo.webp" },
        embeddedWallets: { ethereum: { createOnLogin: "users-without-wallets" } },
        defaultChain: sepolia,
        supportedChains: [sepolia]
      }}
    >
      {mode === "isi-eth" ? <FundFlow /> : <LoginFlow />}
    </PrivyProvider>
  );
}

createRoot(document.getElementById("root")).render(<App />);
