# Battle manager — controls turn flow, damage, harmony effects.
class_name BattleManager
extends Node2D
signal enemy_intent_changed(intent_type: int, value: int)
signal enemy_hp_changed(hp: int, max_hp: int)
signal player_attacked_enemy(damage: int)
signal enemy_attacked_player(damage: int)
signal harmony_triggered(attribute: int, bonus_text: String)
signal shake_screen
signal battle_over(won: bool)
signal damage_popup(amount: int, is_player: bool)
signal block_popup(amount: int)
signal enemy_damaged
signal harmony_bonus_damage(amount: int)
signal player_debuffed(strength_change: int)
signal skill_log(text: String)
signal enemy_buff_changed(strength: int, block: int, vulnerable: int)
signal enemy_block_changed(block: int)
var enemy_data: EnemyData
var enemy_hp: int
var enemy_max_hp: int
var enemy_block: int = 0
var enemy_strength: int = 0
var enemy_vulnerable: int = 0
var enemy_move_index: int = 0
var current_intent_type: int = 0
var current_intent_value: int = 0
var current_intent_effect: String = ""
var turn_count: int = 0
var last_intent_type: int = -1  # track last intent type for anti-repeat
var consecutive_same_intent: int = 0  # count of consecutive same-type intents
# Track if attack card was played this turn (for block_if_attack_3)
var attack_played_this_turn: bool = false

func setup(data: EnemyData) -> void:
	enemy_data = data
	enemy_max_hp = data.roll_hp()
	enemy_hp = enemy_max_hp
	enemy_block = 0
	enemy_strength = 0
	enemy_vulnerable = 0
	enemy_move_index = 0
	last_intent_type = -1
	consecutive_same_intent = 0
	turn_count = 0
	attack_played_this_turn = false
	_choose_next_intent()
	emit_signal("enemy_hp_changed", enemy_hp, enemy_max_hp)

func execute_enemy_turn() -> void:
	# Enemy block resets at start of enemy turn
	enemy_block = 0
	# Execute current intent
	match current_intent_type:
		EnemyData.IntentType.ATTACK:
			var dmg = current_intent_value + enemy_strength
			# Player vulnerable: +50% damage
			if GameManager.vulnerable_stacks > 0:
				dmg = int(dmg * 1.5)
			# Check relics
			if GameManager.relics.has("muffler"):
				dmg = maxi(dmg - 1, 0)
			# Relic: dark_room (敌人意图为攻击时-3伤害)
			if GameManager.relics.has("dark_room"):
				dmg = maxi(dmg - 3, 0)
			# Relic: soundproof_hood (30%概率伤害减半)
			if GameManager.relics.has("soundproof_hood") and randf() < 0.3:
				dmg = maxi(dmg / 2, 0)
				emit_signal("skill_log", "隔音头罩触发！伤害减半")
			dmg = maxi(dmg, 0)
			GameManager.take_damage(dmg)
			emit_signal("enemy_attacked_player", dmg)
			emit_signal("shake_screen")
			emit_signal("damage_popup", dmg, true)
		EnemyData.IntentType.DEFEND:
			enemy_block += current_intent_value
			emit_signal("enemy_buff_changed", enemy_strength, enemy_block, enemy_vulnerable)
		EnemyData.IntentType.BUFF:
			enemy_strength += current_intent_value
			emit_signal("enemy_buff_changed", enemy_strength, enemy_block, enemy_vulnerable)
		EnemyData.IntentType.DEBUFF:
			GameManager.strength_buff -= current_intent_value
			emit_signal("player_debuffed", -current_intent_value)
		EnemyData.IntentType.EMPOWER:
			enemy_strength += current_intent_value
			emit_signal("enemy_buff_changed", enemy_strength, enemy_block, enemy_vulnerable)
	# Process effect
	if current_intent_effect != "":
		_process_enemy_effect(current_intent_effect)
	turn_count += 1
	attack_played_this_turn = false
	# Decrement vulnerable
	if GameManager.vulnerable_stacks > 0:
		GameManager.vulnerable_stacks -= 1
	if enemy_vulnerable > 0:
		enemy_vulnerable -= 1
	_choose_next_intent()
	# Check if player died
	if GameManager.player_hp <= 0:
		emit_signal("battle_over", false)

