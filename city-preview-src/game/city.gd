extends Node3D

const BUILD_ID := "meadow-city-preview-20261126-r1"
var map: Dictionary
var decor: Dictionary
var manifest: Dictionary
var camera: Camera3D
var sun: DirectionalLight3D
var environment: Environment
var models: Dictionary = {}
var material_cache: Dictionary = {}
var water_drops: Array[MeshInstance3D] = []
var camera_mode := "overview"
var player := Vector3(80,0,83)
var yaw := 0.0
var pitch := -0.12
var eye_height := 1.65
var touch_move := Vector2.ZERO
var prayer := false
var coins := 100
var donations := 0
var clock := 0.0
var status_clock := 0.0
var message := ""
var command_callback
var browser_window
var capture_path := ""
var capture_view := "overview"
var capture_frames := 0
var mesh_count := 0
var triangle_count := 0

func _ready() -> void:
	map = JSON.parse_string(FileAccess.get_file_as_string("res://source-map.json"))
	decor = JSON.parse_string(FileAccess.get_file_as_string("res://decor.json"))
	manifest = JSON.parse_string(FileAccess.get_file_as_string("res://previewassets/manifest.json"))
	build_environment()
	build_terrain()
	build_buildings()
	build_plaza()
	build_gardens()
	build_interior()
	build_portals()
	camera = Camera3D.new()
	add_child(camera)
	camera.fov = 62
	camera.far = 320
	camera.near = 0.08
	set_view("overview")
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--capture" and i+1 < args.size(): capture_path=args[i+1]
		if args[i] == "--view" and i+1 < args.size(): capture_view=args[i+1]
		if args[i] == "--audit":
			run_audit(args[i+1] if i+1<args.size() else "")
	if capture_path != "": set_view(capture_view)
	if OS.has_feature("web"):
		browser_window=JavaScriptBridge.get_interface("window")
		command_callback=JavaScriptBridge.create_callback(_browser_command)
		browser_window.cityCommand=command_callback
		browser_window.cityReady=true
	print("CITY_READY ", BUILD_ID, " models=",mesh_count," triangles=",triangle_count)

func build_environment() -> void:
	var world := WorldEnvironment.new()
	environment=Environment.new()
	world.environment=environment
	environment.background_mode=Environment.BG_COLOR
	environment.background_color=Color("bfcfd0")
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color=Color("e4e5dc")
	environment.ambient_light_energy=0.42
	environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	add_child(world)
	sun=DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-48,-34,0)
	sun.light_color=Color("fff0cf")
	sun.light_energy=0.8
	sun.shadow_enabled=true
	sun.directional_shadow_max_distance=150
	sun.directional_shadow_mode=DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	add_child(sun)

func mat(color: Color, metallic: float=0.0) -> StandardMaterial3D:
	var key := str(color)+str(metallic)
	if material_cache.has(key): return material_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color=color
	m.metallic=metallic
	m.roughness=0.55 if metallic>0 else 0.92
	material_cache[key]=m
	return m

func shape(mesh: Mesh, pos: Vector3, color: Color, parent: Node3D=null, metallic: float=0) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh=mesh
	instance.material_override=mat(color,metallic)
	(parent if parent else self).add_child(instance)
	instance.position=pos
	return instance

func box(pos: Vector3, size: Vector3, color: Color, parent: Node3D=null) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size=size
	return shape(mesh,pos,color,parent)

func cylinder(pos: Vector3, radius: float, height: float, color: Color, top: float=-1, parent: Node3D=null) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius=radius
	mesh.top_radius=top if top>=0 else radius
	mesh.height=height
	mesh.radial_segments=48
	return shape(mesh,pos,color,parent)

func orb(pos: Vector3, scale_v: Vector3, color: Color, parent: Node3D=null) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius=1
	mesh.height=2
	mesh.radial_segments=24
	mesh.rings=12
	var obj := shape(mesh,pos,color,parent,0.35 if color==Color("cc9d46") else 0)
	obj.scale=scale_v
	return obj

