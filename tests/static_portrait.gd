extends SceneTree
var frames := 0
var out := ""
func _init() -> void:
	var p := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.get_slice("=", 1)
		elif a.begins_with("--model="): p = a.get_slice("=", 1)
	var Props = load("res://scripts/combat/props.gd")
	var r := Node3D.new(); root.add_child(r)
	var env := Environment.new(); env.background_mode = Environment.BG_COLOR; env.background_color = Color("cfd5d8"); env.ambient_light_energy = 0.7; env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new(); we.environment = env; r.add_child(we)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-35, 25, 0); sun.light_energy = 1.2; r.add_child(sun)
	for i in 3:
		var n: Node3D = load(p).instantiate()
		r.add_child(n)
		var b: AABB = Props.bounds(n)
		var s := 1.78 / b.size.y
		n.scale = Vector3.ONE * s
		n.rotation.y = [0.0, PI / 2.0, PI][i]
		n.position = Vector3(-1.3 + i * 1.3, -b.position.y * s, 0)
		if i == 0: print("taille d'origine ", b.size)
	var cam := Camera3D.new(); cam.transform = Transform3D(Basis(), Vector3(0, 1.05, 4.4)).looking_at(Vector3(0, 0.95, 0)); cam.fov = 45; r.add_child(cam)
func _process(_d: float) -> bool:
	frames += 1
	if frames == 10:
		root.get_texture().get_image().save_png(out)
		return true
	return false
