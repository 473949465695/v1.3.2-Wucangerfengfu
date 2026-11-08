(async () => {
  const $ = (s) => document.querySelector(s);
  const inj = new URLSearchParams(location.search).get('inj') || '';
  const CSS = {
    anim: '.stamp{animation:none!important}',
    hide: '.stamp{display:none!important}',
    nofoot: '.out-foot{display:none!important}',
    nomix: '.stamp{mix-blend-mode:normal!important}',
    norot: '.stamp{transform:none!important}',
  };
  if (CSS[inj]) {
    const s = document.createElement('style');
    s.textContent = CSS[inj];
    document.head.appendChild(s);
  }
  document.getElementById('agreeConsent').click();
  const i = document.getElementById('input');
  i.value = '晚上八点老地方，别迟到。';
  i.dispatchEvent(new Event('input', { bubbles: true }));
  document.getElementById('btnEncode').click();
  await new Promise((r) => setTimeout(r, 900));

  const cw = document.documentElement.clientWidth;
  const widest = [];
  document.querySelectorAll('*').forEach((el) => {
    const r = el.getBoundingClientRect();
    const b = el.getBoundingClientRect();
    widest.push([Math.round(r.right), (el.tagName + '.' + (el.className || '')).slice(0, 26), Math.round(b.width)]);
  });
  widest.sort((a, b) => b[0] - a[0]);
  return {
    inj: inj || 'baseline',
    vp: [innerWidth, innerHeight],
    cw,
    docScrollW: document.documentElement.scrollWidth,
    docScrollH: document.documentElement.scrollHeight,
    shellOverflow: getComputedStyle($('.output-shell')).overflow,
    stampRect: (() => { const b = $('.stamp').getBoundingClientRect(); return [Math.round(b.left), Math.round(b.right), Math.round(b.top)]; })(),
    top3: widest.slice(0, 3),
  };
})()
