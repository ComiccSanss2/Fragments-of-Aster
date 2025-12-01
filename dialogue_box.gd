extends Control

@onready var panel := $Panel
@onready var text_label := $Panel/Text
@onready var portrait := $Panel/Portrait
@onready var space_hint := $Panel/SpaceHint

var waiting_for_space := false


func _ready():
	visible = false 
	modulate.a = 1.0




# MONTRE LE TEXTE + ATTEND SPACE POUR CONTINUER
func show_dialog(text: String, portrait_tex: Texture2D = null) -> void:
	visible = true
	modulate.a = 1.0

	# portrait
	if portrait_tex != null:
		portrait.texture = portrait_tex
		portrait.visible = true
	else:
		portrait.visible = false

	# Reset
	text_label.text = ""
	space_hint.visible = false
	waiting_for_space = false

	# Effet typewriter
	for i in text.length():
		text_label.text = text.substr(0, i + 1)
		await get_tree().create_timer(0.02).timeout

	# Montre l’icône [SPACE]
	space_hint.visible = true
	waiting_for_space = true

	# Attend SPACE
	while waiting_for_space:
		await get_tree().process_frame
		if Input.is_action_just_pressed("ui_accept"):
			waiting_for_space = false


func hide_dialog():
	var t = create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.25)
	await t.finished

	visible = false
	modulate.a = 1.0
