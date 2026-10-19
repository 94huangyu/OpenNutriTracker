'use strict';

(() => {
  const M = globalThis.NutritionPrototype;
  const $ = (selector) => document.querySelector(selector);
  const escape = (v) => String(v ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const copy = v => structuredClone(v);
  const uid = () => globalThis.crypto?.randomUUID?.() ?? `demo-${Date.now()}-${Math.random().toString(36).slice(2)}`;
  const fmt = (v, precision = 1) => v == null ? '—' : Number(v.toFixed(precision)).toLocaleString('zh-CN', { maximumFractionDigits: precision });
  const unitLabel = u => ({ g: 'g', ml: 'mL', serving: '份' }[u] ?? u);
  const foodUnit = (food, unit) => unit === 'serving' ? (food.servingLabel || food.portion?.label || '份') : unitLabel(unit);
  const meals = { breakfast: '早餐', lunch: '午餐', dinner: '晚餐', snack: '加餐' };
  const storageKey = 'ont-m1-design-demo-v4';
  const asset = id => `../../../assets/demo/meals/${id}.jpg`;
  const photos = { oats: asset('1548807371-30dc1bbe6cb5'), rice: asset('1593357849627-cbbc9fda6b05'), chicken: asset('1762631934518-f75e233413ca'), yogurt: asset('1571212515416-fef01fc43637'), apple: asset('1567306226416-28f0efdc88ce'), broccoli: asset('1646161762904-043f71f256f1'), almonds: asset('1627820752174-acae1b399128') };
  const paths = {
    back: '<path d="m14 5-7 7 7 7"/>', next: '<path d="m9 5 7 7-7 7"/>',
    plus: '<path d="M12 5v14M5 12h14"/>', close: '<path d="m6 6 12 12M6 18 18 6"/>',
    search: '<circle cx="10.5" cy="10.5" r="6.5"/><path d="m16 16 4.5 4.5"/>',
    scan: '<path d="M8 3H3v5m13-5h5v5M3 16v5h5m13-5v5h-5M7 8v8m3-8v8m4-8v8m3-8v8"/>',
    calendar: '<rect x="4" y="5" width="16" height="16" rx="3"/><path d="M8 3v4m8-4v4M4 11h16"/>',
    book: '<path d="M4 4h7a3 3 0 0 1 3 3v14a3 3 0 0 0-3-3H4zm16 0h-6m6 0v14h-3"/>',
    bowl: '<path d="M3 11h18a9 9 0 0 1-18 0Zm5 10h8M8 3v4m4-5v5m4-4v4"/>',
    chart: '<path d="M4 3v17h17M8 15l4-5 4 2 5-7"/>',
    settings: '<path d="M4 6h16M4 12h16M4 18h16M8 3v6m8 0v6M8 15v6"/>',
    person: '<circle cx="12" cy="7" r="4"/><path d="M4 21v-2a8 8 0 0 1 16 0v2"/>',
    star: '<path d="m12 3 2.8 5.7 6.2.9-4.5 4.4 1.1 6.2-5.6-3-5.6 3 1.1-6.2L3 9.6l6.2-.9Z"/>',
    edit: '<path d="m15 4 5 5M4 20l5-1L21 7a2 2 0 0 0-5-5L4 14Z"/>',
    check: '<path d="m5 12 4 4L19 6"/>', more: '<path d="m6 9 6 6 6-6"/>',
    info: '<circle cx="12" cy="12" r="9"/><path d="M12 11v6m0-10v.1"/>',
    camera: '<path d="M4 7h4l2-3h4l2 3h4v14H4Z"/><circle cx="12" cy="13" r="4"/>',
    copy: '<rect x="8" y="8" width="13" height="13" rx="2"/><path d="M15 4H4v11"/>',
    trash: '<path d="M3 6h18M9 6V3h6v3M6 6l1 15h10l1-15M10 10v7m4-7v7"/>',
  };
  const icon = (name, filled = false) => `<svg class="icon" viewBox="0 0 24 24" aria-hidden="true" fill="${filled ? 'currentColor' : 'none'}" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round">${paths[name] ?? paths.bowl}</svg>`;
  function seed() {
    const food = (id, name, values, extras = {}) => ({ id, name, brand: '', image: photos[id] ?? null, source: '参考食品库 · 示例', kind: 'reference', basisAmount: 100, basisUnit: 'g', nutrients: M.nutrients(values), checked: false, evidence: '', evidenceType: 'none', favorite: false, ...extras });
    const foods = [
      food('oats', '燕麦粥', { energy: 150, protein: 5, fat: 3, carbs: 27, fiber: 4, sodium: 6 }, { kind: 'mine', source: '我的食品', checked: true, evidenceType: 'reference', evidence: '示例：已对照所用食谱核对配料与成品重量。', checkedAt: '2026-10-14', portion: { label: '碗', amount: 200, unit: 'g' }, favorite: true }),
      food('rice', '熟糙米饭', { energy: 123, protein: 3, fat: 1, carbs: 26, fiber: 1.8, sodium: 5, zinc: .6, vitaminB6: .15 }, { kind: 'mine', source: '我的食品', checked: true, evidenceType: 'reference', evidence: '示例：核对熟食基准，非干米重量。', checkedAt: '2026-10-14', portion: { label: '碗', amount: 150, unit: 'g' }, favorite: true }),
      food('chicken', '鸡胸肉（熟）', { energy: 165, protein: 31, fat: 3.6, carbs: 0, sodium: 74, cholesterol: 85, zinc: 1, vitaminB6: .6 }, { portion: { label: '份', amount: 120, unit: 'g' } }),
      food('yogurt', '原味希腊酸奶', { energy: 59, protein: 10, fat: .4, carbs: 3.6, sugars: 3.6, calcium: 110 }, { brand: '示例品牌', source: '包装标签 · 示例', kind: 'mine', portion: { label: '杯', amount: 100, unit: 'g' }, favorite: true }),
      food('apple', '苹果（带皮）', { energy: 52, protein: .3, fat: .2, carbs: 13.8, fiber: 2.4 }, { portion: { label: '个', amount: 150, unit: 'g' } }),
      food('broccoli', '西兰花', { energy: 34, protein: 2.8, fat: .4, carbs: 7, fiber: 2.6, sodium: 33, vitaminC: 89 }),
      food('milk', '纯牛奶', { energy: 61, protein: 3.2, fat: 3.3, carbs: 4.8, sugars: 4.8, sodium: 43, calcium: 113 }, { basisUnit: 'ml', brand: '示例品牌', source: '公共包装食品库 · 示例', portion: { label: '盒', amount: 250, unit: 'ml' } }),
      food('egg', '家常鸡蛋羹', { energy: 110, protein: 9, fat: 7, carbs: 2 }, { kind: 'mine', source: '我的食品', basisAmount: 150, portion: { label: '份', amount: 150, unit: 'g' } }),
      food('almonds', '原味杏仁', { energy: 579, protein: 21, fat: 50, carbs: 22, fiber: 12.5, magnesium: 270 }),
      food('cn-milk', '伊利纯牛奶', {}, { brand: '伊利', barcode: '6907992507385', source: 'Open Food Facts · 样例', kind: 'public' }),
      food('nutella', 'Nutella 榛子可可酱', { energy: 539, protein: 6.3, fat: 30.9, carbs: 57.5, sugars: 56.3, sodium: 42.8 }, { brand: 'Nutella / Ferrero', barcode: '3017620422003', source: 'Open Food Facts · 样例', kind: 'public', portion: { label: '份', amount: 15, unit: 'g' } }),
    ];
    const samples = [['oats', 200, 'breakfast'], ['yogurt', 100, 'breakfast'], ['rice', 150, 'lunch'], ['chicken', 120, 'lunch'], ['broccoli', 150, 'lunch'], ['apple', 150, 'snack']];
    const entries = samples.map(([id, amount, meal], i) => M.makeEntry(foods.find(f => f.id === id), amount, 'g', meal, '2026-10-15', `seed-${i}`));
    return { version: 1, foods, entries, date: '2026-10-15', recent: ['rice', 'chicken', 'broccoli', 'oats', 'yogurt', 'apple'], lastAmounts: Object.fromEntries(entries.map(e => [e.food.id, { amount: e.amount, unit: e.unit }])) };
  }
  function load() { try { const v = JSON.parse(sessionStorage.getItem(storageKey)); return v?.version === 1 && Array.isArray(v.foods) && Array.isArray(v.entries) ? v : seed(); } catch { return seed(); } }
  let state = load();
  const queryParams = new URLSearchParams(location.search);
  let view = { screen: queryParams.get('screen') ?? 'home', meal: 'lunch', query: '', filter: 'all', foodId: 'rice', recordId: null, amount: 100, unit: 'g' };
  let draft = null;
  let draftContext = null;
  let error = '';
  let networkMode = 'online';
  let scanTarget = 'lookup';
  let scanScroll = 0;
  let displayKj = false;
  let toastTimer;
  let undo;
  let navigationDepth = 0;
  function persist() { try { sessionStorage.setItem(storageKey, JSON.stringify(state)); } catch { toast('当前标签页空间不足，操作仍留在本页内存中'); } }
  function toast(message, undoAction = null) {
    clearTimeout(toastTimer); undo = undoAction;
    $('#toast').innerHTML = `<span>${escape(message)}</span>${undoAction ? '<button type="button" id="undo-action">撤销</button>' : '<button type="button" id="dismiss-toast" aria-label="关闭提示">×</button>'}`;
    $('#toast').hidden = false;
    toastTimer = setTimeout(() => { $('#toast').hidden = true; undo = null; }, 8000);
  }
  const foodById = id => state.foods.find(f => f.id === id);
  const currentEntry = () => state.entries.find(e => e.id === view.recordId);
  const currentFood = () => currentEntry()?.food ?? foodById(view.foodId) ?? state.foods[0];
  const dateShort = date => `${Number(date.slice(5, 7))}月${Number(date.slice(8, 10))}日`;
  function changeDate(days) { const d = new Date(`${state.date}T12:00:00`); d.setDate(d.getDate() + days); state.date = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`; persist(); render(); }
  function navigate(next, replace = false) { view = { ...view, ...next }; error = ''; if (!replace) navigationDepth++; (replace ? history.replaceState : history.pushState).call(history, { view: copy(view), depth: navigationDepth }, ''); render(); $('.screen-body')?.scrollTo(0, 0); }
  function back() {
    if (view.screen === 'edit' && draftContext?.dirty && !confirm('食品尚未保存，放弃本次编辑？')) return;
    if (navigationDepth > 0) history.back(); else navigate({ screen: 'home', recordId: null }, true);
  }
  const image = food => food.image ? `<img class="food-image" src="${escape(food.image)}" alt="${escape(food.name)}示意照片">` : `<span class="food-image food-fallback" aria-hidden="true">${icon('bowl')}</span>`;
  const badge = food => food.checked ? `<span class="badge checked">${icon('check')}我已核对</span>` : `<span class="badge">${food.kind === 'mine' ? '我的食品' : '公共数据'}</span>`;
  const basisLabel = food => `每 ${fmt(food.basisAmount)} ${foodUnit(food, food.basisUnit)}`;
  const energyText = kcal => kcal == null ? '—' : fmt(displayKj ? M.kcalToKj(kcal) : kcal, displayKj ? 0 : 1);
  const energyUnit = () => displayKj ? 'kJ' : 'kcal';
  function intakeLabel(food, amount, unit) {
    if (!Number.isFinite(amount)) return '请填写摄入量';
    const main = `${fmt(amount, 2)} ${foodUnit(food, unit)}`;
    if (!food.portion || unit !== 'serving') return main;
    return `${main}（${fmt(M.convertAmount(food, amount, unit, food.portion.unit), 2)} ${unitLabel(food.portion.unit)}）`;
  }
  function portionHint(food) {
    return food.portion ? `1 ${foodUnit(food, 'serving')} = ${fmt(food.portion.amount, 2)} ${unitLabel(food.portion.unit)} · 可按份数或${food.portion.unit === 'g' ? '克数' : '毫升数'}记录` : '未填写每份重量或容量，可在编辑食品资料中补充。';
  }
  const row = entry => {
    const total = M.totals(entry.food, entry.amount, entry.unit);
    return `<div class="food-row"><button type="button" class="row-main" data-action="edit-record" data-id="${entry.id}" aria-label="修改${escape(entry.food.name)}的摄入量">${image(entry.food)}<span class="food-copy"><span class="food-name">${escape(entry.food.name)}</span><span class="food-subtitle">${escape(intakeLabel(entry.food, entry.amount, entry.unit))}</span></span><span class="food-kcal">${energyText(total.energy)}<small>${energyUnit()}</small></span></button></div>`;
  };
  function macroGroup(values, summary = false) {
    return `<div class="${summary ? 'macro-grid' : 'detail-macros'}">${[['protein', '蛋白质'], ['fat', '脂肪'], ['carbs', '碳水']].map(([key, name]) => summary ? `<div class="macro-item ${key}"><div class="macro-title">${name}</div><div class="macro-value">${fmt(values[key])}<small> g</small></div></div>` : `<div><small>${name}</small><strong data-nutrient="${key}">${fmt(values[key])}<small>g</small></strong></div>`).join('')}</div>`;
  }
  function home() {
    const dayEntries = state.entries.filter(e => e.date === state.date);
    const sum = { energy: 0, protein: 0, fat: 0, carbs: 0 };
    for (const e of dayEntries) { const total = M.totals(e.food, e.amount, e.unit); for (const key of Object.keys(sum)) sum[key] += total[key] ?? 0; }
    const date = new Date(`${state.date}T12:00:00`);
    const monday = new Date(date); monday.setDate(date.getDate() - ((date.getDay() + 6) % 7));
    const week = Array.from({ length: 7 }, (_, i) => { const d = new Date(monday); d.setDate(d.getDate() + i); const value = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`; return `<button type="button" data-action="pick-date" data-date="${value}" class="${value === state.date ? 'active' : ''}" aria-label="${dateShort(value)}" aria-pressed="${value === state.date}"><small>${['一', '二', '三', '四', '五', '六', '日'][i]}</small><span>${d.getDate()}</span></button>`; }).join('');
    return `<header class="topbar"><div class="head-copy"><h1>饮食日记</h1><small>把每一餐，记得清楚。</small></div><button class="icon-button" type="button" data-action="date-focus" aria-label="选择日期">${icon('calendar')}</button></header><main class="screen-body"><div class="date-control"><button class="icon-button" type="button" data-action="prev-date" aria-label="前一天">${icon('back')}</button><label class="date-label"><input id="day-input" aria-label="日记日期" type="date" value="${state.date}"></label><button class="icon-button" type="button" data-action="next-date" aria-label="后一天">${icon('next')}</button></div><div class="pad"><div class="week-strip">${week}</div><section class="summary" aria-label="当日营养摘要"><div class="summary-top"><div><p class="eyebrow">已摄入</p><div class="energy-main"><strong id="day-energy">${energyText(sum.energy)}</strong><small>${energyUnit()}</small></div></div><div class="energy-goal">${dayEntries.length} 条记录</div></div>${macroGroup(sum, true)}</section>${Object.entries(meals).map(([key, label]) => { const entries = dayEntries.filter(e => e.meal === key); const kcal = entries.reduce((a, e) => a + (M.totals(e.food, e.amount, e.unit).energy ?? 0), 0); return `<section class="meal-section" aria-label="${label}记录"><details class="meal-details"><summary aria-label="${label}明细"><h2>${label}</h2><span class="meal-total">${energyText(kcal)} <small>${energyUnit()}</small></span>${icon('more')}</summary>${entries.length ? `<div class="food-list">${entries.map(row).join('')}</div>` : `<p class="empty-meal">这餐还没有记录，点击右上角＋添加。</p>`}</details><button class="meal-add" type="button" data-action="add-meal" data-meal="${key}" aria-label="向${label}添加食品">${icon('plus')}</button></section>`; }).join('')}</div></main><nav class="bottom-nav" aria-label="主导航"><button class="active" type="button" data-action="home" aria-current="page"><span class="nav-icon">${icon('book')}</span>日记</button><button type="button" data-action="library"><span class="nav-icon">${icon('bowl')}</span>食品库</button><button type="button" disabled aria-label="营养趋势，本轮原型未展开"><span class="nav-icon">${icon('chart')}</span>营养趋势</button><button type="button" disabled aria-label="设置，本轮原型未展开"><span class="nav-icon">${icon('settings')}</span>设置</button></nav>`;
  }
  function matches(food, q) { return `${food.name} ${food.brand} ${food.barcode ?? ''}`.toLowerCase().includes(q.trim().toLowerCase()); }
  function searchResults() {
    let foods = state.foods.filter(f => (!f.oneOff || state.recent.includes(f.id)) && matches(f, view.query));
    if (networkMode !== 'online') foods = foods.filter(f => f.kind === 'mine' || state.recent.includes(f.id));
    if (view.filter === 'mine') foods = foods.filter(f => f.kind === 'mine' && !f.oneOff);
    if (view.filter === 'favorite') foods = foods.filter(f => f.favorite);
    if (view.filter === 'recent') foods = foods.filter(f => state.recent.includes(f.id));
    const tier = f => f.kind === 'mine' && f.checked ? 0 : f.kind === 'mine' ? 1 : f.favorite ? 2 : state.recent.includes(f.id) ? 3 : 4;
    const recency = f => state.recent.includes(f.id) ? state.recent.indexOf(f.id) : Number.MAX_SAFE_INTEGER;
    foods.sort((a, b) => tier(a) - tier(b) || recency(a) - recency(b));
    const notice = networkMode === 'online' ? '' : `<div class="status-notice" role="status">${networkMode === 'offline' ? '当前离线。仍可搜索我的食品和最近记录。' : '公共来源暂时无法获取，已保留本地结果。'}<br>找不到时，也可以手动创建食品。</div>`;
    return `${notice}<div class="list-label"><span>${view.query ? `“${escape(view.query)}”的搜索结果` : view.filter === 'all' ? '常用与最近食品' : { mine: '我的食品', recent: '最近记录', favorite: '收藏食品' }[view.filter]}</span><span>${foods.length} 项</span></div>${foods.length ? `<div class="search-list">${foods.map(f => `<div class="food-row"><button type="button" class="row-main" data-action="open-food" data-id="${f.id}" aria-label="查看${escape(f.name)}">${image(f)}<span class="food-copy"><span class="food-name">${escape(f.name)}</span>${f.brand ? `<span class="food-subtitle">${escape(f.brand)}</span>` : ''}<span class="source-line">${badge(f)}<span>${f.nutrients.energy == null ? '营养数据缺失' : basisLabel(f)}</span></span></span><span class="food-kcal">${energyText(f.nutrients.energy)}<small>${energyUnit()}</small></span></button><button class="icon-button" type="button" data-action="${view.filter === 'recent' && state.lastAmounts[f.id] ? 'quick-add' : 'open-food'}" data-id="${f.id}" aria-label="${view.filter === 'recent' && state.lastAmounts[f.id] ? '按上次份量添加' : '选择摄入量：'}${escape(f.name)}">${icon('plus')}</button></div>`).join('')}</div>` : `<div class="empty-state">${icon('search')}<h2>没有找到合适的食品</h2><p>可以换个名称，或直接创建自己的食品。<br>不需要等待公共数据库收录。</p><button type="button" class="primary-button" data-action="create">${icon('plus')}创建“${escape(view.query || '新食品')}”</button></div>`}`;
  }
  function search() {
    return `<header class="topbar"><button type="button" class="icon-button" data-action="back" aria-label="返回">${icon('back')}</button><div class="head-copy"><h1>${view.library ? '我的食品库' : `添加到${meals[view.meal]}`}</h1><small>${dateShort(state.date)} · ${view.library ? '自己的食品优先' : '搜索、核对、记录'}</small></div><button type="button" class="text-button" data-action="create">新建</button></header><div class="search-area"><div class="search-box">${icon('search')}<input id="food-search" type="search" aria-label="搜索食品名称或品牌" autocomplete="off" placeholder="搜索食品名称、品牌" value="${escape(view.query)}"><button type="button" class="icon-button" data-action="scan" aria-label="扫描条形码">${icon('scan')}</button></div><div class="filter-row" role="group" aria-label="食品筛选">${[['all', '全部'], ['mine', '我的'], ['recent', '最近'], ['favorite', '收藏']].map(([key, label]) => `<button type="button" class="chip ${view.filter === key ? 'active' : ''}" data-action="filter" data-filter="${key}" aria-pressed="${view.filter === key}">${label}</button>`).join('')}</div></div><main class="screen-body pad"><div id="search-results">${searchResults()}</div></main><footer class="bottom-action"><button type="button" class="secondary-button" data-action="create">${icon('plus')} 没找到？手动创建食品</button></footer>`;
  }
  function unitOptions(food, selected) {
    const options = [[food.basisUnit, foodUnit(food, food.basisUnit)]];
    if (food.basisUnit !== 'serving' && food.portion?.unit === food.basisUnit) options.push(['serving', foodUnit(food, 'serving')]);
    if (food.basisUnit === 'serving' && food.portion) options.push([food.portion.unit, unitLabel(food.portion.unit)]);
    return options.map(([key, label]) => `<option value="${key}" ${key === selected ? 'selected' : ''}>${escape(label)}</option>`).join('');
  }
  function consumed(food) {
    let total; try { total = M.totals(food, Number(view.amount), view.unit); } catch { total = M.nutrients(); }
    return `<p>本次摄入 · ${escape(intakeLabel(food, Number(view.amount), view.unit))}</p><div class="detail-energy"><strong id="intake-energy">${energyText(total.energy)}</strong><small>${energyUnit()}</small></div>${macroGroup(total)}`;
  }
  function detail() {
    const food = currentFood();
    const recorded = !!currentEntry();
    const missing = food.nutrients.energy == null;
    return `<header class="topbar"><button type="button" class="icon-button" data-action="back" aria-label="返回">${icon('back')}</button><div class="head-copy"><h1>${recorded ? '修改记录' : '食品详情'}</h1><small class="target-context">${dateShort(state.date)} · ${recorded ? meals[view.meal] : `<select id="target-meal" aria-label="记录餐次">${Object.entries(meals).map(([key, label]) => `<option value="${key}" ${view.meal === key ? 'selected' : ''}>${escape(label)}</option>`).join('')}</select>`}</small></div><button class="icon-button" type="button" data-action="favorite" aria-label="${foodById(food.id)?.favorite ? '取消收藏' : '收藏食品'}" aria-pressed="${!!foodById(food.id)?.favorite}">${icon('star', !!foodById(food.id)?.favorite)}</button></header><main class="screen-body pad"><div class="food-hero">${image(food)}<div class="food-copy"><h2>${escape(food.name)}</h2><p class="brand">${escape(food.brand || '未填写品牌')}</p>${badge(food)}</div></div><section class="detail-block"><div class="basis-title"><span>基准 · ${escape(basisLabel(food))} / ${energyText(food.nutrients.energy)} ${energyUnit()}</span><button type="button" class="text-button" data-action="toggle-energy">${energyUnit()} ⇄</button></div><div class="consumed-summary" id="consumed" aria-live="polite">${consumed(food)}</div></section>${missing ? '<div class="status-notice">该食品缺少营养信息，暂不能计算本次摄入。可以对照包装标签补充，另存为自己的版本。</div>' : ''}<details class="source-details"><summary><span>来源与个人核对</span>${icon('more')}</summary><p>来源：${escape(food.source)}${food.origin ? `<br>原始来源：${escape(food.origin)}` : ''}${food.barcode ? `<br>条码：${escape(food.barcode)}` : ''}<br>${food.checked ? `个人核对：${escape(food.evidence)}<br>核对日期：${escape(food.checkedAt)}` : '尚未标记个人核对。收藏或来自公共数据库，都不等于营养数据已核验。'}<br>本原型数值用于演示操作，不作为真实营养依据。</p></details><details class="source-details"><summary><span>更多营养素</span>${icon('more')}</summary><table class="nutrient-table"><caption class="field-help">${escape(basisLabel(food))} · 未提供的数据以“—”显示</caption><tbody>${M.nutrientFields.slice(4).map(([key, label, unit]) => `<tr><td>${label}</td><td>${fmt(food.nutrients[key])} ${unit}</td></tr>`).join('')}</tbody></table></details><button type="button" class="text-button" data-action="revise">${icon('edit')} ${food.kind === 'mine' ? '编辑食品资料' : '修正数据，另存为我的食品'}</button>${recorded ? `<div class="record-actions"><button type="button" class="secondary-button" data-action="repeat">${icon('copy')}再记一份</button><button type="button" class="secondary-button danger-button" data-action="delete">${icon('trash')}删除记录</button></div>` : ''}<p class="field-help">${recorded ? '改量只影响这条记录；食品资料和其他历史记录保持原值。' : '重量与容量只按食品已提供的依据换算。'}${food.image && !food.image.startsWith('data:') ? '<br>食品示意照片：Unsplash，署名见设计说明。' : ''}</p></main><footer class="portion-dock"><p class="portion-hint">${food.packageAmount != null ? `包装 ${fmt(food.packageAmount)} ${unitLabel(food.basisUnit)} · ` : ''}${escape(portionHint(food))}</p><div class="quantity-row"><label class="field">摄入量<input id="quantity" type="number" inputmode="decimal" step="any" min="0.01" value="${view.amount}" aria-label="摄入量"></label><label class="field">计量单位<select id="quantity-unit" aria-label="计量单位">${unitOptions(food, view.unit)}</select></label></div><button type="button" class="primary-button" id="save-intake" data-action="save-intake" ${missing ? 'disabled' : ''}><span>${recorded ? '保存修改' : `添加到${meals[view.meal]}`}</span><strong id="button-energy">${energyText((() => { try { return M.totals(food, Number(view.amount), view.unit).energy; } catch { return null; } })())} ${energyUnit()}</strong></button></footer>`;
  }
  function startDraft(original = null) {
    draft = original ? (original.kind === 'mine' ? copy(foodById(original.id) ?? original) : M.personalCopy(original, uid())) : { id: uid(), name: view.query.trim(), brand: '', image: null, kind: 'mine', source: '我的食品', basisAmount: 100, basisUnit: 'g', nutrients: M.nutrients(), checked: false, evidence: '', evidenceType: 'none', favorite: false, barcode: '' };
    draftContext = { from: copy(view), editExisting: original?.kind === 'mine', mode: 'simple', energyUnit: 'kcal', saveForLater: true, dirty: false };
    navigate({ screen: 'edit', recordId: null });
  }
  function nutritionField(key, label, unit) {
    const value = draft.nutrients[key];
    return `<label class="field">${key === 'carbs' ? '碳水' : label}（${unit}）<input type="number" inputmode="decimal" min="0" step="any" data-nutrient-input="${key}" aria-label="${label}" value="${value == null ? '' : value}" placeholder="未知可留空"></label>`;
  }
  function estimate() {
    const comparison = M.energyComparison(draft);
    return comparison ? `标示热量 ${fmt(comparison.declared)} kcal · 三大营养素估算 ${fmt(comparison.estimated)} kcal，差值 ${fmt(Math.abs(comparison.gap))} kcal。<br>纤维、糖醇、标签口径和四舍五入均可能产生差异；保存时保留你的标示值，不自动覆盖。` : '三大营养素未填齐，暂不判断热量一致性。留空代表未知，不会自动填写为 0。';
  }
  function edit() {
    if (!draft) { draft = { id: uid(), name: '', brand: '', kind: 'mine', source: '我的食品', basisAmount: 100, basisUnit: 'g', nutrients: M.nutrients(), checked: false, evidenceType: 'none', evidence: '' }; draftContext = { from: { ...view, screen: 'search' }, mode: 'simple', energyUnit: 'kcal', saveForLater: true }; }
    const advanced = draftContext.mode === 'advanced';
    const displayedEnergy = draft.nutrients.energy == null ? '' : Number((draftContext.energyUnit === 'kJ' ? M.kcalToKj(draft.nutrients.energy) : draft.nutrients.energy).toFixed(4));
    return `<header class="topbar"><button type="button" class="icon-button" data-action="back" aria-label="返回">${icon('back')}</button><div class="head-copy"><h1>${draftContext.editExisting ? '编辑食品' : draft.derivedFrom ? '另存修正版' : '创建食品'}</h1><small>${draft.derivedFrom ? '保留原始来源，不修改公共条目' : '保存你自己的食品资料'}</small></div></header><main class="screen-body pad"><div class="form-mode" role="group" aria-label="录入模式"><button type="button" data-action="edit-mode" data-mode="simple" class="${!advanced ? 'active' : ''}" aria-pressed="${!advanced}">简单模式</button><button type="button" data-action="edit-mode" data-mode="advanced" class="${advanced ? 'active' : ''}" aria-pressed="${advanced}">高级模式</button></div><form id="food-form"><div class="edit-photo">${image(draft)}<label class="photo-picker">${icon('camera')}<span>添加食品照片<input type="file" class="visually-hidden" id="food-photo" accept="image/jpeg,image/png,image/webp" aria-label="选择食品照片"></span></label></div><section class="form-section"><label class="field">食品名称<input type="text" data-draft="name" aria-label="食品名称" value="${escape(draft.name)}" placeholder="例如：家常鸡蛋羹" required maxlength="100"></label><label class="field">品牌（选填）<input type="text" data-draft="brand" aria-label="品牌" value="${escape(draft.brand)}" placeholder="无品牌可留空" maxlength="100"></label><label class="field barcode-field">条形码（选填）<span class="barcode-input"><input type="text" inputmode="numeric" data-draft="barcode" aria-label="食品条码" value="${escape(draft.barcode)}" placeholder="可输入或扫码填写"><button type="button" class="text-button" data-action="scan-into-field" aria-label="扫描并填写食品条码">${icon('scan')}扫码</button></span></label><section class="form-section specifications" aria-label="包装与营养基准"><div class="spec-heading"><h2>包装与营养基准</h2><label class="field unit-field">计量单位<select data-draft="basisUnit" aria-label="营养基准单位">${[['g', 'g（重量）'], ['ml', 'mL（容量）']].map(([unit, label]) => `<option value="${unit}" ${draft.basisUnit === unit ? 'selected' : ''}>${label}</option>`).join('')}</select></label></div><div class="form-grid macro-inputs"><label class="field">包装大小（${unitLabel(draft.basisUnit)}）<input type="number" inputmode="decimal" data-draft="packageAmount" aria-label="包装大小" value="${draft.packageAmount ?? ''}" min="0.01" step="any" placeholder="可留空"></label><label class="field">单份份量（${unitLabel(draft.basisUnit)}）<input type="number" inputmode="decimal" data-portion="amount" aria-label="单份份量" value="${draft.portion?.amount ?? ''}" min="0.01" step="any" placeholder="可留空"></label><label class="field">营养基准（${unitLabel(draft.basisUnit)}）<input type="number" inputmode="decimal" data-draft="basisAmount" aria-label="营养基准数量" value="${draft.basisAmount}" min="0.01" step="any" required></label></div><p class="field-help" id="basis-help">下方热量和营养值按 ${escape(basisLabel(draft))} 填写；包装大小、单份份量独立保存，不会相互覆盖。</p></section><label class="field">热量<div class="energy-input"><input type="number" inputmode="decimal" aria-label="热量" id="draft-energy" value="${displayedEnergy}" min="0" step="any" required placeholder="按标签填写"><select id="edit-energy-unit" aria-label="热量单位"><option ${draftContext.energyUnit === 'kcal' ? 'selected' : ''}>kcal</option><option ${draftContext.energyUnit === 'kJ' ? 'selected' : ''}>kJ</option></select></div></label><div class="form-grid macro-inputs">${M.nutrientFields.slice(1, 4).map(([key, label, unit]) => nutritionField(key, label, unit)).join('')}</div></section>${advanced ? `<section class="form-section"><h2>糖、纤维与脂肪</h2><div class="form-grid">${M.nutrientFields.filter(([key]) => ['sugars', 'fiber', 'satFat', 'monoFat', 'polyFat', 'transFat', 'cholesterol'].includes(key)).map(([key, label, unit]) => nutritionField(key, label, unit)).join('')}</div><h2>矿物质</h2><div class="form-grid">${M.nutrientFields.filter(([key]) => ['sodium', 'calcium', 'iron', 'potassium', 'magnesium', 'zinc', 'phosphorus'].includes(key)).map(([key, label, unit]) => nutritionField(key, label, unit)).join('')}</div><h2>维生素</h2><div class="form-grid">${M.nutrientFields.filter(([key]) => key.startsWith('vitamin') || key === 'niacin').map(([key, label, unit]) => nutritionField(key, label, unit)).join('')}</div></section>` : ''}<div class="nutrition-estimate" id="nutrition-estimate">${estimate()}</div><details class="source-details" ${draft.checked ? 'open' : ''}><summary><span>来源与个人核对（选填）</span>${icon('more')}</summary><div class="verification-fields"><label class="field">数据依据<select data-draft="evidenceType" aria-label="数据依据">${[['none', '未提供来源'], ['label', '食品包装标签'], ['reference', '公开参考数据库 / 食谱'], ['other', '其他可说明来源']].map(([key, label]) => `<option value="${key}" ${draft.evidenceType === key ? 'selected' : ''}>${escape(label)}</option>`).join('')}</select></label><label class="field">来源或核对说明<textarea data-draft="evidence" aria-label="来源或核对说明" rows="2" placeholder="例如标签版本、数据库条目或食谱依据">${escape(draft.evidence)}</textarea></label><label class="check-line"><input type="checkbox" id="checked-food" ${draft.checked ? 'checked' : ''}><span>我已对照来源核对营养数据<br><small>这是个人核对记录，不代表第三方认证。</small></span></label></div></details>${!draftContext.editExisting ? `<label class="check-line"><input id="save-template" type="checkbox" ${draftContext.saveForLater ? 'checked' : ''}><span>保存到我的食品，下次搜索优先显示</span></label>` : ''}<div id="form-error" class="form-error" role="alert" ${error ? '' : 'hidden'}>${escape(error)}</div></form></main><footer class="bottom-action"><button type="submit" form="food-form" class="primary-button">${draftContext.editExisting || view.library ? '保存食品资料' : '保存并继续记录'}</button></footer>`;
  }
  function render() {
    $('#app').innerHTML = ({ home, search, detail, edit }[view.screen] ?? home)();
    document.querySelectorAll('[data-screen]').forEach(b => b.setAttribute('aria-current', b.dataset.screen === view.screen ? 'page' : 'false'));
    $('#toast').hidden = true;
  }
  function openFood(id, recordId = null) {
    const entry = state.entries.find(e => e.id === recordId);
    const food = entry?.food ?? foodById(id);
    if (!food) return;
    const byServing = food.basisUnit === 'serving' || (food.portion?.unit === food.basisUnit && food.portion.amount > 0);
    navigate({ screen: 'detail', foodId: food.id, recordId, meal: entry?.meal ?? view.meal, amount: entry?.amount ?? (byServing ? 1 : 100), unit: entry?.unit ?? (byServing ? 'serving' : food.basisUnit) });
  }
  function addEntry(food, amount, unit, meal = view.meal) {
    const entry = M.makeEntry(food, Number(amount), unit, meal, state.date, uid());
    state.entries.push(entry);
    state.recent = [food.id, ...state.recent.filter(id => id !== food.id)];
    state.lastAmounts[food.id] = { amount: Number(amount), unit };
    persist();
    return entry;
  }
  function undoAdd(id) { state.entries = state.entries.filter(e => e.id !== id); persist(); render(); toast('已撤销添加'); }
  function updateConsumption() {
    const food = currentFood();
    $('#consumed').innerHTML = consumed(food);
    let total; try { total = M.totals(food, Number(view.amount), view.unit); } catch { total = M.nutrients(); }
    $('#button-energy').textContent = `${energyText(total.energy)} ${energyUnit()}`;
    $('#save-intake').disabled = food.nutrients.energy == null || !Number.isFinite(Number(view.amount)) || Number(view.amount) <= 0;
  }
  function saveFood(event) {
    event.preventDefault();
    error = M.validateFood(draft);
    if (!error && draft.barcode && !/^\d{8,14}$/.test(draft.barcode)) error = '条码应为 8–14 位数字；没有条码可以留空';
    if (error) { $('#form-error').textContent = error; $('#form-error').hidden = false; $('#form-error').scrollIntoView({ block: 'nearest' }); return; }
    draft.name = draft.name.trim(); draft.brand = draft.brand.trim();
    if (draft.servingLabel) draft.servingLabel = draft.servingLabel.trim();
    if (draft.portion) draft.portion.label = draft.portion.label?.trim() || '份';
    draft.checkedAt = draft.checked ? '2026-10-15' : null;
    // Keep the per-serving physical amount even when nutrition is entered per serving.
    const saved = copy(draft);
    if (draftContext.saveForLater || draftContext.editExisting || view.library) {
      const index = state.foods.findIndex(f => f.id === saved.id);
      if (index < 0) state.foods.unshift(saved); else state.foods[index] = saved;
    } else {
      // A one-off food remains reachable by this demo's detail route, but search excludes it.
      saved.oneOff = true; state.foods.push(saved);
    }
    persist(); draftContext.dirty = false;
    if (draftContext.editExisting || view.library) { navigate({ screen: 'search', query: saved.name, filter: 'mine', recordId: null }); toast('食品资料已保存，历史记录保持原值'); }
    else openFood(saved.id);
  }
  $('#app').addEventListener('click', event => {
    const button = event.target.closest('[data-action]'); if (!button) return;
    const action = button.dataset.action;
    if (action === 'back') back();
    if (action === 'home') navigate({ screen: 'home', recordId: null });
    if (action === 'library') navigate({ screen: 'search', library: true, filter: 'mine', query: '', recordId: null });
    if (action === 'date-focus') { try { $('#day-input').showPicker(); } catch { $('#day-input').focus(); } }
    if (action === 'prev-date') changeDate(-1);
    if (action === 'next-date') changeDate(1);
    if (action === 'pick-date') { state.date = button.dataset.date; persist(); render(); }
    if (action === 'add-meal') navigate({ screen: 'search', meal: button.dataset.meal, filter: 'all', query: '', library: false, recordId: null });
    if (action === 'filter') { view.filter = button.dataset.filter; render(); }
    if (action === 'open-food') openFood(button.dataset.id);
    if (action === 'edit-record') openFood(null, button.dataset.id);
    if (action === 'create') startDraft();
    if (action === 'revise') startDraft(currentFood());
    if (action === 'edit-mode') { draftContext.mode = button.dataset.mode; const scroll = $('.screen-body').scrollTop; render(); $('.screen-body').scrollTop = scroll; }
    if (action === 'favorite') { const food = foodById(currentFood().id); if (food) { food.favorite = !food.favorite; persist(); render(); toast(food.favorite ? '已收藏；个人核对状态没有改变' : '已取消收藏'); } }
    if (action === 'toggle-energy') { displayKj = !displayKj; const scroll = $('.screen-body').scrollTop; render(); $('.screen-body').scrollTop = scroll; }
    if (action === 'quick-add') { const food = foodById(button.dataset.id); const last = state.lastAmounts[food.id]; const entry = addEntry(food, last.amount, last.unit); toast(`${food.name}已按上次 ${last.amount} ${foodUnit(food, last.unit)} 添加`, () => undoAdd(entry.id)); }
    if (action === 'save-intake') {
      try {
        if (currentEntry()) {
          const entry = currentEntry(); const before = copy(entry);
          M.totals(entry.food, Number(view.amount), view.unit);
          entry.amount = Number(view.amount); entry.unit = view.unit; persist(); navigate({ screen: 'home', recordId: null });
          toast('已修改这条记录', () => { const i = state.entries.findIndex(e => e.id === before.id); if (i >= 0) state.entries[i] = before; persist(); render(); toast('已撤销修改'); });
        } else {
          const entry = addEntry(currentFood(), view.amount, view.unit); navigate({ screen: 'home', recordId: null }); toast(`已添加到${dateShort(state.date)}·${meals[view.meal]}`, () => undoAdd(entry.id));
        }
      } catch (e) { toast(e.message); }
    }
    if (action === 'repeat') { const old = currentEntry(); const entry = addEntry(old.food, old.amount, old.unit, old.meal); navigate({ screen: 'home', recordId: null }); toast('已再记一份', () => undoAdd(entry.id)); }
    if (action === 'delete') { const old = copy(currentEntry()); const index = state.entries.findIndex(e => e.id === old.id); state.entries.splice(index, 1); persist(); navigate({ screen: 'home', recordId: null }); toast('已删除记录', () => { if (!state.entries.some(e => e.id === old.id)) state.entries.splice(index, 0, old); persist(); render(); toast('已恢复记录'); }); }
    if (action === 'scan') openScanner('lookup');
    if (action === 'scan-into-field') openScanner('edit');
  });
  $('#app').addEventListener('submit', event => { if (event.target.id === 'food-form') saveFood(event); });
  $('#app').addEventListener('input', event => {
    const el = event.target;
    if (el.id === 'food-search') { view.query = el.value; $('#search-results').innerHTML = searchResults(); }
    if (el.id === 'quantity') { view.amount = el.value === '' ? NaN : Number(el.value); updateConsumption(); }
    if (el.dataset.draft && el.dataset.draft !== 'basisUnit') { const key = el.dataset.draft; draft[key] = ['basisAmount', 'packageAmount'].includes(key) ? (el.value === '' ? null : Number(el.value)) : el.value; draftContext.dirty = true; }
    if (el.dataset.nutrientInput) { draft.nutrients[el.dataset.nutrientInput] = el.value.trim() === '' ? null : Number(el.value); draftContext.dirty = true; }
    if (el.id === 'draft-energy') { draft.nutrients.energy = el.value.trim() === '' ? null : (draftContext.energyUnit === 'kJ' ? M.kjToKcal(Number(el.value)) : Number(el.value)); draftContext.dirty = true; }
    if (el.dataset.portion === 'amount') { draft.portion = el.value === '' ? null : { label: draft.portion?.label || '份', amount: Number(el.value), unit: draft.basisUnit }; draftContext.dirty = true; }
    if (view.screen === 'edit') { $('#nutrition-estimate').innerHTML = estimate(); $('#basis-help').textContent = `下方热量和营养值按 ${basisLabel(draft)} 填写；包装大小、单份份量独立保存，不会相互覆盖。`; }
  });
  $('#app').addEventListener('change', event => {
    const el = event.target;
    if (el.id === 'target-meal') { view.meal = el.value; render(); }
    if (el.id === 'day-input') { if (el.value) { state.date = el.value; persist(); render(); } }
    if (el.id === 'quantity-unit') { const food = currentFood(); view.amount = M.convertAmount(food, Number(view.amount) || 0, view.unit, el.value); view.unit = el.value; render(); }
    if (el.id === 'edit-energy-unit') { draftContext.energyUnit = el.value; const scroll = $('.screen-body').scrollTop; render(); $('.screen-body').scrollTop = scroll; }
    if (el.dataset.draft === 'basisUnit') {
      draft.basisUnit = el.value;
      if (draft.portion) draft.portion.unit = el.value;
      draftContext.dirty = true; const scroll = $('.screen-body').scrollTop; render(); $('.screen-body').scrollTop = scroll;
      toast('已切换计量单位，请核对包装、单份、营养基准和营养数值；不会自动重算。');
    }
    if (el.id === 'checked-food') { draft.checked = el.checked; draftContext.dirty = true; }
    if (el.id === 'save-template') draftContext.saveForLater = el.checked;
    if (el.id === 'food-photo' && el.files[0]) {
      const file = el.files[0];
      if (!['image/jpeg', 'image/png', 'image/webp'].includes(file.type) || file.size > 2 * 1024 * 1024) { toast('请选择 2 MB 以内的 JPG、PNG 或 WebP 图片'); return; }
      const reader = new FileReader(); reader.onload = () => { draft.image = reader.result; draftContext.dirty = true; const scroll = $('.screen-body').scrollTop; render(); $('.screen-body').scrollTop = scroll; }; reader.readAsDataURL(file);
    }
  });
  $('#toast').addEventListener('click', event => { if (event.target.id === 'undo-action' && undo) { const action = undo; undo = null; action(); } else if (event.target.id === 'dismiss-toast') $('#toast').hidden = true; });
  document.querySelectorAll('[data-screen]').forEach(button => button.addEventListener('click', () => {
    if (button.dataset.screen === 'edit') { view.library = false; view.query = ''; startDraft(); }
    else if (button.dataset.screen === 'detail') { view.meal = 'lunch'; view.library = false; openFood('rice'); }
    else navigate({ screen: button.dataset.screen, library: false, query: '', filter: 'all', recordId: null });
  }));
  document.querySelectorAll('[data-style]').forEach(button => { if (button.tagName !== 'BUTTON') return; button.addEventListener('click', () => { $('#phone').dataset.style = button.dataset.style; $('#preview-caption').textContent = button.dataset.style === 'warm' ? '暖白 · 柔和' : '青绿 · 清晰'; document.querySelectorAll('#style-options button').forEach(b => b.setAttribute('aria-pressed', b === button)); }); });
  $('#theme-toggle').addEventListener('click', () => { const dark = $('#phone').dataset.theme !== 'dark'; $('#phone').dataset.theme = dark ? 'dark' : 'light'; $('#theme-toggle').setAttribute('aria-pressed', dark); $('#theme-toggle').textContent = dark ? '浅色模式' : '深色模式'; });
  $('#text-toggle').addEventListener('click', () => { $('#phone').classList.toggle('large-text'); $('#text-toggle').setAttribute('aria-pressed', $('#phone').classList.contains('large-text')); });
  $('#network-mode').addEventListener('change', event => { networkMode = event.target.value; if (view.screen !== 'search') navigate({ screen: 'search', query: '', filter: 'all', recordId: null }); else render(); });
  $('#reset-demo').addEventListener('click', () => { state = seed(); draft = null; persist(); navigate({ screen: 'home', recordId: null, query: '', library: false }, true); toast('示例数据已重置'); });
  $('#close-scanner').addEventListener('click', () => $('#scanner').close());
  function openScanner(target) {
    scanTarget = target; scanScroll = $('.screen-body')?.scrollTop || 0;
    $('#barcode-input').value = target === 'edit' ? draft.barcode || '' : '';
    $('#barcode-input').setCustomValidity('');
    $('#scanner-title').textContent = target === 'edit' ? '扫描并填写条码' : '扫描条形码';
    $('#barcode-form button').textContent = target === 'edit' ? '填入条形码' : '查找食品';
    $('.scanner-note').textContent = target === 'edit' ? '识别后自动返回并填写数字，不修改已填食品资料。这里用样例模拟识别，不调用相机。' : '这是扫码交互演示，不调用相机。输入条码或选择下面的样例。';
    $('#scanner').dataset.theme = $('#phone').dataset.theme; $('#scanner').showModal();
  }
  function scanBarcode(code) {
    $('#scanner').close();
    if (scanTarget === 'edit') { draft.barcode = code; draftContext.dirty = true; render(); $('.screen-body').scrollTop = scanScroll; return; }
    const food = state.foods.find(f => f.kind === 'mine' && f.barcode === code) ?? state.foods.find(f => f.barcode === code);
    if (food) openFood(food.id); else { view.query = ''; startDraft(); draft.barcode = code; render(); toast('没有找到该条码，可以手动补充食品'); }
  }
  $('#barcode-form').addEventListener('submit', event => { event.preventDefault(); const code = $('#barcode-input').value.trim(); if (!/^\d{8,14}$/.test(code)) { $('#barcode-input').setCustomValidity('请输入 8–14 位数字'); $('#barcode-input').reportValidity(); return; } scanBarcode(code); });
  $('#barcode-input').addEventListener('input', () => $('#barcode-input').setCustomValidity(''));
  document.querySelectorAll('[data-barcode]').forEach(button => button.addEventListener('click', () => scanBarcode(button.dataset.barcode)));
  addEventListener('popstate', event => { if (event.state?.view) { view = event.state.view; navigationDepth = event.state.depth ?? 0; render(); } });
  if (queryParams.get('standalone') === '1') document.body.classList.add('standalone');
  if (queryParams.get('style') === 'warm') $('#phone').dataset.style = 'warm';
  if (queryParams.get('theme') === 'dark') $('#theme-toggle').click();
  if (view.screen === 'edit') edit();
  history.replaceState({ view: copy(view), depth: 0 }, '');
  render();
})();
