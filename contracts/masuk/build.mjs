import { build } from "esbuild";
import { copyFileSync, mkdirSync } from "node:fs";

const outdir = new URL("../public/masuk/", import.meta.url).pathname;
mkdirSync(outdir, { recursive: true });

await build({
  entryPoints: ["app.jsx"],
  bundle: true,
  minify: true,
  splitting: true,
  format: "esm",
  target: "es2020",
  outdir,
  entryNames: "masuk-[hash]",
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
  const entry = Object.keys(result.metafile.outputs).find((file) => /masuk-[^/]+\.js$/.test(file));
  const { readFileSync, writeFileSync } = await import("node:fs");
  const html = readFileSync("index.html", "utf8").replace("__ENTRY__", `/masuk/${entry.split("/").pop()}`);
  writeFileSync(`${outdir}index.html`, html);
  copyFileSync("masuk.css", `${outdir}masuk.css`);
});
