# Global game state manager — autoload singleton.
extends Node

signal hp_changed(new_hp: int, max_hp: int)
signal gold_changed(new_gold: int)
signal block_changed(new_block: int)
signal energy_changed(current: int, max_energy: int)
signal battle_started
signal battle_won(gold_reward: int)
signal battle_lost
signal turn_started
signal turn_ended
signal run_complete

var player_hp: int = 80
var player_max_hp: int = 80
var gold: int = 0
var current_floor: int = 1
var max_floors: int = 20

# Map state
var map_nodes: Array = []
var current_node_id: String = ""
var encounter_type: String = ""
var next_enemy_id: String = ""
var gold_reward_pending: int = 0

# Deck / draw / discard piles
var deck: Array = []
var draw_pile: Array = []
var hand: Array = []
var discard_pile: Array = []

# Battle state
var energy: int = 3
var max_energy: int = 3
var player_block: int = 0
var last_played_attribute: int = -1  # CardData.Attribute enum value
var in_battle: bool = false
var harmony_count: int = 0  # consecutive harmony triggers this turn
var last_played_card_type: int = -1  # CardData.CardType of last card played this turn
var kills_this_battle: int = 0  # number of enemies killed this battle
var was_harmony: bool = false  # set in play_card(), read by BattleManager

# Beat system (for 白石杏)
var cards_played_this_turn: int = 0  # how many cards played this turn
var prev_turn_cards_played: int = 0  # cards played last turn (for power_beat_energy)

# Player buffs (reset per battle)
var strength_buff: int = 0  # extra damage per attack
var dexterity_buff: int = 0  # extra block per defense
var vulnerable_stacks: int = 0  # player takes 50% more damage, -1 per turn

# Power card permanent effects (reset per battle)
var power_harmony_flat_bonus: int = 0  # 和声触发时伤害/护盾+N (base:2, upgraded:3)
var power_skill_str: bool = false  # 每打出技能+1力量
var power_skill_dex: bool = false  # (upgrade) 每打出技能+1敏捷
var power_first_return: bool = false  # 每回合首牌回手
var power_extra_energy: bool = false  # 每回合+1能量
var power_extra_gold: int = 0  # (upgrade) 每回合额外获得金币
var power_harmony_draw_count: int = 0  # 和声触发时抽N牌(1默认,升级2)
var power_beat_energy: bool = false  # 上回合3+牌则本回合+1能量
var power_beat_threshold: int = 3  # (upgrade) 3→2
var harmony_boost_active: bool = false  # 下次和声效果翻倍（一次性）
var first_card_played_this_turn: bool = false  # track for power_first_return
var headphone_used: bool = false  # 耳机遗物：每回合已用过折扣
var next_card_discount: int = 0  # 類·彩排: 下张牌费用减免量（用完归零）
var power_play_energy: bool = false  # 類·指挥之心: 每回合3+牌→下回合+1能量
var power_play_threshold: int = 3  # (upgrade) 3→2
var beat_energy_applied: bool = false  # prevent double max_energy increase
var play_energy_applied: bool = false  # prevent double max_energy increase


# Relic state (reset per battle)
var battle_turn_count: int = 0
var wah_pedal_counter: int = 0
var wah_pedal_free: bool = false
var first_attack_played_this_turn: bool = false
var first_defense_played_this_turn: bool = false
var cassette_tape_used: bool = false

# Relics
var relics: Array = []
var relic_pick_pending: bool = false
var relic_pick_count: int = 3

# Character selection
var selected_character_id: int = 1  # default: Ichika

# Run state
var run_active: bool = false

# === Score tracking (persist across entire run) ===
var total_gold_earned: int = 0       # cumulative gold earned (not current gold)
var normal_kills: int = 0            # total normal enemy kills across run
var elite_kills: int = 0             # total elite enemy kills across run
var boss_kills: int = 0              # total boss kills (0 or 1)
var total_battles_won: int = 0       # total battle victories
var upgraded_cards_count: int = 0    # number of cards upgraded during run
var run_completed_won: bool = false  # whether the run ended in victory


