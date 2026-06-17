# Map generator — creates 20-floor branching map with single final boss.
class_name MapGenerator
extends RefCounted


func generate() -> Array:
	var nodes: Array = []
	var floors: Dictionary = {}
	for floor_num in range(1, 21):
		var floor_nodes = _create_floor_nodes(floor_num)
		for node in floor_nodes:
			nodes.append(node)
		floors[str(floor_num)] = floor_nodes
	_connect_nodes(nodes, floors)
	return nodes


func _create_floor_nodes(floor_num: int) -> Array:
	var result: Array = []
	var lane_count: int = _get_lane_count(floor_num)
	for lane in range(lane_count):
		var node_type: String = _determine_node_type(floor_num, lane)
		var node = {
			"id": "floor_%d_lane_%d" % [floor_num, lane],
			"floor": floor_num,
			"lane": lane,
			"lane_count": lane_count,
			"type": node_type,
			"connections": [],
			"visited": false,
			"available": false,
			"enemy_id": "",
		}
		var layer = _get_layer(floor_num)
		if node_type == "boss":
			var boss = EnemyDB.get_boss_for_floor(floor_num)
			if boss:
				node["enemy_id"] = boss.id
		elif node_type == "elite":
			var elite = EnemyDB.get_random_elite_by_layer(layer)
			if elite:
				node["enemy_id"] = elite.id
		elif node_type == "battle":
			var enemy = EnemyDB.get_random_normal_by_layer(layer)
			if enemy:
				node["enemy_id"] = enemy.id
		result.append(node)
	return result


func _get_lane_count(floor_num: int) -> int:
	# === Single-node floors (convergence / special) ===
	if floor_num == 1:
		return 1  # start
	if floor_num == 5:
		return 1  # elite convergence
	if floor_num == 10:
		return 1  # campfire mid-point
	if floor_num == 15:
		return 1  # elite convergence
	if floor_num == 19:
		return 1  # campfire before boss
	if floor_num == 20:
		return 1  # final boss
	# === 2-lane transition floors ===
	if floor_num in [2, 6, 11, 16]:
		return 2  # diverge from single node
	if floor_num in [4, 9, 14, 18]:
		return 2  # converge to single node
	# === 3-lane branching floors ===
	return 3


func _get_layer(floor_num: int) -> int:
	if floor_num <= 5:
		return 1
	elif floor_num <= 10:
		return 2
	elif floor_num <= 15:
		return 3
	else:
		return 4


func _determine_node_type(floor_num: int, _lane: int) -> String:
	# Fixed-type floors
	if floor_num == 1:
		return "battle"
	if floor_num == 20:
		return "boss"
	if floor_num == 5:
		return "elite"
	if floor_num == 10:
		return "campfire"
	if floor_num == 15:
		return "elite"
	if floor_num == 19:
		return "campfire"
	# 2-lane converge floors: mostly campfire, small chance shop
	if floor_num in [4, 9, 14, 18]:
		if randf() < 0.2:
			return "shop"
		else:
			return "campfire"
	# 2-lane diverge floors: mostly battle, small chance shop
	if floor_num in [2, 6, 11, 16]:
		if randf() < 0.15:
			return "shop"
		else:
			return "battle"
	# 3-lane floors: weighted random
	var roll = randf()
	if roll < 0.55:
		return "battle"
	elif roll < 0.72:
		return "event"
	elif roll < 0.78:
		return "shop"
	elif roll < 0.90:
		return "campfire"
	else:
		return "elite"


func _is_boss_floor(floor_num: int) -> bool:
	return floor_num == 20


func _connect_nodes(nodes: Array, floors: Dictionary) -> void:
	for floor_num in range(1, 20):
		var cur_key = str(floor_num)
		var next_key = str(floor_num + 1)
		if not floors.has(cur_key) or not floors.has(next_key):
			continue
		var cur_nodes = floors[cur_key]
		var next_nodes = floors[next_key]
		if cur_nodes.is_empty() or next_nodes.is_empty():
			continue

		var cur_count = cur_nodes.size()
		var next_count = next_nodes.size()

		if cur_count == 1 and next_count == 1:
			cur_nodes[0]["connections"].append(next_nodes[0]["id"])
		elif cur_count == 1 and next_count > 1:
			_connect_diverge(cur_nodes[0], next_nodes)
		elif cur_count > 1 and next_count == 1:
			_connect_converge(cur_nodes, next_nodes[0])
		else:
			_connect_parallel(cur_nodes, next_nodes)


func _connect_diverge(source: Dictionary, targets: Array) -> void:
	for target in targets:
		source["connections"].append(target["id"])


func _connect_converge(sources: Array, target: Dictionary) -> void:
	for source in sources:
		source["connections"].append(target["id"])


func _connect_parallel(cur_nodes: Array, next_nodes: Array) -> void:
	var cur_count = cur_nodes.size()
	var next_count = next_nodes.size()

	# Step 1: Each cur node connects to its closest next node
	for i in range(cur_count):
		var target_lane = mini(i, next_count - 1)
		var target_id = next_nodes[target_lane]["id"]
		if not cur_nodes[i]["connections"].has(target_id):
			cur_nodes[i]["connections"].append(target_id)

	# Step 2: Each next node must have at least one parent
	for j in range(next_count):
		var next_id = next_nodes[j]["id"]
		var has_parent = false
		for cur in cur_nodes:
			if cur["connections"].has(next_id):
				has_parent = true
				break
		if not has_parent:
			var best_cur = cur_nodes[mini(j, cur_count - 1)]
			best_cur["connections"].append(next_id)

	# Step 3: Add cross-connections for variety (30% chance per node)
	for i in range(cur_count):
		if cur_nodes[i]["connections"].size() == 1 and randf() < 0.30:
			var adj = -1
			if randf() < 0.5 and i > 0:
				adj = i - 1
			elif i < next_count - 1:
				adj = i + 1
			if adj >= 0 and adj < next_count:
				var adj_id = next_nodes[adj]["id"]
				if not cur_nodes[i]["connections"].has(adj_id):
					cur_nodes[i]["connections"].append(adj_id)