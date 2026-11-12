extends RefCounted
## Vrais modèles 3D d'armes et d'équipement (Sketchfab, CC BY 4.0 — voir assets/CREDITS.md).
## Chaque modèle est mis à sa taille réelle et orienté : l'axe long le long de -Z,
## la bouche du canon (ou la pointe) vers -Z, centré sur la poignée.

## length : longueur réelle (m) ; flip : retourner si le canon pointe du mauvais côté ;
## grip : position de la main sur la longueur (0 = arrière, 1 = avant).
const MODELS := {
	"mas36": {"path": "res://assets/props/mas36/scene.gltf", "length": 1.02, "flip": false, "grip": 0.38},
	"berthier": {"path": "res://assets/props/berthier/scene.gltf", "length": 1.13, "flip": false, "grip": 0.36},
	"lebel": {"path": "res://assets/props/lebel/scene.gltf", "length": 1.82, "flip": false, "grip": 0.27},
	"coupe_coupe": {"path": "res://assets/props/coupe_coupe/scene.gltf", "length": 0.52, "flip": true, "grip": 0.12, "drop": ["mont"]},
	"adrian": {"path": "res://assets/props/adrian/scene.gltf", "length": 0.31, "flip": false, "grip": 0.5},
}

static var _scenes := {}


static func has(kind: String) -> bool:
	return MODELS.has(kind) and ResourceLoader.exists(MODELS[kind].path)


static func bounds(top: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mi: MeshInstance3D in top.find_children("*", "MeshInstance3D", true, false):
		var t := Transform3D()
		var n: Node = mi
		while n != top:
			t = (n as Node3D).transform * t
			n = n.get_parent()
		var b := t * mi.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out


## Renvoie un Node3D prêt à l'emploi : origine sur la poignée, canon vers -Z.
static func make(kind: String) -> Node3D:
	var info: Dictionary = MODELS[kind]
	if not _scenes.has(info.path):
		_scenes[info.path] = load(info.path)
	var inst: Node3D = _scenes[info.path].instantiate()
	# maillages « skinnés » (armes animées) : on les fige dans leur pose de repos
	for mi: MeshInstance3D in inst.find_children("*", "MeshInstance3D", true, false):
		if mi.skin != null:
			mi.skin = null
			mi.skeleton = NodePath()
	# parties à retirer (exemplaire démonté, etc.)
	for sub in info.get("drop", []):
		for n in inst.find_children("*", "Node3D", true, false):
			if is_instance_valid(n) and String(n.name).contains(sub) and String(n.name).contains("(d"):
				n.free()
	var b := bounds(inst)
	var s := b.size
	# axe le plus long → Z
	var basis := Basis()
	if s.x >= s.y and s.x >= s.z:
		basis = Basis(Vector3.UP, PI / 2.0)
	elif s.y >= s.x and s.y >= s.z:
		basis = Basis(Vector3.RIGHT, PI / 2.0)
	if info.flip:
		basis = Basis(Vector3.UP, PI) * basis
	var length: float = maxf(s.x, maxf(s.y, s.z))
	var sc: float = info.length / maxf(length, 0.0001)
	inst.transform = Transform3D(basis.scaled(Vector3.ONE * sc), Vector3.ZERO)
	var nb := inst.transform * b
	var grip_z: float = lerpf(nb.end.z, nb.position.z, info.grip)
	inst.position -= Vector3(nb.get_center().x, nb.get_center().y, grip_z)
	var root := Node3D.new()
	root.name = kind
	root.add_child(inst)
	for gi in root.find_children("*", "GeometryInstance3D", true, false):
		gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	root.set_meta("length", info.length)
	root.set_meta("muzzle_z", -(info.length * (1.0 - info.grip)))
	return root
