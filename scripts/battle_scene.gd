# Battle scene — main gameplay scene for combat.
extends Control

var battle_manager: BattleManager
var card_nodes: Array = []
var enemy_node: Control

var deck_viewer_panel: Panel = null

	# UI references
var hp_bar: ProgressBar
var hp_label: Label
var block_bar: ProgressBar
var energy_label: Label
var gold_label: Label
var floor_label: Label
var hand_container: HBoxContainer
var end_turn_button: Button
var battle_log: RichTextLabel
var harmony_label: Label
var enemy_container: CenterContainer
var player_icon: TextureRect
var player_node: Control
var player_hp_bar: ProgressBar
var player_block_bar: ProgressBar
var player_hp_label: Label
var player_buff_container: HBoxContainer
var help_button: Button
var help_panel: Panel
var draw_pile_btn: Button
var discard_pile_btn: Button
var deck_view_btn: Button

# Card detail tooltip
var card_detail_panel: Panel
var card_detail_image: TextureRect
var card_detail_name: Label
var card_detail_info: Label
var card_detail_effect: Label

# Combat effect layers
var screen_flash: ColorRect
var player_shake_timer: float = 0.0
var player_base_pos: Vector2 = Vector2.ZERO

# Colors
const BG_COLOR = Color(0.08, 0.06, 0.15)
const PANEL_COLOR = Color(0.12, 0.1, 0.2, 0.9)

# Character -> FF14 job icon mapping
const CHAR_ICONS = {
	1: "res://assets/player/PLD.png",
	2: "res://assets/player/BRD.png",
	17: "res://assets/player/SCH.png",
	20: "res://assets/player/NIN.png",
	16: "res://assets/player/SMN.png",
	14: "res://assets/player/DNC.png",
	13: "res://assets/player/DRG.png",
}


func _ready() -> void:
	battle_manager = BattleManager.new()
	add_child(battle_manager)
	battle_manager.enemy_hp_changed.connect(_on_enemy_hp_changed)
	battle_manager.enemy_block_changed.connect(_on_enemy_block_changed)
	battle_manager.enemy_intent_changed.connect(_on_enemy_intent_changed)
	battle_manager.enemy_buff_changed.connect(_on_enemy_buff_changed)
	battle_manager.player_attacked_enemy.connect(_on_player_attacked)
	battle_manager.enemy_attacked_player.connect(_on_enemy_attacked)
	battle_manager.harmony_triggered.connect(_on_harmony_triggered)
	battle_manager.shake_screen.connect(_on_shake_screen)
	battle_manager.damage_popup.connect(_on_damage_popup)
	battle_manager.block_popup.connect(_on_block_popup)
	battle_manager.enemy_damaged.connect(_on_enemy_damaged)
	battle_manager.player_debuffed.connect(_on_player_debuffed)
	battle_manager.harmony_bonus_damage.connect(_on_harmony_bonus_damage)
	battle_manager.skill_log.connect(_on_skill_log)
	battle_manager.battle_over.connect(_on_battle_over)

	_build_ui()

	GameManager.hp_changed.connect(_on_hp_changed)
	GameManager.gold_changed.connect(_on_gold_changed)
	GameManager.block_changed.connect(_on_block_changed)
	GameManager.energy_changed.connect(_on_energy_changed)
	GameManager.turn_started.connect(_on_turn_started)
	GameManager.turn_ended.connect(_on_turn_ended)

	var enemy_id = GameManager.next_enemy_id
	if enemy_id == "":
		enemy_id = "noise_slime"
	var enemy = EnemyDB.get_enemy(enemy_id)
	if enemy:
		start_battle(enemy)


func start_battle(enemy_data: EnemyData) -> void:
	battle_manager.setup(enemy_data)
	if enemy_node:
		enemy_node.setup(enemy_data, battle_manager.enemy_hp, battle_manager.enemy_max_hp)
		enemy_node.update_intent(battle_manager.current_intent_type, battle_manager.current_intent_value)
	GameManager.start_battle([enemy_data])
	_update_all_ui()
	_log("战斗开始！对手: " + enemy_data.enemy_name)


