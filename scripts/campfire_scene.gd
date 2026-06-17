# Campfire scene — rest (heal 30% HP) or upgrade a card.
extends Control

var mode: String = ""  # "", "rest", "upgrade", "upgrading"
var upgrade_panel: Panel

var hp_label: Label
var deck_btn: Button
var result_label: Label

const BG_COLOR = Color(0.12, 0.08, 0.06)


func _ready() -> void:
	_build_ui()
	GameManager.hp_changed.connect(_on_hp_changed)
	_update_hp()


func _build_ui() -> void:
	var bg = ColorRect.new()
	bg.color = BG_COLOR
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Title
	var title = Label.new()
	title.text = "篝火"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 60)
	title.size = Vector2(1280, 50)
	add_child(title)

	# Subtitle
	var sub = Label.new()
	sub.text = "选择一项："
	sub.add_theme_font_size_override("font_size", 20)
	sub.add_theme_color_override("font_color", Color(0.7, 0.6, 0.5))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.position = Vector2(0, 130)
	sub.size = Vector2(1280, 30)
	add_child(sub)

	# HP display
	hp_label = Label.new()
	hp_label.add_theme_font_size_override("font_size", 22)
	hp_label.add_theme_color_override("font_color", Color.WHITE)
	hp_label.position = Vector2(40, 20)
	add_child(hp_label)

	deck_btn = Button.new()
	deck_btn.text = "查看卡组"
	deck_btn.position = Vector2(1140, 20)
	deck_btn.size = Vector2(120, 35)
	deck_btn.add_theme_font_size_override("font_size", 16)
	deck_btn.pressed.connect(_on_deck_btn)
	add_child(deck_btn)

	# Rest button
	var rest_btn = Button.new()
	var heal_amount = int(GameManager.player_max_hp * 0.3)
	rest_btn.text = "休息\n回复 " + str(heal_amount) + " HP"
	rest_btn.position = Vector2(340, 200)
	rest_btn.size = Vector2(250, 120)
	rest_btn.add_theme_font_size_override("font_size", 22)
	rest_btn.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
	rest_btn.pressed.connect(_on_rest_pressed)
	add_child(rest_btn)

	# Upgrade button
	var upgrade_btn = Button.new()
	upgrade_btn.text = "升级卡牌\n选择1张卡升级"
	upgrade_btn.position = Vector2(690, 200)
	upgrade_btn.size = Vector2(250, 120)
	upgrade_btn.add_theme_font_size_override("font_size", 22)
	upgrade_btn.add_theme_color_override("font_color", Color(0.5, 0.7, 1.0))
	upgrade_btn.pressed.connect(_on_upgrade_pressed)
	add_child(upgrade_btn)

	# Result label (shows after action)
	result_label = Label.new()
	result_label.add_theme_font_size_override("font_size", 22)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.position = Vector2(0, 380)
	result_label.size = Vector2(1280, 40)
	result_label.visible = false
	add_child(result_label)

	# Continue button (hidden until action taken)
	var continue_btn = Button.new()
	continue_btn.text = "继续"
	continue_btn.position = Vector2(490, 450)
	continue_btn.size = Vector2(300, 60)
	continue_btn.add_theme_font_size_override("font_size", 22)
	continue_btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	continue_btn.pressed.connect(_on_continue_pressed)
	continue_btn.name = "ContinueBtn"
	add_child(continue_btn)


func _on_rest_pressed() -> void:
	if mode != "":
		return
	var heal_amount = int(GameManager.player_max_hp * 0.3)
	if GameManager.relics.has("tuning_key"):
		heal_amount += 5
	GameManager.heal(heal_amount)
	mode = "rest"
	result_label.text = "回复了 " + str(heal_amount) + " HP！"
	result_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
	result_label.visible = true


func _on_upgrade_pressed() -> void:
	if mode != "":
		return
	mode = "upgrading"
	_show_upgrade_selector()


func _show_upgrade_selector() -> void:
	upgrade_panel = Panel.new()
	upgrade_panel.position = Vector2(200, 80)
	upgrade_panel.size = Vector2(880, 560)
	upgrade_panel.z_index = 200
	upgrade_panel.self_modulate = Color(0.1, 0.1, 0.2, 0.98)
	add_child(upgrade_panel)

	var title = Label.new()
	title.text = "选择要升级的卡牌"
	title.position = Vector2(10, 10)
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.5, 0.7, 1.0))
	upgrade_panel.add_child(title)

	var close_btn = Button.new()
	close_btn.text = "取消"
	close_btn.position = Vector2(800, 10)
	close_btn.size = Vector2(70, 30)
	close_btn.pressed.connect(_close_upgrade)
	upgrade_panel.add_child(close_btn)

	var scroll = ScrollContainer.new()
	scroll.position = Vector2(10, 45)
	scroll.size = Vector2(860, 500)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	upgrade_panel.add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(vbox)

	for card in GameManager.deck:
		if card.is_upgraded:
			continue
		var btn = Button.new()
		var cur_cost = card.get_display_cost()
		var upg_cost = card.upgraded_cost if card.upgraded_cost >= 0 else card.cost
		var cur_text = card.get_display_text()
		var upg_text = card.upgraded_effect_text
		var info = "%s/%s %d费: %s" % [card.character_name, card.card_name, cur_cost, cur_text]
		if cur_text != upg_text:
			var cost_part = " → %d费: " % upg_cost if upg_cost != cur_cost else " → "
			info += cost_part + upg_text
		elif upg_cost != cur_cost:
			info += " → %d费" % upg_cost
		btn.text = info
		btn.add_theme_font_size_override("font_size", 13)
		btn.add_theme_color_override("font_color", card.get_type_color())
		btn.custom_minimum_size = Vector2(840, 40)
		btn.pressed.connect(_on_upgrade_card.bind(card))
		vbox.add_child(btn)


func _on_upgrade_card(card: CardData) -> void:
	card.is_upgraded = true
	GameManager.upgraded_cards_count += 1
	mode = "upgrade"
	result_label.text = card.character_name + "/" + card.card_name + " 已升级！"
	result_label.add_theme_color_override("font_color", Color(0.5, 0.7, 1.0))
	result_label.visible = true
	_close_upgrade()


func _close_upgrade() -> void:
	if upgrade_panel:
		upgrade_panel.queue_free()
		upgrade_panel = null
	if mode == "upgrading":
		mode = ""


func _on_continue_pressed() -> void:
	if mode == "" or mode == "upgrading":
		return
	GameManager.advance_floor()
	if not GameManager.run_active:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/map.tscn")


func _on_deck_btn() -> void:
	DeckViewer.show_deck(GameManager.deck, self)


func _update_hp() -> void:
	if hp_label:
		hp_label.text = "HP: " + str(GameManager.player_hp) + "/" + str(GameManager.player_max_hp)

func _on_hp_changed(hp: int, max_hp: int) -> void:
	_update_hp()