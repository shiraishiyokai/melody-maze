extends Control

var current_event: Dictionary = {}
var choice_made: bool = false
var result_texts: Array = []
var card_select_mode: bool = false
var card_select_callback: Callable = Callable()

var title_label: Label
var desc_label: Label
var choice_container: VBoxContainer
var result_container: VBoxContainer
var continue_btn: Button
var card_select_panel: Panel


func _ready() -> void:
	_build_ui()
	_load_random_event()


func _build_ui() -> void:
	# Background
	var bg = ColorRect.new()
	bg.color = Color(0.08, 0.06, 0.15)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Decorative top bar
	var top_bar = ColorRect.new()
	top_bar.color = Color(0.15, 0.1, 0.25)
	top_bar.set_anchor(SIDE_LEFT, 0.0)
	top_bar.set_anchor(SIDE_RIGHT, 1.0)
	top_bar.set_anchor(SIDE_TOP, 0.0)
	top_bar.set_anchor(SIDE_BOTTOM, 0.08)
	add_child(top_bar)

	# Scrollable content area — anchor-based positioning, no fixed pixel offsets
	var scroll = ScrollContainer.new()
	scroll.set_anchor(SIDE_LEFT, 0.05)
	scroll.set_anchor(SIDE_RIGHT, 0.95)
	scroll.set_anchor(SIDE_TOP, 0.08)
	scroll.set_anchor(SIDE_BOTTOM, 0.98)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	# Main layout container — auto-arranges vertically with proper spacing
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 12)
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(main_vbox)

	# Title
	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	title_label.add_theme_font_size_override("font_size", 26)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main_vbox.add_child(title_label)

	# Description area — autowrap, no fixed height, auto-sizes by content
	desc_label = Label.new()
	desc_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	desc_label.add_theme_font_size_override("font_size", 18)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(desc_label)

	# Separator
	var sep = HSeparator.new()
	sep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(sep)

	# Choice buttons container
	choice_container = VBoxContainer.new()
	choice_container.add_theme_constant_override("separation", 10)
	choice_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(choice_container)

	# Result area
	result_container = VBoxContainer.new()
	result_container.add_theme_constant_override("separation", 8)
	result_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(result_container)

	# Continue button
	continue_btn = Button.new()
	continue_btn.text = "继续"
	continue_btn.custom_minimum_size = Vector2(0, 50)
	continue_btn.add_theme_font_size_override("font_size", 20)
	continue_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	continue_btn.visible = false
	continue_btn.pressed.connect(_on_continue)
	main_vbox.add_child(continue_btn)

	# Card selection panel (hidden by default)
	card_select_panel = Panel.new()
	card_select_panel.set_anchor(SIDE_LEFT, 0.05)
	card_select_panel.set_anchor(SIDE_RIGHT, 0.95)
	card_select_panel.set_anchor(SIDE_TOP, 0.35)
	card_select_panel.set_anchor(SIDE_BOTTOM, 0.92)
	card_select_panel.visible = false
	card_select_panel.z_index = 10
	add_child(card_select_panel)


func _load_random_event() -> void:
	var file = FileAccess.open("res://data/events.json", FileAccess.READ)
	if not file:
		_fallback_no_event()
		return
	var json_text = file.get_as_text()
	file.close()

	var json_obj = JSON.new()
	if json_obj.parse(json_text) != OK:
		_fallback_no_event()
		return

	var events = json_obj.data
	if events.size() == 0:
		_fallback_no_event()
		return

	# Pick a random event
	current_event = events[randi() % events.size()]
	_display_event()


func _fallback_no_event() -> void:
	title_label.text = "空旷的走廊"
	desc_label.text = "这里什么也没有发生..."
	_add_choice_button("继续", [], true, "")


func _display_event() -> void:
	title_label.text = current_event.get("name", "???")
	desc_label.text = current_event.get("description", "")

	var choices = current_event.get("choices", [])
	for i in choices.size():
		var choice = choices[i]
		var enabled = _check_condition(choice)
		var effect_desc = _describe_effects(choice.get("effects", []))
		_add_choice_button(choice.get("text", "???"), choice.get("effects", []), enabled, effect_desc)


