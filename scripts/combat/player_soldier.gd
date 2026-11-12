extends CharacterBody3D
## Le joueur au combat : caméra à l'épaule, visée (clic droit), tir (clic gauche),
## culasse et rechargement (R), accroupi (C) pour se mettre à couvert, pansements (H).

const Humanoid = preload("res://scripts/characters/humanoid.gd")
const Rifle = preload("res://scripts/combat/rifle.gd")
const Fx = preload("res://scripts/combat/fx.gd")
const Step = preload("res://scripts/core/step.gd")

signal died
signal fired

const WALK := 2.2
const RUN := 5.0
const CROUCH := 1.3

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var team := 0
var health := 100.0
var bandages := 3
var model
var rifle
var cam_pivot: Node3D
var spring: SpringArm3D
var camera: Camera3D
var yaw := 0.0
var pitch := -0.15
var mouse_sensitivity := 0.0025
var crouching := false
var aiming := false
var controls_locked := false
var hud = null
var dead := false
var _hurt_flash := 0.0
var _col: CollisionShape3D
var _cap: CapsuleShape3D


func setup(look: Dictionary) -> void:
	add_to_group("player")
	add_to_group("team0")
	collision_layer = 2
	collision_mask = 1 | 2 | 4
	floor_snap_length = 0.3
	_col = CollisionShape3D.new()
	_cap = CapsuleShape3D.new()
	_cap.radius = 0.3
	_cap.height = 1.75
	_col.shape = _cap
	_col.position.y = 0.875
	add_child(_col)
	model = Humanoid.new()
	add_child(model)
	model.build(look)
	rifle = Rifle.new()
	var hand = model.hand_attachment()
	if hand:
		hand.add_child(rifle)
		rifle.position = Vector3(0.0, 0.08, 0.02)
		rifle.rotation = Vector3(PI / 2.0, 0.0, 0.0)
	cam_pivot = Node3D.new()
	cam_pivot.position.y = 1.55
	add_child(cam_pivot)
	spring = SpringArm3D.new()
	spring.spring_length = 3.0
	spring.margin = 0.2
	spring.collision_mask = 1
	var ss := SphereShape3D.new()
	ss.radius = 0.2
	spring.shape = ss
	spring.position.x = 0.55
	cam_pivot.add_child(spring)
	camera = Camera3D.new()
	camera.fov = 70.0
	camera.near = 0.05
	camera.far = 1500.0
	spring.add_child(camera)
	camera.make_current()
	if DisplayServer.get_name() != "headless" and not OS.has_feature("web"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func is_alive() -> bool:
	return not dead


func is_crouching() -> bool:
	return crouching and not aiming


func aim_point() -> Vector3:
	return global_position + Vector3(0, 0.95 if is_crouching() else 1.35, 0)


func take_damage(amount: float, _from: Vector3) -> void:
	if dead:
		return
	health -= amount
	_hurt_flash = 0.6
	if hud and hud.has_method("hurt"):
		hud.hurt()
	if health <= 0.0:
		health = 0.0
		dead = true
		model.set_combat_pose(false, false)
		model.play_action("Death01", 1.0)
		died.emit()
	else:
		model.play_action("Hit_Chest", 1.6)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var s := mouse_sensitivity * (0.5 if aiming else 1.0)
		yaw -= event.relative.x * s
		pitch = clampf(pitch - event.relative.y * s, -1.1, 0.7)
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not OS.has_feature("web"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("pause"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
	if dead or controls_locked:
		return
	if event.is_action_pressed("crouch"):
		crouching = not crouching
	elif event.is_action_pressed("reload"):
		if rifle.start_reload():
			model.play_action("Pistol_Reload", 1.0)
	elif event.is_action_pressed("bandage") and bandages > 0 and health < 100.0:
		bandages -= 1
		health = minf(100.0, health + 50.0)
		if hud:
			hud.toast("Pansement : +50")


func _physics_process(delta: float) -> void:
	var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	yaw -= look.x * 2.4 * delta
	pitch = clampf(pitch - look.y * 2.4 * delta, -1.1, 0.7)
	cam_pivot.rotation = Vector3(pitch, yaw, 0.0)
	_hurt_flash = maxf(0.0, _hurt_flash - delta)
	if dead:
		velocity = Vector3(0, velocity.y - gravity * delta, 0)
		move_and_slide()
		return
	var locked := controls_locked
	aiming = not locked and Input.is_action_pressed("aim")
	# caméra : plus proche et plus serrée en visée
	spring.spring_length = lerpf(spring.spring_length, 1.3 if aiming else (2.4 if crouching else 3.0), clampf(10.0 * delta, 0.0, 1.0))
	camera.fov = lerpf(camera.fov, 48.0 if aiming else 70.0, clampf(10.0 * delta, 0.0, 1.0))
	cam_pivot.position.y = lerpf(cam_pivot.position.y, 1.05 if crouching and not aiming else 1.55, clampf(8.0 * delta, 0.0, 1.0))
	# déplacement
	var input := Vector2.ZERO if locked else Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := Vector3(input.x, 0.0, input.y).rotated(Vector3.UP, yaw)
	var speed := CROUCH if crouching else (RUN if Input.is_action_pressed("sprint") and not aiming else WALK)
	if aiming:
		speed = minf(speed, 1.6)
	var hv := Vector3(velocity.x, 0.0, velocity.z).lerp(dir.normalized() * speed * minf(1.0, input.length()) if dir.length() > 0.05 else Vector3.ZERO, clampf(10.0 * delta, 0.0, 1.0))
	velocity.x = hv.x
	velocity.z = hv.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - gravity * delta
	Step.try_step(self, hv, delta)
	move_and_slide()
	# accroupi : capsule plus basse (on se cache vraiment derrière un muret)
	_cap.height = lerpf(_cap.height, 1.15 if crouching and not aiming else 1.75, clampf(10.0 * delta, 0.0, 1.0))
	_col.position.y = _cap.height * 0.5
	# orientation du corps : vers la visée, sinon vers le déplacement
	if aiming:
		model.rotation.y = lerp_angle(model.rotation.y, yaw, clampf(14.0 * delta, 0.0, 1.0))
	elif hv.length() > 0.2:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(-hv.x, -hv.z), clampf(10.0 * delta, 0.0, 1.0))
	model.set_combat_pose(crouching and not aiming, aiming)
	model.animate(hv.length(), delta)
	if aiming and Input.is_action_just_pressed("fire"):
		_fire()
	elif not aiming and Input.is_action_just_pressed("fire") and hud:
		hud.toast("Clic droit pour épauler")
	if hud and hud.has_method("set_combat"):
		hud.set_combat(health, rifle.mag, rifle.reserve, bandages, aiming, rifle.reloading > 0.0)


## Tir : le rayon part du centre de l'écran (le réticule) ; la traçante part du canon.
func _fire() -> void:
	if not rifle.fire():
		if rifle.mag == 0 and rifle.start_reload():
			model.play_action("Pistol_Reload", 1.0)
		return
	fired.emit()
	var from := camera.global_position
	var forward := -camera.global_transform.basis.z
	var to := from + forward * Rifle.RANGE
	var q := PhysicsRayQueryParameters3D.create(from, to, 1 | 2, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var end := to
	if not hit.is_empty():
		end = hit.position
		var c: Object = hit.collider
		if c.has_method("take_damage") and c.get("team") != team:
			# la tête (au-dessus des épaules) est mortelle
			var head: bool = end.y - (c as Node3D).global_position.y > 1.45
			c.take_damage(Rifle.DAMAGE * (2.0 if head else 1.0), global_position)
			if hud and hud.has_method("hitmark"):
				hud.hitmark()
		else:
			Fx.dust(get_tree().current_scene, end)
	var muzzle: Vector3 = rifle.muzzle_position()
	model.play_action("Pistol_Shoot", 1.0)
	Fx.muzzle_flash(get_tree().current_scene, muzzle)
	Fx.tracer(get_tree().current_scene, muzzle, end)
	Fx.play_shot(get_tree().current_scene, muzzle, 1.4)
	pitch = minf(0.7, pitch + 0.035)   # recul
