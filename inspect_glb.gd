extends SceneTree

func _init():
    var gltf = GLTFDocument.new()
    var state = GLTFState.new()
    var err = gltf.append_from_file("res://assets/models/minecraft_-_pig.glb", state)
    if err == OK:
        print("--- PIG NODES ---")
        for i in range(state.nodes.size()):
            print("Node: ", state.nodes[i].resource_name)
        print("--- PIG ANIMATIONS ---")
        for i in range(state.animations.size()):
            print("Animation: ", state.animations[i].resource_name)
            
    var err2 = gltf.append_from_file("res://assets/models/minecraft_-_cow.glb", state)
    if err2 == OK:
        print("--- COW ANIMATIONS ---")
        for i in range(state.animations.size()):
            print("Animation: ", state.animations[i].resource_name)
    quit()
