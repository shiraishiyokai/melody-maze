# Deck viewer utility — creates a popup panel to view all cards in a deck.
# Displays card images in a grid. Hovering a card shows a detail panel.
# Returns the panel reference so the caller can track and close it.
class_name DeckViewer
extends RefCounted

const MINI_CARD_W = 90
const MINI_CARD_H = 126
const MINI_IMG_SIZE = 78
const DETAIL_IMG_W = 160
const DETAIL_IMG_H = 220


static func show_deck(deck: Array, parent: Control, title_text: String = "卡组") -> Panel:
	# Full-screen overlay to block clicks on underlying UI
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.5)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 199
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(overlay)

	var panel = Panel.new()
	# Use anchors for centering — occupy 80% width, 87% height, centered
	panel.set_anchor(SIDE_LEFT, 0.1)
	panel.set_anchor(SIDE_RIGHT, 0.9)
	panel.set_anchor(SIDE_TOP, 0.05)
	panel.set_anchor(SIDE_BOTTOM, 0.92)
	panel.z_index = 200
	parent.add_child(panel)

	# Store overlay on panel metadata so we can free it together
	panel.set_meta("overlay", overlay)

	var title = Label.new()
	title.text = title_text + " (" + str(deck.size()) + "张)"
	title.position = Vector2(10, 8)
	title.size = Vector2(300, 30)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.add_theme_font_size_override("font_size", 20)
	panel.add_child(title)

	var close_btn = Button.new()
	close_btn.text = "关闭"
	close_btn.set_anchor(SIDE_RIGHT, 1.0)
	close_btn.set_anchor(SIDE_TOP, 0.0)
	close_btn.offset_left = -80
	close_btn.offset_top = 8
	close_btn.offset_right = -10
	close_btn.offset_bottom = 38
	close_btn.pressed.connect(func():
		var ov = panel.get_meta("overlay") if panel.has_meta("overlay") else null
		if ov:
			ov.queue_free()
		panel.queue_free()
	)
	panel.add_child(close_btn)

	# Click overlay to close as well
	overlay.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var ov = panel.get_meta("overlay") if panel.has_meta("overlay") else null
			if ov:
				ov.queue_free()
			panel.queue_free()
	)

	# Detail panel (hidden by default, shown on hover)
	var detail_panel = Panel.new()
	detail_panel.z_index = 300
	detail_panel.visible = false
	detail_panel.size = Vector2(480, 460)
	parent.add_child(detail_panel)
	panel.set_meta("detail_panel", detail_panel)

	var scroll = ScrollContainer.new()
	scroll.set_anchor(SIDE_LEFT, 0.0)
	scroll.set_anchor(SIDE_RIGHT, 1.0)
	scroll.set_anchor(SIDE_TOP, 0.0)
	scroll.set_anchor(SIDE_BOTTOM, 1.0)
	scroll.offset_left = 10
	scroll.offset_top = 45
	scroll.offset_right = -10
	scroll.offset_bottom = -10
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)

	var grid = GridContainer.new()
	# Calculate columns based on estimated panel width (~80% of 1280 = 1024, minus padding = ~1004)
	var est_width = int(parent.get_viewport().get_visible_rect().size.x * 0.8) - 20
	var cols = maxi(3, est_width / (MINI_CARD_W + 8))
	grid.columns = cols
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)

	for card in deck:
		var mini = _create_mini_card(card, panel, detail_panel)
		grid.add_child(mini)

	return panel


