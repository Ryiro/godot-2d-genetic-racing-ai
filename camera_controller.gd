extends Camera2D

func _ready() -> void:
	position = Vector2(0, 0)
	zoom = Vector2(0.65, 0.65) # Closer zoom so cars are large and distinct
