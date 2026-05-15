extends Control

# --- RÉFÉRENCES UI ---
@onready var title_container = $TitleContainer
@onready var press_key_label = $TitleContainer/Label2

@onready var title_label = $TitleLabel 
@onready var button_container = $ButtonContainer

# Sous-menus
@onready var slot_container = $SlotContainer
@onready var options_container = $OptionsContainer

# Boutons du Menu Principal
@onready var btn_play = $ButtonContainer/PlayButton
@onready var btn_options = $ButtonContainer/OptionsButton
@onready var btn_exit = $ButtonContainer/ExitButton

# --- NUOVI BOUTONS OPTIONS ---
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

# Bouton Retour des Slots
@onready var slot_back_btn = $SlotContainer/SlotBackButton

# Popup Suppression
@onready var delete_popup = $DeletePopup
@onready var confirm_btn = $DeletePopup/VBoxContainer/HBoxContainer/ConfirmButton
@onready var cancel_btn = $DeletePopup/VBoxContainer/HBoxContainer/CancelButton

# --- AUDIO NODES ---
@onready var click_main = $ClickMain
@onready var click_option = $ClickOption

# --- ÉTATS DU MENU ---
enum State { TITLE, MENU, SLOTS, OPTIONS, POPUP }
var current_state = State.TITLE
var slot_to_delete: int = -1

# --- VARIABILI PER GLI EFFETTI VISIVI E OPZIONI ---
var hovered_button: Button = null
var button_container_target_x: float = 0.0

var vol_master: int = 10
var vol_music: int = 10
var vol_sfx: int = 10
var is_fullscreen: bool = false

# ==========================================
# FUNZIONE MAGICA "CATTURA BOTTONI"
# ==========================================
func _get_all_buttons(node: Node) -> Array:
	var arr = []
	for c in node.get_children():
		if c is Button:
			arr.append(c)
		if c.get_child_count() > 0:
			arr.append_array(_get_all_buttons(c))
	return arr

func _ready():
	button_container_target_x = button_container.position.x
	
	var skip_intro = SaveManager.has_meta("skip_main_menu_intro")
	
	if skip_intro:
		SaveManager.remove_meta("skip_main_menu_intro")
		_reset_alpha_and_hide([title_container, slot_container, options_container, delete_popup])
		_animate_buttons_entry()
		
		if title_label: 
			title_label.visible = true
			title_label.modulate.a = 1.0
			
		current_state = State.MENU
	else:
		_reset_alpha_and_hide([button_container, title_label, slot_container, options_container, delete_popup])
		
		if title_container:
			title_container.visible = true
			title_container.modulate.a = 0.0
			var t = create_tween()
			t.tween_interval(0.5)
			t.tween_property(title_container, "modulate:a", 1.0, 2.0)
			t.tween_callback(loop_press_key_anim)
	
	# --- INIZIALIZZAZIONE EFFETTI E SUONI ---
	if btn_play: 
		_setup_button_effects(btn_play, true)
		btn_play.pressed.connect(_play_main_click.bind(1.2))
		
	if btn_options: 
		_setup_button_effects(btn_options, true)
		btn_options.pressed.connect(_play_main_click.bind(0.85))
		
	if btn_exit: 
		_setup_button_effects(btn_exit, true)
		btn_exit.pressed.connect(_play_main_click.bind(0.85))
		
	var back_buttons = [options_back_btn, slot_back_btn]
	for btn in back_buttons:
		if btn: 
			_setup_button_effects(btn, false)
			btn.pressed.connect(_play_main_click.bind(0.85))
	
	var option_arrows = [master_minus, master_plus, music_minus, music_plus, sfx_minus, sfx_plus, video_minus, video_plus]
	for arrow in option_arrows:
		if arrow: 
			_setup_simple_rgb_effect(arrow)
			arrow.pressed.connect(_play_option_click)
	
	# --- Connexions Logica ---
	if btn_play: btn_play.pressed.connect(_on_play_pressed)
	if btn_options: btn_options.pressed.connect(_on_options_pressed)
	if btn_exit: btn_exit.pressed.connect(_on_exit_pressed)
	
	# --- INIZIALIZZAZIONE SLOTS ---
	if slot_container:
		for i in range(1, 4):
			if slot_container.get_child_count() >= i:
				var slot_node = slot_container.get_child(i-1)
				var btns = _get_all_buttons(slot_node)
				
				if btns.size() >= 2:
					var slot_btn = btns[0]
					var del_btn = btns[1]
					
					# Applichiamo SOLO l'effetto RGB ai bottoni dei salvataggi (niente più simboli = niente più spostamenti)
					_setup_simple_rgb_effect(slot_btn)
					_setup_simple_rgb_effect(del_btn)
					
					slot_btn.pressed.connect(_on_slot_pressed.bind(i))
					slot_btn.pressed.connect(_play_main_click.bind(1.0))
					
					del_btn.pressed.connect(_on_delete_request.bind(i))
					del_btn.pressed.connect(_play_main_click.bind(0.85))
					
				update_slot_display(i)

	if slot_back_btn: slot_back_btn.pressed.connect(_on_back_to_menu)
	if options_back_btn: options_back_btn.pressed.connect(_on_back_to_menu)
	
	if confirm_btn: 
		confirm_btn.pressed.connect(_on_confirm_delete)
		confirm_btn.pressed.connect(_play_main_click.bind(0.7))
	if cancel_btn: 
		cancel_btn.pressed.connect(_on_cancel_delete)
		cancel_btn.pressed.connect(_play_main_click.bind(0.85))
		
	_setup_options_ui()

