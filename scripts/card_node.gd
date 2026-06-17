# Card UI node — displays a single card, supports drag-to-play.
extends Control

signal card_played(card_data: CardData)
signal card_hovered(card_data: CardData)
signal card_unhovered

var card_data: CardData
var is_playable: bool = true
var is_hovering: bool = false
var is_dragging: bool = false
var drag_start_pos: Vector2 = Vector2.ZERO
var drag_offset: Vector2 = Vector2.ZERO

var card_bg: ColorRect
var card_image: TextureRect
var cost_label: Label
var cost_bg: ColorRect
var wah_pedal_tag: Label  # 哇音踏板提示标签
var damage_preview_label: Label  # 拖拽时伤害预览
var name_label: Label
var attr_dot: ColorRect
var damage_label: Label
var block_label: Label
var effect_label: Label
var harmony_tag: Label

const CARD_W = 100
const CARD_H = 140
const DRAG_THRESHOLD = 10.0  # pixels before drag starts
const PLAY_DISTANCE = 80.0  # non-attack cards must be dragged this far to play
var mouse_pressed: bool = false
var mouse_press_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	custom_minimum_size = Vector2(CARD_W, CARD_H)
	size = Vector2(CARD_W, CARD_H)
	_build_ui()


func _build_ui() -> void:
	card_bg = ColorRect.new()
	card_bg.size = Vector2(CARD_W, CARD_H)
	card_bg.color = Color(0.3, 0.15, 0.15)
	add_child(card_bg)

	card_image = TextureRect.new()
	card_image.position = Vector2(8, 8)
	card_image.size = Vector2(84, 84)
	card_image.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	card_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(card_image)

	cost_bg = ColorRect.new()
	cost_bg.position = Vector2(2, 2)
	cost_bg.size = Vector2(22, 22)
	cost_bg.color = Color(0.1, 0.1, 0.2, 0.8)
	add_child(cost_bg)

	cost_label = Label.new()
	cost_label.position = Vector2(2, 2)
	cost_label.size = Vector2(22, 22)
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost_label.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	cost_label.add_theme_font_size_override("font_size", 16)
	add_child(cost_label)

	wah_pedal_tag = Label.new()
	wah_pedal_tag.position = Vector2(2, 24)
	wah_pedal_tag.size = Vector2(22, 10)
	wah_pedal_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wah_pedal_tag.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
	wah_pedal_tag.add_theme_font_size_override("font_size", 8)
	wah_pedal_tag.text = "踏板"
	wah_pedal_tag.visible = false
	wah_pedal_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wah_pedal_tag)

	damage_preview_label = Label.new()
	damage_preview_label.position = Vector2(-10, -30)
	damage_preview_label.size = Vector2(120, 24)
	damage_preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	damage_preview_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	damage_preview_label.add_theme_font_size_override("font_size", 13)
	damage_preview_label.visible = false
	damage_preview_label.z_index = 200
	damage_preview_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(damage_preview_label)

	attr_dot = ColorRect.new()
	attr_dot.position = Vector2(78, 4)
	attr_dot.size = Vector2(14, 14)
	attr_dot.color = Color.PINK
	add_child(attr_dot)

	name_label = Label.new()
	name_label.position = Vector2(4, 94)
	name_label.size = Vector2(92, 16)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.clip_text = true
	add_child(name_label)

	damage_label = Label.new()
	damage_label.position = Vector2(4, 110)
	damage_label.size = Vector2(46, 16)
	damage_label.add_theme_color_override("font_color", Color(1, 0.5, 0.5))
	damage_label.add_theme_font_size_override("font_size", 13)
	add_child(damage_label)

	block_label = Label.new()
	block_label.position = Vector2(50, 110)
	block_label.size = Vector2(46, 16)
	block_label.add_theme_color_override("font_color", Color(0.5, 0.7, 1))
	block_label.add_theme_font_size_override("font_size", 13)
	add_child(block_label)

	effect_label = Label.new()
	effect_label.position = Vector2(4, 124)
	effect_label.size = Vector2(92, 14)
	effect_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	effect_label.add_theme_font_size_override("font_size", 10)
	effect_label.clip_text = true
	add_child(effect_label)

	harmony_tag = Label.new()
	harmony_tag.position = Vector2(4, 4)
	harmony_tag.size = Vector2(40, 14)
	harmony_tag.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	harmony_tag.add_theme_font_size_override("font_size", 10)
	harmony_tag.visible = false
	harmony_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(harmony_tag)