func _build_ui() -> void:
	# === Background: gradient + noise + SVG decorations ===
	_build_background()

	# Screen flash overlay
	screen_flash = ColorRect.new()
	screen_flash.color = Color.TRANSPARENT
	screen_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(screen_flash)

	# Top bar: Energy, Gold, Floor
	var top_bar = HBoxContainer.new()
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_bottom = 35
	top_bar.add_theme_constant_override("separation", 20)
	add_child(top_bar)

	energy_label = Label.new()
	energy_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	energy_label.add_theme_font_size_override("font_size", 24)
	top_bar.add_child(energy_label)

	gold_label = Label.new()
	gold_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	gold_label.add_theme_font_size_override("font_size", 20)
	top_bar.add_child(gold_label)

	floor_label = Label.new()
	floor_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	floor_label.add_theme_font_size_override("font_size", 20)
	top_bar.add_child(floor_label)

	# ===== LEFT: Player area =====
	player_node = Control.new()
	player_node.position = Vector2(50, 120)
	player_node.size = Vector2(280, 350)
	player_base_pos = player_node.position
	add_child(player_node)

	# Player icon (FF14 job)
	player_icon = TextureRect.new()
	player_icon.position = Vector2(30, 30)
	player_icon.size = Vector2(180, 180)
	player_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	player_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	player_icon.modulate = Color(1, 1, 1, 0.9)
	var icon_path = CHAR_ICONS.get(GameManager.selected_character_id, "")
	if icon_path != "" and FileAccess.file_exists(icon_path):
		player_icon.texture = load(icon_path)
	player_node.add_child(player_icon)

	# Player HP bar (red background + green fill)
	var player_hp_bg = ColorRect.new()
	player_hp_bg.position = Vector2(10, 225)
	player_hp_bg.size = Vector2(260, 22)
	player_hp_bg.color = Color(0.3, 0.1, 0.1)
	player_node.add_child(player_hp_bg)

	player_hp_bar = ProgressBar.new()
	player_hp_bar.position = Vector2(10, 225)
	player_hp_bar.size = Vector2(260, 22)
	player_hp_bar.show_percentage = false
	player_hp_bar.add_theme_stylebox_override("fill", _make_style(Color(0.2, 0.7, 0.2)))
	player_node.add_child(player_hp_bar)

	# Block overlay bar (blue, on top of HP bar)
	player_block_bar = ProgressBar.new()
	player_block_bar.position = Vector2(10, 225)
	player_block_bar.size = Vector2(260, 22)
	player_block_bar.show_percentage = false
	player_block_bar.value = 0
	player_block_bar.add_theme_stylebox_override("fill", _make_style(Color(0.3, 0.55, 0.9, 0.7)))
	player_block_bar.add_theme_stylebox_override("background", _make_style(Color.TRANSPARENT))
	player_node.add_child(player_block_bar)

	player_hp_label = Label.new()
	player_hp_label.position = Vector2(80, 224)
	player_hp_label.add_theme_color_override("font_color", Color.WHITE)
	player_hp_label.add_theme_font_size_override("font_size", 14)
	player_node.add_child(player_hp_label)

	# Player buff icon strip
	player_buff_container = HBoxContainer.new()
	player_buff_container.position = Vector2(10, 252)
	player_buff_container.size = Vector2(260, 70)
	player_buff_container.add_theme_constant_override("separation", 4)
	player_node.add_child(player_buff_container)

	# ===== RIGHT: Enemy area =====
	enemy_container = CenterContainer.new()
	enemy_container.position = Vector2(680, 60)
	enemy_container.size = Vector2(500, 380)
	add_child(enemy_container)

	enemy_node = _create_enemy_node()
	enemy_container.add_child(enemy_node)

	# ===== CENTER: Harmony indicator =====
	harmony_label = Label.new()
	harmony_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	harmony_label.add_theme_font_size_override("font_size", 18)
	harmony_label.visible = false
	harmony_label.position = Vector2(540, 350)
	add_child(harmony_label)

	# Battle log
	battle_log = RichTextLabel.new()
	battle_log.custom_minimum_size = Vector2(260, 200)
	battle_log.position = Vector2(1010, 50)
	battle_log.size = Vector2(260, 200)
	battle_log.bbcode_enabled = true
	battle_log.add_theme_color_override("default_color", Color(0.8, 0.8, 0.8))
	battle_log.add_theme_font_size_override("normal_font_size", 13)
	add_child(battle_log)

	# Help button (?)
	help_button = Button.new()
	help_button.text = "?"
	help_button.position = Vector2(1220, 10)
	help_button.size = Vector2(40, 35)
	help_button.add_theme_font_size_override("font_size", 20)
	help_button.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	help_button.pressed.connect(_toggle_help_panel)
	add_child(help_button)

	# ===== BOTTOM: Hand area =====
	var bottom_panel = Panel.new()
	bottom_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_panel.offset_top = -180
	bottom_panel.self_modulate = PANEL_COLOR
	add_child(bottom_panel)

	hand_container = HBoxContainer.new()
	hand_container.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hand_container.offset_top = -170
	hand_container.offset_bottom = -50
	hand_container.add_theme_constant_override("separation", 8)
	hand_container.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(hand_container)

	# Pile info + end turn row
	draw_pile_btn = Button.new()
	draw_pile_btn.text = "抽牌:0"
	draw_pile_btn.position = Vector2(30, 520)
	draw_pile_btn.size = Vector2(110, 35)
	draw_pile_btn.add_theme_font_size_override("font_size", 15)
	draw_pile_btn.add_theme_color_override("font_color", Color(0.6, 0.65, 0.8))
	draw_pile_btn.pressed.connect(func(): _open_deck_viewer(GameManager.draw_pile, "抽牌堆"))
	add_child(draw_pile_btn)

	discard_pile_btn = Button.new()
	discard_pile_btn.text = "弃牌:0"
	discard_pile_btn.position = Vector2(150, 520)
	discard_pile_btn.size = Vector2(110, 35)
	discard_pile_btn.add_theme_font_size_override("font_size", 15)
	discard_pile_btn.add_theme_color_override("font_color", Color(0.7, 0.6, 0.6))
	discard_pile_btn.pressed.connect(func(): _open_deck_viewer(GameManager.discard_pile, "弃牌堆"))
	add_child(discard_pile_btn)

	deck_view_btn = Button.new()
	deck_view_btn.text = "卡组"
	deck_view_btn.position = Vector2(270, 520)
	deck_view_btn.size = Vector2(70, 35)
	deck_view_btn.add_theme_font_size_override("font_size", 15)
	deck_view_btn.pressed.connect(func(): _open_deck_viewer(GameManager.deck))
	add_child(deck_view_btn)

	end_turn_button = Button.new()
	end_turn_button.text = "结束回合"
	end_turn_button.position = Vector2(1100, 520)
	end_turn_button.size = Vector2(140, 50)
	end_turn_button.add_theme_font_size_override("font_size", 18)
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	add_child(end_turn_button)

	# ===== Relic bar (top-left, below top bar) =====
	var relic_bar = HBoxContainer.new()
	relic_bar.position = Vector2(10, 38)
	relic_bar.size = Vector2(600, 40)
	relic_bar.alignment = BoxContainer.ALIGNMENT_BEGIN
	relic_bar.add_theme_constant_override("separation", 4)
	add_child(relic_bar)
	_refresh_relic_bar(relic_bar)

	# ===== Card detail tooltip =====
	_build_card_detail_panel()


