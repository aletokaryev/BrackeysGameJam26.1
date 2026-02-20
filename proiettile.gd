extends Area2D

@export var speed: float = 500.0
var velocity: Vector2 = Vector2.ZERO

func _physics_process(delta: float) -> void:
	position += velocity * delta

	# opzionale: se va troppo lontano, distruggilo
	if abs(global_position.x) > 10000 or abs(global_position.y) > 10000:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if !body.is_in_group("player"):
		print("sparo!")
		queue_free()
