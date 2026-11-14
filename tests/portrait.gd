extends SceneTree
## Planche de validation d'un personnage : face, profil, dos (+ gros plan du visage),
## sur fond neutre, en pose de repos animée.
##   --look=demba_a | demba_b      --out=chemin.png
var frames := 0
var out := ""
var key := "demba_a"

const LOOKS := {
	"demba_a": {"top": Color("efe9dc"), "bottom": Color("8a7a5c"), "shoes": Color("5a3d28"), "sandals": true, "hair": "Hair_Buzzed", "beard": false, "height": 1.78, "build": 0.95},
	"demba_c": {"model": "res://assets/characters/civils/african_man_1/scene.gltf", "height": 1.78, "hide_materials": ["fedora", "fedora_cocked.001"],
		"textures": {"male_casualsuit03": "res://assets/characters/civils/african_man_1/textures/demba_1939_diffuse.png"}},
	"demba_d": {"model": "res://assets/characters/civils/african_man_1/scene.gltf", "height": 1.78, "hide_materials": ["fedora", "fedora_cocked.001"], "no_anim": true, "slim": 0.85,
		"textures": {"male_casualsuit03": "res://assets/characters/civils/african_man_1/textures/demba_1939_diffuse.png"}},
	"demba_mh": {"model": "res://assets/characters/makehuman/demba/demba.fbx", "height": 1.78, "arm_in": 14.0, "fix_normals": true,
		"textures": {"male_casualsuit01": "res://assets/characters/makehuman/demba/textures/demba_1939_diffuse.png"}},
	"demba_flat": {"model": "res://assets/characters/makehuman/demba/demba.fbx", "height": 1.78, "arm_in": 14.0, "fix_normals": true, "flat": true},
	"control": {"model": "res://assets/characters/quaternius/Superhero_Male_FullBody.gltf", "height": 1.78},
	"demba_b": {"model": "res://assets/characters/civils/african_man_1/scene.gltf", "height": 1.78, "hide_materials": ["fedora", "fedora_cocked.001"]},
}


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.get_slice("=", 1)
		elif a.begins_with("--look="): key = a.get_slice("=", 1)
	var r := Node3D.new(); root.add_child(r)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("cfd5d8")
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new(); we.environment = env; r.add_child(we)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-35, 25, 0); sun.light_energy = 1.2; r.add_child(sun)
	var g := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(20, 20); g.mesh = pm
	var gm := StandardMaterial3D.new(); gm.albedo_color = Color("b9ae98"); g.material_override = gm; r.add_child(g)
	var look: Dictionary = LOOKS[key]
	for i in 3:
		var holder := Node3D.new()
		r.add_child(holder)
		holder.position = Vector3(-1.3 + i * 1.3, 0, 0)
		var m: Node3D = (load("res://scripts/characters/model_character.gd").new() if look.has("model") else load("res://scripts/characters/humanoid.gd").new())
		holder.add_child(m)
		m.build(look)
		m.rotation.y = [PI, PI / 2.0, 0.0][i]   # face, profil, dos (le personnage regarde vers -Z)
	var cam := Camera3D.new()
	cam.transform = Transform3D(Basis(), Vector3(0, 1.05, 4.4)).looking_at(Vector3(0, 0.95, 0))
	cam.fov = 45
	r.add_child(cam)


func _process(d: float) -> bool:
	for n in root.get_child(0).get_children():
		for m in n.get_children():
			if m.has_method("animate"):
				m.animate(0.0, d)
	frames += 1
	if frames == 30:
		root.get_texture().get_image().save_png(out)
		return true
	return false
