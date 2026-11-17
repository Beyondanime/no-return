extends CanvasLayer
class_name GameUI

## All UI: title screen, camcorder HUD (REC, timestamp, grain, scanlines,
## vignette, tracking line, night-vision tint), toasts, subtitles,
## walkie-talkie panel, pause menu, ending screen.

signal start_pressed
signal resume_pressed
signal restart_pressed
signal quit_to_title_pressed
signal quit_game_pressed

var title_screen: Control
var hud: Control
var pause_menu: Control
var ending_screen: Control
var objective_label: Label
var explored_label: Label
var clock_label: Label
var controls_label: Label # title-screen "HOW TO PLAY" text (keyboard or touch)
var rec_dot: ColorRect
var rec_label: Label
var toast_label: Label
var subtitle_label: Label
var hint_label: Label
var walkie_panel: PanelContainer
var walkie_label: Label
var fade_rect: ColorRect
var flash_rect: ColorRect
var grain_rect: TextureRect
var scan_rect: TextureRect
var vignette_rect: TextureRect
var tracking_line: ColorRect
var nv_overlay: ColorRect
var ending_stats: Label

var grain_textures: Array[ImageTexture] = []
var grain_index := 0
var grain_timer := 0.0
var rec_timer := 0.0
var rec_visible := true
var toast_timer := 0.0
var subtitle_timer := 0.0
var tracking_timer := 5.0
var tracking_active := false
var tracking_t := 0.0
var hint_timer := 30.0

func _ready() -> void:
	layer = 10
	_build_overlays()
	_build_title()
	_build_hud()
	_build_pause()
	_build_ending()
	show_title()

# ------------------------------------------------------------------ build ---

func _make_label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	return l

func _make_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(300, 52)
	b.add_theme_font_size_override("font_size", 22)
	return b

func _noise_texture(size: int, seed: int) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for y in size:
		for x in size:
			var g := rng.randf_range(0.0, 1.0)
			img.set_pixel(x, y, Color(g, g, g, 1.0))
	return ImageTexture.create_from_image(img)

func _scanline_texture() -> ImageTexture:
	var img := Image.create(1, 3, false, Image.FORMAT_RGBA8)
	img.set_pixel(0, 0, Color(0, 0, 0, 0))
	img.set_pixel(0, 1, Color(0, 0, 0, 0))
	img.set_pixel(0, 2, Color(0, 0, 0, 0.55))
	return ImageTexture.create_from_image(img)

func _vignette_texture() -> ImageTexture:
	var s := 256
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	for y in s:
		for x in s:
			var dx := (float(x) / float(s) - 0.5) * 2.0
			var dy := (float(y) / float(s) - 0.5) * 2.0
			var d := sqrt(dx * dx + dy * dy)
			var a := clampf((d - 0.55) / 0.6, 0.0, 1.0) * 0.75
			img.set_pixel(x, y, Color(0, 0, 0, a))
	return ImageTexture.create_from_image(img)

func _build_overlays() -> void:
	# Film grain: three noise textures cycled fast, low opacity.
	for i in range(3):
		grain_textures.append(_noise_texture(256, 100 + i))
	grain_rect = TextureRect.new()
	grain_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	grain_rect.texture = grain_textures[0]
	grain_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	grain_rect.stretch_mode = TextureRect.STRETCH_SCALE
	grain_rect.modulate = Color(1, 1, 1, 0.07)
	grain_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(grain_rect)
	# Scanlines.
	scan_rect = TextureRect.new()
	scan_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	scan_rect.texture = _scanline_texture()
	scan_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scan_rect.stretch_mode = TextureRect.STRETCH_TILE
	scan_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scan_rect)
	# Vignette.
	vignette_rect = TextureRect.new()
	vignette_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette_rect.texture = _vignette_texture()
	vignette_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette_rect.stretch_mode = TextureRect.STRETCH_SCALE
	vignette_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vignette_rect)
	# Tracking line that rolls down the screen now and then.
	tracking_line = ColorRect.new()
	tracking_line.color = Color(1, 1, 1, 0.0)
	tracking_line.set_anchors_preset(Control.PRESET_TOP_WIDE)
	tracking_line.offset_top = 0
	tracking_line.offset_bottom = 2
	tracking_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tracking_line)
	# Night-vision green wash.
	nv_overlay = ColorRect.new()
	nv_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	nv_overlay.color = Color(0.05, 0.4, 0.12, 0.14)
	nv_overlay.visible = false
	nv_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(nv_overlay)
	# Flash (disappearance) + fade (transitions) sit above everything.
	flash_rect = ColorRect.new()
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.color = Color(0.8, 0.9, 1.0, 0.0)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash_rect)
	fade_rect = ColorRect.new()
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.color = Color(0, 0, 0, 0.0)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade_rect)

