extends SceneTree

var textures: Dictionary = {}
var materials: Dictionary = {}
var manifest: Dictionary = {"models":{},"textures":{},"missing":[]}
var asset_root := "res://assets/remaster/polyart/"
var output_root := ""

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	output_root = args[1].path_join("previewassets")
	assert(DirAccess.make_dir_recursive_absolute(output_root)==OK,output_root)
	assert(ProjectSettings.load_resource_pack(args[1].get_base_dir().path_join("compiled/thai-town.pck"),false))
	for pack: String in ["index.world.pck","index.mapkit.pck","index.pck","index.polyart.pck","index.polyart_s3tc.pck","index.polyart_s3tc2.pck"]:
		assert(ProjectSettings.load_resource_pack(args[0].path_join(pack), false), pack)
	var ids: Array[String] = ["farm_house_variation_01_nointerior","farm_house_variation_02_nointerior","farm_house_variation_03_nointerior","farm_house_variation_04_nointerior","farm_farmhouse","farm_shed_01","farm_boatshed","farm_shed_crops","farm_bench_01","farm_cart_01","farm_barrel_01","farm_box_01","farm_sign_03","farm_flowerspot_c_01","farm_flowerspot_b_01","farm_gentree_b_fulltree_01","farm_gentree_bush_04","temple_olivetree_01","temple_cypress_02","temple_oleander_02","temple_lionstatue","temple_arch_01","temple_arch_03","temple_brazier_02","temple_wall_400x400_02","temple_statuecomplete_a","temple_chest_01","east_lamp_ground_01"]
	for id: String in ids:
		var path := ""
		# One fixed mobile budget for this exploration build; no quality changes while walking.
		for folder: String in ["models_lod2","models_lod1","models"]:
			var candidate := asset_root + folder + "/" + id + ".res"
			if ResourceLoader.exists(candidate):
				path = candidate
				break
		copy_mesh(id, path)
	for id: String in ["wat","belltower","thai_house","thai_shop","prop_sala"]:
		copy_mesh(id, "res://maps/willowbrook/willow/" + id + ".res")
	for item: Array in [["ground_grass",asset_root+"textures/grass_02_c_green.png"],["ground_dirt",asset_root+"textures/t_farm_dirt_flat_ch.png"],["ground_stone",asset_root+"textures/t_suntemple_stonefloor_01_c_ao.png"],["ground_tile",asset_root+"textures/t_suntemple_stonefloor_02_c_ao.png"],["ground_layout","res://maps/willowbrook/polyart_layout.png"]]:
		if ResourceLoader.exists(item[1]):
			var tex: Texture2D = load(item[1])
			var saved := copy_texture(tex, str(item[0]))
			manifest["textures"][item[0]] = saved.resource_path if saved else ""
	var file := FileAccess.open(output_root.path_join("manifest.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest,"  "))
	print("ASSET_PREPARED ", JSON.stringify({"models":manifest.models.size(),"textures":textures.size(),"missing":manifest.missing}))
	quit(0 if manifest.models.size() >= 20 and manifest.missing.is_empty() else 1)

func copy_mesh(id: String, path: String) -> void:
	if path == "" or not ResourceLoader.exists(path):
		manifest.missing.append({"id":id,"path":path})
		return
	var original = load(path)
	if not original is ArrayMesh:
		manifest.missing.append({"id":id,"type":original.get_class() if original else "null"})
		return
	var mesh := ArrayMesh.new()
	var triangles := 0
	for i in original.get_surface_count():
		var arrays: Array = original.surface_get_arrays(i)
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var source_mat: Material=original.surface_get_material(i)
		if source_mat==null and FileAccess.file_exists("res://maps/willowbrook/willow/"+id+".jpg"):
			source_mat=StandardMaterial3D.new()
			source_mat.albedo_texture=ImageTexture.create_from_image(Image.load_from_file("res://maps/willowbrook/willow/"+id+".jpg"))
		mesh.surface_set_material(i, copy_material(source_mat))
		triangles += int(arrays[Mesh.ARRAY_INDEX].size()/3) if arrays[Mesh.ARRAY_INDEX] != null else int(arrays[Mesh.ARRAY_VERTEX].size()/3)
	var dest := "res://previewassets/"+id+".res"
	assert(ResourceSaver.save(mesh,output_root.path_join(dest.get_file()),ResourceSaver.FLAG_COMPRESS)==OK,dest)
	var aabb := mesh.get_aabb()
	manifest.models[id] = {"source":path,"triangles":triangles,"size":[aabb.size.x,aabb.size.y,aabb.size.z]}

func copy_texture(tex: Texture2D, named: String = "") -> Texture2D:
	if tex == null:
		return null
	var key := tex.resource_path
	if key == "": key = str(tex.get_instance_id())
	if named != "": key += "#"+named
	if textures.has(key): return textures[key]
	var img: Image = tex.get_image()
	if img == null or img.is_empty():
		push_error("Empty texture: " + key)
		return null
	if img.is_compressed(): assert(img.decompress()==OK,key)
	var limit := 1024 if named == "ground_layout" else 512
	if maxi(img.get_width(),img.get_height()) > limit:
		var factor := float(limit)/maxi(img.get_width(),img.get_height())
		img.resize(maxi(1,int(img.get_width()*factor)),maxi(1,int(img.get_height()*factor)),Image.INTERPOLATE_LANCZOS)
	img.clear_mipmaps()
	var dest := "res://previewassets/"+(named if named != "" else "texture_%03d"%textures.size())+".png"
	assert(img.save_png(output_root.path_join(dest.get_file()))==OK,dest)
	# Leave compression to the normal PNG importer. Serializing ImageTexture would inflate the exported PCK.
	var imported := "res://.godot/imported/"+dest.get_file()+"-"+dest.md5_text()+".ctex"
	var cfg := ConfigFile.new()
	cfg.set_value("remap","importer","texture")
	cfg.set_value("remap","type","CompressedTexture2D")
	cfg.set_value("remap","path",imported)
	cfg.set_value("remap","metadata",{"vram_texture":false})
	cfg.set_value("deps","source_file",dest)
	cfg.set_value("deps","dest_files",PackedStringArray([imported]))
	cfg.set_value("params","compress/mode",0)
	cfg.set_value("params","mipmaps/generate",true)
	cfg.set_value("params","process/fix_alpha_border",true)
	cfg.set_value("params","detect_3d/compress_to",0)
	cfg.save(output_root.path_join(dest.get_file()+".import"))
	var result := CompressedTexture2D.new()
	result.take_over_path(dest)
	textures[key] = result
	return result

func copy_material(source: Material) -> Material:
	if source == null: return StandardMaterial3D.new()
	var key := str(source.get_instance_id())
	if materials.has(key): return materials[key]
	var mat := StandardMaterial3D.new()
	mat.roughness = 0.9
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if source is ShaderMaterial:
		var tex = source.get_shader_parameter("albedo_tex")
		if tex is Texture2D: mat.albedo_texture = copy_texture(tex)
		var shader_path: String = source.shader.resource_path if source.shader else ""
		if "foliage" in shader_path or "leaves" in source.resource_path or "grass" in shader_path:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			mat.alpha_scissor_threshold = 0.35
			mat.albedo_color=Color(.72,.88,.63)
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	elif source is StandardMaterial3D:
		mat.albedo_color = source.albedo_color
		mat.albedo_texture = copy_texture(source.albedo_texture)
		mat.vertex_color_use_as_albedo = source.vertex_color_use_as_albedo
		mat.cull_mode = source.cull_mode
		mat.transparency = source.transparency
	materials[key] = mat
	return mat