func setup(data: CardData, playable: bool = true) -> void:
	card_data = data
	is_playable = playable
	_update_display()


func _update_display() -> void:
	if not card_data:
		return

	if card_bg:
		card_bg.color = card_data.get_type_color() * Color(0.4, 0.4, 0.4)

	if card_image and card_data.image_path != "":
		var tex = load(card_data.image_path)
		if tex:
			card_image.texture = tex

	if cost_label:
		# Show actual cost after dynamic reductions
		var display_cost = card_data.get_display_cost()
		# Ichika: 终章·独奏 cost -2 if 3+ harmony triggers
		if card_data.effect_id == "finale_cost_reduce" and GameManager.harmony_count >= 3:
			display_cost = maxi(display_cost - 2, 0)
		# Relic: wah_pedal free card
		if GameManager.relics.has("wah_pedal") and GameManager.wah_pedal_free:
			display_cost = 0
		# Relic: headphone (每回合第一张牌费用-1)
		elif GameManager.relics.has("headphone") and not GameManager.headphone_used:
			display_cost = maxi(display_cost - 1, 0)
		cost_label.text = str(display_cost)
		if cost_bg:
			if GameManager.relics.has("wah_pedal") and GameManager.wah_pedal_free:
				cost_bg.color = Color(0.1, 0.5, 0.2, 0.9)
			else:
				cost_bg.color = Color(0.1, 0.1, 0.2, 0.8)
		if wah_pedal_tag:
			wah_pedal_tag.visible = GameManager.relics.has("wah_pedal") and GameManager.wah_pedal_free

	if name_label:
		name_label.text = card_data.character_name

	if attr_dot:
		attr_dot.color = card_data.get_attribute_color()
		attr_dot.visible = card_data.attribute != CardData.Attribute.NONE

	if damage_label:
		if card_data.get_display_damage() > 0 or card_data.damage > 0:
			var base_dmg = card_data.get_display_damage()
			var calculated = base_dmg
			var bonus_parts: Array = []
			# Strength buff
			if GameManager.strength_buff != 0:
				calculated += GameManager.strength_buff
				bonus_parts.append(("+" if GameManager.strength_buff > 0 else "") + str(GameManager.strength_buff) + "力")
			# Relic: distortion_pedal (+3)
			if GameManager.relics.has("distortion_pedal"):
				calculated += 3
				bonus_parts.append("+3遗")
			# Relic: pitch_pipe (+2 first attack)
			if GameManager.relics.has("pitch_pipe") and not GameManager.first_attack_played_this_turn:
				calculated += 2
				bonus_parts.append("+2首攻")
			# Relic: speaker_cone (+2 hand≤3)
			if GameManager.relics.has("speaker_cone") and GameManager.hand.size() <= 3:
				calculated += 2
				bonus_parts.append("+2空手")
			# Relic: amplifier (+gold/50)
			if GameManager.relics.has("amplifier"):
				var amp_bonus = GameManager.gold / 50
				if amp_bonus > 0:
					calculated += amp_bonus
					bonus_parts.append("+" + str(amp_bonus) + "金")
			# Relic: sustain_pedal (+4 discard≥8)
			if GameManager.relics.has("sustain_pedal") and GameManager.discard_pile.size() >= 8:
				calculated += 4
				bonus_parts.append("+4弃")
			# Enemy vulnerable (+50%)
			# Note: we can't easily access battle_manager.enemy_vulnerable here,
			# so we don't show it on the card display
			calculated = maxi(calculated, 0)
			if bonus_parts.size() > 0:
				damage_label.text = "ATK:" + str(calculated) + "(" + "/".join(bonus_parts) + ")"
				damage_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
			else:
				damage_label.text = "ATK:" + str(calculated)
				damage_label.add_theme_color_override("font_color", Color(1, 0.5, 0.5))
			damage_label.visible = true
		else:
			damage_label.visible = card_data.card_type == CardData.CardType.ATTACK
			damage_label.text = ""

	if block_label:
		if card_data.get_display_block() > 0 or card_data.block > 0:
			var base_blk = card_data.get_display_block()
			var calculated = base_blk
			var bonus_parts: Array = []
			# Dexterity buff
			if GameManager.dexterity_buff != 0:
				calculated += GameManager.dexterity_buff
				bonus_parts.append(("+" if GameManager.dexterity_buff > 0 else "") + str(GameManager.dexterity_buff) + "敏")
			# Relic: reverb_plate (+3)
			if GameManager.relics.has("reverb_plate"):
				calculated += 3
				bonus_parts.append("+3遗")
			# Relic: music_stand (+2 first defense)
			if GameManager.relics.has("music_stand") and not GameManager.first_defense_played_this_turn:
				calculated += 2
				bonus_parts.append("+2首防")
			calculated = maxi(calculated, 0)
			if bonus_parts.size() > 0:
				block_label.text = "DEF:" + str(calculated) + "(" + "/".join(bonus_parts) + ")"
				block_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
			else:
				block_label.text = "DEF:" + str(calculated)
				block_label.add_theme_color_override("font_color", Color(0.5, 0.7, 1))
			block_label.visible = true
		else:
			block_label.visible = card_data.card_type == CardData.CardType.DEFENSE
			block_label.text = ""

	if effect_label:
		effect_label.text = card_data.get_display_text()

	# Power cards show type indicator
	if card_data.card_type == CardData.CardType.POWER:
		if name_label:
			name_label.text = "★" + card_data.card_name
		if card_bg:
			card_bg.color = Color(0.35, 0.15, 0.35)

	# Harmony card indicator
	if harmony_tag:
		if card_data.is_harmony_card():
			harmony_tag.text = "♪和声"
			harmony_tag.visible = true
		else:
			harmony_tag.visible = false

	modulate = Color(1, 1, 1) if is_playable else Color(0.5, 0.5, 0.5, 0.8)


