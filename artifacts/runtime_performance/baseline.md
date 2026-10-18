# Runtime baseline — 2026-10-19

Captured before runtime edits, from the complete dirty working tree at `428207b`.
The isolated source is `build/runtime_performance/before/source`; it includes
concurrent user work and the earlier mine asset replacement. No GLB change is part
of this task. Engine 4.8.dev6, Compatibility, 1280×720, Apple M4 Pro.

Initial real native render: frame median ~6.89 ms, p99 ~7.7 ms. Large first-use
frame stalls are not reproduced on this machine/cache. Event CPU time: first player
shot 278 µs, first ordinary salvo 129 µs, simultaneous salvos 449 µs, first mine
1,171 µs; repeated mine/VFX bursts 215–282 µs. These timings exclude asynchronous
GPU work. A corrected run verifies the flagship launches (the initial fixture
predicted a moving muzzle while holding the hull fixed); final report uses that run.

Confirmed from code: each shot creates a sphere mesh, material and mesh node;
expiry frees its node. Each mine instantiates its model and builds ring geometry
and a shader material. Mine visuals also upload invariant wave settings every
update, including both physics and presentation updates. Particle and splash
visuals are already pooled. First-use shader compilation remains a hypothesis,
not a measured root cause. Browser and corrected native raw data will accompany
the final comparison. No FPS claim comes from headless or fixed-delta runs.

Initial WebGL run reproduced first-use spikes: player-shot phase maximum
131.5 ms, enemy-shot 26.0 ms and first-mine 76.4 ms, versus idle 10.5 ms;
phase medians stayed 8.3 ms. JavaScript-side event CPU calls were only 1.1 ms,
0.5 ms and 2.1 ms respectively. GPU/driver shader work is a plausible cause
of the remaining stall; there are no GPU timer-query measurements to prove it.
