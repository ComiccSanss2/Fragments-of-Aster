extends Control

# Conteneurs
@onready var main_container = $MenuContainer
@onready var options_container = $OptionsContainer

# Boutons Principaux (Dans MainContainer)
@onready var resume_btn = $MenuContainer/ResumeButton
@onready var options_btn = $MenuContainer/OptionsButton
@onready var menu_btn = $MenuContainer/MenuButton

# Options (Dans OptionsContainer)
@onready var volume_slider = $OptionsContainer/MasterVolumeSlider
@onready var fullscreen_check = $OptionsContainer/FullscreenCheck
@onready var vsync_check = $OptionsContainer/VSyncCheck

# CORRECTION ICI : Le nom est OptionsBackButton
@onready var options_back_btn = $OptionsContainer/OptionsBackButton

func _ready():
	# On s'assure que le menu est caché au lancement du jeu
	visible = false
	options_container.visible = false
	main_container.visible = true
	
	# Connexions Principales
	resume_btn.pressed.connect(toggle_pause)
	options_btn.pressed.connect(_on_options_pressed)
	menu_btn.pressed.connect(_on_menu_pressed)
	
	# Connexions Options
	if options_back_btn: 
		options_back_btn.pressed.connect(_on_options_back_pressed)
	
	# --- SETUP OPTIONS ---
	var bus_index = AudioServer.get_bus_index("Master")
	if volume_slider:
		volume_slider.value = db_to_linear(AudioServer.get_bus_volume_db(bus_index))
		volume_slider.value_changed.connect(_on_volume_changed)
	
	if fullscreen_check:
		fullscreen_check.button_pressed = (DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
		fullscreen_check.toggled.connect(_on_fullscreen_toggled)
		
	if vsync_check:
		vsync_check.button_pressed = (DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_ENABLED)
		vsync_check.toggled.connect(_on_vsync_toggled)

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
		resume_btn.grab_focus()

func _on_options_pressed():
	main_container.visible = false
	options_container.visible = true
	if options_back_btn: options_back_btn.grab_focus()

func _on_options_back_pressed():
	options_container.visible = false
	main_container.visible = true
	resume_btn.grab_focus()

func _on_menu_pressed():
	# 1. On remet le temps
	get_tree().paused = false
	
	# 2. APPEL DU NETTOYAGE (C'est la nouveauté)
	# On cherche le nœud Main (la racine actuelle)
	var main = get_tree().current_scene
	
	# Sécurité : On vérifie si c'est bien Main et s'il a la fonction
	if main.name == "Main" and main.has_method("cleanup_before_exit"):
		main.cleanup_before_exit()
	
	# 3. On lance l'écran de chargement
	var loading_screen = load("res://loading_screen.tscn").instantiate()
	loading_screen.target_scene_path = "res://main_menu.tscn"
	loading_screen.min_load_time = 1.5
	get_tree().root.add_child(loading_screen)
	
	# 4. On détruit le menu pause
	queue_free()

# --- LOGIQUE OPTIONS ---

func _on_volume_changed(value: float):
	var bus_index = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(value))

func _on_fullscreen_toggled(is_fullscreen: bool):
	if is_fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _on_vsync_toggled(is_vsync: bool):
	if is_vsync:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