# Generate human-readable description of effect list for button display
func _describe_effects(effects: Array) -> String:
	var parts: Array = []
	for effect in effects:
		var type = effect.get("type", "")
		match type:
			"heal":
				parts.append("回复%dHP" % effect.get("value", 0))
			"damage":
				parts.append("失去%dHP" % effect.get("value", 0))
			"add_gold":
				parts.append("获得%d金币" % effect.get("value", 0))
			"spend_gold":
				parts.append("花费%d金币" % effect.get("value", 0))
			"add_card":
				var card_id = effect.get("card_id", "")
				var card = CardDB.get_card(card_id)
				var card_name = card.card_name if card else card_id
				parts.append("获得卡牌:%s" % card_name)
			"add_basic_card":
				parts.append("获得1张基础牌")
			"add_random_rare_card":
				parts.append("获得1张随机稀有牌")
			"remove_card_basic":
				parts.append("移除1张基础牌")
			"remove_card_choice":
				parts.append("选择移除1张牌")
			"upgrade_random":
				var val = effect.get("value", 1)
				parts.append("升级%d张卡牌" % val)
			"add_relic":
				var relic_id = effect.get("relic_id", "")
				var relic_data = RelicDB.get_relic(relic_id)
				var relic_name = relic_data.name if relic_data else relic_id
				parts.append("获得遗物:%s" % relic_name)
			"transform_basic":
				parts.append("变形1张基础牌")
			"random_outcome":
				var chance = effect.get("chance", 50)
				var desc_a = _describe_effects(effect.get("effects_a", []))
				var desc_b = _describe_effects(effect.get("effects_b", []))
				if desc_a == "":
					desc_a = "好运"
				if desc_b == "":
					desc_b = "厄运"
				parts.append("%d%%概率:%s/否则:%s" % [chance, desc_a, desc_b])
			"heal_or_gold":
				var threshold = effect.get("threshold", 50)
				var heal_amt = effect.get("heal", 20)
				var gold_amt = effect.get("gold", 20)
				parts.append("HP≤%d%%时回复%dHP，否则获得%d金币" % [threshold, heal_amt, gold_amt])
	if parts.size() == 0:
		return ""
	return "，".join(parts)


func _check_condition(choice: Dictionary) -> bool:
	var condition = choice.get("condition", "")
	if condition == "":
		return true

	# Parse condition
	if condition == "has_basic_card":
		return GameManager.has_basic_card()

	# gold >= N
	if condition.begins_with("gold >= "):
		var threshold = int(condition.substr(8))
		return GameManager.gold >= threshold

	# hp_percent <= N
	if condition.begins_with("hp_percent <= "):
		var threshold = int(condition.substr(15))
		var pct = int(100.0 * GameManager.player_hp / GameManager.player_max_hp)
		return pct <= threshold

	return true


func _add_choice_button(text: String, effects: Array, enabled: bool, effect_desc: String) -> void:
	var display_text = text
	if effect_desc != "":
		display_text = text + "（" + effect_desc + "）"
	# Use a custom clickable panel with autowrapping label instead of Button
	# (Godot Button does not support text autowrap — long text overflows)
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, 44)
	# Style
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.12, 0.22) if enabled else Color(0.1, 0.1, 0.12)
	style.border_color = Color(0.5, 0.45, 0.35) if enabled else Color(0.25, 0.25, 0.25)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	# Text label with autowrap
	var label = Label.new()
	label.text = display_text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 16)
	if not enabled:
		label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	else:
		label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	panel.add_child(label)
	# Click handling
	if enabled:
		panel.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				_on_choice_selected(effects)
		)
		# Hover highlight
		panel.mouse_entered.connect(func():
			style.bg_color = Color(0.22, 0.18, 0.3)
		)
		panel.mouse_exited.connect(func():
			style.bg_color = Color(0.15, 0.12, 0.22)
		)
	choice_container.add_child(panel)


