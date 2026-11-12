extends SceneTree
## Aligne les armes et le casque : un repère rouge marque l'avant (-Z) attendu du canon.
var frames := 0
var out := ""
func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.get_slice("=", 1)
	var Props = load("res://scripts/combat/props.gd")
	var r := Node3D.new()
	root.add_child(r)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("c8d4dc")
	env.ambient_light_energy = 0.6
	var we := WorldEnvironment.new(); we.environment = env; r.add_child(we)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-55, 30, 0); r.add_child(sun)
	var x := -1.6
	for k in ["mas36", "berthier", "lebel", "coupe_coupe", "adrian"]:
		var p: Node3D = Props.make(k)
		p.position = Vector3(x, 0, 0)
		r.add_child(p)
		var mark := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 0.03; sm.height = 0.06; mark.mesh = sm
		var mm := StandardMaterial3D.new(); mm.albedo_color = Color.RED; mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; mark.material_override = mm
		mark.position = Vector3(x, 0, p.get_meta("muzzle_z") - 0.06); r.add_child(mark)
		var l := Label3D.new(); l.text = k; l.position = Vector3(x, 0.15, 0.55); l.pixel_size = 0.0025; l.modulate = Color.BLACK; l.outline_size = 0; r.add_child(l)
		x += 0.8
	var cam := Camera3D.new()
	cam.transform = Transform3D(Basis(), Vector3(0.0, 2.4, 1.2)).looking_at(Vector3(0.0, 0, -0.2))
	r.add_child(cam)
func _process(_d: float) -> bool:
	frames += 1
	if frames == 10:
		root.get_texture().get_image().save_png(out)
		return true
	return false
