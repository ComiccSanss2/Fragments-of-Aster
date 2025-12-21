extends Node

# On aura 3 slots : "user://save_slot_1.save", etc.
const SAVE_PATH_TEMPLATE = "user://save_slot_%d.save"

# Variable pour savoir quel slot est en cours d'utilisation
var current_slot_id: int = -1

# Structure de base d'une sauvegarde
func get_default_data():
	return {
		"current_level": "res://scenes/levels/level_1.tscn",
		"grapple_unlocked": false,
		"dash_unlocked": false,
		"intro_played": false
	}

# Vérifie si un slot existe
func save_exists(slot_id: int) -> bool:
	return FileAccess.file_exists(SAVE_PATH_TEMPLATE % slot_id)

# Charge les données d'un slot (pour afficher le nom du niveau dans le menu)
func load_data(slot_id: int):
	if not save_exists(slot_id):
		return null
	
	var file = FileAccess.open(SAVE_PATH_TEMPLATE % slot_id, FileAccess.READ)
	var content = file.get_as_text()
	var data = JSON.parse_string(content)
	return data

# Sauvegarde le jeu (appelé par le Main à chaque niveau)
func save_game(slot_id: int, data: Dictionary):
	var file = FileAccess.open(SAVE_PATH_TEMPLATE % slot_id, FileAccess.WRITE)
	var json_string = JSON.stringify(data)
	file.store_string(json_string)


func delete_save(slot_id: int):
	var path = SAVE_PATH_TEMPLATE % slot_id
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
