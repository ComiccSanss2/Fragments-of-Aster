extends Node2D

@onready var impact_trigger = $ImpactTrigger
@onready var speed_lines = get_node_or_null("SpeedLines") 

var is_falling_cinematic = true

func _ready():
	if speed_lines:
		speed_lines.emitting = true
		speed_lines.visible = true
	
	if impact_trigger:
		impact_trigger.body_entered.connect(_on_impact)
	
	# CREIAMO 50 PUNTI DI RIFERIMENTO VISIVI NEL VUOTO
	for i in range(50):
		var marker = ColorRect.new()
		marker.color = Color(0.2, 0.2, 0.2, 0.5) # Un quadrato grigio scuro
		marker.size = Vector2(64, 64)
		# Li posizioniamo sparsi lungo tutta la caduta (da -3000 fino al pavimento)
		marker.global_position = Vector2(randf_range(-400, 400), randf_range(-3500, 0))
		add_child(marker)
	
	await get_tree().process_frame
	_start_the_drop()

func _start_the_drop():
	var main = get_tree().root.get_node_or_null("Main")
	if main and main.player:
		Engine.time_scale = 1.0 
		if main.player.has_method("reset_from_cinematic"):
			main.player.reset_from_cinematic()
		main.player.can_move = false

# ==========================================
# IL RADAR DI CADUTA (Rompiamo l'illusione)
# ==========================================
var timer = 0.0
func _process(delta):
	timer += delta
	if timer > 0.5 and is_falling_cinematic:
		timer = 0.0
		var p = get_tree().get_first_node_in_group("player")
		if p:
			print("RADAR CADUTA - Altitudine attuale di Lyra: Y = ", p.global_position.y)

func _on_impact(body):
	if body.is_in_group("player") and is_falling_cinematic:
		is_falling_cinematic = false
		print("BOOM! LYRA SI È SCHIANTATA AL SUOLO!") # Se vedi questo, il sistema funziona
		
		if speed_lines:
			speed_lines.emitting = false
			speed_lines.visible = false
		
		var main = get_tree().root.get_node_or_null("Main")
		if main:
			main.trigger_shake(45.0)
			
			var crash_sfx = get_node_or_null("CrashSound")
			if crash_sfx and crash_sfx.stream:
				crash_sfx.play()
			
			await get_tree().create_timer(1.5).timeout
			main.player.can_move = true
			
			if impact_trigger:
				impact_trigger.queue_free()
