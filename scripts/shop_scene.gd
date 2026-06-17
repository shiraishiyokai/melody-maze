# Shop scene — buy cards, remove a card, heal HP.
extends Control

var shop_cards: Array = []
var shop_relics: Array = []
var removal_cost: int = 75
var heal_cost: int = 15
var removal_used: bool = false
var showing_removal: bool = false

var gold_label: Label
var hp_label: Label
var card_panels: Array = []
var remove_btn: Button
var heal_btn: Button
var leave_btn: Button
var deck_btn: Button
var removal_panel: Panel

const BG_COLOR = Color(0.08, 0.06, 0.15)


func _ready() -> void:
	_generate_shop()
	_build_ui()
	GameManager.gold_changed.connect(_on_gold_changed)
	GameManager.hp_changed.connect(_on_hp_changed)


func _generate_shop() -> void:
	shop_cards = CardDB.get_shop_cards(5)
	shop_relics = RelicDB.get_shop_relics(2)


func _get_card_price(card: CardData) -> int:
	var base: int = 50
	match card.rarity:
		CardData.Rarity.COMMON: base = 50
		CardData.Rarity.RARE: base = 75
		CardData.Rarity.LEGENDARY: base = 150
	if GameManager.selected_character_id == 14:
		base = int(base * 0.8)
	return base


func _build_ui() -> void:
	var bg = ColorRect.new()
	bg.color = BG_COLOR
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Title
	var title = Label.new()
	title.text = "商店"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 20)
	title.size = Vector2(1280, 50)
	add_child(title)

	# Top bar: gold + HP
	var top = HBoxContainer.new()
	top.position = Vector2(40, 80)
	top.add_theme_constant_override("separation", 30)
	add_child(top)

	gold_label = Label.new()
	gold_label.add_theme_font_size_override("font_size", 22)
	gold_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	top.add_child(gold_label)

	hp_label = Label.new()
	hp_label.add_theme_font_size_override("font_size", 22)
	hp_label.add_theme_color_override("font_color", Color.WHITE)
	top.add_child(hp_label)

	deck_btn = Button.new()
	deck_btn.text = "查看卡组"
	deck_btn.add_theme_font_size_override("font_size", 16)
	deck_btn.pressed.connect(_on_deck_btn)
	top.add_child(deck_btn)

	# Card display
	var card_area = HBoxContainer.new()
	card_area.position = Vector2(40, 130)
	card_area.size = Vector2(1200, 280)
	card_area.add_theme_constant_override("separation", 20)
	add_child(card_area)

	card_panels.clear()
	for i in range(shop_cards.size()):
		var card = shop_cards[i]
		var panel = _create_card_panel(card, i)
		card_area.add_child(panel)
		card_panels.append(panel)

	# Relic display
	var relic_title = Label.new()
	relic_title.text = "遗物"
	relic_title.position = Vector2(40, 420)
	relic_title.size = Vector2(100, 30)
	relic_title.add_theme_font_size_override("font_size", 20)
	relic_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	add_child(relic_title)

	var relic_area = HBoxContainer.new()
	relic_area.position = Vector2(40, 450)
	relic_area.size = Vector2(1200, 80)
	relic_area.add_theme_constant_override("separation", 20)
	add_child(relic_area)

	for i in range(shop_relics.size()):
		var relic = shop_relics[i]
		var panel = _create_relic_panel(relic, i)
		relic_area.add_child(panel)

	# Action buttons
	var action_area = HBoxContainer.new()
	action_area.position = Vector2(300, 550)
	action_area.add_theme_constant_override("separation", 30)
	add_child(action_area)

	remove_btn = Button.new()
	remove_btn.text = "移除卡牌 (" + str(removal_cost) + "金)"
	remove_btn.add_theme_font_size_override("font_size", 18)
	remove_btn.add_theme_color_override("font_color", Color(0.7, 0.5, 1.0))
	remove_btn.pressed.connect(_on_remove_pressed)
	action_area.add_child(remove_btn)

	heal_btn = Button.new()
	heal_btn.text = "回血 (" + str(heal_cost) + "金 / 5HP)"
	heal_btn.add_theme_font_size_override("font_size", 18)
	heal_btn.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
	heal_btn.pressed.connect(_on_heal_pressed)
	action_area.add_child(heal_btn)

	leave_btn = Button.new()
	leave_btn.text = "离开商店"
	leave_btn.add_theme_font_size_override("font_size", 18)
	leave_btn.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	leave_btn.pressed.connect(_on_leave_pressed)
	action_area.add_child(leave_btn)

	_update_top_bar()


