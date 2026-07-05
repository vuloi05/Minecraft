extends Node3D

const CHUNK_SIZE = 16
var blocks = []
var block_scene = preload("res://Block.tscn")

func _ready():
	# 2.1 Khai báo mảng 3D kích thước 16x16x16
	blocks.resize(CHUNK_SIZE)
	for x in range(CHUNK_SIZE):
		blocks[x] = []
		blocks[x].resize(CHUNK_SIZE)
		for y in range(CHUNK_SIZE):
			blocks[x][y] = []
			blocks[x][y].resize(CHUNK_SIZE)
			for z in range(CHUNK_SIZE):
				blocks[x][y][z] = 1 # 1 = Đá
	
	print("Kích thước mảng: ", blocks.size(), "x", blocks[0].size(), "x", blocks[0][0].size())
	
	# 2.2 Vòng lặp duyệt mảng spawn khối
	for x in range(CHUNK_SIZE):
		for y in range(CHUNK_SIZE):
			for z in range(CHUNK_SIZE):
				if blocks[x][y][z] == 1:
					var b = block_scene.instantiate()
					b.position = Vector3(x, y, z)
					add_child(b)