func _on_choice_selected(effects: Array) -> void:
	if choice_made:
		return
	choice_made = true

	# Disable all choice panels
	for child in choice_container.get_children():
		if child is PanelContainer:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
			# Grey out the label
			for sub in child.get_children():
				if sub is Label:
					sub.add_theme_color_override("font_color", Color(0.35, 0.35, 0.35))
			# Dim the panel style
			var style = child.get_theme_stylebox("panel") as StyleBoxFlat
			if style:
				style.bg_color = Color(0.08, 0.08, 0.1)
				style.border_color = Color(0.2, 0.2, 0.2)

	# Process effects — may be async if card selection is needed
	_process_effects(effects)


func _process_effects(effects: Array) -> void:
	result_texts.clear()
	_process_effect_list(effects)


func _process_effect_list(effects: Array) -> void:
	for effect in effects:
		var type = effect.get("type", "")

		match type:
			"heal":
				_effect_heal(effect)
			"damage":
				_effect_damage(effect)
			"add_gold":
				_effect_add_gold(effect)
			"spend_gold":
				_effect_spend_gold(effect)
			"add_card":
				_effect_add_card(effect)
			"add_basic_card":
				_effect_add_basic_card(effect)
			"add_random_rare_card":
				_effect_add_random_rare_card(effect)
			"remove_card_basic":
				_effect_remove_card_basic(effect)
			"remove_card_choice":
				_effect_remove_card_choice(effect)
				return  # async — will resume after selection
			"upgrade_random":
				_effect_upgrade_random(effect)
			"add_relic":
				_effect_add_relic(effect)
			"transform_basic":
				_effect_transform_basic(effect)
			"random_outcome":
				_effect_random_outcome(effect)
			"heal_or_gold":
				_effect_heal_or_gold(effect)

	_show_results()


func _effect_heal(effect: Dictionary) -> void:
	var amount = effect.get("value", 0)
	GameManager.heal(amount)
	result_texts.append("[color=green]回复 %d HP[/color]" % amount)


func _effect_damage(effect: Dictionary) -> void:
	var amount = effect.get("value", 0)
	GameManager.take_damage(amount)
	result_texts.append("[color=red]失去 %d HP[/color]" % amount)


func _effect_add_gold(effect: Dictionary) -> void:
	var amount = effect.get("value", 0)
	GameManager.add_gold(amount)
	result_texts.append("[color=yellow]获得 %d 金币[/color]" % amount)


func _effect_spend_gold(effect: Dictionary) -> void:
	var amount = effect.get("value", 0)
	GameManager.spend_gold(amount)
	result_texts.append("[color=yellow]花费 %d 金币[/color]" % amount)


func _effect_add_card(effect: Dictionary) -> void:
	var card_id = effect.get("card_id", "")
	var card = CardDB.get_card(card_id)
	if card:
		var new_card = card.duplicate()
		GameManager.add_card_to_deck(new_card)
		result_texts.append("[color=cyan]获得卡牌: %s[/color]" % new_card.card_name)


func _effect_add_basic_card(effect: Dictionary) -> void:
	# Add a random basic card (strike or defend)
	var basic_ids = ["basic_strike", "basic_defend"]
	var chosen_id = basic_ids[randi() % basic_ids.size()]
	var card = CardDB.get_card(chosen_id)
	if card:
		var new_card = card.duplicate()
		GameManager.add_card_to_deck(new_card)
		result_texts.append("[color=cyan]获得卡牌: %s[/color]" % new_card.card_name)


func _effect_add_random_rare_card(effect: Dictionary) -> void:
	var rare_cards = CardDB.get_cards_by_rarity(CardData.Rarity.RARE)
	# Filter to current character + generic
	var pool: Array = []
	for card in rare_cards:
		if card.character_id == GameManager.selected_character_id or card.character_id == 0:
			pool.append(card)
	if pool.size() > 0:
		var chosen = pool[randi() % pool.size()]
		var new_card = chosen.duplicate()
		GameManager.add_card_to_deck(new_card)
		result_texts.append("[color=cyan]获得稀有卡牌: %s[/color]" % new_card.card_name)
	else:
		result_texts.append("没有找到可用的稀有卡牌")


