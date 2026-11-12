extends CharacterBody3D
## Soldat contrôlé par l'ordinateur (allié ou ennemi).
## Il avance de couverture en couverture, s'accroupit, se relève pour tirer sur la cible
## visible la plus proche, puis se remet à couvert. Touché, il encaisse ; à zéro, il tombe.
## Les alliés ne meurent pas : ils sont blessés et se relèvent plus tard (choix de jeu).

const Humanoid = preload("res://scripts/characters/humanoid.gd")
const Rifle = preload("res://scripts/combat/rifle.gd")
const Fx = preload("res://scripts/combat/fx.gd")
const Step = preload("res://scripts/core/step.gd")

signal died(soldier)

enum State { ADVANCE, COVER, DOWN, DEAD }

var team := 1                 # 0 = tirailleurs (joueur et alliés), 1 = ennemis
var display_name := ""
var health := 100.0
var state := State.ADVANCE
var cover_point := Vector3.ZERO
var threat_dir := Vector3.FORWARD   # direction d'où vient l'ennemi
var accuracy := 0.5
var model
var rifle
var battle = null             # le chapitre (fournit les couvertures et les cibles)
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _timer := 0.0
var _in_cover_time := 0.0
var _exposed := 0.0
var _target: Node3D = null
var _retarget := 0.0
var _bubble: Label3D
var _stuck := 0.0
var _vaulting := false


func setup(p_team: int, look: Dictionary, p_battle, name_text := "") -> void:
	team = p_team
	battle = p_battle
	display_name = name_text
	add_to_group("soldier")
	add_to_group("team%d" % team)
	collision_layer = 2
	collision_mask = 1 | 2
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.75
	col.shape = cap
	col.position.y = 0.875
	add_child(col)
	model = Humanoid.new()
	add_child(model)
	model.build(look)
	rifle = Rifle.new()
	var hand = model.hand_attachment()
	if hand:
		hand.add_child(rifle)
		rifle.position = Vector3(0.0, 0.08, 0.02)
		rifle.rotation = Vector3(PI / 2.0, 0.0, 0.0)
	else:
		model.add_child(rifle)
	rifle.reserve = 999
	_timer = randf_range(0.5, 2.5)
	if display_name != "":
		var l := Label3D.new()
		l.text = display_name
		l.font_size = 36
		l.pixel_size = 0.004
		l.outline_size = 8
		l.modulate = Color(0.9, 0.95, 1.0) if team == 0 else Color(1, 0.7, 0.7)
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.position.y = 2.05
		l.visibility_range_end = 25.0
		add_child(l)
	_bubble = Label3D.new()
	_bubble.font_size = 44
	_bubble.pixel_size = 0.0045
	_bubble.outline_size = 10
	_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble.position.y = 2.35
	_bubble.visible = false
	add_child(_bubble)


func say(text: String, t := 2.5) -> void:
	_bubble.text = text
	_bubble.visible = true
	_bubble.set_meta("t", t)


func is_alive() -> bool:
	return state != State.DEAD and state != State.DOWN


func is_crouching() -> bool:
	return state == State.COVER and _exposed <= 0.0


## Point visé sur ce soldat (poitrine, ou tête qui dépasse quand il est accroupi).
func aim_point() -> Vector3:
	return global_position + Vector3(0, 0.95 if is_crouching() else 1.35, 0)


func take_damage(amount: float, from: Vector3) -> void:
	if not is_alive():
		return
	health -= amount
	if health <= 0.0:
		if team == 0:
			state = State.DOWN
			model.set_combat_pose(false, false)
			model.play_action("Death01", 1.2)
			_timer = 25.0     # se relève après un moment (soigné par l'infirmier)
			say("Aïe… !", 2.0)
		else:
			state = State.DEAD
			model.set_combat_pose(false, false)
			model.play_action("Death01", 1.1)
			collision_layer = 0
			collision_mask = 1
			died.emit(self)
			var tw := create_tween()
			tw.tween_interval(20.0)
			tw.tween_callback(queue_free)
	else:
		model.play_action("Hit_Chest", 1.4)
		_exposed = 0.0     # se remet à couvert


