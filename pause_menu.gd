extends Control

# Conteneurs
@onready var main_container = $MenuContainer
@onready var options_container = $OptionsContainer

# Boutons Principaux
@onready var resume_btn = $MenuContainer/ResumeButton
@onready var options_btn = $MenuContainer/OptionsButton
@onready var menu_btn = $MenuContainer/MenuButton

# --- NOUVEAUX BOUTONS OPTIONS ---
@onready var master_minus = $OptionsContainer/MasterBox/MasterMinus
@onready var master_label = $OptionsContainer/MasterBox/MasterLabel
@onready var master_plus  = $OptionsContainer/MasterBox/MasterPlus

@onready var music_minus = $OptionsContainer/MusicBox/MusicMinus
@onready var music_label = $OptionsContainer/MusicBox/MusicLabel
@onready var music_plus  = $OptionsContainer/MusicBox/MusicPlus

@onready var sfx_minus = $OptionsContainer/SFXBox/SFXMinus
@onready var sfx_label = $OptionsContainer/SFXBox/SFXLabel
@onready var sfx_plus  = $OptionsContainer/SFXBox/SFXPlus

@onready var video_minus = $OptionsContainer/VideoBox/VideoMinus
@onready var video_label = $OptionsContainer/VideoBox/VideoLabel
@onready var video_plus  = $OptionsContainer/VideoBox/VideoPlus

@onready var options_back_btn = $OptionsContainer/OptionsBackButton

# --- VARIABLES D'ÉTAT ---
var hovered_button: Button = null

var vol_master: int = 10
var vol_music: int = 10
var vol_sfx: int = 10
var is_fullscreen: bool = false

func _ready():
	visible = false
	options_container.visible = false
	main_container.visible = true
	
	# --- INITIALISATION EFFETS VISUELS ---
	var main_buttons = [resume_btn, options_btn, menu_btn, options_back_btn]
	for btn in main_buttons:
		# Passiamo 'false' per impedire lo zoom su TUTTI i bottoni del menu di pausa
		if btn: _setup_button_effects(btn, false)
		
	var option_arrows = [master_minus, master_plus, music_minus, music_plus, sfx_minus, sfx_plus, video_minus, video_plus]
	for arrow in option_arrows:
		if arrow: _setup_simple_rgb_effect(arrow)
	
	# --- CONNEXIONS ---
	if resume_btn: resume_btn.pressed.connect(toggle_pause)
	if options_btn: options_btn.pressed.connect(_on_options_pressed)
	if menu_btn: menu_btn.pressed.connect(_on_menu_pressed)
	if options_back_btn: options_back_btn.pressed.connect(_on_options_back_pressed)
	
	# --- SETUP OPTIONS ---
	_setup_options_ui()

func _process(_delta):
	# RGB Arcobaleno in tempo reale per il bottone in focus
	if hovered_button and is_instance_valid(hovered_button):
		var time = Time.get_ticks_msec() / 1000.0
		hovered_button.modulate = Color.from_hsv(fmod(time * 0.5, 1.0), 1.0, 1.0)

# ==========================================
# LOGIQUE DE PAUSE ET NAVIGATION
# ==========================================
func _input(event):
	if event.is_action_pressed("ui_cancel"):
		if visible and options_container.visible:
			_on_options_back_pressed()
		else:
			toggle_pause()

func toggle_pause():
	var is_paused = not get_tree().paused
	get_tree().paused = is_paused
	visible = is_paused
	
	if visible:
		main_container.visible = true
		options_container.visible = false
		if resume_btn: resume_btn.grab_focus()

func _on_options_pressed():
	main_container.visible = false
	options_container.visible = true
	if master_plus: master_plus.grab_focus()

func _on_options_back_pressed():
	options_container.visible = false
	main_container.visible = true
	if resume_btn: resume_btn.grab_focus()

func _on_menu_pressed():
	get_tree().paused = false
	var main = get_tree().current_scene
	if main.name == "Main" and main.has_method("cleanup_before_exit"):
		main.cleanup_before_exit()
	
	var loading_screen = load("res://loading_screen.tscn").instantiate()
	loading_screen.target_scene_path = "res://main_menu.tscn"
	loading_screen.min_load_time = 1.5
	get_tree().root.add_child(loading_screen)
	queue_free()

