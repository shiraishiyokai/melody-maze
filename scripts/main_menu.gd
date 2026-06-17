# Main menu scene.
extends Control

var character_buttons: Array = []
var start_button: Button
var selected_character: int = 1

var _characters: Array = []

# StyleBoxes for selection state
var style_unselected: StyleBoxFlat
var style_selected: StyleBoxFlat

# Character → card image + FF14 icon mapping
const CHAR_CARD = {
	1: "res://assets/cards/res001_no003_normal.png",
	2: "res://assets/cards/res010_no003_normal.png",
	17: "res://assets/cards/res017_no003_normal.png",
	20: "res://assets/cards/res020_no003_normal.png",
	16: "res://assets/cards/res016_no003_normal.png",
	14: "res://assets/cards/res014_no003_normal.png",
	13: "res://assets/cards/res013_no003_normal.png",
}
const CHAR_ICON = {
	1: "res://assets/player/PLD.png",
	2: "res://assets/player/BRD.png",
	17: "res://assets/player/SCH.png",
	20: "res://assets/player/NIN.png",
	16: "res://assets/player/SMN.png",
	14: "res://assets/player/DNC.png",
	13: "res://assets/player/DRG.png",
}


func _init() -> void:
	_characters = [
		{"id": 1, "name": "星乃一歌", "desc": "均衡攻防", "attr": "mysterious"},
		{"id": 2, "name": "白石杏", "desc": "节拍连击", "attr": "cool"},
		{"id": 17, "name": "宵崎奏", "desc": "高技能卡", "attr": "happy"},
		{"id": 20, "name": "暁山瑞希", "desc": "高闪避", "attr": "mysterious"},
		{"id": 16, "name": "神代類", "desc": "属性联动", "attr": "happy"},
		{"id": 14, "name": "鳳えむ", "desc": "经济型", "attr": "happy"},
		{"id": 13, "name": "天馬司", "desc": "高攻击", "attr": "cute"},
	]

	# Unselected: dark background + dim border
	style_unselected = StyleBoxFlat.new()
	style_unselected.bg_color = Color(0.15, 0.12, 0.25, 0.9)
	style_unselected.border_color = Color(0.35, 0.3, 0.45)
	style_unselected.set_border_width_all(2)
	style_unselected.set_corner_radius_all(4)

	# Selected: warm background + bright gold border
	style_selected = StyleBoxFlat.new()
	style_selected.bg_color = Color(0.22, 0.17, 0.12, 0.95)
	style_selected.border_color = Color(1.0, 0.85, 0.3)
	style_selected.set_border_width_all(3)
	style_selected.set_corner_radius_all(4)


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	# Background
	var bg = ColorRect.new()
	bg.color = Color(0.06, 0.05, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Title
	var title = Label.new()
	title.text = "♪ 杀币尖塔 ♪"
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 30
	title.offset_bottom = 80
	add_child(title)

	# Subtitle
	var subtitle = Label.new()
	subtitle.text = "肉鸽卡牌构筑"
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.set_anchors_preset(Control.PRESET_TOP_WIDE)
	subtitle.offset_top = 80
	subtitle.offset_bottom = 110
	add_child(subtitle)

	# Character selection panel
	var char_panel = Panel.new()
	char_panel.position = Vector2(290, 180)
	char_panel.size = Vector2(700, 320)
	char_panel.self_modulate = Color(0.12, 0.1, 0.2, 0.9)
	add_child(char_panel)

	var char_label = Label.new()
	char_label.text = "选择调律师"
	char_label.add_theme_font_size_override("font_size", 20)
	char_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	char_label.position = Vector2(310, 195)
	add_child(char_label)

	var char_grid = GridContainer.new()
	char_grid.columns = 3
	char_grid.position = Vector2(310, 230)
	char_grid.size = Vector2(660, 240)
	char_grid.add_theme_constant_override("h_separation", 10)
	char_grid.add_theme_constant_override("v_separation", 10)
	add_child(char_grid)

	for i in range(_characters.size()):
		var char_info = _characters[i]
		var char_id = int(char_info["id"])

		# Character panel (clickable)
		var panel = Panel.new()
		panel.custom_minimum_size = Vector2(200, 100)
		panel.clip_contents = true
		panel.gui_input.connect(_on_char_panel_input.bind(char_id, panel))
		_apply_panel_style(panel, char_id == selected_character)
		char_grid.add_child(panel)

		# Horizontal layout: text left, card right
		var hbox = HBoxContainer.new()
		hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		hbox.add_theme_constant_override("separation", 4)
		hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(hbox)

		# Left: text + icon
		var left_vbox = VBoxContainer.new()
		left_vbox.custom_minimum_size = Vector2(120, 0)
		left_vbox.add_theme_constant_override("separation", 2)
		left_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(left_vbox)

		var name_l = Label.new()
		name_l.text = str(char_info["name"])
		name_l.add_theme_color_override("font_color", Color(1.0, 0.9, 0.7) if char_id == selected_character else Color.WHITE)
		name_l.add_theme_font_size_override("font_size", 15)
		left_vbox.add_child(name_l)

		var desc_l = Label.new()
		desc_l.text = str(char_info["desc"])
		desc_l.add_theme_color_override("font_color", Color(0.7, 0.65, 0.8))
		desc_l.add_theme_font_size_override("font_size", 13)
		left_vbox.add_child(desc_l)

		# Attribute tag
		var attr_l = Label.new()
		attr_l.text = _get_attr_display(str(char_info["attr"]))
		attr_l.add_theme_color_override("font_color", _get_attr_color(str(char_info["attr"])))
		attr_l.add_theme_font_size_override("font_size", 12)
		left_vbox.add_child(attr_l)

		# FF14 job icon (inline under text)
		var icon_path = CHAR_ICON.get(char_id, "")
		if icon_path != "" and FileAccess.file_exists(icon_path):
			var job_tex = load(icon_path)
			if job_tex:
				var job_img = TextureRect.new()
				job_img.texture = job_tex
				job_img.custom_minimum_size = Vector2(20, 20)
				job_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				job_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				job_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
				left_vbox.add_child(job_img)

		# Right: card image
		var card_path = CHAR_CARD.get(char_id, "")
		if card_path != "" and FileAccess.file_exists(card_path):
			var card_tex = load(card_path)
			if card_tex:
				var card_img = TextureRect.new()
				card_img.texture = card_tex
				card_img.custom_minimum_size = Vector2(60, 80)
				card_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				card_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				card_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
				hbox.add_child(card_img)

		character_buttons.append(panel)

	# Start button
	start_button = Button.new()
	start_button.text = "▶ 开始冒险"
	start_button.position = Vector2(490, 520)
	start_button.size = Vector2(300, 60)
	start_button.add_theme_font_size_override("font_size", 22)
	start_button.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	start_button.pressed.connect(_on_start_pressed)
	add_child(start_button)


func _apply_panel_style(panel: Panel, is_selected: bool) -> void:
	var style = style_selected.duplicate() if is_selected else style_unselected.duplicate()
	panel.add_theme_stylebox_override("panel", style)
	panel.self_modulate = Color.WHITE  # Reset so StyleBox controls appearance


func _on_char_panel_input(event: InputEvent, char_id: int, panel: Panel) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		selected_character = char_id
		for b in character_buttons:
			_apply_panel_style(b, false)
			# Update name color
			var hbox = b.get_child(0)
			var left_vbox = hbox.get_child(0)
			var name_l = left_vbox.get_child(0) as Label
			if name_l:
				name_l.add_theme_color_override("font_color", Color.WHITE)
		_apply_panel_style(panel, true)
		# Highlight selected name
		var sel_hbox = panel.get_child(0)
		var sel_left = sel_hbox.get_child(0)
		var sel_name = sel_left.get_child(0) as Label
		if sel_name:
			sel_name.add_theme_color_override("font_color", Color(1.0, 0.9, 0.7))


func _get_attr_display(attr: String) -> String:
	match attr:
		"cute": return "♪ 可爱"
		"cool": return "♪ 帅气"
		"happy": return "♪ 快乐"
		"mysterious": return "♪ 神秘"
		"pure": return "♪ 纯真"
	return ""


func _get_attr_color(attr: String) -> Color:
	match attr:
		"cute": return Color(1.0, 0.6, 0.78)
		"cool": return Color(0.4, 0.6, 0.9)
		"happy": return Color(1.0, 0.7, 0.3)
		"mysterious": return Color(0.6, 0.3, 0.85)
		"pure": return Color(0.4, 0.85, 0.5)
	return Color.WHITE


func _on_start_pressed() -> void:
	GameManager.start_new_run(selected_character)
	GameManager.generate_map()
	get_tree().change_scene_to_file("res://scenes/map.tscn")