func _process(delta: float) -> void:
	if _bubble.visible:
		var t: float = _bubble.get_meta("t", 0.0) - delta
		_bubble.set_meta("t", t)
		if t <= 0.0:
			_bubble.visible = false


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		velocity.x = 0.0
		velocity.z = 0.0
		velocity.y = 0.0 if is_on_floor() else velocity.y - gravity * delta
		move_and_slide()
		return
	if state == State.DOWN:
		_timer -= delta
		if _timer <= 0.0:
			health = 60.0
			state = State.COVER
			say("Ça va… je tiens.", 2.0)
		return
	_retarget -= delta
	if _retarget <= 0.0:
		_retarget = 0.6
		_target = _find_target()
	var hv := Vector3.ZERO
	match state:
		State.ADVANCE:
			var to := cover_point - global_position
			to.y = 0.0
			if to.length() < 0.7:
				state = State.COVER
				_in_cover_time = 0.0
				_timer = randf_range(0.8, 2.0)
			else:
				hv = to.normalized() * (3.4 if team == 1 else 3.8)
				model.set_combat_pose(false, false)
				# bloqué par une haie ou un muret : on l'enjambe
				if Vector2(velocity.x, velocity.z).length() < 0.5:
					_stuck += delta
					if _stuck > 0.8 and not _vaulting:
						_vault(to.normalized())
				else:
					_stuck = 0.0
		State.COVER:
			_in_cover_time += delta
			_timer -= delta
			if _exposed > 0.0:
				_exposed -= delta
				model.set_combat_pose(false, true)
				if _target:
					_face(_target.global_position, delta)
				if _exposed <= 0.0:
					model.set_combat_pose(true, false)
			else:
				model.set_combat_pose(true, false)
				_face(global_position + threat_dir, delta)
				if _timer <= 0.0 and _target:
					_exposed = randf_range(1.2, 2.0)
					_timer = randf_range(2.5, 4.5)
					_shoot_later(0.5)
			# les ennemis avancent vers la couverture suivante
			if team == 1 and battle and _in_cover_time > randf_range(5.0, 9.0) and _exposed <= 0.0:
				var next: Vector3 = battle.next_cover(self)
				if next != Vector3.INF:
					cover_point = next
					state = State.ADVANCE
	if _vaulting:
		return
	velocity.x = hv.x
	velocity.z = hv.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - gravity * delta
	if hv.length() > 0.1:
		_face(global_position + hv, delta)
		Step.try_step(self, hv, delta)
	move_and_slide()
	model.animate(Vector2(velocity.x, velocity.z).length(), delta)


## Enjambe un obstacle bas (haie, muret) : on cherche un point libre de l'autre côté.
func _vault(dir: Vector3) -> void:
	_stuck = 0.0
	# on ne saute que devant un vrai obstacle bas (muret, haie) :
	# quelque chose à hauteur de genou, rien à hauteur de tête, et pas un autre soldat
	var space := get_world_3d().direct_space_state
	var base := global_position
	var knee := space.intersect_ray(PhysicsRayQueryParameters3D.create(base + Vector3(0, 0.5, 0), base + Vector3(0, 0.5, 0) + dir * 1.2, 1, [get_rid()]))
	if knee.is_empty():
		return
	var head := space.intersect_ray(PhysicsRayQueryParameters3D.create(base + Vector3(0, 1.7, 0), base + Vector3(0, 1.7, 0) + dir * 1.2, 1, [get_rid()]))
	if not head.is_empty():
		return   # mur ou maison : trop haut, on contourne plutôt
	for dist in [1.6, 2.2, 2.8]:
		var land: Vector3 = global_position + dir * dist
		var t := Transform3D(Basis(), land + Vector3(0, 0.1, 0))
		if not test_move(t, Vector3(0, 0.05, 0)):
			_vaulting = true
			if OS.get_cmdline_user_args().has("--trace"):
				print("SAUT ", global_position.snapped(Vector3.ONE))
			model.play_action("Jump", 1.4)
			var tw := create_tween()
			tw.tween_property(self, "global_position", global_position + dir * dist * 0.5 + Vector3(0, 1.5, 0), 0.25)
			tw.tween_property(self, "global_position", land + Vector3(0, 0.1, 0), 0.25)
			tw.tween_callback(func(): _vaulting = false)
			return


func _face(p: Vector3, delta: float) -> void:
	var d := p - global_position
	if Vector2(d.x, d.z).length() < 0.1:
		return
	model.rotation.y = lerp_angle(model.rotation.y, atan2(-d.x, -d.z), clampf(8.0 * delta, 0.0, 1.0))


func _find_target() -> Node3D:
	var best: Node3D = null
	var bd := 140.0
	var eye := global_position + Vector3(0, 1.5, 0)
	for o in get_tree().get_nodes_in_group("team%d" % (1 - team)):
		if not o.is_alive():
			continue
		var d: float = o.global_position.distance_to(global_position)
		if d < bd and _line_of_sight(eye, o.aim_point(), o):
			bd = d
			best = o
	return best


func _line_of_sight(from: Vector3, to: Vector3, target: Node) -> bool:
	var q := PhysicsRayQueryParameters3D.create(from, to, 1 | 2, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return hit.is_empty() or hit.collider == target


func _shoot_later(delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if not is_alive() or _target == null or not is_instance_valid(_target) or not _target.is_alive():
		return
	if not rifle.fire():
		rifle.start_reload()
		return
	var muzzle: Vector3 = rifle.muzzle_position()
	var aim: Vector3 = _target.aim_point()
	var dist := muzzle.distance_to(aim)
	var chance := clampf(accuracy - dist / 220.0, 0.08, 0.7)
	if _target.has_method("is_crouching") and _target.is_crouching():
		chance *= 0.45
	var end := aim
	if randf() < chance:
		_target.take_damage(randf_range(25.0, 40.0), global_position)
	else:
		end = aim + Vector3(randf_range(-1.2, 1.2), randf_range(-0.4, 0.8), randf_range(-1.2, 1.2))
		var q := PhysicsRayQueryParameters3D.create(muzzle, muzzle + (end - muzzle).normalized() * 300.0, 1, [get_rid()])
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty():
			end = hit.position
			Fx.dust(get_tree().current_scene, end)
	model.play_action("Pistol_Shoot", 1.0)
	Fx.muzzle_flash(get_tree().current_scene, muzzle)
	Fx.tracer(get_tree().current_scene, muzzle, end)
	Fx.play_shot(get_tree().current_scene, muzzle, 1.0)