func _build_card_detail_panel() -> void:
	card_detail_panel = Panel.new()
	card_detail_panel.size = Vector2(300, 380)
	card_detail_panel.visible = false
	card_detail_panel.z_index = 200
	card_detail_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.1, 0.22, 0.97)
	style.border_color = Color(1.0, 0.85, 0.3, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	card_detail_panel.add_theme_stylebox_override("panel", style)
	add_child(card_detail_panel)

	# Card image (top)
	card_detail_image = TextureRect.new()
	card_detail_image.position = Vector2(10, 10)
	card_detail_image.size = Vector2(120, 120)
	card_detail_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card_detail_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	card_detail_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_detail_panel.add_child(card_detail_image)

	# Card name (top-right of image)
	card_detail_name = Label.new()
	card_detail_name.position = Vector2(140, 10)
	card_detail_name.size = Vector2(150, 28)
	card_detail_name.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	card_detail_name.add_theme_font_size_override("font_size", 18)
	card_detail_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_detail_panel.add_child(card_detail_name)

	# Info line: type / attribute / rarity / cost (below name)
	card_detail_info = Label.new()
	card_detail_info.position = Vector2(140, 40)
	card_detail_info.size = Vector2(150, 80)
	card_detail_info.add_theme_color_override("font_color", Color(0.75, 0.75, 0.85))
	card_detail_info.add_theme_font_size_override("font_size", 13)
	card_detail_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_detail_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_detail_panel.add_child(card_detail_info)

	# Effect text (full, below image)
	card_detail_effect = Label.new()
	card_detail_effect.position = Vector2(10, 140)
	card_detail_effect.size = Vector2(280, 230)
	card_detail_effect.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	card_detail_effect.add_theme_font_size_override("font_size", 15)
	card_detail_effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_detail_effect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_detail_panel.add_child(card_detail_effect)


func _show_card_detail(card_data: CardData) -> void:
	if not card_data or not card_detail_panel:
		return

	# Image
	if card_data.image_path != "" and FileAccess.file_exists(card_data.image_path):
		var tex = load(card_data.image_path)
		if tex:
			card_detail_image.texture = tex
			card_detail_image.visible = true
		else:
			card_detail_image.visible = false
	else:
		card_detail_image.visible = false

	# Name
	card_detail_name.text = card_data.card_name

	# Info: type / attribute / rarity / cost / stats
	var info_parts: Array = []
	info_parts.append(card_data.get_type_name())
	if card_data.attribute != CardData.Attribute.NONE:
		info_parts.append(_attr_name(card_data.attribute))
	info_parts.append(card_data.get_rarity_name())
	# Show actual cost after relic reductions
	var display_cost = card_data.cost
	if GameManager.relics.has("wah_pedal") and GameManager.wah_pedal_free:
		display_cost = 0
	elif GameManager.relics.has("headphone") and not GameManager.first_card_played_this_turn:
		display_cost = maxi(display_cost - 1, 0)
	info_parts.append(str(display_cost) + "费")
	if card_data.damage > 0:
		var calc_dmg = card_data.get_display_damage() + GameManager.strength_buff
		if GameManager.relics.has("distortion_pedal"):
			calc_dmg += 3
		if GameManager.relics.has("pitch_pipe") and not GameManager.first_attack_played_this_turn:
			calc_dmg += 2
		if GameManager.relics.has("speaker_cone") and GameManager.hand.size() <= 3:
			calc_dmg += 2
		if GameManager.relics.has("amplifier"):
			calc_dmg += GameManager.gold / 50
		if GameManager.relics.has("sustain_pedal") and GameManager.discard_pile.size() >= 8:
			calc_dmg += 4
		calc_dmg = maxi(calc_dmg, 0)
		info_parts.append("攻击:" + str(calc_dmg))
	if card_data.block > 0:
		var calc_blk = card_data.get_display_block() + GameManager.dexterity_buff
		if GameManager.relics.has("reverb_plate"):
			calc_blk += 3
		if GameManager.relics.has("music_stand") and not GameManager.first_defense_played_this_turn:
			calc_blk += 2
		calc_blk = maxi(calc_blk, 0)
		info_parts.append("护盾:" + str(calc_blk))
	if card_data.is_upgraded:
		info_parts.append("已升级")
	if card_data.is_harmony_card():
		info_parts.append("♪和声")
	if card_data.is_exhaust():
		info_parts.append("消耗")
	card_detail_info.text = "  ".join(info_parts)

	# Effect text
	var effect_text = card_data.get_display_text()
	if card_data.is_upgraded and card_data.upgraded_effect_text != "":
		effect_text += "\n[升级] " + card_data.upgraded_effect_text
	card_detail_effect.text = effect_text

	# Position: near the mouse, keep within screen
	var mouse_pos = get_global_mouse_position()
	var panel_x = mouse_pos.x + 20
	var panel_y = mouse_pos.y - 190
	if panel_x + 300 > 1280:
		panel_x = mouse_pos.x - 320
	if panel_y < 10:
		panel_y = 10
	if panel_y + 380 > 710:
		panel_y = 710 - 380
	card_detail_panel.position = Vector2(panel_x, panel_y)
	card_detail_panel.visible = true


func _hide_card_detail() -> void:
	if card_detail_panel:
		card_detail_panel.visible = false


func _attr_name(attr: int) -> String:
	match attr:
		CardData.Attribute.NONE: return "无"
		CardData.Attribute.CUTE: return "可爱"
		CardData.Attribute.COOL: return "帅气"
		CardData.Attribute.HAPPY: return "快乐"
		CardData.Attribute.MYSTERIOUS: return "神秘"
		CardData.Attribute.PURE: return "纯真"
	return ""


func _make_style(color: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	return style


func _build_background() -> void:
	# Layer 1: Gradient base
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

	# Layer 2: Noise texture for stone/depth feel
	var noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.02
	noise.fractal_octaves = 4
	var noise_tex = NoiseTexture2D.new()
	noise_tex.noise = noise
	noise_tex.width = 1280
	noise_tex.height = 720
	noise_tex.as_normal_map = false

	var noise_rect = TextureRect.new()
	noise_rect.texture = noise_tex
	noise_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	noise_rect.stretch_mode = TextureRect.STRETCH_SCALE
	noise_rect.modulate = Color(0.4, 0.25, 0.5, 0.15)
	noise_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(noise_rect)

	# Layer 3: Vignette (darker edges)
	var vignette_grad = Gradient.new()
	vignette_grad.colors = PackedColorArray([
		Color(0, 0, 0, 0.5),
		Color(0, 0, 0, 0.0),
		Color(0, 0, 0, 0.0),
		Color(0, 0, 0, 0.6),
	])
	vignette_grad.offsets = PackedFloat32Array([0.0, 0.3, 0.7, 1.0])
	var vig_tex = GradientTexture2D.new()
	vig_tex.gradient = vignette_grad
	vig_tex.fill = GradientTexture2D.FILL_LINEAR
	vig_tex.fill_from = Vector2(0.5, 0.0)
	vig_tex.fill_to = Vector2(0.5, 1.0)
	vig_tex.width = 1280
	vig_tex.height = 720

	var vig_rect = TextureRect.new()
	vig_rect.texture = vig_tex
	vig_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig_rect.stretch_mode = TextureRect.STRETCH_SCALE
	vig_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vig_rect)

	# Layer 4: SVG decorative elements
	_add_bg_svg("res://assets/bg/pillars.svg", Vector2(0, 80), Vector2(130, 430), Color(0.5, 0.35, 0.6, 0.12))
	_add_bg_svg("res://assets/bg/pillars.svg", Vector2(1150, 80), Vector2(130, 430), Color(0.5, 0.35, 0.6, 0.12))
	_add_bg_svg("res://assets/bg/stone_wall.svg", Vector2(400, 0), Vector2(480, 180), Color(0.45, 0.3, 0.55, 0.08))
	_add_bg_svg("res://assets/bg/chains.svg", Vector2(200, 20), Vector2(80, 120), Color(0.6, 0.4, 0.7, 0.10))
	_add_bg_svg("res://assets/bg/chains.svg", Vector2(1000, 30), Vector2(70, 100), Color(0.6, 0.4, 0.7, 0.10))
	_add_bg_svg("res://assets/bg/cave.svg", Vector2(550, 360), Vector2(110, 110), Color(0.5, 0.35, 0.45, 0.06))
	_add_bg_svg("res://assets/bg/broken_shield.svg", Vector2(500, 250), Vector2(70, 70), Color(0.45, 0.3, 0.4, 0.06))
	_add_bg_svg("res://assets/bg/treble_clef.svg", Vector2(350, 420), Vector2(60, 60), Color(0.6, 0.45, 0.7, 0.10))
	_add_bg_svg("res://assets/bg/bass_clef.svg", Vector2(900, 450), Vector2(50, 50), Color(0.6, 0.45, 0.7, 0.10))
	_add_bg_svg("res://assets/bg/musical_notes.svg", Vector2(150, 430), Vector2(55, 55), Color(0.55, 0.4, 0.65, 0.08))
	_add_bg_svg("res://assets/bg/musical_notes.svg", Vector2(1100, 400), Vector2(50, 50), Color(0.55, 0.4, 0.65, 0.08))

	# Layer 5: Subtle floor line
	var floor_line = ColorRect.new()
	floor_line.color = Color(0.3, 0.2, 0.4, 0.25)
	floor_line.position = Vector2(0, 490)
	floor_line.size = Vector2(1280, 2)
	add_child(floor_line)


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


func _create_enemy_node() -> Control:
	var node = Control.new()
	node.set_script(load("res://scripts/enemy_node.gd"))
	node.custom_minimum_size = Vector2(200, 250)
	return node


func _update_all_ui() -> void:
	_on_hp_changed(GameManager.player_hp, GameManager.player_max_hp)
	_on_gold_changed(GameManager.gold)
	_on_block_changed(GameManager.player_block)
	_on_energy_changed(GameManager.energy, GameManager.max_energy)
	_update_floor_display()
	_update_hand_display()
	_update_pile_display()
	_update_player_buff_display()
	if enemy_node and battle_manager.enemy_data:
		enemy_node.update_hp(battle_manager.enemy_hp, battle_manager.enemy_max_hp)
		enemy_node.update_intent(battle_manager.current_intent_type, battle_manager.current_intent_value)
		enemy_node.update_buffs(battle_manager.enemy_strength, battle_manager.enemy_block, battle_manager.enemy_vulnerable)


func _update_hand_display() -> void:
	for child in hand_container.get_children():
		child.queue_free()
	card_nodes.clear()
	_update_pile_display()

	for card_data in GameManager.hand:
		var card_node = Control.new()
		card_node.set_script(load("res://scripts/card_node.gd"))
		card_node.custom_minimum_size = Vector2(100, 140)
		hand_container.add_child(card_node)
		card_node.setup(card_data, card_data.cost <= GameManager.energy)
		card_node.card_played.connect(_on_card_clicked)
		card_node.card_hovered.connect(_on_card_hovered)
		card_node.card_unhovered.connect(_on_card_unhovered)
		card_nodes.append(card_node)


func _update_floor_display() -> void:
	if floor_label:
		floor_label.text = "层 " + str(GameManager.current_floor) + "/" + str(GameManager.max_floors)


func _update_pile_display() -> void:
	if draw_pile_btn:
		draw_pile_btn.text = "抽牌:" + str(GameManager.draw_pile.size())
	if discard_pile_btn:
		discard_pile_btn.text = "弃牌:" + str(GameManager.discard_pile.size())


func _update_player_buff_display() -> void:
	if not player_buff_container:
		return
	for child in player_buff_container.get_children():
		child.queue_free()

	# Strength
	if GameManager.strength_buff != 0:
		var is_debuff = GameManager.strength_buff < 0
		_add_buff_icon(player_buff_container,
			"力", GameManager.strength_buff,
			"力量：每次攻击%s%d伤害" % ["+" if GameManager.strength_buff > 0 else "", GameManager.strength_buff],
			Color(1.0, 0.6, 0.3) if not is_debuff else Color(0.5, 0.5, 0.55))

	# Dexterity
	if GameManager.dexterity_buff != 0:
		_add_buff_icon(player_buff_container,
			"敏", GameManager.dexterity_buff,
			"敏捷：每次防御+%d护盾" % GameManager.dexterity_buff,
			Color(0.3, 0.7, 1.0))

	# Vulnerable
	if GameManager.vulnerable_stacks > 0:
		_add_buff_icon(player_buff_container,
			"易", GameManager.vulnerable_stacks,
			"易伤：受到攻击伤害+50%%，每回合减1层",
			Color(0.9, 0.3, 0.5))

	# Harmony
	if GameManager.harmony_count > 0:
		_add_buff_icon(player_buff_container,
			"和", GameManager.harmony_count,
			"和声：连打2张同属性牌触发(触发后重置)，触发牌获得固定加成(见卡牌描述)，属性加成：可爱回1HP/帅气敌-1力/快乐抽1/神秘敌+1易伤/纯+1盾",
			Color(1.0, 0.9, 0.3))

	# Power effects
	if GameManager.power_harmony_flat_bonus > 0:
		_add_buff_icon(player_buff_container, "和+", GameManager.power_harmony_flat_bonus, "和声触发时伤害/护盾+%d(永久)" % GameManager.power_harmony_flat_bonus, Color(1.0, 0.7, 0.9))
	if GameManager.power_skill_str:
		_add_buff_icon(player_buff_container, "技力", 0, "每打技能牌+1力量(永久)", Color(0.6, 0.8, 0.3))
	if GameManager.power_first_return:
		_add_buff_icon(player_buff_container, "回手", 0, "每回合首牌回手(永久)", Color(0.4, 0.6, 0.9))
	if GameManager.power_extra_energy:
		_add_buff_icon(player_buff_container, "+能", 1, "每回合+1能量(永久)", Color(1.0, 0.85, 0.3))
	if GameManager.power_beat_energy:
		_add_buff_icon(player_buff_container, "拍能", 0, "本回合第3拍+1能量(永久)", Color(0.3, 0.7, 1.0))

	# Harmony boost pending
	if GameManager.harmony_boost_active:
		_add_buff_icon(player_buff_container, "和×2", 0,
			"和声翻倍：下次和声触发时属性效果翻倍(可爱→2HP等)", Color(1.0, 0.5, 0.9))

	# Beat counter (节拍)
	if GameManager.cards_played_this_turn > 0:
		_add_buff_icon(player_buff_container, "拍", GameManager.cards_played_this_turn,
			"节拍：本回合已打出%d张牌" % GameManager.cards_played_this_turn, Color(0.4, 0.7, 1.0))


func _add_buff_icon(container: HBoxContainer, icon_char: String, value: int, tooltip: String, color: Color) -> void:
	var cell = Panel.new()
	cell.custom_minimum_size = Vector2(50, 30)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(color.r * 0.2, color.g * 0.2, color.b * 0.2, 0.9)
	style.border_color = color
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	cell.add_theme_stylebox_override("panel", style)
	cell.tooltip_text = tooltip

	var label = Label.new()
	var display_text = icon_char
	if value != 0:
		display_text += ":" + str(value)
	label.text = display_text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 12)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(label)

	container.add_child(cell)


