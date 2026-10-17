@tool
extends Marker3D
## Editable regional target; bearings refer to this water, never to a star position.
@export var display_name: String = "Landmark"
@export var radius: float = 30.0
@export var star_name: String = "North Star"
@export var star_direction := Vector3(0, 0.8290376, -0.5591929)
