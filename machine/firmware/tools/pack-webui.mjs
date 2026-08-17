// Puts the app on the machine.
//
// The machine makes its own network when there is nothing to join, and a laptop
// on that network has no way out to the internet, so the libraries the page
// loads from a CDN have to come along with it. This fetches them once, points
// the page at the local copies, compresses everything and leaves it in data/,
// which is what `pio run -t uploadfs` writes to the board.
//
//   node tools/pack-webui.mjs
//
// Run it again whenever index.html changes.
import { gzipSync } from 'node:zlib';
import { mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, '..', '..', '..');
const out = join(here, '..', 'data');

// Everything the page pulls from elsewhere, and what it becomes on the machine.
// The flags are part of the language picker, so they matter as much as React.
const external = [
  ['https://unpkg.com/react@18/umd/react.production.min.js', 'vendor/react.js'],
  ['https://unpkg.com/react-dom@18/umd/react-dom.production.min.js', 'vendor/react-dom.js'],
  ['https://unpkg.com/jspdf@2.5.1/dist/jspdf.umd.min.js', 'vendor/jspdf.js'],
  ['https://unpkg.com/three@0.147.0/build/three.min.js', 'vendor/three.js'],
  ['https://flagcdn.com/w20/gb.png', 'vendor/gb.png'],
  ['https://flagcdn.com/w20/pt.png', 'vendor/pt.png'],
  ['https://flagcdn.com/w20/fr.png', 'vendor/fr.png'],
  ['https://flagcdn.com/w20/es.png', 'vendor/es.png'],
  ['https://flagcdn.com/w20/it.png', 'vendor/it.png'],
  ['https://flagcdn.com/w20/de.png', 'vendor/de.png']
];

function human(n) {
  return n < 1024 ? n + ' B' : (n / 1024).toFixed(1) + ' kB';
}

async function grab(url) {
  const answer = await fetch(url);
  if (!answer.ok) throw new Error(url + ' came back ' + answer.status);
  return Buffer.from(await answer.arrayBuffer());
}

const FONT_CSS = 'https://fonts.googleapis.com/css2?family=Exo:wght@100;300;600&display=swap';
// Google hands back a different stylesheet depending on who is asking; this is
// the one that gets woff2, which is the small one.
const MODERN = 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122 Safari/537.36';

rmSync(out, { recursive: true, force: true });
mkdirSync(join(out, 'vendor'), { recursive: true });

let page = readFileSync(join(root, 'index.html'), 'utf8');
let total = 0;

for (const [url, local] of external) {
  const body = await grab(url);
  // Pictures are already compressed; squeezing them again only wastes flash.
  const zip = local.endsWith('.png');
  const written = zip ? body : gzipSync(body, { level: 9 });
  writeFileSync(join(out, local + (zip ? '' : '.gz')), written);
  total += written.length;
  console.log(`  ${local.padEnd(20)} ${human(body.length).padStart(9)} -> ${human(written.length)}`);
  if (!page.includes(url)) throw new Error('index.html no longer asks for ' + url);
  page = page.split(url).join('/' + local);
}

// The typeface, which is a stylesheet pointing at a handful of files. Without
// it the page falls back to whatever the laptop has, which works but does not
// look like the app people know.
{
  let css = await (await fetch(FONT_CSS, { headers: { 'User-Agent': MODERN } })).text();
  const urls = [...new Set([...css.matchAll(/url\((https:\/\/[^)]+)\)/g)].map(m => m[1]))];
  let n = 0;
  for (const url of urls) {
    const body = await grab(url);
    const local = 'vendor/font-' + (n++) + '.woff2';
    writeFileSync(join(out, local), body);
    total += body.length;
    css = css.split(url).join('/' + local);
    console.log(`  ${local.padEnd(20)} ${human(body.length).padStart(9)} -> ${human(body.length)}`);
  }
  const zipped = gzipSync(Buffer.from(css, 'utf8'), { level: 9 });
  writeFileSync(join(out, 'vendor/fonts.css.gz'), zipped);
  total += zipped.length;
  page = page.split(FONT_CSS).join('/vendor/fonts.css');
  // The preconnects would still send the browser looking for a Google that is
  // not there on a machine making its own network.
  page = page.replace(/\s*<link rel="preconnect"[^>]*>/g, '');
}

// Served from the machine, the app already knows where the machine is.
page = page.replace("host: 'printer.local'", "host: location.host || 'printer.local'");

const zipped = gzipSync(Buffer.from(page, 'utf8'), { level: 9 });
writeFileSync(join(out, 'index.html.gz'), zipped);
total += zipped.length;
console.log(`  ${'index.html'.padEnd(20)} ${human(page.length).padStart(9)} -> ${human(zipped.length)}`);

const budget = 2 * 1024 * 1024;
console.log(`\n${human(total)} of ${human(budget)} filesystem used.`);
if (total > budget * 0.9) {
  console.error('That is too close to the edge; trim something before flashing.');
  process.exit(1);
}
console.log('Now: pio run -t uploadfs');
