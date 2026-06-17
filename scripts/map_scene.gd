# Map scene — central hub, player selects next encounter node.
extends Control

var node_buttons: Dictionary = {}  # node_id -> Button
var line_layer: Control
var node_positions: Dictionary = {}  # node_id -> Vector2 (center of button)

# UI references
var hp_label: Label
var block_label: Label
var gold_label: Label
var floor_label: Label
var deck_btn: Button

const BG_COLOR = Color(0.08, 0.06, 0.15)
const NODE_COLORS = {
	"battle": Color(0.8, 0.3, 0.3),
	"elite": Color(0.85, 0.55, 0.2),
	"boss": Color(0.6, 0.2, 0.7),
	"shop": Color(0.9, 0.75, 0.2),
	"campfire": Color(0.6, 0.5, 0.3),
	"event": Color(0.3, 0.5, 0.8),
}
const NODE_LABELS = {
	"battle": "战斗",
	"elite": "精英",
	"boss": "Boss",
	"shop": "商店",
	"campfire": "篝火",
	"event": "事件",
}

# Lane X positions (3 lanes: left, center, right)
const LANE_X = {
	1: 640.0,       # single center
	2: [490.0, 790.0],  # two lanes
	3: [340.0, 640.0, 940.0],  # three lanes
}


# Inner class for drawing connection lines
class MapLineLayer extends Control:
	var line_data: Array = []

	func set_lines(data: Array) -> void:
		line_data = data
		queue_redraw()

	func _draw() -> void:
		for entry in line_data:
			draw_line(entry.from, entry.to, entry.color, entry.width, true)


func _ready() -> void:
	_build_ui()
	_render_map()
	GameManager.hp_changed.connect(_on_hp_changed)
	GameManager.gold_changed.connect(_on_gold_changed)
	GameManager.block_changed.connect(_on_block_changed)
	_update_top_bar()


func _build_ui() -> void:
	var grad = Gradient.new()
	grad.colors = PackedColorArray([
		Color(0.10, 0.07, 0.18),
		Color(0.06, 0.04, 0.12),
		Color(0.03, 0.02, 0.08),
	])
	grad.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
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
	add_child(bg_rect)

	var noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.025
	noise.fractal_octaves = 3
	var noise_tex = NoiseTexture2D.new()
	noise_tex.noise = noise
	noise_tex.width = 1280
	noise_tex.height = 720

	var noise_rect = TextureRect.new()
	noise_rect.texture = noise_tex
	noise_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	noise_rect.stretch_mode = TextureRect.STRETCH_SCALE
	noise_rect.modulate = Color(0.35, 0.25, 0.45, 0.12)
	noise_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(noise_rect)

	_add_bg_svg("res://assets/bg/scroll_unfurled.svg", Vector2(20, 300), Vector2(90, 120), Color(0.5, 0.4, 0.3, 0.10))
	_add_bg_svg("res://assets/bg/lyre.svg", Vector2(1150, 50), Vector2(70, 70), Color(0.5, 0.35, 0.6, 0.08))
	_add_bg_svg("res://assets/bg/stone_path.svg", Vector2(560, 600), Vector2(160, 80), Color(0.4, 0.3, 0.5, 0.10))
	_add_bg_svg("res://assets/bg/spooky_house.svg", Vector2(1050, 200), Vector2(80, 80), Color(0.5, 0.3, 0.5, 0.08))
	_add_bg_svg("res://assets/bg/musical_notes.svg", Vector2(100, 100), Vector2(50, 50), Color(0.55, 0.4, 0.65, 0.08))

	var top_bar = HBoxContainer.new()
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_bottom = 40
	top_bar.add_theme_constant_override("separation", 20)
	add_child(top_bar)

	hp_label = Label.new()
	hp_label.add_theme_color_override("font_color", Color.WHITE)
	hp_label.add_theme_font_size_override("font_size", 20)
	top_bar.add_child(hp_label)

	block_label = Label.new()
	block_label.add_theme_color_override("font_color", Color(0.4, 0.6, 0.9))
	block_label.add_theme_font_size_override("font_size", 20)
	block_label.visible = false
	top_bar.add_child(block_label)

	gold_label = Label.new()
	gold_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	gold_label.add_theme_font_size_override("font_size", 20)
	top_bar.add_child(gold_label)

	var relic_label = Label.new()
	relic_label.add_theme_color_override("font_color", Color(0.7, 0.5, 1.0))
	relic_label.add_theme_font_size_override("font_size", 20)
	relic_label.text = "遗物:" + str(GameManager.relics.size())
	top_bar.add_child(relic_label)

	floor_label = Label.new()
	floor_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	floor_label.add_theme_font_size_override("font_size", 20)
	top_bar.add_child(floor_label)

	deck_btn = Button.new()
	deck_btn.text = "查看卡组"
	deck_btn.add_theme_font_size_override("font_size", 16)
	deck_btn.pressed.connect(_on_deck_btn_pressed)
	top_bar.add_child(deck_btn)

	line_layer = MapLineLayer.new()
	line_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	line_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(line_layer)


