extends Node3D
## Chapitre 0 — Médina, septembre 1939.
## Demba vit avec sa mère Aïda et sa sœur Khady. Une matinée ordinaire : l'oncle Lamine,
## tailleur, l'attend à l'atelier ; sur la place du marché, un crieur annonce la mobilisation.
## Demba retrouve son ami Ousmane, puis rentre faire ses adieux.
##
## Personnages et situations fictifs, contexte historique réel (la France entre en guerre le
## 3 septembre 1939 ; des hommes d'AOF sont appelés ou recrutés comme tirailleurs).

const SkyBuilder = preload("res://scripts/world/sky.gd")
const OsmCity = preload("res://scripts/world/osm_city.gd")
const Player = preload("res://scripts/characters/player.gd")
const Npc = preload("res://scripts/characters/npc.gd")
const Pedestrian = preload("res://scripts/characters/pedestrian.gd")
const Hud = preload("res://scripts/ui/hud.gd")

signal finished

## Marché Tilène, au cœur de la Médina (position OpenStreetMap).
const TILENE := Vector3(-1977.6, 0, -1516.1)

var city
var player
var hud
var npcs := {}
var step := 0
var targets := {}
var beacon: MeshInstance3D
var _done := false

## Étapes : [personnage à rejoindre, texte de l'objectif]
const STEPS := [
	["aida", "Parle à ta mère"],
	["lamine", "Va à l'atelier de l'oncle Lamine"],
	["crieur", "Va au marché Tilène"],
	["ousmane", "Parle à Ousmane"],
	["aida", "Rentre à la maison"],
]


func _ready() -> void:
	SkyBuilder.make(self, 9.0, 0.1)
	city = OsmCity.new()
	city.era_1939 = true
	add_child(city)
	city.build()

	hud = Hud.new()
	add_child(hud)

	var marche: Vector3 = _node_near(TILENE)
	var home: Vector3 = city.sidewalk_point_near(marche, 260.0, 330.0)
	var atelier: Vector3 = city.sidewalk_point_near(home, 130.0, 200.0, [marche], 130.0)

	player = Player.new()
	# Demba en 1939 : chemise blanche, pantalon de toile, sandales
	player.look = {"top": Color("efe9dc"), "bottom": Color("8a7a5c"), "shoes": Color("5a3d28"), "sandals": true,
		"hair": "Hair_Buzzed", "beard": false, "height": 1.78, "build": 0.95}
	add_child(player)
	player.global_position = home + Vector3(2.5, 0.2, 0)
	player.hud = hud
	hud.player = player
	hud.camera = player.camera
	city.focus = player

	_npc("aida", "Aïda (ta mère)", home + Vector3(-1.2, 0, 0.8),
		{"female": true, "long_dress": true, "head_wrap": true, "wrap_color": Color("8e44ad"), "top": Color("6b3fa0"), "wax": true, "pattern_color": Color("f1c40f"), "height": 1.64})
	_npc("khady", "Khady (ta sœur)", home + Vector3(-1.8, 0, -1.2),
		{"female": true, "long_dress": true, "head_wrap": true, "wrap_color": Color("e67e22"), "top": Color("c0392b"), "height": 1.58})
	_npc("lamine", "Oncle Lamine", atelier,
		{"long_dress": true, "top": Color("ecf0f1"), "beard": true, "height": 1.8})
	_npc("crieur", "Le crieur", marche,
		{"long_dress": true, "top": Color("1f5fae"), "height": 1.76})
	_npc("ousmane", "Ousmane", marche + Vector3(3.5, 0, 2.0),
		{"top": Color("d9cfb8"), "bottom": Color("5b4a3a"), "sandals": true, "height": 1.77})
	targets = {"aida": npcs.aida.global_position, "lamine": atelier, "crieur": marche, "ousmane": npcs.ousmane.global_position}

	# un peu de vie : des passants autour
	for k in 30:
		var p := Pedestrian.new()
		add_child(p)
		var female := randf() < 0.5
		p.setup(city, city.random_sidewalk_node_near(home, 260.0), {
			"female": female, "long_dress": randf() < 0.85, "sandals": true, "head_wrap": female and randf() < 0.7,
			"top": [Color("ecf0f1"), Color("1f5fae"), Color("8e44ad"), Color("e67e22"), Color("16a085"), Color("c9b28a")].pick_random(),
			"wax": randf() < 0.3, "pattern_color": Color("f1c40f")})

	_make_beacon()
	hud.toast("Médina, Dakar — septembre 1939")
	_update_objective()
	_dev_args.call_deferred()


func _node_near(p: Vector3) -> Vector3:
	var best := Vector3.ZERO
	var bd := INF
	for n in city.sidewalk_nodes:
		var d: float = Vector2(n.x - p.x, n.z - p.z).length()
		if d < bd:
			bd = d
			best = n
	return best


func _npc(id: String, title: String, pos: Vector3, look: Dictionary) -> void:
	var n := Npc.new()
	add_child(n)
	n.setup({"id": id, "name": title, "look": look, "idle": ["…"]})
	n.global_position = pos
	n.talked.connect(_on_talk)
	npcs[id] = n