# ==========================================
# AUDIO HELPERS (GESTIONE PITCH)
# ==========================================
func _play_main_click(pitch_val: float = 1.0):
	if click_main:
		click_main.pitch_scale = pitch_val
		click_main.play()

func _play_option_click():
	if click_option:
		click_option.play()

# ==========================================
# ANIMAZIONE ENTRATA (SLIDE-IN PRINCIPALE)
# ==========================================
func _animate_buttons_entry():
	button_container.visible = true
	button_container.position.x = button_container_target_x - 400
	button_container.modulate.a = 0.0
	
	var t = create_tween()
	t.tween_interval(0.4)
	t.parallel().tween_property(button_container, "position:x", button_container_target_x, 0.6).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(button_container, "modulate:a", 1.0, 0.5)
	t.tween_callback(func(): if btn_play: btn_play.grab_focus())

func show_main_menu():
	current_state = State.MENU
	var t = create_tween()
	
	if title_container:
		t.tween_property(title_container, "modulate:a", 0.0, 0.4)
		t.tween_callback(func(): title_container.visible = false)
	
	t.tween_callback(_animate_buttons_entry)
	
	if title_label:
		title_label.visible = true
		title_label.modulate.a = 0.0
		t.tween_property(title_label, "modulate:a", 1.0, 0.5)

# ==========================================
# EFFETTI RGB E BRACKET DI SISTEMA
# ==========================================
func _process(_delta):
	if hovered_button and is_instance_valid(hovered_button):
		var time = Time.get_ticks_msec() / 1000.0
		hovered_button.modulate = Color.from_hsv(fmod(time * 0.5, 1.0), 1.0, 1.0)

# Questa funzione aggiunge i bracket (usata SOLO per i bottoni Play/Options/Exit)
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
	
	# Disconnettiamo per evitare bug se la funzione viene richiamata
	if btn.mouse_entered.is_connected(_on_btn_hovered):
		btn.mouse_entered.disconnect(_on_btn_hovered)
		btn.focus_entered.disconnect(_on_btn_hovered)
		btn.mouse_exited.disconnect(_on_btn_unhovered)
		btn.focus_exited.disconnect(_on_btn_unhovered)
		
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

# Questa funzione accende solo l'RGB e NON tocca mai i testi (usata per Slots, Purge e frecce Opzioni)
func _setup_simple_rgb_effect(btn: Button):
	btn.flat = true 
	
	var empty_style = StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal", empty_style)
	btn.add_theme_stylebox_override("hover", empty_style)
	btn.add_theme_stylebox_override("pressed", empty_style)
	btn.add_theme_stylebox_override("focus", empty_style)
	
	btn.mouse_entered.connect(func(): hovered_button = btn)
	btn.focus_entered.connect(func(): hovered_button = btn)
	btn.mouse_exited.connect(func(): 
		if hovered_button == btn: hovered_button = null
		btn.modulate = Color.WHITE
	)
	btn.focus_exited.connect(func(): 
		if hovered_button == btn: hovered_button = null
		btn.modulate = Color.WHITE
	)

# ==========================================
# LOGICA OPZIONI (AUDIO E VIDEO)
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
# LOGICA DI NAVIGAZIONE E SLOTS (SISTEMA ASTER)
# ==========================================

func format_time(seconds: int) -> String:
	var h = seconds / 3600
	var m = (seconds % 3600) / 60
	var s = seconds % 60
	return "%02d:%02d:%02d" % [h, m, s]

func update_slot_display(slot_id: int):
	var slot_node = slot_container.get_child(slot_id-1)
	
	var btns = _get_all_buttons(slot_node)
	if btns.size() < 2:
		return 
		
	var slot_btn = btns[0]
	var del_btn = btns[1]
	
	slot_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# CENTRIAMO IL TESTO
	slot_btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	del_btn.flat = true
	del_btn.modulate = Color(1.0, 0.2, 0.2) # Rosso errore
	del_btn.text = "[ PURGE ]"
	
	if SaveManager.save_exists(slot_id):
		var data = SaveManager.load_data(slot_id)
		var lvl_name = data["current_level"].get_file().get_basename().to_upper()
		
		var play_time_seconds = data.get("play_time", 0) 
		var time_str = format_time(play_time_seconds)
		
		var new_text = "SECTOR_0%d : STABLE // %s [%s]" % [slot_id, lvl_name, time_str]
		
		# Solo testo puro, nessun bracket nascosto
		slot_btn.text = new_text
		del_btn.visible = true 
	else:
		var new_text = "SECTOR_0%d : UNALLOCATED // NULL" % slot_id
		slot_btn.text = new_text
		del_btn.visible = false 

