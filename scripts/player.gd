extends CharacterBody3D
class_name Player

## First-person controller for Jayce, the camera operator.
## WASD + mouse look, sprint, jump, flashlight (camcorder LED).

const WALK_SPEED := 4.2
const SPRINT_SPEED := 7.0
const ACCEL := 18.0
const JUMP_VELOCITY := 5.5
const GRAVITY := 20.0
const MOUSE_SENS := 0.0022
const BASE_CAM_Y := 1.6

signal stepped

var pitch := 0.0
var flashlight_on := false
var bob_time := 0.0
var _step_accum := 0.0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var flashlight: SpotLight3D = $Head/Camera3D/Flashlight

func _ready() -> void:
	flashlight.light_energy = 0.0

func _unhandled_input(event: InputEvent) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		rotate_y(-motion.relative.x * MOUSE_SENS)
		pitch = clampf(pitch - motion.relative.y * MOUSE_SENS, -1.55, 1.55)
		head.rotation.x = pitch

func _physics_process(delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var speed := SPRINT_SPEED if Input.is_action_pressed("sprint") else WALK_SPEED
	var dir := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	if dir.length() > 0.1:
		velocity.x = move_toward(velocity.x, dir.x * speed, ACCEL * delta * speed)
		velocity.z = move_toward(velocity.z, dir.z * speed, ACCEL * delta * speed)
	else:
		velocity.x = move_toward(velocity.x, 0.0, ACCEL * delta)
		velocity.z = move_toward(velocity.z, 0.0, ACCEL * delta)
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = JUMP_VELOCITY
	move_and_slide()
	var planar_speed := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and planar_speed > 0.5:
		bob_time += delta * planar_speed * 1.6
		camera.position.y = BASE_CAM_Y + sin(bob_time * 2.0) * 0.035
		# Footsteps: one per stride, so the audio can match the surface.
		_step_accum += planar_speed * delta
		var stride := 2.7 if Input.is_action_pressed("sprint") else 2.2
		if _step_accum >= stride:
			_step_accum = 0.0
			stepped.emit()
	else:
		camera.position.y = lerpf(camera.position.y, BASE_CAM_Y, delta * 8.0)
	# Safety net: never fall through the world.
	if position.y < -40.0:
		position = Vector3(0.0, 30.0, 90.0)
		velocity = Vector3.ZERO

func set_flashlight(on: bool) -> void:
	flashlight_on = on
	flashlight.light_energy = 3.0 if on else 0.0

func get_planar_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()