func start_new_run(character_id: int) -> void:
	selected_character_id = character_id
	player_hp = 80
	player_max_hp = 80
	gold = 0
	current_floor = 1
	deck = CardDB.get_starting_deck(character_id)
	relics.clear()
	relic_pick_pending = false
	relic_pick_count = 3
	draw_pile.clear()
	hand.clear()
	discard_pile.clear()
	run_active = true
	map_nodes.clear()
	current_node_id = ""
	encounter_type = ""
	next_enemy_id = ""
	gold_reward_pending = 0
	total_gold_earned = 0
	normal_kills = 0
	elite_kills = 0
	boss_kills = 0
	total_battles_won = 0
	upgraded_cards_count = 0
	run_completed_won = false
	emit_signal("hp_changed", player_hp, player_max_hp)
	emit_signal("gold_changed", gold)


func start_battle(_enemies: Array) -> void:
	in_battle = true
	max_energy = 3  # Reset to base; power card bonuses are battle-only
	energy = max_energy
	player_block = 0
	# Relic: vinyl_record (战斗开始时获得4护盾)
	if relics.has("vinyl_record"):
		add_block(4)
	strength_buff = 0
	# old_metronome: +1 permanent strength each battle
	if relics.has("old_metronome"):
		strength_buff += 1
	dexterity_buff = 0
	vulnerable_stacks = 0
	harmony_count = 0
	last_played_attribute = -1
	last_played_card_type = -1
	kills_this_battle = 0
	was_harmony = false
	cards_played_this_turn = 0
	prev_turn_cards_played = 0
	# Reset power effects
	power_harmony_flat_bonus = 0
	power_skill_str = false
	power_skill_dex = false
	power_first_return = false
	power_extra_energy = false
	power_extra_gold = 0
	power_harmony_draw_count = 0
	power_beat_energy = false
	power_beat_threshold = 3
	harmony_boost_active = false
	first_card_played_this_turn = false
	headphone_used = false
	next_card_discount = 0
	power_play_energy = false
	power_play_threshold = 3
	beat_energy_applied = false
	play_energy_applied = false
	battle_turn_count = 0
	wah_pedal_counter = 0
	wah_pedal_free = false
	first_attack_played_this_turn = false
	first_defense_played_this_turn = false
	cassette_tape_used = false
	draw_pile = deck.duplicate()
	draw_pile.shuffle()
	hand.clear()
	discard_pile.clear()
	# Guaranteed first draw: cards with guaranteed_first_draw go to hand first
	var guaranteed: Array = []
	for card in draw_pile:
		if card.guaranteed_first_draw:
			guaranteed.append(card)
	for card in guaranteed:
		draw_pile.erase(card)
		hand.append(card)
	_draw_cards(5 - guaranteed.size())
	emit_signal("energy_changed", energy, max_energy)
	emit_signal("battle_started")
	emit_signal("turn_started")


func end_player_turn() -> void:
	for card in hand:
		discard_pile.append(card)
	hand.clear()
	last_played_attribute = -1
	last_played_card_type = -1
	prev_turn_cards_played = cards_played_this_turn
	cards_played_this_turn = 0
	# Decrement vulnerable
	if vulnerable_stacks > 0:
		vulnerable_stacks -= 1
	emit_signal("turn_ended")


