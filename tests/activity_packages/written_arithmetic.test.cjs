const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const fs = require('node:fs');
const packageRoot = path.resolve(__dirname, '../../content/activity_packages/written-arithmetic/1.0.0');
const { connect, validOrigin } = require(path.join(packageRoot, 'bridge.js'));
const { validatePayload, normalizeResult, collectResponses } = require(path.join(packageRoot, 'activity.js'));

const protocol = { protocol: 'cornerstone.activity', version: 1 };
function fakeSurface() {
  const sent = [];
  const listeners = new Map();
  const intervals = new Map();
  const surface = {
    parent: { postMessage(data, target) { sent.push({ data, target }); } },
    addEventListener(type, callback) { listeners.set(type, callback); },
    removeEventListener(type, callback) { if (listeners.get(type) === callback) listeners.delete(type); },
    setInterval(callback) { intervals.set(1, callback); return 1; },
    clearInterval(id) { intervals.delete(id); },
  };
  function emit(data, origin = 'https://learn.example', source = surface.parent) {
    listeners.get('message')?.({ data, origin, source });
  }
  return { surface, sent, listeners, intervals, emit };
}
function init(channel = 'test-channel') {
  return { ...protocol, type: 'initialize', channel, payload: { fixture: true } };
}
function response(request, changes = {}) {
  return { ...protocol, type: 'response', channel: 'test-channel', request_id: request.request_id, ok: true, result: { correct_count: 1 }, ...changes };
}
function payload() {
  return {
    mode: 'assisted',
    worksheet: {
      level: { title: 'Addition', instructions: 'Use columns.' },
      problems: [{ id: 'q1', prompt: '55 + 68', columns: 2, rows: [{ label: 'Answer', kind: 'answer', cells: [
        { id: null, text: '', max_digits: 1 }, { id: 'q1.r1.c1', text: '', max_digits: 1 },
      ] }] }],
    },
  };
}

test('bridge accepts only an actual HTTP(S) host origin', () => {
  for (const origin of ['https://learn.example', 'http://127.0.0.1:8788', 'http://localhost:8080']) assert.equal(validOrigin(origin), true);
  for (const origin of ['null', '', '*', 'file:///tmp/index.html', 'https://learn.example/path', 'https://learn.example/', 'javascript:alert(1)', undefined]) assert.equal(validOrigin(origin), false);
});

test('ready retries contain no worksheet data and initialization pins source, origin, and channel', async () => {
  const fake = fakeSurface();
  const initialized = [];
  const bridge = connect(fake.surface, (value) => initialized.push(value));
  assert.deepEqual(fake.sent[0], { data: { ...protocol, type: 'ready' }, target: '*' });
  fake.intervals.get(1)();
  assert.equal(fake.sent.length, 2);
  fake.emit(init(), 'https://learn.example', {});
  fake.emit(init(), 'null');
  fake.emit({ ...init(), version: 2 });
  assert.equal(initialized.length, 0);
  await assert.rejects(bridge.request('check', { responses: [] }), /not connected/);
  fake.emit(init());
  assert.equal(initialized.length, 1);
  assert.equal(fake.intervals.size, 0);
  fake.emit(init('replaced-channel'), 'https://attacker.example');
  assert.equal(initialized.length, 1);
  const pending = bridge.request('check', { responses: [{ item_id: 'q1.cell', value: '3' }], duration_seconds: 4 });
  const message = fake.sent.at(-1);
  assert.equal(message.target, 'https://learn.example');
  assert.equal(message.data.channel, 'test-channel');
  assert.equal(message.data.action, 'check');
  assert.deepEqual(message.data.responses, [{ item_id: 'q1.cell', value: '3' }]);
  fake.emit(response(message.data), 'https://attacker.example');
  fake.emit(response(message.data, { channel: 'wrong-channel' }));
  fake.emit(response(message.data), 'https://learn.example', {});
  fake.emit(response(message.data, { request_id: 'wrong-id' }));
  fake.emit(response(message.data, { ok: 'true' }));
  let resolved = false;
  pending.then(() => { resolved = true; });
  await Promise.resolve();
  assert.equal(resolved, false);
  fake.emit(response(message.data));
  assert.deepEqual(await pending, { correct_count: 1 });
  bridge.dispose();
  assert.equal(fake.listeners.size, 0);
});

