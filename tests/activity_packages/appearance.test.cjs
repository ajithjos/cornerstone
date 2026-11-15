const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { connect, applyAppearance, COLOR_TOKENS } = require('../../content/activity_foundation/bridge.js');

function surface() {
  const properties = new Map();
  const attributes = new Map();
  const listeners = new Map();
  const node = { setAttribute: (key, value) => attributes.set(key, value),
    style: { setProperty: (key, value) => properties.set(key, value) } };
  const host = { postMessage() {} };
  return {
    parent: host, document: { documentElement: node }, properties, attributes, listeners,
    addEventListener: (type, callback) => listeners.set(type, callback),
    removeEventListener: (type) => listeners.delete(type),
    setInterval() { return 1; }, clearInterval() {},
  };
}
function appearance(mode, color) {
  return { mode, colors: Object.fromEntries(COLOR_TOKENS.map((name) => [name, color])) };
}
const envelope = { protocol: 'cornerstone.activity', version: 1, channel: 'test' };

test('theme changes update only semantic CSS tokens without initializing the exercise again', () => {
  const fake = surface();
  let initializations = 0;
  const bridge = connect(fake, () => { initializations++; });
  const emit = (data, origin = 'https://school.test', source = fake.parent) =>
    fake.listeners.get('message')({ data, origin, source });
  emit({ ...envelope, type: 'initialize', payload: {}, appearance: appearance('light', '#ffffff') });
  assert.equal(initializations, 1);
  assert.equal(fake.attributes.get('data-appearance'), 'light');
  emit({ ...envelope, type: 'appearance', appearance: appearance('dark', '#161915') });
  assert.equal(fake.properties.get('--cs-background'), '#161915');
  assert.equal(fake.document.documentElement.style.colorScheme, 'dark');
  assert.equal(initializations, 1);
  // Theme messages retain the same source, origin and channel boundary as replies.
  emit({ ...envelope, type: 'appearance', appearance: appearance('light', '#ffffff') }, 'https://other.test');
  emit({ ...envelope, channel: 'wrong', type: 'appearance', appearance: appearance('light', '#ffffff') });
  emit({ ...envelope, type: 'appearance', appearance: appearance('light', '#ffffff') }, 'https://school.test', {});
  assert.equal(fake.attributes.get('data-appearance'), 'dark');
  bridge.dispose();
});

test('appearance validation is atomic and does not accept CSS, URLs, or unknown token injection', () => {
  const fake = surface();
  assert.equal(applyAppearance(fake, appearance('light', '#ffffff')), true);
  for (const value of ['url(https://other.test)', '#fff; color:red', 'red', '#abcd', 2, null]) {
    const invalid = appearance('dark', '#161915');
    invalid.colors.primary = value;
    assert.equal(applyAppearance(fake, invalid), false);
    assert.equal(fake.attributes.get('data-appearance'), 'light');
    assert.equal(fake.properties.get('--cs-background'), '#ffffff');
  }
  const valid = appearance('dark', '#161915');
  valid.colors['evil-selector'] = 'url(https://other.test)';
  assert.equal(applyAppearance(fake, valid), true);
  assert.equal(fake.properties.has('--cs-evil-selector'), false);
  assert.equal(applyAppearance(fake, { mode: 'system', colors: valid.colors }), false);
});

test('every package ships the shared foundation and leaves all palette choices to semantic tokens', () => {
  const root = path.resolve(__dirname, '../../content');
  const registry = JSON.parse(fs.readFileSync(path.join(root, 'activity_packages/registry.json')));
  for (const item of registry.packages) {
    const directory = path.join(root, 'activity_packages', item.path);
    for (const file of ['bridge.js', 'foundation.css']) {
      assert.equal(fs.readFileSync(path.join(directory, file), 'utf8'),
        fs.readFileSync(path.join(root, 'activity_foundation', file), 'utf8'));
    }
    const css = fs.readFileSync(path.join(directory, 'styles.css'), 'utf8');
    assert.doesNotMatch(css, /#[0-9a-f]{3,8}\b|(?:color|background):\s*(?:white|black)\b/i);
  }
});