func start_new_turn() -> void:
	energy = max_energy
	player_block = 0  # block doesn't carry over
	first_card_played_this_turn = false
	headphone_used = false
	beat_energy_applied = false
	emit_signal("block_changed", player_block)
	battle_turn_count += 1
	first_attack_played_this_turn = false
	first_defense_played_this_turn = false
	next_card_discount = 0
	# Relic: tuning fork (+1 energy, -1 draw)
	if relics.has("tuning_fork"):
		energy += 1
	# Relic: grand piano (energy per 3 relics)
	if relics.has("grand_piano"):
		energy += relics.size() / 3
	# Power: extra energy
	if power_extra_energy:
		energy += 1
		# Power: extra gold (emu_power upgrade)
		if power_extra_gold > 0:
			add_gold(power_extra_gold)
	# Rui: 指挥之心 (power_play_energy: increase max_energy permanently, once)
	if power_play_energy and not play_energy_applied and prev_turn_cards_played >= power_play_threshold:
		max_energy += 1
		play_energy_applied = true
		energy = max_energy
	# Draw cards
	var draw_count = 5
	if relics.has("tuning_fork"):
		draw_count -= 1  # 代价：少抽1牌
	if relics.has("radio"):
		draw_count += 1  # 收音机：额外抽1牌
	if relics.has("metronome") and battle_turn_count <= 2:
		draw_count += 1  # 节拍器：前2回合额外抽1牌
	_draw_cards(draw_count)
	# Relic: distortion_pedal / reverb_plate 代价（每回合-1HP）
	if relics.has("distortion_pedal") or relics.has("reverb_plate"):
		take_damage(1)
	emit_signal("energy_changed", energy, max_energy)
	emit_signal("turn_started")


func play_card(card: CardData) -> bool:
	if card.get_display_cost() > energy:
		return false

	# Track last card type for effects
	last_played_card_type = card.card_type
	cards_played_this_turn += 1
	# Power: beat_energy (本回合第3拍/升级第2拍→+1能量永久, 一次)
	if power_beat_energy and not beat_energy_applied and cards_played_this_turn >= power_beat_threshold:
		max_energy += 1
		beat_energy_applied = true
		energy += 1
		emit_signal("energy_changed", energy, max_energy)



	var _was_wah_free = wah_pedal_free
	var actual_cost = card.get_display_cost()
	# Finisher: cost 0 if enemy HP < 50%
	if card.effect_id == "finisher":
		pass  # handled in battle_manager after checking enemy HP
	# Rui: 彩排 next_card_discount
	if next_card_discount > 0:
		actual_cost = maxi(actual_cost - next_card_discount, 0)
		next_card_discount = 0
	# Relic: wah_pedal free card
	elif wah_pedal_free:
		actual_cost = 0
		wah_pedal_free = false
	# Relic: headphone (每回合第一张牌费用-1)
	elif relics.has("headphone") and not headphone_used:
		actual_cost = maxi(actual_cost - 1, 0)
		headphone_used = true
	# Relic: wah_pedal (每打出3张牌，下张牌费用为0; 0费牌不计入计数)
	if relics.has("wah_pedal") and not _was_wah_free:
		wah_pedal_counter += 1
		if wah_pedal_counter >= 3:
			wah_pedal_free = true
			wah_pedal_counter = 0
	# Ichika: 终章·独奏 cost -2 if 3+ harmony triggers
	if card.effect_id == "finale_cost_reduce" and harmony_count >= 3:
		actual_cost = maxi(actual_cost - 2, 0)

	energy -= actual_cost

	# Check harmony: same attribute as last played
	var card_attr = card.attribute
	was_harmony = false
	# NONE attribute cards never participate in harmony
	if card_attr == CardData.Attribute.NONE:
		last_played_attribute = -1
	else:
		# always_harmony: card counts as all attributes
		if card.effect_id == "always_harmony" and last_played_attribute != -1:
			card_attr = last_played_attribute  # match whatever was last played
		var is_harmony = last_played_attribute == card_attr and last_played_attribute != -1
		if is_harmony:
			harmony_count += 1
			was_harmony = true
			# 和声触发后重置：需要再打出2张同属性牌才能触发下一次和声
			last_played_attribute = -1
		else:
			last_played_attribute = card_attr

	# Power card first-return: first card each turn returns to hand
	if power_first_return and not first_card_played_this_turn:
		first_card_played_this_turn = true
		hand.erase(card)
		hand.append(card)  # return to hand instead of discard
		# Still remove energy cost but card stays in hand
		# Do NOT add to discard
		emit_signal("energy_changed", energy, max_energy)
		return true

	# Remove from hand
	hand.erase(card)

	# Power cards: stay in permanent deck, but removed from battle piles this combat
	if card.card_type == CardData.CardType.POWER:
		draw_pile.erase(card)
		discard_pile.erase(card)
	elif card.is_exhaust():
		# Exhaust cards: remove from this battle but stay in permanent deck
		draw_pile.erase(card)
		discard_pile.erase(card)
	else:
		discard_pile.append(card)

	emit_signal("energy_changed", energy, max_energy)
	return true


