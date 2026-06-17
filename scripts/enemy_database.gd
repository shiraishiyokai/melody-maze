# Enemy database — autoload singleton. Loads enemy data from JSON.
extends Node

var _enemies: Dictionary = {}  # id -> EnemyData


func _ready() -> void:
	_load_enemies()


func get_enemy(id: String) -> EnemyData:
	return _enemies.get(id)


func get_enemies_by_tier(tier: int) -> Array:
	var result: Array = []
	for enemy in _enemies.values():
		if enemy.tier == tier:
			result.append(enemy)
	return result


func get_random_normal_enemy() -> EnemyData:
	var normals = get_enemies_by_tier(EnemyData.EnemyTier.NORMAL)
	if normals.is_empty():
		return null
	return normals[randi() % normals.size()]


func get_random_elite() -> EnemyData:
	var elites = get_enemies_by_tier(EnemyData.EnemyTier.ELITE)
	if elites.is_empty():
		return null
	return elites[randi() % elites.size()]


func get_random_normal_by_layer(layer: int) -> EnemyData:
	var normals: Array = []
	for enemy in _enemies.values():
		if enemy.tier == EnemyData.EnemyTier.NORMAL and enemy.layer == layer:
			normals.append(enemy)
	if normals.is_empty():
		return get_random_normal_enemy()
	return normals[randi() % normals.size()]


func get_random_elite_by_layer(layer: int) -> EnemyData:
	var elites: Array = []
	for enemy in _enemies.values():
		if enemy.tier == EnemyData.EnemyTier.ELITE and enemy.layer == layer:
			elites.append(enemy)
	if elites.is_empty():
		return get_random_elite()
	return elites[randi() % elites.size()]


func get_boss_for_floor(floor_num: int) -> EnemyData:
	match floor_num:
		20: return get_enemy("void_tuner")
	return null


func _load_enemies() -> void:
	var path = "res://data/enemies.json"
	if not FileAccess.file_exists(path):
		push_error("Enemy data file not found: " + path)
		return
	var file = FileAccess.open(path, FileAccess.READ)
	var json = JSON.new()
	var err = json.parse(file.get_as_text())
	if err != OK:
		push_error("Failed to parse enemies.json: " + json.get_error_message())
		return
	var data = json.data
	for entry in data:
		var enemy = EnemyData.new()
		enemy.id = entry.get("id", "")
		enemy.enemy_name = entry.get("enemy_name", "")
		enemy.tier = _str_to_tier(entry.get("tier", "normal"))
		enemy.layer = entry.get("layer", 1)
		enemy.min_hp = entry.get("min_hp", 20)
		enemy.max_hp = entry.get("max_hp", 30)
		enemy.image_path = entry.get("image_path", "")
		enemy.moves = entry.get("moves", [])
		_enemies[enemy.id] = enemy


func _str_to_tier(s: String) -> int:
	match s:
		"normal": return EnemyData.EnemyTier.NORMAL
		"elite": return EnemyData.EnemyTier.ELITE
		"boss": return EnemyData.EnemyTier.BOSS
	return EnemyData.EnemyTier.NORMAL