func model(id: String, pos: Vector3, max_size: Vector3, rot: float=0) -> Node3D:
	var path := "res://previewassets/"+id+".res"
	if not ResourceLoader.exists(path): return null
	if not models.has(id): models[id]=load(path)
	var mesh: Mesh=models[id]
	var aabb := mesh.get_aabb()
	var pivot := Node3D.new()
	add_child(pivot)
	pivot.position=pos
	pivot.rotation.y=deg_to_rad(rot)
	var mesh_node := MeshInstance3D.new()
	mesh_node.mesh=mesh
	pivot.add_child(mesh_node)
	var size := aabb.size
	if int(abs(rot))%180==90: size=Vector3(size.z,size.y,size.x)
	var s := minf(max_size.x/maxf(size.x,0.01),minf(max_size.y/maxf(size.y,0.01),max_size.z/maxf(size.z,0.01)))
	mesh_node.scale=Vector3.ONE*s
	mesh_node.position=Vector3(-aabb.get_center().x,-aabb.position.y,-aabb.get_center().z)*s
	mesh_count+=1
	triangle_count+=int(manifest.models.get(id,{}).get("triangles",0))
	return pivot

func ground_height(x: float, z: float) -> float:
	var ix := clampi(int(floor(x-.5)),0,158)
	var iz := clampi(int(floor(z-.5)),0,158)
	var fx := clampf(x-.5-ix,0,1)
	var fz := clampf(z-.5-iz,0,1)
	return lerpf(lerpf(map.heights[iz][ix],map.heights[iz][ix+1],fx),lerpf(map.heights[iz+1][ix],map.heights[iz+1][ix+1],fx),fz)

func build_terrain() -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in 160:
		for x in 160:
			for corner: Vector2i in [Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,0),Vector2i(1,1),Vector2i(0,1)]:
				var px := x+corner.x
				var pz := z+corner.y
				tool.set_uv(Vector2(px,pz)/160)
				tool.add_vertex(Vector3(px,ground_height(px,pz),pz))
	tool.generate_normals()
	tool.index()
	var terrain := MeshInstance3D.new()
	terrain.mesh=tool.commit()
	var material := ShaderMaterial.new()
	material.shader=load("res://ground.gdshader")
	for name: String in ["grass","dirt","stone","tile","layout"]:
		var path := "res://previewassets/ground_"+name+".res"
		if ResourceLoader.exists(path): material.set_shader_parameter(name+"_tex",load(path))
	terrain.material_override=material
	add_child(terrain)
	# River surface and the two existing bridge decks.
	box(Vector3(139,-.94,89),Vector3(42,.06,142),Color("408f9e"))
	box(Vector3(139,4.69,9),Vector3(42,.04,18),Color("589da2"))
	box(Vector3(145.3,1.88,18.9),Vector3(9.8,5.65,.16),Color("9bd1cf"))
	for bridge: Dictionary in decor.bridges:
		var width: float=bridge.x1-bridge.x0
		var z: float=(bridge.y0+bridge.y1)*.5
		box(Vector3((bridge.x0+bridge.x1)*.5,.62,z),Vector3(width+.6,.36,4),Color("c5b495"))
		for side in [-1,1]:
			box(Vector3((bridge.x0+bridge.x1)*.5,1.32,z+side*2),Vector3(width+.6,.5,.25),Color("e1cdae"))
	for wall: Dictionary in decor.retaining:
		box(Vector3((wall.x0+wall.x1)*.5,1,(wall.z0+wall.z1)*.5),Vector3(wall.x1-wall.x0,2,wall.z1-wall.z0),Color("9d9581"))
	for step in 14:
		box(Vector3(80,(14-step)*2.0/14-.08,38.25+step*.5),Vector3(6,.18,.51),Color("d8c8a8"))
	for side in [-1,1]:
		for i in 8:
			cylinder(Vector3(80+side*3.3,2.8-i*.25,38.3+i*.85),.11,.75,Color("c6aa65"))

