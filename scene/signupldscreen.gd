extends CanvasLayer

@export_file("*.tscn") var next_scene_path: String = "res://scene/signup.tscn"
@export var parameters: Dictionary 

func _ready():
	ResourceLoader.load_threaded_request(next_scene_path) 

func _process(_delta):
	if ResourceLoader.load_threaded_get_status(next_scene_path) == ResourceLoader.THREAD_LOAD_LOADED:
		set_process(false) 
		await get_tree().create_timer(1).timeout 
		
		# Slide down with fade animation on sprite before scene change
		var sprite = get_node_or_null("Control/AnimatedSprite2D")
		if sprite:
			var tween = create_tween()
			tween.set_trans(Tween.TRANS_QUAD)
			tween.set_ease(Tween.EASE_IN)
			tween.set_parallel(true)
			tween.tween_property(sprite, "position:y", get_tree().root.get_visible_rect().size.y, 1.0)
			tween.tween_property(sprite, "modulate:a", 0.0, 1.0)
			await tween.finished
		else:
			await get_tree().create_timer(1.0).timeout
		
		var new_scene: PackedScene = ResourceLoader.load_threaded_get(next_scene_path)
		var new_node = new_scene.instantiate()

		
		if "parameters" in new_node:
			new_node.parameters = parameters
		elif new_node.has_method("set_parameters"):
			new_node.set_parameters(parameters)

		var current_scene = get_tree().current_scene
		get_tree().get_root().add_child(new_node)
		get_tree().current_scene = new_node
		current_scene.queue_free()