func _create_card_panel(card: CardData, index: int) -> Panel:
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(220, 270)
	panel.self_modulate = Color(0.15, 0.12, 0.25, 0.95)

	var price = _get_card_price(card)

	var name_l = Label.new()
	name_l.text = card.character_name + " / " + card.card_name
	name_l.position = Vector2(10, 10)
	name_l.size = Vector2(200, 22)
	name_l.add_theme_font_size_override("font_size", 14)
	name_l.add_theme_color_override("font_color", Color.WHITE)
	name_l.clip_text = true
	panel.add_child(name_l)

	var price_l = Label.new()
	price_l.text = "价格: " + str(price) + "金"
	price_l.position = Vector2(10, 35)
	price_l.add_theme_font_size_override("font_size", 14)
	price_l.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	panel.add_child(price_l)

	var type_l = Label.new()
	type_l.text = card.get_type_name() + " | " + card.get_attribute_name()
	type_l.position = Vector2(10, 55)
	type_l.add_theme_font_size_override("font_size", 13)
	type_l.add_theme_color_override("font_color", card.get_type_color())
	panel.add_child(type_l)

	var info = ""
	if card.damage > 0:
		info += "ATK:" + str(card.get_display_damage()) + " "
	if card.block > 0:
		info += "DEF:" + str(card.get_display_block()) + " "
	info += card.get_display_text()
	var info_l = Label.new()
	info_l.text = info
	info_l.position = Vector2(10, 75)
	info_l.size = Vector2(200, 80)
	info_l.add_theme_font_size_override("font_size", 12)
	info_l.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	info_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(info_l)

	var buy_btn = Button.new()
	buy_btn.text = "购买"
	buy_btn.position = Vector2(50, 180)
	buy_btn.size = Vector2(120, 35)
	buy_btn.add_theme_font_size_override("font_size", 16)
	buy_btn.pressed.connect(_on_buy_card.bind(index))
	panel.add_child(buy_btn)

	return panel


func _on_buy_card(index: int) -> void:
	if index >= shop_cards.size():
		return
	var card = shop_cards[index]
	var price = _get_card_price(card)
	if GameManager.gold < price:
		return
	GameManager.spend_gold(price)
	GameManager.add_card_to_deck(card.duplicate())
	shop_cards.remove_at(index)
	card_panels[index].queue_free()
	card_panels.remove_at(index)
	_update_top_bar()


func _on_remove_pressed() -> void:
	if removal_used:
		return
	if GameManager.gold < removal_cost:
		return
	showing_removal = true
	_show_removal_selector()


func _show_removal_selector() -> void:
	removal_panel = Panel.new()
	removal_panel.position = Vector2(200, 80)
	removal_panel.size = Vector2(880, 560)
	removal_panel.z_index = 200
	removal_panel.self_modulate = Color(0.1, 0.1, 0.2, 0.98)
	add_child(removal_panel)

	var title = Label.new()
	title.text = "选择要移除的卡牌 (" + str(removal_cost) + "金)"
	title.position = Vector2(10, 10)
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.7, 0.5, 1.0))
	removal_panel.add_child(title)

	var close_btn = Button.new()
	close_btn.text = "取消"
	close_btn.position = Vector2(800, 10)
	close_btn.size = Vector2(70, 30)
	close_btn.pressed.connect(_close_removal)
	removal_panel.add_child(close_btn)

	var scroll = ScrollContainer.new()
	scroll.position = Vector2(10, 45)
	scroll.size = Vector2(860, 500)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	removal_panel.add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(vbox)

	for card in GameManager.deck:
		var btn = Button.new()
		var info = "%s/%s %d费 %s" % [card.character_name, card.card_name, card.cost, card.get_display_text()]
		btn.text = info
		btn.add_theme_font_size_override("font_size", 14)
		var color = card.get_type_color()
		btn.add_theme_color_override("font_color", color)
		btn.custom_minimum_size = Vector2(840, 40)
		btn.pressed.connect(_on_remove_card.bind(card))
		vbox.add_child(btn)


