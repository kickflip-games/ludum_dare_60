extends RefCounted
## World compass: north = -Z, east = +X. Positive turns are clockwise/starboard.
## Celestial directions are fixed references, separate from landmark bearings.

static func bearing_to(origin: Vector3, destination: Vector3, fallback: float = 0.0) -> float:
	var offset := Vector2(destination.x - origin.x, destination.z - origin.z)
	# A coincident target has no bearing; retain the bow heading instead of atan2(0, 0).
	return atan2(offset.x, -offset.y) if offset.length_squared() > 0.000001 else fallback


static func compass_degrees(angle: float, step_degrees: int = 1) -> int:
	# Round before the final modulo so 359.9 degrees displays 000, never 360.
	return (roundi(fposmod(rad_to_deg(angle), 360.0) / step_degrees) * step_degrees) % 360


static func signed_turn(heading: float, bearing: float) -> float:
	# Shortest correction in [-PI, PI); exactly astern is the equivalent -PI tie.
	return wrapf(bearing - heading, -PI, PI)
