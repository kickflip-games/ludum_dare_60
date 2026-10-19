extends RefCounted
## Inclusive CPU timings, enabled only by the bounded production-scene A/B run.
## Nested categories overlap; never add their totals together.
static var enabled := false
static var totals := {}
static var calls := {}

static func start() -> int:
	return Time.get_ticks_usec() if enabled else 0

static func finish(label: String, started: int) -> void:
	if not enabled: return
	totals[label] = totals.get(label, 0) + Time.get_ticks_usec() - started
	calls[label] = calls.get(label, 0) + 1

static func take() -> Dictionary:
	var result := {"us": totals, "calls": calls}
	totals = {}
	calls = {}
	return result