func _on_remove_card(card: CardData) -> void:
	GameManager.spend_gold(removal_cost)
	GameManager.remove_card_from_deck(card)
	removal_used = true
	showing_removal = false
	_close_removal()
	_update_top_bar()


func _close_removal() -> void:
	if removal_panel:
		removal_panel.queue_free()
		removal_panel = null
	showing_removal = false


func _on_heal_pressed() -> void:
	if GameManager.gold < heal_cost:
		return
	if GameManager.player_hp >= GameManager.player_max_hp:
		return
	GameManager.spend_gold(heal_cost)
	GameManager.heal(5)
	_update_top_bar()


func _on_leave_pressed() -> void:
	GameManager.advance_floor()
	if not GameManager.run_active:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/map.tscn")


func _on_deck_btn() -> void:
	DeckViewer.show_deck(GameManager.deck, self)


func _create_relic_panel(relic: RelicData, index: int) -> Panel:
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(300, 70)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.12, 0.25, 0.95)
	style.border_color = relic.get_rarity_color()
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)

	var name_l = Label.new()
	name_l.text = relic.name
	name_l.position = Vector2(10, 5)
	name_l.size = Vector2(280, 20)
	name_l.add_theme_font_size_override("font_size", 16)
	name_l.add_theme_color_override("font_color", relic.get_rarity_color())
	panel.add_child(name_l)

	var desc_l = Label.new()
	desc_l.text = relic.description
	desc_l.position = Vector2(10, 25)
	desc_l.size = Vector2(280, 20)
	desc_l.add_theme_font_size_override("font_size", 13)
	desc_l.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	panel.add_child(desc_l)

	var price = relic.price
	if GameManager.relics.has("audio_interface"):
		price = int(price * 0.8)
	if GameManager.selected_character_id == 14:
		price = int(price * 0.8)

	var buy_btn = Button.new()
	buy_btn.text = str(price) + "金 购买"
	buy_btn.position = Vector2(10, 48)
	buy_btn.size = Vector2(280, 20)
	buy_btn.add_theme_font_size_override("font_size", 14)
	buy_btn.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	buy_btn.pressed.connect(_on_buy_relic.bind(index))
	if GameManager.relics.has(relic.id):
		buy_btn.disabled = true
		buy_btn.text = "已拥有"
	panel.add_child(buy_btn)

	return panel


func _on_buy_relic(index: int) -> void:
	if index < 0 or index >= shop_relics.size():
		return
	var relic = shop_relics[index]
	var price = relic.price
	if GameManager.relics.has("audio_interface"):
		price = int(price * 0.8)
	if GameManager.selected_character_id == 14:
		price = int(price * 0.8)
	if GameManager.relics.has(relic.id):
		return
	if not GameManager.spend_gold(price):
		return
	GameManager.relics.append(relic.id)
	shop_relics.remove_at(index)
	# Refresh shop UI
	get_tree().change_scene_to_file("res://scenes/shop.tscn")


func _update_top_bar() -> void:
	if gold_label:
		gold_label.text = "💰 " + str(GameManager.gold)
	if hp_label:
		hp_label.text = "HP: " + str(GameManager.player_hp) + "/" + str(GameManager.player_max_hp)


func _on_gold_changed(new_gold: int) -> void:
	if gold_label:
		gold_label.text = "💰 " + str(new_gold)

func _on_hp_changed(hp: int, max_hp: int) -> void:
	if hp_label:
		hp_label.text = "HP: " + str(hp) + "/" + str(max_hp)