func build_buildings() -> void:
	var variants := ["farm_house_variation_01_nointerior","farm_house_variation_02_nointerior","farm_house_variation_03_nointerior","farm_house_variation_04_nointerior"]
	var n := 0
	for building: Dictionary in decor.buildings:
		var id: String=variants[n%4]
		var rot := 0.0
		var dx: float=80.0-building.x
		var dz: float=76.0-building.z
		rot=(90.0 if dx>0 else 270.0) if absf(dx)>absf(dz) else (0.0 if dz>0 else 180.0)
		var maximum_height := 9.0
		var name: String=building.get("name",building.t)
		if building.t=="chapel":
			id="wat"
			maximum_height=14
		elif building.t=="bell_tower":
			id="belltower"
			maximum_height=10
		elif building.t=="inn": id="farm_farmhouse"
		elif name=="stable": id="farm_boatshed"
		elif name=="farm_shed": id="farm_shed_01"
		elif name=="item_shop" or name=="potion_shop": id="thai_shop"
		elif name in ["house_sw","house_se","house_s1"]: id="thai_house"
		var item := model(id,Vector3(building.x,building.y,building.z),Vector3(building.w*.96,maximum_height,building.d*.96),rot)
		if item and building.t=="chapel": item.name="TempleExterior"
		n+=1
	# Paired existing guardian sculptures make the temple entrance readable.
	for x in [75.6,84.4]: model("temple_lionstatue",Vector3(x,2,32),Vector3(1.8,1.8,1.2))
	# Markets stay on the western apron, clear of the main east-west avenue.
	for point: Vector2 in [Vector2(36,59),Vector2(38,70),Vector2(51,71),Vector2(55,61)]:
		model("farm_shed_crops",Vector3(point.x,ground_height(point.x,point.y),point.y),Vector3(4,3.2,3))
		model("farm_box_01",Vector3(point.x+1.8,ground_height(point.x,point.y),point.y+1.2),Vector3(.6,.65,.6))
	model("farm_cart_01",Vector3(32,0,55),Vector3(2.8,1.7,2.1),25)
	model("farm_cart_01",Vector3(106,0,49),Vector3(2.8,1.7,2.1),-30)
	model("prop_sala",Vector3(65,2,28),Vector3(8,7,7))
	for z in [139.0]:
		model("temple_arch_03",Vector3(80,0,z),Vector3(9,10,3),90)
	for x in range(18,73,4): model("temple_wall_400x400_02",Vector3(x,0,139),Vector3(4.2,2.3,1.3))
	for x in range(88,136,4): model("temple_wall_400x400_02",Vector3(x,0,139),Vector3(4.2,2.3,1.3))

func build_plaza() -> void:
	var base := Vector3(80,.36,76)
	cylinder(base+Vector3(0,.12,0),3.35,.24,Color("b7a984"))
	cylinder(base+Vector3(0,.34,0),3.0,.45,Color("dfcda5"))
	cylinder(base+Vector3(0,.59,0),2.82,.035,Color("4da4b1"))
	# Three lotus bowls, built for this preview; not mislabelled as a purchased asset.
	for tier in 3:
		var y := .85+tier*.7
		var radius := 1.55-tier*.43
		cylinder(base+Vector3(0,y-.25,0),.22,.7,Color("b7a16c"))
		cylinder(base+Vector3(0,y,0),radius*.38,.26,Color("d9c18c"),radius)
		cylinder(base+Vector3(0,y+.14,0),radius*.88,.025,Color("78c6cd"))
		for petal in 12:
			var a := petal*TAU/12
			var leaf := orb(base+Vector3(cos(a)*radius*.91,y+.06,sin(a)*radius*.91),Vector3(.17,.24,.34),Color("d9c18c"))
			leaf.rotation.y=-a
	for i in 42:
		var droplet := orb(base,Vector3(.035,.085,.035),Color("b8eced"))
		droplet.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		water_drops.append(droplet)
	for point: Vector2 in [Vector2(70,70),Vector2(90,70),Vector2(70,83),Vector2(90,83)]:
		model("farm_bench_01",Vector3(point.x,ground_height(point.x,point.y),point.y),Vector3(2,.65,1),90 if point.x<80 else -90)
		model("farm_flowerspot_c_01",Vector3(point.x,ground_height(point.x,point.y),point.y-1.5),Vector3(1.1,.7,1.1))

