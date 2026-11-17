extends Node
class_name DayNight

## Drives the sun, moon, sky colors and fog from the game clock.
## Morning -> golden afternoon -> sunset -> night. The night is the point.

var sun: DirectionalLight3D
var moon: DirectionalLight3D
var sun_pivot: Node3D
var world_env: WorldEnvironment
var sky_mat: ProceduralSkyMaterial
var env: Environment

var time_hours := 8.0
var target_hours := 8.0
var transitioning := false
var transition_speed := 1.5 # game-hours per real second during a time skip

var day_top := Color(0.25, 0.5, 0.85)
var day_horizon := Color(0.65, 0.8, 0.95)
var day_ground := Color(0.3, 0.3, 0.25)
var sunset_top := Color(0.15, 0.12, 0.3)
var sunset_horizon := Color(0.95, 0.45, 0.15)
var sunset_ground := Color(0.2, 0.12, 0.1)
var night_top := Color(0.01, 0.015, 0.05)
var night_horizon := Color(0.03, 0.04, 0.09)
var night_ground := Color(0.01, 0.01, 0.02)

func setup(p_sun: DirectionalLight3D, p_moon: DirectionalLight3D, p_pivot: Node3D, p_env: WorldEnvironment) -> void:
	sun = p_sun
	moon = p_moon
	sun_pivot = p_pivot
	world_env = p_env
	env = p_env.environment
	sky_mat = env.sky.sky_material as ProceduralSkyMaterial
	_apply_time()

func set_time(hours: float) -> void:
	time_hours = hours
	target_hours = hours
	transitioning = false
	_apply_time()

func transition_to(hours: float) -> void:
	target_hours = hours
	transitioning = true

func is_night() -> bool:
	return time_hours >= 18.5

func _process(delta: float) -> void:
	if transitioning:
		var step := transition_speed * delta
		if absf(target_hours - time_hours) <= step:
			time_hours = target_hours
			transitioning = false
		else:
			time_hours += signf(target_hours - time_hours) * step
		_apply_time()

func _apply_time() -> void:
	var elev := sin((time_hours - 6.0) / 12.0 * PI) * 65.0 # deg; 0 at 06:00 & 18:00
	var azim := 90.0 + (time_hours - 6.0) * 15.0 # east -> south -> west
	sun_pivot.rotation.y = deg_to_rad(azim)
	sun.rotation.x = deg_to_rad(-elev)
	var t_day := clampf((elev - 5.0) / 15.0, 0.0, 1.0)
	var t_night := clampf((-elev - 2.0) / 8.0, 0.0, 1.0)
	# Sun light.
	var sun_energy := lerpf(0.0, 1.15, t_day)
	sun.light_energy = sun_energy
	if elev < 12.0 and elev > -6.0:
		sun.light_color = Color(1.0, 0.55, 0.25)
	else:
		sun.light_color = Color(1.0, 0.95, 0.85)
	# Moon.
	moon.light_energy = t_night * 0.18
	# Sky colors.
	var top := sunset_top.lerp(day_top, t_day).lerp(night_top, t_night)
	var horizon := sunset_horizon.lerp(day_horizon, t_day).lerp(night_horizon, t_night)
	var ground := sunset_ground.lerp(day_ground, t_day).lerp(night_ground, t_night)
	sky_mat.sky_top_color = top
	sky_mat.sky_horizon_color = horizon
	sky_mat.ground_bottom_color = ground
	sky_mat.ground_horizon_color = horizon.darkened(0.3)
	# Fog and ambient.
	env.fog_density = lerpf(0.0018, 0.014, t_night)
	env.ambient_light_energy = lerpf(lerpf(0.5, 0.55, t_day), 0.06, t_night)
	env.fog_light_color = horizon
