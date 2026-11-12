extends SceneTree
## Vue de face, de dos et de profil d'un modèle (vérification des insignes, de l'échelle).
var frames := 0
var out := ""
func _init() -> void:
	var p := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.get_slice("=", 1)
		elif a.begins_with("--model="): p = a.get_slice("=", 1)
	var r := Node3D.new(); root.add_child(r)
	var env := Environment.new(); env.background_mode = Environment.BG_COLOR; env.background_color = Color("d0d6da"); env.ambient_light_energy = 0.8
	var we := WorldEnvironment.new(); we.environment = env; r.add_child(we)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-35, 25, 0); r.add_child(sun)
	var Props = load("res://scripts/combat/props.gd")
	var h := 0.0
	for i in 3:
		var n: Node3D = load(p).instantiate()
		r.add_child(n)
		var b: AABB = Props.bounds(n)
		var s := 1.8 / maxf(b.size.y, 0.001)
		n.scale = Vector3.ONE * s
		n.position = Vector3(-3.0 + i * 3.0, -b.position.y * s, 0) - Vector3(b.get_center().x, 0, b.get_center().z) * s
		n.rotation.y = [0.0, PI, PI / 2.0][i]
		h = b.size.y
	print("hauteur d'origine : ", h)
	var cam := Camera3D.new()
	cam.transform = Transform3D(Basis(), Vector3(-3.0, 1.45, 1.6)).looking_at(Vector3(-3.0, 1.35, 0))
	cam.fov = 40
	r.add_child(cam)
func _process(_d: float) -> bool:
	frames += 1
	if frames == 10:
		root.get_texture().get_image().save_png(out)
		return true
	return false