func play_card_effects(card: CardData) -> void:
	# Track attack played this turn (for block_if_attack_3)
	if card.card_type == CardData.CardType.ATTACK:
		attack_played_this_turn = true
	# Harmony detection: GameManager.play_card() already set was_harmony
	var is_harmony = GameManager.was_harmony
	var harmony_attribute = -1  # save for post-calc trigger
	var harmony_boosted = false
	if is_harmony:
		harmony_attribute = card.attribute
		harmony_boosted = GameManager.harmony_boost_active
		GameManager.harmony_boost_active = false
	var total_damage = 0
	var total_block = 0
	# Primary effect by card type
	match card.card_type:
		CardData.CardType.ATTACK:
			if card.get_display_damage() > 0 and card.effect_id != "combo_2" and card.effect_id != "pierce" and card.effect_id != "pierce_weak" and card.effect_id != "beat_pierce_vulnerable":
				var base_damage = card.get_display_damage() + GameManager.strength_buff
				if GameManager.relics.has("distortion_pedal"):
					base_damage += 3
				if GameManager.relics.has("pitch_pipe") and not GameManager.first_attack_played_this_turn:
					base_damage += 2
				if GameManager.relics.has("speaker_cone") and GameManager.hand.size() <= 3:
					base_damage += 2
				if GameManager.relics.has("amplifier"):
					base_damage += GameManager.gold / 50
				if GameManager.relics.has("sustain_pedal") and GameManager.discard_pile.size() >= 8:
					base_damage += 4
				if GameManager.relics.has("finale_scroll") and card.effect_id.begins_with("finale"):
					base_damage = roundi(base_damage * 1.5)
				if enemy_vulnerable > 0:
					base_damage = roundi(base_damage * 1.5)
				# Harmony flat bonus (replaces multiplier)
				var harmony_bonus = 0
				if is_harmony:
					harmony_bonus = card.get_harmony_damage()
					if GameManager.relics.has("resonance_shard"):
						harmony_bonus += 2
					if GameManager.relics.has("resonance_fork"):
						harmony_bonus += 3
					harmony_bonus += GameManager.power_harmony_flat_bonus
				total_damage = maxi(base_damage + harmony_bonus, 0)
				_apply_damage_to_enemy(total_damage)
				emit_signal("player_attacked_enemy", base_damage)
				emit_signal("shake_screen")
				emit_signal("damage_popup", base_damage, false)
				emit_signal("enemy_damaged")
				if harmony_bonus > 0:
					emit_signal("harmony_bonus_damage", harmony_bonus)
				# Rui: 出场 (首张攻击牌时敌人+2易伤)
				if card.effect_id == "first_attack_vulnerable_2" and not GameManager.first_attack_played_this_turn:
					enemy_vulnerable += 2
					emit_signal("skill_log", "出场！敌人+2易伤")
		CardData.CardType.DEFENSE:
			if card.get_display_block() > 0:
				total_block = card.get_display_block() + GameManager.dexterity_buff
				if GameManager.relics.has("reverb_plate"):
					total_block += 3
				# Relic: music_stand (每回合第一张防御牌+2护盾)
				if GameManager.relics.has("music_stand") and not GameManager.first_defense_played_this_turn:
					total_block += 2
				# Rui: 指挥盾 (敌人意图为攻击时+3/4护盾)
				if card.effect_id == "block_if_intent_attack" and current_intent_type == EnemyData.IntentType.ATTACK:
					var intent_bonus = 4 if card.is_upgraded else 3
					total_block += intent_bonus
					emit_signal("skill_log", "指挥盾！意图为攻击，额外+" + str(intent_bonus) + "护盾")
				if is_harmony:
					total_block += card.get_harmony_block()
					total_block += GameManager.power_harmony_flat_bonus
				GameManager.add_block(total_block)
				emit_signal("block_popup", total_block)
		CardData.CardType.SKILL:
			_process_skill_effect(card, is_harmony)
		CardData.CardType.POWER:
			_process_power_effect(card)
	# Secondary effect: attack cards can also grant block, defense cards can also deal damage
	if card.card_type == CardData.CardType.ATTACK and card.get_display_block() > 0:
		total_block = card.get_display_block() + GameManager.dexterity_buff
		if GameManager.relics.has("reverb_plate"):
			total_block += 3
		if is_harmony:
			total_block += card.get_harmony_block()
			total_block += GameManager.power_harmony_flat_bonus
		GameManager.add_block(total_block)
		emit_signal("block_popup", total_block)
	elif card.card_type == CardData.CardType.DEFENSE and card.get_display_damage() > 0:
		total_damage = card.get_display_damage() + GameManager.strength_buff
		if GameManager.relics.has("distortion_pedal"):
			total_damage += 3
		total_damage += _calc_relic_damage_bonus(card)
		if enemy_vulnerable > 0:
			total_damage = int(total_damage * 1.5)
		if is_harmony:
			total_damage += card.get_harmony_damage()
			if GameManager.relics.has("resonance_fork"):
				total_damage += 3
			total_damage += GameManager.power_harmony_flat_bonus
		_apply_damage_to_enemy(total_damage)
		emit_signal("damage_popup", total_damage, false)
	# Process special effect_id FIRST (before harmony attribute effect)
	if card.effect_id != "":
		_process_card_effect(card, card.effect_id, is_harmony)
	# === Deferred harmony attribute effect ===
	# Triggered AFTER all card effects so that MYSTERIOUS vulnerable
	# only affects subsequent attacks, not the triggering card itself.
	if harmony_attribute >= 0:
		_trigger_harmony_effect(harmony_attribute, harmony_boosted)
	# Power: skill_str triggers when skill is played
	if card.card_type == CardData.CardType.SKILL and GameManager.power_skill_str:
		GameManager.strength_buff += 1
		# Power: skill_dex (yoi_power upgrade)
		if card.card_type == CardData.CardType.SKILL and GameManager.power_skill_dex:
			GameManager.dexterity_buff += 1
	# Set first-attack/defense flags AFTER all relic checks are done
	if card.card_type == CardData.CardType.ATTACK and not GameManager.first_attack_played_this_turn:
		GameManager.first_attack_played_this_turn = true
	if card.card_type == CardData.CardType.DEFENSE and not GameManager.first_defense_played_this_turn:
		GameManager.first_defense_played_this_turn = true
	# Check if enemy died
	if enemy_hp <= 0:
		GameManager.kills_this_battle += 1
		# heal_on_kill_5 check
		if card.effect_id == "heal_on_kill_5":
			GameManager.heal(5)
		emit_signal("battle_over", true)

func _apply_damage_to_enemy(amount: int) -> void:
	var actual = amount
	if enemy_block > 0:
		var blocked = min(enemy_block, actual)
		enemy_block -= blocked
		actual -= blocked
	enemy_hp = maxi(enemy_hp - actual, 0)
	emit_signal("enemy_hp_changed", enemy_hp, enemy_max_hp)
	emit_signal("enemy_block_changed", enemy_block)
## Calculate relic bonus damage for a given card.
## Use this in effect handlers that calculate their own damage
## to ensure relic bonuses (pitch_pipe, speaker_cone, etc.) are consistently applied.
func _calc_relic_damage_bonus(card: CardData) -> int:
	var bonus := 0
	if GameManager.relics.has("pitch_pipe") and card.card_type == CardData.CardType.ATTACK and not GameManager.first_attack_played_this_turn:
		bonus += 2
	if GameManager.relics.has("speaker_cone") and GameManager.hand.size() <= 3:
		bonus += 2
	if GameManager.relics.has("amplifier"):
		bonus += GameManager.gold / 50
	if GameManager.relics.has("sustain_pedal") and GameManager.discard_pile.size() >= 8:
		bonus += 4
	return bonus

