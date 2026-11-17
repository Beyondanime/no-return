extends CanvasLayer
class_name TouchControls

## Touch controls for phones (iPhone first): left virtual joystick to move,
## drag on the right half to look, on-screen buttons for jump / flashlight /
## night vision / walkie-talkie / pause. Shown only on touch devices (or when
## forced with ?touch=1 on web / --force-touch on the command line, for
## testing). Desktop keyboard+mouse is untouched: this layer stays hidden
## there, and the player + main input paths are shared, not duplicated.
##
## How input reaches the game:
##   - Movement / sprint / jump feed the SAME InputMap actions the keyboard
##     uses (Input.action_press/release), so player.gd needs no changes.
##   - Flashlight / night vision / walkie / pause are sent as real
##     InputEventAction events through Input.parse_input_event, so main.gd's
##     _unhandled_input handles them exactly like the F / N / T / ESC keys.
##   - Look drag calls player.apply_look(), the same math as mouse look.
##
## NOTE: project.godot sets input_devices/pointing/emulate_mouse_from_touch
## to false. With emulation on, a touch would ALSO arrive as an emulated
## mouse-motion event while the mouse is captured, and the player would turn
## twice as fast (once from the drag, once from the emulated mouse). Buttons
## and the joystick here use raw screen-touch events, so nothing is lost.

const LOOK_SENS_SCALE := 2.0 # finger drags are shorter than mouse moves
const JOY_DEADZONE := 0.15
const JOY_SPRINT_EDGE := 0.92 # push the stick to the rim to sprint
const JOY_RADIUS := 78.0
const JOY_ZONE_WIDTH_FRAC := 0.42 # left part of the screen is the stick
const JOY_ZONE_TOP_FRAC := 0.45 # ... and only its bottom half

var player: Player
var ui: GameUI
var touch_enabled := false
var playing := false

var _joy_touch := -1
var _joy_value := Vector2.ZERO
var _look_touch := -1

var _joy_visual: _JoyVisual
var _buttons: Array[Button] = []

# The joystick's drawn base: a fixed circle bottom-left, knob follows the
# thumb within JOY_RADIUS of the base center.
class _JoyVisual extends Control:
	var knob := Vector2.ZERO

	func _draw() -> void:
		var c := size * 0.5
		draw_circle(c, 78.0, Color(1, 1, 1, 0.07))
		draw_arc(c, 78.0, 0.0, TAU, 64, Color(1, 1, 1, 0.35), 3.0, true)
		draw_circle(c + knob, 30.0, Color(1, 1, 1, 0.25))
		draw_arc(c + knob, 30.0, 0.0, TAU, 40, Color(1, 1, 1, 0.55), 2.5, true)


static func touch_available() -> bool:
	if DisplayServer.is_touchscreen_available():
		return true
	if "--force-touch" in OS.get_cmdline_user_args():
		return true
	# Web: ?touch=1 forces the touch UI (for testing, and for devices that
	# report no touchscreen). JavaScriptBridge exists only on web, so it is
	# looked up by name — Engine.get_singleton returns null elsewhere.
	var jsb = Engine.get_singleton("JavaScriptBridge")
	if jsb != null:
		var q = jsb.eval("window.location.search")
		if q != null and "touch=1" in str(q):
			return true
	return false


func setup(p: Player, game_ui: GameUI) -> void:
	player = p
	ui = game_ui
	touch_enabled = touch_available()
	layer = 11
	visible = false
	_build()


func set_playing(value: bool) -> void:
	playing = value
	visible = touch_enabled and playing
	if not playing:
		_release_move_actions()
		_joy_touch = -1
		_look_touch = -1
		_joy_value = Vector2.ZERO
		if _joy_visual != null:
			_joy_visual.knob = Vector2.ZERO
			_joy_visual.queue_redraw()


# ------------------------------------------------------------------ build ---

func _make_touch_button(text: String, font_px: int) -> Button:
	var b := Button.new()
	b.text = text
	b.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	b.add_theme_font_size_override("font_size", font_px)
	b.add_theme_color_override("font_color", Color(0.95, 0.95, 0.9))
	b.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	b.add_theme_constant_override("shadow_offset_x", 1)
	b.add_theme_constant_override("shadow_offset_y", 1)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.05, 0.05, 0.08, 0.55)
	normal.border_color = Color(1, 1, 1, 0.4)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(14)
	b.add_theme_stylebox_override("normal", normal)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.55, 0.55, 0.6, 0.65)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("hover", normal)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b


