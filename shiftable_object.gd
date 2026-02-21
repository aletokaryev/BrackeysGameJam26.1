extends Node2D


@onready var sprite: Sprite2D              = $Sprite2D
@onready var collision: CollisionShape2D   = $StaticBody2D/CollisionShape2D

# Opzionale: aggiungi un PointLight2D figlio chiamato "GlowLight"
# Se non esiste, usa solo il modulate come fallback
@onready var glow_light: Node = $GlowLight if has_node("GlowLight") else null

@export var texture: Texture2D : set = _set_texture
@export var shift_height: float = -96.0
@export var start_on_top: bool  = false
@export var shift_time: float   = 0.25

@export_group("Raggio e Glow")
@export var shift_radius: float  = 360.0   # px entro cui lo shift funziona
@export var glow_color: Color    = Color(0.4, 0.9, 1.0, 1.0)   # azzurrino
@export var glow_intensity: float = 0.5   # quanto si illumina il modulate (0–1)

var _is_on_top: bool  = false
var _bottom_pos: Vector2
var _top_pos: Vector2
var _in_range: bool   = false
var _is_shifting: bool = false


func _ready() -> void:
	add_to_group("shiftable")
	_bottom_pos = global_position
	_top_pos    = _bottom_pos + Vector2(0.0, shift_height)
	_is_on_top  = start_on_top

	if _is_on_top:
		global_position = _top_pos

	if texture:
		_apply_texture_and_collision()

	# Spegni il glow di default
	_set_glow(false)


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


# ── Chiamato dal player via call_group("shiftable", "try_shift", pos) ──

func try_shift(player_pos: Vector2) -> void:
	var dist := global_position.distance_to(player_pos)
	if dist <= shift_radius:
		shift()


# ── Controlla ogni frame se il player è in range per il glow ──

func _process(_delta: float) -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		_update_in_range(false)
		return

	var player = players[0]

	# Glow solo se il player ha gravity_flip EQUIPAGGIATA
	var has_equipped = player.get("equipped_ability") == "gravity_flip"

	var dist := global_position.distance_to(player.global_position)
	_update_in_range(dist <= shift_radius and has_equipped)


func _update_in_range(in_range: bool) -> void:
	if _in_range == in_range:
		return
	_in_range = in_range
	_set_glow(in_range)


func _set_glow(on: bool) -> void:
	if glow_light != null:
		# Se hai un PointLight2D figlio, accendilo/spegnilo
		glow_light.visible = on
	else:
		# Fallback: modulate dello sprite
		if on:
			sprite.modulate = Color(
				1.0 + glow_color.r * glow_intensity,
				1.0 + glow_color.g * glow_intensity,
				1.0 + glow_color.b * glow_intensity,
				1.0
			)
		else:
			sprite.modulate = Color.WHITE


# ── Shift vero e proprio ──────────────────────

func shift() -> void:
	if _is_shifting:
		return   # evita di shiftare due volte nello stesso frame

	_is_shifting = true
	var target := _top_pos if not _is_on_top else _bottom_pos
	_is_on_top   = not _is_on_top

	var tween := get_tree().create_tween()
	tween.tween_property(self, "global_position", target, shift_time) \
		.set_trans(Tween.TRANS_QUAD) \
		.set_ease(Tween.EASE_OUT)
	tween.tween_callback(func(): _is_shifting = false)