func _trigger_harmony_effect(attribute: int, boosted: bool = false) -> void:
	var bonus_text = ""
	var boost_tag = "" 
	if boosted:
		boost_tag = "[翻倍]" 
	match attribute:
		CardData.Attribute.NONE:
			bonus_text = ""
		CardData.Attribute.CUTE:
			var heal_amt = 2 if boosted else 1
			GameManager.heal(heal_amt)
			bonus_text = boost_tag + "回复" + str(heal_amt) + "HP"
		CardData.Attribute.COOL:
			var str_red = 2 if boosted else 1
			enemy_strength -= str_red
			emit_signal("enemy_buff_changed", enemy_strength, enemy_block, enemy_vulnerable)
			bonus_text = boost_tag + "敌人-" + str(str_red) + "力量"
		CardData.Attribute.HAPPY:
			var draw_amt = 2 if boosted else 1
			GameManager._draw_cards(draw_amt)
			bonus_text = boost_tag + "抽" + str(draw_amt) + "牌"
		CardData.Attribute.MYSTERIOUS:
			var vuln_amt = 2 if boosted else 1
			enemy_vulnerable += vuln_amt
			bonus_text = boost_tag + "敌人+" + str(vuln_amt) + "易伤"
		CardData.Attribute.PURE:
			var block_amt = 2 if boosted else 1
			GameManager.add_block(block_amt)
			bonus_text = boost_tag + "+" + str(block_amt) + "护盾"
	# Power: harmony_draw triggers when harmony triggers
	if GameManager.power_harmony_draw_count > 0:
		GameManager._draw_cards(1)
		bonus_text += "+抽1牌"
	emit_signal("harmony_triggered", attribute, bonus_text)

func _choose_next_intent() -> void:
	if enemy_data.moves.is_empty():
		current_intent_type = EnemyData.IntentType.ATTACK
		current_intent_value = 5
		current_intent_effect = ""
		var display_val = current_intent_value + enemy_strength if current_intent_type == EnemyData.IntentType.ATTACK else current_intent_value
		if display_val < 0: display_val = 0
		emit_signal("enemy_intent_changed", current_intent_type, display_val)
		return
	# Anti-repeat: if same type 2+ times in a row, try to pick a different type
	var max_retries = 3
	var chosen_type = -1
	var chosen_value = 0
	var chosen_effect = ""
	for _retry in range(max_retries + 1):
		var total_weight: int = 0
		for move in enemy_data.moves:
			total_weight += int(move.get("weight", 1))
		var roll = randi() % total_weight
		var cumulative: int = 0
		for move in enemy_data.moves:
			cumulative += int(move.get("weight", 1))
			if roll < cumulative:
				chosen_type = _str_to_intent(str(move.get("intent", "attack")))
				chosen_value = int(move.get("value", 5))
				chosen_effect = move.get("effect_id", "")
				break
		# If only 1 move type available, accept it regardless
		var unique_types: Array = []
		for move in enemy_data.moves:
			var t = _str_to_intent(str(move.get("intent", "attack")))
			if not unique_types.has(t):
				unique_types.append(t)
		if unique_types.size() <= 1:
			break
		# Accept if different from last type, or if consecutive count < 2
		if chosen_type != last_intent_type or consecutive_same_intent < 2:
			break
	# Update tracking
	if chosen_type == last_intent_type:
		consecutive_same_intent += 1
	else:
		consecutive_same_intent = 1
	last_intent_type = chosen_type
	current_intent_type = chosen_type
	current_intent_value = chosen_value
	current_intent_effect = chosen_effect
	var display_val = current_intent_value + enemy_strength if current_intent_type == EnemyData.IntentType.ATTACK else current_intent_value
	if display_val < 0: display_val = 0
	emit_signal("enemy_intent_changed", current_intent_type, display_val)

func update_intent_display() -> void:
	# Re-emit intent with current enemy_strength for ATTACK intents
	if current_intent_type == EnemyData.IntentType.ATTACK:
		var display_val = current_intent_value + enemy_strength
		if display_val < 0: display_val = 0
		emit_signal("enemy_intent_changed", current_intent_type, display_val)

