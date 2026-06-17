# Enemy UI node — displays enemy with HP bar, intent, block overlay, buffs.
extends Control

var enemy_data: EnemyData
var current_hp: int
var max_hp: int
var current_block: int = 0
var intent_type: int = 0
var intent_value: int = 0
var shake_offset: Vector2 = Vector2.ZERO
var shake_timer: float = 0.0
var shake_intensity: float = 6.0
var base_position: Vector2 = Vector2.ZERO
var base_scale: Vector2 = Vector2.ONE
var base_modulate: Color = Color.WHITE

var enemy_image: TextureRect
var hp_bar: ProgressBar
var block_bar: ProgressBar
var hp_label: Label
var block_label: Label
var intent_icon: ColorRect
var intent_text_label: Label
var intent_value_label: Label
var name_label: Label
var buff_container: HBoxContainer

const INTENT_NAMES = {
	EnemyData.IntentType.ATTACK: "攻击",
	EnemyData.IntentType.DEFEND: "防御",
	EnemyData.IntentType.BUFF: "强化",
	EnemyData.IntentType.DEBUFF: "削弱",
	EnemyData.IntentType.EMPOWER: "蓄力",
}


func _ready() -> void:
	custom_minimum_size = Vector2(220, 280)
	size = Vector2(220, 280)
	base_position = position
	_build_ui()


func _build_ui() -> void:
	# Intent area (top) — icon + text + value
	var intent_area = HBoxContainer.new()
	intent_area.position = Vector2(20, 0)
	intent_area.size = Vector2(180, 35)
	intent_area.add_theme_constant_override("separation", 4)
	add_child(intent_area)

	intent_icon = ColorRect.new()
	intent_icon.custom_minimum_size = Vector2(28, 28)
	intent_icon.size = Vector2(28, 28)
	intent_icon.color = Color.RED
	intent_area.add_child(intent_icon)

	intent_text_label = Label.new()
	intent_text_label.add_theme_color_override("font_color", Color.WHITE)
	intent_text_label.add_theme_font_size_override("font_size", 16)
	intent_area.add_child(intent_text_label)

	intent_value_label = Label.new()
	intent_value_label.add_theme_color_override("font_color", Color.WHITE)
	intent_value_label.add_theme_font_size_override("font_size", 18)
	intent_area.add_child(intent_value_label)

	# Buff icon strip (below HP bar)
	buff_container = HBoxContainer.new()
	buff_container.position = Vector2(5, 248)
	buff_container.size = Vector2(210, 30)
	buff_container.add_theme_constant_override("separation", 3)
	add_child(buff_container)

	# Enemy image (center)
	enemy_image = TextureRect.new()
	enemy_image.position = Vector2(35, 68)
	enemy_image.size = Vector2(150, 130)
	enemy_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	enemy_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(enemy_image)

	# Name
	name_label = Label.new()
	name_label.position = Vector2(0, 198)
	name_label.size = Vector2(220, 20)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	name_label.add_theme_font_size_override("font_size", 15)
	add_child(name_label)

	# HP bar background
	var hp_bg = ColorRect.new()
	hp_bg.position = Vector2(20, 220)
	hp_bg.size = Vector2(180, 18)
	hp_bg.color = Color(0.3, 0.1, 0.1)
	add_child(hp_bg)

	# HP bar
	hp_bar = ProgressBar.new()
	hp_bar.position = Vector2(20, 220)
	hp_bar.size = Vector2(180, 18)
	hp_bar.show_percentage = false
	hp_bar.add_theme_stylebox_override("fill", _make_style(Color(0.8, 0.2, 0.2)))
	add_child(hp_bar)

	# Block overlay bar (blue, same position as HP)
	block_bar = ProgressBar.new()
	block_bar.position = Vector2(20, 220)
	block_bar.size = Vector2(180, 18)
	block_bar.show_percentage = false
	block_bar.value = 0
	block_bar.add_theme_stylebox_override("fill", _make_style(Color(0.3, 0.55, 0.9, 0.7)))
	block_bar.add_theme_stylebox_override("background", _make_style(Color.TRANSPARENT))
	add_child(block_bar)

	# HP label
	hp_label = Label.new()
	hp_label.position = Vector2(70, 219)
	hp_label.add_theme_color_override("font_color", Color.WHITE)
	hp_label.add_theme_font_size_override("font_size", 13)
	add_child(hp_label)

	# Block label (below HP bar)
	block_label = Label.new()
	block_label.position = Vector2(70, 240)
	block_label.add_theme_color_override("font_color", Color(0.4, 0.6, 0.9))
	block_label.add_theme_font_size_override("font_size", 14)
	block_label.visible = false
	add_child(block_label)


