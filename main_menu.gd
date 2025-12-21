extends Control

@onready var background = $Background
@onready var title_container = $TitleContainer
@onready var title_label = $TitleContainer/Label
@onready var press_key_label = $TitleContainer/Label2 
@onready var slot_container = $SlotContainer

# --- POPUP NODES ---
@onready var delete_popup = $DeletePopup
@onready var confirm_btn = $DeletePopup/VBoxContainer/HBoxContainer/ConfirmButton
@onready var cancel_btn = $DeletePopup/VBoxContainer/HBoxContainer/CancelButton

enum State { TITLE, SLOTS, POPUP }
var current_state = State.TITLE
var slot_to_delete: int = -1

func _ready():
	# 1. On cache le popup immédiatement (au cas où il est resté visible éditeur)
	if delete_popup: delete_popup.visible = false
	
	# 2. Setup initial (Fade In ne marchait pas si le script plantait avant)
	if title_label: title_label.modulate.a = 0.0
	if press_key_label: press_key_label.modulate.a = 0.0
	slot_container.visible = false
	slot_container.modulate.a = 0.0
	
	# 3. Intro Animation
	var t = create_tween()
	t.tween_interval(0.5)
	if title_label: t.tween_property(title_label, "modulate:a", 1.0, 2.0)
	if press_key_label: t.tween_property(press_key_label, "modulate:a", 1.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	loop_press_key_anim()
	
	# 4. Connexion des Slots
	for i in range(1, 4):
		# Vérification de sécurité
		if slot_container.get_child_count() < i: break
		
		var hbox = slot_container.get_child(i-1)
		var slot_btn = hbox.get_node_or_null("SlotButton")
		var del_btn = hbox.get_node_or_null("DeleteButton")
		
		if slot_btn and del_btn:
			slot_btn.pressed.connect(_on_slot_pressed.bind(i))
			del_btn.pressed.connect(_on_delete_request.bind(i))
			update_slot_display(i)

	# 5. Bouton Retour
	if slot_container.get_child_count() > 3:
		var back_btn = slot_container.get_child(3) as Button
		back_btn.text = "BACK"
		back_btn.pressed.connect(_on_back_pressed)
	
	# 6. Connexion Popup (Vérification pour éviter le crash)
	if confirm_btn: confirm_btn.pressed.connect(_on_confirm_delete)
	else: print("ERREUR: ConfirmButton non trouvé ! Vérifie le chemin dans le script.")
	
	if cancel_btn: cancel_btn.pressed.connect(_on_cancel_delete)
	else: print("ERREUR: CancelButton non trouvé ! Vérifie le chemin dans le script.")


func _input(event):
	if current_state == State.TITLE:
		if event is InputEventKey and event.pressed:
			show_slots()

func loop_press_key_anim():
	if not press_key_label: return
	var t = create_tween().set_loops()
	t.tween_property(press_key_label, "modulate:a", 0.3, 1.0)
	t.tween_property(press_key_label, "modulate:a", 1.0, 1.0)

func show_slots():
	current_state = State.SLOTS
	var t = create_tween()
	t.tween_property(title_container, "modulate:a", 0.0, 0.5)
	t.tween_callback(func(): title_container.visible = false)
	t.tween_callback(func(): slot_container.visible = true)
	t.tween_property(slot_container, "modulate:a", 1.0, 0.5)

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

func _on_delete_request(slot_id: int):
	slot_to_delete = slot_id
	current_state = State.POPUP
	delete_popup.visible = true

func _on_confirm_delete():
	if slot_to_delete != -1:
		SaveManager.delete_save(slot_to_delete)
		update_slot_display(slot_to_delete)
	_close_popup()

func _on_cancel_delete():
	_close_popup()

func _close_popup():
	delete_popup.visible = false
	current_state = State.SLOTS
	slot_to_delete = -1

func _on_slot_pressed(slot_id: int):
	SaveManager.current_slot_id = slot_id
	var level_to_load = "res://scenes/levels/level_1.tscn"
	var saved_data = SaveManager.load_data(slot_id)
	
	if saved_data:
		level_to_load = saved_data["current_level"]
	else:
		var new_data = SaveManager.get_default_data()
		SaveManager.save_game(slot_id, new_data)
	
	SaveManager.set_meta("level_to_load", level_to_load)
	
	# Chargement via Loading Screen
	# Assure-toi que loading_screen.tscn est bien dans le dossier scenes !
	var loading_screen = load("res://loading_screen.tscn").instantiate()
	loading_screen.target_scene_path = "res://scenes/main.tscn"
	get_tree().root.add_child(loading_screen)
	queue_free()

func _on_back_pressed():
	current_state = State.TITLE
	slot_container.visible = false
	slot_container.modulate.a = 0.0
	title_container.visible = true
	title_container.modulate.a = 0.0
	var t = create_tween()
	t.tween_property(title_container, "modulate:a", 1.0, 0.5)
