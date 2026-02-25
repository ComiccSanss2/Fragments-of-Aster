extends Control

# --- RÉFÉRENCES UI ---
@onready var title_container = $TitleContainer
@onready var title_label = $TitleContainer/Label
@onready var press_key_label = $TitleContainer/Label2 

# Conteneurs principaux
@onready var menu_container = $MenuContainer
@onready var slot_container = $SlotContainer
@onready var options_container = $OptionsContainer

# Boutons du Menu Principal
@onready var btn_play = $MenuContainer/PlayButton
@onready var btn_options = $MenuContainer/OptionsButton
@onready var btn_exit = $MenuContainer/ExitButton

# Boutons Options
@onready var volume_slider = $OptionsContainer/MasterVolumeSlider
@onready var fullscreen_check = $OptionsContainer/FullscreenCheck
@onready var vsync_check = $OptionsContainer/VSyncCheck
@onready var options_back_btn = $OptionsContainer/OptionsBackButton

# Bouton Retour des Slots
@onready var slot_back_btn = $SlotContainer/SlotBackButton

# Popup Suppression
@onready var delete_popup = $DeletePopup
@onready var confirm_btn = $DeletePopup/VBoxContainer/HBoxContainer/ConfirmButton
@onready var cancel_btn = $DeletePopup/VBoxContainer/HBoxContainer/CancelButton

# --- ÉTATS DU MENU ---
enum State { TITLE, MENU, SLOTS, OPTIONS, POPUP }
var current_state = State.TITLE
var slot_to_delete: int = -1

