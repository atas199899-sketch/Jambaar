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
	# normales abîmées à l'import (certains FBX) : on les recalcule, lissées
	if look.get("fix_normals", false):
		for mi: MeshInstance3D in inst.find_children("*", "MeshInstance3D", true, false):
			var src: Mesh = mi.mesh
			var am := ArrayMesh.new()
			for k in src.get_surface_count():
				var st := SurfaceTool.new()
				st.create_from(src, k)
				if src.surface_get_format(k) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS:
					st.set_skin_weight_count(SurfaceTool.SKIN_8_WEIGHTS)
				st.set_smooth_group(0)
				st.generate_normals()
				st.generate_tangents()
				var arr := st.commit_to_arrays()
				var nv: int = (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
				var nb: int = (arr[Mesh.ARRAY_BONES] as PackedInt32Array).size() if arr[Mesh.ARRAY_BONES] != null else 0
				var flags: int = Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if nv > 0 and nb == nv * 8 else 0
				am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, flags)
				am.surface_set_material(k, src.surface_get_material(k))
			mi.mesh = am
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
			if look.get("flat", false) and m.resource_name.begins_with("male_"):
				var fm := StandardMaterial3D.new()
				fm.albedo_color = Color(0.85, 0.82, 0.75)
				mi.set_surface_override_material(k, fm)
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
	# corpulence : on affine le torse et les membres (épaisseur des os, pas la longueur)
	if look.has("slim"):
		var k: float = look.slim
		for b in ["spine_02", "spine_03", "mixamorig_Spine1", "mixamorig_Spine2", "spine02", "spine03", "spine04", "spine05"]:
			var i := _bone([b])
			if i >= 0:
				skeleton.set_bone_pose_scale(i, Vector3(k, 1.0, k))
	if look.get("no_anim", false):
		anim = null
		return
	var res: Dictionary = Retarget.library_for(_model_path, inst, skeleton, ANIMS, look.get("arm_in", 0.0))
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
	if anim == null:
		return
	if n != _current and anim.has_animation(n):
		anim.play(n)
		_current = n
	anim.speed_scale = speed


func animate(speed: float, delta: float, _airborne := false) -> void:
	if anim == null:
		return
	if _action > 0.0:
		_action -= delta
		return
	if crouching:
		if speed > 0.15:
			_play("Crouch_Fwd", clampf(speed / 1.6, 0.6, 1.4))
		else:
			_play("Crouch_Idle")
	elif aiming and speed < 0.3:
		_play("Idle")
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
var _shouldered: Node3D = null
var aim_target = null        # point visé (Vector3) : le canon est orienté exactement vers lui
var aim_pitch := 0.0          # inclinaison verticale de la visée (radians, positif = vers le haut)
var _ik_r: SkeletonIK3D
var _ik_l: SkeletonIK3D
var _grip_r: Node3D
var _grip_l: Node3D


## Le fusil à la bretelle est recalé à chaque image, après la mise à jour du squelette.
func _process(_d: float) -> void:
	if _slung and not _rifle_in_hand and is_instance_valid(_slung):
		_sling(_slung)
	elif _shouldered and _rifle_in_hand and is_instance_valid(_shouldered):
		_shoulder(_shouldered)


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
		rifle.reparent(self, false)
		_shouldered = rifle
		_start_ik(rifle)
		return
	_shouldered = null
	_stop_ik()
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
	rifle.global_transform = Transform3D(b, _back_att.global_position + back * 0.17 - up * 0.05)



# ---------------------------------------------------------------- fusil épaulé (pose de tir construite par code)

func _bone(names: Array) -> int:
	for k in skeleton.get_bone_count():
		if Retarget.clean(skeleton.get_bone_name(k)) in names:
			return k
	return -1


## Crosse contre l'épaule droite, canon dans la direction visée, à hauteur de joue.
func _shoulder(rifle: Node3D) -> void:
	var sh := _bone(["upperarm_r", "mixamorig_RightArm"])
	var neck := _bone(["neck_01", "mixamorig_Neck"])
	if sh < 0:
		return
	var sk_xf := skeleton.global_transform
	var shoulder: Vector3 = sk_xf * skeleton.get_bone_global_pose(sh).origin
	var neck_p: Vector3 = sk_xf * skeleton.get_bone_global_pose(neck).origin if neck >= 0 else shoulder
	var fwd := -global_basis.z.normalized()
	var right := global_basis.x.normalized()
	var aim := (fwd * cos(aim_pitch) + Vector3.UP * sin(aim_pitch)).normalized()
	# la crosse (≈ 0,38 m derrière la poignée) se cale entre l'épaule et le cou, un peu plus haut
	var butt := shoulder.lerp(neck_p, 0.35) + Vector3.UP * 0.02 + fwd * 0.02
	if aim_target != null:
		aim = ((aim_target as Vector3) - butt).normalized()
	var grip := butt + aim * 0.36
	var up := right.cross(aim).normalized() * -1.0
	if up.y < 0.0:
		up = -up
	rifle.global_transform = Transform3D(Basis.looking_at(aim, up), grip)


func _start_ik(rifle: Node3D) -> void:
	if _ik_r == null:
		_grip_r = Node3D.new()
		_grip_l = Node3D.new()
		var r_up := _bone(["upperarm_r", "mixamorig_RightArm"])
		var r_hand := _bone(["hand_r", "mixamorig_RightHand"])
		var l_up := _bone(["upperarm_l", "mixamorig_LeftArm"])
		var l_hand := _bone(["hand_l", "mixamorig_LeftHand"])
		if r_up < 0 or r_hand < 0 or l_up < 0 or l_hand < 0:
			return
		_ik_r = _make_ik(skeleton.get_bone_name(r_up), skeleton.get_bone_name(r_hand), _grip_r)
		_ik_l = _make_ik(skeleton.get_bone_name(l_up), skeleton.get_bone_name(l_hand), _grip_l)
	# cibles des mains, attachées au fusil : poignée (main droite) et fût (main gauche)
	for g in [_grip_r, _grip_l]:
		if g.get_parent():
			g.get_parent().remove_child(g)
		rifle.add_child(g)
	_grip_r.transform = Transform3D(Basis.from_euler(Vector3(0, 0, -PI / 2.0)), Vector3(0.02, -0.04, 0.02))
	_grip_l.transform = Transform3D(Basis.from_euler(Vector3(0, 0, PI / 2.0)), Vector3(-0.02, -0.03, -0.32))
	_ik_r.target_node = _ik_r.get_path_to(_grip_r)
	_ik_l.target_node = _ik_l.get_path_to(_grip_l)
	_ik_r.start()
	_ik_l.start()


func _make_ik(root: String, tip: String, target: Node3D) -> SkeletonIK3D:
	var ik := SkeletonIK3D.new()
	skeleton.add_child(ik)
	ik.root_bone = root
	ik.tip_bone = tip
	ik.interpolation = 1.0
	ik.override_tip_basis = false
	ik.max_iterations = 8
	ik.set_meta("target", target)
	ik.target_node = ik.get_path_to(target) if target.is_inside_tree() else NodePath()
	return ik


func _stop_ik() -> void:
	if _ik_r:
		_ik_r.stop()
		_ik_l.stop()