func take_damage(amount: int) -> void:
	var actual = amount
	if player_block > 0:
		var blocked = min(player_block, actual)
		player_block -= blocked
		actual -= blocked
		emit_signal("block_changed", player_block)
	player_hp -= actual
	if player_hp < 0:
		player_hp = 0
	emit_signal("hp_changed", player_hp, player_max_hp)


func heal(amount: int) -> void:
	player_hp = mini(player_hp + amount, player_max_hp)
	emit_signal("hp_changed", player_hp, player_max_hp)


func add_block(amount: int) -> void:
	player_block += amount
	emit_signal("block_changed", player_block)


func add_gold(amount: int) -> void:
	gold += amount
	total_gold_earned += amount
	emit_signal("gold_changed", gold)


func spend_gold(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	emit_signal("gold_changed", gold)
	return true


func add_card_to_deck(card: CardData) -> void:
	deck.append(card)


func remove_card_from_deck(card: CardData) -> void:
	deck.erase(card)
	draw_pile.erase(card)
	hand.erase(card)
	discard_pile.erase(card)


func _draw_cards(count: int) -> void:
	for i in count:
		if draw_pile.is_empty():
			draw_pile = discard_pile.duplicate()
			discard_pile.clear()
			_shuffle_draw_pile()
		if not draw_pile.is_empty():
			var card = draw_pile.pop_front()
			hand.append(card)


func _shuffle_draw_pile() -> void:
	draw_pile.shuffle()

func generate_map() -> void:
	var gen = MapGenerator.new()
	map_nodes = gen.generate()
	current_node_id = ""
	_mark_available_nodes()

func select_node(node_id: String) -> void:
	var node = _get_node_by_id(node_id)
	if node.is_empty():
		return
	encounter_type = node.get("type", "battle")
	current_node_id = node_id
	if encounter_type in ["battle", "elite", "boss"]:
		next_enemy_id = node.get("enemy_id", "noise_slime")

func advance_floor() -> void:
	_mark_node_visited(current_node_id)
	current_floor += 1
	if current_floor > max_floors:
		run_completed_won = true
		run_active = false
		emit_signal("run_complete")
		return
	_mark_available_nodes()

func get_encounter_scene_path() -> String:
	match encounter_type:
		"battle", "elite", "boss":
			return "res://scenes/battle.tscn"
		"event":
			return "res://scenes/event.tscn"
		"shop":
			return "res://scenes/shop.tscn"
		"campfire":
			return "res://scenes/campfire.tscn"
	return "res://scenes/map.tscn"

func _mark_available_nodes() -> void:
	for node in map_nodes:
		node["available"] = false
	if current_node_id == "":
		for node in map_nodes:
			if node.get("floor", 0) == 1:
				node["available"] = true
		return
	var current = _get_node_by_id(current_node_id)
	if current.is_empty():
		return
	for conn_id in current.get("connections", []):
		var conn_node = _get_node_by_id(conn_id)
		if not conn_node.is_empty():
			conn_node["available"] = true

func _mark_node_visited(id: String) -> void:
	for node in map_nodes:
		if node.get("id", "") == id:
			node["visited"] = true

func _get_node_by_id(id: String) -> Dictionary:
	for node in map_nodes:
		if node.get("id", "") == id:
			return node
	return {}

func has_basic_card() -> bool:
	for card in deck:
		if card.id in ["basic_strike", "basic_defend"]:
			return true
	return false


func get_basic_cards() -> Array:
	var basics: Array = []
	for card in deck:
		if card.id in ["basic_strike", "basic_defend"]:
			basics.append(card)
	return basics


func get_upgradable_cards() -> Array:
	var upgradable: Array = []
	for card in deck:
		if not card.is_upgraded:
			upgradable.append(card)
	return upgradable
