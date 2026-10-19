/* Local-only browser lifecycle and diagnostics. Loaded before the Web engine. */
(() => {
    'use strict';
    if (window.BlackwaterRuntime) return;
    const seconds = 240, capacity = 40000, eventLimit = 2000;
    const times = new Float64Array(capacity), intervals = new Float32Array(capacity);
    let cursor = 0, count = 0, recording = false, previous = 0, raf = 0;
    let lifecycle = 0, wasLocked = false, audioPaused = false;
    const events = [], contexts = [], keys = new Set(), renderTargets = [], gpuContexts = [];
    // Observe actual GPU attachment allocations independently of CSS dimensions
    // (rare calls, no per-draw hook).
    const getContext = HTMLCanvasElement.prototype.getContext;
    HTMLCanvasElement.prototype.getContext = function (...args) {
        const gl = getContext.apply(this, args);
        if (!gl || !args[0].startsWith('webgl') || gl.__blackwaterObserved) return gl;
        gl.__blackwaterObserved = true;
        const dimensions = new WeakMap();
        const observedSizes = new WeakMap();
        const attachments = new Map();
        const colorAttachment = a => a >= gl.COLOR_ATTACHMENT0 && a < gl.COLOR_ATTACHMENT0 + 16;
        const remember = (framebuffer, point, object, kind) => {
            if (!framebuffer) return;
            if (!attachments.has(framebuffer)) attachments.set(framebuffer, new Map());
            if (object) attachments.get(framebuffer).set(point, {object, kind});
            else attachments.get(framebuffer).delete(point);
            const size = dimensions.get(object);
            const signature = size ? kind + ':' + size.join('x') : null;
            // Cubemap faces are reattached while rendering the sky. Retain size
            // changes, without flooding history with identical per-frame binds.
            if (size && colorAttachment(point) && observedSizes.get(object) !== signature) {
                observedSizes.set(object, signature);
                renderTargets.push({t_ms: now(), size, kind});
                if (renderTargets.length > 64) renderTargets.shift();
            }
        };
        const binding = target => gl.getParameter(target === gl.READ_FRAMEBUFFER ? gl.READ_FRAMEBUFFER_BINDING : gl.FRAMEBUFFER_BINDING);
        const debug = gl.getExtension('WEBGL_debug_renderer_info');
        const renderer = debug ? gl.getParameter(debug.UNMASKED_RENDERER_WEBGL) : gl.getParameter(gl.RENDERER);
        gpuContexts.push(() => ({
            canvas_id: this.id || null,
            drawing_buffer: [gl.drawingBufferWidth, gl.drawingBufferHeight],
            renderer,
            context_lost: gl.isContextLost(),
            // Current attachments, including resized storage and deletions. This is
            // distinct from allocation history and from the default drawing buffer.
            color_attachments: [...attachments.values()].flatMap(points => [...points].filter(([point]) => colorAttachment(point)).map(([point, a]) => ({
                attachment: point - gl.COLOR_ATTACHMENT0, kind: a.kind, size: dimensions.get(a.object) ?? null
            })))
        }));
        for (const method of ['texImage2D', 'texStorage2D']) {
            const original = gl[method].bind(gl);
            gl[method] = (...a) => {
                const result = original(...a);
                const size = method === 'texStorage2D' || a.length >= 9 ? [a[3], a[4]] : a[5]?.width ? [a[5].width, a[5].height] : null;
                const cube = a[0] === gl.TEXTURE_CUBE_MAP || (a[0] >= gl.TEXTURE_CUBE_MAP_POSITIVE_X && a[0] <= gl.TEXTURE_CUBE_MAP_NEGATIVE_Z);
                if (size && (a[0] === gl.TEXTURE_2D || cube) && (method === 'texStorage2D' || a[1] === 0)) {
                    const texture = gl.getParameter(cube ? gl.TEXTURE_BINDING_CUBE_MAP : gl.TEXTURE_BINDING_2D);
                    if (texture) dimensions.set(texture, size);
                }
                return result;
            };
        }
        const attach = gl.framebufferTexture2D.bind(gl);
        gl.framebufferTexture2D = (...a) => {
            const result = attach(...a);
            remember(binding(a[0]), a[1], a[3], 'texture');
            return result;
        };
        for (const method of ['renderbufferStorage', 'renderbufferStorageMultisample']) {
            if (!gl[method]) continue;
            const original = gl[method].bind(gl);
            gl[method] = (...a) => {
                const result = original(...a), rb = gl.getParameter(gl.RENDERBUFFER_BINDING);
                if (rb) dimensions.set(rb, [gl.getRenderbufferParameter(gl.RENDERBUFFER, gl.RENDERBUFFER_WIDTH),
                    gl.getRenderbufferParameter(gl.RENDERBUFFER, gl.RENDERBUFFER_HEIGHT)]);
                return result;
            };
        }
        const attachRB = gl.framebufferRenderbuffer.bind(gl);
        gl.framebufferRenderbuffer = (...a) => {
            const result = attachRB(...a);
            remember(binding(a[0]), a[1], a[3], 'renderbuffer');
            return result;
        };
        const deleteFB = gl.deleteFramebuffer.bind(gl);
        gl.deleteFramebuffer = fb => { attachments.delete(fb); return deleteFB(fb); };
        for (const method of ['deleteTexture', 'deleteRenderbuffer']) {
            const original = gl[method].bind(gl);
            gl[method] = object => {
                dimensions.delete(object);
                for (const points of attachments.values()) for (const [point, a] of points) if (a.object === object) points.delete(point);
                return original(object);
            };
        }
        return gl;
    };
    const controls = new Set(['KeyA', 'KeyD', 'ArrowLeft', 'ArrowRight', 'KeyW',
        'ShiftLeft', 'ShiftRight', 'Space', 'KeyE', 'KeyR', 'KeyM', 'Enter', 'Escape', 'F8', 'Equal', 'NumpadAdd']);
    const now = () => performance.now();
    const event = (kind, data = {}) => {
        if (!recording) return;
        events.push({t_ms: now(), kind, data});
        while (events.length > eventLimit || (events.length && events[0].t_ms < now() - seconds * 1000)) events.shift();
    };
    const notify = (kind) => {
        event(kind);
        if (['window_blur', 'hidden', 'canvas_blur'].includes(kind)) {
            lifecycle |= 1;
            audioPaused = true;
            for (const ctx of contexts) if (ctx.state === 'running') ctx.suspend().catch(() => {});
        } else if (kind === 'pointer_released') lifecycle |= 4;
        else lifecycle |= 2;
    };
    function tick(t) {
        if (!recording) return;
        if (previous) {
            times[cursor] = t; intervals[cursor] = t - previous;
            cursor = (cursor + 1) % capacity; count = Math.min(count + 1, capacity);
        }
        previous = t;
        raf = requestAnimationFrame(tick);
    }
    // Observe the actual engine AudioContexts, including suspension. No audio leaves the page.
    for (const name of ['AudioContext', 'webkitAudioContext']) {
        const Original = window[name];
        if (!Original) continue;
        window[name] = new Proxy(Original, {construct(Target, args) {
            const ctx = Reflect.construct(Target, args);
            contexts.push(ctx);
            const resume = ctx.resume.bind(ctx);
            // The engine also resumes on browser gestures. Focus restoration or
            // diagnostic clicks must not bypass the game's explicit Resume.
            ctx.resume = (...a) => audioPaused ? Promise.resolve() : resume(...a);
            ctx.addEventListener('statechange', () => event('audio_context', {state: ctx.state}));
            const create = ctx.createBufferSource.bind(ctx);
            ctx.createBufferSource = () => {
                const source = create(), start = source.start.bind(source);
                source.start = (...args) => {
                    event('audio_sample_start', {duration_s: source.buffer?.duration,
                        sample_rate: source.buffer?.sampleRate, loop: source.loop,
                        loop_start_s: source.loopStart, loop_end_s: source.loopEnd,
                        playback_rate: source.playbackRate.value, offset_s: args[1] || 0,
                        context_time_s: ctx.currentTime, scheduled_time_s: args[0] || 0});
                    source.addEventListener('ended', () => event('audio_sample_end', {
                        duration_s: source.buffer?.duration, context_time_s: ctx.currentTime}));
                    return start(...args);
                };
                return source;
            };
            return ctx;
        }});
    }
    const canvas = () => document.getElementById('canvas');
    const focused = () => document.visibilityState === 'visible' && document.hasFocus()
        && (document.activeElement === canvas() || document.pointerLockElement === canvas());
    const resumeAudio = () => {
        if (audioPaused || !focused()) return;
        for (const ctx of contexts) if (ctx.state === 'suspended') ctx.resume().catch(e => event('audio_resume_denied', {name: e.name}));
    };
    window.addEventListener('blur', () => { keys.clear(); notify('window_blur'); });
    window.addEventListener('focus', () => notify('window_focus'));
    document.addEventListener('visibilitychange', () => {
        if (document.hidden) keys.clear();
        notify(document.hidden ? 'hidden' : 'visible');
    });
    document.addEventListener('pointerlockchange', () => {
        const locked = document.pointerLockElement === canvas();
        event('pointer_lock', {locked});
        // Only a released, previously acquired lock is an Escape/menu transition.
        // A denied request never changes keyboard focus or pauses the game.
        if (wasLocked && !locked) notify('pointer_released');
        wasLocked = locked;
    });
    document.addEventListener('pointerlockerror', () => event('pointer_lock_denied'));
    window.addEventListener('keydown', e => {
        if (!controls.has(e.code) || document.activeElement !== canvas()) return;
        if (!e.repeat) { keys.add(e.code); event('browser_keydown', {code: e.code}); }
        resumeAudio();
    }, true);
    window.addEventListener('keyup', e => {
        if (!controls.has(e.code)) return;
        if (keys.delete(e.code)) event('browser_keyup', {code: e.code});
    }, true);
    window.addEventListener('pointerdown', resumeAudio, true);
    function installCanvas() {
        const c = canvas();
        if (!c) return;
        // Canvas Resize Policy=None: the engine follows this backing buffer.
        // Match its aspect to CSS so Window's KEEP letterboxing and pointer
        // coordinates stay aligned. Presentation is bounded even at extreme DPR,
        // zoom, iframe resize or fullscreen; the 3D viewport is bounded separately.
        const resize = () => {
            const width = Math.max(1, innerWidth), height = Math.max(1, innerHeight);
            const scale = Math.min(devicePixelRatio || 1, 1280 / width, 720 / height);
            const w = Math.max(1, Math.floor(width * scale)), h = Math.max(1, Math.floor(height * scale));
            if (c.width !== w) c.width = w;
            if (c.height !== h) c.height = h;
        };
        resize();
        window.addEventListener('resize', resize);
        document.addEventListener('fullscreenchange', resize);
        c.addEventListener('blur', () => { keys.clear(); notify('canvas_blur'); });
        c.addEventListener('focus', () => notify('canvas_focus'));
    }
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', installCanvas, {once: true});
    else installCanvas();
    const frames = () => {
        const rows = [], cutoff = now() - seconds * 1000;
        for (let i = 0; i < count; i++) {
            const n = (cursor - count + i + capacity) % capacity;
            if (times[n] >= cutoff) rows.push([Math.round(times[n]), +intervals[n].toFixed(3)]);
        }
        return rows;
    };
    function environment() {
        const c = canvas(), r = c?.getBoundingClientRect();
        return {user_agent: navigator.userAgent, platform: navigator.platform,
            device_pixel_ratio: devicePixelRatio, display: [screen.width, screen.height],
            browser_inner: [innerWidth, innerHeight], canvas_css: r ? [r.width, r.height] : null,
            canvas_backing: c ? [c.width, c.height] : null, visibility: document.visibilityState,
            document_focus: document.hasFocus(), canvas_focus: document.activeElement === c,
            pointer_locked: document.pointerLockElement === c, keys: [...keys],
            fullscreen: !!document.fullscreenElement, embedded: window !== window.top,
            service_worker_controlled: !!navigator.serviceWorker?.controller,
            gpu_color_target_allocations: renderTargets.slice(),
            webgl: gpuContexts.map(snapshot => snapshot()),
            audio_contexts: contexts.map(c => ({state: c.state, sample_rate: c.sampleRate,
                base_latency_s: c.baseLatency ?? null, output_latency_s: c.outputLatency ?? null}))};
    }
    window.BlackwaterRuntime = {
        clockMs: now,
        takeLifecycle() { const value = lifecycle; lifecycle = 0; return value; },
        detach() { this.setRecording(false); },
        isFocused: focused,
        setRecording(value) {
            recording = value; previous = 0; cancelAnimationFrame(raf);
            if (value) { cursor = 0; count = 0; events.length = 0; event('recording_started'); raf = requestAnimationFrame(tick); }
        },
        snapshot: () => JSON.stringify(environment()),
        report: () => JSON.stringify({environment: environment(), time_origin_unix_ms: performance.timeOrigin,
            frame_columns: ['browser_ms', 'interval_ms'], raf_frames: frames(),
            events: events.filter(e => e.t_ms >= now() - seconds * 1000)}),
        focusCanvas() { canvas()?.focus({preventScroll: true}); resumeAudio(); return focused(); },
        canCapture: () => !!navigator.userActivation?.isActive && focused(),
        pauseAudio(value) {
            audioPaused = value; event('audio_pause', {paused: value});
            for (const ctx of contexts) if (value && ctx.state === 'running') ctx.suspend().catch(e => event('audio_suspend_denied', {name: e.name}));
            if (!value) resumeAudio();
        },
        offerExport(report, filename) {
            document.getElementById('blackwater-export')?.remove();
            const pane = document.createElement('div'); pane.id = 'blackwater-export';
            pane.style.cssText = 'position:fixed;inset:5%;z-index:9999;background:#102838;color:#f0e5cc;padding:20px;font:16px sans-serif;display:flex;flex-direction:column;gap:12px;border:2px solid #d6ac68';
            const label = document.createElement('p');
            label.textContent = 'Diagnostics stay on this device. Download JSON, or select and copy the text if downloads are blocked.';
            const text = document.createElement('textarea'); text.value = report; text.readOnly = true;
            text.setAttribute('aria-label', 'Diagnostic JSON'); text.style.cssText = 'flex:1;min-height:80px;width:100%;box-sizing:border-box';
            const actions = document.createElement('div');
            for (const [name, action] of [
                ['Download JSON', () => {
                    const url = URL.createObjectURL(new Blob([report], {type: 'application/json'}));
                    const a = document.createElement('a'); a.href = url; a.download = filename;
                    pane.append(a); a.click(); a.remove(); setTimeout(() => URL.revokeObjectURL(url), 60000);
                }],
                ['Copy JSON', async () => {
                    text.focus(); text.select();
                    try { await navigator.clipboard.writeText(report); label.textContent = 'Copied. Diagnostics stay on this device.'; }
                    catch (_) { label.textContent = 'Text selected. Use Ctrl+C or Command+C to copy.'; }
                }],
                ['Close', () => { pane.remove(); canvas()?.focus({preventScroll: true}); }]]) {
                const button = document.createElement('button'); button.textContent = name;
                button.style.cssText = 'padding:10px;margin-right:12px'; button.addEventListener('click', action); actions.append(button);
            }
            pane.append(label, actions, text); document.body.append(pane); text.focus();
        }
    };
})();
