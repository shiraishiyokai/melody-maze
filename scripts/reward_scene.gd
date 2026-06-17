# Reward scene — pick 1 of 3 cards after battle victory.
extends Control

var reward_cards: Array = []
var gold_earned: int = 0

const BG_COLOR = Color(0.08, 0.06, 0.15)


func _ready() -> void:
	reward_cards = CardDB.get_random_reward_cards(3)
	gold_earned = GameManager.gold_reward_pending
	GameManager.add_gold(gold_earned)
	_build_ui()


func _build_ui() -> void:
	var bg = ColorRect.new()
	bg.color = BG_COLOR
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Victory title
	var title = Label.new()
	title.text = "★ 战斗胜利！★"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 40)
	title.size = Vector2(1280, 50)
	add_child(title)

	# Gold earned
	var gold_label = Label.new()
	gold_label.text = "获得 💰 " + str(gold_earned)
	gold_label.add_theme_font_size_override("font_size", 24)
	gold_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gold_label.position = Vector2(0, 100)
	gold_label.size = Vector2(1280, 40)
	add_child(gold_label)

	# Prompt
	var prompt = Label.new()
	prompt.text = "选择一张卡牌加入卡组："
	prompt.add_theme_font_size_override("font_size", 20)
	prompt.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.position = Vector2(0, 160)
	prompt.size = Vector2(1280, 30)
	add_child(prompt)

	# Card display area
	var card_container = HBoxContainer.new()
	card_container.position = Vector2(190, 210)
	card_container.size = Vector2(900, 320)
	card_container.add_theme_constant_override("separation", 30)
	card_container.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(card_container)

	for i in range(reward_cards.size()):
		var card = reward_cards[i]
		var card_panel = _create_card_panel(card, i)
		card_container.add_child(card_panel)

	# Skip button
	var skip_btn = Button.new()
	skip_btn.text = "跳过（不选择卡牌）"
	skip_btn.position = Vector2(440, 580)
	skip_btn.size = Vector2(400, 50)
	skip_btn.add_theme_font_size_override("font_size", 20)
	skip_btn.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	skip_btn.pressed.connect(_on_skip_pressed)
	add_child(skip_btn)

	# Deck view button
	var deck_btn = Button.new()
	deck_btn.text = "查看卡组"
	deck_btn.position = Vector2(1140, 10)
	deck_btn.size = Vector2(120, 35)
	deck_btn.add_theme_font_size_override("font_size", 16)
	deck_btn.pressed.connect(_on_deck_btn)
	add_child(deck_btn)


func _create_card_panel(card: CardData, index: int) -> Panel:
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(250, 300)
	panel.self_modulate = Color(0.15, 0.12, 0.25, 0.95)

	# Card type color bar
	var type_bar = ColorRect.new()
	type_bar.position = Vector2(0, 0)
	type_bar.size = Vector2(250, 6)
	type_bar.color = card.get_type_color()
	panel.add_child(type_bar)

	# Rarity label
	var rarity = Label.new()
	rarity.text = "[" + card.get_rarity_name() + "]"
	rarity.position = Vector2(10, 12)
	rarity.add_theme_font_size_override("font_size", 14)
	rarity.add_theme_color_override("font_color", _get_rarity_color(card.rarity))
	panel.add_child(rarity)

	# Card name
	var name_l = Label.new()
	name_l.text = card.character_name + " / " + card.card_name
	name_l.position = Vector2(10, 32)
	name_l.size = Vector2(230, 24)
	name_l.add_theme_font_size_override("font_size", 16)
	name_l.add_theme_color_override("font_color", Color.WHITE)
	name_l.clip_text = true
	panel.add_child(name_l)

	# Cost
	var cost_l = Label.new()
	cost_l.text = "费用: " + str(card.cost)
	cost_l.position = Vector2(10, 60)
	cost_l.add_theme_font_size_override("font_size", 14)
	cost_l.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	panel.add_child(cost_l)

	# Attribute
	var attr_l = Label.new()
	attr_l.text = "属性: " + card.get_attribute_name()
	attr_l.position = Vector2(10, 80)
	attr_l.add_theme_font_size_override("font_size", 14)
	attr_l.add_theme_color_override("font_color", card.get_attribute_color())
	panel.add_child(attr_l)

	# Stats
	var stats_y = 105
	if card.damage > 0:
		var dmg_l = Label.new()
		dmg_l.text = "攻击: " + str(card.get_display_damage())
		dmg_l.position = Vector2(10, stats_y)
		dmg_l.add_theme_font_size_override("font_size", 16)
		dmg_l.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
		panel.add_child(dmg_l)
		stats_y += 24
	if card.block > 0:
		var blk_l = Label.new()
		blk_l.text = "护盾: " + str(card.get_display_block())
		blk_l.position = Vector2(10, stats_y)
		blk_l.add_theme_font_size_override("font_size", 16)
		blk_l.add_theme_color_override("font_color", Color(0.5, 0.7, 1.0))
		panel.add_child(blk_l)
		stats_y += 24

	# Effect text
	var eff_l = Label.new()
	eff_l.text = card.get_display_text()
	eff_l.position = Vector2(10, stats_y + 8)
	eff_l.size = Vector2(230, 60)
	eff_l.add_theme_font_size_override("font_size", 13)
	eff_l.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	eff_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(eff_l)

	# Select button
	var select_btn = Button.new()
	select_btn.text = "选择此卡"
	select_btn.position = Vector2(40, 250)
	select_btn.size = Vector2(170, 40)
	select_btn.add_theme_font_size_override("font_size", 16)
	select_btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	select_btn.pressed.connect(_on_card_selected.bind(index))
	panel.add_child(select_btn)

	return panel


func _get_rarity_color(rarity: int) -> Color:
	match rarity:
		CardData.Rarity.COMMON: return Color(0.7, 0.7, 0.7)
		CardData.Rarity.RARE: return Color(0.3, 0.6, 1.0)
		CardData.Rarity.LEGENDARY: return Color(1.0, 0.7, 0.2)
	return Color.WHITE


func _on_card_selected(index: int) -> void:
	if index < reward_cards.size():
		GameManager.add_card_to_deck(reward_cards[index])
	_go_to_map()


func _on_skip_pressed() -> void:
	_go_to_map()


func _on_deck_btn() -> void:
	DeckViewer.show_deck(GameManager.deck, self)


func _go_to_map() -> void:
	GameManager.advance_floor()
	if not GameManager.run_active:
		get_tree().change_scene_to_file("res://scenes/score_scene.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/map.tscn")