func _toggle_help_panel() -> void:
	if help_panel and help_panel.visible:
		help_panel.visible = false
		return

	_close_all_popups()

	if not help_panel:
		help_panel = Panel.new()
		help_panel.size = Vector2(400, 320)
		help_panel.z_index = 300
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.12, 0.1, 0.22, 0.97)
		style.border_color = Color(1.0, 0.85, 0.3, 0.8)
		style.set_border_width_all(2)
		style.set_corner_radius_all(6)
		help_panel.add_theme_stylebox_override("panel", style)
		add_child(help_panel)

		var title = Label.new()
		title.text = "♪ 和声机制说明"
		title.position = Vector2(10, 10)
		title.size = Vector2(380, 30)
		title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		title.add_theme_font_size_override("font_size", 18)
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		help_panel.add_child(title)

		var desc = Label.new()
		desc.text = """触发条件：连续打出两张同属性牌(第二张触发和声)
触发后重置：需再打出两张同属性牌才能再次触发
效果：触发牌获得固定伤害/护盾加成(具体数值见每张卡牌描述)
	「共鸣碎片」遗物：和声触发时额外+2伤害
	「共振叉」遗物：和声触发时额外+3伤害

各属性和声加成：
♪ 可爱  → 回复1HP
♪ 帅气  → 敌人-1力量
♪ 快乐  → 抽1牌
♪ 神秘  → 敌人+1易伤(受到伤害+50%)
♪ 纔真  → +1护盾

常见Buff说明：
力量：每次攻击额外+N伤害
敏捷：每次防御额外+N护盾
易伤：受到攻击伤害+50%，每回合减1层
能力牌(Power)：打出后移除，效果持续本战斗"""
		desc.position = Vector2(10, 45)
		desc.size = Vector2(380, 270)
		desc.add_theme_color_override("font_color", Color(0.85, 0.85, 0.92))
		desc.add_theme_font_size_override("font_size", 14)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		help_panel.add_child(desc)

		var close_btn = Button.new()
		close_btn.text = "关闭"
		close_btn.position = Vector2(160, 285)
		close_btn.size = Vector2(80, 30)
		close_btn.pressed.connect(func(): help_panel.visible = false)
		help_panel.add_child(close_btn)

	help_panel.position = Vector2(880, 50)
	help_panel.visible = true


