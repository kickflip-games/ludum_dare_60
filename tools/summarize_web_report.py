"""Summarize exported diagnostics by scene/configuration using real browser frames.

Keeps full source JSON intact. Excludes paused, hidden/unfocused samples and two
seconds around configuration changes. Title and sailing results stay separate.
"""
import argparse
import bisect
from collections import defaultdict
import json
import math
from pathlib import Path


def summary(values):
    values = sorted(values)
    q = lambda p: values[math.ceil((len(values) - 1) * p)]
    return dict(frames=len(values), seconds=sum(values) / 1000,
                mean_ms=sum(values) / len(values), median_ms=q(.5),
                p95_ms=q(.95), p99_ms=q(.99), max_ms=values[-1],
                slow_over_33_ms=sum(v > 33.334 for v in values))


def summarize(path):
    data = json.loads(path.read_text())
    samples = data['samples']
    times = [s['t_ms'] for s in samples]
    changes = [e['t_ms'] for e in data['events'] if e['kind'] in
               ('resolution', 'audio_mode', 'music_mode', 'ocean_mode', 'recording_started', 'focus', 'pause', 'diagnostics_open', 'diagnostics_close')]
    offset = data['engine_clock_ms'] - data['browser_clock_ms']
    groups = defaultdict(list)
    for stamp, interval in data['browser']['raf_frames']:
        t = stamp + offset
        i = bisect.bisect_right(times, t) - 1
        if i < 0 or t - times[i] > 350 or any(abs(t - c) < 2000 for c in changes):
            continue
        s = samples[i]
        b = s['browser'] or {}
        if s['paused'] or s.get('diagnostics_panel_open') or not s['window_focused']:
            continue
        if b.get('visibility') != 'visible' or not b.get('canvas_focus'):
            continue
        audio = s['audio']
        key = (s['game_state'], tuple(s.get('viewport_internal', s.get('render_target', []))), audio['mode'],
               audio['music_playback_type'], audio['ocean_generator'])
        groups[key].append(interval)
    music = [e for e in data['browser']['events'] if e['kind'] == 'audio_sample_start'
             and 41 < e['data'].get('duration_s', 0) < 42]
    return dict(file=str(path), build=data['build'],
                configurations=[dict(state=k[0], render=k[1], audio_mode=k[2],
                                     music_type=k[3], generator=k[4], **summary(v))
                                for k, v in groups.items() if v],
                music_sample_starts=music,
                generator_events=[e for e in data['events'] if 'generator' in e['kind']],
                browser=data['browser']['environment'])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('reports', nargs='+', type=Path)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    results = [summarize(p) for p in args.reports]
    text = json.dumps(results, indent=2)
    if args.output:
        args.output.write_text(text + '\n')
        print(args.output)
    else:
        print(text)


if __name__ == '__main__':
    main()
