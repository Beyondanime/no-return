extends SceneTree

## Headless touch-controls + full-flow smoke test.
##   godot --headless --path . --script tests/touch_smoke_test.gd -- --force-touch
## With --force-touch the touch UI is forced on and the joystick / look-drag /
## buttons are exercised through real input events. Without it the touch UI
## must stay off, and the story flow is still exercised (desktop path).
## The window is resized to 844x390 (a landscape phone) first: the headless
## dummy display defaults to 64x64, which would put every control in the
## wrong place. All touch coordinates are read from the real control rects.
## Exits 0 when every check passes, 1 otherwise.

var failures: Array[String] = []
var checks := 0
var main: Node3D
var player: Player
var touch: TouchControls


func _initialize() -> void:
	_run.call_deferred()


func _check(cond: bool, name: String) -> void:
	checks += 1
	if cond:
		print("  PASS: ", name)
	else:
		failures.append(name)
		print("  FAIL: ", name)


func _touch(index: int, pos: Vector2, pressed: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = index
	ev.position = pos
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _drag(index: int, pos: Vector2, relative: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = index
	ev.position = pos
	ev.relative = relative
	Input.parse_input_event(ev)


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _teleport(pos: Vector3) -> void:
	player.position = pos
	player.velocity = Vector3.ZERO


func _button_center(i: int) -> Vector2:
	return touch._buttons[i].get_global_rect().get_center()


func _run() -> void:
	print("=== NO RETURN touch smoke test ===")
	# Landscape phone window; the headless dummy display starts at 64x64.
	root.size = Vector2i(844, 390)
	var scene := load("res://scenes/main.tscn") as PackedScene
	main = scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	await process_frame
	player = main.player
	touch = main.touch_controls
	var vp: Vector2 = root.get_visible_rect().size
	print("viewport: ", vp)
	var forced := "--force-touch" in OS.get_cmdline_user_args()
	print("force-touch flag: ", forced, " | touch_enabled: ", touch.touch_enabled)

	if forced:
		_check(touch.touch_enabled, "touch UI enabled when forced")
		_check(not touch.visible, "touch UI hidden on title screen")
		_check(vp.x > 800.0 and vp.y > 300.0, "phone-sized window applied (%.0fx%.0f)" % [vp.x, vp.y])
	else:
		_check(not touch.touch_enabled, "touch UI off without a touchscreen")

	main._start_game()
	await process_frame
	_check(main.state == 1, "state PLAYING after start")
	if forced:
		_check(touch.visible, "touch UI visible while playing")
		var joy_center := touch._joy_visual.get_global_rect().get_center()
		print("joy center: ", joy_center, " | JUMP: ", _button_center(0), " WALKIE: ", _button_center(1), " NIGHT: ", _button_center(2), " LIGHT: ", _button_center(3), " PAUSE: ", _button_center(4))

		# --- Joystick: push the stick forward, the player must walk. ---
		var start_pos: Vector3 = player.position
		_touch(0, joy_center, true)
		for i in 12:
			_drag(0, joy_center + Vector2(0, -6 * (i + 1)), Vector2(0, -6))
			await physics_frame
		_check(Input.is_action_pressed("move_forward"), "move_forward held while stick pushed")
		for i in 120:
			await physics_frame
		var moved := player.position.distance_to(start_pos)
		_check(moved > 1.0, "joystick forward moves player (%.1f m)" % moved)
		_touch(0, joy_center + Vector2(0, -72), false)
		await physics_frame
		await physics_frame
		_check(not Input.is_action_pressed("move_forward"), "move actions released on stick release")
		_check(not Input.is_action_pressed("sprint"), "sprint off after stick release")

		# --- Look drag: drag right on the right half, the player turns. ---
		var yaw0: float = player.rotation.y
		var look_pos := Vector2(vp.x * 0.8, vp.y * 0.4)
		_touch(1, look_pos, true)
		for i in 10:
			_drag(1, look_pos + Vector2(20 * (i + 1), 0), Vector2(20, 0))
			await physics_frame
		_touch(1, look_pos + Vector2(200, 0), false)
		var dyaw: float = absf(player.rotation.y - yaw0)
		_check(dyaw > 0.3, "look drag turns player (%.2f rad)" % dyaw)

		# --- LIGHT button: flashlight toggles on. ---
		_check(not player.flashlight_on, "flashlight off before LIGHT tap")
		_touch(2, _button_center(3), true)
		await process_frame
		_touch(2, _button_center(3), false)
		await process_frame
		_check(player.flashlight_on, "LIGHT button toggles flashlight on")

		# --- NIGHT button: night vision toggles on. ---
		_check(not main.night_vision_on, "night vision off before NIGHT tap")
		_touch(3, _button_center(2), true)
		await process_frame
		_touch(3, _button_center(2), false)
		await process_frame
		_check(main.night_vision_on, "NIGHT button toggles night vision on")

		# --- JUMP button: the player leaves the ground. ---
		_touch(4, _button_center(0), true)
		var jumped := false
		for i in 10:
			await physics_frame
			if player.velocity.y > 0.5:
				jumped = true
				break
		_touch(4, _button_center(0), false)
		_check(jumped, "JUMP button makes the player jump")

		# --- WALKIE button: the walkie panel opens. ---
		_touch(5, _button_center(1), true)
		await process_frame
		_touch(5, _button_center(1), false)
		await process_frame
		_check(main.ui.walkie_panel.visible, "WALKIE button opens the walkie panel")

		# --- Walkie panel fits on-screen (regression: the status text ran
		# ~12px past the right edge). Longest status must stay in-bounds. ---
		main.ui.set_walkie(true, "NO RESPONSE — STATIC")
		await process_frame
		await process_frame
		var wr: Rect2 = main.ui.walkie_panel.get_global_rect()
		_check(wr.end.x <= vp.x and wr.position.x >= 0.0, "walkie panel fully on-screen with longest status (rect %s, viewport %s)" % [wr, vp])
		main.ui.set_walkie(false, "")

		# --- PAUSE button: pause menu opens, resume works. ---
		_touch(6, _button_center(4), true)
		await process_frame
		_touch(6, _button_center(4), false)
		await process_frame
		_check(main.state == 2, "PAUSE button pauses the game")
		_check(not touch.visible, "touch UI hidden while paused")
		main._resume_game()
		await process_frame
		_check(main.state == 1, "resume returns to PLAYING")
		_check(touch.visible, "touch UI back after resume")

	# --- Story flow: camp -> 4 story canyons -> night -> crash site. ---
	_teleport(main.world.campsite_pos)
	await _wait(1.5)
	_check(main.camp_done, "camp set up on reaching campsite")
	for i in [0, 1, 2, 3]:
		var c: Dictionary = main.world.canyons[i]
		var pos: Vector2 = c["pos"]
		var floor_h: float = c["floor_h"]
		_teleport(Vector3(pos.x, floor_h + 3.0, pos.y))
		await _wait(2.0)
	_check(main.canyons_visited == 4, "all 4 story canyons visited")
	_check(main.night_fell, "night fell after the 4th canyon")

	_teleport(main.world.discovery_pos + Vector3(0, 2.0, 0))
	await _wait(13.0)
	_check(main.discovery_done, "crash site discovery ran")
	_check(main.sal_missing, "Sal is gone after the discovery")

	# Walkie after the loss: 1st use = static, 2nd = garbled transmission.
	await _wait(3.5)
	main._use_walkie()
	await _wait(4.0)
	main._use_walkie()
	await _wait(11.0)
	_check(main.state == 3, "ending reached after the garbled transmission")
	_check(main.ui.ending_screen.visible, "ending screen shown")

	print("---")
	print("CHECKS: %d passed, %d failed" % [checks - failures.size(), failures.size()])
	for f in failures:
		print("  FAILED: ", f)
	quit(0 if failures.is_empty() else 1)