func _make_beacon() -> void:
	beacon = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.0
	cm.bottom_radius = 1.0
	cm.height = 40.0
	cm.cap_top = false
	cm.cap_bottom = false
	beacon.mesh = cm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.95, 0.75, 0.2, 0.2)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	beacon.material_override = m
	add_child(beacon)


func _update_objective() -> void:
	if step >= STEPS.size():
		hud.set_objective("")
		beacon.visible = false
		return
	hud.set_objective(STEPS[step][1])
	for id in npcs:
		npcs[id].set_has_mission(id == STEPS[step][0])


func _process(_d: float) -> void:
	if step >= STEPS.size():
		hud.set_distance(-1.0)
		return
	var t: Vector3 = npcs[STEPS[step][0]].global_position
	beacon.global_position = t + Vector3(0, 20, 0)
	hud.set_distance(player.global_position.distance_to(t))
	hud.set_compass_target(t)


# ---------------------------------------------------------------- dialogues

func _on_talk(npc) -> void:
	var id: String = npc.npc_id
	var expected: String = STEPS[step][0] if step < STEPS.size() else ""
	if id != expected:
		var idle := {
			"aida": ["Va, mon fils. Ne fais pas attendre ton oncle."],
			"khady": ["Grand frère, tu me rapportes des beignets ?"],
			"lamine": ["Le fil, les aiguilles… la patience, Demba. Tout est là."],
			"crieur": ["Écoutez bien, gens de la Médina !"],
			"ousmane": ["Ah, Demba ! Tu as entendu ?"],
		}
		hud.show_dialogue(npc.npc_name, idle.get(id, ["…"]))
		return
	match step:
		0:
			hud.show_dialogue("Aïda", [
				"Demba, tu es déjà réveillé ? Jërëjëf Yàlla.",
				"Ton oncle Lamine te demande à l'atelier. Il a beaucoup de boubous à finir avant la Tamkharit.",
				"Et rapporte du pain sur le chemin du retour, s'il te plaît."], _next)
		1:
			hud.show_dialogue("Oncle Lamine", [
				"Te voilà enfin ! Assieds-toi, il y a trois grands boubous à ourler.",
				"…",
				"Tu entends ce tambour ? Les gens courent vers le marché Tilène.",
				"On dit que la France est entrée en guerre contre l'Allemagne. Va voir ce que dit le crieur, et reviens me raconter."], _next)
		2:
			hud.show_dialogue("Le crieur", [
				"Gens de la Médina, écoutez !",
				"La France est en guerre depuis le 3 septembre.",
				"Les hommes inscrits sur les listes doivent se présenter au bureau de recrutement.",
				"Ceux qui sont appelés partiront rejoindre les régiments de tirailleurs sénégalais."], _next)
		3:
			hud.show_dialogue("Ousmane", [
				"Demba ! Mon nom est sur la liste… et le tien aussi.",
				"Mon père dit que c'est l'honneur de la famille. Ma mère, elle, n'arrête pas de pleurer.",
				"On partira ensemble, hein ? Comme quand on allait à l'école.",
				"Va dire au revoir à ta mère. On se retrouve demain au camp."], _next)
		4:
			hud.show_dialogue("Aïda", [
				"…Je sais, mon fils. Les voisins me l'ont dit.",
				"Ton père aussi est parti, en 1914. Il est revenu. Toi aussi, tu reviendras.",
				"Prends ce gris-gris. Garde-le toujours sur toi.",
				"Khady : « Écris-nous, Demba. Chaque semaine. Promis ? »",
				"Va. Que Dieu te garde."], _finish)


func _next() -> void:
	step += 1
	_update_objective()


func _finish() -> void:
	step = STEPS.size()
	_update_objective()
	if _done:
		return
	_done = true
	hud.toast("Fin du chapitre 0")
	await get_tree().create_timer(3.0).timeout
	finished.emit()


## Outils de test : --step=N (aller à l'étape N), --near (se placer près de la cible).
func _dev_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--step="):
			step = int(a.get_slice("=", 1))
			_update_objective()
		elif a == "--near" and step < STEPS.size():
			var t: Vector3 = npcs[STEPS[step][0]].global_position
			player.global_position = t + Vector3(0, 0.3, 4.0)
			player.yaw = 0.0
			player.pitch = -0.12
		elif a == "--autoplay":
			_autoplay()
		elif a == "--talk" and step < STEPS.size():
			npcs[STEPS[step][0]].interact(player)



func _autoplay() -> void:
	await get_tree().create_timer(1.0).timeout
	while step < STEPS.size():
		var id: String = STEPS[step][0]
		player.global_position = npcs[id].global_position + Vector3(0, 0.3, 2.0)
		await get_tree().create_timer(0.3).timeout
		npcs[id].interact(player)
		var n := 0
		while hud.is_dialogue_open() and n < 20:
			hud.advance_dialogue()
			n += 1
		print("AUTOPLAY étape %d (%s) → %d répliques" % [step, id, n])
		await get_tree().create_timer(0.3).timeout