func _effect_remove_card_basic(effect: Dictionary) -> void:
	var basics = GameManager.get_basic_cards()
	if basics.size() > 0:
		var chosen = basics[randi() % basics.size()]
		GameManager.remove_card_from_deck(chosen)
		result_texts.append("[color=orange]移除卡牌: %s[/color]" % chosen.card_name)
	else:
		result_texts.append("没有基础牌可以移除")


func _effect_remove_card_choice(effect: Dictionary) -> void:
	# Show card selection UI — async
	_show_card_selection()


func _effect_upgrade_random(effect: Dictionary) -> void:
	var count = effect.get("value", 1)
	var upgradable = GameManager.get_upgradable_cards()
	var upgraded_count = 0
	for i in range(mini(count, upgradable.size())):
		var idx = randi() % upgradable.size()
		var card = upgradable[idx]
		card.is_upgraded = true
		upgradable.remove_at(idx)
		upgraded_count += 1
	if upgraded_count > 0:
		result_texts.append("[color=green]升级了 %d 张卡牌[/color]" % upgraded_count)
	else:
		result_texts.append("没有可升级的卡牌")


func _effect_add_relic(effect: Dictionary) -> void:
	var relic_id = effect.get("relic_id", "")
	if relic_id != "" and not GameManager.relics.has(relic_id):
		GameManager.relics.append(relic_id)
		var relic_data = RelicDB.get_relic(relic_id)
		var rname = relic_data.name if relic_data else relic_id
		result_texts.append("[color=magenta]获得遗物: %s[/color]" % rname)
	else:
		result_texts.append("遗物已拥有或无效")


func _effect_transform_basic(effect: Dictionary) -> void:
	var basics = GameManager.get_basic_cards()
	if basics.size() > 0:
		var chosen = basics[randi() % basics.size()]
		GameManager.remove_card_from_deck(chosen)
		# Get a random character card
		var char_cards = CardDB.get_cards_by_character(GameManager.selected_character_id)
		if char_cards.size() > 0:
			var new_card = char_cards[randi() % char_cards.size()].duplicate()
			GameManager.add_card_to_deck(new_card)
			result_texts.append("[color=orange]移除 %s[/color]，[color=cyan]获得 %s[/color]" % [chosen.card_name, new_card.card_name])
		else:
			result_texts.append("[color=orange]移除 %s[/color]" % chosen.card_name)
	else:
		result_texts.append("没有基础牌可以替换")


func _effect_random_outcome(effect: Dictionary) -> void:
	var chance = effect.get("chance", 50)
	var roll = randi() % 100
	if roll < chance:
		result_texts.append("[color=yellow]运气不错！[/color]")
		_process_effect_list(effect.get("effects_a", []))
	else:
		result_texts.append("[color=red]运气不佳...[/color]")
		_process_effect_list(effect.get("effects_b", []))


func _effect_heal_or_gold(effect: Dictionary) -> void:
	var threshold = effect.get("threshold", 50)
	var pct = int(100.0 * GameManager.player_hp / GameManager.player_max_hp)
	if pct <= threshold:
		var heal_amt = effect.get("heal", 20)
		GameManager.heal(heal_amt)
		result_texts.append("[color=green]水晶感应到你的虚弱，回复 %d HP[/color]" % heal_amt)
	else:
		var gold_amt = effect.get("gold", 20)
		GameManager.add_gold(gold_amt)
		result_texts.append("[color=yellow]水晶认可你的力量，获得 %d 金币[/color]" % gold_amt)