test('malformed initialization cannot bind; host errors preserve a usable connection', async () => {
  const fake = fakeSurface();
  const bridge = connect(fake.surface, (value) => { if (!value.fixture) throw Error('invalid'); });
  fake.emit({ ...init(), payload: {} });
  assert.equal(fake.intervals.size, 1);
  fake.emit(init());
  const pending = bridge.request('complete', { responses: [], duration_seconds: 12 });
  const message = fake.sent.at(-1).data;
  fake.emit(response(message, { ok: false, error: { message: 'Please retry.' } }));
  await assert.rejects(pending, /Please retry/);
  const retry = bridge.request('complete', { responses: [], duration_seconds: 13 });
  fake.emit(response(fake.sent.at(-1).data, { result: { complete: true } }));
  assert.deepEqual(await retry, { complete: true });
  await assert.rejects(bridge.request('fetch-credentials', {}), /Unsupported/);
  const interrupted = bridge.request('check', { responses: [] });
  bridge.dispose();
  await assert.rejects(interrupted, /closed/);
});

test('worksheet validation requires rectangular, uniquely identified backend cells', () => {
  assert.equal(validatePayload(payload()).worksheet.problems[0].columns, 2);
  const duplicate = payload();
  duplicate.worksheet.problems[0].rows[0].cells[0].id = 'q1.r1.c1';
  assert.throws(() => validatePayload(duplicate), /duplicate/);
  const mismatched = payload();
  mismatched.worksheet.problems[0].columns = 3;
  assert.throws(() => validatePayload(mismatched), /row/);
  assert.throws(() => validatePayload({ ...payload(), mode: 'hidden-assessment' }), /mode/);
  const invalidDigits = payload();
  invalidDigits.worksheet.problems[0].rows[0].cells[1].max_digits = 0;
  assert.throws(() => validatePayload(invalidDigits), /cell/);
});

test('per-exercise checks send only entered boxes, completion includes every working cell', () => {
  const entries = new Map([
    ['a', { cellId: 'a', problemId: 'q1', input: { value: ' 3 ' } }],
    ['b', { cellId: 'b', problemId: 'q1', input: { value: '' } }],
    ['c', { cellId: 'c', problemId: 'q2', input: { value: '8' } }],
  ]);
  assert.deepEqual(collectResponses(entries, 'q1', false), [{ item_id: 'a', value: '3' }]);
  assert.deepEqual(collectResponses(entries, undefined, true), [
    { item_id: 'a', value: '3' }, { item_id: 'b', value: '' }, { item_id: 'c', value: '8' },
  ]);
});

test('server result presentation preserves working feedback without calculating grades', () => {
  const check = { correct_count: 2, total_count: 3, feedback: [{ cell_id: 'a', correct: false, expected: '4', explanation: 'Carry one ten.' }] };
  assert.deepEqual(normalizeResult(check), { correctCount: 2, totalCount: 3, feedback: check.feedback, summary: '' });
  const tracked = normalizeResult({ check_result: check, run_outcome_label: 'Keep practising' });
  assert.equal(tracked.summary, 'Keep practising');
  assert.deepEqual(tracked.feedback, check.feedback);
  const fallback = normalizeResult({ activity_summary: { corrections: [{ item_id: 'a', expected_response: '4', correction_cue: 'Carry one ten.' }] } });
  assert.deepEqual(fallback.feedback, [{ cell_id: 'a', correct: false, expected: '4', explanation: 'Carry one ten.' }]);
  assert.equal(fallback.correctCount, null);
});

test('package entry uses local assets with no inline script, styles, or network access', () => {
  const manifest = JSON.parse(fs.readFileSync(path.join(packageRoot, 'manifest.json'), 'utf8'));
  assert.equal(manifest.protocol_version, 1);
  for (const file of manifest.files) assert.ok(fs.existsSync(path.join(packageRoot, file)), file);
  const html = fs.readFileSync(path.join(packageRoot, 'index.html'), 'utf8');
  assert.doesNotMatch(html, /<script(?![^>]*\bsrc=)|\bstyle=|<style|https?:\/\//i);
  const renderer = fs.readFileSync(path.join(packageRoot, 'activity.js'), 'utf8');
  assert.doesNotMatch(renderer, /\bfetch\s*\(|XMLHttpRequest|\.innerHTML\b|\beval\s*\(/);
});
