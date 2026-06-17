# Relic pick scene — choose 1 relic after elite/boss battle.
extends Control

var relic_choices: Array = []
var relic_panels: Array = []

const BG_COLOR = Color(0.08, 0.06, 0.15)


func _ready() -> void:
	relic_choices = RelicDB.get_random_relic_choices(GameManager.relic_pick_count, GameManager.encounter_type)
	_build_ui()


func _build_ui() -> void:
	var bg = ColorRect.new()
	bg.color = BG_COLOR
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Title
	var title = Label.new()
	title.text = "获得遗物！"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 40)
	title.size = Vector2(1280, 50)
	add_child(title)

	# Subtitle
	var subtitle = Label.new()
	if GameManager.encounter_type == "boss":
		subtitle.text = "Boss战胜利！选择一个遗物："
	elif GameManager.encounter_type == "elite":
		subtitle.text = "精英战胜利！选择一个遗物："
	else:
		subtitle.text = "发现了一个遗物！"
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.position = Vector2(0, 100)
	subtitle.size = Vector2(1280, 30)
	add_child(subtitle)

	# Relic display area
	var relic_container = HBoxContainer.new()
	relic_container.position = Vector2(190, 160)
	relic_container.size = Vector2(900, 380)
	relic_container.add_theme_constant_override("separation", 40)
	relic_container.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(relic_container)

	for i in range(relic_choices.size()):
		var relic = relic_choices[i]
		var panel = _create_relic_panel(relic, i)
		relic_panels.append(panel)
		relic_container.add_child(panel)

	# Skip button
	var skip_btn = Button.new()
	skip_btn.text = "跳过（不选择遗物）"
	skip_btn.position = Vector2(440, 580)
	skip_btn.size = Vector2(400, 50)
	skip_btn.add_theme_font_size_override("font_size", 20)
	skip_btn.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	skip_btn.pressed.connect(_on_skip_pressed)
	add_child(skip_btn)


func _create_relic_panel(relic: RelicData, index: int) -> Panel:
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(250, 350)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.10, 0.22, 0.95)
	style.border_color = relic.get_rarity_color()
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)

	# Rarity label
	var rarity_label = Label.new()
	rarity_label.text = relic.get_rarity_name()
	rarity_label.add_theme_color_override("font_color", relic.get_rarity_color())
	rarity_label.add_theme_font_size_override("font_size", 14)
	rarity_label.position = Vector2(10, 10)
	rarity_label.size = Vector2(230, 20)
	rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(rarity_label)

	# Boss only tag
	if relic.boss_only:
		var boss_tag = Label.new()
		boss_tag.text = "★ Boss限定"
		boss_tag.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		boss_tag.add_theme_font_size_override("font_size", 12)
		boss_tag.position = Vector2(10, 30)
		boss_tag.size = Vector2(230, 20)
		boss_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		panel.add_child(boss_tag)

	# Name
	var name_label = Label.new()
	name_label.text = relic.name
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.position = Vector2(10, 55)
	name_label.size = Vector2(230, 30)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(name_label)

	# Description
	var desc_label = Label.new()
	desc_label.text = relic.description
	desc_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	desc_label.add_theme_font_size_override("font_size", 16)
	desc_label.position = Vector2(15, 100)
	desc_label.size = Vector2(220, 120)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(desc_label)

	# Price (for context)
	var price_label = Label.new()
	price_label.text = "商店价格: " + str(relic.price) + "金"
	price_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	price_label.add_theme_font_size_override("font_size", 13)
	price_label.position = Vector2(10, 240)
	price_label.size = Vector2(230, 20)
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(price_label)

	# Select button
	var select_btn = Button.new()
	select_btn.text = "选择"
	select_btn.position = Vector2(50, 280)
	select_btn.size = Vector2(150, 45)
	select_btn.add_theme_font_size_override("font_size", 18)
	select_btn.add_theme_color_override("font_color", relic.get_rarity_color())
	select_btn.pressed.connect(_on_relic_selected.bind(index))
	panel.add_child(select_btn)

	return panel


func _on_relic_selected(index: int) -> void:
	if index < 0 or index >= relic_choices.size():
		return
	var relic = relic_choices[index]
	GameManager.relics.append(relic.id)
	GameManager.relic_pick_pending = false
	get_tree().change_scene_to_file("res://scenes/reward.tscn")


func _on_skip_pressed() -> void:
	GameManager.relic_pick_pending = false
	get_tree().change_scene_to_file("res://scenes/reward.tscn")