func _build_title() -> void:
	title_screen = Control.new()
	title_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(title_screen)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.55)
	title_screen.add_child(dim)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	title_screen.add_child(box)
	var title := _make_label("NO RETURN", 110, Color(0.78, 0.12, 0.1))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var park := _make_label("S T A R V E D   R O C K", 40, Color(0.85, 0.65, 0.2))
	park.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(park)
	var sub := _make_label("Four friends. One closed park. No way back.", 22, Color(0.82, 0.8, 0.72))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	var note := _make_label("A found-footage horror slice  •  Phones were left at the car. The walkie-talkie is all you've got.", 15, Color(0.6, 0.6, 0.55))
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(note)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 18)
	box.add_child(spacer)
	var start_btn := _make_button("START THE TRIP")
	start_btn.pressed.connect(func() -> void: start_pressed.emit())
	box.add_child(start_btn)
	var how_btn := _make_button("HOW TO PLAY")
	box.add_child(how_btn)
	var quit_btn := _make_button("QUIT")
	quit_btn.pressed.connect(func() -> void: quit_game_pressed.emit())
	box.add_child(quit_btn)
	var controls := _make_label("WASD move   •   Mouse look   •   SHIFT sprint   •   SPACE jump\nF flashlight   •   N night vision   •   T walkie-talkie   •   ESC pause\n\nObjective: hike every trail. Visit each canyon. Film everything.", 16, Color(0.75, 0.75, 0.68))
	controls_label = controls
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.visible = false
	box.add_child(controls)
	how_btn.pressed.connect(func() -> void: controls.visible = not controls.visible)

