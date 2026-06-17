# Enemy data resource for Melody Maze.
class_name EnemyData
extends Resource

enum IntentType { ATTACK, DEFEND, BUFF, DEBUFF, EMPOWER }
enum EnemyTier { NORMAL, ELITE, BOSS }

@export var id: String = ""
@export var enemy_name: String = ""
@export var tier: EnemyTier = EnemyTier.NORMAL
@export var layer: int = 1  # 1=floors 1-5, 2=floors 6-10, 3=floors 11-15
@export var min_hp: int = 20
@export var max_hp: int = 30
@export var image_path: String = ""
@export var moves: Array = []  # [{intent, value, effect_id, weight}]


func get_tier_name() -> String:
	if tier == EnemyTier.NORMAL:
		return "普通"
	elif tier == EnemyTier.ELITE:
		return "精英"
	elif tier == EnemyTier.BOSS:
		return "Boss"
	return "普通"


func roll_hp() -> int:
	if max_hp <= min_hp:
		return max_hp
	return randi() % (max_hp - min_hp + 1) + min_hp