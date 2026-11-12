extends RefCounted
## Ciel, soleil et brume communs aux chapitres. `hour` : heure de la journée (0-24).

static func make(parent: Node, hour: float, overcast := 0.0) -> Dictionary:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sun_angle_max = 20.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.6
	env.ambient_light_color = Color("d8c7a8")
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.85
	env.ssao_enabled = true
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.fog_enabled = true
	env.fog_density = 0.002 + overcast * 0.004
	env.adjustment_enabled = true
	env.adjustment_saturation = lerpf(1.05, 0.8, overcast)
	var we := WorldEnvironment.new()
	we.environment = env
	parent.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 160.0
	parent.add_child(sun)
	var elev := (hour - 7.0) / 12.0 * PI
	var height := sin(elev)
	var day := clampf(height * 3.0 + 0.3, 0.0, 1.0)
	var dusk := clampf(1.0 - absf(height - 0.08) / 0.3, 0.0, 1.0)
	sun.rotation = Vector3(-clampf(elev, 0.15, PI - 0.15), deg_to_rad(-35.0), 0.0)
	sun.light_energy = lerpf(0.2, 1.1, day) * lerpf(1.0, 0.6, overcast)
	sun.light_color = Color(1.0, 0.95, 0.85).lerp(Color(1.0, 0.65, 0.4), dusk)
	sky_mat.sky_top_color = Color("2f6db5").lerp(Color("7d8a96"), overcast)
	sky_mat.sky_horizon_color = Color("a9cbe6").lerp(Color("f0a060"), dusk * 0.7).lerp(Color("b4b8bc"), overcast)
	sky_mat.ground_horizon_color = sky_mat.sky_horizon_color
	sky_mat.ground_bottom_color = Color("5a4c3a")
	env.fog_light_color = sky_mat.sky_horizon_color
	return {"env": env, "sun": sun, "sky": sky_mat}
