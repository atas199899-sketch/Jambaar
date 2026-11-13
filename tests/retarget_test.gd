extends SceneTree
## Test du reciblage : 4 copies du modèle, chacune avec une animation convertie, figées à un instant.
var frames := 0
var out := ""
var players: Array = []
var t_at := 0.4
func _init() -> void:
	var model := "res://assets/characters/enemy/panzergrenadier.glb"
	var anims := ["Idle", "Walk", "Pistol_Aim_Neutral", "Crouch_Idle"]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.get_slice("=", 1)
		elif a.begins_with("--anims="): anims = Array(a.get_slice("=", 1).split(","))
		elif a.begins_with("--t="): t_at = float(a.get_slice("=", 1))
	var Retarget = load("res://scripts/characters/retarget.gd")
	var Props = load("res://scripts/combat/props.gd")
	var r := Node3D.new(); root.add_child(r)
	var env := Environment.new(); env.background_mode = Environment.BG_COLOR; env.background_color = Color("d0d6da"); env.ambient_light_energy = 0.8
	var we := WorldEnvironment.new(); we.environment = env; r.add_child(we)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-40, 30, 0); r.add_child(sun)
	var g := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(20, 20); g.mesh = pm; r.add_child(g)
	for i in anims.size():
		var holder := Node3D.new()
		r.add_child(holder)
		var n: Node3D = load(model).instantiate()
		holder.add_child(n)
		var b: AABB = Props.bounds(n)
		var s := 1.8 / b.size.y
		n.scale = Vector3.ONE * s
		n.position = Vector3(0, -b.position.y * s, 0)
		holder.position = Vector3(-2.4 + i * 1.6, 0, 0)
		holder.rotation.y = 0.5
		var sk: Skeleton3D = n.find_children("*", "Skeleton3D", true, false)[0]
		var res: Dictionary = Retarget.library_for(model, n, sk, anims)
		var ap := AnimationPlayer.new()
		n.add_child(ap)
		ap.root_node = NodePath("..")
		ap.add_animation_library("", res.library)
		ap.play(anims[i])
		ap.seek(t_at, true)
		ap.pause()
		players.append(ap)
		var l := Label3D.new(); l.text = anims[i]; l.position = Vector3(0, 2.1, 0); l.pixel_size = 0.004; l.modulate = Color.BLACK; holder.add_child(l)
	var cam := Camera3D.new()
	cam.transform = Transform3D(Basis(), Vector3(0, 1.4, 5.5)).looking_at(Vector3(0, 0.95, 0))
	r.add_child(cam)
func _process(_d: float) -> bool:
	frames += 1
	if frames == 8:
		root.get_texture().get_image().save_png(out)
		return true
	return false