func _build_hud() -> void:
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)
	# REC indicator (top-left).
	rec_dot = ColorRect.new()
	rec_dot.color = Color(0.9, 0.05, 0.05)
	rec_dot.position = Vector2(18, 18)
	rec_dot.size = Vector2(14, 14)
	hud.add_child(rec_dot)
	rec_label = _make_label("REC", 18, Color(0.95, 0.95, 0.95))
	rec_label.position = Vector2(38, 12)
	hud.add_child(rec_label)
	# Timestamp (top-right).
	clock_label = _make_label("", 18, Color(0.92, 0.92, 0.85))
	clock_label.position = Vector2(0, 14)
	clock_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	clock_label.offset_left = -260
	clock_label.offset_right = -16
	clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud.add_child(clock_label)
	# Objective (top-left, under REC).
	objective_label = _make_label("SET UP CAMP\nReach the campsite", 20, Color(0.95, 0.95, 0.9))
	objective_label.position = Vector2(18, 46)
	hud.add_child(objective_label)
	# Exploration tally (under the objective).
	explored_label = _make_label("EXPLORED 0/18", 16, Color(0.75, 0.75, 0.68))
	explored_label.position = Vector2(18, 98)
	hud.add_child(explored_label)
	# Crosshair dot.
	var dot := ColorRect.new()
	dot.color = Color(1, 1, 1, 0.85)
	dot.set_anchors_preset(Control.PRESET_CENTER)
	dot.position = Vector2(-2, -2)
	dot.size = Vector2(4, 4)
	hud.add_child(dot)
	# Toast (center-top).
	toast_label = _make_label("", 28, Color(0.95, 0.9, 0.75))
	toast_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast_label.position = Vector2(0, 110)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.offset_left = -500
	toast_label.offset_right = 500
	hud.add_child(toast_label)
	# Subtitle (bottom-center).
	subtitle_label = _make_label("", 22, Color(1, 0.98, 0.85))
	subtitle_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	subtitle_label.position = Vector2(0, -90)
	subtitle_label.offset_left = -600
	subtitle_label.offset_right = 600
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud.add_child(subtitle_label)
	# Controls hint (bottom-left).
	hint_label = _make_label("WASD move  •  SHIFT sprint  •  F flashlight  •  N night vision  •  T walkie  •  ESC pause", 15, Color(0.7, 0.7, 0.65))
	hint_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hint_label.position = Vector2(16, -16)
	hint_label.offset_top = -34
	hud.add_child(hint_label)
	# Walkie-talkie panel (bottom-right). Sized to fit the longest status
	# ("WALKIE CH-04  •  NO RESPONSE — STATIC" is 318px at 16px); the old
	# 200px minimum let the text run past the right screen edge.
	walkie_panel = PanelContainer.new()
	walkie_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	walkie_panel.position = Vector2(-360, -70)
	walkie_panel.custom_minimum_size = Vector2(340, 44)
	walkie_panel.visible = false
	hud.add_child(walkie_panel)
	walkie_label = _make_label("WALKIE CH-04", 16, Color(0.9, 0.9, 0.85))
	walkie_panel.add_child(walkie_label)

func _build_pause() -> void:
	pause_menu = Control.new()
	pause_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_menu.visible = false
	add_child(pause_menu)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.6)
	pause_menu.add_child(dim)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	pause_menu.add_child(box)
	var title := _make_label("PAUSED", 56, Color(0.9, 0.9, 0.85))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var resume_btn := _make_button("RESUME")
	resume_btn.pressed.connect(func() -> void: resume_pressed.emit())
	box.add_child(resume_btn)
	var restart_btn := _make_button("RESTART THE TRIP")
	restart_btn.pressed.connect(func() -> void: restart_pressed.emit())
	box.add_child(restart_btn)
	var quit_btn := _make_button("QUIT TO TITLE")
	quit_btn.pressed.connect(func() -> void: quit_to_title_pressed.emit())
	box.add_child(quit_btn)

func _build_ending() -> void:
	ending_screen = Control.new()
	ending_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	ending_screen.visible = false
	add_child(ending_screen)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.92)
	ending_screen.add_child(dim)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
	ending_screen.add_child(box)
	var title := _make_label("TO BE CONTINUED", 72, Color(0.78, 0.12, 0.1))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	ending_stats = _make_label("", 20, Color(0.85, 0.82, 0.72))
	ending_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(ending_stats)
	var line := _make_label("Sal is missing.", 22, Color(0.9, 0.85, 0.7))
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(line)
	var act3 := _make_label("ACT 3 — THE HOLLOW — continues in the full game.", 18, Color(0.7, 0.65, 0.55))
	act3.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(act3)
	var again_btn := _make_button("PLAY AGAIN")
	again_btn.pressed.connect(func() -> void: restart_pressed.emit())
	box.add_child(again_btn)
	var title_btn := _make_button("QUIT TO TITLE")
	title_btn.pressed.connect(func() -> void: quit_to_title_pressed.emit())
	box.add_child(title_btn)

# ------------------------------------------------------------------ show ---

func show_title() -> void:
	title_screen.visible = true
	hud.visible = false
	pause_menu.visible = false
	ending_screen.visible = false

func show_hud() -> void:
	title_screen.visible = false
	hud.visible = true
	pause_menu.visible = false
	ending_screen.visible = false
	hint_timer = 30.0
	hint_label.visible = true

func show_pause(on: bool) -> void:
	pause_menu.visible = on

