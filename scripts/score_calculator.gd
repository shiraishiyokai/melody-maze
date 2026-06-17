# ScoreCalculator — computes final run score from GameManager state.
# Produces a structured ScoreResult that is serializable for leaderboard integration.
class_name ScoreCalculator
extends RefCounted


class ScoreResult:
	var run_completion: int = 0
	var floor_points: int = 0
	var normal_kill_points: int = 0
	var elite_kill_points: int = 0
	var boss_kill_points: int = 0
	var hp_bonus: int = 0
	var gold_bonus: int = 0
	var relic_bonus: int = 0
	var upgrade_bonus: int = 0
	var total_score: int = 0

	# Metadata for leaderboard serialization
	var character_id: int = 0
	var character_name: String = ""
	var floors_reached: int = 0
	var normal_kills: int = 0
	var elite_kills: int = 0
	var boss_kills: int = 0
	var total_battles_won: int = 0
	var final_hp: int = 0
	var final_max_hp: int = 0
	var total_gold_earned: int = 0
	var relic_count: int = 0
	var upgraded_card_count: int = 0
	var deck_size: int = 0
	var run_won: bool = false

	# Serialized dictionary for leaderboard upload
	func to_dict() -> Dictionary:
		return {
			"total_score": total_score,
			"character_id": character_id,
			"character_name": character_name,
			"run_won": run_won,
			"floors_reached": floors_reached,
			"kills": {"normal": normal_kills, "elite": elite_kills, "boss": boss_kills},
			"total_battles_won": total_battles_won,
			"final_hp": final_hp,
			"max_hp": final_max_hp,
			"total_gold_earned": total_gold_earned,
			"relic_count": relic_count,
			"upgraded_card_count": upgraded_card_count,
			"deck_size": deck_size,
			"breakdown": {
				"run_completion": run_completion,
				"floor_points": floor_points,
				"normal_kill_points": normal_kill_points,
				"elite_kill_points": elite_kill_points,
				"boss_kill_points": boss_kill_points,
				"hp_bonus": hp_bonus,
				"gold_bonus": gold_bonus,
				"relic_bonus": relic_bonus,
				"upgrade_bonus": upgrade_bonus,
			}
		}


const POINTS_RUN_COMPLETION: int = 5000
const POINTS_PER_FLOOR: int = 300
const POINTS_NORMAL_KILL: int = 150
const POINTS_ELITE_KILL: int = 300
const POINTS_BOSS_KILL: int = 500
const POINTS_PER_HP: int = 30
const POINTS_PER_GOLD: int = 2
const POINTS_PER_RELIC: int = 200
const POINTS_PER_UPGRADE: int = 50

# Character ID → name mapping
const CHAR_NAMES = {
	1: "星乃一歌",
	2: "白石杏",
	13: "天馬司",
	14: "鳳えむ",
	16: "神代類",
	17: "宵崎奏",
	20: "暁山瑞希",
}


static func calculate() -> ScoreResult:
	var result = ScoreResult.new()

	# Metadata
	result.character_id = GameManager.selected_character_id
	result.character_name = CHAR_NAMES.get(GameManager.selected_character_id, "未知角色")
	result.floors_reached = GameManager.current_floor
	result.normal_kills = GameManager.normal_kills
	result.elite_kills = GameManager.elite_kills
	result.boss_kills = GameManager.boss_kills
	result.total_battles_won = GameManager.total_battles_won
	result.final_hp = GameManager.player_hp
	result.final_max_hp = GameManager.player_max_hp
	result.total_gold_earned = GameManager.total_gold_earned
	result.relic_count = GameManager.relics.size()
	result.upgraded_card_count = GameManager.upgraded_cards_count
	result.deck_size = GameManager.deck.size()
	result.run_won = GameManager.run_completed_won

	# Score components
	if result.run_won:
		result.run_completion = POINTS_RUN_COMPLETION

	result.floor_points = mini(result.floors_reached, 20) * POINTS_PER_FLOOR
	result.normal_kill_points = result.normal_kills * POINTS_NORMAL_KILL
	result.elite_kill_points = result.elite_kills * POINTS_ELITE_KILL
	result.boss_kill_points = result.boss_kills * POINTS_BOSS_KILL
	result.hp_bonus = result.final_hp * POINTS_PER_HP
	result.gold_bonus = result.total_gold_earned * POINTS_PER_GOLD
	result.relic_bonus = result.relic_count * POINTS_PER_RELIC
	result.upgrade_bonus = result.upgraded_card_count * POINTS_PER_UPGRADE

	result.total_score = result.run_completion + result.floor_points + \
		result.normal_kill_points + result.elite_kill_points + result.boss_kill_points + \
		result.hp_bonus + result.gold_bonus + result.relic_bonus + result.upgrade_bonus

	return result
