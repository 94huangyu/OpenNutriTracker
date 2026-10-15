const { test } = require('node:test');
const assert = require('node:assert/strict');
const M = require('./model.js');
const food = { id: 'rice', name: '熟糙米饭', basisAmount: 100, basisUnit: 'g', kind: 'reference', source: '参考库示例', nutrients: M.nutrients({ energy: 123, protein: 3, fat: 1, carbs: 26, zinc: 0.6, vitaminB12: 0 }), portion: { unit: 'g', amount: 150, label: '碗' } };
test('150 g and one 150 g portion use the same nutrition basis', () => {
  assert.equal(M.totals(food, 150, 'g').energy, 184.5);
  assert.deepEqual(M.totals(food, 150, 'g'), M.totals(food, 1, 'serving'));
});
test('60 g package, 15 g serving, 15 g nutrient basis stay independent', () => {
  const chips = { ...food, packageAmount: 60, basisAmount: 15, portion: { label: '份', amount: 15, unit: 'g' }, nutrients: M.nutrients({ energy: 80 }) };
  assert.equal(M.totals(chips, 1, 'serving').energy, 80);
  assert.equal(M.totals(chips, 2, 'serving').energy, 160);
  assert.equal(M.totals(chips, 30, 'g').energy, 160);
  assert.equal(M.totals(chips, 60, 'g').energy, 320);
  chips.packageAmount = 120;
  assert.equal(M.totals(chips, 2, 'serving').energy, 160);
});
test('200 g package, 50 g serving, 100 g nutrient basis scale only intake over nutrient basis', () => {
  const chips = { ...food, packageAmount: 200, basisAmount: 100, portion: { label: '份', amount: 50, unit: 'g' }, nutrients: M.nutrients({ energy: 400 }) };
  assert.equal(M.totals(chips, 1, 'serving').energy, 200);
  assert.equal(M.totals(chips, 2, 'serving').energy, 400);
  assert.equal(M.totals(chips, 100, 'g').energy, 400);
  assert.equal(M.convertAmount(chips, 2, 'serving', 'g'), 100);
});
test('package metadata accepts unknown but rejects invalid sizes', () => {
  assert.equal(M.validateFood({ ...food, packageAmount: null }), null);
  for (const packageAmount of [0, -1, Infinity, NaN]) assert.match(M.validateFood({ ...food, packageAmount }), /包装大小/);
});
test('100 mL data stays in mL; absent density never permits grams', () => {
  const milk = { ...food, basisUnit: 'ml', portion: { unit: 'ml', amount: 250 } };
  assert.equal(M.totals(milk, 250, 'ml').energy, 307.5);
  assert.throws(() => M.totals(milk, 250, 'g'), /换算依据/);
});
test('per-portion data without weight can be logged in portions only', () => {
  const portion = { ...food, basisAmount: 1, basisUnit: 'serving', portion: null };
  assert.equal(M.totals(portion, 2, 'serving').energy, 246);
  assert.throws(() => M.totals(portion, 100, 'g'));
});
test('per-serving nutrition with editable 150 g weight accepts half and one-and-a-half servings or grams', () => {
  const portion = { ...food, basisAmount: 1, basisUnit: 'serving', portion: { label: '份', amount: 150, unit: 'g' } };
  for (const servings of [.5, 1.5]) {
    assert.deepEqual(M.totals(portion, servings, 'serving'), M.totals(portion, servings * 150, 'g'));
    assert.equal(M.convertAmount(portion, servings, 'serving', 'g'), servings * 150);
    assert.equal(M.convertAmount(portion, servings * 150, 'g', 'serving'), servings);
  }
});
test('per-serving mL conversion respects nutrition basis of two servings and does not guess density', () => {
  const portion = { ...food, basisAmount: 2, basisUnit: 'serving', portion: { label: '盒', amount: 250, unit: 'ml' } };
  assert.equal(M.totals(portion, 250, 'ml').energy, 61.5);
  assert.deepEqual(M.totals(portion, 1.5, 'serving'), M.totals(portion, 375, 'ml'));
  assert.throws(() => M.convertAmount(portion, 375, 'ml', 'g'), /换算依据/);
});
test('template portion weight edits do not change recorded serving snapshots', () => {
  const template = { ...structuredClone(food), basisUnit: 'serving', basisAmount: 1 };
  const entry = M.makeEntry(template, 75, 'g', 'lunch', '2026-10-15', 'half');
  template.portion.amount = 200;
  assert.equal(M.totals(entry.food, entry.amount, entry.unit).energy, 61.5);
  assert.equal(M.convertAmount(entry.food, entry.amount, 'g', 'serving'), .5);
});
test('invalid portion mappings cannot be saved or converted', () => {
  for (const amount of [0, -1, Infinity, NaN]) {
    const invalid = { ...food, basisUnit: 'serving', portion: { label: '份', amount, unit: 'g' } };
    assert.match(M.validateFood(invalid), /每份重量/);
    assert.throws(() => M.convertAmount(invalid, 1, 'serving', 'g'));
  }
});
test('unknown nutrients remain null while a known zero remains zero', () => {
  const result = M.totals(food, 150, 'g');
  assert.equal(result.sodium, null);
  assert.equal(result.vitaminB12, 0);
});
test('partial macros produce no energy-consistency judgment', () => {
  const partial = { ...food, nutrients: M.nutrients({ energy: 123, protein: 3 }) };
  assert.equal(M.energyComparison(partial), null);
});
test('energy estimate never overwrites declared energy', () => {
  const before = structuredClone(food);
  assert.equal(M.energyComparison(food).estimated, 125);
  assert.deepEqual(food, before);
});
test('kcal/kJ round trip preserves internal value', () => {
  assert.ok(Math.abs(M.kjToKcal(M.kcalToKj(123)) - 123) < 1e-10);
});
test('personal revision preserves all 24 nutrients and origin but resets verification', () => {
  const original = { ...food, checked: true, evidence: 'old label', checkedAt: '2026-10-14' };
  const copy = M.personalCopy(original, 'mine-rice');
  assert.equal(M.nutrientFields.length, 24);
  assert.deepEqual(copy.nutrients, original.nutrients);
  assert.equal(copy.checked, false);
  assert.equal(copy.derivedFrom, 'rice');
  assert.equal(copy.origin, original.source);
  copy.nutrients.zinc = 2;
  assert.equal(original.nutrients.zinc, 0.6);
});
test('saved diary snapshot is independent from later food-template edits', () => {
  const template = structuredClone(food);
  const entry = M.makeEntry(template, 150, 'g', 'lunch', '2026-10-15', 'entry-1');
  template.nutrients.energy = 900;
  assert.equal(M.totals(entry.food, entry.amount, entry.unit).energy, 184.5);
});
test('no personal checked status without evidence; favorite alone confers no checked status', () => {
  assert.match(M.validateFood({ ...food, checked: true, evidence: '' }), /核对依据/);
  assert.equal(M.validateFood({ ...food, favorite: true, checked: false }), null);
});
test('invalid intake or basis cannot create non-finite nutrition', () => {
  for (const amount of [NaN, Infinity, -1]) assert.throws(() => M.totals(food, amount, 'g'));
  assert.throws(() => M.makeEntry(food, 0, 'g', 'lunch', '2026-10-15', 'bad'));
  assert.throws(() => M.totals({ ...food, basisAmount: 0 }, 150, 'g'));
});
