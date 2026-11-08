(() => {
  const mode = (location.hash || '#editor').slice(1);
  const $ = (s) => document.querySelector(s);
  const setText = (v) => {
    const i = document.getElementById('input');
    i.value = v;
    i.dispatchEvent(new Event('input', { bubbles: true }));
  };
  const encode = (v) => { setText(v); document.getElementById('btnEncode').click(); };
  const decode = (v) => { setText(v); document.getElementById('btnDecode').click(); };

  // full-page capture: let the bar flow after the content so nothing is hidden
  if (new URLSearchParams(location.search).get('cap') === 'full') {
    const st = document.createElement('style');
    st.textContent = '.tabbar{position:static!important;transform:none!important;width:auto!important}.app{padding-bottom:0!important}';
    document.head.appendChild(st);
  }

  if (mode !== 'consent') {
    const agree = document.getElementById('agreeConsent');
    if (agree) agree.click();
  }
  // theme goes through the real toggle so the button label stays truthful
  const wantTheme = mode === 'ink' ? 'ink' : 'paper';
  if (document.documentElement.dataset.theme !== wantTheme) {
    const t = document.getElementById('themeToggle');
    if (t) t.click();
  }
  if (mode === 'history') {
    localStorage.removeItem('wcf-history');
    if (typeof renderHistory === 'function') renderHistory();
  }
  if (mode === 'editor' || mode === 'ink') {
    encode('晚上八点老地方，别迟到。');
  }
  if (mode === 'history') {
    encode('晚上八点老地方，别迟到。');
    encode('今天那家店排队排到马路上了。');
    decode('苍福苍吾苍苍吾冯苍苍吾福苍福吾冯苍耳苍福苍吾耳冯苍福吾福苍吾苍冯');
    document.getElementById('tab-history').click();
  }
  if (mode === 'announce') {
    document.getElementById('tab-announce').click();
  }
  if (mode === 'decode') {
    decode('苍福苍吾苍苍吾冯苍苍吾福苍福吾冯苍耳苍福苍吾耳冯苍福吾福苍吾苍冯');
  }
  if (mode === 'error') {
    decode('苍福苍吾abc');
  }

  const d = document.documentElement;
  const over = [];
  document.querySelectorAll('*').forEach((el) => {
    const r = el.getBoundingClientRect();
    if (r.right > d.clientWidth + 0.5 || r.left < -0.5) {
      over.push((el.tagName + '.' + (el.className || '')).slice(0, 34) + ' L=' + Math.round(r.left) + ' R=' + Math.round(r.right));
    }
  });
  return {
    mode,
    innerWidth: window.innerWidth,
    clientWidth: d.clientWidth,
    scrollWidth: d.scrollWidth,
    docHeight: Math.round(document.body.getBoundingClientRect().height),
    over
  };
})()