func _process_skill_effect(card: CardData, is_harmony: bool) -> void:
	var extra_draw = 0
	match card.effect_id:
		"draw_2":
			extra_draw = 2
		"draw_1":
			extra_draw = 1
		"draw_2_skill_power":
			extra_draw = 2 if not card.is_upgraded else 3
			var skill_count = 0
			for c in GameManager.hand:
				if c.card_type == CardData.CardType.SKILL:
					skill_count += 1
			GameManager.strength_buff += skill_count
		"draw_2_skill_discount":
			extra_draw = 2
			# Mark skill discount for this turn (reduce skill card costs by 1)
			for c in GameManager.hand:
				if c.card_type == CardData.CardType.SKILL and c.cost > 0:
					c.cost = maxi(c.cost - 1, 0)
		"exhaust_draw_2":
			extra_draw = 2
			# Card is already handled as exhaust in play_card
		"next_card_discount":
			# Rui: 彩排 - 下张牌费用减免
			GameManager.next_card_discount = 3 if card.is_upgraded else 2
			emit_signal("skill_log", "彩排！下张牌费用-" + str(GameManager.next_card_discount))
		"dodge":
			GameManager.add_block(card.get_display_block())
		"trade":
			var gold_amount = 25 if card.is_upgraded else 15
			GameManager.add_gold(gold_amount)
		"gold_20_block_5":
			GameManager.add_gold(20)
			var charity_blk = card.get_display_block()
			if is_harmony:
				charity_blk += card.get_harmony_block()
				charity_blk += GameManager.power_harmony_flat_bonus
			GameManager.add_block(charity_blk)
		"power_up":
			GameManager.strength_buff += 2
		"harmony_boost":
			GameManager.harmony_boost_active = true
			emit_signal("skill_log", "♪ 和声翻倍已就绪！下次和声触发时加成与属性效果翻倍")
		"heal_low_hp":
			if GameManager.player_hp < GameManager.player_max_hp / 2:
				GameManager.heal(6)
			else:
				GameManager.heal(3)
		"purify":
			if GameManager.strength_buff < 0:
				GameManager.strength_buff = 0
			if GameManager.vulnerable_stacks > 0:
				GameManager.vulnerable_stacks = 0
		"cycle_draw3_discard2":
			extra_draw = 3
			# Discard 2 random cards from hand
			for i in range(mini(2, GameManager.hand.size())):
				var idx = randi() % GameManager.hand.size()
				var discarded = GameManager.hand.pop_at(idx)
				GameManager.discard_pile.append(discarded)
		"retrieve_attack":
			# Get a random attack card from discard pile back to hand
			var attacks: Array = []
			for c in GameManager.discard_pile:
				if c.card_type == CardData.CardType.ATTACK:
					attacks.append(c)
			if not attacks.is_empty():
				var picked = attacks[randi() % attacks.size()]
				GameManager.discard_pile.erase(picked)
				GameManager.hand.append(picked)
		# === NEW SKILL EFFECTS ===
		"ichika_alternate":
			# 一歌·弦乐交替: 造成伤害+获得护盾（攻防混合）
			var alt_dmg = 5 if card.is_upgraded else 3
			alt_dmg += GameManager.strength_buff
			if GameManager.relics.has("distortion_pedal"):
				alt_dmg += 3
			alt_dmg += _calc_relic_damage_bonus(card)
			if enemy_vulnerable > 0:
				alt_dmg = int(alt_dmg * 1.5)
			# Harmony flat bonus for damage
			if is_harmony:
				var h_bonus = card.get_harmony_damage()
				if GameManager.relics.has("resonance_shard"): h_bonus += 2
				if GameManager.relics.has("resonance_fork"): h_bonus += 3
				h_bonus += GameManager.power_harmony_flat_bonus
				alt_dmg += h_bonus
				if h_bonus > 0:
					emit_signal("harmony_bonus_damage", h_bonus)
			_apply_damage_to_enemy(alt_dmg)
			emit_signal("damage_popup", alt_dmg, false)
			emit_signal("enemy_damaged")
			var alt_blk = 5 if card.is_upgraded else 3
			alt_blk += GameManager.dexterity_buff
			if GameManager.relics.has("reverb_plate"):
				alt_blk += 3
			if GameManager.relics.has("music_stand") and not GameManager.first_defense_played_this_turn:
				alt_blk += 2
			# Harmony flat bonus for block
			if is_harmony:
				var h_blk = card.get_harmony_block()
				h_blk += GameManager.power_harmony_flat_bonus
				alt_blk += h_blk
			GameManager.add_block(alt_blk)
			emit_signal("block_popup", alt_blk)
		"cycle_discard_power":
			# 奏·灵感碎片: discard 1 draw 2, if discard pile 5+ → +strength
			if GameManager.hand.size() > 0:
				var idx = randi() % GameManager.hand.size()
				var discarded = GameManager.hand.pop_at(idx)
				GameManager.discard_pile.append(discarded)
			extra_draw = 2
			var threshold = 4 if card.is_upgraded else 5
			var str_bonus = 2 if card.is_upgraded else 1
			if GameManager.discard_pile.size() >= threshold:
				GameManager.strength_buff += str_bonus
		"draw_1_echo_play":
			# 瑞希·影分身: draw 1/2, next card played this turn returns to hand
			extra_draw = 2 if card.is_upgraded else 1
			GameManager.power_first_return = true
			GameManager.first_card_played_this_turn = false
		"str_2_minus_1_energy":
			# 司·蓄力姿态: +2/3 strength, -1 energy this turn
			var str_amt = 3 if card.is_upgraded else 2
			GameManager.strength_buff += str_amt
			GameManager.energy = maxi(GameManager.energy - 1, 0)
			GameManager.emit_signal("energy_changed", GameManager.energy, GameManager.max_energy)
		"discard_damage_all_draw3":
			# 奏·终章·无眠: discard pile / 3/2 = damage to enemy, draw 3
			var divisor = 2 if card.is_upgraded else 3
			var dmg = GameManager.discard_pile.size() / divisor
			if dmg > 0:
				if enemy_vulnerable > 0:
					dmg = int(dmg * 1.5)
				_apply_damage_to_enemy(dmg)
				emit_signal("damage_popup", dmg, false)
			extra_draw = 3
		"beat_strength_per_card":
			# 杏·踏拍: +1 str per card played BEFORE this one, upgrade: also draw 1
			var prev_cards = GameManager.cards_played_this_turn - 1
			if prev_cards > 0:
				GameManager.strength_buff += prev_cards
			if card.is_upgraded:
				extra_draw += 1
		"damage_gain_gold_5":
			var dmg = 8 if card.is_upgraded else 5
			dmg += GameManager.strength_buff
			dmg += _calc_relic_damage_bonus(card)
			if enemy_vulnerable > 0:
				dmg = int(dmg * 1.5)
			_apply_damage_to_enemy(dmg)
			emit_signal("damage_popup", dmg, false)
			emit_signal("enemy_damaged")
			var gold_amt = 8 if card.is_upgraded else 5
			GameManager.add_gold(gold_amt)
		"exhaust_retrieve_2":
			var retrieve_count = 3 if card.is_upgraded else 2
			for idx in range(mini(retrieve_count, GameManager.discard_pile.size())):
				var picked = GameManager.discard_pile[randi() % GameManager.discard_pile.size()]
				GameManager.discard_pile.erase(picked)
				GameManager.hand.append(picked)
		"event_heal_exhaust":
			var heal_amt = 8 if card.is_upgraded else 5
			GameManager.heal(heal_amt)
			emit_signal("skill_log", "调律之音！回复" + str(heal_amt) + "HP")
		"draw_2_discard_1":
			extra_draw = 3 if card.is_upgraded else 2
			for idx in range(mini(1, GameManager.hand.size())):
				var d_idx = randi() % GameManager.hand.size()
				var discarded = GameManager.hand.pop_at(d_idx)
				GameManager.discard_pile.append(discarded)
	if extra_draw > 0:
		if GameManager.relics.has("microphone"):
			extra_draw += 1
		GameManager._draw_cards(extra_draw)

