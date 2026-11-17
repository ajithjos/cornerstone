const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const fs = require('node:fs');
const vm = require('node:vm');
const packageRoot = path.resolve(__dirname, '../../content/activity_packages/written-arithmetic/1.1.0');
const { connect, validOrigin } = require(path.join(packageRoot, 'bridge.js'));
const { validatePayload, normalizeResult } = require(path.join(packageRoot, 'activity.js'));

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
  const badLabels = payload();
  badLabels.worksheet.problems[0].column_labels = ['tens'];
  assert.throws(() => validatePayload(badLabels), /column labels/);
  const badSign = payload();
  badSign.worksheet.problems[0].rows[0].trailing_sign = 'word';
  assert.throws(() => validatePayload(badSign), /operation sign/);
});

// Run the actual package click and input handlers, with only DOM and host IO stubbed.
const cell = (id, text = '', max_digits = 1) => ({ id, text, max_digits });

function openPractice(mode, problems, answers = { first: '1', second: '6', third: '4' }) {
  const byId = new Map();
  const all = [];
  let focused;
  function element(tag) {
    const el = {
      tag, value: '', children: [], attrs: {}, handlers: {}, classList: { toggle() {} },
      setAttribute(key, value) { this.attrs[key] = value; },
      removeAttribute(key) { delete this.attrs[key]; },
      append(...nodes) { this.children.push(...nodes); },
      replaceChildren(...nodes) { this.children = nodes; },
      addEventListener(event, handler) { this.handlers[event] = handler; },
      focus() { focused = this; },
    };
    all.push(el);
    return el;
  }
  const document = {
    getElementById(id) {
      if (!byId.has(id)) byId.set(id, element('div'));
      return byId.get(id);
    },
    createElement: element,
  };
  const requests = [];
  let initialize;
  const window = {
    document, parent: {}, performance: { now: () => 1000 }, addEventListener() {},
    CornerstoneActivityBridge: {
      connect(_, ready) {
        initialize = ready;
        return { request: async (action, body) => {
          requests.push({ action, ...JSON.parse(JSON.stringify(body)) });
          const feedback = body.responses.map(({ item_id, value }) => ({
            cell_id: item_id, correct: [answers[item_id]].flat().includes(value), expected: [answers[item_id]].flat().join(' or '),
            explanation: 'Check the ones.',
          }));
          return { check_result: { feedback, total_count: feedback.length, correct_count: feedback.filter(cell => cell.correct).length } };
        } };
      },
    },
  };
  vm.runInNewContext(fs.readFileSync(path.join(packageRoot, 'activity.js'), 'utf8'), { window });
  const sheet = payload();
  sheet.worksheet.problems = problems || [{
    id: 'q1', prompt: '321 − 157', columns: 3, column_labels: ['hundreds', 'tens', 'ones'],
    rows: [
      { label: 'Exchange marks', kind: 'annotation', cells: [cell(null, '2'), cell('first', '', 2), cell(null)] },
      { label: 'Answer', kind: 'answer', cells: [cell(null, '1'), cell('second'), cell(null, '4')] },
    ],
  }, {
    id: 'q2', prompt: '7 − 3', columns: 1, column_labels: ['ones'],
    rows: [{ label: 'Answer', kind: 'answer', cells: [cell('third')] }],
  }];
  initialize({ ...sheet, mode });
  const inputs = all.filter((el) => el.tag === 'input');
  function type(index, value) { inputs[index].value = value; inputs[index].handlers.input(); }
  return {
    all, inputs, requests, type, focused: () => focused,
    checks: all.filter((el) => el.tag === 'button'),
    complete: byId.get('complete'), notice: byId.get('notice'),
  };
}

