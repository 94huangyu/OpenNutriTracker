const { test } = require('node:test');
const assert = require('node:assert/strict');
const M = require('./model.js');
const food = { id: 'rice', name: '熟糙米饭', basisAmount: 100, basisUnit: 'g', kind: 'reference', source: '参考库示例', nutrients: M.nutrients({ energy: 123, protein: 3, fat: 1, carbs: 26, zinc: 0.6, vitaminB12: 0 }), portion: { unit: 'g', amount: 150, label: '碗' } };
test('150 g and one 150 g portion use the same nutrition basis', () => {
  assert.equal(M.totals(food, 150, 'g').energy, 184.5);
  assert.deepEqual(M.totals(food, 150, 'g'), M.totals(food, 1, 'serving'));
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