func _on_card_hovered(card_data: CardData) -> void:
	_show_card_detail(card_data)


func _on_card_unhovered() -> void:
	_hide_card_detail()


func _on_card_clicked(card_data: CardData) -> void:
	if not GameManager.in_battle:
		return
	if card_data.get_display_cost() > GameManager.energy:
		_log("[color=red]能量不足！[/color]")
		return
	_close_all_popups()
	GameManager.play_card(card_data)
	battle_manager.play_card_effects(card_data)
	_update_hand_display()
	_update_player_buff_display()
	# Update enemy block/strength after card effects
	if enemy_node:
		enemy_node.update_buffs(battle_manager.enemy_strength, battle_manager.enemy_block, battle_manager.enemy_vulnerable)

	if GameManager.player_hp <= 0:
		return


func _close_all_popups() -> void:
	_hide_card_detail()
	if help_panel and help_panel.visible:
		help_panel.visible = false
	if deck_viewer_panel and is_instance_valid(deck_viewer_panel):
		var ov = deck_viewer_panel.get_meta("overlay") if deck_viewer_panel.has_meta("overlay") else null
		if ov and is_instance_valid(ov):
			ov.queue_free()
		deck_viewer_panel.queue_free()
		deck_viewer_panel = null


func _open_deck_viewer(pile: Array, title_text: String = "卡组") -> void:
	_close_all_popups()
	deck_viewer_panel = DeckViewer.show_deck(pile, self, title_text)


