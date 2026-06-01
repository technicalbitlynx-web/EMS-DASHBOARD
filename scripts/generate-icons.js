'use strict';
// Generates public/icons/icon-192.png and icon-512.png
// Run once: node scripts/generate-icons.js
const zlib = require('zlib');
const fs   = require('fs');
const path = require('path');

// ── CRC-32 ────────────────────────────────────────────────────────
const CRC = (() => {
  const t = new Uint32Array(256);
  for (let i = 0; i < 256; i++) {
    let c = i;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xEDB88320 ^ (c >>> 1) : c >>> 1;
    t[i] = c;
  }
  return t;
})();
function crc32(buf) {
  let c = 0xFFFFFFFF;
  for (const b of buf) c = CRC[(c ^ b) & 0xFF] ^ (c >>> 8);
  return (c ^ 0xFFFFFFFF) >>> 0;
}
function u32(n) { const b = Buffer.alloc(4); b.writeUInt32BE(n); return b; }
function pngChunk(type, data) {
  const t = Buffer.from(type);
  return Buffer.concat([u32(data.length), t, data, u32(crc32(Buffer.concat([t, data])))]);
}

// ── Icon pixel renderer ───────────────────────────────────────────
function pixel(x, y, W, H) {
  const px = x / W;   // 0..1
  const py = y / H;

  const BG   = [15, 138, 80];    // #0f8a50 EMS green
  const BODY = [255, 255, 255];  // white server rack body
  const DIV  = [167, 224, 192];  // soft green divider lines
  const LED  = [52, 192, 125];   // #34c07d green LED dot

  // Server rack body: 18–82% wide, 25–75% tall
  if (px >= 0.18 && px <= 0.82 && py >= 0.25 && py <= 0.75) {
    // Horizontal unit dividers
    if ((py >= 0.41 && py <= 0.43) || (py >= 0.58 && py <= 0.60)) return DIV;
    // LED indicator dots (right side of each unit)
    const inLed = px >= 0.70 && px <= 0.77 && (
      (py >= 0.29 && py <= 0.37) ||
      (py >= 0.46 && py <= 0.54) ||
      (py >= 0.63 && py <= 0.71)
    );
    if (inLed) return LED;
    return BODY;
  }
  return BG;
}

// ── PNG builder ───────────────────────────────────────────────────
function makePng(size) {
  const raw = [];
  for (let y = 0; y < size; y++) {
    raw.push(0); // filter: None
    for (let x = 0; x < size; x++) raw.push(...pixel(x, y, size, size));
  }
  const IHDR = Buffer.from([
    0,0,0,0, 0,0,0,0,   // width, height (set below)
    8,                   // bit depth
    2,                   // colour type: RGB
    0, 0, 0              // compression, filter, interlace
  ]);
  IHDR.writeUInt32BE(size, 0);
  IHDR.writeUInt32BE(size, 4);
  return Buffer.concat([
    Buffer.from([137,80,78,71,13,10,26,10]),   // PNG signature
    pngChunk('IHDR', IHDR),
    pngChunk('IDAT', zlib.deflateSync(Buffer.from(raw), { level: 9 })),
    pngChunk('IEND', Buffer.alloc(0)),
  ]);
}

// ── Write files ───────────────────────────────────────────────────
const out = path.join(__dirname, '..', 'public', 'icons');
fs.mkdirSync(out, { recursive: true });
for (const size of [192, 512]) {
  const file = path.join(out, `icon-${size}.png`);
  fs.writeFileSync(file, makePng(size));
  console.log(`  created ${file}`);
}
console.log('Done — commit public/icons/ to git.');
