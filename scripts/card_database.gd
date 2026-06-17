# Card database — autoload singleton. Loads card data from JSON.
extends Node

var _cards: Dictionary = {}  # id -> CardData


func _ready() -> void:
	_load_cards()


func get_card(id: String) -> CardData:
	return _cards.get(id)


func get_all_cards() -> Dictionary:
	return _cards


func get_cards_by_rarity(rarity: int) -> Array:
	var result: Array = []
	for card in _cards.values():
		if card.rarity == rarity:
			result.append(card)
	return result


func get_cards_by_character(char_id: int) -> Array:
	var result: Array = []
	for card in _cards.values():
		if card.character_id == char_id:
			result.append(card)
	return result


# Rarity weights: common 65%, rare 25%, legendary 10%
const RARITY_WEIGHTS = {
	CardData.Rarity.COMMON: 65,
	CardData.Rarity.RARE: 25,
	CardData.Rarity.LEGENDARY: 10,
}


func _build_pool(char_id: int) -> Array:
	var pool: Array = []
	for card in _cards.values():
		if card.id.begins_with("basic"):
			continue
		if card.id.begins_with("event_"):
			continue
		# Include current character's cards AND generic cards (character_id=0)
		if card.character_id == char_id or card.character_id == 0:
			pool.append(card)
	return pool


func _pick_weighted_cards(pool: Array, count: int) -> Array:
	var result: Array = []
	var available = pool.duplicate()
	for i in count:
		if available.is_empty():
			break
		# Roll rarity tier based on weights
		var roll = randi() % 100
		var target_rarity: int = -1
		var cumulative: int = 0
		for rarity in [CardData.Rarity.COMMON, CardData.Rarity.RARE, CardData.Rarity.LEGENDARY]:
			cumulative += RARITY_WEIGHTS[rarity]
			if roll < cumulative:
				target_rarity = rarity
				break
		# If no tier matched (shouldn't happen), default to common
		if target_rarity == -1:
			target_rarity = CardData.Rarity.COMMON
		# Filter available cards by target rarity
		var tier_cards: Array = []
		for card in available:
			if card.rarity == target_rarity:
				tier_cards.append(card)
		# If no cards in this tier, fall back to any available card
		if tier_cards.is_empty():
			tier_cards = available
		# Pick random card from tier
		tier_cards.shuffle()
		var picked = tier_cards[0]
		result.append(picked.duplicate())
		# Remove from available to avoid duplicates
		available.erase(picked)
	return result


func get_shop_cards(count: int) -> Array:
	var pool = _build_pool(GameManager.selected_character_id)
	return _pick_weighted_cards(pool, count)


func get_random_reward_cards(count: int, _rarity_weights: Dictionary = {}) -> Array:
	var pool = _build_pool(GameManager.selected_character_id)
	return _pick_weighted_cards(pool, count)


func get_cards_by_attribute(attr: int) -> Array:
	var result: Array = []
	for card in _cards.values():
		if card.attribute == attr:
			result.append(card)
	return result


func get_starting_deck(character_id: int) -> Array:
	var deck: Array = []
	# 4 basic strikes
	for i in range(4):
		deck.append(get_card("basic_strike").duplicate())
	# 4 basic defends
	for i in range(4):
		deck.append(get_card("basic_defend").duplicate())
	# Character-specific starter cards
	var char_cards = _get_character_cards(character_id)
	for card in char_cards:
		deck.append(card.duplicate())
	return deck


func _get_character_cards(character_id: int) -> Array:
	var char_map = {
		1: ["ichika_strike", "ichika_defend"],
		2: ["an_beat_slash", "an_rhythm_guard"],
		17: ["yoi_strike", "yoi_skill"],
		20: ["mizuki_dodge", "mizuki_strike"],
		16: ["rui_harmony", "rui_strike"],
		14: ["emu_trade", "emu_defend"],
		13: ["tsukasa_power", "tsukasa_strike"],
	}
	var ids = char_map.get(character_id, ["ichika_strike", "ichika_defend"])
	var result: Array = []
	for id in ids:
		var card = get_card(id)
		if card:
			result.append(card)
	return result


func _load_cards() -> void:
	var path = "res://data/cards.json"
	if not FileAccess.file_exists(path):
		push_error("Card data file not found: " + path)
		return
	var file = FileAccess.open(path, FileAccess.READ)
	var json = JSON.new()
	var err = json.parse(file.get_as_text())
	if err != OK:
		push_error("Failed to parse cards.json: " + json.get_error_message())
		return
	var data = json.data
	for entry in data:
		var card = CardData.new()
		card.id = entry.get("id", "")
		card.card_name = entry.get("card_name", "")
		card.character_name = entry.get("character_name", "")
		card.cost = entry.get("cost", 0)
		card.card_type = _str_to_card_type(entry.get("card_type", "attack"))
		card.attribute = _str_to_attribute(entry.get("attribute", "cute"))
		card.rarity = _str_to_rarity(entry.get("rarity", "common"))
		card.damage = entry.get("damage", 0)
		card.block = entry.get("block", 0)
		card.effect_text = entry.get("effect_text", "")
		card.effect_id = entry.get("effect_id", "")
		card.image_path = entry.get("image_path", "")
		card.upgraded_damage = entry.get("upgraded_damage", card.damage + 3 if card.damage > 0 else 0)
		card.upgraded_block = entry.get("upgraded_block", card.block + 3 if card.block > 0 else 0)
		card.upgraded_effect_text = entry.get("upgraded_effect_text", card.effect_text)
		card.upgraded_cost = entry.get("upgraded_cost", -1)
		card.guaranteed_first_draw = entry.get("guaranteed_first_draw", false)
		card.character_id = entry.get("character_id", 0)
		card.harmony_damage = entry.get("harmony_damage", 0)
		card.harmony_block = entry.get("harmony_block", 0)
		card.upgraded_harmony_damage = entry.get("upgraded_harmony_damage", card.harmony_damage)
		card.upgraded_harmony_block = entry.get("upgraded_harmony_block", card.harmony_block)
		_cards[card.id] = card


func _str_to_card_type(s: String) -> int:
	match s:
		"attack": return CardData.CardType.ATTACK
		"defense": return CardData.CardType.DEFENSE
		"skill": return CardData.CardType.SKILL
		"power": return CardData.CardType.POWER
	return CardData.CardType.ATTACK


func _str_to_attribute(s: String) -> int:
	match s:
		"none": return CardData.Attribute.NONE
		"cute": return CardData.Attribute.CUTE
		"cool": return CardData.Attribute.COOL
		"happy": return CardData.Attribute.HAPPY
		"mysterious": return CardData.Attribute.MYSTERIOUS
		"pure": return CardData.Attribute.PURE
	return CardData.Attribute.NONE


func _str_to_rarity(s: String) -> int:
	match s:
		"common": return CardData.Rarity.COMMON
		"rare": return CardData.Rarity.RARE
		"legendary": return CardData.Rarity.LEGENDARY
	return CardData.Rarity.COMMON