func _ready():
	# 1. Initialisation visuelle (Tout cacher sauf le titre)
	_reset_alpha_and_hide([menu_container, slot_container, options_container, delete_popup])
	
	title_label.modulate.a = 0.0
	press_key_label.modulate.a = 0.0
	
	# 2. Intro Animation
	var t = create_tween()
	t.tween_interval(0.5)
	t.tween_property(title_label, "modulate:a", 1.0, 2.0)
	t.tween_property(press_key_label, "modulate:a", 1.0, 1.0)
	loop_press_key_anim()
	
	# 3. Connexions MENU PRINCIPAL
	btn_play.pressed.connect(_on_play_pressed)
	btn_options.pressed.connect(_on_options_pressed)
	btn_exit.pressed.connect(_on_exit_pressed)
	
	# 4. Connexions SLOTS (Dynamique)
	for i in range(1, 4):
		if slot_container.get_child_count() >= i:
			var hbox = slot_container.get_child(i-1)
			var slot_btn = hbox.get_node_or_null("SlotButton")
			var del_btn = hbox.get_node_or_null("DeleteButton")
			if slot_btn and del_btn:
				slot_btn.pressed.connect(_on_slot_pressed.bind(i))
				del_btn.pressed.connect(_on_delete_request.bind(i))
				update_slot_display(i)

	if slot_back_btn: slot_back_btn.pressed.connect(_on_back_to_menu)
	
	# 5. Connexions OPTIONS
	if options_back_btn: options_back_btn.pressed.connect(_on_back_to_menu)
	
	# Audio setup (Master Bus)
	var bus_index = AudioServer.get_bus_index("Master")
	if volume_slider:
		volume_slider.min_value = 0.0
		volume_slider.max_value = 1.0
		volume_slider.step = 0.05
		volume_slider.value = db_to_linear(AudioServer.get_bus_volume_db(bus_index))
		volume_slider.value_changed.connect(_on_volume_changed)
	
	# Video setup
	if fullscreen_check:
		fullscreen_check.button_pressed = (DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
		fullscreen_check.toggled.connect(_on_fullscreen_toggled)
		
	if vsync_check:
		vsync_check.button_pressed = (DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_ENABLED)
		vsync_check.toggled.connect(_on_vsync_toggled)

# 6. Connexions POPUP
	if confirm_btn: confirm_btn.pressed.connect(_on_confirm_delete)
	if cancel_btn: cancel_btn.pressed.connect(_on_cancel_delete)
	
	# --- NOUVEAU : BLOQUER LE FOCUS DANS LE POPUP ---
	if confirm_btn and cancel_btn:
		# Empêcher le focus de s'échapper vers le haut ou le bas
		confirm_btn.focus_neighbor_top = confirm_btn.get_path()
		confirm_btn.focus_neighbor_bottom = confirm_btn.get_path()
		
		cancel_btn.focus_neighbor_top = cancel_btn.get_path()
		cancel_btn.focus_neighbor_bottom = cancel_btn.get_path()
		
		# (Optionnel) Forcer la boucle gauche/droite si on appuie sur gauche depuis "Confirm"
		confirm_btn.focus_neighbor_left = cancel_btn.get_path()
		cancel_btn.focus_neighbor_right = confirm_btn.get_path()
	# ------------------------------------------------

func _input(event):
	if current_state == State.TITLE:
		# Accepte le clavier OU n'importe quel bouton de manette pour démarrer
		if (event is InputEventKey and event.pressed) or (event is InputEventJoypadButton and event.pressed) or Input.is_action_just_pressed("ui_accept"):
			show_main_menu()
	else:
		# --- GESTION DU BOUTON RETOUR (B / ROND / ECHAP) ---
		if Input.is_action_just_pressed("ui_cancel"):
			if current_state == State.SLOTS or current_state == State.OPTIONS:
				_on_back_to_menu()
			elif current_state == State.POPUP:
				_on_cancel_delete()

# --- TRANSITIONS ---

func show_main_menu():
	current_state = State.MENU
	
	var t = create_tween()
	t.tween_property(title_container, "modulate:a", 0.0, 0.5)
	t.tween_callback(func(): title_container.visible = false)
	
	# Fade In Menu + DONNER LE FOCUS AU BOUTON "PLAY"
	t.tween_callback(func(): 
		menu_container.visible = true
		btn_play.grab_focus() # <-- C'est ça qui active la manette !
	)
	
	menu_container.modulate.a = 0.0
	t.tween_property(menu_container, "modulate:a", 1.0, 0.5)

func _on_play_pressed():
	# On focus le premier slot de sauvegarde
	var first_slot = slot_container.get_child(0).get_node_or_null("SlotButton")
	_switch_view(menu_container, slot_container, State.SLOTS, first_slot)

func _on_options_pressed():
	# On focus le slider de volume
	_switch_view(menu_container, options_container, State.OPTIONS, volume_slider)

func _on_back_to_menu():
	if current_state == State.SLOTS:
		_switch_view(slot_container, menu_container, State.MENU, btn_play)
	elif current_state == State.OPTIONS:
		_switch_view(options_container, menu_container, State.MENU, btn_play)

# Ajout d'un paramètre optionnel "focus_node" pour dire à Godot quoi sélectionner
func _switch_view(from_node: Control, to_node: Control, new_state: State, focus_node: Control = null):
	current_state = new_state
	var t = create_tween()
	
	t.tween_property(from_node, "modulate:a", 0.0, 0.3)
	t.tween_callback(func(): from_node.visible = false)
	
	t.tween_callback(func(): 
		to_node.visible = true
		if focus_node:
			focus_node.grab_focus() # <-- On donne le focus au nouvel écran
	)
	
	to_node.modulate.a = 0.0
	t.tween_property(to_node, "modulate:a", 1.0, 0.3)

func _on_exit_pressed():
	get_tree().quit()

# --- LOGIQUE OPTIONS (AUDIO / VIDEO) ---

func _on_volume_changed(value: float):
	var bus_index = AudioServer.get_bus_index("Master")
	if value <= 0.0:
		AudioServer.set_bus_mute(bus_index, true)
	else:
		AudioServer.set_bus_mute(bus_index, false)
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

# --- LOGIQUE SLOTS & JEU ---

func update_slot_display(slot_id: int):
	var hbox = slot_container.get_child(slot_id-1)
	var slot_btn = hbox.get_node("SlotButton")
	var del_btn = hbox.get_node("DeleteButton")
	
	if SaveManager.save_exists(slot_id):
		var data = SaveManager.load_data(slot_id)
		var lvl_name = data["current_level"].get_file().get_basename()
		slot_btn.text = "Slot %d - %s" % [slot_id, lvl_name.capitalize()]
		del_btn.visible = true 
	else:
		slot_btn.text = "Slot %d - Empty (New Game)" % slot_id
		del_btn.visible = false 

func _on_slot_pressed(slot_id: int):
	SaveManager.current_slot_id = slot_id
	var target_scene = ""
	var saved_data = SaveManager.load_data(slot_id)
	
	if saved_data:
		target_scene = "res://scenes/main.tscn"
		var level = saved_data["current_level"]
		SaveManager.set_meta("level_to_load", level)
	else:
		var new_data = SaveManager.get_default_data()
		SaveManager.save_game(slot_id, new_data)
		target_scene = "res://intro.tscn" 
	
	var loading_screen = load("res://loading_screen.tscn").instantiate()
	loading_screen.target_scene_path = target_scene
	get_tree().root.add_child(loading_screen)
	queue_free()

# --- LOGIQUE POPUP ---

func _on_delete_request(slot_id: int):
	slot_to_delete = slot_id
	current_state = State.POPUP
	
	delete_popup.visible = true
	delete_popup.modulate.a = 0.0
	
	var t = create_tween()
	t.tween_property(delete_popup, "modulate:a", 1.0, 0.2)
	# Focus sur "Annuler" par défaut pour éviter les suppressions accidentelles !
	t.tween_callback(func(): cancel_btn.grab_focus())

func _on_confirm_delete():
	if slot_to_delete != -1:
		SaveManager.delete_save(slot_to_delete)
		update_slot_display(slot_to_delete)
	_close_popup()

func _on_cancel_delete():
	_close_popup()

func _close_popup():
	var t = create_tween()
	t.tween_property(delete_popup, "modulate:a", 0.0, 0.2)
	t.tween_callback(func(): 
		delete_popup.visible = false
		current_state = State.SLOTS
		slot_to_delete = -1
		
		# On redonne le focus au bouton "Retour" de la liste des slots par sécurité
		if slot_back_btn:
			slot_back_btn.grab_focus()
	)

# --- HELPERS ---
func loop_press_key_anim():
	if not press_key_label: return
	var t = create_tween().set_loops()
	t.tween_property(press_key_label, "modulate:a", 0.3, 1.0)
	t.tween_property(press_key_label, "modulate:a", 1.0, 1.0)

func _reset_alpha_and_hide(nodes: Array):
	for n in nodes:
		if n:
			n.visible = false
			n.modulate.a = 0.0
