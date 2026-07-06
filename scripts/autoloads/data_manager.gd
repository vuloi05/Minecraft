extends Node

var blocks_data = {}
var tool_tiers = {}

# Ánh xạ từ Integer ID sang String ID
var int_to_string_id = {
	1: "grass_block",
	2: "oak_log",
	3: "oak_planks",
	4: "oak_leaves",
	5: "torch",
	6: "stone_pickaxe",
	7: "stone",
	8: "dirt",
	9: "stick",
	10: "crafting_table",
	11: "wooden_pickaxe",
	12: "furnace"
}

# Ánh xạ ngược từ String ID sang Integer ID
var string_to_int_id = {}

func _ready():
	# Tạo ánh xạ ngược
	for k in int_to_string_id.keys():
		string_to_int_id[int_to_string_id[k]] = k
	
	load_blocks_data()
	load_recipes_and_tools()

func load_blocks_data():
	var file = FileAccess.open("res://docs/blocks_data.json", FileAccess.READ)
	if file:
		var content = file.get_as_text()
		var json = JSON.new()
		if json.parse(content) == OK:
			var data = json.get_data()
			if data.has("blocks"):
				for b in data["blocks"]:
					blocks_data[b["id"]] = b
		else:
			push_error("Lỗi phân tích cú pháp blocks_data.json")
	else:
		push_error("Không tìm thấy docs/blocks_data.json")

func load_recipes_and_tools():
	var file = FileAccess.open("res://docs/crafting_recipes.json", FileAccess.READ)
	if file:
		var content = file.get_as_text()
		var json = JSON.new()
		if json.parse(content) == OK:
			var data = json.get_data()
			if data.has("tool_tier_reference"):
				tool_tiers = data["tool_tier_reference"]
		else:
			push_error("Lỗi phân tích cú pháp crafting_recipes.json")
	else:
		push_error("Không tìm thấy docs/crafting_recipes.json")

func get_block_data(block_id: int) -> Dictionary:
	if not int_to_string_id.has(block_id):
		return {}
	var string_id = int_to_string_id[block_id]
	if blocks_data.has(string_id):
		return blocks_data[string_id]
	return {}

func get_item_int_id(string_id: String) -> int:
	if string_to_int_id.has(string_id):
		return string_to_int_id[string_id]
	return 0 # Trả về 0 nếu không tìm thấy

func get_tool_tier_of_item(item_id: int) -> int:
	# Tạm thời hardcode tier từ ID vật phẩm dựa theo crafting_recipes.json
	if item_id == 11: return 1 # wooden
	if item_id == 6: return 2 # stone
	return 0 # Tay không hoặc item thường

func get_tool_multiplier(tier: int) -> float:
	if tier == 1: return 2.0
	if tier == 2: return 4.0
	if tier == 3: return 6.0
	if tier == 4: return 8.0
	return 1.0 # Tier 0

func get_mining_time(block_id: int, tool_id: int) -> float:
	var b_data = get_block_data(block_id)
	if b_data.is_empty():
		return 1.0 # Mặc định nếu không có data

	var hardness = b_data.get("hardness", 1.0)
	if hardness < 0: # Không thể phá (bedrock)
		return -1.0
	if hardness == 0: # Phá tức thời
		return 0.0

	var best_tool = b_data.get("best_tool", null)
	var current_tool_tier = get_tool_tier_of_item(tool_id)
	
	var is_correct_tool = false
	if best_tool == "pickaxe" and (tool_id == 6 or tool_id == 11): is_correct_tool = true
	# (nếu có rìu, xẻng thì thêm vào đây)
	
	var base_time = hardness
	if is_correct_tool or best_tool == null:
		base_time = hardness * 1.5
		# Giảm thời gian dựa trên tier
		var speed_mult = get_tool_multiplier(current_tool_tier)
		base_time /= speed_mult
	else:
		base_time = hardness * 5.0 # Dùng sai tool

	return base_time

func get_drops(block_id: int, tool_id: int) -> Array:
	var b_data = get_block_data(block_id)
	if b_data.is_empty():
		return []

	var tool_tier_req = b_data.get("tool_tier_required", 0)
	var current_tool_tier = get_tool_tier_of_item(tool_id)
	
	# Nếu tool chưa đủ tier, không rớt gì
	if current_tool_tier < tool_tier_req:
		return []
		
	var drops = b_data.get("drops", [])
	var result = []
	for d in drops:
		var item_str = d.get("item", "")
		var count = d.get("count", 1)
		var chance = d.get("chance", 1.0)
		
		if randf() <= chance:
			var out_id = get_item_int_id(item_str)
			if out_id > 0:
				result.append({"id": out_id, "count": count})
				
	return result