func build_gardens() -> void:
	var tree_points := [Vector2(63,21),Vector2(93,22),Vector2(64,33),Vector2(95,33),Vector2(66,65),Vector2(95,65),Vector2(67,88),Vector2(96,87),Vector2(30,79),Vector2(117,86),Vector2(101,114),Vector2(61,125),Vector2(18,88),Vector2(128,97),Vector2(127,122),Vector2(35,35),Vector2(48,130),Vector2(100,133)]
	for i in tree_points.size():
		var p: Vector2=tree_points[i]
		model("temple_olivetree_01" if i%3 else "farm_gentree_b_fulltree_01",Vector3(p.x,ground_height(p.x,p.y),p.y),Vector3(5,5.5,5))
		for offset: Vector2 in [Vector2(-1.5,.4),Vector2(1,1)]:
			var b := p+offset
			model("farm_gentree_bush_04",Vector3(b.x,ground_height(b.x,b.y),b.y),Vector3(1.3,.75,1.3))
	for p: Vector2 in [Vector2(62,31),Vector2(93,30)]: model("farm_bench_01",Vector3(p.x,2,p.y),Vector3(2,.65,1))
	for z in [48,59,95,110,126]:
		for x in [74,86]: model("east_lamp_ground_01",Vector3(x,ground_height(x,z),z),Vector3(.8,2.1,.8))

func build_interior() -> void:
	# The interior sits within the existing chapel footprint; exterior roof is hidden only while inside.
	var cream := Color("d5c6a8")
	box(Vector3(80,2.03,22.5),Vector3(7.5,.08,12),cream)
	box(Vector3(80,7.05,22.5),Vector3(7.8,.12,12.2),cream)
	box(Vector3(76.2,4.5,22.5),Vector3(.2,5,12),Color("c7b18b"))
	box(Vector3(83.8,4.5,22.5),Vector3(.2,5,12),Color("c7b18b"))
	box(Vector3(80,4.5,16.4),Vector3(7.8,5,.2),Color("887252"))
	for x in [76.7,83.3]:
		for z in [18,22,26]:
			cylinder(Vector3(x,4.35,z),.16,4.6,Color("a14f35"))
	box(Vector3(80,2.325,18.8),Vector3(3.6,.65,2.3),Color("a1814a"))
	box(Vector3(80,2.7,18.8),Vector3(3.2,.1,2),Color("d4b675"))
	# Simple newly built seated Buddha study, 2.2m above the podium.
	var gold := Color("cc9d46")
	cylinder(Vector3(80,2.86,18.8),1.05,.23,gold)
	orb(Vector3(80,3.15,18.8),Vector3(.92,.25,.56),gold)
	orb(Vector3(80,3.76,18.67),Vector3(.46,.69,.31),gold)
	orb(Vector3(80,4.55,18.68),Vector3(.265,.34,.255),gold)
	for side in [-1,1]:
		orb(Vector3(80+side*.09,4.57,18.913),Vector3(.055,.012,.008),Color("8b682c"))
	orb(Vector3(80,4.49,18.94),Vector3(.038,.067,.05),gold)
	orb(Vector3(80,4.41,18.921),Vector3(.062,.009,.009),Color("8b682c"))
	orb(Vector3(80,4.86,18.68),Vector3(.14,.16,.14),gold)
	cylinder(Vector3(80,5.0,18.68),.08,.22,gold,0)
	for side in [-1,1]:
		orb(Vector3(80+side*.28,4.48,18.68),Vector3(.065,.19,.08),gold)
		var arm := orb(Vector3(80+side*.42,3.58,18.91),Vector3(.14,.45,.15),gold)
		arm.rotation.z=side*.48
		orb(Vector3(80+side*.18,3.27,19.13),Vector3(.23,.07,.12),gold)
	for x in [77.5,82.5]: model("temple_lionstatue",Vector3(x,2.08,18.8),Vector3(.9,1.2,.7))
	for x in [78.6,80,81.4]: box(Vector3(x,2.11,23.7),Vector3(.95,.07,1.6),Color("774b3d"))
	model("temple_chest_01",Vector3(82.4,2.08,27.5),Vector3(.9,1,.6))
	box(Vector3(82.4,2.95,27.5),Vector3(.65,.05,.35),Color("c7ad6d"))
	box(Vector3(82.4,2.98,27.5),Vector3(.25,.01,.035),Color("302e29"))
	for x in [77.2,82.8]:
		model("temple_brazier_02",Vector3(x,2.05,20.8),Vector3(.55,1.1,.55))

