# RelicData — data class for a single relic.
class_name RelicData
extends Resource

enum Rarity { COMMON, RARE, LEGENDARY }

@export var id: String = ""
@export var name: String = ""
@export var description: String = ""
@export var rarity: Rarity = Rarity.COMMON
@export var price: int = 150
@export var boss_only: bool = false  # 只能从Boss战获得（能量遗物）


func get_rarity_name() -> String:
	match rarity:
		Rarity.COMMON: return "普通"
		Rarity.RARE: return "稀有"
		Rarity.LEGENDARY: return "传说"
	return ""


func get_rarity_color() -> Color:
	match rarity:
		Rarity.COMMON: return Color(0.7, 0.7, 0.7)
		Rarity.RARE: return Color(0.3, 0.6, 1.0)
		Rarity.LEGENDARY: return Color(1.0, 0.7, 0.2)
	return Color.WHITE