test('exercise checks report unfinished work; final submission waits for every editable box', async () => {
  const run = openPractice('assisted');
  const [first, second, third] = run.inputs;
  assert.equal(run.inputs.length, 3);
  assert.equal(first.maxLength, 2);
  assert.equal(first.attrs['aria-label'], 'Question 1, Exchange marks, tens');
  assert.equal(run.all.filter((el) => el.className === 'printed-prefix').length, 0);
  assert.deepEqual(run.all.filter((el) => el.scope === 'col').map((el) => el.textContent), ['hundreds', 'tens', 'ones', 'ones']);

  run.type(0, '1');
  await run.checks[0].handlers.click();
  assert.deepEqual(run.requests[0].responses, [{ item_id: 'first', value: '1' }, { item_id: 'second', value: '' }]);
  assert.equal(second.attrs['aria-invalid'], 'false');
  assert.equal(second.attrs['aria-describedby'], 'missing-1');
  assert.ok(!run.all.some((el) => el.textContent === '✓ This question is correct.'));
  await run.complete.handlers.click();
  assert.equal(run.requests.length, 1);
  assert.equal(run.focused(), second);
  run.type(1, '5');
  await run.checks[0].handlers.click();
  assert.equal(second.attrs['aria-invalid'], 'true');
  run.type(1, '6');
  await run.checks[0].handlers.click();
  assert.ok(run.all.some((el) => el.textContent === '✓ This question is correct.'));
  await run.complete.handlers.click();
  assert.equal(run.focused(), third);
  run.type(2, '4');
  await run.complete.handlers.click();
  assert.deepEqual(run.requests.at(-1), {
    action: 'complete', duration_seconds: 0,
    responses: [{ item_id: 'first', value: '1' }, { item_id: 'second', value: '6' }, { item_id: 'third', value: '4' }],
  });
  assert.ok(run.inputs.every(input => input.disabled));
  assert.equal(run.complete.disabled, true);
});

test('four-digit subtraction preserves full and short entries as entered', async () => {
  const run = openPractice('assisted', [{
    id: 'q1', prompt: '5674 − 2987', columns: 4, column_labels: ['thousands', 'hundreds', 'tens', 'ones'],
    rows: [{ label: 'Exchange marks', kind: 'annotation', cells: [
      cell('thousands'), cell('hundreds', '', 2), cell('tens', '', 2), cell(null),
    ] }, { label: 'Answer', kind: 'answer', cells: ['a', 'b', 'c', 'd'].map(id => cell(id)) }],
  }], { thousands: '4', hundreds: ['5', '15'], tens: ['6', '16'], a: '2', b: '6', c: '8', d: '7' });
  ['4', '15', '6', '2', '6', '8', '7'].forEach((value, index) => run.type(index, value));
  await run.checks[0].handlers.click();
  assert.deepEqual(run.requests[0].responses.map(r => r.value), ['4', '15', '6', '2', '6', '8', '7']);
  assert.ok(run.inputs.every(input => input.attrs['aria-invalid'] === 'false'));
  run.type(1, '5');
  run.type(2, '16');
  run.type(2, '16x');
  assert.equal(run.inputs[2].value, '16');
  run.type(2, '');
  run.type(2, '16');
  await run.complete.handlers.click();
  assert.deepEqual(run.requests.at(-1).responses.map(r => r.value), ['4', '5', '16', '2', '6', '8', '7']);
  assert.ok(run.inputs.every(input => input.disabled && input.attrs['aria-invalid'] === 'false'));
});

test('assessment identifies a missing box without checking answers or submitting early', async () => {
  const run = openPractice('assessment');
  assert.equal(run.checks.length, 0);
  run.type(0, '8');
  await run.complete.handlers.click();
  assert.deepEqual(run.requests, []);
  assert.equal(run.inputs[0].attrs['aria-invalid'], 'false');
  assert.equal(run.focused(), run.inputs[1]);
  run.type(1, '6');
  run.type(2, '4');
  await run.complete.handlers.click();
  assert.equal(run.requests.length, 1);
  assert.equal(run.inputs[0].attrs['aria-invalid'], 'true');
  assert.equal(run.complete.textContent, 'Assessment submitted');
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
