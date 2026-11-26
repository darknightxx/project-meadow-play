extends SceneTree
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var packs := args[0]
	var output := args[1]
	for name in ["index.world.pck","index.polyart.pck","index.polyart_s3tc.pck","index.polyart_s3tc2.pck"]:
		if not ProjectSettings.load_resource_pack(packs.path_join(name), false):
			push_error("Cannot load " + name)
			quit(1)
			return
	var path := "res://assets/remaster/polyart/kit.json"
	if not FileAccess.file_exists(path):
		push_error("No Polyart kit catalog in published packs")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	var f := FileAccess.open(output.path_join("kit.json"), FileAccess.WRITE)
	f.store_string(FileAccess.get_file_as_string(path))
	f.close()
	var catalog := {}
	for folder in ["models","models_lod1","models_lod2"]:
		var dir: String = "res://assets/remaster/polyart/" + folder
		catalog[folder] = Array(DirAccess.get_files_at(dir))
	var existing := {}
	for id in ["farm_house_variation_01_nointerior","farm_house_variation_02_nointerior","farm_house_variation_03_nointerior","farm_house_variation_04_nointerior","farm_farmhouse","farm_shed_01","farm_boatshed","temple_cathedralmodule_01","temple_lionstatue","farm_bench_01"]:
		var levels := {}
		for folder in ["models","models_lod1","models_lod2"]:
			var resource_path: String = "res://assets/remaster/polyart/" + folder + "/" + id + ".res"
			if ResourceLoader.exists(resource_path):
				var mesh := load(resource_path)
				if mesh is Mesh:
					var aabb: AABB = mesh.get_aabb()
					var triangles := 0
					for surface in mesh.get_surface_count():
						triangles += mesh.surface_get_array_index_len(surface) / 3
					levels[folder] = {"path":resource_path,"size":[aabb.size.x,aabb.size.y,aabb.size.z],"triangles":triangles}
				else:
					levels[folder] = {"path":resource_path,"type":mesh.get_class() if mesh else "NULL"}
		existing[id] = levels
	catalog["selected"] = existing
	var out := FileAccess.open(output.path_join("inventory.json"), FileAccess.WRITE)
	out.store_string(JSON.stringify(catalog,"  "))
	out.close()
	print("ASSET_PROBE_OK ", existing.size(), " building/prop IDs inspected")
	quit(0)