func _on_end_turn_pressed() -> void:
	if not GameManager.in_battle:
		return
	_close_all_popups()
	end_turn_button.disabled = true
	GameManager.end_player_turn()
	battle_manager.execute_enemy_turn()
	if battle_manager.enemy_hp <= 0:
		return
	GameManager.start_new_turn()
	_update_hand_display()
	_update_player_buff_display()
	if enemy_node:
		enemy_node.update_buffs(battle_manager.enemy_strength, battle_manager.enemy_block, battle_manager.enemy_vulnerable)
	end_turn_button.disabled = false


func _on_hp_changed(hp: int, max_hp: int) -> void:
	if player_hp_bar:
		player_hp_bar.value = float(hp) / float(max_hp) * 100.0
	if player_hp_label:
		player_hp_label.text = str(hp) + "/" + str(max_hp)


func _on_block_changed(new_block: int) -> void:
	if player_block_bar:
		if new_block > 0:
			player_block_bar.value = mini(new_block * 5.0, 100.0)
		else:
			player_block_bar.value = 0
	# Update HP label to show block value
	if player_hp_label:
		var block_text = ""
		if new_block > 0:
			block_text = " 🛡" + str(new_block)
		player_hp_label.text = str(GameManager.player_hp) + "/" + str(GameManager.player_max_hp) + block_text
	_update_player_buff_display()


func _on_gold_changed(new_gold: int) -> void:
	if gold_label:
		gold_label.text = "💰" + str(new_gold)


func _on_energy_changed(current: int, maximum: int) -> void:
	if energy_label:
		energy_label.text = "⚡" + str(current) + "/" + str(maximum)
	for card_node in card_nodes:
		if card_node.card_data:
			var playable = card_node.card_data.cost <= current
			card_node.is_playable = playable
			card_node.modulate = Color(1, 1, 1) if playable else Color(0.5, 0.5, 0.5, 0.8)


func _on_enemy_hp_changed(hp: int, max_hp: int) -> void:
	if enemy_node:
		enemy_node.update_hp(hp, max_hp)


func _on_enemy_block_changed(block: int) -> void:
	if enemy_node:
		enemy_node.update_buffs(battle_manager.enemy_strength, block, battle_manager.enemy_vulnerable)


func _on_enemy_intent_changed(type: int, value: int) -> void:
	if enemy_node:
		enemy_node.update_intent(type, value)

func _on_enemy_buff_changed(strength: int, block: int, vulnerable: int) -> void:
	if enemy_node:
		enemy_node.update_buffs(strength, block, vulnerable)
		battle_manager.update_intent_display()


func _on_player_attacked(damage: int) -> void:
	_log("[color=red]造成 " + str(damage) + " 伤害[/color]")
	_flash_screen(Color(1.0, 1.0, 1.0, 0.3), 0.08)


