import { build } from "esbuild";
import { copyFileSync, mkdirSync } from "node:fs";

const outdir = new URL("../public/masuk/", import.meta.url).pathname;
mkdirSync(outdir, { recursive: true });

await build({
  // The /masuk page, and the in-game login the game page loads on demand.
  entryPoints: { masuk: "app.jsx", login: "game-login.jsx" },
  bundle: true,
  minify: true,
  splitting: true,
  format: "esm",
  target: "es2020",
  outdir,
  entryNames: "[name]-[hash]",
  chunkNames: "chunk-[hash]",
  metafile: true,
  legalComments: "none",
  jsx: "automatic",
  define: {
    "process.env.PRIVY_APP_ID": JSON.stringify(process.env.PRIVY_APP_ID || ""),
    "process.env.NODE_ENV": '"production"',
    global: "globalThis"
  }
}).then(async (result) => {
  const outputs = Object.keys(result.metafile.outputs).map((file) => file.split("/").pop());
  const entry = outputs.find((file) => /^masuk-[^/]+\.js$/.test(file));
  const login = outputs.find((file) => /^login-[^/]+\.js$/.test(file));
  const { readFileSync, writeFileSync } = await import("node:fs");
  const html = readFileSync("index.html", "utf8").replace("__ENTRY__", `/masuk/${entry}`);
  writeFileSync(`${outdir}index.html`, html);
  // Stable name for the game page's loader; the hashed file is cached forever.
  writeFileSync(`${outdir}login.js`, `export * from "./${login}";\n`);
  copyFileSync("masuk.css", `${outdir}masuk.css`);
});
