# Deck camera and turbulence implementation

Work in progress, 2026-10-18 (Pacific/Auckland).

Base: `4f464ecc44ca3df609a4125c7fd050874e3aa85b` (fresh origin/main).
Branch: `codex/turbulence-deck-camera`. Engine: Godot 4.8.dev7.c971f93e7;
Compatibility renderer; target viewport 1280 x 720.

Player experience: stand on the wooden deck, see the lantern left and the real
cannon right, and feel directional crests lift, bank and settle the hull.
Camera-only motion must carry this experience before adding synchronized effects.

The approved [implementation plan](TURBULENCE_CAMERA_IMPLEMENTATION_PLAN.md)
is the acceptance contract. Preserve four physical waves, scheduled heights,
force/yaw limits, countersteering, finite encounters/recovery, five-point
flotation, actual-motion wakes, projectile contacts and current controls.

Overlap checked: [draft PR #3](https://github.com/kickflip-games/ludum_dare_60/pull/3)
by avivajpeyi changes controls and sextant/restart timing, with future overlap in
crossing.gd and mode tests. This branch preserves the baseline input contracts.

Planned checks: deterministic calm/front/port/starboard/oblique/four-wave
production fixtures; 30/60/120 Hz, long gap and retry; camera clearance; cannon,
sighting, damage and route regression suites; native motion captures; isolated
web export and actual browser measurements when available. Subjective comfort
and human playtesting will be identified separately from scripted evidence.