static func _create_mini_card(card: CardData, deck_panel: Panel, detail_panel: Panel) -> Control:
	var mini = Control.new()
	mini.custom_minimum_size = Vector2(MINI_CARD_W, MINI_CARD_H)
	mini.size = Vector2(MINI_CARD_W, MINI_CARD_H)

	# Background — type color dimmed
	var bg = ColorRect.new()
	bg.size = Vector2(MINI_CARD_W, MINI_CARD_H)
	bg.color = card.get_type_color() * Color(0.4, 0.4, 0.4)
	mini.add_child(bg)

	# Card image
	var img = TextureRect.new()
	img.position = Vector2(6, 6)
	img.size = Vector2(MINI_IMG_SIZE, MINI_IMG_SIZE)
	img.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if card.image_path != "" and FileAccess.file_exists(card.image_path):
		var tex = load(card.image_path)
		if tex:
			img.texture = tex
	mini.add_child(img)

	# Cost label (top-left, gold)
	var cost_bg = ColorRect.new()
	cost_bg.position = Vector2(2, 2)
	cost_bg.size = Vector2(20, 20)
	cost_bg.color = Color(0.1, 0.1, 0.2, 0.85)
	mini.add_child(cost_bg)

	var cost_l = Label.new()
	cost_l.position = Vector2(2, 2)
	cost_l.size = Vector2(20, 20)
	cost_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost_l.text = str(card.get_display_cost())
	cost_l.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	cost_l.add_theme_font_size_override("font_size", 14)
	mini.add_child(cost_l)

	# Attribute dot (top-right)
	var attr_dot = ColorRect.new()
	attr_dot.position = Vector2(MINI_CARD_W - 16, 4)
	attr_dot.size = Vector2(12, 12)
	attr_dot.color = card.get_attribute_color()
	attr_dot.visible = card.attribute != CardData.Attribute.NONE
	mini.add_child(attr_dot)

	# Card name label (bottom area)
	var name_l = Label.new()
	name_l.position = Vector2(4, MINI_IMG_SIZE + 10)
	name_l.size = Vector2(MINI_CARD_W - 8, 20)
	name_l.add_theme_color_override("font_color", Color.WHITE)
	name_l.add_theme_font_size_override("font_size", 11)
	name_l.clip_text = true
	var display_name = card.card_name
	if card.is_upgraded:
		display_name = "★" + display_name
	if card.card_type == CardData.CardType.POWER:
		display_name = "★" + display_name
		bg.color = Color(0.35, 0.15, 0.35)
	name_l.text = display_name
	mini.add_child(name_l)

	# Damage/block indicators (below name)
	var stats_y = MINI_IMG_SIZE + 30
	if card.get_display_damage() > 0 or card.damage > 0:
		var dmg_l = Label.new()
		dmg_l.position = Vector2(4, stats_y)
		dmg_l.size = Vector2(MINI_CARD_W / 2 - 4, 14)
		dmg_l.text = "ATK:" + str(card.get_display_damage())
		dmg_l.add_theme_color_override("font_color", Color(1, 0.5, 0.5))
		dmg_l.add_theme_font_size_override("font_size", 10)
		mini.add_child(dmg_l)

	if card.get_display_block() > 0 or card.block > 0:
		var blk_l = Label.new()
		blk_l.position = Vector2(MINI_CARD_W / 2 + 2, stats_y)
		blk_l.size = Vector2(MINI_CARD_W / 2 - 6, 14)
		blk_l.text = "DEF:" + str(card.get_display_block())
		blk_l.add_theme_color_override("font_color", Color(0.5, 0.7, 1))
		blk_l.add_theme_font_size_override("font_size", 10)
		mini.add_child(blk_l)

	# Harmony tag
	if card.is_harmony_card():
		var harmony_l = Label.new()
		harmony_l.position = Vector2(4, 4)
		harmony_l.size = Vector2(40, 14)
		harmony_l.text = "♪和声"
		harmony_l.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
		harmony_l.add_theme_font_size_override("font_size", 9)
		harmony_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mini.add_child(harmony_l)

	# Exhaust tag
	if card.is_exhaust():
		var exhaust_l = Label.new()
		exhaust_l.position = Vector2(MINI_CARD_W - 30, MINI_CARD_H - 14)
		exhaust_l.size = Vector2(28, 14)
		exhaust_l.text = "消耗"
		exhaust_l.add_theme_color_override("font_color", Color(0.8, 0.5, 0.3))
		exhaust_l.add_theme_font_size_override("font_size", 9)
		exhaust_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mini.add_child(exhaust_l)

	# Hover signals — show/hide detail panel
	mini.mouse_entered.connect(func():
		_show_detail(card, detail_panel, deck_panel)
	)
	mini.mouse_exited.connect(func():
		detail_panel.visible = false
	)

	return mini


