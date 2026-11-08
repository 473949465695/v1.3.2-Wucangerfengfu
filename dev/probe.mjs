// CDP probe / screenshot driver.
// usage: node probe.mjs <fileUrl> <width> <height> <outPng|-> [scriptFile]
// env: CDP_PORT (default 9333), CDP_FULL=1 to capture beyond viewport
const [url, wArg, hArg, outPng, scriptFile] = process.argv.slice(2);
const W = Number(wArg || 390), H = Number(hArg || 844);
const PORT = process.env.CDP_PORT || '9333';
const FULL = process.env.CDP_FULL === '1';

const fs = await import('node:fs/promises');

async function getPageTarget() {
  for (let i = 0; i < 80; i++) {
    try {
      const r = await fetch(`http://127.0.0.1:${PORT}/json/list`);
      const list = await r.json();
      const page = list.find((t) => t.type === 'page' && t.webSocketDebuggerUrl);
      if (page) return page;
    } catch (_) {}
    await new Promise((r) => setTimeout(r, 250));
  }
  throw new Error('no page target on port ' + PORT);
}

const target = await getPageTarget();
const ws = new WebSocket(target.webSocketDebuggerUrl);
let id = 0;
const pending = new Map();
ws.addEventListener('message', (ev) => {
  const msg = JSON.parse(ev.data);
  if (msg.id && pending.has(msg.id)) {
    const { resolve, reject } = pending.get(msg.id);
    pending.delete(msg.id);
    if (msg.error) reject(new Error(JSON.stringify(msg.error)));
    else resolve(msg.result);
  }
});
await new Promise((res, rej) => {
  ws.addEventListener('open', res, { once: true });
  ws.addEventListener('error', rej, { once: true });
});

const send = (method, params = {}) =>
  new Promise((resolve, reject) => {
    const mid = ++id;
    pending.set(mid, { resolve, reject });
    ws.send(JSON.stringify({ id: mid, method, params }));
  });

await send('Page.enable');
await send('Runtime.enable');
await send('Emulation.setDeviceMetricsOverride', {
  width: W, height: H, deviceScaleFactor: 2, mobile: true, screenWidth: W, screenHeight: H
});
await send('Emulation.setTouchEmulationEnabled', { enabled: true, maxTouchPoints: 5 });
// cache-buster: force a real document load even if only the hash changed
const u = new URL(url);
u.searchParams.set('t', String(Date.now()));
await send('Page.navigate', { url: u.href });
await new Promise((r) => setTimeout(r, 900));

// re-apply after load so a mid-load layout change (scrollbar appearing) cannot
// leave the session with stale/overridden metrics
await send('Emulation.setScrollbarsHidden', { hidden: true });
await send('Emulation.setDeviceMetricsOverride', {
  width: W, height: H, deviceScaleFactor: 2, mobile: true, screenWidth: W, screenHeight: H
});
await new Promise((r) => setTimeout(r, 250));

if (scriptFile) {
  const src = await fs.readFile(scriptFile, 'utf8');
  const r = await send('Runtime.evaluate', { expression: src, awaitPromise: true, returnByValue: true });
  if (r.exceptionDetails) console.log('EXCEPTION ' + JSON.stringify(r.exceptionDetails).slice(0, 900));
  else console.log(JSON.stringify(r.result.value));
  await new Promise((r2) => setTimeout(r2, 600));
}

if (outPng && outPng !== '-') {
  const shot = await send('Page.captureScreenshot', { format: 'png', captureBeyondViewport: FULL });
  await fs.writeFile(outPng, Buffer.from(shot.data, 'base64'));
  console.log('SHOT ' + outPng);
}
ws.close();
process.exit(0);
