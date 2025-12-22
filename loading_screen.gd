extends CanvasLayer 

var target_scene_path: String = ""
var min_load_time: float = 5.0 
var time_elapsed: float = 0.0
var progress: Array = []

@onready var sprite = $Content/AnimatedSprite2D
# NOUVEAU : On récupère le conteneur pour gérer la transparence
@onready var content = $Content 

func _ready():
	# Animation du Sprite
	if sprite.sprite_frames.has_animation("run"):
		sprite.play("run")
	
	# --- 1. FADE IN ---
	content.modulate.a = 0.0
	var t = create_tween()
	t.tween_property(content, "modulate:a", 1.0, 0.5)
	# ------------------
	
	if target_scene_path == "":
		print("Erreur : Aucune scène cible définie !")
		queue_free() 
		return
		
	ResourceLoader.load_threaded_request(target_scene_path)

func _process(delta):
	time_elapsed += delta
	
	sprite.position.x += sin(time_elapsed * 10) * 0.5
	
	var status = ResourceLoader.load_threaded_get_status(target_scene_path, progress)
	
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		if time_elapsed >= min_load_time:
			finish_loading()

func finish_loading():
	set_process(false)
	
	var new_scene = ResourceLoader.load_threaded_get(target_scene_path)
	get_tree().change_scene_to_packed(new_scene)
	
	queue_free()
