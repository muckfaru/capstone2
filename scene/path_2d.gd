extends Path2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Get the baked points from the curve
	var polygon_points = curve.get_baked_points()
	
	# Access the Polygon2D node (sibling of Path2D, both children of Main)
	var polygon = get_parent().get_node("Polygon2D")
	
	# Assign the points to the Polygon2D
	polygon.polygon = polygon_points
	
	# Optional: Print for debugging
	print("Polygon points set: ", polygon_points.size(), " points")
