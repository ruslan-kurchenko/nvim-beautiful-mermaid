const fs = require('fs');

function readStdin() {
  return new Promise((resolve) => {
    let data = '';
    process.stdin.setEncoding('utf8');
    process.stdin.on('data', (chunk) => { data += chunk; });
    process.stdin.on('end', () => resolve(data));
  });
}

async function main() {
  const input = await readStdin();
  let payload;
  try {
    payload = JSON.parse(input);
  } catch (err) {
    process.stdout.write(JSON.stringify({ error: 'invalid json input' }));
    process.exit(1);
  }

  let renderMermaid;
  let renderMermaidAscii;
  try {
    const path = require('path');
    const bundlePath = path.join(__dirname, 'vendor', 'beautiful-mermaid.bundle.cjs');
    ({ renderMermaid, renderMermaidAscii } = require(bundlePath));
  } catch (err) {
    const msg = err && err.message ? err.message : String(err);
    process.stdout.write(JSON.stringify({ error: 'beautiful-mermaid bundle not available: ' + msg }));
    process.exit(1);
  }

  try {
    const text = payload.text || '';
    const options = payload.options || {};
    if (payload.format === 'ascii') {
      const output = await renderMermaidAscii(text, options);
      process.stdout.write(JSON.stringify({ output }));
      return;
    }
    const output = await renderMermaid(text, options);
    process.stdout.write(JSON.stringify({ output }));
  } catch (err) {
    process.stdout.write(JSON.stringify({ error: String(err) }));
    process.exit(1);
  }
}

main();
