function safeReturnUrl(request) {
  const fallback = `${request.headers['x-forwarded-proto'] || 'https'}://${request.headers.host || ''}/`;
  const requested = typeof request.query?.return === 'string' ? request.query.return : '';
  try {
    const url = new URL(requested || fallback, fallback);
    if (url.protocol === 'taniin:' && url.host === 'wallet') return url.toString();
    if (url.protocol === 'https:' && url.origin === new URL(fallback).origin) return url.toString();
  } catch (_) {}
  return fallback;
}

function escapeJson(value) {
  return JSON.stringify(value).replace(/[<>&]/g, (character) => `\\u${character.charCodeAt(0).toString(16).padStart(4, '0')}`);
}

module.exports = function walletConnect(request, response) {
  const returnUrl = safeReturnUrl(request);
  const config = escapeJson({
    projectId: process.env.TANIIN_WALLETCONNECT_PROJECT_ID || '',
    returnUrl,
    cancelUrl: returnUrl,
  });
  const page = `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
  <meta name="theme-color" content="#0b2116">
  <title>Connect Wallet | Taniin</title>
  <link rel="stylesheet" href="/wallet-connect.css">
</head>
<body>
  <div id="root"></div>
  <script>window.__TANIIN_WALLET_CONFIG__=${config}</script>
  <script src="/wallet-connect.js" defer></script>
</body>
</html>`;

  response.setHeader('Content-Type', 'text/html; charset=utf-8');
  response.setHeader('Cache-Control', 'no-store');
  response.setHeader('Content-Security-Policy', "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; connect-src 'self' https: wss:; frame-src https:; frame-ancestors 'none'; base-uri 'none'");
  response.setHeader('X-Content-Type-Options', 'nosniff');
  response.setHeader('Referrer-Policy', 'strict-origin');
  response.setHeader('Permissions-Policy', 'camera=(), microphone=(), geolocation=()');
  response.status(200).send(page);
};
