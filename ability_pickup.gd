extends Area2D

@export var ability_name: String = "gun"
@export var auto_destroy: bool = true
@export var pickup_sound: AudioStreamPlayer2D

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return

	if body.has_method("unlock_ability"):
		body.unlock_ability(ability_name)

	if pickup_sound:
		pickup_sound.play()

	if auto_destroy:
		queue_free()
