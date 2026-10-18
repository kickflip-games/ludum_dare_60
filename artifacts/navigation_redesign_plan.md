# Navigation redesign proposal

18 October 2026. Planning only; no gameplay implementation is authorized by this document.

## Requested experience

Keep the sextant visible in a gameplay corner, make the active red or blue guiding
star visible from the helm without looking up, remove the sighting button, shorten
star-following legs to roughly 15 seconds, and make sailing faster. Consider
optional wind regions that reward deliberate steering with extra speed.

## Coordination

Open draft [PR #5](https://github.com/kickflip-games/ludum_dare_60/pull/5), by
avivajpeyi, proposes replacing the voyage with a lighthouse combat arena. That
conflicts with retaining a journey through successive stars. At inspection it
changed only changelog.md. This proposal assumes the voyage remains; that product
direction needs agreement before gameplay work.

## Planned evidence

Review current bearing, sky, HUD, voyage, movement and encounter code. Specify
positive, negative, lifecycle and rendered checks for the proposed behaviors.
All numbers are starting hypotheses until tested in engine and by a player.