func _on_enemy_attacked(damage: int) -> void:
	_log("[color=orange]受到 " + str(damage) + " 伤害[/color]")
	_flash_screen(Color(0.8, 0.1, 0.1, 0.4), 0.12)
	player_shake_timer = 0.3
	# Shake player icon
	if player_node:
		var tween = create_tween()
		tween.tween_property(player_icon, "modulate", Color(2.0, 0.4, 0.4), 0.05)
		tween.tween_property(player_icon, "modulate", Color(1, 1, 1, 0.9), 0.2)
	_update_player_buff_display()


func _on_harmony_triggered(attribute: int, bonus_text: String) -> void:
	var attr_name = ""
	match attribute:
		CardData.Attribute.NONE: attr_name = "none"
		CardData.Attribute.CUTE: attr_name = "cute"
		CardData.Attribute.COOL: attr_name = "cool"
		CardData.Attribute.HAPPY: attr_name = "happy"
		CardData.Attribute.MYSTERIOUS: attr_name = "mysterious"
		CardData.Attribute.PURE: attr_name = "pure"
	_log("[color=yellow]♪ 和声！%s → %s[/color]" % [attr_name, bonus_text])
	harmony_label.text = "♪ 和声！"
	harmony_label.visible = true
	var timer = get_tree().create_timer(1.5)
	timer.timeout.connect(func(): harmony_label.visible = false)
	# Refresh enemy buff display (COOL harmony reduces enemy strength, MYSTERIOUS adds vulnerable)
	if enemy_node:
		enemy_node.update_buffs(battle_manager.enemy_strength, battle_manager.enemy_block, battle_manager.enemy_vulnerable)
	_update_hand_display()


func _on_damage_popup(amount: int, is_player: bool) -> void:
	_spawn_damage_number(amount, is_player)


func _on_block_popup(amount: int) -> void:
	_spawn_block_number(amount)
	_log("[color=cyan]获得 " + str(amount) + " 护盾[/color]")


func _on_enemy_damaged() -> void:
	if enemy_node:
		enemy_node.shake()


func _on_player_debuffed(strength_change: int) -> void:
	if strength_change != 0:
		var text = "力量-%d" % abs(strength_change) if strength_change < 0 else "力量+%d" % strength_change
		_log("[color=purple]%s[/color]" % text)
	_update_player_buff_display()


func _on_harmony_bonus_damage(amount: int) -> void:
	_log("[color=yellow]♪ 和声加成 +%d 伤害[/color]" % amount)
	_spawn_damage_number(amount, false)


func _on_skill_log(text: String) -> void:
	_log("[color=cyan]%s[/color]" % text)
	_update_player_buff_display()


func _on_shake_screen() -> void:
	if enemy_node:
		enemy_node.shake()


func _on_turn_started() -> void:
	end_turn_button.disabled = false
	_log("--- 你的回合 ---")
	_update_player_buff_display()
	if enemy_node:
		enemy_node.update_buffs(battle_manager.enemy_strength, battle_manager.enemy_block, battle_manager.enemy_vulnerable)


func _on_turn_ended() -> void:
	_log("--- 敌人回合 ---")


func _on_battle_over(won: bool) -> void:
	GameManager.in_battle = false
	end_turn_button.disabled = true
	if won:
		_log("[color=green]★ 战斗胜利！★[/color]")
		var gold_reward = randi() % 8 + 8
		if GameManager.encounter_type == "elite":
			gold_reward = randi() % 16 + 25
		elif GameManager.encounter_type == "boss":
			gold_reward = randi() % 21 + 40
		GameManager.gold_reward_pending = gold_reward
		# Score tracking: record kill by tier
		match GameManager.encounter_type:
			"elite":
				GameManager.elite_kills += 1
			"boss":
				GameManager.boss_kills += 1
			_:
				GameManager.normal_kills += 1
		GameManager.total_battles_won += 1
		# Relic reward routing: elite/boss → relic pick first
		if GameManager.encounter_type in ["elite", "boss"]:
			GameManager.relic_pick_pending = true
			GameManager.relic_pick_count = 3
			var timer = get_tree().create_timer(2.0)
			timer.timeout.connect(func(): get_tree().change_scene_to_file("res://scenes/relic_pick.tscn"))
		elif randf() < 0.10:
			# Normal battle: 10% chance for a common relic
			GameManager.relic_pick_pending = true
			GameManager.relic_pick_count = 1
			var timer = get_tree().create_timer(2.0)
			timer.timeout.connect(func(): get_tree().change_scene_to_file("res://scenes/relic_pick.tscn"))
		else:
			var timer = get_tree().create_timer(2.0)
			timer.timeout.connect(func(): get_tree().change_scene_to_file("res://scenes/reward.tscn"))
	else:
		_log("[color=red]✖ 战斗失败...[/color]")
		GameManager.run_active = false
		GameManager.run_completed_won = false
		var timer = get_tree().create_timer(2.0)
		timer.timeout.connect(func(): get_tree().change_scene_to_file("res://scenes/score_scene.tscn"))


var relic_detail_panel: Panel = null
var relic_bar_container: HBoxContainer = null

func _refresh_relic_bar(bar: HBoxContainer) -> void:
	relic_bar_container = bar
	for child in bar.get_children():
		bar.remove_child(child)
		child.queue_free()
	for relic_id in GameManager.relics:
		var relic_data = RelicDB.get_relic(relic_id)
		if not relic_data:
			continue
		var cell = Panel.new()
		cell.custom_minimum_size = Vector2(36, 36)
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.15, 0.12, 0.25, 0.9)
		style.border_color = relic_data.get_rarity_color()
		style.set_border_width_all(1)
		style.set_corner_radius_all(3)
		cell.add_theme_stylebox_override("panel", style)
		# Store relic data for tooltip lookup
		cell.set_meta("relic_id", relic_id)
		var label = Label.new()
		label.text = relic_data.name[0]  # first character as icon
		label.add_theme_color_override("font_color", relic_data.get_rarity_color())
		label.add_theme_font_size_override("font_size", 16)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.set_anchors_preset(Control.PRESET_FULL_RECT)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(label)
		# Hover signals for custom tooltip panel
		cell.mouse_entered.connect(_on_relic_cell_entered.bind(cell))
		cell.mouse_exited.connect(_on_relic_cell_exited)
		bar.add_child(cell)

