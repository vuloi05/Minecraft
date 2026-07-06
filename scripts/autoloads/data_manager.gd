extends Node

var blocks_data = {}
var tool_tiers = {}
var recipes = []

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
	12: "furnace",
	13: "coal_ore",
	14: "iron_ore",
	15: "diamond_ore",
	16: "wooden_axe",
	17: "wooden_sword",
	18: "wooden_shovel",
	19: "stone_axe",
	20: "stone_sword",
	21: "stone_shovel",
	22: "iron_pickaxe",
	23: "iron_axe",
	24: "iron_sword",
	25: "iron_shovel"
}

# Ánh xạ ngược từ String ID sang Integer ID
var string_to_int_id = {}

func _ready():
	# Tạo ánh xạ ngược
	for k in int_to_string_id.keys():
		string_to_int_id[int_to_string_id[k]] = k
	
	load_blocks_data()
	load_recipes_and_tools()
	load_uv_map()

var uv_map = {}

func load_uv_map():
	var file = FileAccess.open("res://assets/textures/atlas_uv.json", FileAccess.READ)
	if file:
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			uv_map = json.get_data()
		else:
			push_error("Lỗi phân tích cú pháp atlas_uv.json")

func get_block_uv(block_id: int) -> Dictionary:
	var b_data = get_block_data(block_id)
	if b_data.has("texture"):
		var tex_name = b_data["texture"].replace(".png", "")
		if uv_map.has(tex_name):
			return uv_map[tex_name]
	return {"u_min": 0, "v_min": 0, "u_max": 0.05, "v_max": 0.05} # Fallback


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
			if data.has("recipes"):
				recipes = data["recipes"]
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

func get_recipe_output(grid_array: Array, columns: int) -> Dictionary:
	var rows = grid_array.size() / columns
	var min_c = columns; var max_c = -1
	var min_r = rows; var max_r = -1
	var items_count = {}
	var has_items = false
	
	for r in range(rows):
		for c in range(columns):
			var id = grid_array[r * columns + c]
			if id > 0:
				has_items = true
				if c < min_c: min_c = c
				if c > max_c: max_c = c
				if r < min_r: min_r = r
				if r > max_r: max_r = r
				items_count[id] = items_count.get(id, 0) + 1
				
	if not has_items: return {}
	
	# Bounding Box
	var w = max_c - min_c + 1
	var h = max_r - min_r + 1
	var b_box = []
	for r in range(h):
		var row_arr = []
		for c in range(w):
			row_arr.append(grid_array[(min_r + r) * columns + (min_c + c)])
		b_box.append(row_arr)

	for r_data in recipes:
		# Bỏ qua nung (smelting)
		if r_data.has("type") and r_data["type"] == "smelting": continue
		
		var grid_req = r_data.get("grid", "no_table")
		if grid_req == "crafting_table" and columns < 3: continue
		
		var is_shapeless = r_data.get("shapeless", false)
		if is_shapeless:
			var ingredients = r_data.get("ingredients", [])
			var req_count = {}
			for ing in ingredients:
				var ing_id = get_item_int_id(ing.get("item", ""))
				req_count[ing_id] = req_count.get(ing_id, 0) + ing.get("count", 1)
			
			var match_all = true
			if req_count.size() != items_count.size(): match_all = false
			else:
				for k in req_count.keys():
					if not items_count.has(k) or items_count[k] != req_count[k]:
						match_all = false
						break
			if match_all:
				return {"id": get_item_int_id(r_data["output"]["item"]), "count": r_data["output"]["count"]}
		else:
			var shape = r_data.get("shape", [])
			var sh_h = shape.size()
			var sh_w = 0 if sh_h == 0 else shape[0].size()
			
			var s_min_r = 100; var s_max_r = -1
			var s_min_c = 100; var s_max_c = -1
			for r in range(sh_h):
				for c in range(sh_w):
					if shape[r][c] != null:
						if r < s_min_r: s_min_r = r
						if r > s_max_r: s_max_r = r
						if c < s_min_c: s_min_c = c
						if c > s_max_c: s_max_c = c
			
			if s_max_r == -1: continue
			
			var real_h = s_max_r - s_min_r + 1
			var real_w = s_max_c - s_min_c + 1
			
			if h != real_h or w != real_w: continue
			
			var match_all = true
			for r in range(real_h):
				for c in range(real_w):
					var str_item = shape[s_min_r + r][s_min_c + c]
					var req_id = 0
					if str_item != null: req_id = get_item_int_id(str_item)
					if b_box[r][c] != req_id:
						match_all = false
						break
				if not match_all: break
				
			if match_all:
				return {"id": get_item_int_id(r_data["output"]["item"]), "count": r_data["output"]["count"]}
	return {}