func _on_play_pressed():
	var btns = _get_all_buttons(slot_container.get_child(0))
	var first_slot = btns[0] if btns.size() > 0 else null
	_switch_view(button_container, slot_container, State.SLOTS, first_slot)

func _on_options_pressed():
	_switch_view(button_container, options_container, State.OPTIONS, master_plus)

func _on_back_to_menu():
	if current_state == State.SLOTS:
		_switch_view(slot_container, button_container, State.MENU, btn_play)
	elif current_state == State.OPTIONS:
		_switch_view(options_container, button_container, State.MENU, btn_play)

func _switch_view(from_node: Control, to_node: Control, new_state: State, focus_node: Control = null):
	current_state = new_state
	var t = create_tween()
	
	# FADE OUT del menu attuale
	t.tween_property(from_node, "modulate:a", 0.0, 0.2)
	if from_node == button_container and title_label:
		t.parallel().tween_property(title_label, "modulate:a", 0.0, 0.2)
		
	t.tween_callback(func(): 
		from_node.visible = false
		if title_label: title_label.visible = (to_node == button_container)
		to_node.visible = true
		to_node.modulate.a = 1.0
		
		# ANIMAZIONE A CASCATA 
		# (1s primo slot -> 1s pausa -> 1s secondo slot -> 1s pausa -> 1s terzo slot)
		if to_node == slot_container:
			for i in range(3):
				var slot_node = slot_container.get_child(i)
				slot_node.modulate.a = 0.0
				
				# Logica: 0 (Sinistra), 1 (Destra), 2 (Sinistra)
				var start_x = -300.0 if i % 2 == 0 else 300.0
				slot_node.position.x = start_x
				
				var cascade = create_tween()
				
				# i * 2.0 calcola la pausa perfetta:
				# i = 0 -> 0 secondi di ritardo
				# i = 1 -> 2 secondi di ritardo (cioè 1s di slot precedente + 1s di pausa)
				# i = 2 -> 4 secondi di ritardo (cioè 2s di slot precedenti + 2s di pause totali)
				var start_delay = i * 2.0 
				if start_delay > 0:
					cascade.tween_interval(start_delay)
					
				# Movimento e comparsa (durano esattamente 1.0 secondo)
				cascade.parallel().tween_property(slot_node, "modulate:a", 1.0, 1.0).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
				cascade.parallel().tween_property(slot_node, "position:x", 0.0, 1.0).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
			
			# Il bottone back entra in ritardo quando la cascata è finita
			slot_back_btn.modulate.a = 0.0
			var b_t = create_tween()
			b_t.tween_interval(5.0)
			b_t.tween_property(slot_back_btn, "modulate:a", 1.0, 0.5)
		else:
			to_node.modulate.a = 0.0
			var t2 = create_tween()
			t2.tween_property(to_node, "modulate:a", 1.0, 0.2)
			
		if focus_node: focus_node.grab_focus()
	)
	
	if to_node == button_container and title_label:
		t.parallel().tween_property(title_label, "modulate:a", 1.0, 0.2)

func _on_exit_pressed():
	get_tree().quit()

func _on_slot_pressed(slot_id: int):
	SaveManager.current_slot_id = slot_id
	var target = "res://scenes/main.tscn" if SaveManager.save_exists(slot_id) else "res://intro.tscn"
	if SaveManager.save_exists(slot_id):
		SaveManager.set_meta("level_to_load", SaveManager.load_data(slot_id)["current_level"])
	var ls = load("res://loading_screen.tscn").instantiate()
	ls.target_scene_path = target
	get_tree().root.add_child(ls)
	queue_free()

func _on_delete_request(slot_id: int):
	slot_to_delete = slot_id
	current_state = State.POPUP
	delete_popup.visible = true
	delete_popup.modulate.a = 0.0
	create_tween().tween_property(delete_popup, "modulate:a", 1.0, 0.2)
	cancel_btn.grab_focus()

func _on_confirm_delete():
	SaveManager.delete_save(slot_to_delete)
	update_slot_display(slot_to_delete)
	_close_popup()

func _on_cancel_delete(): _close_popup()

func _close_popup():
	var t = create_tween()
	t.tween_property(delete_popup, "modulate:a", 0.0, 0.2)
	t.tween_callback(func(): 
		delete_popup.visible = false
		current_state = State.SLOTS
		slot_back_btn.grab_focus()
	)

func _input(event):
	if current_state == State.TITLE:
		if event.is_pressed() or Input.is_action_just_pressed("ui_accept"): show_main_menu()
	elif Input.is_action_just_pressed("ui_cancel"):
		if current_state in [State.SLOTS, State.OPTIONS]: _on_back_to_menu()
		elif current_state == State.POPUP: _on_cancel_delete()

func loop_press_key_anim():
	var t = create_tween().set_loops()
	t.tween_property(press_key_label, "modulate:a", 0.3, 1.0)
	t.tween_property(press_key_label, "modulate:a", 1.0, 1.0)

func _reset_alpha_and_hide(nodes: Array):
	for n in nodes: if n: n.visible = false; n.modulate.a = 0.0
