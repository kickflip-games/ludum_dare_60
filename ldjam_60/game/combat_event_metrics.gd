extends RefCounted
## Opt-in CPU counters. Only the combat benchmark enables recording.
static var enabled := false
static var samples: Dictionary = {}

static func start() -> int:
	return Time.get_ticks_usec() if enabled else 0

static func finish(label: String, started: int) -> void:
	if not enabled: return
	var us := Time.get_ticks_usec() - started
	if not samples.has(label): samples[label] = {"calls": 0, "total_us": 0, "max_us": 0}
	var record: Dictionary = samples[label]
	record.calls += 1
	record.total_us += us
	record.max_us = maxi(record.max_us, us)
