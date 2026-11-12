extends Node
## Point d'entrée (version de test) : lance directement le chapitre 2 (La Somme, 1940).
## Le menu, le chapitre 0 et les lettres viendront après validation de ce chapitre.

const Ch2 = preload("res://scripts/chapters/ch2_somme.gd")

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
	_start()


func _start() -> void:
	if chapter:
		chapter.queue_free()
	chapter = Ch2.new()
	chapter.name = "Chapitre2"
	add_child(chapter)
	chapter.restart.connect(func(): _start.call_deferred())
	chapter.finished.connect(func(): chapter.hud.toast("Fin du chapitre (version de test)"))
	_dev_args.call_deferred()


## Outils de test : --autofight (le joueur tire tout seul sur les ennemis visibles),
## --fastwave (première vague tout de suite), --look=yaw,pitch.
func _dev_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "--fastwave":
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
	if OS.get_cmdline_user_args().has("--trace") and Engine.get_physics_frames() % 120 == 0 and chapter:
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
