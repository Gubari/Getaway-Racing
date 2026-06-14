extends SceneTree
## Generise city_navmesh.tres iz trenutne mape.
## Pokreni posle izmene zidova/kolizije u city.tscn:
##   godot --headless --path . --script res://tools/bake_navmesh.gd

const OUT_PATH := "res://scenes/levels/city_navmesh.tres"

func _initialize() -> void:
	var main_ps: PackedScene = load("res://scenes/main/main.tscn")
	var main: Node = main_ps.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame
	var nav: NavigationRegion2D = main.get_node("NavRegion")
	if not nav.has_method("bake_to_resource"):
		push_error("NavRegion missing bake_to_resource()")
		quit(1)
		return
	var np: NavigationPolygon = nav.bake_to_resource()
	if np == null or np.get_polygon_count() == 0:
		push_error("Nav bake produced empty mesh")
		quit(1)
		return
	var err := ResourceSaver.save(np, OUT_PATH)
	if err != OK:
		push_error("Failed to save navmesh: %s" % error_string(err))
		quit(1)
		return
	print("Saved ", OUT_PATH, " polygons=", np.get_polygon_count())
	quit()
