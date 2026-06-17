# Relic database — autoload singleton. Loads relic data from JSON.
extends Node

var _relics: Dictionary = {}  # id -> RelicData

# Rarity weights by encounter type
const ELITE_WEIGHTS = {RelicData.Rarity.COMMON: 50, RelicData.Rarity.RARE: 35, RelicData.Rarity.LEGENDARY: 15}
const BOSS_WEIGHTS = {RelicData.Rarity.COMMON: 30, RelicData.Rarity.RARE: 40, RelicData.Rarity.LEGENDARY: 30}


func _ready() -> void:
	_load_relics()


func get_relic(id: String) -> RelicData:
	return _relics.get(id)


func get_all_relics() -> Dictionary:
	return _relics


func get_relics_by_rarity(rarity: int) -> Array:
	var result: Array = []
	for relic in _relics.values():
		if relic.rarity == rarity:
			result.append(relic)
	return result


# Get random relic choices for reward screen (3 choices for elite/boss, 1 for normal)
func get_random_relic_choices(count: int, encounter_type: String) -> Array:
	var weights: Dictionary
	var allow_boss_only: bool = false
	match encounter_type:
		"boss":
			weights = BOSS_WEIGHTS
			allow_boss_only = true
		"elite":
			weights = ELITE_WEIGHTS
			allow_boss_only = false
		_:
			weights = {RelicData.Rarity.COMMON: 100}
			allow_boss_only = false

	# Build pool: exclude already owned and boss_only (unless boss)
	var available: Array = []
	for relic in _relics.values():
		if relic.boss_only and not allow_boss_only:
			continue
		if GameManager.relics.has(relic.id):
			continue
		available.append(relic)

	var result: Array = []
	var picked_ids: Array = []
	for _i in range(count):
		if available.is_empty():
			break
		# Roll rarity tier
		var roll = randi() % 100
		var target_rarity: int = -1
		var cumulative: int = 0
		for rarity in [RelicData.Rarity.COMMON, RelicData.Rarity.RARE, RelicData.Rarity.LEGENDARY]:
			cumulative += weights.get(rarity, 0)
			if roll < cumulative:
				target_rarity = rarity
				break
		if target_rarity == -1:
			target_rarity = RelicData.Rarity.COMMON
		# Filter by rarity tier and not yet picked
		var tier: Array = []
		for relic in available:
			if relic.rarity == target_rarity and not picked_ids.has(relic.id):
				tier.append(relic)
		# Fallback to any available if tier empty
		if tier.is_empty():
			for relic in available:
				if not picked_ids.has(relic.id):
					tier.append(relic)
		if tier.is_empty():
			break
		tier.shuffle()
		result.append(tier[0])
		picked_ids.append(tier[0].id)
	return result


# Get relics for shop (exclude boss_only and already owned)
func get_shop_relics(count: int) -> Array:
	var pool: Array = []
	for relic in _relics.values():
		if not relic.boss_only and not GameManager.relics.has(relic.id):
			pool.append(relic)
	pool.shuffle()
	var result: Array = []
	for relic in pool:
		result.append(relic)
		if result.size() >= count:
			break
	return result


func _load_relics() -> void:
	var path = "res://data/relics.json"
	if not FileAccess.file_exists(path):
		push_error("Relic data file not found: " + path)
		return
	var file = FileAccess.open(path, FileAccess.READ)
	var json = JSON.new()
	var err = json.parse(file.get_as_text())
	if err != OK:
		push_error("Failed to parse relics.json: " + json.get_error_message())
		return
	var data = json.data
	for entry in data:
		var relic = RelicData.new()
		relic.id = entry.get("id", "")
		relic.name = entry.get("name", "")
		relic.description = entry.get("description", "")
		relic.rarity = _str_to_rarity(entry.get("rarity", "common"))
		relic.price = entry.get("price", 150)
		relic.boss_only = entry.get("boss_only", false)
		_relics[relic.id] = relic


func _str_to_rarity(s: String) -> int:
	match s:
		"common": return RelicData.Rarity.COMMON
		"rare": return RelicData.Rarity.RARE
		"legendary": return RelicData.Rarity.LEGENDARY
	return RelicData.Rarity.COMMON