func _process_power_effect(card: CardData) -> void:
	match card.effect_id:
		"power_str_1":
			GameManager.strength_buff += 1
		"power_str_2":
			GameManager.strength_buff += 2
			# Upgrade: also +1 dexterity
			if card.is_upgraded:
				GameManager.dexterity_buff += 1
				emit_signal("skill_log", "激情之心！+2力量+1敏捷")
		"power_dex_1":
			GameManager.dexterity_buff += 1
		"power_harmony_flat_bonus":
			GameManager.power_harmony_flat_bonus = 3 if card.is_upgraded else 2
			if card.is_upgraded:
				emit_signal("skill_log", "调律之心！和声触发时伤害/护盾+3(本战斗永久)")
			else:
				emit_signal("skill_log", "调律之心！和声触发时伤害/护盾+2(本战斗永久)")
		"power_skill_str":
			GameManager.power_skill_str = true
			# Upgrade: also +1 dexterity per skill
			if card.is_upgraded:
				GameManager.power_skill_dex = true
				emit_signal("skill_log", "作曲家的执念！每打出技能牌+1力量+1敏捷")
		"power_first_return":
			GameManager.power_first_return = true
			# Upgrade: card guaranteed in first hand draw + cost becomes 0
			if card.is_upgraded:
				emit_signal("skill_log", "幻影之心！每回合首牌回手（0费）")
		"power_extra_energy":
			GameManager.power_extra_energy = true
			# Upgrade: also +3 gold per turn
			if card.is_upgraded:
				GameManager.power_extra_gold = 3
				emit_signal("skill_log", "富足之心！每回合+1能量+3金")
		"power_harmony_draw":
			GameManager.power_harmony_draw_count = 2 if card.is_upgraded else 1
			emit_signal("skill_log", "音域扩展！和声触发时抽" + str(GameManager.power_harmony_draw_count) + "牌")
		"power_beat_energy":
			GameManager.power_beat_energy = true
			# Upgrade: threshold 3→2
			if card.is_upgraded:
				GameManager.power_beat_threshold = 2
				emit_signal("skill_log", "节拍之心！本回合第2拍→+1能量")
			else:
				GameManager.power_beat_threshold = 3
				emit_signal("skill_log", "节拍之心！本回合第3拍→+1能量")
		"power_play_energy":
			# Rui: 指挥之心
			GameManager.power_play_energy = true
			# Upgrade: threshold 3→2
			if card.is_upgraded:
				GameManager.power_play_threshold = 2
				emit_signal("skill_log", "指挥之心！每回合2+牌→下回合+1能量")
			else:
				emit_signal("skill_log", "指挥之心！每回合3+牌→下回合+1能量")
	# Power cards are removed from deck in GameManager.play_card()

