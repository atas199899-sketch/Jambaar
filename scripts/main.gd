extends Node
## Point d'entrée : chapitre 0 (Médina, 1939), une lettre, puis chapitre 2 (La Somme, 1940).
## --chapter=2 lance directement le chapitre 2 (tests).

const Ch0 = preload("res://scripts/chapters/ch0_medina.gd")
const Ch2 = preload("res://scripts/chapters/ch2_somme.gd")

var current := 0

var chapter: Node3D
var _capture_path := ""
var _capture_list: Array[int] = []
var _frames := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--capture="):
			_capture_path = a.get_slice("=", 1)
		elif a.begins_with("--capframes="):
			for f in a.get_slice("=", 1).split(","):
				_capture_list.append(int(f))
		elif a.begins_with("--chapter="):
			current = int(a.get_slice("=", 1))
	_start()


func _start() -> void:
	if chapter:
		chapter.queue_free()
	if current == 0:
		chapter = Ch0.new()
		chapter.name = "Chapitre0"
		add_child(chapter)
		chapter.finished.connect(func(): _letter.call_deferred())
	else:
		chapter = Ch2.new()
		chapter.name = "Chapitre2"
		add_child(chapter)
		chapter.restart.connect(func(): _start.call_deferred())
		chapter.finished.connect(func(): chapter.hud.toast("Fin de la démo — la suite arrive bientôt"))
	_dev_args.call_deferred()


## Lettre de Demba entre deux chapitres (texte lu à l'écran).
func _letter() -> void:
	chapter.queue_free()
	chapter = null
	var layer := CanvasLayer.new()
	add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color("1a140d")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	var l := Label.new()
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.offset_left = 160
	l.offset_right = -160
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 24)
	l.add_theme_color_override("font_color", Color("efe3c8"))
	l.text = """Camp de Thiaroye, octobre 1939

Chère mère, chère Khady,

On nous a donné un uniforme, un casque et un fusil. Ousmane est avec moi, il vous salue.
Le sergent Mamadou dit que nous partirons bientôt pour la France, en bateau.
Je garde le gris-gris sur moi, comme promis. Priez pour nous.

Votre fils et frère, Demba.

…

Juin 1940. Les tirailleurs sont en France, sur la Somme."""
	layer.add_child(l)
	l.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(l, "modulate:a", 1.0, 1.5)
	await get_tree().create_timer(12.0 if not OS.get_cmdline_user_args().has("--fast") else 1.0).timeout
	layer.queue_free()
	current = 2
	_start()
	print("CHAPITRE 2 lancé après la lettre")


## Outils de test : --autofight (le joueur tire tout seul sur les ennemis visibles),
## --fastwave (première vague tout de suite), --look=yaw,pitch.
func _dev_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "--fastwave" and "_between" in chapter:
			chapter._between = 0.5
		elif a.begins_with("--look="):
			var v := a.get_slice("=", 1).split(",")
			chapter.player.yaw = float(v[0])
			if a.ends_with(",zoom"):
				pass
			chapter.player.pitch = float(v[1])
		elif a == "--aim":
			Input.action_press("aim")
		elif a == "--lineup":
			# aligne un tirailleur et un assaillant devant la caméra (vérification des tenues)
			var p: Vector3 = chapter.player.global_position
			for i in 2:
				var sd = chapter.Soldier.new()
				chapter.add_child(sd)
				sd.setup(i, chapter.TIRAILLEUR if i == 0 else chapter.ENEMY, null)
				sd.global_position = p + Vector3(-0.8 + i * 1.6, 0.2, 2.4)
				sd.set_physics_process(false)
				sd.model.rotation.y = PI
				sd.model.animate(0.0, 0.016)
		elif a == "--crouch":
			chapter.player.crouching = true
		elif a.begins_with("--goto="):
			var v := a.get_slice("=", 1).split(",")
			chapter.player.global_position = Vector3(float(v[0]), 0.3, float(v[1]))


func _physics_process(_delta: float) -> void:
	if OS.get_cmdline_user_args().has("--trace") and Engine.get_physics_frames() % 120 == 0 and chapter and "wave" in chapter:
		var en := get_tree().get_nodes_in_group("team1")
		var info := []
		for e in en.slice(0, 3):
			info.append("%s st=%d hp=%d" % [str(e.global_position.snapped(Vector3.ONE)), e.state, e.health])
		print("TRACE f=%d vague=%d ennemis=%d vivants=%d between=%.1f %s" % [Engine.get_physics_frames(), chapter.wave, en.size(), chapter.enemies_alive, chapter._between, info])
	if _capture_path == "" or _capture_list.is_empty():
		return
	_frames += 1
	if _frames in _capture_list:
		var img := get_viewport().get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path(_capture_path.get_basename() + "_%d.png" % _frames))
		if _frames == _capture_list.max():
			get_tree().quit()
