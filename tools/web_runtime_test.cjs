// Unit checks for the shipped browser bridge, without a browser or network.
const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
let checks = 0;
const check = new Proxy(assert, {
    apply(target, self, args) { checks++; return Reflect.apply(target, self, args); },
    get(target, key) { const value = target[key]; return typeof value === 'function' ? (...args) => { checks++; return value(...args); } : value; }
});
class Target {
    constructor() { this.listeners = {}; this.children = []; this.style = {}; }
    addEventListener(kind, fn) { (this.listeners[kind] ??= []).push(fn); }
    emit(kind, data = {}) { for (const fn of this.listeners[kind] ?? []) fn(data); }
    append(...items) { this.children.push(...items); }
    remove() {}
    setAttribute() {}
    focus() { document.activeElement = this; }
    select() { this.selected = true; }
}
class Canvas extends Target {
    width = 2560; height = 1440;
    getContext() { return null; }
    getBoundingClientRect() { return {width: 1280, height: 720}; }
}
const canvas = new Canvas(), window = new Target(), document = new Target();
Object.assign(document, {body: new Target(), readyState: 'complete', activeElement: canvas,
    visibilityState: 'visible', hidden: false, hasFocus: () => true,
    getElementById: id => id === 'canvas' ? canvas : null,
    createElement: tag => Object.assign(new Target(), {tag})});
window.top = window;
let time = 10, serial = 0;
const frames = new Map();
vm.runInNewContext(fs.readFileSync('ldjam_60/game/web_runtime.js', 'utf8'), {
    window, document, HTMLCanvasElement: Canvas, performance: {now: () => time, timeOrigin: 1000},
    navigator: {userAgent: 'unit-test', platform: 'test', userActivation: {isActive: false}},
    devicePixelRatio: 2, screen: {width: 1280, height: 720}, innerWidth: 1280, innerHeight: 720,
    requestAnimationFrame: fn => { frames.set(++serial, fn); return serial; },
    cancelAnimationFrame: id => frames.delete(id), setTimeout, URL, Blob,
});
const runtime = window.BlackwaterRuntime;
check.equal(frames.size, 0, 'disabled recorder schedules no rAF work');
check.equal(runtime.isFocused(), true, 'canvas focus works without pointer lock');
document.emit('pointerlockerror');
check.equal(runtime.takeLifecycle(), 0, 'denied pointer lock does not become focus loss');
runtime.setRecording(true);
function step(ms) { time += ms; const pending = [...frames.values()]; frames.clear(); for (const fn of pending) fn(time); }
step(16); step(17); step(50);
window.emit('keydown', {code: 'KeyA', repeat: false});
window.emit('keydown', {code: 'KeyA', repeat: true});
window.emit('keydown', {code: 'KeyQ', repeat: false, key: 'private typed text'});
window.emit('keyup', {code: 'KeyA'});
let report = JSON.parse(runtime.report());
check.deepEqual(report.raf_frames.map(r => r[1]), [17, 50]);
check.equal(report.events.filter(e => e.kind === 'browser_keydown').length, 1);
check(!JSON.stringify(report).includes('private typed text'), 'unrelated keys/text are excluded');
check.equal(report.environment.device_pixel_ratio, 2);
check.deepEqual(report.environment.canvas_css, [1280, 720]);
check.deepEqual(report.environment.canvas_backing, [2560, 1440]);
canvas.emit('blur'); canvas.emit('focus');
check.equal(runtime.takeLifecycle(), 3, 'loss is retained even when focus returns in the same frame');
check.equal(runtime.takeLifecycle(), 0, 'lifecycle flags are consumed once');
document.pointerLockElement = canvas; document.emit('pointerlockchange');
document.pointerLockElement = null; document.emit('pointerlockchange');
check.equal(runtime.takeLifecycle(), 4, 'release of an acquired lock is distinct from denial');
for (let i = 0; i < 2200; i++) {
    window.emit('keydown', {code: 'KeyD', repeat: false}); window.emit('keyup', {code: 'KeyD'});
}
check(JSON.parse(runtime.report()).events.length <= 2000, 'event history is bounded');
for (let i = 0; i < 41000; i++) step(6);
report = JSON.parse(runtime.report());
check(report.raf_frames.length <= 40000, 'frame history is bounded');
check(report.raf_frames.every(r => r[0] >= time - 240000), 'export filters the retention window');
const json = '{"safe":"<script>not executable</script>"}';
runtime.offerExport(json, 'test.json');
const pane = document.body.children.at(-1);
check.equal(pane.children.at(-1).value, json, 'copyable text fallback preserves JSON as text');
runtime.setRecording(false);
check.equal(frames.size, 0, 'disabling stops rAF immediately');
console.log(`Browser bridge: ${checks} checks passed`);
