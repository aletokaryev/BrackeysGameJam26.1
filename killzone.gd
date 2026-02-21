extends Area2D

@export var instant_kill: bool = true  # false = toglie 1 vita sola

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		if instant_kill:
			body._die()
		else:
			if body.has_method("apply_damage"):
				body.apply_damage(999)