func _process_card_effect(card: CardData, effect_id: String, is_harmony: bool) -> void:
	match effect_id:
		# Skip effects already handled in skill/power
		"draw_2", "draw_2_skill_power", "draw_2_skill_discount", \
		"heal_low_hp", "purify", "trade", "exhaust_draw_2", "gold_20_block_5", \
		"cycle_draw3_discard2", "retrieve_attack", \
		"ichika_alternate", "cycle_discard_power", "draw_1_echo_play", \
		"str_2_minus_1_energy", "discard_damage_all_draw3", \
		"power_str_1", "power_str_2", "power_dex_1", "power_harmony_flat_bonus", \
		"power_skill_str", "power_first_return", "power_extra_energy", "power_harmony_draw", \
		"beat_strength_per_card", "power_beat_energy", "next_card_discount", "power_play_energy", \
		"first_attack_vulnerable_2", "block_if_intent_attack", \
		"power_skill_dex", "exhaust_retrieve_2", "draw_2_discard_1", "damage_gain_gold_5", "event_heal_exhaust":
			pass
		"draw_1":
			GameManager._draw_cards(1)
		"aoe_3":
			var dmg = 3 + GameManager.strength_buff
			if GameManager.relics.has("subwoofer"):
				dmg += 3
			_apply_damage_to_enemy(dmg)
		"aoe_5_str":
			var dmg = 5 + GameManager.strength_buff
			if GameManager.relics.has("subwoofer"):
				dmg += 3
			_apply_damage_to_enemy(dmg)
			GameManager.strength_buff += 2
		"self_heal_3":
			GameManager.heal(3)
		"weak_2":
			enemy_strength -= 2
			emit_signal("enemy_buff_changed", enemy_strength, enemy_block, enemy_vulnerable)
		"vulnerable_2":
			enemy_vulnerable += 2
		"gain_strength_2":
			GameManager.strength_buff += 2
		"gain_strength_1":
			GameManager.strength_buff += 2 if card.is_upgraded else 1
		"combo_2":
			var harmony_hit_bonus = 0
			if is_harmony:
				harmony_hit_bonus = card.get_harmony_damage()
				if GameManager.relics.has("resonance_shard"):
					harmony_hit_bonus += 2
				if GameManager.relics.has("resonance_fork"):
					harmony_hit_bonus += 3
				harmony_hit_bonus += GameManager.power_harmony_flat_bonus
			# First hit (with harmony bonus)
			var dmg = card.get_display_damage() + GameManager.strength_buff + harmony_hit_bonus
			if enemy_vulnerable > 0:
				dmg = int(dmg * 1.5)
			_apply_damage_to_enemy(dmg)
			emit_signal("player_attacked_enemy", dmg)
			emit_signal("damage_popup", dmg, false)
			emit_signal("enemy_damaged")
			# Second hit (no harmony bonus)
			var dmg2 = card.get_display_damage() + GameManager.strength_buff
			if enemy_vulnerable > 0:
				dmg2 = int(dmg2 * 1.5)
			_apply_damage_to_enemy(dmg2)
			emit_signal("player_attacked_enemy", dmg2)
			emit_signal("damage_popup", dmg2, false)
			emit_signal("enemy_damaged")
		"pierce":
			var dmg = card.get_display_damage() + GameManager.strength_buff
			if GameManager.relics.has("distortion_pedal"):
				dmg += 3
			dmg += _calc_relic_damage_bonus(card)
			var harmony_dmg = 0
			if is_harmony:
				harmony_dmg = card.get_harmony_damage()
				if GameManager.relics.has("resonance_shard"):
					harmony_dmg += 2
				if GameManager.relics.has("resonance_fork"):
					harmony_dmg += 3
				harmony_dmg += GameManager.power_harmony_flat_bonus
			dmg += harmony_dmg
			if enemy_vulnerable > 0:
				dmg = int(dmg * 1.5)
			enemy_hp = maxi(enemy_hp - dmg, 0)
			emit_signal("enemy_hp_changed", enemy_hp, enemy_max_hp)
			emit_signal("player_attacked_enemy", dmg)
			if harmony_dmg > 0:
				emit_signal("harmony_bonus_damage", harmony_dmg)
			emit_signal("damage_popup", dmg, false)
			emit_signal("enemy_damaged")
		"pierce_weak":
			var dmg = card.get_display_damage() + GameManager.strength_buff
			if GameManager.relics.has("distortion_pedal"):
				dmg += 3
			dmg += _calc_relic_damage_bonus(card)
			var harmony_dmg = 0
			if is_harmony:
				harmony_dmg = card.get_harmony_damage()
				if GameManager.relics.has("resonance_shard"):
					harmony_dmg += 2
				if GameManager.relics.has("resonance_fork"):
					harmony_dmg += 3
				harmony_dmg += GameManager.power_harmony_flat_bonus
			dmg += harmony_dmg
			if enemy_vulnerable > 0:
				dmg = int(dmg * 1.5)
			enemy_hp = maxi(enemy_hp - dmg, 0)
			enemy_strength -= 2
			emit_signal("enemy_buff_changed", enemy_strength, enemy_block, enemy_vulnerable)
			emit_signal("enemy_hp_changed", enemy_hp, enemy_max_hp)
			emit_signal("player_attacked_enemy", dmg)
			if harmony_dmg > 0:
				emit_signal("harmony_bonus_damage", harmony_dmg)
			emit_signal("damage_popup", dmg, false)
			emit_signal("enemy_damaged")
		"harmony_combo_4":
			if is_harmony:
				var combo_bonus = 7 if card.is_upgraded else 4
				var bonus_dmg = combo_bonus + GameManager.strength_buff
				if enemy_vulnerable > 0:
					bonus_dmg = int(bonus_dmg * 1.5)
				_apply_damage_to_enemy(bonus_dmg)
				emit_signal("damage_popup", bonus_dmg, false)
				emit_signal("skill_log", "弦音斩！和声+" + str(combo_bonus) + "伤害")
		"discard_scaling":
			var bonus_dmg = GameManager.discard_pile.size()
			if bonus_dmg > 0:
				if enemy_vulnerable > 0:
					bonus_dmg = int(bonus_dmg * 1.5)
				_apply_damage_to_enemy(bonus_dmg)
				emit_signal("damage_popup", bonus_dmg, false)
		"attr_synergy_5":
			var same_attr_count = 0
			for c in GameManager.hand:
				if c.attribute == card.attribute:
					same_attr_count += 1
			if same_attr_count >= 3:
				var bonus_dmg = 5 + GameManager.strength_buff
				if enemy_vulnerable > 0:
					bonus_dmg = int(bonus_dmg * 1.5)
				_apply_damage_to_enemy(bonus_dmg)
				emit_signal("damage_popup", bonus_dmg, false)
		"finisher":
			# Cost becomes 0 if enemy HP < 50% - handled in battle_scene
			pass
		"block_if_attack_3":
			if attack_played_this_turn:
				GameManager.add_block(3)
		"block_if_harmony_3":
			if is_harmony:
				var harmony_blk = 4 if card.is_upgraded else 3
				GameManager.add_block(harmony_blk)
		"exhaust":
			pass  # exhaust is handled in GameManager.play_card() for POWER type
		"heal_on_kill_5":
			pass  # checked in play_card_effects after enemy death check
		"draw_if_small_hand":
			if GameManager.hand.size() <= 3:
				GameManager._draw_cards(1)
		"damage_heal_2":
			GameManager.heal(2)
		"finale_harmony_scaling":
			# 類·终章·交响: 造成(基础+和声次数×5)额外伤害
			var harmony_dmg = GameManager.harmony_count * 5
			if harmony_dmg > 0:
				var bonus_dmg = harmony_dmg + GameManager.strength_buff
				if enemy_vulnerable > 0:
					bonus_dmg = int(bonus_dmg * 1.5)
				_apply_damage_to_enemy(bonus_dmg)
				emit_signal("damage_popup", bonus_dmg, false)
				emit_signal("enemy_damaged")
		"combo_if_2_cards_6":
			# 類·复奏冲击: 本回合已打出2+牌时再造成6/8伤害
			if GameManager.cards_played_this_turn >= 2:
				var bonus = 8 if card.is_upgraded else 6
				var bonus_dmg = bonus + GameManager.strength_buff
				if enemy_vulnerable > 0:
					bonus_dmg = int(bonus_dmg * 1.5)
				_apply_damage_to_enemy(bonus_dmg)
				emit_signal("player_attacked_enemy", bonus_dmg)
				emit_signal("damage_popup", bonus_dmg, false)
				emit_signal("enemy_damaged")
		"finale_cost_reduce":
			# 一歌·终章·独奏: cost -2 handled in GameManager.play_card() (harmony_count >= 3)
			pass
		"gold_bonus_damage_3":
			# えむ·压轴演出: gold ≥ 50 → +3/5 damage
			if GameManager.gold >= 50:
				var bonus = 5 if card.is_upgraded else 3
				var bonus_dmg = bonus + GameManager.strength_buff + _calc_relic_damage_bonus(card)
				if enemy_vulnerable > 0:
					bonus_dmg = int(bonus_dmg * 1.5)
				_apply_damage_to_enemy(bonus_dmg)
				emit_signal("damage_popup", bonus_dmg, false)
		"gold_scaling_damage_exhaust":
			# えむ·终章·盛演: +5 damage per 30 gold, exhaust
			var gold_bonus = (GameManager.gold / 30) * 5
			if gold_bonus > 0:
				var bonus_dmg = gold_bonus + GameManager.strength_buff
				if enemy_vulnerable > 0:
					bonus_dmg = int(bonus_dmg * 1.5)
				_apply_damage_to_enemy(bonus_dmg)
				emit_signal("damage_popup", bonus_dmg, false)
		"hand_scale_block_2":
			# 瑞希·终章·残像: +2/3 block per missing card from 5
			var max_hand = 5
			var missing = maxi(max_hand - GameManager.hand.size(), 0)
			var per_missing = 3 if card.is_upgraded else 2
			var total_blk = missing * per_missing
			if total_blk > 0:
				GameManager.add_block(total_blk)
				emit_signal("block_popup", total_blk)
		"kill_scaling_exhaust":
			# 司·终章·谢幕: +15/20 damage per kill this battle, exhaust
			var per_kill = 20 if card.is_upgraded else 15
			var kill_bonus = GameManager.kills_this_battle * per_kill
			if kill_bonus > 0:
				var bonus_dmg = kill_bonus + GameManager.strength_buff
				if enemy_vulnerable > 0:
					bonus_dmg = int(bonus_dmg * 1.5)
				_apply_damage_to_enemy(bonus_dmg)
				emit_signal("damage_popup", bonus_dmg, false)
		# === 白石杏 节拍效果 ===
		"beat_bonus_damage_5":
			# 杏·节拍斩: 3rd beat → +5/7 damage
			if GameManager.cards_played_this_turn == 3:
				var bonus = 7 if card.is_upgraded else 5
				var bonus_dmg = bonus + GameManager.strength_buff
				if enemy_vulnerable > 0:
					bonus_dmg = int(bonus_dmg * 1.5)
				_apply_damage_to_enemy(bonus_dmg)
				emit_signal("player_attacked_enemy", bonus_dmg)
				emit_signal("damage_popup", bonus_dmg, false)
				emit_signal("enemy_damaged")
		"beat_bonus_block_3":
			# 杏·律动盾: 2nd beat → +3/4 block
			if GameManager.cards_played_this_turn == 2:
				var bonus_blk = 4 if card.is_upgraded else 3
				GameManager.add_block(bonus_blk)
				emit_signal("block_popup", bonus_blk)
		"beat_pierce_vulnerable":
			# 杏·强拍冲击: 第3拍→穿透护盾+敌人+2易伤, 非第3拍→正常伤害
			var base_dmg = card.get_display_damage() + GameManager.strength_buff
			if GameManager.relics.has("distortion_pedal"):
				base_dmg += 3
			base_dmg += _calc_relic_damage_bonus(card)
			var harmony_dmg = 0
			if is_harmony:
				harmony_dmg = card.get_harmony_damage()
				if GameManager.relics.has("resonance_shard"):
					harmony_dmg += 2
				if GameManager.relics.has("resonance_fork"):
					harmony_dmg += 3
				harmony_dmg += GameManager.power_harmony_flat_bonus
			base_dmg += harmony_dmg
			if enemy_vulnerable > 0:
				base_dmg = int(base_dmg * 1.5)
			if GameManager.cards_played_this_turn == 3:
				# 第3拍：穿透护盾 + 敌人+2易伤
				enemy_hp = maxi(enemy_hp - base_dmg, 0)
				enemy_vulnerable += 2
				emit_signal("enemy_buff_changed", enemy_strength, enemy_block, enemy_vulnerable)
				emit_signal("enemy_hp_changed", enemy_hp, enemy_max_hp)
			else:
				# 非第3拍：正常伤害（受护盾减免）
				_apply_damage_to_enemy(base_dmg)
			emit_signal("player_attacked_enemy", base_dmg)
			if harmony_dmg > 0:
				emit_signal("harmony_bonus_damage", harmony_dmg)
			emit_signal("damage_popup", base_dmg, false)
			emit_signal("enemy_damaged")
		"beat_2_damage_5":
			# 杏·弱拍斩: 第2拍+5/7伤害
			if GameManager.cards_played_this_turn == 2:
				var bonus = 7 if card.is_upgraded else 5
				var bonus_dmg = bonus + GameManager.strength_buff
				if enemy_vulnerable > 0:
					bonus_dmg = int(bonus_dmg * 1.5)
				_apply_damage_to_enemy(bonus_dmg)
				emit_signal("player_attacked_enemy", bonus_dmg)
				emit_signal("damage_popup", bonus_dmg, false)
				emit_signal("enemy_damaged")
		"beat_3_block_5":
			# 杏·节拍步法: 第3拍+5/7护盾
			if GameManager.cards_played_this_turn == 3:
				var bonus_blk = 7 if card.is_upgraded else 5
				GameManager.add_block(bonus_blk)
				emit_signal("block_popup", bonus_blk)
		"beat_3_double":
			# 杏·终章·狂想: 第3拍→伤害翻倍+敌人-2力量, 消耗
			if GameManager.cards_played_this_turn == 3:
				var base_dmg = card.get_display_damage() + GameManager.strength_buff
				if enemy_vulnerable > 0:
					base_dmg = int(base_dmg * 1.5)
				_apply_damage_to_enemy(base_dmg)
				emit_signal("player_attacked_enemy", base_dmg)
				emit_signal("damage_popup", base_dmg, false)
				emit_signal("enemy_damaged")
				enemy_strength -= 2
				emit_signal("enemy_buff_changed", enemy_strength, enemy_block, enemy_vulnerable)
		# === NEW CARD EFFECTS ===
		"harmony_combo_5":
			if is_harmony:
				var combo_bonus = 8 if card.is_upgraded else 5
				var bonus_dmg = combo_bonus + GameManager.strength_buff
				if enemy_vulnerable > 0:
					bonus_dmg = int(bonus_dmg * 1.5)
				_apply_damage_to_enemy(bonus_dmg)
				emit_signal("damage_popup", bonus_dmg, false)
				emit_signal("skill_log", "回音斩！和声+" + str(combo_bonus) + "伤害")
		"first_card_damage_4":
			# 杏·首拍斩: 第1拍+4/6伤害
			if GameManager.cards_played_this_turn == 1:
				var bonus = 6 if card.is_upgraded else 4
				bonus += GameManager.strength_buff
				bonus += _calc_relic_damage_bonus(card)
				if enemy_vulnerable > 0:
					bonus = int(bonus * 1.5)
				_apply_damage_to_enemy(bonus)
				emit_signal("damage_popup", bonus, false)
				emit_signal("skill_log", "首拍斩！第1拍+" + str(bonus) + "伤害")
		"beat_2_3_damage":
			# 杏·交替连打: 第2拍+4/5伤害, 第3拍+8/10伤害
			var beat = GameManager.cards_played_this_turn
			if beat == 2:
				var bonus = 5 if card.is_upgraded else 4
				var bonus_dmg = bonus + GameManager.strength_buff
				if enemy_vulnerable > 0:
					bonus_dmg = int(bonus_dmg * 1.5)
				_apply_damage_to_enemy(bonus_dmg)
				emit_signal("player_attacked_enemy", bonus_dmg)
				emit_signal("damage_popup", bonus_dmg, false)
				emit_signal("enemy_damaged")
			elif beat == 3:
				var bonus = 10 if card.is_upgraded else 8
				var bonus_dmg = bonus + GameManager.strength_buff
				if enemy_vulnerable > 0:
					bonus_dmg = int(bonus_dmg * 1.5)
				_apply_damage_to_enemy(bonus_dmg)
				emit_signal("player_attacked_enemy", bonus_dmg)
				emit_signal("damage_popup", bonus_dmg, false)
				emit_signal("enemy_damaged")
		"strength_double":
			# 司·霸气斩: strength counts double
			var str_bonus = GameManager.strength_buff
			if enemy_vulnerable > 0:
				str_bonus = int(str_bonus * 1.5)
			_apply_damage_to_enemy(str_bonus)
			emit_signal("damage_popup", str_bonus, false)
		"discard_bonus_3":
			if GameManager.discard_pile.size() >= 5:
				var bonus = 5 if card.is_upgraded else 3
				var bonus_dmg = bonus + GameManager.strength_buff + _calc_relic_damage_bonus(card)
				if enemy_vulnerable > 0:
					bonus_dmg = int(bonus_dmg * 1.5)
				_apply_damage_to_enemy(bonus_dmg)
				emit_signal("damage_popup", bonus_dmg, false)
		"hand_bonus_damage_2":
			var per_card = 3 if card.is_upgraded else 2
			var bonus_dmg = per_card * GameManager.hand.size()
			bonus_dmg += GameManager.strength_buff
			bonus_dmg += _calc_relic_damage_bonus(card)
			if enemy_vulnerable > 0:
				bonus_dmg = int(bonus_dmg * 1.5)
			_apply_damage_to_enemy(bonus_dmg)
			emit_signal("damage_popup", bonus_dmg, false)
		"gold_per_block_2":
			var per_gold = 3 if card.is_upgraded else 2
			var gold_bonus = (GameManager.gold / 30) * per_gold
			if gold_bonus > 0:
				GameManager.add_block(gold_bonus)
				emit_signal("skill_log", "富足之盾！金币加成+" + str(gold_bonus) + "护盾")

