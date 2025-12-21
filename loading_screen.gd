extends Control

var target_scene_path: String = ""
var min_load_time: float = 3.0 
var time_elapsed: float = 0.0
var progress: Array = []

@onready var sprite = $AnimatedSprite2D

func _ready():
	if sprite.sprite_frames.has_animation("run"):
		sprite.play("run")
	elif sprite.sprite_frames.has_animation("walk"):
		sprite.play("walk")
	
	if target_scene_path == "":
		print("Erreur : Aucune scène cible définie !")
		# On se détruit si pas de cible pour éviter de bloquer l'écran
		queue_free() 
		return
		
	ResourceLoader.load_threaded_request(target_scene_path)

func _process(delta):
	time_elapsed += delta
	# Animation visuelle
	sprite.position.x += sin(time_elapsed * 10) * 0.5
	
	var status = ResourceLoader.load_threaded_get_status(target_scene_path, progress)
	
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		if time_elapsed >= min_load_time:
			var new_scene = ResourceLoader.load_threaded_get(target_scene_path)
			get_tree().change_scene_to_packed(new_scene)
			
			# --- LA CORRECTION EST ICI ---
			queue_free() # On détruit l'écran de chargement pour voir le jeu !
			# -----------------------------
