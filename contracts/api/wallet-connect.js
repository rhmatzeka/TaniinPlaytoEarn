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
    body { background: radial-gradient(circle at 50% 0%, #28563b 0, #102c20 42%, #091b14 100%); }
    main { width: min(100%, 720px); border-radius: 22px; border-width: 4px; background: #132d21; }
    header { min-height: 84px; padding: 16px 20px; background: #173b2a; border-bottom: 1px solid #315943; }
    h1 { font-size: clamp(24px, 5vw, 32px); color: #fff4d8; }
    .dot { display: none; }
    .badge { background: #ffcf32; border-color: #78520b; border-radius: 12px; }
    .back {
      margin-left: auto;
      width: 44px;
      min-height: 44px;
      padding: 0;
      border: 1px solid #496d58;
      border-radius: 12px;
      background: #234b36;
      font-size: 24px;
    }
    .content { padding: 22px; }
    .frame { padding: 0; border: 0; background: transparent; }
    .lead { color: #c9d9ce; font-weight: 600; margin-bottom: 16px; }
    .search {
      width: 100%;
      height: 50px;
      padding: 0 16px;
      border: 1px solid #496d58;
      border-radius: 13px;
      outline: none;
      background: #0d2419;
      color: #fff4d8;
      font: inherit;
      font-weight: 700;
    }
    .search:focus { border-color: #74d693; box-shadow: 0 0 0 3px rgba(116, 214, 147, .14); }
    .section-title { margin: 22px 0 10px; color: #fff4d8; font-size: 14px; letter-spacing: .08em; text-transform: uppercase; }
    .hint { margin: 10px 0 0; border: 0; padding: 0; background: transparent; color: #8eaa98; font-weight: 600; }
    #wallets, #popular { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 10px; }
    .wallet-choice, .popular-wallet {
      position: relative;
      min-height: 68px;
      margin: 0;
      padding: 10px 14px;
      justify-content: flex-start;
      gap: 12px;
      border: 1px solid #426650;
      border-radius: 14px;
      background: #1b432f;
      transition: border-color .15s, background .15s, transform .15s;
    }
    .wallet-choice:hover, .popular-wallet:hover { background: #24583d; border-color: #79d596; transform: translateY(-1px); }
    .wallet-choice img, .popular-icon { width: 38px; height: 38px; border-radius: 10px; object-fit: contain; }
    .popular-icon { display: grid; place-items: center; background: #0d2419; color: #ffcf32; font-size: 20px; font-weight: 900; }
    .wallet-copy { min-width: 0; display: flex; flex-direction: column; align-items: flex-start; gap: 3px; }
    .wallet-name { color: #fff4d8; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; max-width: 100%; }
    .wallet-state { color: #91b19c; font-size: 12px; font-weight: 700; }
    .installed { color: #7bea9f; }
    #status { padding: 10px 0 0; margin: 0; }
    .footer { margin-top: 20px; padding-top: 16px; border-top: 1px solid #315943; display: flex; justify-content: space-between; gap: 12px; flex-wrap: wrap; }
    .network { margin: 0; color: #a9c1b0; }
    .safety { color: #789484; font-size: 12px; font-weight: 600; }
    @media (max-width: 560px) {
      #wallets, #popular { grid-template-columns: 1fr; }
      main { border-radius: 16px; }
      .content { padding: 18px; }
    }
  </style>
</head>
<body>
  <main>
    <header>
      <div class="badge">W</div>
      <h1>Pilih Wallet</h1>
      <button id="back" class="back" aria-label="Kembali">&times;</button>
    </header>
    <section class="content">
      <div class="frame">
        <p class="lead">Hubungkan wallet Ethereum untuk bermain dan menyinkronkan aktivitas Sepolia.</p>
        <input id="search" class="search" type="search" placeholder="Cari wallet..." autocomplete="off">
        <h2 class="section-title">Tersedia di browser</h2>
        <div id="hint" class="hint"></div>
        <div id="wallets"></div>
        <h2 class="section-title">Wallet populer</h2>
        <div id="popular"></div>
        <div id="status"></div>
        <div class="footer">
          <div class="network">Sepolia network</div>
          <div class="safety">Taniin tidak pernah meminta seed phrase.</div>
        </div>
      </div>
    </section>
  </main>
  <script>
    const statusEl = document.getElementById('status');
    const hintEl = document.getElementById('hint');
    const walletsEl = document.getElementById('wallets');
    const popularEl = document.getElementById('popular');
    const searchEl = document.getElementById('search');
    const backButton = document.getElementById('back');
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
    const popularWallets = [
      { name: 'Rabby Wallet', short: 'R', url: 'https://rabby.io/' },
      { name: 'Coinbase Wallet', short: 'C', url: 'https://www.coinbase.com/wallet/downloads' },
      { name: 'OKX Wallet', short: 'O', url: 'https://www.okx.com/web3' },
      { name: 'Trust Wallet', short: 'T', url: 'https://trustwallet.com/download' },
      { name: 'MetaMask', short: 'M', url: 'https://metamask.io/download/' },
      { name: 'WalletConnect', short: 'W', url: '', disabled: true }
    ];

    function addProvider(info, provider) {
      if (!provider || typeof provider.request !== 'function') return;
      const key = info && info.uuid ? info.uuid : (info && info.rdns ? info.rdns : 'legacy');
      if (providers.has(key)) return;
      providers.set(key, { info: info || { name: 'Browser Wallet', icon: '' }, provider });
      renderProviders();
    }

    function walletButton(name, icon, subtitle, onClick, className) {
      const button = document.createElement('button');
      button.className = className;
      button.dataset.walletName = name.toLowerCase();
      if (icon && icon.startsWith('data:image/')) {
        const image = document.createElement('img');
        image.src = icon;
        image.alt = '';
        button.appendChild(image);
      } else {
        const fallback = document.createElement('span');
        fallback.className = 'popular-icon';
        fallback.textContent = icon || name.slice(0, 1);
        button.appendChild(fallback);
      }
      const copy = document.createElement('span');
      copy.className = 'wallet-copy';
      const title = document.createElement('span');
      title.className = 'wallet-name';
      title.textContent = name;
      const state = document.createElement('span');
      state.className = 'wallet-state' + (subtitle === 'Terpasang' ? ' installed' : '');
      state.textContent = subtitle;
      copy.append(title, state);
      button.appendChild(copy);
      if (onClick) button.addEventListener('click', onClick);
      if (!onClick) button.disabled = true;
      return button;
    }

    function renderProviders() {
      walletsEl.replaceChildren();
      for (const entry of providers.values()) {
        const name = entry.info.name || 'Browser Wallet';
        walletsEl.appendChild(walletButton(name, entry.info.icon, 'Terpasang', () => connect(entry.provider, name), 'wallet-choice'));
      }
      hintEl.textContent = providers.size
        ? ''
        : 'Belum ada wallet Ethereum yang terdeteksi di browser ini.';
      renderPopular();
      filterWallets();
    }

    function renderPopular() {
      popularEl.replaceChildren();
      const installedNames = Array.from(providers.values()).map((entry) => String(entry.info.name || '').toLowerCase());
      for (const wallet of popularWallets) {
        const installed = installedNames.some((name) => name.includes(wallet.name.split(' ')[0].toLowerCase()));
        if (installed) continue;
        const action = wallet.disabled
          ? null
          : () => window.open(wallet.url, '_blank', 'noopener,noreferrer');
        popularEl.appendChild(walletButton(wallet.name, wallet.short, wallet.disabled ? 'Segera hadir' : 'Install', action, 'popular-wallet'));
      }
    }

    function filterWallets() {
      const query = searchEl.value.trim().toLowerCase();
      document.querySelectorAll('[data-wallet-name]').forEach((item) => {
        item.hidden = query && !item.dataset.walletName.includes(query);
      });
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
    searchEl.addEventListener('input', filterWallets);
    backButton.addEventListener('click', () => {
      if (history.length > 1) history.back();
      else location.href = location.origin;
    });
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