func _on_relic_cell_entered(cell: Panel) -> void:
	var relic_id = cell.get_meta("relic_id") as String
	var relic_data = RelicDB.get_relic(relic_id)
	if not relic_data:
		return
	# Create or reuse relic detail panel
	if not relic_detail_panel:
		relic_detail_panel = Panel.new()
		relic_detail_panel.z_index = 200
		relic_detail_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.12, 0.10, 0.22, 0.97)
		style.border_color = Color(1.0, 0.85, 0.3, 0.8)
		style.set_border_width_all(2)
		style.set_corner_radius_all(6)
		relic_detail_panel.add_theme_stylebox_override("panel", style)
		add_child(relic_detail_panel)
	# Clear old children
	for child in relic_detail_panel.get_children():
		child.queue_free()
	# Build content
	relic_detail_panel.custom_minimum_size = Vector2(260, 140)
	# Rarity tag
	var rarity_label = Label.new()
	rarity_label.text = relic_data.get_rarity_name() + (" ★Boss限定" if relic_data.boss_only else "")
	rarity_label.add_theme_color_override("font_color", relic_data.get_rarity_color())
	rarity_label.add_theme_font_size_override("font_size", 14)
	rarity_label.position = Vector2(10, 8)
	rarity_label.size = Vector2(240, 22)
	rarity_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	relic_detail_panel.add_child(rarity_label)
	# Name
	var name_label = Label.new()
	name_label.text = relic_data.name
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.position = Vector2(10, 32)
	name_label.size = Vector2(240, 28)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	relic_detail_panel.add_child(name_label)
	# Description
	var desc_label = Label.new()
	desc_label.text = relic_data.description
	desc_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	desc_label.add_theme_font_size_override("font_size", 15)
	desc_label.position = Vector2(10, 62)
	desc_label.size = Vector2(240, 60)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	relic_detail_panel.add_child(desc_label)
	# Price info
	var price_label = Label.new()
	price_label.text = "商店价格: " + str(relic_data.price) + "金"
	price_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	price_label.add_theme_font_size_override("font_size", 13)
	price_label.position = Vector2(10, 122)
	price_label.size = Vector2(240, 18)
	price_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	relic_detail_panel.add_child(price_label)
	# Wah pedal counter info
	if relic_id == "wah_pedal":
		var counter_label = Label.new()
		var counter_text = "已出 %d/3 张" % GameManager.wah_pedal_counter
		if GameManager.wah_pedal_free:
			counter_text = "下张牌0费!"
		counter_label.text = counter_text
		counter_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
		counter_label.add_theme_font_size_override("font_size", 14)
		counter_label.position = Vector2(10, 108)
		counter_label.size = Vector2(240, 20)
		counter_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		relic_detail_panel.add_child(counter_label)
	# Position panel below the relic bar, aligned to the hovered cell
	var cell_pos = cell.global_position
	var panel_x = cell_pos.x - 10
	var panel_y = cell_pos.y + 40
	if panel_x + 260 > 1280:
		panel_x = 1280 - 270
	if panel_y + 140 > 710:
		panel_y = cell_pos.y - 150
	relic_detail_panel.position = Vector2(panel_x, panel_y)
	relic_detail_panel.visible = true

func _on_relic_cell_exited() -> void:
	if relic_detail_panel:
		relic_detail_panel.visible = false

func _process(delta: float) -> void:
	if player_shake_timer > 0:
		player_shake_timer -= delta
		var intensity = player_shake_timer * 15.0
		player_node.position = player_base_pos + Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
	else:
		if player_node and player_node.position.distance_to(player_base_pos) > 0.5:
			player_node.position = player_node.position.lerp(player_base_pos, 0.2)
		elif player_node:
			player_node.position = player_base_pos


func _log(text: String) -> void:
	if battle_log:
		battle_log.append_text(text + "\n")
		await get_tree().process_frame
		battle_log.scroll_to_line(battle_log.get_line_count())


func _flash_screen(color: Color, duration: float) -> void:
	if not screen_flash:
		return
	screen_flash.color = color
	var tween = create_tween()
	tween.tween_property(screen_flash, "color:a", 0.0, duration)


func _spawn_damage_number(amount: int, is_player: bool) -> void:
	var label = Label.new()
	label.text = str(amount)
	label.add_theme_font_size_override("font_size", 32)
	if is_player:
		label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		label.position = player_base_pos + Vector2(80, 200)
	else:
		label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		if enemy_container:
			label.position = enemy_container.position + Vector2(230, 120)
		else:
			label.position = Vector2(800, 150)
	label.z_index = 50
	add_child(label)
	var tween = create_tween()
	tween.tween_property(label, "position:y", label.position.y - 60, 0.8)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.8)
	tween.tween_callback(label.queue_free)


func _spawn_block_number(amount: int) -> void:
	var label = Label.new()
	label.text = "🛡" + str(amount)
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0))
	label.position = player_base_pos + Vector2(80, 180)
	label.z_index = 50
	add_child(label)
	var tween = create_tween()
	tween.tween_property(label, "position:y", label.position.y - 50, 0.8)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.8)
	tween.tween_callback(label.queue_free)