func _process_enemy_effect(effect_id: String) -> void:
	match effect_id:
		"self_heal_2":
			enemy_hp = mini(enemy_hp + 2, enemy_max_hp)
			emit_signal("enemy_hp_changed", enemy_hp, enemy_max_hp)
		"self_heal_3":
			enemy_hp = mini(enemy_hp + 3, enemy_max_hp)
			emit_signal("enemy_hp_changed", enemy_hp, enemy_max_hp)

func _str_to_intent(s: String) -> int:
	match s:
		"attack": return EnemyData.IntentType.ATTACK
		"defend": return EnemyData.IntentType.DEFEND
		"buff": return EnemyData.IntentType.BUFF
		"debuff": return EnemyData.IntentType.DEBUFF
		"empower": return EnemyData.IntentType.EMPOWER
	return EnemyData.IntentType.ATTACK



# Calculate preview damage for a card (used by drag preview UI).
# Returns a Dictionary with base_damage, harmony_bonus, vulnerable_multiplier,
# pierces_block, enemy_block, final_damage, shield_absorbed.
func calc_attack_damage(card: CardData, is_harmony: bool) -> Dictionary:
	var result = {
		"base_damage": 0,
		"harmony_bonus": 0,
		"vulnerable_multiplier": 1.0,
		"pierces_block": false,
		"enemy_block": enemy_block,
		"final_damage": 0,
		"shield_absorbed": 0,
	}
	if card.get_display_damage() <= 0 and card.harmony_damage <= 0:
		return result

	# Base damage calculation
	var base_dmg = card.get_display_damage()
	# Excluded effect_ids handle their own damage — calc their base normally
	if card.get_display_damage() > 0:
		base_dmg += GameManager.strength_buff
		if GameManager.relics.has("distortion_pedal"):
			base_dmg += 3
		base_dmg += _calc_relic_damage_bonus(card)
		if enemy_vulnerable > 0:
			base_dmg = int(base_dmg * 1.5)
			result.vulnerable_multiplier = 1.5
	base_dmg = maxi(base_dmg, 0)
	result.base_damage = base_dmg

	# Harmony bonus
	if is_harmony:
		var h_bonus = card.get_harmony_damage()
		if GameManager.relics.has("resonance_shard"):
			h_bonus += 2
		if GameManager.relics.has("resonance_fork"):
			h_bonus += 3
		h_bonus += GameManager.power_harmony_flat_bonus
		result.harmony_bonus = h_bonus

	# Pierces block?
	var pierce_ids = ["pierce", "pierce_weak"]
	if card.effect_id in pierce_ids:
		result.pierces_block = true
	elif card.effect_id == "beat_pierce_vulnerable" and GameManager.cards_played_this_turn == 2:
		# Next card will be 3rd beat (we haven't played this card yet)
		result.pierces_block = true

	# Final damage calculation (accounting for block)
	var total_dmg = base_dmg + result.harmony_bonus
	result.final_damage = total_dmg
	if not result.pierces_block and enemy_block > 0:
		var absorbed = mini(enemy_block, total_dmg)
		result.shield_absorbed = absorbed
		result.final_damage = maxi(total_dmg - absorbed, 0)

	return result
