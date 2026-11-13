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
	skeleton = inst.find_children("*", "Skeleton3D", true, false)[0]
	# taille mesurée sur le squelette (plus fiable que la boîte des maillages déformés) :
	# du plus bas des os (pieds) jusqu'à la tête, + 8 % pour le crâne
	var to_root: Transform3D = Retarget.to_root(inst, skeleton)
	var rests: Array = []
	rests.resize(skeleton.get_bone_count())
	var lo := INF
	var head_y := -INF
	var hips := Vector3.ZERO
	for k in skeleton.get_bone_count():
		var p := skeleton.get_bone_parent(k)
		rests[k] = (rests[p] if p >= 0 else Transform3D()) * skeleton.get_bone_rest(k)
		var w: Vector3 = to_root * (rests[k] as Transform3D).origin
		var nm := Retarget.clean(skeleton.get_bone_name(k)).to_lower()
		lo = minf(lo, w.y)
		if nm in ["head", "mixamorig_head"]:
			head_y = w.y
		if nm in ["pelvis", "mixamorig_hips", "hips"]:
			hips = w
	var model_h := (head_y - lo) * 1.08 if head_y > lo else 1.8
	var s: float = look.get("height", 1.8) / maxf(model_h, 0.001)
	inst.scale = Vector3.ONE * s
	inst.position = Vector3(-hips.x * s, -lo * s, -hips.z * s)
	var swaps: Dictionary = look.get("textures", {})
	if look.has("albedo"):
		swaps[look.get("albedo_material", "")] = look.albedo
	var hide: Array = look.get("hide_materials", [])
	for mi: MeshInstance3D in inst.find_children("*", "MeshInstance3D", true, false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		for k in mi.mesh.get_surface_count():
			var m: Material = mi.mesh.surface_get_material(k)
			if m == null:
				continue
			if m.resource_name in hide:
				mi.set_surface_override_material(k, _invisible())
			elif swaps.has(m.resource_name) and m is BaseMaterial3D and ResourceLoader.exists(swaps[m.resource_name]):
				var mm: BaseMaterial3D = m.duplicate()
				mm.albedo_texture = load(swaps[m.resource_name])
				mi.set_surface_override_material(k, mm)
				if m.resource_name == look.get("skin_material", "Body") and look.has("skin_tint"):
					mm.albedo_color = look.skin_tint
	if look.get("hat", "") == "adrian" and Props.has("adrian"):
		_add_helmet()
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
		if Retarget.clean(skeleton.get_bone_name(k)) in ["mixamorig_RightHand", "hand_r"]:
			i = k
	if i < 0:
		return null
	var att := BoneAttachment3D.new()
	att.bone_idx = i
	skeleton.add_child(att)
	return att


func _add_helmet() -> void:
	var head := -1
	for k in skeleton.get_bone_count():
		if Retarget.clean(skeleton.get_bone_name(k)) in ["Head", "head", "mixamorig_Head"]:
			head = k
	if head < 0:
		return
	var att := BoneAttachment3D.new()
	att.bone_idx = head
	skeleton.add_child(att)
	var holder := Node3D.new()
	att.add_child(holder)
	var h: Node3D = Props.make("adrian")
	holder.add_child(h)
	# le modèle d'origine est vert vif : on le ternit vers le kaki-brun des casques de 1940
	for mi: MeshInstance3D in h.find_children("*", "MeshInstance3D", true, false):
		for k in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(k)
			if m is BaseMaterial3D:
				var mm: BaseMaterial3D = m.duplicate()
				mm.albedo_color = mm.albedo_color * Color(0.62, 0.52, 0.36)
				mm.roughness = 0.75
				mi.set_surface_override_material(k, mm)
	_place_helmet.call_deferred(holder, att)


## Le casque est placé en mètres dans l'espace du monde : on annule l'échelle de l'os,
## puis on le pose au sommet du crâne.
func _place_helmet(holder: Node3D, att: BoneAttachment3D) -> void:
	await get_tree().process_frame
	var gs: float = att.global_transform.basis.get_scale().x
	holder.scale = Vector3.ONE / maxf(gs, 0.0001)
	holder.global_basis = Basis.from_euler(Vector3(0, global_rotation.y, 0)).scaled(Vector3.ONE * 0.95)
	holder.global_position = att.global_position + Vector3(0, 0.16, 0)



# ---------------------------------------------------------------- fusil : en main ou à la bretelle

var _back_att: BoneAttachment3D
var _rifle_in_hand := true
var _slung: Node3D = null


## Le fusil à la bretelle est recalé à chaque image, après la mise à jour du squelette.
func _process(_d: float) -> void:
	if _slung and not _rifle_in_hand and is_instance_valid(_slung):
		_sling(_slung)


## Met le fusil dans la main (visée, tir) ou à la bretelle dans le dos (marche, repos).
func hold_rifle(rifle: Node3D, in_hand: bool) -> void:
	if rifle == null or not rifle.is_inside_tree():
		return
	if not rifle.has_meta("hand_parent"):
		rifle.set_meta("hand_parent", rifle.get_parent())
		rifle.set_meta("hand_xf", rifle.transform)
	if in_hand == _rifle_in_hand:
		return
	_rifle_in_hand = in_hand
	if in_hand:
		_slung = null
		rifle.reparent(rifle.get_meta("hand_parent"), false)
		rifle.transform = rifle.get_meta("hand_xf")
		return
	if _back_att == null:
		var spine := -1
		for k in skeleton.get_bone_count():
			if Retarget.clean(skeleton.get_bone_name(k)) in ["spine_03", "mixamorig_Spine2"]:
				spine = k
		if spine < 0:
			return
		_back_att = BoneAttachment3D.new()
		_back_att.bone_idx = spine
		skeleton.add_child(_back_att)
	rifle.reparent(_back_att, false)
	_slung = rifle


## Fusil en travers du dos, canon vers le haut au-dessus de l'épaule gauche.
func _sling(rifle: Node3D) -> void:
	if _rifle_in_hand or not is_instance_valid(rifle):
		return
	var fwd := -global_basis.z.normalized()
	var right := global_basis.x.normalized()
	var up := Vector3.UP
	var muzzle_dir := (up * 0.85 - right * 0.5).normalized()
	var back := -fwd
	var b := Basis.looking_at(muzzle_dir, back)
	rifle.global_transform = Transform3D(b, _back_att.global_position + back * 0.3 - up * 0.05)