func build_portals() -> void:
	for portal: Dictionary in map.portals:
		var x: float=portal.x+portal.w*.5
		var z: float=portal.y+portal.h*.5
		cylinder(Vector3(x,ground_height(x,z)+.04,z),.9,.05,Color("5d9f97"))

func is_walkable(x: float,z: float) -> bool:
	if x<.5 or z<.5 or x>=159.5 or z>=159.5: return false
	# New interior connection and the smaller fountain replace only their old collision cells.
	if x>76.45 and x<83.55 and z>20.2 and z<32.4:
		if x>81.8 and z>26.9 and z<28.1: return false
		return true
	if Vector2(x-80,z-76).length()<5.3:
		return Vector2(x-80,z-76).length()>3.45
	return map.walkable[int(z)][int(x)]=="."

func can_stand(at: Vector3) -> bool:
	for offset: Vector2 in [Vector2.ZERO,Vector2(.25,0),Vector2(-.25,0),Vector2(0,.25),Vector2(0,-.25)]:
		if not is_walkable(at.x+offset.x,at.z+offset.y): return false
	return true

func set_view(view: String) -> void:
	prayer=false
	camera_mode=view
	if view=="overview":
		camera.position=Vector3(141,91,168)
		camera.look_at(Vector3(80,0,75))
	elif view=="temple":
		camera.position=Vector3(102,24,53)
		camera.look_at(Vector3(80,6,23))
	elif view=="interior":
		player=Vector3(80,2,27.3)
		yaw=0
		pitch=0.07
		camera_mode="walk"
	elif view=="walk":
		player=Vector3(80,ground_height(80,83),83)
		yaw=0
		pitch=-.12
	elif view=="plaza":
		camera.position=Vector3(102,20,99)
		camera.look_at(Vector3(80,1,72))
	update_camera(0)

func _browser_command(arguments: Array) -> void:
	if arguments.is_empty(): return
	var command: Dictionary=JSON.parse_string(str(arguments[0]))
	match str(command.get("type","")):
		"view": set_view(str(command.get("value","overview")))
		"move": touch_move=Vector2(float(command.get("x",0)),float(command.get("y",0)))
		"look":
			yaw-=float(command.get("x",0))*.004
			pitch=clampf(pitch-float(command.get("y",0))*.004,-1.15,1.0)
		"pray":
			if inside() and player.z<26: prayer=not prayer
		"donate":
			if inside() and player.distance_to(Vector3(82.4,2,27.5))<2.8 and coins>=10:
				coins-=10
				donations+=10
				message="บริจาคเหรียญทดลอง 10 เหรียญแล้ว"
		"dusk":
			var dusk: bool=command.get("value",false)
			sun.light_energy=.55 if dusk else .8
			sun.light_color=Color("ffbd89") if dusk else Color("fff0cf")
			environment.ambient_light_energy=.34 if dusk else .42
		"reset": coins=100; donations=0; message="รีเซ็ตเหรียญทดลองแล้ว"

func inside() -> bool:
	return camera_mode=="walk" and player.x>76.4 and player.x<83.6 and player.z<29 and player.z>16.4

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		yaw-=event.relative.x*.004
		pitch=clampf(pitch-event.relative.y*.004,-1.15,1.0)
	if event is InputEventKey and event.pressed:
		if event.keycode==KEY_1: set_view("overview")
		if event.keycode==KEY_2: set_view("walk")
		if event.keycode==KEY_3: set_view("interior")
		if event.keycode==KEY_E and inside() and player.z<26: prayer=not prayer

