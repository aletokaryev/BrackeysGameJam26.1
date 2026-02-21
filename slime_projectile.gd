extends Area2D

# ─────────────────────────────────────────────
#  SLIME PROJECTILE
#  Sparato dal boss verso il player.
#  Si distrugge su pavimento/muri o al contatto col player.
# ─────────────────────────────────────────────

@onready var sprite: AnimatedSprite2D = $Sprite

@export var speed:          float = 750.0
@export var damage:         int   = 1
@export var lifetime:       float = 3.0
@export var gravity_scale:  float = 0.4   # cade leggermente (traiettoria arcuata)

var velocity: Vector2 = Vector2.ZERO
var _timer:   float   = 0.0


func _ready() -> void:
	add_to_group("enemy_bullet")
	sprite.play("idle")
	body_entered.connect(_on_body_entered)
	# rimuovi area_entered, non serve


func launch(direction: Vector2) -> void:
	velocity = direction.normalized() * speed


func _physics_process(delta: float) -> void:
	# Gravità leggera → traiettoria arcuata
	velocity.y += 980.0 * gravity_scale * delta

	global_position += velocity * delta

	# Rotazione visiva in base alla direzione
	rotation = velocity.angle()

	_timer += delta
	if _timer >= lifetime:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		if body.has_method("apply_damage"):
			body.apply_damage(damage)
		_splat()
		return
	# qualsiasi altro body (muri, pavimento) → splat
	if not body.is_in_group("enemy"):
		_splat()


func _splat() -> void:
	# Qui puoi aggiungere un effetto splat (particelle, animazione)
	queue_free()
