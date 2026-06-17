# Card data resource for Melody Maze.
class_name CardData
extends Resource

enum CardType { ATTACK, DEFENSE, SKILL, POWER }
enum Attribute { NONE, CUTE, COOL, HAPPY, MYSTERIOUS, PURE }
enum Rarity { COMMON, RARE, LEGENDARY }

@export var id: String = ""
@export var card_name: String = ""
@export var character_name: String = ""
@export var cost: int = 0
@export var card_type: CardType = CardType.ATTACK
@export var attribute: Attribute = Attribute.CUTE
@export var rarity: Rarity = Rarity.COMMON
@export var damage: int = 0
@export var block: int = 0
@export var effect_text: String = ""
@export var effect_id: String = ""  # special effect identifier
@export var image_path: String = ""

# Upgraded version (after upgrade at shop/rest)
@export var upgraded_cost: int = -1  # -1 = same as base cost
@export var upgraded_damage: int = 0
@export var upgraded_block: int = 0
@export var upgraded_effect_text: String = ""
@export var is_upgraded: bool = false
@export var guaranteed_first_draw: bool = false  # always in initial hand when true

# Character restriction (empty = available to all)
@export var character_id: int = 0  # 0 = shared, 1/13/14/16/17/20 = character-specific

# Harmony flat bonus (replaces universal x1.4 multiplier)
@export var harmony_damage: int = 0  # flat damage bonus when harmony triggers
@export var harmony_block: int = 0  # flat block bonus when harmony triggers
@export var upgraded_harmony_damage: int = 0  # upgraded version of harmony_damage
@export var upgraded_harmony_block: int = 0  # upgraded version of harmony_block


func get_display_cost() -> int:
	if is_upgraded and upgraded_cost >= 0:
		return upgraded_cost
	return cost


func get_display_damage() -> int:
	return damage if not is_upgraded else upgraded_damage


func get_display_block() -> int:
	return block if not is_upgraded else upgraded_block


func get_harmony_damage() -> int:
	return upgraded_harmony_damage if is_upgraded else harmony_damage


func get_harmony_block() -> int:
	return upgraded_harmony_block if is_upgraded else harmony_block


func get_display_text() -> String:
	return effect_text if not is_upgraded else upgraded_effect_text


func get_attribute_name() -> String:
	match attribute:
		Attribute.NONE: return "none"
		Attribute.CUTE: return "cute"
		Attribute.COOL: return "cool"
		Attribute.HAPPY: return "happy"
		Attribute.MYSTERIOUS: return "mysterious"
		Attribute.PURE: return "pure"
	return "none"


func get_rarity_name() -> String:
	match rarity:
		Rarity.COMMON: return "普通"
		Rarity.RARE: return "稀有"
		Rarity.LEGENDARY: return "传说"
	return "普通"


func get_type_name() -> String:
	match card_type:
		CardType.ATTACK: return "攻击"
		CardType.DEFENSE: return "防御"
		CardType.SKILL: return "技能"
		CardType.POWER: return "能力"
	return "攻击"


func get_type_color() -> Color:
	match card_type:
		CardType.ATTACK: return Color(0.85, 0.25, 0.25)
		CardType.DEFENSE: return Color(0.25, 0.55, 0.85)
		CardType.SKILL: return Color(0.25, 0.7, 0.35)
		CardType.POWER: return Color(0.7, 0.4, 0.85)
	return Color.WHITE


func get_attribute_color() -> Color:
	match attribute:
		Attribute.NONE: return Color(0.6, 0.6, 0.6)
		Attribute.CUTE: return Color(1.0, 0.6, 0.78)
		Attribute.COOL: return Color(0.4, 0.6, 0.9)
		Attribute.HAPPY: return Color(1.0, 0.7, 0.3)
		Attribute.MYSTERIOUS: return Color(0.6, 0.3, 0.85)
		Attribute.PURE: return Color(0.4, 0.85, 0.5)
	return Color.WHITE


func is_harmony_card() -> bool:
	# Cards whose effects interact with the harmony mechanic
	return effect_id.begins_with("harmony_") or effect_id == "always_harmony" or \
		effect_id == "block_if_harmony_3" or effect_id == "power_harmony_flat_bonus" or \
		effect_id == "power_harmony_draw" or \
		harmony_damage > 0 or harmony_block > 0


func is_exhaust() -> bool:
	# Cards that remove themselves from the battle when played
	return effect_id.begins_with("exhaust") or effect_text.find("消耗") >= 0
