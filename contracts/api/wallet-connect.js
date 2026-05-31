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
      display: grid;
      place-items: center;
      background: #17351f;
      color: #fff0cf;
      font-family: Inter, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    }
    main {
      width: min(92vw, 520px);
      padding: 28px;
      border: 3px solid #f0ad45;
      border-radius: 18px;
      background: #3d2819;
      box-shadow: 0 18px 50px rgba(0, 0, 0, 0.35);
    }
    .badge {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      width: 48px;
      height: 48px;
      border-radius: 14px;
      background: #ffdc5d;
      color: #3a2614;
      font-weight: 800;
      margin-bottom: 16px;
    }
    h1 { margin: 0 0 8px; font-size: 30px; line-height: 1.1; color: #ffe486; }
    p { margin: 0 0 18px; color: #f2ddbc; line-height: 1.45; }
    button, a.button {
      width: 100%;
      min-height: 54px;
      border: 0;
      border-radius: 14px;
      background: #2c8356;
      color: white;
      font: inherit;
      font-weight: 800;
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: center;
      text-decoration: none;
      margin-top: 12px;
    }
    a.button { background: #d88424; }
    #status { min-height: 24px; margin-top: 16px; color: #a9edae; }
    code { color: #ffd86b; word-break: break-all; }
  </style>
</head>
<body>
  <main>
    <div class="badge">W</div>
    <h1>Connect Taniin Wallet</h1>
    <p>Approve public account access in your wallet. Taniin will return to the Android app automatically; no private key is needed.</p>
    <button id="connect">Connect Wallet</button>
    <a id="metamask" class="button" href="#">Open in MetaMask</a>
    <div id="status"></div>
  </main>
  <script>
    const statusEl = document.getElementById('status');
    const callback = new URLSearchParams(location.search).get('return') || 'taniin://wallet';

    function setStatus(message, bad) {
      statusEl.style.color = bad ? '#ffb199' : '#a9edae';
      statusEl.textContent = message;
    }

    function appCallback(account, chainId) {
      const separator = callback.includes('?') ? '&' : '?';
      return callback + separator
        + 'address=' + encodeURIComponent(account)
        + '&chainId=' + encodeURIComponent(chainId || '');
    }

    async function connect() {
      const ethereum = window.ethereum;
      if (!ethereum || !ethereum.request) {
        setStatus('Open this page inside MetaMask or another Ethereum wallet browser.', true);
        return;
      }
      try {
        setStatus('Waiting for wallet approval...');
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

    const dappPath = location.host + location.pathname;
    document.getElementById('metamask').href = 'https://metamask.app.link/dapp/' + dappPath;
    document.getElementById('connect').addEventListener('click', connect);
  </script>
</body>
</html>`;
}

module.exports = function walletConnect(_request, response) {
  response.setHeader('Content-Type', 'text/html; charset=utf-8');
  response.setHeader('Cache-Control', 'no-store');
  response.status(200).send(html());
};
