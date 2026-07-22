function html() {
  return `<!doctype html>
<html lang="id">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
  <title>Taniin Wallet Connect</title>
  <style>
    :root { color-scheme: dark; }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      min-height: 100vh;
      padding: max(18px, env(safe-area-inset-top)) max(18px, env(safe-area-inset-right)) max(18px, env(safe-area-inset-bottom)) max(18px, env(safe-area-inset-left));
      display: flex;
      align-items: center;
      justify-content: center;
      background:
        linear-gradient(180deg, rgba(16, 50, 26, 0.96), rgba(12, 34, 22, 0.98)),
        #17351f;
      color: #fff0cf;
      font-family: Inter, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    }
    main {
      width: min(100%, 520px);
      border: 5px solid #633010;
      border-radius: 8px;
      background: #a34a1c;
      box-shadow: 0 8px 0 rgba(0, 0, 0, 0.36), 0 22px 46px rgba(0, 0, 0, 0.35);
      overflow: hidden;
    }
    header {
      min-height: 90px;
      padding: 18px 22px;
      display: flex;
      align-items: center;
      gap: 14px;
      border-bottom: 5px solid #763513;
      background: #a94f1e;
    }
    .dot {
      width: 9px;
      height: 9px;
      border-radius: 3px;
      background: #ffde19;
      box-shadow: 0 0 0 1px rgba(76, 35, 11, 0.35);
    }
    .badge {
      flex: 0 0 auto;
      display: flex;
      align-items: center;
      justify-content: center;
      width: 42px;
      height: 42px;
      border: 3px solid #4c230b;
      border-radius: 7px;
      background: #ffd51c;
      color: #3a2614;
      font-weight: 800;
    }
    h1 { margin: 0; font-size: clamp(26px, 7vw, 36px); line-height: 1.05; color: #ffde19; }
    .content { padding: 24px; }
    .frame {
      padding: 20px;
      border: 5px solid #e07b20;
      border-radius: 12px;
      background: #7a2d0e;
    }
    p { margin: 0 0 18px; color: #fff0cf; line-height: 1.45; font-weight: 700; }
    .hint {
      margin: 0 0 16px;
      padding: 12px 14px;
      border: 3px solid #5c2a0c;
      border-radius: 8px;
      background: #8e411b;
      color: #ffe7a8;
      font-size: 14px;
      font-weight: 800;
    }
    body[data-wallet="inside"] .hint {
      background: #285a3d;
      color: #c8f7cf;
    }
    button, a.button {
      width: 100%;
      min-height: 58px;
      border: 3px solid #ffb23f;
      border-radius: 8px;
      background: #2c8356;
      color: #fff0d4;
      font: inherit;
      font-weight: 800;
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: center;
      text-decoration: none;
      margin-top: 12px;
    }
    button:active, a.button:active { transform: translateY(2px); }
    a.button { background: #b85b1e; }
    #wallets { display: grid; gap: 10px; }
    .wallet-choice { justify-content: flex-start; padding: 0 18px; gap: 12px; }
    .wallet-choice img { width: 30px; height: 30px; border-radius: 7px; }
    #status { min-height: 24px; margin-top: 16px; color: #a9edae; font-weight: 800; line-height: 1.35; }
    .network {
      margin-top: 16px;
      display: flex;
      align-items: center;
      gap: 10px;
      color: #e9c692;
      font-size: 13px;
      font-weight: 800;
    }
    .network::before {
      content: "";
      width: 10px;
      height: 10px;
      border-radius: 3px;
      background: #69e081;
    }
    code { color: #ffd86b; word-break: break-all; }
    @media (max-width: 420px) {
      .content { padding: 18px 14px 16px; }
      .frame { padding: 16px; }
      header { padding: 16px 18px; }
      button, a.button { min-height: 56px; }
    }
  </style>
</head>
<body>
  <main>
    <header>
      <span class="dot"></span>
      <div class="badge">W</div>
      <h1>Connect Taniin Wallet</h1>
    </header>
    <section class="content">
      <div class="frame">
        <p>Pilih wallet yang ingin digunakan. Taniin tidak meminta seed phrase atau private key.</p>
        <div id="hint" class="hint"></div>
        <div id="wallets"></div>
        <div id="status"></div>
        <div class="network">Sepolia network</div>
      </div>
    </section>
  </main>
  <script>
    const statusEl = document.getElementById('status');
    const hintEl = document.getElementById('hint');
    const walletsEl = document.getElementById('wallets');
    const requestedCallback = new URLSearchParams(location.search).get('return') || 'taniin://wallet';
    const callback = safeCallback(requestedCallback);

    function safeCallback(value) {
      try {
        const uri = new URL(value, location.origin);
        if (uri.protocol === 'taniin:' && uri.host === 'wallet') return uri.toString();
        if (uri.protocol === 'https:' && uri.origin === location.origin) return uri.toString();
      } catch (_) {}
      return 'taniin://wallet';
    }

    function setStatus(message, bad) {
      statusEl.style.color = bad ? '#ffb199' : '#a9edae';
      statusEl.textContent = message;
    }

    const providers = new Map();

    function addProvider(info, provider) {
      if (!provider || typeof provider.request !== 'function') return;
      const key = info && info.uuid ? info.uuid : (info && info.rdns ? info.rdns : 'legacy');
      if (providers.has(key)) return;
      providers.set(key, { info: info || { name: 'Browser Wallet', icon: '' }, provider });
      renderProviders();
    }

    function renderProviders() {
      walletsEl.replaceChildren();
      for (const entry of providers.values()) {
        const button = document.createElement('button');
        button.className = 'wallet-choice';
        if (entry.info.icon && entry.info.icon.startsWith('data:image/')) {
          const icon = document.createElement('img');
          icon.src = entry.info.icon;
          icon.alt = '';
          button.appendChild(icon);
        }
        const label = document.createElement('span');
        label.textContent = entry.info.name || 'Browser Wallet';
        button.appendChild(label);
        button.addEventListener('click', () => connect(entry.provider, label.textContent));
        walletsEl.appendChild(button);
      }
      hintEl.textContent = providers.size
        ? 'Pilih salah satu wallet yang terpasang di browser ini.'
        : 'Tidak ada wallet Ethereum yang terdeteksi. Install wallet yang mendukung EIP-6963, lalu reload halaman.';
    }

    function appCallback(account, chainId) {
      const separator = callback.includes('?') ? '&' : '?';
      return callback + separator
        + 'address=' + encodeURIComponent(account)
        + '&chainId=' + encodeURIComponent(chainId || '');
    }

    async function connect(ethereum, walletName) {
      try {
        setStatus('Menunggu persetujuan ' + walletName + '...');
        const accounts = await ethereum.request({ method: 'eth_requestAccounts' });
        const account = accounts && accounts[0];
        if (!account) {
          setStatus('Wallet did not return an account.', true);
          return;
        }
        let chainId = '';
        try {
          chainId = await ethereum.request({ method: 'eth_chainId' });
          if (chainId !== '0xaa36a7') {
            try {
              await ethereum.request({ method: 'wallet_switchEthereumChain', params: [{ chainId: '0xaa36a7' }] });
              chainId = '0xaa36a7';
            } catch (switchError) {
              setStatus('Wallet connected. Switch to Sepolia in wallet if balances look wrong.');
            }
          }
        } catch (chainError) {}
        setStatus('Connected: ' + account.slice(0, 6) + '...' + account.slice(-4));
        location.href = appCallback(account, chainId);
      } catch (error) {
        setStatus(error && error.message ? error.message : 'Wallet connection cancelled.', true);
      }
    }

    window.addEventListener('eip6963:announceProvider', (event) => {
      addProvider(event.detail && event.detail.info, event.detail && event.detail.provider);
    });
    window.dispatchEvent(new Event('eip6963:requestProvider'));
    window.setTimeout(() => {
      if (providers.size === 0 && window.ethereum) {
        addProvider({ name: 'Browser Wallet', uuid: 'legacy', icon: '' }, window.ethereum);
      } else {
        renderProviders();
      }
    }, 500);
  </script>
</body>
</html>`;
}

module.exports = function walletConnect(_request, response) {
  response.setHeader('Content-Type', 'text/html; charset=utf-8');
  response.setHeader('Cache-Control', 'no-store');
  response.setHeader('Content-Security-Policy', "default-src 'self'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; img-src 'self' data:; connect-src 'self'; frame-ancestors 'none'; base-uri 'none'");
  response.setHeader('X-Content-Type-Options', 'nosniff');
  response.setHeader('Referrer-Policy', 'no-referrer');
  response.setHeader('Permissions-Policy', 'camera=(), microphone=(), geolocation=()');
  response.status(200).send(html());
};