func _build() -> void:
	# Virtual joystick, bottom-left. Base center sits at (160, H-160);
	# the touch zone around it is much bigger than the drawn base.
	_joy_visual = _JoyVisual.new()
	_joy_visual.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_joy_visual.offset_left = 60
	_joy_visual.offset_top = -260
	_joy_visual.offset_right = 260
	_joy_visual.offset_bottom = -60
	_joy_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_joy_visual)

	# Action buttons, right edge, in a compact cluster that fits a short
	# landscape phone screen (~375px tall) without covering the HUD:
	# JUMP bottom-right, the three toggles in a row to its left, and a small
	# pause button top-center. The walkie-talkie panel (bottom-right corner)
	# and the subtitle (bottom-center) both sit below this cluster.
	var jump_btn := _make_touch_button("JUMP", 22)
	jump_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	jump_btn.offset_left = -108
	jump_btn.offset_top = -216
	jump_btn.offset_right = -20
	jump_btn.offset_bottom = -128
	jump_btn.button_down.connect(func() -> void: Input.action_press("jump"))
	jump_btn.button_up.connect(func() -> void: Input.action_release("jump"))
	add_child(jump_btn)
	_buttons.append(jump_btn)

	var walkie_btn := _make_touch_button("WALKIE", 17)
	walkie_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	walkie_btn.offset_left = -188
	walkie_btn.offset_top = -216
	walkie_btn.offset_right = -124
	walkie_btn.offset_bottom = -160
	walkie_btn.pressed.connect(func() -> void: _tap_action("walkie"))
	add_child(walkie_btn)
	_buttons.append(walkie_btn)

	var night_btn := _make_touch_button("NIGHT", 17)
	night_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	night_btn.offset_left = -252
	night_btn.offset_top = -216
	night_btn.offset_right = -188
	night_btn.offset_bottom = -160
	night_btn.pressed.connect(func() -> void: _tap_action("night_vision"))
	add_child(night_btn)
	_buttons.append(night_btn)

	var light_btn := _make_touch_button("LIGHT", 17)
	light_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	light_btn.offset_left = -316
	light_btn.offset_top = -216
	light_btn.offset_right = -252
	light_btn.offset_bottom = -160
	light_btn.pressed.connect(func() -> void: _tap_action("flashlight"))
	add_child(light_btn)
	_buttons.append(light_btn)

	var pause_btn := _make_touch_button("II", 20)
	pause_btn.set_anchors_preset(Control.PRESET_CENTER_TOP)
	pause_btn.offset_left = -22
	pause_btn.offset_top = 12
	pause_btn.offset_right = 22
	pause_btn.offset_bottom = 56
	pause_btn.pressed.connect(func() -> void: _tap_action("pause"))
	add_child(pause_btn)
	_buttons.append(pause_btn)


# ------------------------------------------------------------------ input ---

func _tap_action(action_name: StringName) -> void:
	# A real action event through the input pipeline, so main.gd handles it
	# exactly like the matching key. The release follows at once so the
	# action does not stay pressed; the toggle already fired on the press.
	var press := InputEventAction.new()
	press.action = action_name
	press.pressed = true
	Input.parse_input_event(press)
	var release := InputEventAction.new()
	release.action = action_name
	release.pressed = false
	Input.parse_input_event(release)


func _input(event: InputEvent) -> void:
	if not touch_enabled or not playing:
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			_on_touch_down(t.index, t.position)
		else:
			_on_touch_up(t.index)
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		_on_touch_drag(d.index, d.position, d.relative)


func _on_touch_down(index: int, pos: Vector2) -> void:
	if _joy_touch == -1 and _joy_zone().has_point(pos):
		_joy_touch = index
		_update_joy(pos)
	elif _look_touch == -1 and _look_zone().has_point(pos) and not _over_button(pos):
		_look_touch = index


func _on_touch_drag(index: int, pos: Vector2, relative: Vector2) -> void:
	if index == _joy_touch:
		_update_joy(pos)
	elif index == _look_touch:
		player.apply_look(relative * LOOK_SENS_SCALE)


func _on_touch_up(index: int) -> void:
	if index == _joy_touch:
		_joy_touch = -1
		_joy_value = Vector2.ZERO
		_release_move_actions()
		_joy_visual.knob = Vector2.ZERO
		_joy_visual.queue_redraw()
	elif index == _look_touch:
		_look_touch = -1


# ---------------------------------------------------------------- helpers ---

func _viewport_size() -> Vector2:
	return get_viewport().get_visible_rect().size


func _joy_zone() -> Rect2:
	var s := _viewport_size()
	return Rect2(0, s.y * JOY_ZONE_TOP_FRAC, s.x * JOY_ZONE_WIDTH_FRAC, s.y * (1.0 - JOY_ZONE_TOP_FRAC))


func _look_zone() -> Rect2:
	var s := _viewport_size()
	return Rect2(s.x * JOY_ZONE_WIDTH_FRAC, 0, s.x * (1.0 - JOY_ZONE_WIDTH_FRAC), s.y)


func _over_button(pos: Vector2) -> bool:
	for b in _buttons:
		if b.visible and b.get_global_rect().has_point(pos):
			return true
	return false


func _update_joy(pos: Vector2) -> void:
	var center := _joy_visual.get_global_rect().get_center()
	var offset := pos - center
	if offset.length() > JOY_RADIUS:
		offset = offset.normalized() * JOY_RADIUS
	_joy_value = offset / JOY_RADIUS
	_joy_visual.knob = offset
	_joy_visual.queue_redraw()
	_apply_move_actions()


func _apply_move_actions() -> void:
	var mag := _joy_value.length()
	var fwd := 0.0
	var back := 0.0
	var left := 0.0
	var right := 0.0
	if mag >= JOY_DEADZONE:
		fwd = clampf(-_joy_value.y, 0.0, 1.0)
		back = clampf(_joy_value.y, 0.0, 1.0)
		left = clampf(-_joy_value.x, 0.0, 1.0)
		right = clampf(_joy_value.x, 0.0, 1.0)
	_set_action_strength("move_forward", fwd)
	_set_action_strength("move_back", back)
	_set_action_strength("move_left", left)
	_set_action_strength("move_right", right)
	_set_action_strength("sprint", 1.0 if mag > JOY_SPRINT_EDGE else 0.0)


func _set_action_strength(action_name: StringName, strength: float) -> void:
	if strength > 0.0:
		Input.action_press(action_name, strength)
	else:
		Input.action_release(action_name)


func _release_move_actions() -> void:
	Input.action_release("move_forward")
	Input.action_release("move_back")
	Input.action_release("move_left")
	Input.action_release("move_right")
	Input.action_release("sprint")
