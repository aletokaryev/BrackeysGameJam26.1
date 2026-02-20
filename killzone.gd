extends Area2D

@export var respawn_point: NodePath


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		var spawn = get_node(respawn_point) as Node2D
		body.global_position = spawn.global_position
