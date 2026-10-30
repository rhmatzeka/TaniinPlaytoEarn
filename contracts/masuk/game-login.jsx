// Privy login inside the game page (/main/), loaded on demand by the small
// loader in taniin_flutter/web/index.html. The Privy modal opens over the
// game; once signed in, the Privy token is exchanged for a Taniin session
// and handed to the game as the same fragment the /masuk page redirects
// with, through a `taniin-auth` window event (also kept on
// window.__taniinAuth in case the game is still loading).
import React, { useCallback, useEffect, useRef, useState } from "react";
import { createRoot } from "react-dom/client";
import { PrivyProvider, useLogin, usePrivy } from "@privy-io/react-auth";
import { sepolia } from "viem/chains";

const APP_ID = process.env.PRIVY_APP_ID;
// The game's login nonce, kept across the Google redirect.
const STATE_KEY = "taniin.inGameLoginState";
const WALLET_WAIT_MS = 15_000;

let root = null;
let request = 0;

function deliver(type, detail) {
  if (type === "taniin-auth") window.__taniinAuth = detail;
  window.dispatchEvent(new CustomEvent(type, { detail }));
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

function Toast({ text, tone }) {
  if (!text) return null;
  return (
    <div className={`taniin-login-toast taniin-login-${tone}`} role={tone === "error" ? "alert" : "status"}>
      {text}
    </div>
  );
}

function Bridge({ request }) {
  const { ready, authenticated, getAccessToken, user } = usePrivy();
  const [status, setStatus] = useState({ text: "", tone: "info" });
  const exchanging = useRef(false);
  const latestUser = useRef(user);
  latestUser.current = user;

  const exchange = useCallback(async () => {
    if (exchanging.current) return;
    const state = sessionStorage.getItem(STATE_KEY);
    if (state === null) return;
    exchanging.current = true;
    try {
      setStatus({ text: "Menyiapkan wallet kamu...", tone: "info" });
      const started = Date.now();
      // The embedded wallet is created right after the first login.
      while (!latestUser.current?.wallet?.address && Date.now() - started < WALLET_WAIT_MS) {
        await new Promise((resolve) => setTimeout(resolve, 500));
      }
      const accessToken = await getAccessToken();
      const result = await postJson("/auth/privy", { accessToken });
      sessionStorage.removeItem(STATE_KEY);
      deliver(
        "taniin-auth",
        new URLSearchParams({
          session: result.session,
          wallet: result.wallet,
          expires: result.expiresAt,
          method: result.loginMethod,
          state
        }).toString()
      );
      setStatus({ text: "Berhasil masuk!", tone: "ok" });
      setTimeout(() => setStatus({ text: "", tone: "info" }), 2000);
    } catch (error) {
      setStatus({ text: error.message || "Gagal masuk. Coba lagi.", tone: "error" });
      setTimeout(() => setStatus({ text: "", tone: "info" }), 5000);
      deliver("taniin-auth-cancel", "error");
    } finally {
      exchanging.current = false;
    }
  }, [getAccessToken]);

  const { login } = useLogin({
    onComplete: () => exchange(),
    onError: (error) => {
      // Closing the modal ends here too.
      if (!exchanging.current) {
        sessionStorage.removeItem(STATE_KEY);
        deliver("taniin-auth-cancel", String(error || "exited"));
      }
    }
  });

  // A press on "Masuk" in the game.
  useEffect(() => {
    if (!ready || !request) return;
    if (authenticated) {
      exchange();
    } else {
      login();
    }
  }, [ready, request]);

  // Back from the Google redirect: Privy finishes signing in by itself.
  useEffect(() => {
    if (ready && authenticated && !request) exchange();
  }, [ready, authenticated]);

  return <Toast {...status} />;
}

function App({ request }) {
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
      <Bridge request={request} />
    </PrivyProvider>
  );
}

function mount() {
  if (root) return;
  const host = document.createElement("div");
  host.id = "taniin-login";
  document.body.appendChild(host);
  const style = document.createElement("style");
  style.textContent = `
    #taniin-login { position: fixed; inset: 0; pointer-events: none; z-index: 2147483000; }
    .taniin-login-toast {
      position: absolute; left: 50%; top: 16px; transform: translateX(-50%);
      pointer-events: auto; padding: 10px 18px; border: 3px solid #3b1d10;
      background: #f6e2b3; color: #3b1d10; font: 600 16px/1.3 "Pixelify Sans", system-ui, sans-serif;
      box-shadow: 0 4px 0 #3b1d10; border-radius: 6px;
    }
    .taniin-login-ok { background: #cdeeb4; }
    .taniin-login-error { background: #f6c2b3; }
  `;
  document.head.appendChild(style);
  root = createRoot(host);
}

function render() {
  root.render(<App request={request} />);
}

/// Opens the Privy modal for a login the game started with [state] as nonce.
export function open(state) {
  if (!APP_ID) {
    deliver("taniin-login-failed", "no-app-id");
    return;
  }
  sessionStorage.setItem(STATE_KEY, String(state || ""));
  mount();
  request += 1;
  render();
}

/// Finishes a login that left the page for Google and came back.
export function resume() {
  if (!APP_ID || sessionStorage.getItem(STATE_KEY) === null) return;
  mount();
  render();
}
