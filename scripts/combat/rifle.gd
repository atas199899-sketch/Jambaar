extends Node3D
## Fusil à verrou d'époque (silhouette inspirée du MAS 36), construit en code.
## Coup par coup : 5 cartouches par chargeur, manœuvre de la culasse entre deux tirs.

const MAG_SIZE := 5
const CYCLE_TIME := 1.1     # temps de manœuvre de la culasse (s)
const RELOAD_TIME := 2.6
const RANGE := 400.0
const DAMAGE := 100.0

var mag := MAG_SIZE
var reserve := 40
var _cooldown := 0.0
var reloading := 0.0
var muzzle: Node3D


var model_kind := "mas36"


func _ready() -> void:
	var Props = load("res://scripts/combat/props.gd")
	if Props.has(model_kind):
		# vrai modèle 3D (Sketchfab, CC BY) ; origine sur la poignée, canon vers -Z
		var m: Node3D = Props.make(model_kind)
		m.position = Vector3(0, 0.02, -0.05)
		add_child(m)
		muzzle = Node3D.new()
		muzzle.position = Vector3(0, 0.04, m.get_meta("muzzle_z") - 0.05)
		add_child(muzzle)
		return
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("5a3a22")
	wood.roughness = 0.7
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color("2b2d30")
	steel.metallic = 0.85
	steel.roughness = 0.35
	# le fusil est orienté le long de -Z (canon vers l'avant)
	_part(BoxMesh.new(), wood, Vector3(0, -0.03, 0.12), Vector3(0.05, 0.09, 0.42))       # crosse
	_part(BoxMesh.new(), wood, Vector3(0, -0.005, -0.3), Vector3(0.045, 0.05, 0.5))      # fût
	var barrel := CylinderMesh.new()
	barrel.top_radius = 0.011
	barrel.bottom_radius = 0.013
	barrel.height = 0.62
	var b := _part(barrel, steel, Vector3(0, 0.025, -0.45), Vector3.ONE)
	b.rotation.x = PI / 2.0
	_part(BoxMesh.new(), steel, Vector3(0, 0.03, -0.05), Vector3(0.045, 0.05, 0.16))     # boîtier de culasse
	var bolt := CylinderMesh.new()
	bolt.top_radius = 0.008
	bolt.bottom_radius = 0.008
	bolt.height = 0.08
	var bh := _part(bolt, steel, Vector3(0.05, 0.035, -0.02), Vector3.ONE)
	bh.rotation.z = PI / 2.0
	muzzle = Node3D.new()
	muzzle.position = Vector3(0, 0.025, -0.77)
	add_child(muzzle)


func _part(mesh: Mesh, m: Material, pos: Vector3, scl: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.scale = scl
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mi)
	return mi


func _process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	if reloading > 0.0:
		reloading -= delta
		if reloading <= 0.0:
			var n := mini(MAG_SIZE - mag, reserve)
			mag += n
			reserve -= n


func can_fire() -> bool:
	return mag > 0 and _cooldown <= 0.0 and reloading <= 0.0


## Consomme une cartouche ; renvoie vrai si le coup part.
func fire() -> bool:
	if not can_fire():
		return false
	mag -= 1
	_cooldown = CYCLE_TIME
	return true


func start_reload() -> bool:
	if reloading > 0.0 or mag >= MAG_SIZE or reserve <= 0:
		return false
	reloading = RELOAD_TIME
	return true


func muzzle_position() -> Vector3:
	return muzzle.global_position
