extends Node3D
## Visual leases only: each weapon still owns its ballistic state and collision.
## 192 covers all 16 ordinary debug-wave ships (<=9 concurrent balls each),
## 12 flagship balls and two player balls, with reserve. Normal play caps at six ships.
const CAPACITY := 192
var free_nodes: Array[MeshInstance3D] = []
var leased: Dictionary = {}
var sphere: SphereMesh
var friendly: StandardMaterial3D
var hostile: StandardMaterial3D
var peak_active := 0
var exhaustion_count := 0

func setup(game: Node3D) -> void:
	sphere = SphereMesh.new()
	sphere.radius = 0.4
	sphere.height = 0.8
	sphere.radial_segments = 8
	sphere.rings = 4
	friendly = game._material(Color("e8c286"), 1.0)
	hostile = game._material(Color("ffad66"), 1.5)
	for i in CAPACITY:
		var node := MeshInstance3D.new()
		node.mesh = sphere
		node.visible = false
		node.set_meta("projectile_pool", self)
		add_child(node)
		free_nodes.append(node)

func acquire(at: Vector3, enemy := false) -> MeshInstance3D:
	if free_nodes.is_empty():
		exhaustion_count += 1
		return null
	var node: MeshInstance3D = free_nodes.pop_back()
	leased[node] = true
	node.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * (1.0 if enemy else 0.8)), at)
	node.material_override = hostile if enemy else friendly
	node.visible = true
	peak_active = maxi(peak_active, leased.size())
	return node

func release(node: MeshInstance3D) -> void:
	if not is_instance_valid(node): return
	if not leased.has(node):
		# Older test fixtures may inject an unpooled shot. Do not retain foreign nodes.
		if not node.has_meta("projectile_pool"): node.queue_free()
		return
	leased.erase(node)
	node.visible = false
	node.transform = Transform3D.IDENTITY
	free_nodes.append(node)
