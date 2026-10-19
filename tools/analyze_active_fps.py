"""Summarize Blackwater state-specific frame evidence and production-scene A/Bs."""
import argparse
import bisect
import json
import math
from collections import defaultdict
from pathlib import Path


def stats(values):
    if not values:
        return None
    values = sorted(values)
    quantile = lambda p: values[math.ceil((len(values) - 1) * p)]
    return dict(n=len(values), mean=sum(values) / len(values), median=quantile(.5),
                p95=quantile(.95), p99=quantile(.99), maximum=values[-1])


def summarize(report):
    samples = report.get('samples', [])
    times = [row['t_ms'] for row in samples]
    states = defaultdict(list)
    for row in report.get('engine_frames', []):
        if len(row) >= 3:
            state = row[2]  # Schema 3 tags every interval; transitions are separate.
        else:
            index = bisect.bisect_right(times, row[0]) - 1
            if index < 0:
                continue
            sample = samples[index]
            state = sample['game_state'] + ('_PAUSED' if sample['paused'] else '')
        states[state].append(row[1])
    output = {'build': report.get('build'), 'state_attribution':
              'per frame' if report.get('schema', 0) >= 3 else 'preceding 200 ms sample; transition uncertainty',
              'states': {key: dict(frame_ms=stats(values), fps=1000 * len(values) / sum(values))
                         for key, values in states.items()}, 'cases': []}
    for case in report.get('active_fps_investigation', {}).get('results', []):
        rows = case['rows']
        ticks = sum(row['cpu']['calls'].get('physics_tick', 0) for row in rows)
        groups = sorted(set(key for row in rows for key in row['cpu']['us']))
        output['cases'].append(dict(
            case=case['case'], interrupted=case['interrupted'], summary=case['summary'],
            browser_raf=case.get('browser_raf_summary'),
            cpu_ms_per_gameplay_tick={key: sum(row['cpu']['us'].get(key, 0) for row in rows) / max(1, ticks) / 1000
                                      for key in groups},
            inclusive_cpu_ms_per_render={key: stats([row['cpu']['us'].get(key, 0) / 1000 for row in rows])
                                         for key in groups},
            engine_physics_ms=stats([row['physics_ms'] for row in rows]),
            engine_process_ms=stats([row['process_ms'] for row in rows]),
            physics_ticks_per_render=stats([row['physics_ticks'] for row in rows]),
            gameplay_ticks=ticks,
            wave_queries=sum(row['cpu']['calls'].get('wave_queries', 0) for row in rows),
            counters={key: stats([row[key] for row in rows]) for key in
                      ['draw_calls', 'render_primitives', 'render_objects', 'nodes', 'resources', 'static_bytes', 'video_bytes']},
            inventory=case['inventory']))
    return output


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('report', type=Path)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    result = summarize(json.loads(args.report.read_text()))
    text = json.dumps(result, indent=2)
    if args.output:
        args.output.write_text(text + '\n')
    else:
        print(text)