func show_ending(stats: String) -> void:
	ending_stats.text = stats
	ending_screen.visible = true
	hud.visible = false
	pause_menu.visible = false

func set_touch_mode() -> void:
	# On phones the keyboard hints are wrong — say what the thumbs do.
	hint_label.text = "Left stick move  •  Drag right side to look  •  Push stick to the edge to sprint"
	if controls_label != null:
		controls_label.text = "Left stick move   •   Drag right side to look   •   Push stick to the edge to sprint\nJUMP button   •   LIGHT flashlight   •   NIGHT night vision   •   WALKIE walkie-talkie\n\nObjective: hike every trail. Visit each canyon. Film everything."

func set_objective(line1: String, line2: String) -> void:
	objective_label.text = line1 + "\n" + line2

func set_explored(count: int, total: int) -> void:
	explored_label.text = "EXPLORED %d/%d" % [count, total]

func set_clock(text: String) -> void:
	clock_label.text = text

func set_night_vision(on: bool) -> void:
	nv_overlay.visible = on
	grain_rect.modulate = Color(1, 1, 1, 0.14 if on else 0.07)

func set_walkie(on: bool, status: String) -> void:
	walkie_panel.visible = on
	if on:
		walkie_label.text = "WALKIE CH-04  •  " + status
		# Fit the panel to the text, growing leftward from a 16px right
		# margin, so the full status is always on-screen whatever its length.
		var w := walkie_panel.get_combined_minimum_size().x
		walkie_panel.offset_right = -16.0
		walkie_panel.offset_left = -16.0 - w

func toast(text: String, duration := 3.0) -> void:
	toast_label.text = text
	toast_timer = duration

func subtitle(speaker: String, text: String, duration := 4.0) -> void:
	if speaker.is_empty():
		subtitle_label.text = text
	else:
		subtitle_label.text = speaker + ":  " + text
	subtitle_timer = duration

func flash() -> void:
	flash_rect.color = Color(0.8, 0.9, 1.0, 0.85)
	var tw := create_tween()
	tw.tween_property(flash_rect, "color:a", 0.0, 0.7)

func fade_to(alpha: float, duration: float) -> Tween:
	var tw := create_tween()
	tw.tween_property(fade_rect, "color:a", alpha, duration)
	return tw

func _process(delta: float) -> void:
	# REC blink.
	rec_timer += delta
	if rec_timer > 0.6:
		rec_timer = 0.0
		rec_visible = not rec_visible
		rec_dot.visible = rec_visible
		rec_label.visible = rec_visible
	# Grain animation: cycle textures + jitter.
	grain_timer += delta
	if grain_timer > 0.09:
		grain_timer = 0.0
		grain_index = (grain_index + 1) % grain_textures.size()
		grain_rect.texture = grain_textures[grain_index]
		grain_rect.position = Vector2(randf_range(-6, 6), randf_range(-6, 6))
	# Tracking line roll.
	tracking_timer -= delta
	if tracking_timer <= 0.0 and not tracking_active:
		tracking_active = true
		tracking_t = 0.0
		tracking_line.color = Color(1, 1, 1, 0.12)
	if tracking_active:
		tracking_t += delta
		var h := get_viewport().get_visible_rect().size.y
		tracking_line.offset_top = tracking_t * 500.0
		tracking_line.offset_bottom = tracking_t * 500.0 + 2.0
		if tracking_t > h / 500.0:
			tracking_active = false
			tracking_timer = randf_range(6.0, 12.0)
			tracking_line.color = Color(1, 1, 1, 0.0)
	# Toast / subtitle expiry.
	if toast_timer > 0.0:
		toast_timer -= delta
		if toast_timer <= 0.0:
			toast_label.text = ""
	if subtitle_timer > 0.0:
		subtitle_timer -= delta
		if subtitle_timer <= 0.0:
			subtitle_label.text = ""
	# Hint fades out after a while.
	if hint_timer > 0.0:
		hint_timer -= delta
		if hint_timer <= 0.0:
			hint_label.visible = false