func _gui_input(event: InputEvent) -> void:
	if not is_playable:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			mouse_pressed = true
			mouse_press_pos = event.global_position
			drag_offset = event.global_position - global_position
		else:
			if is_dragging:
				# Drag released — attack needs to be over enemy
				# Non-attack cards must be dragged far enough to confirm play
				var drag_dist = event.global_position.distance_to(mouse_press_pos)
				if card_data.card_type == CardData.CardType.ATTACK:
					if _is_over_enemy():
						emit_signal("card_played", card_data)
				else:
					# Defense/skill/power — only play if dragged far enough
					if drag_dist >= PLAY_DISTANCE:
						emit_signal("card_played", card_data)
				_cancel_drag()
			mouse_pressed = false

	elif event is InputEventMouseMotion and mouse_pressed:
		var dist = event.global_position.distance_to(mouse_press_pos)
		if not is_dragging and dist > DRAG_THRESHOLD:
			_start_drag()
		if is_dragging:
			# Move card with mouse (in parent coordinate space)
			var parent = get_parent()
			if parent:
				global_position = event.global_position - drag_offset
			# Only highlight enemy for attack cards
			if card_data.card_type == CardData.CardType.ATTACK:
				_update_enemy_highlight(_is_over_enemy())


func _input(event: InputEvent) -> void:
	# Catch mouse release even if outside card
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if is_dragging:
			var drag_dist = get_global_mouse_position().distance_to(mouse_press_pos)
			if card_data.card_type == CardData.CardType.ATTACK:
				if _is_over_enemy():
					emit_signal("card_played", card_data)
			else:
				if drag_dist >= PLAY_DISTANCE:
					emit_signal("card_played", card_data)
			_cancel_drag()
		mouse_pressed = false


func _start_drag() -> void:
	is_dragging = true
	drag_start_pos = position
	z_index = 100
	scale = Vector2(1.2, 1.2)
	modulate = Color(1, 1, 1, 0.85)
	_show_damage_preview()


