async (page) => {
  const base = 'http://127.0.0.1:8815/docs/china-fork/prototype/';
  const capture = name => page.locator('#phone').screenshot({ path: `output/playwright/m1/${name}.png` });
  const reports = [];
  await page.setViewportSize({ width: 390, height: 844 });
  for (const screen of ['home', 'search', 'detail', 'edit']) {
    await page.goto(base + `index.html?standalone=1&screen=${screen}`);
    if (screen === 'detail') await page.locator('#quantity').fill('150');
    if (screen === 'edit') {
      await page.getByRole('textbox', { name: '食品名称', exact: true }).fill('自制鸡蛋羹');
      await page.getByRole('combobox', { name: '营养基准单位', exact: true }).selectOption('serving');
      for (const [name, value] of [['热量', '110'], ['蛋白质', '9'], ['脂肪', '7'], ['碳水化合物', '2']]) await page.getByRole('spinbutton', { name, exact: true }).fill(value);
      await page.evaluate(() => { document.activeElement.blur(); document.querySelector('.screen-body').scrollTop = 0; });
    }
    await page.waitForFunction(() => [...document.images].every(img => img.complete));
    await capture(screen);
  }
  for (const style of ['clear', 'warm']) for (const theme of ['light', 'dark']) {
    await page.goto(base + `index.html?standalone=1&screen=home&style=${style}&theme=${theme}`);
    const colors = await page.locator('#phone').evaluate(el => {
      const c = getComputedStyle(el);
      return Object.fromEntries(['bg', 'surface', 'text', 'secondary', 'accent', 'on-accent', 'soft', 'warning', 'warning-bg'].map(key => [key, c.getPropertyValue('--' + key).trim()]));
    });
    const luminance = hex => { const channels = hex.slice(1).match(/../g).map(s => parseInt(s, 16) / 255).map(v => v <= .04045 ? v / 12.92 : ((v + .055) / 1.055) ** 2.4); return .2126 * channels[0] + .7152 * channels[1] + .0722 * channels[2]; };
    const pairs = [['text', 'bg'], ['secondary', 'bg'], ['text', 'surface'], ['secondary', 'surface'], ['accent', 'on-accent'], ['accent', 'soft'], ['warning', 'warning-bg']];
    const contrasts = pairs.map(([a, b]) => { const x = luminance(colors[a]), y = luminance(colors[b]); const ratio = (Math.max(x, y) + .05) / (Math.min(x, y) + .05); if (ratio < 4.5) throw new Error(`${style}/${theme}/${a}/${b} contrast ${ratio}`); return { pair: `${a}/${b}`, ratio: Number(ratio.toFixed(2)) }; });
    reports.push({ style, theme, contrasts });
    await capture(`${style}-${theme}`);
  }
  await page.setViewportSize({ width: 360, height: 480 });
  await page.goto(base + 'index.html?standalone=1&screen=detail');
  const keyboardFit = await page.locator('.portion-dock').evaluate(el => { const r = el.getBoundingClientRect(); return { top: r.top, bottom: r.bottom, viewport: innerHeight }; });
  if (keyboardFit.bottom > keyboardFit.viewport) throw new Error('Small-height quantity dock clipped');
  await capture('compact-height');
  await page.setViewportSize({ width: 1480, height: 1020 });
  await page.goto(base + 'overview.html');
  await page.waitForFunction(() => [...document.querySelectorAll('iframe')].every(f => f.contentDocument?.querySelector('#app h1')));
  for (const frame of page.frames().slice(1)) await frame.waitForFunction(() => [...document.images].every(img => img.complete));
  await page.screenshot({ path: 'output/playwright/m1/overview.png', fullPage: true });
  await page.setViewportSize({ width: 1100, height: 980 });
  await page.goto(base + 'index.html');
  return { contrastChecks: reports, smallHeightDock: keyboardFit, screenshots: ['home', 'search', 'detail', 'edit', 'clear-light', 'clear-dark', 'warm-light', 'warm-dark', 'compact-height', 'overview'] };
}