func _process(delta: float) -> void:
	clock+=delta
	if camera_mode=="walk":
		var move := touch_move+Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
		if move.length()>1: move=move.normalized()
		if move.length_squared()>.001:
			prayer=false
			var direction := Basis(Vector3.UP,yaw)*Vector3(move.x,0,move.y)
			var step := direction*3.4*minf(delta,.05)
			var test := player+Vector3(step.x,0,0)
			if can_stand(test): player.x=test.x
			test=player+Vector3(0,0,step.z)
			if can_stand(test): player.z=test.z
		player.y=2.08 if inside() else ground_height(player.x,player.z)
	update_camera(delta)
	for i in water_drops.size():
		var t := fmod(clock*.65+float(i)/14,1.0)
		var a := float(i%14)*TAU/14
		water_drops[i].position=Vector3(80+cos(a)*t*2.1,.96+2.7*(1-t*t),76+sin(a)*t*2.1)
	status_clock+=delta
	if OS.has_feature("web") and status_clock>.25:
		status_clock=0
		var nearby := ""
		for portal: Dictionary in map.portals:
			if Vector2(player.x-portal.x-1,player.z-portal.y-1).length()<2.5: nearby=portal.target_map
		var state := {"build":BUILD_ID,"mode":camera_mode,"inside":inside(),"prayer":prayer,"canPray":inside() and player.z<26,"canDonate":inside() and player.distance_to(Vector3(82.4,2,27.5))<2.8,"coins":coins,"donations":donations,"x":snappedf(player.x,.01),"z":snappedf(player.z,.01),"fps":Engine.get_frames_per_second(),"message":message,"portal":nearby,"models":mesh_count,"triangles":triangle_count}
		browser_window.cityState=JSON.stringify(state)
	if capture_path!="":
		capture_frames+=1
		if capture_frames==45:
			await RenderingServer.frame_post_draw
			var result := get_viewport().get_texture().get_image().save_png(capture_path)
			print("CAPTURE_RESULT ",result)
			get_tree().quit(0 if result==OK else 1)

func update_camera(delta: float) -> void:
	if camera_mode=="walk":
		eye_height=lerpf(eye_height,1.03 if prayer else 1.65,minf(delta*8,1))
		camera.position=player+Vector3(0,eye_height,0)
		camera.rotation=Vector3(pitch-.08 if prayer else pitch,yaw,0)
	var temple := get_node_or_null("TempleExterior")
	if temple: temple.visible=not inside()

func run_audit(output: String) -> void:
	var reachable := {}
	var queue: Array[Vector2i]=[Vector2i(80,83)]
	reachable["80,83"]=true
	var cursor := 0
	while cursor<queue.size():
		var p := queue[cursor]
		cursor+=1
		for d: Vector2i in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
			var n := p+d
			var key := "%d,%d"%[n.x,n.y]
			if not reachable.has(key) and can_stand(Vector3(n.x+.5,0,n.y+.5)):
				reachable[key]=true
				queue.append(n)
	var checks := {"dimensions":map.width==160 and map.height==160,"spawn":int(map.spawn.x)==80 and int(map.spawn.y)==83,"portals":map.portals.size()==5,"npcs":map.npcs.size()==19,"temple_reachable":reachable.has("80,24"),"fountain_solid":not can_stand(Vector3(80,0,76)),"donation_box_solid":not can_stand(Vector3(82.4,2,27.5))}
	for p: Dictionary in map.portals: checks[p.id]=reachable.has("%d,%d"%[p.x,p.y])
	var pass_all := true
	for value: bool in checks.values(): pass_all=pass_all and value
	var report := {"build":BUILD_ID,"checks":checks,"pass":pass_all,"reachable_cells":reachable.size(),"models":mesh_count,"triangles":triangle_count,"scope":"Exploration preview; portal destinations preserved as data, no MMO/server travel. Donation coins are local demonstration only."}
	if output!="":
		var file := FileAccess.open(output,FileAccess.WRITE)
		file.store_string(JSON.stringify(report,"  "))
	print("CITY_AUDIT ",JSON.stringify(report))
	if capture_path=="": get_tree().quit(0 if pass_all else 2)