func _make_style(color: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	return style


func setup(data: EnemyData, hp: int, hp_max: int) -> void:
	enemy_data = data
	current_hp = hp
	max_hp = hp_max
	current_block = 0
	_update_display()


func update_hp(hp: int, hp_max: int) -> void:
	current_hp = hp
	max_hp = hp_max
	_update_hp_bar()


func update_intent(type: int, value: int) -> void:
	intent_type = type
	intent_value = value
	_update_intent_display()


func update_block(block: int) -> void:
	current_block = block
	if block_bar:
		if block > 0:
			block_bar.value = mini(block * 5.0, 100.0)
		else:
			block_bar.value = 0
	if block_label:
		if block > 0:
			block_label.text = "🛡" + str(block)
			block_label.visible = true
		else:
			block_label.visible = false


func update_buffs(strength_val: int, block_val: int, vulnerable_val: int) -> void:
	current_block = block_val
	if block_bar:
		if block_val > 0:
			block_bar.value = mini(block_val * 5.0, 100.0)
		else:
			block_bar.value = 0
	if block_label:
		if block_val > 0:
			block_label.text = "🛡" + str(block_val)
			block_label.visible = true
		else:
			block_label.visible = false

	# Update buff icons
	if not buff_container:
		return
	for child in buff_container.get_children():
		buff_container.remove_child(child)
		child.queue_free()

	if strength_val > 0:
		_add_enemy_buff_icon("力+" + str(strength_val), "力量：攻击额外+%d伤害" % strength_val, Color(1.0, 0.6, 0.2))
	elif strength_val < 0:
		_add_enemy_buff_icon("力" + str(strength_val), "虚弱：攻击减少%d伤害" % abs(strength_val), Color(0.5, 0.5, 0.55))

	if vulnerable_val > 0:
		_add_enemy_buff_icon("易" + str(vulnerable_val), "易伤：受到伤害+50%%，每回合减1层", Color(0.9, 0.3, 0.5))


func _add_enemy_buff_icon(text: String, tooltip: String, color: Color) -> void:
	var cell = Panel.new()
	cell.custom_minimum_size = Vector2(42, 26)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(color.r * 0.2, color.g * 0.2, color.b * 0.2, 0.85)
	style.border_color = color
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	cell.add_theme_stylebox_override("panel", style)
	cell.tooltip_text = tooltip

	var label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 11)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(label)

	buff_container.add_child(cell)


func shake() -> void:
	shake_timer = 0.4
	shake_intensity = 10.0
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.25, 1.25), 0.06)
	tween.tween_property(self, "scale", base_scale, 0.15)
	var flash_tween = create_tween()
	flash_tween.tween_property(self, "modulate", Color(1.8, 0.4, 0.4), 0.05)
	flash_tween.tween_property(self, "modulate", base_modulate, 0.2)


func _update_display() -> void:
	if enemy_image and enemy_data and enemy_data.image_path != "":
		var tex = load(enemy_data.image_path)
		if tex:
			enemy_image.texture = tex
	if name_label and enemy_data:
		name_label.text = enemy_data.enemy_name
	_update_hp_bar()
	_update_intent_display()


func _update_hp_bar() -> void:
	if hp_bar:
		hp_bar.value = float(current_hp) / float(max_hp) * 100.0 if max_hp > 0 else 0
	if hp_label:
		hp_label.text = str(current_hp) + "/" + str(max_hp)


func _update_intent_display() -> void:
	if intent_icon:
		match intent_type:
			EnemyData.IntentType.ATTACK:
				intent_icon.color = Color(0.85, 0.25, 0.25)
			EnemyData.IntentType.DEFEND:
				intent_icon.color = Color(0.25, 0.55, 0.85)
			EnemyData.IntentType.BUFF:
				intent_icon.color = Color(0.25, 0.7, 0.35)
			EnemyData.IntentType.DEBUFF:
				intent_icon.color = Color(0.8, 0.2, 0.8)
			EnemyData.IntentType.EMPOWER:
				intent_icon.color = Color(0.9, 0.5, 0.2)
	if intent_text_label:
		intent_text_label.text = INTENT_NAMES.get(intent_type, "?")
		match intent_type:
			EnemyData.IntentType.ATTACK:
				intent_text_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
			EnemyData.IntentType.DEFEND:
				intent_text_label.add_theme_color_override("font_color", Color(0.4, 0.65, 1.0))
			EnemyData.IntentType.BUFF:
				intent_text_label.add_theme_color_override("font_color", Color(0.4, 0.85, 0.5))
			EnemyData.IntentType.DEBUFF:
				intent_text_label.add_theme_color_override("font_color", Color(0.9, 0.4, 0.9))
			EnemyData.IntentType.EMPOWER:
				intent_text_label.add_theme_color_override("font_color", Color(1.0, 0.65, 0.3))
	if intent_value_label:
		if intent_type == EnemyData.IntentType.ATTACK or intent_type == EnemyData.IntentType.DEFEND:
			intent_value_label.text = str(intent_value)
			intent_value_label.visible = true
		else:
			intent_value_label.visible = false


func _process(delta: float) -> void:
	if shake_timer > 0:
		shake_timer -= delta
		shake_intensity = lerpf(shake_intensity, 0.0, 0.08)
		position = base_position + Vector2(randf_range(-shake_intensity, shake_intensity), randf_range(-shake_intensity, shake_intensity))
	else:
		if position.distance_to(base_position) > 0.5:
			position = position.lerp(base_position, 0.2)
		else:
			position = base_position