# Score scene — run summary with score breakdown.
# Built programmatically to match other scenes' style.
extends Control

var score_result: ScoreCalculator.ScoreResult
var total_score_label: Label
var breakdown_container: VBoxContainer
var stats_label: RichTextLabel
var return_button: Button
var animated_score: int = 0
var score_tween: Tween


func _ready() -> void:
	score_result = ScoreCalculator.calculate()
	_build_ui()
	_animate_score()


func _build_ui() -> void:
	# Background (same gradient style as other scenes)
	var grad = Gradient.new()
	var colors = PackedColorArray([
		Color(0.12, 0.06, 0.22),
		Color(0.06, 0.04, 0.14),
		Color(0.03, 0.02, 0.08),
	])
	var offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	grad.colors = colors
	grad.offsets = offsets
	var grad_tex = GradientTexture2D.new()
	grad_tex.gradient = grad
	grad_tex.fill = GradientTexture2D.FILL_LINEAR
	grad_tex.fill_from = Vector2(0.5, 0.0)
	grad_tex.fill_to = Vector2(0.5, 1.0)
	grad_tex.width = 1280
	grad_tex.height = 720
	var bg_rect = TextureRect.new()
	bg_rect.texture = grad_tex
	bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_rect.stretch_mode = TextureRect.STRETCH_SCALE
	bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg_rect)

	# === Title ===
	var title_label = Label.new()
	title_label.position = Vector2(0, 40)
	title_label.size = Vector2(1280, 50)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if score_result.run_won:
		title_label.text = "★ 通关成功！★"
		title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	else:
		title_label.text = "冒险结束"
		title_label.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4))
	title_label.add_theme_font_size_override("font_size", 36)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title_label)

	# === Character info strip ===
	var char_label = Label.new()
	char_label.position = Vector2(0, 95)
	char_label.size = Vector2(1280, 30)
	char_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	char_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	char_label.add_theme_font_size_override("font_size", 16)
	char_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	char_label.text = "角色: %s    到达楼层: %d/%d" % [
		score_result.character_name,
		score_result.floors_reached, 20
	]
	add_child(char_label)

	# === Total Score ===
	var score_panel = Panel.new()
	score_panel.position = Vector2(340, 135)
	score_panel.size = Vector2(600, 80)
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.1, 0.2, 0.9)
	panel_style.border_color = Color(1.0, 0.85, 0.3, 0.6)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	score_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(score_panel)

	var score_prefix = Label.new()
	score_prefix.position = Vector2(140, 0)
	score_prefix.size = Vector2(150, 80)
	score_prefix.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	score_prefix.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_prefix.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	score_prefix.add_theme_font_size_override("font_size", 32)
	score_prefix.mouse_filter = Control.MOUSE_FILTER_IGNORE
	score_prefix.text = "总分: "
	score_panel.add_child(score_prefix)

	total_score_label = Label.new()
	total_score_label.position = Vector2(300, 0)
	total_score_label.size = Vector2(280, 80)
	total_score_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	total_score_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.5))
	total_score_label.add_theme_font_size_override("font_size", 36)
	total_score_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	score_panel.add_child(total_score_label)

	# === Breakdown panel ===
	breakdown_container = VBoxContainer.new()
	breakdown_container.position = Vector2(290, 230)
	breakdown_container.size = Vector2(700, 300)
	var breakdown_panel = Panel.new()
	breakdown_panel.position = Vector2(290, 225)
	breakdown_panel.size = Vector2(700, 310)
	var bp_style = StyleBoxFlat.new()
	bp_style.bg_color = Color(0.08, 0.06, 0.15, 0.8)
	bp_style.border_color = Color(0.4, 0.3, 0.6, 0.5)
	bp_style.set_border_width_all(1)
	bp_style.set_corner_radius_all(6)
	breakdown_panel.add_theme_stylebox_override("panel", bp_style)
	add_child(breakdown_container)
	add_child(breakdown_panel)

	# Title
	var break_title = Label.new()
	break_title.position = Vector2(300, 230)
	break_title.size = Vector2(680, 30)
	break_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	break_title.add_theme_color_override("font_color", Color(0.8, 0.7, 1.0))
	break_title.add_theme_font_size_override("font_size", 18)
	break_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	break_title.text = "得分明细"
	add_child(break_title)

	_add_breakdown_rows()

	# === Stats bar ===
	stats_label = RichTextLabel.new()
	stats_label.position = Vector2(290, 550)
	stats_label.size = Vector2(700, 60)
	stats_label.bbcode_enabled = true
	stats_label.add_theme_color_override("default_color", Color(0.7, 0.7, 0.7))
	stats_label.add_theme_font_size_override("normal_font_size", 14)
	stats_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stats_label)

	_build_stats_text()

	# === Return button ===
	return_button = Button.new()
	return_button.position = Vector2(520, 630)
	return_button.size = Vector2(240, 50)
	return_button.text = "返回主菜单"
	return_button.add_theme_font_size_override("font_size", 22)
	return_button.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	return_button.add_theme_color_override("font_color_hover", Color(1.0, 0.95, 0.6))
	return_button.pressed.connect(_on_return_pressed)
	add_child(return_button)


