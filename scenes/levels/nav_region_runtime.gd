extends NavigationRegion2D
## Pece navmesh u RUNTIME-u za nivo. Parsira staticke kolizije scene
## (zidovi: StaticBody2D ILI TileMapLayer kolizija) i isece ih iz arene.
## Podrzava rebake() (grupa "nav_region") za barikadu (moc).
## Radi u bilo kom nivou koji ima get_arena_rect(). Vlasnik: B (glue za AI).

@export var agent_radius: float = 22.0   # pola sirine auta + margina; uze ulice su ~96px
@export var fallback_area: Rect2 = Rect2(0, 0, 2048, 2048)

func _ready() -> void:
	add_to_group("nav_region")
	rebake()   # pece posle jednog frejma (da se tilemap kolizije slegnu)

## Pozivaju prepreke (barikada) i start. Ceka frejm pa ispece nanovo.
func rebake() -> void:
	await get_tree().physics_frame
	_bake()

func _bake() -> void:
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
	# Parsiraj SAMO slojeve u grupi "walls" (Sidewalk/Buildings/Outline) -> Road ostaje vozan.
	np.source_geometry_mode = NavigationPolygon.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	np.source_geometry_group_name = &"walls"

	var src := NavigationMeshSourceGeometryData2D.new()
	NavigationServer2D.parse_source_geometry_data(np, src, get_tree().current_scene)
	src.add_traversable_outline(outline)   # KLJUC: arena = prohodna podloga (iz koje se sece kolizija)
	NavigationServer2D.bake_from_source_geometry_data(np, src)
	navigation_polygon = np

## Arena: prvo roditelj (ako je nivo), pa bilo koji cvor u sceni sa get_arena_rect().
func _find_arena() -> Rect2:
	var root := get_parent()
	if root and root.has_method("get_arena_rect"):
		return root.get_arena_rect()
	for child in get_tree().current_scene.get_children():
		if child.has_method("get_arena_rect"):
			return child.get_arena_rect()
	return fallback_area
