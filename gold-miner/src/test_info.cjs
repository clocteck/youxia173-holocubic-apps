// Run the actual inline script against a minimal DOM, including language toggle.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const html = fs.readFileSync(path.join(__dirname, '../package/info.html'), 'utf8');
const nodes = [...html.matchAll(/data-i18n="([^"]+)">([^<]*)</g)].map((m) => ({
  key: m[1], textContent: m[2], getAttribute() { return this.key; }
}));
const defaults = nodes.map(n => n.textContent);
let click;
const button = { addEventListener(event, fn) { assert.equal(event, 'click'); click = fn; } };
const document = {
  documentElement: {},
  getElementById(id) { assert.equal(id, 'langBtn'); return button; },
  querySelectorAll(selector) { assert.equal(selector, '[data-i18n]'); return nodes; }
};
const context = vm.createContext({ document });
vm.runInContext(html.match(/<script>([\s\S]*?)<\/script>/)[1], context);
const dictionaries = vm.runInContext('dict', context);
for (const dictionary of Object.values(dictionaries)) {
  for (const node of nodes) assert.ok(dictionary[node.key], `Missing ${node.key}`);
}
assert.deepEqual(nodes.map(n => n.textContent), defaults);
assert.equal(document.documentElement.lang, 'zh-CN');
assert.equal(button.textContent, 'EN');
click();
assert.equal(document.documentElement.lang, 'en');
assert.equal(document.title, 'Gold Miner - App info');
assert.equal(nodes.find(n => n.key === 'title').textContent, 'Gold Miner');
assert.match(nodes.find(n => n.key === 'note').textContent, /prices vary/);
click();
assert.deepEqual(nodes.map(n => n.textContent), defaults);
console.log(`PASS: ${nodes.length} translated fields, defaults, titles and language toggle`);
