#!/usr/bin/env node
// Decrypt AES-256-GCM envelope: v1:iv_b64:ct_b64:tag_b64
// Mirrors openclaw-cfw/src/lib/crypto/secrets.ts and cfw-social/src/lib/crypto/secrets.ts.
//
// Usage:
//   ENCRYPTION_KEY=<64-hex> node decrypt-token.mjs <envelope>
//
// Prints plaintext to stdout. Exits 2 on config / format errors,
// 1 on decryption failure (tampered ciphertext, wrong key).

import { createDecipheriv } from "node:crypto";

const ALGO = "aes-256-gcm";
const VERSION = "v1";

const envelope = process.argv[2];
const keyHex = process.env.ENCRYPTION_KEY;

if (!keyHex || keyHex.length !== 64) {
  console.error("ENCRYPTION_KEY must be a 64-char hex string (32 bytes)");
  process.exit(2);
}
if (!envelope) {
  console.error("usage: decrypt-token.mjs <envelope>");
  process.exit(2);
}

const parts = envelope.split(":");
if (parts.length !== 4) {
  console.error("envelope must be v1:iv:ct:tag");
  process.exit(2);
}
const [version, ivB64, ctB64, tagB64] = parts;
if (version !== VERSION) {
  console.error(`unsupported envelope version: ${version}`);
  process.exit(2);
}

try {
  const key = Buffer.from(keyHex, "hex");
  const iv = Buffer.from(ivB64, "base64");
  const ct = Buffer.from(ctB64, "base64");
  const tag = Buffer.from(tagB64, "base64");
  const decipher = createDecipheriv(ALGO, key, iv);
  decipher.setAuthTag(tag);
  const pt = Buffer.concat([decipher.update(ct), decipher.final()]);
  process.stdout.write(pt.toString("utf8"));
} catch {
  console.error("decryption failed — bad key or tampered ciphertext");
  process.exit(1);
}
