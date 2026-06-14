extends NavigationRegion2D
## Navmesh: pre-pečen u editoru (city_navmesh.tres). Runtime rebake samo za barikadu.
## Vlasnik: B (glue za AI).

@export var agent_radius: float = 22.0
@export var fallback_area: Rect2 = Rect2(0, 0, 2048, 2048)
## Ukljuci samo ako nema pre-pečenog mesha ili se mapa promenila.
@export var bake_on_ready: bool = false

func _ready() -> void:
	add_to_group("nav_region")
	if bake_on_ready or _needs_runtime_bake():
		rebake()

func _needs_runtime_bake() -> bool:
	return navigation_polygon == null or navigation_polygon.get_polygon_count() == 0

## Pozivaju prepreke (barikada). Ceka frejm pa ispece nanovo.
func rebake() -> void:
	await get_tree().physics_frame
	_bake()

## Za tools/bake_navmesh.gd — generise NavigationPolygon bez menjanja scene.
func bake_to_resource() -> NavigationPolygon:
	var area := _find_arena()
	var outline := PackedVector2Array([
		area.position,
		Vector2(area.end.x, area.position.y),
		area.end,
		Vector2(area.position.x, area.end.y),
	])
	var np := NavigationPolygon.new()
	np.agent_radius = agent_radius
	np.parsed_geometry_type = NavigationPolygon.PARSED_GEOMETRY_STATIC_COLLIDERS
	np.source_geometry_mode = NavigationPolygon.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	np.source_geometry_group_name = &"walls"
	var src := NavigationMeshSourceGeometryData2D.new()
	NavigationServer2D.parse_source_geometry_data(np, src, _bake_root())
	src.add_traversable_outline(outline)
	NavigationServer2D.bake_from_source_geometry_data(np, src)
	return np

func _bake() -> void:
	navigation_polygon = bake_to_resource()

func _bake_root() -> Node:
	var parent := get_parent()
	if parent != null:
		return parent
	return get_tree().current_scene

func _find_arena() -> Rect2:
	var parent := get_parent()
	if parent != null:
		for child in parent.get_children():
			if child.has_method("get_arena_rect"):
				return child.get_arena_rect()
	if get_tree().current_scene != null:
		for child in get_tree().current_scene.get_children():
			if child.has_method("get_arena_rect"):
				return child.get_arena_rect()
	return fallback_area
