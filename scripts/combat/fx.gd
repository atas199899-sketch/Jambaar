extends RefCounted
## Effets de combat : lueur de tir, traçante, poussière d'impact, son de détonation.
## Le son est synthétisé (bruit filtré qui décroît) : pas de fichier audio à fournir.

static var _shot: AudioStreamWAV
static var _dust_mat: StandardMaterial3D
static var _flash_mat: StandardMaterial3D


static func gunshot_stream() -> AudioStreamWAV:
	if _shot:
		return _shot
	var rate := 22050
	var n := int(rate * 0.9)
	var data := PackedByteArray()
	data.resize(n * 2)
	var low := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in n:
		var t := float(i) / rate
		var env := exp(-t * 9.0) * (1.0 if t > 0.002 else t / 0.002)
		var white := rng.randf_range(-1.0, 1.0)
		low = lerpf(low, white, 0.18)          # filtre passe-bas : détonation plus sourde
		var boom := sin(t * TAU * 55.0) * exp(-t * 14.0) * 0.6
		var v := clampf((low * 1.8 + boom) * env + white * exp(-t * 60.0) * 0.5, -1.0, 1.0)
		data.encode_s16(i * 2, int(v * 30000.0))
	_shot = AudioStreamWAV.new()
	_shot.format = AudioStreamWAV.FORMAT_16_BITS
	_shot.mix_rate = rate
	_shot.data = data
	return _shot


static func play_shot(parent: Node, pos: Vector3, loud := 1.0) -> void:
	var p := AudioStreamPlayer3D.new()
	p.stream = gunshot_stream()
	p.unit_size = 25.0 * loud
	p.max_db = 3.0
	p.pitch_scale = randf_range(0.9, 1.08)
	parent.add_child(p)
	p.global_position = pos
	p.play()
	p.finished.connect(p.queue_free)


static func muzzle_flash(parent: Node, pos: Vector3) -> void:
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.75, 0.4)
	l.light_energy = 4.0
	l.omni_range = 6.0
	parent.add_child(l)
	l.global_position = pos
	if _flash_mat == null:
		_flash_mat = StandardMaterial3D.new()
		_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flash_mat.albedo_color = Color(1.0, 0.8, 0.4)
	var s := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.07
	sm.height = 0.14
	s.mesh = sm
	s.material_override = _flash_mat
	parent.add_child(s)
	s.global_position = pos
	var tw := parent.create_tween()
	tw.tween_interval(0.05)
	tw.tween_callback(func():
		l.queue_free()
		s.queue_free())


static func tracer(parent: Node, from: Vector3, to: Vector3) -> void:
	var d := to - from
	if d.length() < 0.5:
		return
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.008
	cm.bottom_radius = 0.008
	cm.height = d.length()
	mi.mesh = cm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.9, 0.6, 0.5)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = m
	parent.add_child(mi)
	mi.global_position = from + d * 0.5
	mi.look_at(to, Vector3.UP if absf(d.normalized().y) < 0.95 else Vector3.RIGHT)
	mi.rotate_object_local(Vector3.RIGHT, PI / 2.0)
	var tw := parent.create_tween()
	tw.tween_interval(0.04)
	tw.tween_callback(mi.queue_free)


static func dust(parent: Node, pos: Vector3, color := Color(0.55, 0.48, 0.38)) -> void:
	if _dust_mat == null:
		_dust_mat = StandardMaterial3D.new()
		_dust_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_dust_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for k in 4:
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.08
		sm.height = 0.16
		mi.mesh = sm
		var m := _dust_mat.duplicate()
		m.albedo_color = Color(color.r, color.g, color.b, 0.6)
		mi.material_override = m
		parent.add_child(mi)
		mi.global_position = pos + Vector3(randf_range(-0.1, 0.1), randf_range(0.0, 0.15), randf_range(-0.1, 0.1))
		var tw := parent.create_tween()
		tw.set_parallel(true)
		tw.tween_property(mi, "scale", Vector3.ONE * randf_range(2.5, 4.0), 0.6)
		tw.tween_property(mi, "global_position", mi.global_position + Vector3(randf_range(-0.3, 0.3), 0.5, randf_range(-0.3, 0.3)), 0.6)
		tw.tween_property(m, "albedo_color:a", 0.0, 0.6)
		tw.chain().tween_callback(mi.queue_free)
