extends CharacterBody3D
class_name Companion

## One of the three friends (Chris, Sal, Harry). Real people, not capsules:
## distinct looks (shirt, hair, height), procedural walk/idle animation,
## and they hike the trail behind Jayce by following his actual footprints
## (a breadcrumb path), not by cutting straight across the map.
##
## Reactions: barks above their head + subtitles, a scared state (they
## huddle close and look at the player), and a scripted manual target used
## by the disappearance system — a friend can be walked somewhere on purpose.

const FOLLOW_SPEED := 5.0
const CATCHUP_SPEED := 7.0
const GRAVITY := 20.0

var friend_name := "Chris"
var follow_target: Node3D
var slot_offset := Vector3.ZERO
var path: Array = [] # shared breadcrumb trail of the player's positions
var path_offset := 12
var bark_timer := 0.0
var enabled_follow := true
var scared := false
var manual_target := Vector3.ZERO
var has_manual_target := false
var face_target := Vector3.ZERO
var has_face_target := false

var walk_phase := 0.0
var idle_time := 0.0
var moving := false
var _last_pos := Vector3.ZERO

@onready var body_node: Node3D = $Body
@onready var torso_mesh: MeshInstance3D = $Body/Torso
@onready var head_pivot: Node3D = $HeadPivot
@onready var leg_l: Node3D = $LegL
@onready var leg_r: Node3D = $LegR
@onready var shin_l: Node3D = $LegL/ShinPivot
@onready var shin_r: Node3D = $LegR/ShinPivot
@onready var arm_l: Node3D = $ArmL
@onready var arm_r: Node3D = $ArmR
@onready var fore_l: Node3D = $ArmL/ForearmPivot
@onready var fore_r: Node3D = $ArmR/ForearmPivot
@onready var name_label: Label3D = $NameLabel
@onready var bark_label: Label3D = $BarkLabel

func setup(def: Dictionary, target: Node3D, offset: Vector3) -> void:
	friend_name = def.get("name", "Chris")
	follow_target = target
	slot_offset = offset
	Humanoid.build_companion(self, def)
	name_label.text = friend_name
	name_label.modulate = (def.get("shirt", Color(0.8, 0.2, 0.15)) as Color).lightened(0.4)
	# "height" in the defs is a scale factor around the 1.75 m base build.
	scale = Vector3.ONE * float(def.get("height", 1.0))

func customize(_hair_color: Color, _hair_style: int, height_scale: float) -> void:
	# Kept for compatibility; the look is now built in setup() via Humanoid.
	scale = Vector3.ONE * height_scale

func set_path(p_path: Array, p_offset: int) -> void:
	path = p_path
	path_offset = p_offset

func set_scared(on: bool) -> void:
	scared = on

func set_manual_target(pos: Vector3) -> void:
	manual_target = pos
	has_manual_target = true

func clear_manual_target() -> void:
	has_manual_target = false

func at_manual_target() -> bool:
	if not has_manual_target:
		return false
	return global_position.distance_to(manual_target) < 3.0

func look_at_point(pos: Vector3) -> void:
	face_target = pos
	has_face_target = true

func clear_look_target() -> void:
	has_face_target = false

func _ready() -> void:
	bark_label.visible = false
	_last_pos = global_position

