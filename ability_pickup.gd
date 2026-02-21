extends Area2D

# ─────────────────────────────────────────────
#  ABILITY PICKUP
#  Animazione: bob su/giù + rotazione lenta
#  Glow: PointLight2D che pulsa (opzionale)
# ─────────────────────────────────────────────

@onready var sprite: Sprite2D = $Sprite2D

@export var ability_name: String = "gun"
@export var auto_destroy: bool = true
@export var pickup_sound: AudioStreamPlayer2D
@export var icon_texture: Texture2D

# ── Animazione ────────────────────────────────
@export_group("Animation")
@export var bob_amplitude: float = 5.0      # pixel su/giù
@export var bob_speed: float     = 2.0      # Hz
@export var rotate_speed: float  = 45.0     # gradi/sec (0 = no rotazione)

var _base_y: float = 0.0
var _time: float   = 0.0


func _ready() -> void:
	if icon_texture:
		sprite.texture = icon_texture

	_base_y = position.y
	_time   = randf() * TAU   # fase random così più pickup non vanno in sync

	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_time += delta

	# Bob verticale
	position.y = _base_y + sin(_time * bob_speed) * bob_amplitude

	# Rotazione lenta (in gradi → radianti)
	if rotate_speed != 0.0:
		sprite.rotation += deg_to_rad(rotate_speed) * delta


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	if body.has_method("unlock_ability"):
		body.unlock_ability(ability_name)
	if pickup_sound:
		pickup_sound.play()
	if auto_destroy:
		queue_free()
