extends Area2D

# ─────────────────────────────────────────────
#  BULLET
#  Si muove in linea retta e si distrugge
#  quando colpisce un nemico o un muro.
# ─────────────────────────────────────────────

@export var speed: float = 600.0
@export var damage: int = 1
@export var lifetime: float = 1.5   # secondi prima di sparire da solo

var velocity: Vector2 = Vector2.ZERO
var _timer: float = 0.0


func _ready() -> void:
	# Connetti il segnale di collisione con corpi fisici
	body_entered.connect(_on_area_entered)
	add_to_group("player_bullet")


func _process(delta: float) -> void:
	global_position += velocity * delta

	_timer += delta
	if _timer >= lifetime:
		queue_free()


func _on_area_entered(body: Node) -> void:
	# Colpisce un nemico
	if body.is_in_group("enemy"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
		queue_free()
		return

	# Colpisce un muro (qualsiasi altra cosa che non sia il player)
	if not body.is_in_group("player"):
		queue_free()
