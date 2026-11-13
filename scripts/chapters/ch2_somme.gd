extends Node3D
## Chapitre 2 — La Somme, juin 1940.
## Un village picard : la section de Demba tient la lisière nord face à l'offensive.
## Trois vagues d'assaut, puis l'ordre de repli vers le camion au sud du village.

const SkyBuilder = preload("res://scripts/world/sky.gd")
const Soldier = preload("res://scripts/combat/soldier.gd")
const PlayerSoldier = preload("res://scripts/combat/player_soldier.gd")
const Hud = preload("res://scripts/ui/hud.gd")

signal finished
signal restart

const WAVES := [5, 8, 11]
const DEFENSE_Z := -35.0
const TRUCK_POS := Vector3(3.5, 0, 82.0)

## Tenues : tirailleurs (kaki, casque Adrian) ; ennemis (gris-vert, casque, sans insigne).
## Tenue des tirailleurs en 1940 : capote kaki moutarde, culotte, bandes molletières, brodequins,
## casque Adrian, ceinturon, cartouchières et havresac (d'après les photos d'époque).
const TIRAILLEUR := {"model": "res://assets/characters/tirailleur/scene.gltf", "height": 1.78,
	"textures": {"Clothes": "res://assets/characters/tirailleur/textures/Clothes_tirailleur.png", "Body": "res://assets/characters/tirailleur/textures/Body_tirailleur.png"},
	"hide_materials": ["Material.003"],   # calot d'origine (étoile rouge) : remplacé par le casque Adrian
	"style": "capote", "top": Color("7d6a40"), "bottom": Color("6e5e3a"), "shoes": Color("3a2818"), "sandals": false,
	"puttees": 1, "puttee_color": Color("6b5d3c"), "hat": "adrian", "hat_color": Color("6f6c58"), "build": 0.98}
## Assaillants : vareuse gris-vert, bottes, casque, sans aucun insigne.
const ENEMY := {"style": "tunic", "top": Color("5d6457"), "bottom": Color("4f554a"), "shoes": Color("161616"), "sandals": false,
	"puttees": 2, "hat": "stahlhelm", "hat_color": Color("4a5045"), "skin_tint": Color(0.86, 0.74, 0.66),
	# vrai modèle 3D (CC BY) : insignes effacés de la texture, filet de camouflage (1944) retiré
	"model": "res://assets/characters/enemy/panzergrenadier.glb", "height": 1.78,
	"albedo": "res://assets/characters/enemy/uniforme_sans_insignes.png", "albedo_material": "Material.003",
	"hide_materials": ["scrimwire_low", "scrimleaves_low"]}

var player
var hud
var wave := 0
var enemies_alive := 0
var phase := "fight"        # fight → retreat → done
var cover_ally: Array[Vector3] = []
var cover_enemy: Array[Vector3] = []
var _occupied := {}
var _between := 0.0
var _mats := {}
var _ended := false


func _ready() -> void:
	SkyBuilder.make(self, 18.2, 0.35)
	_build_terrain()
	_build_village()
	_build_cover_lines()
	_build_truck()
	hud = Hud.new()
	add_child(hud)
	player = PlayerSoldier.new()
	add_child(player)
	var look := TIRAILLEUR.duplicate()
	player.setup(look)
	player.global_position = Vector3(0, 0.2, DEFENSE_Z + 6.0)
	player.yaw = 0.0   # regarde vers le nord (-Z)
	player.hud = hud
	hud.player = player
	hud.camera = player.camera
	player.died.connect(_on_player_died)
	_spawn_allies()
	hud.toast("La Somme — juin 1940")
	hud.set_objective("Tenez la lisière du village")
	_between = 6.0
	_say_sergeant("Section ! À couvert derrière le muret, et on tient la ligne !", 4.0)


# ---------------------------------------------------------------- matériaux

func _tex(n: String) -> Texture2D:
	var p := "res://assets/textures/%s.jpg" % n
	return load(p) if ResourceLoader.exists(p) else null


