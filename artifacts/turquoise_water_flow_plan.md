# Turquoise water and flow zones — design proposal

18 October 2026. Planning only; gameplay implementation has not started.

## Scope

Restore the supplied references' turquoise water, broad moving surface bands and
small pale crest caps. Make the existing directional waves share that style.
Add visible optional flow zones that multiply the player's unboosted forward
sailing speed by 1.25 while inside, with no stacking.

Base: latest `origin/main`, `61ba63f`, the lighthouse survival arena. Preserve
the arena, timed cutter waves, steering, cannon controls, damage and retry.
The separate draft [journey PR #6](https://github.com/kickflip-games/ludum_dare_60/pull/6)
by EL-MZ overlaps movement, water and speed boosts; do not import that voyage or
its 9.5/12.5 m/s wind system into this arena plan.

## Planned checks

- Compare calm water, incoming crests, four overlapping waves and flow boundaries
  in matching native rendered views, including cannon and Reduced motion.
- Check boosted versus unboosted travel, overlap/re-entry, collision and arena
  return, fresh start, damage, win/loss and retry.
- Preserve CPU/GPU surface agreement, projectile-water contacts and countersteering.
- Run relevant ocean, wave, arena, survival, cannon and lifecycle regressions
  after implementation. Human fun, balance and comfort require playtesting.

Detailed tuning, source mapping and acceptance criteria will follow source review.