# ==========================================
# LOGIQUE OPZIONI (AUDIO E VIDEO)
# ==========================================
func _setup_options_ui():
	vol_master = _get_bus_vol_int("Master")
	vol_music = _get_bus_vol_int("Music")
	vol_sfx = _get_bus_vol_int("SFX")
	
	update_audio_label("Master")
	update_audio_label("Music")
	update_audio_label("SFX")
	
	is_fullscreen = (DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
	update_video_label()
	
	if master_minus: master_minus.pressed.connect(change_volume.bind("Master", -1))
	if master_plus: master_plus.pressed.connect(change_volume.bind("Master", 1))
	if music_minus: music_minus.pressed.connect(change_volume.bind("Music", -1))
	if music_plus: music_plus.pressed.connect(change_volume.bind("Music", 1))
	if sfx_minus: sfx_minus.pressed.connect(change_volume.bind("SFX", -1))
	if sfx_plus: sfx_plus.pressed.connect(change_volume.bind("SFX", 1))
	
	if video_minus: video_minus.pressed.connect(toggle_fullscreen)
	if video_plus: video_plus.pressed.connect(toggle_fullscreen)

func _get_bus_vol_int(bus_name: String) -> int:
	var bus_idx = AudioServer.get_bus_index(bus_name)
	if bus_idx == -1: return 10
	var db = AudioServer.get_bus_volume_db(bus_idx)
	var linear = db_to_linear(db)
	return int(round(linear * 10.0))

func change_volume(bus_name: String, amount: int):
	var current_vol = 0
	if bus_name == "Master":
		vol_master = clamp(vol_master + amount, 0, 10)
		current_vol = vol_master
	elif bus_name == "Music":
		vol_music = clamp(vol_music + amount, 0, 10)
		current_vol = vol_music
	elif bus_name == "SFX":
		vol_sfx = clamp(vol_sfx + amount, 0, 10)
		current_vol = vol_sfx

	var bus_index = AudioServer.get_bus_index(bus_name)
	if bus_index != -1:
		if current_vol == 0:
			AudioServer.set_bus_mute(bus_index, true)
		else:
			AudioServer.set_bus_mute(bus_index, false)
			var linear_vol = float(current_vol) / 10.0
			AudioServer.set_bus_volume_db(bus_index, linear_to_db(linear_vol))
			
	update_audio_label(bus_name)

func update_audio_label(bus_name: String):
	if bus_name == "Master" and master_label: master_label.text = "Master : %d%%" % (vol_master * 10)
	elif bus_name == "Music" and music_label: music_label.text = "Music : %d%%" % (vol_music * 10)
	elif bus_name == "SFX" and sfx_label: sfx_label.text = "SFX : %d%%" % (vol_sfx * 10)

func toggle_fullscreen():
	is_fullscreen = !is_fullscreen
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if is_fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	update_video_label()

func update_video_label():
	if video_label: video_label.text = "Fullscreen : ON" if is_fullscreen else "Fullscreen : OFF"

# ==========================================
# EFFETTI VISIVI (BRACKETS & RGB & FIX BACKGROUND)
# ==========================================
func _setup_button_effects(btn: Button, allow_zoom: bool):
	btn.flat = true 
	
	var empty_style = StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal", empty_style)
	btn.add_theme_stylebox_override("hover", empty_style)
	btn.add_theme_stylebox_override("pressed", empty_style)
	btn.add_theme_stylebox_override("focus", empty_style)
	
	var clean_text = btn.text.strip_edges()
	btn.set_meta("orig_text", clean_text)
	btn.set_meta("allow_zoom", allow_zoom)
	btn.text = "   " + clean_text + "   "
	
	btn.mouse_entered.connect(_on_btn_hovered.bind(btn))
	btn.focus_entered.connect(_on_btn_hovered.bind(btn))
	btn.mouse_exited.connect(_on_btn_unhovered.bind(btn))
	btn.focus_exited.connect(_on_btn_unhovered.bind(btn))

func _on_btn_hovered(btn: Button):
	hovered_button = btn
	var txt = str(btn.get_meta("orig_text", ""))
	btn.text = "⩺  " + txt + "  ⩹"
	if btn.get_meta("allow_zoom", false):
		btn.pivot_offset = Vector2(0, btn.size.y / 2.0)
		create_tween().tween_property(btn, "scale", Vector2(1.05, 1.05), 0.1).set_trans(Tween.TRANS_SINE)

func _on_btn_unhovered(btn: Button):
	if hovered_button == btn: hovered_button = null
	var txt = str(btn.get_meta("orig_text", ""))
	btn.text = "   " + txt + "   "
	btn.modulate = Color.WHITE
	if btn.get_meta("allow_zoom", false):
		create_tween().tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_SINE)

func _setup_simple_rgb_effect(btn: Button):
	btn.flat = true 
	
	var empty_style = StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal", empty_style)
	btn.add_theme_stylebox_override("hover", empty_style)
	btn.add_theme_stylebox_override("pressed", empty_style)
	btn.add_theme_stylebox_override("focus", empty_style)
	
	
	btn.mouse_entered.connect(func(): 
		hovered_button = btn
	)
	btn.focus_entered.connect(func(): 
		hovered_button = btn
	)
	
	btn.mouse_exited.connect(func(): 
		if hovered_button == btn: hovered_button = null
		btn.modulate = Color.WHITE
	)
	btn.focus_exited.connect(func(): 
		if hovered_button == btn: hovered_button = null
		btn.modulate = Color.WHITE
	)
