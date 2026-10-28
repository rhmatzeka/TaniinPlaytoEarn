const GAME_PATH = "/main/";

// Only the Android deep link or a same-origin game path may receive a session.
function safeReturnUrl(value) {
  const raw = String(value || "").trim();
  if (raw === "taniin://auth") return raw;
  if (raw.startsWith(GAME_PATH) && !raw.includes("..") && !raw.includes("//") && !raw.includes("\\")) return raw;
  return GAME_PATH;
}

function buildReturnUrl(returnUrl, values) {
  const base = safeReturnUrl(returnUrl).split("#")[0];
  return `${base}#${new URLSearchParams(values).toString()}`;
}

module.exports = { GAME_PATH, buildReturnUrl, safeReturnUrl };
