extends Node3D
## Personnage basé sur un vrai modèle 3D importé (squelette Mixamo), animé avec la bibliothèque
## Quaternius convertie par retarget.gd. Même interface que humanoid.gd :
## build(), animate(), set_combat_pose(), play_action(), hand_attachment().

const Retarget = preload("res://scripts/characters/retarget.gd")
const Props = preload("res://scripts/combat/props.gd")

const ANIMS := ["Idle", "Walk", "Jog_Fwd", "Sprint", "Crouch_Idle", "Crouch_Fwd", "Pistol_Aim_Neutral",
	"Pistol_Shoot", "Pistol_Reload", "Hit_Chest", "Death01", "Jump"]
const LOOPS := ["Idle", "Walk", "Jog_Fwd", "Sprint", "Crouch_Idle", "Crouch_Fwd", "Pistol_Aim_Neutral"]

var anim: AnimationPlayer
var skeleton: Skeleton3D
var crouching := false
var aiming := false
var real = null           # compatibilité avec humanoid.gd (pas de personnage Quaternius ici)
var _current := ""
var _action := 0.0
var _model_path := ""


## look : model (chemin .glb), height, albedo (texture de remplacement),
## hide_materials (noms de matériaux à masquer, ex. filet de camouflage).
func build(look: Dictionary) -> void:
	_model_path = look.model
	var inst: Node3D = load(_model_path).instantiate()
	add_child(inst)
	var b: AABB = Props.bounds(inst)
	var s: float = look.get("height", 1.8) / maxf(b.size.y, 0.001)
	inst.scale = Vector3.ONE * s
	inst.position = Vector3(-b.get_center().x * s, -b.position.y * s, -b.get_center().z * s)
	skeleton = inst.find_children("*", "Skeleton3D", true, false)[0]
	var tex: Texture2D = load(look.albedo) if look.has("albedo") and ResourceLoader.exists(look.albedo) else null
	var hide: Array = look.get("hide_materials", [])
	for mi: MeshInstance3D in inst.find_children("*", "MeshInstance3D", true, false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		for k in mi.mesh.get_surface_count():
			var m: Material = mi.mesh.surface_get_material(k)
			if m == null:
				continue
			if m.resource_name in hide:
				mi.set_surface_override_material(k, _invisible())
			elif tex and m.resource_name == look.get("albedo_material", "") and m is BaseMaterial3D:
				var mm: BaseMaterial3D = m.duplicate()
				mm.albedo_texture = tex
				mi.set_surface_override_material(k, mm)
	var res: Dictionary = Retarget.library_for(_model_path, inst, skeleton, ANIMS)
	# le modèle regarde vers +Z dans son espace : on le tourne vers -Z (convention du jeu)
	inst.rotation.y = PI
	anim = AnimationPlayer.new()
	inst.add_child(anim)
	anim.root_node = NodePath("..")
	var lib: AnimationLibrary = res.library
	for n in lib.get_animation_list():
		lib.get_animation(n).loop_mode = Animation.LOOP_LINEAR if n in LOOPS else Animation.LOOP_NONE
	anim.add_animation_library("", lib)
	anim.playback_default_blend_time = 0.25
	_play("Idle")
	anim.seek(randf(), true)


static var _inv: StandardMaterial3D
static func _invisible() -> StandardMaterial3D:
	if _inv == null:
		_inv = StandardMaterial3D.new()
		_inv.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_inv.albedo_color = Color(0, 0, 0, 0)
	return _inv


func _play(n: String, speed := 1.0) -> void:
	if n != _current and anim.has_animation(n):
		anim.play(n)
		_current = n
	anim.speed_scale = speed


func animate(speed: float, delta: float, _airborne := false) -> void:
	if _action > 0.0:
		_action -= delta
		return
	if crouching:
		if speed > 0.15:
			_play("Crouch_Fwd", clampf(speed / 1.6, 0.6, 1.4))
		else:
			_play("Crouch_Idle")
	elif aiming and speed < 0.3:
		_play("Pistol_Aim_Neutral")
	elif speed > 4.2:
		_play("Sprint", clampf(speed / 5.5, 0.8, 1.3))
	elif speed > 2.4:
		_play("Jog_Fwd", clampf(speed / 3.6, 0.7, 1.4))
	elif speed > 0.15:
		_play("Walk", clampf(speed / 1.45, 0.5, 1.5))
	else:
		_play("Idle")


func set_combat_pose(crouch: bool, aim: bool) -> void:
	crouching = crouch
	aiming = aim


func play_action(n: String, speed_scale := 1.0) -> float:
	if not anim.has_animation(n):
		return 0.0
	anim.play(n, 0.15)
	anim.speed_scale = speed_scale
	_current = n
	_action = anim.get_animation(n).length / speed_scale
	return _action


func set_talking(_v: bool) -> void:
	pass


func hand_attachment() -> BoneAttachment3D:
	var i := -1
	for k in skeleton.get_bone_count():
		if Retarget.clean(skeleton.get_bone_name(k)) == "mixamorig_RightHand":
			i = k
	if i < 0:
		return null
	var att := BoneAttachment3D.new()
	att.bone_idx = i
	skeleton.add_child(att)
	return att
