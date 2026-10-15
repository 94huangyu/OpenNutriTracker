'use strict';

// Design-prototype arithmetic only. The production Flutter calculations stay untouched.
(function (root) {
  const nutrientFields = [
    ['energy', '热量', 'kcal'], ['protein', '蛋白质', 'g'],
    ['fat', '脂肪', 'g'], ['carbs', '碳水化合物', 'g'],
    ['sugars', '糖', 'g'], ['fiber', '膳食纤维', 'g'],
    ['satFat', '饱和脂肪', 'g'], ['sodium', '钠', 'mg'],
    ['calcium', '钙', 'mg'], ['iron', '铁', 'mg'],
    ['potassium', '钾', 'mg'], ['magnesium', '镁', 'mg'],
    ['zinc', '锌', 'mg'], ['phosphorus', '磷', 'mg'],
    ['vitaminA', '维生素 A', 'µg RAE'], ['vitaminC', '维生素 C', 'mg'],
    ['vitaminD', '维生素 D', 'µg'], ['vitaminB6', '维生素 B6', 'mg'],
    ['vitaminB12', '维生素 B12', 'µg'], ['niacin', '烟酸', 'mg'],
    ['cholesterol', '胆固醇', 'mg'], ['monoFat', '单不饱和脂肪', 'g'],
    ['polyFat', '多不饱和脂肪', 'g'], ['transFat', '反式脂肪', 'g'],
  ];
  function nutrients(values = {}) {
    return Object.fromEntries(nutrientFields.map(([key]) => [key, values[key] ?? null]));
  }
  function toBase(food, amount, unit) {
    if (!Number.isFinite(amount) || amount < 0) throw new Error('摄入量需要是非负数');
    if (unit === food.basisUnit) return amount;
    if (unit === 'serving' && food.portion?.unit === food.basisUnit && Number.isFinite(food.portion.amount) && food.portion.amount > 0) {
      return amount * food.portion.amount;
    }
    if (food.basisUnit === 'serving' && unit === food.portion?.unit && Number.isFinite(food.portion.amount) && food.portion.amount > 0) {
      return amount / food.portion.amount;
    }
    throw new Error('没有重量与容量的换算依据');
  }
  function convertAmount(food, amount, from, to) {
    const base = toBase(food, amount, from);
    const targetFactor = toBase(food, 1, to);
    if (from === to) return amount;
    if (from === 'serving') return amount * food.portion.amount;
    if (to === 'serving') return amount / food.portion.amount;
    return base / targetFactor;
  }
  function totals(food, amount, unit) {
    if (!Number.isFinite(food.basisAmount) || food.basisAmount <= 0) throw new Error('营养基准必须大于零');
    const factor = toBase(food, amount, unit) / food.basisAmount;
    return Object.fromEntries(nutrientFields.map(([key]) => [key, food.nutrients[key] == null ? null : food.nutrients[key] * factor]));
  }
  function energyComparison(food) {
    const n = food.nutrients;
    if (['energy', 'protein', 'fat', 'carbs'].some(key => n[key] == null)) return null;
    const estimated = 4 * n.protein + 9 * n.fat + 4 * n.carbs;
    return { declared: n.energy, estimated, gap: n.energy - estimated };
  }
  function validateFood(food) {
    if (!food.name?.trim()) return '请填写食品名称';
    if (!Number.isFinite(food.basisAmount) || food.basisAmount <= 0) return '营养基准必须大于零';
    if (food.nutrients.energy == null) return '请填写标示热量，其他未知营养素可以留空';
    if (nutrientFields.some(([key]) => food.nutrients[key] != null && (!Number.isFinite(food.nutrients[key]) || food.nutrients[key] < 0))) return '营养数值需要是零或正数';
    if (food.portion && (!['g', 'ml'].includes(food.portion.unit) || !Number.isFinite(food.portion.amount) || food.portion.amount <= 0 || (food.basisUnit !== 'serving' && food.portion.unit !== food.basisUnit))) return '请填写有效的每份重量或容量，且单位与营养基准一致';
    if (food.checked && (!food.evidence?.trim() || !food.evidenceType || food.evidenceType === 'none')) return '标记个人核对前，请选择来源并填写核对依据';
    return null;
  }
  function personalCopy(original, id) {
    return { ...structuredClone(original), id, kind: 'mine', checked: false,
      evidence: '', evidenceType: 'none', checkedAt: null,
      derivedFrom: original.derivedFrom ?? original.id,
      origin: original.origin ?? original.source,
      source: '我的修正版', favorite: false };
  }
  function makeEntry(food, amount, unit, meal, date, id) {
    if (amount <= 0) throw new Error('摄入量需要大于零');
    totals(food, amount, unit);
    return { id, food: structuredClone(food), amount, unit, meal, date };
  }
  const api = { nutrientFields, nutrients, toBase, convertAmount, totals, energyComparison, validateFood, personalCopy, makeEntry, kcalToKj: v => v * 4.184, kjToKcal: v => v / 4.184 };
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  else root.NutritionPrototype = api;
})(globalThis);