static func _show_detail(card: CardData, detail_panel: Panel, deck_panel: Panel) -> void:
	# Clear previous detail children
	for child in detail_panel.get_children():
		child.queue_free()

	detail_panel.visible = true
	detail_panel.size = Vector2(480, 460)

	# Close button
	var close_btn = Button.new()
	close_btn.text = "关闭"
	close_btn.position = Vector2(400, 8)
	close_btn.size = Vector2(70, 30)
	close_btn.pressed.connect(func(): detail_panel.visible = false)
	detail_panel.add_child(close_btn)

	# Card image
	if card.image_path != "" and FileAccess.file_exists(card.image_path):
		var tex = load(card.image_path)
		if tex:
			var img = TextureRect.new()
			img.texture = tex
			img.position = Vector2(20, 45)
			img.size = Vector2(DETAIL_IMG_W, DETAIL_IMG_H)
			img.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			detail_panel.add_child(img)

	# Right side: text details
	var dx = 200
	var dy = 45

	# Card name
	var name_l = Label.new()
	name_l.text = card.card_name
	name_l.position = Vector2(dx, dy)
	name_l.size = Vector2(270, 30)
	name_l.add_theme_color_override("font_color", Color(1.0, 0.9, 0.7))
	name_l.add_theme_font_size_override("font_size", 20)
	detail_panel.add_child(name_l)

	# Character / Rarity / Attribute / Tags
	var attr_name = _get_attr_short(card.attribute)
	var rarity_name = _get_rarity_name(card.rarity)
	var type_name = _get_type_full(card.card_type)
	var tags = ""
	if card.is_harmony_card():
		tags += " ♪和声"
	if card.is_exhaust():
		tags += " 消耗"
	var meta_l = Label.new()
	meta_l.text = "%s · %s · %s%s" % [card.character_name, rarity_name, attr_name, tags]
	meta_l.position = Vector2(dx, dy + 35)
	meta_l.size = Vector2(270, 22)
	meta_l.add_theme_color_override("font_color", Color(0.7, 0.65, 0.8))
	meta_l.add_theme_font_size_override("font_size", 14)
	detail_panel.add_child(meta_l)

	# Type + Cost
	var cost_l = Label.new()
	cost_l.text = "类型: %s  费用: %d" % [type_name, card.get_display_cost()]
	cost_l.position = Vector2(dx, dy + 62)
	cost_l.size = Vector2(270, 22)
	cost_l.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	cost_l.add_theme_font_size_override("font_size", 14)
	detail_panel.add_child(cost_l)

	# Stats
	var stats_y = dy + 90
	var stats_parts: Array = []
	if card.get_display_damage() > 0 or card.damage > 0:
		stats_parts.append("攻击: " + str(card.get_display_damage()))
	if card.get_display_block() > 0 or card.block > 0:
		stats_parts.append("防御: " + str(card.get_display_block()))
	if stats_parts.size() > 0:
		var stats_l = Label.new()
		stats_l.text = "  ".join(stats_parts)
		stats_l.position = Vector2(dx, stats_y)
		stats_l.size = Vector2(270, 22)
		stats_l.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
		stats_l.add_theme_font_size_override("font_size", 15)
		detail_panel.add_child(stats_l)

	# Effect text
	var eff_y = stats_y + 30
	if card.get_display_text() != "":
		var eff_label = Label.new()
		eff_label.text = card.get_display_text()
		eff_label.position = Vector2(dx, eff_y)
		eff_label.size = Vector2(270, 80)
		eff_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
		eff_label.add_theme_font_size_override("font_size", 14)
		eff_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail_panel.add_child(eff_label)

	# Upgraded status
	if card.is_upgraded:
		var up_l = Label.new()
		up_l.text = "★ 已升级"
		up_l.position = Vector2(dx, eff_y + 85)
		up_l.size = Vector2(270, 22)
		up_l.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
		up_l.add_theme_font_size_override("font_size", 15)
		detail_panel.add_child(up_l)

	# Upgrade info
	var up_info = _get_upgrade_info(card)
	if up_info != "":
		var up_detail_y = eff_y + 110
		var up_detail_l = Label.new()
		up_detail_l.text = "升级: " + up_info
		up_detail_l.position = Vector2(dx, up_detail_y)
		up_detail_l.size = Vector2(270, 40)
		up_detail_l.add_theme_color_override("font_color", Color(0.5, 0.9, 0.6))
		up_detail_l.add_theme_font_size_override("font_size", 13)
		up_detail_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail_panel.add_child(up_detail_l)

	# Position detail panel near the deck_panel, centered on screen
	# Try to center it on the viewport
	var viewport = deck_panel.get_viewport()
	if viewport:
		var vp_size = viewport.get_visible_rect().size
		detail_panel.position = Vector2(
			(vp_size.x - detail_panel.size.x) / 2.0,
			(vp_size.y - detail_panel.size.y) / 2.0
		)


static func _get_type_full(card_type: int) -> String:
	match card_type:
		CardData.CardType.ATTACK: return "攻击"
		CardData.CardType.DEFENSE: return "防御"
		CardData.CardType.SKILL: return "技能"
		CardData.CardType.POWER: return "能力"
	return "?"


static func _get_attr_short(attr: int) -> String:
	match attr:
		CardData.Attribute.NONE: return "无"
		CardData.Attribute.CUTE: return "可爱"
		CardData.Attribute.COOL: return "帅气"
		CardData.Attribute.HAPPY: return "快乐"
		CardData.Attribute.MYSTERIOUS: return "神秘"
		CardData.Attribute.PURE: return "纯真"
	return "?"


static func _get_rarity_name(rarity: int) -> String:
	match rarity:
		CardData.Rarity.COMMON: return "普通"
		CardData.Rarity.RARE: return "稀有"
		CardData.Rarity.LEGENDARY: return "传说"
	return "普通"


static func _get_upgrade_info(card: CardData) -> String:
	var parts: Array = []
	if card.upgraded_damage > 0 and card.damage > 0:
		parts.append("伤害 %d→%d" % [card.damage, card.upgraded_damage])
	if card.upgraded_block > 0 and card.block > 0:
		parts.append("防御 %d→%d" % [card.block, card.upgraded_block])
	if card.upgraded_effect_text != "" and card.effect_text != "" and card.upgraded_effect_text != card.effect_text:
		parts.append(card.upgraded_effect_text)
	if card.upgraded_cost >= 0 and card.upgraded_cost != card.cost:
		parts.append("费用 %d→%d" % [card.cost, card.upgraded_cost])
	return " ".join(parts)