func _cancel_drag() -> void:
	is_dragging = false
	z_index = 0
	scale = Vector2(1.0, 1.0)
	modulate = Color(1, 1, 1) if is_playable else Color(0.5, 0.5, 0.5, 0.8)
	# Animate back to original position
	var tween = create_tween()
	tween.tween_property(self, "position", drag_start_pos, 0.15)
	_hide_damage_preview()
	_update_enemy_highlight(false)


func _is_over_enemy() -> bool:
	# Check if card center is over the enemy area
	var battle_scene = get_tree().current_scene
	if not battle_scene:
		return false
	# Find enemy_container by checking children
	for child in battle_scene.get_children():
		if child is CenterContainer:
			var enemy_rect = Rect2(child.global_position, child.size)
			if enemy_rect.has_point(get_global_mouse_position()):
				return true
	return false


func _update_enemy_highlight(on: bool) -> void:
	var battle_scene = get_tree().current_scene
	if not battle_scene:
		return
	for child in battle_scene.get_children():
		if child is CenterContainer and child.get_child_count() > 0:
			var enode = child.get_child(0)
			if on:
				enode.modulate = Color(1.2, 0.8, 0.8)
			else:
				enode.modulate = Color(1, 1, 1)


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER:
		if not is_dragging:
			is_hovering = true
			scale = Vector2(1.15, 1.15)
			z_index = 10
			emit_signal("card_hovered", card_data)
	elif what == NOTIFICATION_MOUSE_EXIT:
		if not is_dragging:
			is_hovering = false
			scale = Vector2(1.0, 1.0)
			z_index = 0
			emit_signal("card_unhovered")


func _show_damage_preview() -> void:
	if not card_data:
		return
	# Only show for cards with damage potential
	if card_data.get_display_damage() <= 0 and card_data.get_harmony_damage() <= 0:
		return
	if not damage_preview_label:
		return
	# Find battle_manager from scene
	var bm = _get_battle_manager()
	if not bm:
		return
	# Determine if harmony would trigger for this card
	var is_harmony = false
	if card_data.attribute != CardData.Attribute.NONE and GameManager.last_played_attribute >= 0:
		if card_data.attribute == GameManager.last_played_attribute:
			is_harmony = true
	var result = bm.calc_attack_damage(card_data, is_harmony)
	var parts: Array = []
	if result.pierces_block:
		parts.append("穿透!")
	if result.base_damage > 0:
		var dmg_text = "造成%d伤害" % result.final_damage
		if result.vulnerable_multiplier > 1.0:
			var raw = result.base_damage + result.harmony_bonus
			if raw != result.final_damage or result.shield_absorbed > 0:
				dmg_text = "造成%d伤害(x%.1f易伤)" % [result.final_damage, result.vulnerable_multiplier]
			else:
				dmg_text = "造成%d伤害(x%.1f易伤)" % [result.final_damage, result.vulnerable_multiplier]
		if result.shield_absorbed > 0 and not result.pierces_block:
			dmg_text += "(护盾吸收%d)" % result.shield_absorbed
		parts.append(dmg_text)
	elif result.harmony_bonus > 0 and result.base_damage == 0:
		# Harmony-only damage (no base damage on the card itself)
		pass
	if result.harmony_bonus > 0:
		parts.append("+%d和声" % result.harmony_bonus)
	if parts.size() > 0:
		damage_preview_label.text = " ".join(parts)
		damage_preview_label.visible = true
		# Adjust width to fit text
		damage_preview_label.custom_minimum_size.x = 0
		damage_preview_label.size.x = 0
	else:
		damage_preview_label.visible = false


func _hide_damage_preview() -> void:
	if damage_preview_label:
		damage_preview_label.visible = false


func _get_battle_manager():
	var scene = get_tree().current_scene
	if not scene:
		return null
	for child in scene.get_children():
		if child is BattleManager:
			return child
	# Check script property
	if scene.get("battle_manager"):
		return scene.battle_manager
	return null