func mat(base: String, tint: Color, scale: float) -> StandardMaterial3D:
	var key := base + tint.to_html() + str(scale)
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.albedo_texture = _tex(base + "_albedo")
	m.normal_enabled = m.albedo_texture != null
	m.normal_texture = _tex(base + "_normal")
	m.roughness_texture = _tex(base + "_roughness")
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * scale
	if base == "grass" or base == "dirt":
		m.roughness_texture = null
		m.roughness = 1.0
		m.metallic_specular = 0.15
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_mats[key] = m
	return m


func box(size: Vector3, pos: Vector3, m: Material, collide := true, rot_y := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	mi.rotation.y = rot_y
	add_child(mi)
	if collide:
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = size
		cs.shape = sh
		body.add_child(cs)
		mi.add_child(body)
	return mi


# ---------------------------------------------------------------- terrain

func _build_terrain() -> void:
	box(Vector3(900, 1, 900), Vector3(0, -0.5, 0), mat("grass", Color(0.62, 0.72, 0.5), 0.25))
	# champs de blé au nord (là d'où vient l'ennemi)
	var wheat := mat("grass", Color(1.25, 1.0, 0.45), 0.3)
	for f in [[Vector3(-45, 0.02, -120), Vector3(70, 0.04, 150)], [Vector3(45, 0.02, -120), Vector3(70, 0.04, 150)], [Vector3(-60, 0.02, 60), Vector3(60, 0.04, 80)]]:
		box(f[1], f[0], wheat, false)
	# chemin de terre nord-sud
	box(Vector3(6, 0.05, 420), Vector3(0, 0.02, -60), mat("dirt", Color(1, 1, 1), 0.25), false)
	# alignement de peupliers le long du chemin, au nord
	for z in range(-200, -50, 14):
		for side in [-1.0, 1.0]:
			_tree(Vector3(side * 6.5, 0, float(z)), 1.0)
	# arbres épars
	var rng := RandomNumberGenerator.new()
	rng.seed = 40
	for k in 40:
		var p := Vector3(rng.randf_range(-140, 140), 0, rng.randf_range(-230, 140))
		if absf(p.x) < 12 or (absf(p.x) < 55 and p.z > -45 and p.z < 70):
			continue
		_tree(p, rng.randf_range(0.8, 1.4))


func _tree(p: Vector3, s: float) -> void:
	var bark := StandardMaterial3D.new()
	bark.albedo_color = Color("4a3a2a")
	var poplar := randf() < 0.6
	var h := (11.0 if poplar else 5.0) * s
	var trunk := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.15 * s
	cm.bottom_radius = 0.35 * s
	cm.height = h * 0.6
	trunk.mesh = cm
	trunk.material_override = bark
	trunk.position = p + Vector3(0, h * 0.3, 0)
	add_child(trunk)
	var leaves := mat("grass", Color(0.32, 0.45, 0.24), 0.6)
	# feuillage en plusieurs masses pour casser la silhouette en boule
	var blobs := 5 if poplar else 6
	for k in blobs:
		var crown := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = (1.3 if poplar else 2.0) * s * randf_range(0.8, 1.1)
		sm.height = sm.radius * (2.6 if poplar else 1.7)
		sm.radial_segments = 10
		sm.rings = 6
		crown.mesh = sm
		crown.material_override = leaves
		var a2 := randf() * TAU
		var off := Vector3(cos(a2), 0, sin(a2)) * (0.5 if poplar else 1.5) * s
		crown.position = p + off + Vector3(0, (h * 0.55 + k * 1.3 * s) if poplar else (h + randf_range(0.0, 1.6) * s), 0)
		add_child(crown)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = 0.35 * s
	sh.height = h * 0.6
	cs.shape = sh
	body.add_child(cs)
	trunk.add_child(body)


# ---------------------------------------------------------------- village

func _build_village() -> void:
	var stone := mat("stone", Color(1.0, 0.95, 0.88), 0.35)
	var plaster := mat("plaster_old", Color(1.0, 0.95, 0.85), 0.3)
	var houses := [
		[Vector3(-12, 0, -18), 9.0, 7.0, 5.5, 0.0], [Vector3(12, 0, -16), 10.0, 7.5, 6.0, 0.0],
		[Vector3(-13, 0, 2), 8.0, 7.0, 5.0, 0.0], [Vector3(13, 0, 4), 9.0, 8.0, 6.5, 0.0],
		[Vector3(-14, 0, 22), 10.0, 8.0, 6.0, 0.0], [Vector3(-30, 0, -6), 7.0, 9.0, 5.0, PI / 2.0],
		[Vector3(30, 0, -2), 8.0, 7.0, 5.5, PI / 2.0], [Vector3(-28, 0, 30), 9.0, 7.0, 5.0, 0.0],
		[Vector3(14, 0, 44), 8.0, 7.0, 5.0, 0.0], [Vector3(-12, 0, 48), 9.0, 7.0, 5.5, 0.0],
	]
	var k := 0
	for h in houses:
		_house(h[0], h[1], h[2], h[3], h[4], stone if k % 3 != 1 else plaster)
		k += 1
	_church(Vector3(26, 0, 26))


func _house(c: Vector3, w: float, d: float, h: float, rot: float, wall: Material) -> void:
	var root := Node3D.new()
	root.position = c
	root.rotation.y = rot
	add_child(root)
	var mi := _box_in(root, Vector3(w, h, d), Vector3(0, h * 0.5, 0), wall, true)
	# toit à deux pans
	_gable(root, w + 0.6, d + 0.6, h, 2.6, mat("roof", Color(1, 1, 1), 0.4))
	# porte, fenêtres et volets
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color("2a211a")
	var shutter := StandardMaterial3D.new()
	shutter.albedo_color = [Color("3d5a45"), Color("5a4632"), Color("4a5a6a")][int(absf(c.x + c.z)) % 3]
	for side in [-1.0, 1.0]:
		var z: float = side * (d * 0.5 + 0.02)
		_box_in(root, Vector3(1.1, 2.1, 0.06), Vector3(-w * 0.2, 1.05, z), dark, false)
		for wx in [w * 0.15, w * 0.35]:
			_box_in(root, Vector3(0.9, 1.1, 0.06), Vector3(wx, h * 0.55, z), dark, false)
			_box_in(root, Vector3(0.45, 1.15, 0.04), Vector3(wx - 0.7, h * 0.55, z + side * 0.02), shutter, false)
			_box_in(root, Vector3(0.45, 1.15, 0.04), Vector3(wx + 0.7, h * 0.55, z + side * 0.02), shutter, false)


func _box_in(parent: Node3D, size: Vector3, pos: Vector3, m: Material, collide: bool) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	if collide:
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = size
		cs.shape = sh
		body.add_child(cs)
		mi.add_child(body)
	return mi


## Toit à deux pans (prisme) posé sur les murs.
func _gable(parent: Node3D, w: float, d: float, base_y: float, rise: float, m: Material) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hw := w * 0.5
	var hd := d * 0.5
	var a := Vector3(-hw, base_y, -hd)
	var b := Vector3(hw, base_y, -hd)
	var c := Vector3(hw, base_y, hd)
	var e := Vector3(-hw, base_y, hd)
	var r1 := Vector3(-hw, base_y + rise, 0)
	var r2 := Vector3(hw, base_y + rise, 0)
	for tri in [[a, r1, r2], [a, r2, b], [e, c, r2], [e, r2, r1], [a, e, r1], [b, r2, c]]:
		for v in tri:
			st.add_vertex(v)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mm: StandardMaterial3D = m.duplicate()
	mm.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mm
	parent.add_child(mi)


func _church(c: Vector3) -> void:
	var stone := mat("stone", Color(0.92, 0.9, 0.85), 0.35)
	var root := Node3D.new()
	root.position = c
	add_child(root)
	_box_in(root, Vector3(10, 8, 22), Vector3(0, 4, 0), stone, true)
	_gable(root, 10.8, 22.8, 8.0, 4.0, mat("roof", Color(0.8, 0.8, 0.85), 0.4))
	_box_in(root, Vector3(5, 18, 5), Vector3(0, 9, -12.5), stone, true)
	var spire := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = 3.6
	cm.height = 7.0
	cm.radial_segments = 4
	spire.mesh = cm
	spire.material_override = mat("roof", Color(0.6, 0.6, 0.65), 0.4)
	spire.position = Vector3(0, 21.5, -12.5)
	spire.rotation.y = PI / 4.0
	root.add_child(spire)


# ---------------------------------------------------------------- couvertures

## Murets et haies orientés est-ouest ; chacun fournit des places de couverture
## côté sud (tirailleurs) et côté nord (assaillants).
func _cover_wall(x0: float, x1: float, z: float, kind: String) -> void:
	var length := x1 - x0
	var h := 1.05 if kind == "wall" else 1.35
	var m: Material = mat("stone", Color(0.9, 0.88, 0.82), 0.5) if kind == "wall" else mat("grass", Color(0.4, 0.55, 0.3), 0.7)
	box(Vector3(length, h, 0.7 if kind == "wall" else 1.2), Vector3((x0 + x1) * 0.5, h * 0.5, z), m)
	var x := x0 + 1.0
	while x < x1 - 0.8:
		cover_ally.append(Vector3(x, 0.1, z + 1.0))
		cover_enemy.append(Vector3(x, 0.1, z - 1.0))
		x += 2.2


func _build_cover_lines() -> void:
	# ligne de défense (lisière nord du village), avec un passage pour le chemin
	_cover_wall(-36, -4, DEFENSE_Z, "wall")
	_cover_wall(4, 34, DEFENSE_Z, "wall")
	# couvertures des assaillants, de plus en plus proches
	_cover_wall(-50, -8, -62, "hedge")
	_cover_wall(8, 52, -66, "hedge")
	_cover_wall(-45, 40, -88, "wall")
	_cover_wall(-60, 60, -112, "hedge")
	# grange isolée dans les champs
	box(Vector3(12, 6, 8), Vector3(-38, 3, -100), mat("wood", Color(0.8, 0.75, 0.7), 0.3))
	# bottes de foin et charrette près de la ligne
	var hay := mat("grass", Color(1.5, 1.3, 0.7), 0.6)
	for p in [Vector3(-20, 0.6, DEFENSE_Z - 8), Vector3(18, 0.6, DEFENSE_Z - 10), Vector3(-6, 0.6, -60)]:
		var hb := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.7
		cm.bottom_radius = 0.7
		cm.height = 1.3
		hb.mesh = cm
		hb.material_override = hay
		hb.position = p
		hb.rotation.z = PI / 2.0
		add_child(hb)


## Prochaine couverture pour un assaillant : la plus proche, plus près du village, libre.
func next_cover(s) -> Vector3:
	_occupied.erase(s.cover_point)
	var best := Vector3.INF
	var bd := INF
	for p in cover_enemy:
		if p.z <= s.global_position.z + 4.0 or _occupied.has(p):
			continue
		var d := Vector2(p.x - s.global_position.x, (p.z - s.global_position.z) * 0.5).length()
		if d < bd:
			bd = d
			best = p
	if best != Vector3.INF:
		_occupied[best] = s
	return best


func _build_truck() -> void:
	var olive := StandardMaterial3D.new()
	olive.albedo_color = Color("4d5236")
	olive.roughness = 0.8
	var canvas := StandardMaterial3D.new()
	canvas.albedo_color = Color("6b6a4a")
	var root := Node3D.new()
	root.position = TRUCK_POS
	add_child(root)
	_box_in(root, Vector3(2.2, 1.6, 2.0), Vector3(0, 1.5, -2.6), olive, true)
	_box_in(root, Vector3(2.3, 0.5, 4.6), Vector3(0, 0.95, 0.6), olive, true)
	_box_in(root, Vector3(2.3, 1.8, 4.4), Vector3(0, 2.1, 0.7), canvas, false)
	var tyre := StandardMaterial3D.new()
	tyre.albedo_color = Color("151515")
	for wz in [-2.4, 1.8]:
		for wx in [-1.05, 1.05]:
			var w := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.48
			cm.bottom_radius = 0.48
			cm.height = 0.3
			w.mesh = cm
			w.material_override = tyre
			w.position = Vector3(wx, 0.48, wz)
			w.rotation.z = PI / 2.0
			root.add_child(w)


# ---------------------------------------------------------------- escouade et vagues

const SQUAD := [["Sergent Mamadou", Color("7a6740")], ["Ousmane", Color("806c44")], ["Kouyaté", Color("78663f")],
	["Samba", Color("7d6a40")], ["Bakary", Color("74623c")]]


func _spawn_allies() -> void:
	# seulement le muret de la ligne de défense (pas les haies du côté des assaillants)
	var spots := cover_ally.filter(func(p): return absf(p.z - (DEFENSE_Z + 1.0)) < 0.5)
	spots.sort_custom(func(a, b): return absf(a.x) < absf(b.x))
	for i in SQUAD.size():
		var s := Soldier.new()
		add_child(s)
		var look := TIRAILLEUR.duplicate()
		look["top"] = SQUAD[i][1]
		look["skin_tint"] = [Color(1.0, 0.95, 0.9), Color(0.78, 0.72, 0.68), Color(1.1, 1.0, 0.92), Color(0.86, 0.78, 0.72), Color(0.95, 0.85, 0.8)][i % 5]
		look["height"] = [1.82, 1.74, 1.79, 1.70, 1.85][i % 5]
		if i == 0:
			look["beard"] = true
		s.setup(0, look, self, SQUAD[i][0])
		var p: Vector3 = spots[(i + 1) * 2 % spots.size()]
		s.global_position = p + Vector3(0, 0.1, 2.5)
		s.cover_point = p
		s.threat_dir = Vector3.FORWARD
		s.accuracy = 0.42


func _spawn_wave() -> void:
	wave += 1
	var n: int = WAVES[wave - 1]
	enemies_alive = n
	hud.set_objective("Vague %d / %d — tenez la ligne !" % [wave, WAVES.size()])
	_say_sergeant(["Ils arrivent ! Attendez qu'ils approchent…", "Encore eux ! Visez bien, économisez les cartouches !", "Dernier effort, tirailleurs ! Jàmm rek !"][wave - 1], 4.0)
	for i in n:
		var s := Soldier.new()
		add_child(s)
		s.setup(1, ENEMY, self)
		s.global_position = Vector3(randf_range(-45, 45), 0.2, randf_range(-130, -120))
		s.threat_dir = Vector3.BACK
		s.accuracy = 0.32 + wave * 0.04
		var c := next_cover(s)
		s.cover_point = c if c != Vector3.INF else Vector3(s.global_position.x, 0.1, -115)
		s.died.connect(_on_enemy_died)


func _on_enemy_died(_s) -> void:
	enemies_alive -= 1
	if enemies_alive <= 0 and phase == "fight":
		if wave >= WAVES.size():
			phase = "retreat"
			hud.set_objective("Repli ! Rejoignez le camion au sud du village")
			hud.toast("Ordre de repli !")
			_say_sergeant("On ne peut plus tenir ! Repli, repli ! Au camion !", 4.0)
		else:
			_between = 9.0
			hud.set_objective("Accalmie… préparez-vous (R pour recharger)")


func _say_sergeant(text: String, t: float) -> void:
	for s in get_tree().get_nodes_in_group("team0"):
		if s is Soldier and s.display_name.begins_with("Sergent"):
			s.say(text, t)
			return


func _process(delta: float) -> void:
	if phase == "fight" and enemies_alive <= 0 and _between > 0.0:
		_between -= delta
		if _between <= 0.0:
			_spawn_wave()
	if phase == "retreat" and player and not player.dead:
		var d: float = player.global_position.distance_to(TRUCK_POS)
		hud.set_distance(d)
		hud.set_compass_target(TRUCK_POS)
		if d < 5.0 and not _ended:
			_ended = true
			phase = "done"
			hud.toast("Vous avez rejoint le camion.")
			await get_tree().create_timer(2.5).timeout
			finished.emit()


func _on_player_died() -> void:
	hud.toast("Demba est tombé…")
	await get_tree().create_timer(3.5).timeout
	restart.emit()
