extends Node2D

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $StaticBody2D/CollisionShape2D
@export var texture: Texture2D : set = _set_texture

@export var shift_height: float = -96.0

@export var start_on_top: bool = false
@export var shift_time: float = 0.25

var _is_on_top: bool = false
var _bottom_pos: Vector2
var _top_pos: Vector2

func _ready() -> void:
	add_to_group("shiftable")

	_bottom_pos = global_position
	_top_pos = _bottom_pos + Vector2(0.0, shift_height)

	_is_on_top = start_on_top
	if _is_on_top:
		global_position = _top_pos

	if texture:
		_apply_texture_and_collision()


func _set_texture(t: Texture2D) -> void:
	texture = t
	if is_inside_tree():
		_apply_texture_and_collision()


func _apply_texture_and_collision() -> void:
	if not texture:
		return

	sprite.texture = texture

	var tex_size: Vector2 = texture.get_size() * sprite.scale

	var shape := RectangleShape2D.new()
	shape.extents = tex_size / 2.0

	collision.shape = shape
	collision.position = Vector2.ZERO


func shift() -> void:
	var target := _bottom_pos
	if not _is_on_top:
		target = _top_pos

	_is_on_top = !_is_on_top

	var tween := get_tree().create_tween()
	tween.tween_property(self, "global_position", target, shift_time)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)
