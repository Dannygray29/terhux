#!/usr/bin/env node
'use strict';

const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

function fail(message) {
  console.error(message);
  process.exit(2);
}

const inputPath = process.argv[2];
const certPath = process.argv[3] || path.join(__dirname, 'terhux-access-cert.pem');
const pin = process.env.TERHUX_PIN;
if (!inputPath) fail('Usage: node terhux-encrypt-request.js <fields.json> [public-cert.pem]');
if (!pin || pin.length < 4 || pin.length > 64) fail('TERHUX_PIN must be supplied through the agent secret store (4-64 characters).');
if (!fs.existsSync(certPath)) fail('Terhux public certificate is unavailable; ask the phone owner to initialize access first.');

let fields;
try {
  fields = JSON.parse(fs.readFileSync(inputPath, 'utf8'));
} catch (_) {
  fail('Request fields file must contain valid JSON.');
}
if (!fields || Array.isArray(fields) || typeof fields !== 'object') fail('Request fields must be a JSON object.');

const cleartext = Buffer.from(JSON.stringify({ protocol: 'TERHUX_ISSUE_V1', pin, fields }), 'utf8');
if (cleartext.length > 32000) fail('Encrypted request payload exceeds 32 KB.');
const proc = spawnSync('openssl', [
  'cms', '-encrypt', '-binary', '-aes-256-gcm',
  '-in', '-', '-outform', 'DER', certPath,
], { input: cleartext, maxBuffer: 1024 * 1024, encoding: null });
cleartext.fill(0);
if (proc.error || proc.status !== 0 || !proc.stdout) {
  fail('OpenSSL CMS AES-GCM encryption failed; install OpenSSL 3.x and use the current public certificate.');
}
process.stdout.write(`TERHUX_CMS_V1\nPAYLOAD_B64=${proc.stdout.toString('base64')}\n`);