func _render_map() -> void:
	for btn in node_buttons.values():
		btn.queue_free()
	node_buttons.clear()
	node_positions.clear()

	# Group nodes by floor
	var floors: Dictionary = {}
	for node in GameManager.map_nodes:
		var f = node.get("floor", 1)
		if not floors.has(f):
			floors[f] = []
		floors[f].append(node)

	# Floor 1 at bottom, floor 15 at top
	var map_y_top = 55.0
	var map_y_bottom = 670.0
	var floor_spacing = (map_y_bottom - map_y_top) / 19.0

	# Calculate positions: use lane if available, otherwise distribute evenly
	for floor_num in floors.keys():
		var floor_nodes = floors[floor_num]
		var y = map_y_bottom - (floor_num - 1) * floor_spacing
		var count = floor_nodes.size()
		for i in range(count):
			var node = floor_nodes[i]
			var node_id = node.get("id", "")
			var lane = node.get("lane", i)

			var x: float
			if count == 1:
				x = 640.0
			elif count == 2:
				var lanes_2 = LANE_X[2]
				var idx = mini(lane, lanes_2.size() - 1)
				x = lanes_2[idx]
			else:
				var lanes_3 = LANE_X[3]
				var idx = mini(lane, lanes_3.size() - 1)
				x = lanes_3[idx]

			node_positions[node_id] = Vector2(x, y)

	# Build connection lines
	var lines: Array = []
	for node in GameManager.map_nodes:
		var node_id = node.get("id", "")
		var from_center = node_positions.get(node_id, Vector2.ZERO)
		if from_center == Vector2.ZERO:
			continue

		for conn_id in node.get("connections", []):
			var to_center = node_positions.get(conn_id, Vector2.ZERO)
			if to_center == Vector2.ZERO:
				continue

			var from_visited = node.get("visited", false)
			var from_current = node_id == GameManager.current_node_id
			var to_visited = _is_node_visited(conn_id)
			var to_available = _is_node_available(conn_id)

			var line_color: Color
			var line_width: float = 2.0

			if from_visited and to_visited:
				line_color = Color(0.5, 0.8, 0.4, 0.7)
				line_width = 3.0
			elif from_current or (from_visited and to_available):
				line_color = Color(1.0, 0.85, 0.3, 0.9)
				line_width = 3.0
			else:
				line_color = Color(0.45, 0.4, 0.55, 0.5)
				line_width = 2.0

			lines.append({
				"from": from_center,
				"to": to_center,
				"color": line_color,
				"width": line_width
			})

	line_layer.set_lines(lines)

	# Create node buttons — ALL nodes visible from start
	for node in GameManager.map_nodes:
		var node_id = node.get("id", "")
		var node_type = node.get("type", "battle")
		var pos = node_positions.get(node_id, Vector2(640, 400))
		var is_available = node.get("available", false)
		var is_visited = node.get("visited", false)
		var is_current = node_id == GameManager.current_node_id

		var btn = Button.new()
		var label = NODE_LABELS.get(node_type, "?")
		btn.text = label + "\n" + str(node.get("floor", 1)) + "F"
		btn.custom_minimum_size = Vector2(80, 50)
		btn.position = pos - Vector2(40, 25)
		btn.add_theme_font_size_override("font_size", 14)

		if is_current:
			btn.modulate = Color(1.5, 1.0, 0.5)
			var tween = create_tween()
			tween.set_loops()
			tween.tween_property(btn, "modulate", Color(1.8, 1.2, 0.6), 0.8)
			tween.tween_property(btn, "modulate", Color(1.2, 0.8, 0.4), 0.8)
		elif is_available:
			btn.modulate = NODE_COLORS.get(node_type, Color.WHITE)
		elif is_visited:
			btn.modulate = Color(0.55, 0.55, 0.55)
		else:
			var type_color = NODE_COLORS.get(node_type, Color.WHITE)
			btn.modulate = Color(type_color.r * 0.65, type_color.g * 0.65, type_color.b * 0.65, 0.95)

		btn.disabled = not is_available
		if is_available:
			btn.pressed.connect(_on_node_pressed.bind(node_id))

		add_child(btn)
		node_buttons[node_id] = btn


func _is_node_visited(id: String) -> bool:
	for node in GameManager.map_nodes:
		if node.get("id", "") == id:
			return node.get("visited", false)
	return false


func _is_node_available(id: String) -> bool:
	for node in GameManager.map_nodes:
		if node.get("id", "") == id:
			return node.get("available", false)
	return false


func _on_node_pressed(node_id: String) -> void:
	GameManager.select_node(node_id)
	var path = GameManager.get_encounter_scene_path()
	get_tree().change_scene_to_file(path)


func _on_deck_btn_pressed() -> void:
	DeckViewer.show_deck(GameManager.deck, self)


func _update_top_bar() -> void:
	_on_hp_changed(GameManager.player_hp, GameManager.player_max_hp)
	_on_gold_changed(GameManager.gold)
	_on_block_changed(GameManager.player_block)
	if floor_label:
		floor_label.text = "层 " + str(GameManager.current_floor) + "/" + str(GameManager.max_floors)


func _on_hp_changed(hp: int, max_hp: int) -> void:
	if hp_label:
		hp_label.text = "HP: " + str(hp) + "/" + str(max_hp)

func _on_gold_changed(new_gold: int) -> void:
	if gold_label:
		gold_label.text = "💰" + str(new_gold)

func _on_block_changed(new_block: int) -> void:
	if block_label:
		if new_block > 0:
			block_label.text = "🛡 " + str(new_block)
			block_label.visible = true
		else:
			block_label.visible = false


func _add_bg_svg(path: String, pos: Vector2, size: Vector2, modulate: Color) -> void:
	if not FileAccess.file_exists(path):
		return
	var tex = load(path)
	if not tex:
		return
	var rect = TextureRect.new()
	rect.texture = tex
	rect.position = pos
	rect.size = size
	rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.modulate = modulate
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)