func _show_card_selection() -> void:
	card_select_mode = true
	card_select_panel.visible = true

	# Clear previous children
	for child in card_select_panel.get_children():
		child.queue_free()

	var title = Label.new()
	title.text = "选择要移除的卡牌"
	title.position = Vector2(10, 8)
	title.size = Vector2(300, 30)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	title.add_theme_font_size_override("font_size", 18)
	card_select_panel.add_child(title)

	var scroll = ScrollContainer.new()
	scroll.set_anchor(SIDE_LEFT, 0.0)
	scroll.set_anchor(SIDE_RIGHT, 1.0)
	scroll.set_anchor(SIDE_TOP, 0.0)
	scroll.set_anchor(SIDE_BOTTOM, 1.0)
	scroll.offset_left = 10
	scroll.offset_top = 40
	scroll.offset_right = -10
	scroll.offset_bottom = -10
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card_select_panel.add_child(scroll)

	var grid = GridContainer.new()
	var est_width = int(get_viewport().get_visible_rect().size.x * 0.9) - 20
	var cols = maxi(3, est_width / 98)
	grid.columns = cols
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)

	for card in GameManager.deck:
		var mini = _create_card_select_item(card)
		grid.add_child(mini)


func _create_card_select_item(card: CardData) -> Control:
	var mini = Control.new()
	mini.custom_minimum_size = Vector2(90, 126)
	mini.size = Vector2(90, 126)

	# Background
	var bg = ColorRect.new()
	bg.size = Vector2(90, 126)
	bg.color = card.get_type_color() * Color(0.4, 0.4, 0.4)
	mini.add_child(bg)

	# Card image
	var img = TextureRect.new()
	img.position = Vector2(6, 6)
	img.size = Vector2(78, 78)
	img.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if card.image_path != "" and FileAccess.file_exists(card.image_path):
		var tex = load(card.image_path)
		if tex:
			img.texture = tex
	mini.add_child(img)

	# Cost label
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

	# Card name
	var name_l = Label.new()
	name_l.position = Vector2(4, 88)
	name_l.size = Vector2(82, 18)
	name_l.add_theme_color_override("font_color", Color.WHITE)
	name_l.add_theme_font_size_override("font_size", 11)
	name_l.clip_text = true
	var display_name = card.card_name
	if card.is_upgraded:
		display_name = "★" + display_name
	name_l.text = display_name
	mini.add_child(name_l)

	# Damage/block
	var stats_y = 106
	if card.get_display_damage() > 0:
		var dmg_l = Label.new()
		dmg_l.position = Vector2(4, stats_y)
		dmg_l.size = Vector2(42, 14)
		dmg_l.text = "ATK:" + str(card.get_display_damage())
		dmg_l.add_theme_color_override("font_color", Color(1, 0.5, 0.5))
		dmg_l.add_theme_font_size_override("font_size", 10)
		mini.add_child(dmg_l)
	if card.get_display_block() > 0:
		var blk_l = Label.new()
		blk_l.position = Vector2(48, stats_y)
		blk_l.size = Vector2(40, 14)
		blk_l.text = "DEF:" + str(card.get_display_block())
		blk_l.add_theme_color_override("font_color", Color(0.5, 0.7, 1))
		blk_l.add_theme_font_size_override("font_size", 10)
		mini.add_child(blk_l)

	# Click to select
	var btn = Button.new()
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.flat = true
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	mini.mouse_filter = Control.MOUSE_FILTER_STOP
	mini.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_on_card_selected_for_removal(card)
	)

	return mini


func _on_card_selected_for_removal(card: CardData) -> void:
	if not card_select_mode:
		return
	card_select_mode = false
	card_select_panel.visible = false

	GameManager.remove_card_from_deck(card)
	result_texts.append("[color=orange]移除卡牌: %s[/color]" % card.card_name)
	_show_results()


func _show_results() -> void:
	# Clear previous result labels
	for child in result_container.get_children():
		child.queue_free()

	# Add result text
	for text in result_texts:
		var label = RichTextLabel.new()
		label.bbcode_enabled = true
		label.fit_content = true
		label.scroll_following = false
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("normal_font_size", 18)
		label.text = text
		result_container.add_child(label)

	continue_btn.visible = true


func _on_continue() -> void:
	GameManager.advance_floor()
	if not GameManager.run_active:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/map.tscn")