func _process(delta: float) -> void:
	if bark_timer > 0.0:
		bark_timer -= delta
		if bark_timer <= 0.0:
			bark_label.visible = false
	# Walk cycle / idle animation. Two-segment limbs: thighs swing, knees
	# bend on the forward swing, elbows keep a slight bend.
	var moved := global_position.distance_to(_last_pos)
	_last_pos = global_position
	if moving:
		walk_phase += moved * 2.4
		var s := sin(walk_phase)
		leg_l.rotation.x = s * 0.55
		leg_r.rotation.x = -s * 0.55
		shin_l.rotation.x = -maxf(0.0, s) * 0.7
		shin_r.rotation.x = -maxf(0.0, -s) * 0.7
		arm_l.rotation.x = -s * 0.45
		arm_r.rotation.x = s * 0.45
		fore_l.rotation.x = -0.2 - maxf(0.0, -s) * 0.4
		fore_r.rotation.x = -0.2 - maxf(0.0, s) * 0.4
		body_node.position.y = absf(cos(walk_phase)) * 0.045
		body_node.rotation.z = s * 0.03
		body_node.rotation.x = 0.04
		head_pivot.position.y = 1.62 + absf(cos(walk_phase)) * 0.02
		head_pivot.rotation.y = lerpf(head_pivot.rotation.y, 0.0, delta * 6.0)
	else:
		# Ease limbs back to neutral, breathe, look around.
		leg_l.rotation.x = lerpf(leg_l.rotation.x, 0.0, delta * 8.0)
		leg_r.rotation.x = lerpf(leg_r.rotation.x, 0.0, delta * 8.0)
		shin_l.rotation.x = lerpf(shin_l.rotation.x, 0.0, delta * 8.0)
		shin_r.rotation.x = lerpf(shin_r.rotation.x, 0.0, delta * 8.0)
		arm_l.rotation.x = lerpf(arm_l.rotation.x, 0.0, delta * 8.0)
		arm_r.rotation.x = lerpf(arm_r.rotation.x, 0.0, delta * 8.0)
		fore_l.rotation.x = lerpf(fore_l.rotation.x, -0.15, delta * 8.0)
		fore_r.rotation.x = lerpf(fore_r.rotation.x, -0.15, delta * 8.0)
		body_node.position.y = lerpf(body_node.position.y, 0.0, delta * 8.0)
		body_node.rotation.z = lerpf(body_node.rotation.z, 0.0, delta * 8.0)
		body_node.rotation.x = lerpf(body_node.rotation.x, 0.0, delta * 8.0)
		head_pivot.position.y = lerpf(head_pivot.position.y, 1.62, delta * 8.0)
		idle_time += delta
		var breathe := 1.0 + sin(idle_time * 1.6) * 0.015
		torso_mesh.scale = Vector3(1.0, breathe, 1.0)
		if has_face_target:
			var to := face_target - global_position
			var target_yaw := atan2(-to.x, -to.z) - rotation.y
			head_pivot.rotation.y = lerp_angle(head_pivot.rotation.y, clampf(target_yaw, -1.2, 1.2), delta * 4.0)
		else:
			head_pivot.rotation.y = sin(idle_time * 0.45 + float(friend_name.length())) * 0.35

func _physics_process(delta: float) -> void:
	var target_pos := Vector3.ZERO
	var have_target := false
	if has_manual_target:
		target_pos = manual_target
		have_target = true
	elif follow_target != null and enabled_follow:
		if path.size() > path_offset + 2:
			# Follow the player's actual footprints, N steps back.
			target_pos = path[path.size() - 1 - path_offset]
			have_target = true
		else:
			target_pos = follow_target.global_position + follow_target.global_transform.basis * slot_offset
			have_target = true
	if not have_target:
		velocity.x = 0.0
		velocity.z = 0.0
		moving = false
	else:
		var to := target_pos - global_position
		to.y = 0.0
		var dist := to.length()
		moving = dist > 0.6
		if dist > 2.0:
			var sp := CATCHUP_SPEED if dist > 12.0 else FOLLOW_SPEED
			if scared and dist > 6.0:
				sp = CATCHUP_SPEED
			var dir := to.normalized()
			velocity.x = dir.x * sp
			velocity.z = dir.z * sp
			var target_yaw := atan2(-dir.x, -dir.z)
			rotation.y = lerp_angle(rotation.y, target_yaw, delta * 6.0)
		else:
			velocity.x = 0.0
			velocity.z = 0.0
			if has_face_target:
				var fto := face_target - global_position
				rotation.y = lerp_angle(rotation.y, atan2(-fto.x, -fto.z), delta * 4.0)
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = -0.5
	move_and_slide()

func say(text: String) -> void:
	bark_label.text = text
	bark_label.visible = true
	bark_timer = 4.5