func _add_breakdown_rows() -> void:
	var rows: Array = []
	if score_result.run_won:
		rows.append(["通关奖励", score_result.run_completion])
	rows.append(["楼层进度 (%dF)" % score_result.floors_reached, score_result.floor_points])
	rows.append(["普通击杀 (%d)" % score_result.normal_kills, score_result.normal_kill_points])
	rows.append(["精英击杀 (%d)" % score_result.elite_kills, score_result.elite_kill_points])
	rows.append(["Boss击杀 (%d)" % score_result.boss_kills, score_result.boss_kill_points])
	rows.append(["HP加成 (%d/%d)" % [score_result.final_hp, score_result.final_max_hp], score_result.hp_bonus])
	rows.append(["金币加成 (%d)" % score_result.total_gold_earned, score_result.gold_bonus])
	rows.append(["遗物加成 (%d)" % score_result.relic_count, score_result.relic_bonus])
	rows.append(["升级加成 (%d)" % score_result.upgraded_card_count, score_result.upgrade_bonus])
	rows.append(["── 总计 ──", score_result.total_score])

	var row_idx = 0
	for row_data in rows:
		var label_text: String = row_data[0]
		var points: int = row_data[1]
		var row = _make_breakdown_row(label_text, points, row_idx == rows.size() - 1)
		breakdown_container.add_child(row)
		row_idx += 1
func _make_breakdown_row(label_text: String, points: int, is_total: bool = false) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 28)

	var label = Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_total:
		label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		label.add_theme_font_size_override("font_size", 16)
	else:
		label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
		label.add_theme_font_size_override("font_size", 14)
	row.add_child(label)

	# Dotted filler (use Label with dots)
	var dots = Label.new()
	dots.text = " ··························· "
	dots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dots.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dots.add_theme_color_override("font_color", Color(0.3, 0.3, 0.4))
	dots.add_theme_font_size_override("font_size", 14)
	if is_total:
		dots.visible = false  # hide dots for total row
	row.add_child(dots)

	var value = Label.new()
	value.text = str(points)
	value.custom_minimum_size = Vector2(80, 28)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_total:
		value.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		value.add_theme_font_size_override("font_size", 16)
	else:
		value.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
		value.add_theme_font_size_override("font_size", 14)
	row.add_child(value)

	return row


func _build_stats_text() -> void:
	var lines: Array = []
	lines.append("角色: %s" % score_result.character_name)
	lines.append("楼层: %d/20" % score_result.floors_reached)
	lines.append("战斗胜利: %d" % score_result.total_battles_won)
	lines.append("最终HP: %d/%d" % [score_result.final_hp, score_result.final_max_hp])
	lines.append("总获得金币: %d" % score_result.total_gold_earned)
	lines.append("卡组大小: %d张" % score_result.deck_size)
	lines.append("遗物: %d个" % score_result.relic_count)

	var html = "[color=#888899]"
	for i in range(lines.size()):
		html += lines[i]
		if i < lines.size() - 1:
			html += "     "
	html += "[/color]"
	stats_label.text = html


func _animate_score() -> void:
	total_score_label.text = "0"
	# Animate score from 0 to final over 1.5s
	score_tween = create_tween()
	score_tween.tween_method(_score_tween_callback, 0, score_result.total_score, 1.5)

	# Animate breakdown rows appearing one by one
	var rows = breakdown_container.get_children()
	for i in range(rows.size()):
		rows[i].modulate = Color(1, 1, 1, 0)
		var delay = 0.3 + i * 0.12
		var tween = create_tween()
		# Godot 4.x: use set_process_mode + chain for delay
		tween.tween_property(rows[i], "modulate", Color(1, 1, 1, 0), delay)
		tween.tween_property(rows[i], "modulate", Color(1, 1, 1, 1), 0.15)

func _score_tween_callback(value: float) -> void:
	total_score_label.text = "%d" % roundi(value)
	animated_score = roundi(value)


func _on_return_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
