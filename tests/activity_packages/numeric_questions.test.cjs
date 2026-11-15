const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const fs = require('node:fs');
const crypto = require('node:crypto');
const root = path.resolve(__dirname, '../../content/activity_packages');
const packageRoot = path.join(root, 'numeric-questions/1.0.0');
const { validatePayload, normalizeCompletion } = require(path.join(packageRoot, 'activity.js'));

function payload() {
  return {
    title: 'Fact fluency', mode: 'assessment', instructions: 'Answer each question.', capabilities: { check: false },
    items: [{ item_id: 'item-1', content: '7 + 8 =', response_kind: 'integer' }],
  };
}

test('numeric package accepts explicit integer items without answers or arithmetic rules', () => {
  assert.equal(validatePayload(payload()).items[0].item_id, 'item-1');
  const duplicate = payload();
  duplicate.items.push({ ...duplicate.items[0] });
  assert.throws(() => validatePayload(duplicate), /Invalid integer/);
  const unsupported = payload();
  unsupported.items[0].response_kind = 'written_grid';
  assert.throws(() => validatePayload(unsupported), /Invalid integer/);
  assert.throws(() => validatePayload({ ...payload(), items: [] }), /Invalid question/);
  assert.throws(() => validatePayload({ ...payload(), mode: 'practice' }), /Invalid question/);
});

test('numeric completion displays server outcome, counts, and corrections unchanged', () => {
  const corrections = [{ item_id: 'item-1', expected_response: '15', correction_cue: 'Seven plus eight makes fifteen.' }];
  assert.deepEqual(normalizeCompletion({
    run_outcome_label: 'Keep practising',
    activity_summary: { correct_count: 3, item_count: 4, corrections },
  }), { title: 'Keep practising', correctCount: 3, itemCount: 4, corrections });
  assert.deepEqual(normalizeCompletion({}), {
    title: 'Your work has been submitted.', correctCount: null, itemCount: null, corrections: [],
  });
});

test('every registry package is self-contained and every declared asset matches its pinned hash', () => {
  const registry = JSON.parse(fs.readFileSync(path.join(root, 'registry.json'), 'utf8'));
  assert.ok(registry.packages.length >= 2);
  for (const item of registry.packages) {
    const directory = path.join(root, item.path);
    const manifest = JSON.parse(fs.readFileSync(path.join(directory, 'manifest.json'), 'utf8'));
    assert.equal(manifest.package_id, item.package_id);
    assert.equal(manifest.version, item.version);
    assert.equal(manifest.protocol_version, 1);
    assert.ok(manifest.files.includes(manifest.entry));
    assert.deepEqual(Object.keys(manifest.sha256).sort(), [...manifest.files].sort());
    for (const file of manifest.files) {
      assert.ok(!file.includes('..') && !path.isAbsolute(file));
      const digest = crypto.createHash('sha256').update(fs.readFileSync(path.join(directory, file))).digest('hex');
      assert.equal(digest, manifest.sha256[file], `${item.package_id}/${file}`);
    }
    const html = fs.readFileSync(path.join(directory, manifest.entry), 'utf8');
    assert.doesNotMatch(html, /<script(?![^>]*\bsrc=)|\bstyle=|<style|https?:\/\//i);
  }
});

test('numeric package shares the audited bridge but has no network, early check, or grading implementation', () => {
  assert.equal(
    fs.readFileSync(path.join(packageRoot, 'bridge.js'), 'utf8'),
    fs.readFileSync(path.join(root, 'written-arithmetic/1.0.0/bridge.js'), 'utf8'),
  );
  const script = fs.readFileSync(path.join(packageRoot, 'activity.js'), 'utf8');
  assert.doesNotMatch(script, /\bfetch\s*\(|XMLHttpRequest|\.innerHTML\b|\beval\s*\(|bridge\.request\(['"]check/);
  assert.match(script, /bridge\.request\('complete'/);
});

test('completion button sends answers through the bridge without native form submission', async () => {
  const vm = require('node:vm');
  const html = fs.readFileSync(path.join(packageRoot, 'index.html'), 'utf8');
  assert.match(html, /<button\s+id="submit"\s+type="button"/);
  assert.doesNotMatch(html, /<form\b/);
  const elements = new Map();
  function element() {
    return { value: '', listeners: new Map(), classList: { add() {}, toggle() {} },
      addEventListener(type, handler) { this.listeners.set(type, handler); },
      setAttribute() {}, append() {}, replaceChildren() {}, focus() {} };
  }
  const document = {
    getElementById(id) { if (!elements.has(id)) elements.set(id, element()); return elements.get(id); },
    createElement: element,
  };
  let initialize;
  const requests = [];
  const window = { document, parent: {}, performance: { now: () => 1000 }, addEventListener() {},
    CornerstoneActivityBridge: { connect(_, ready) {
      initialize = ready;
      return { request: async (action, body) => {
        requests.push({ action, body });
        return { run_outcome_label: 'Target met', activity_summary: { correct_count: 1, item_count: 1 } };
      } };
    } },
  };
  vm.runInNewContext(fs.readFileSync(path.join(packageRoot, 'activity.js'), 'utf8'), { window });
  // Capture the input created by the real package, rather than reconstructing its responses.
  let input;
  document.createElement = tag => { const node = element(); if (tag === 'input') input = node; return node; };
  initialize(payload());
  input.value = '15';
  const button = elements.get('submit');
  assert.equal(typeof button.listeners.get('click'), 'function');
  await button.listeners.get('click')({ preventDefault() {} });
  assert.deepEqual(JSON.parse(JSON.stringify(requests)), [{ action: 'complete', body: {
    responses: [{ item_id: 'item-1', value: '15' }], duration_seconds: 0,
  } }]);
  assert.equal(button.disabled, true);
  assert.equal(elements.get('result-title').textContent, 'Target met');
});
