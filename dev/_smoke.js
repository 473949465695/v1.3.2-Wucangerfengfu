(async () => {
  const $ = (s) => document.querySelector(s);
  const out = [];
  const log = (k, v) => out.push(k + ' = ' + JSON.stringify(v));
  const wait = (ms) => new Promise((r) => setTimeout(r, ms));
  const setText = (v) => {
    const i = document.getElementById('input');
    i.value = v;
    i.dispatchEvent(new Event('input', { bubbles: true }));
  };

  // consent
  log('consentVisible', !$('#consentOverlay').hidden && getComputedStyle($('#consentOverlay')).display !== 'none');
  $('#agreeConsent').click();
  await wait(120);
  log('consentHiddenAfterAgree', getComputedStyle($('#consentOverlay')).display);
  log('bodyIntact', document.body.innerHTML.length > 2000);

  // encode / decode round trip on tricky input
  const cases = ['晚上八点老地方，别迟到。', 'abc', '𠀀', 'é\u0301', '吾苍耳冯福', '🙂'];
  for (const c of cases) {
    setText(c);
    $('#btnEncode').click();
    await wait(30);
    const enc = $('#outCipher').textContent.replace(/\s+/g, '');
    setText(enc);
    $('#btnDecode').click();
    await wait(30);
    const dec = $('#outPlain').textContent;
    log('roundtrip ' + JSON.stringify(c), dec === c ? 'OK' : 'FAIL ' + JSON.stringify(dec) + ' enc=' + enc.length);
  }

  // error paths
  const errs = [
    ['bad char', '苍福苍吾abca'],
    ['not multiple of 4', '苍福苍吾苍'],
    ['out of range group', '福福福福'],
  ];
  for (const [name, v] of errs) {
    setText(v);
    $('#btnDecode').click();
    await wait(30);
    log('error ' + name, { status: $('#status').textContent.trim(), invalid: $('#inShell') ? $('#inShell').dataset.invalid : null });
  }

  // theme toggle
  const before = document.documentElement.dataset.theme;
  const labelBefore = $('#themeToggle') ? $('#themeToggle').textContent.trim() : null;
  $('#themeToggle').click();
  await wait(120);
  log('theme', { before, after: document.documentElement.dataset.theme, labelBefore, labelAfter: $('#themeToggle').textContent.trim(), stored: localStorage.getItem('wcf-theme') });
  $('#themeToggle').click();
  await wait(120);

  // swap + clear
  setText('测试');
  $('#btnSwap').click();
  await wait(30);
  log('swapLabelAfterEmpty', $('#input').value);

  // history flow
  localStorage.removeItem('wcf-history');
  if (typeof renderHistory === 'function') renderHistory();
  setText('第一条');
  $('#btnEncode').click();
  await wait(60);
  $('#tab-history').click();
  await wait(60);
  log('historyCount', document.querySelectorAll('#historyList > *').length);
  const loadBtn = document.querySelector('#historyList [data-act="load"], #historyList button');
  log('historyFirstBtn', loadBtn ? loadBtn.textContent.trim() : null);

  return out;
})()
