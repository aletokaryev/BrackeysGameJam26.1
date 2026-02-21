extends CharacterBody2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection_area: Area2D   = $DetectionArea
@onready var hurtbox: Area2D          = $Hurtbox

# ── Patrol ───────────────────────────────────
@export var patrol_distance: float = 80.0
@export var patrol_speed:    float = 30.0

# ── Attacco (salto) ───────────────────────────
@export var jump_speed:         float = 320.0   # velocità orizzontale del salto
@export var jump_force:         float = -340.0  # forza verticale del salto
@export var attack_cooldown:    float = 2.0
@export var prepare_time:       float = 0.4     # secondi di "carica" prima del salto

# ── Danno e knockback ─────────────────────────
@export var damage_to_player:       int   = 1
@export var player_knockback_force: float = 280.0

# ── Vita ──────────────────────────────────────
@export var max_health: int = 2
var health: int = 0

# ── Hit flash ─────────────────────────────────
@export var hit_flash_duration: float = 0.8
var _hit_flash_timer: float = 0.0

# ── Stato ─────────────────────────────────────
enum State { PATROL, PREPARE, JUMP, COOLDOWN }
var state: State = State.PATROL

var home_origin:    Vector2
var patrol_dir:     int = -1
var cooldown_timer: float = 0.0
var prepare_timer:  float = 0.0

var player_in_range: Node2D = null
var target_player:   Node2D = null

var _already_hit: bool = false   # evita danno multiplo nello stesso salto


func _ready() -> void:
	health      = max_health
	home_origin = global_position

	add_to_group("enemy")
	sprite.play("ali")
	sprite.speed_scale = 0.8

	detection_area.body_entered.connect(_on_detection_body_entered)
	detection_area.body_exited.connect(_on_detection_body_exited)
	hurtbox.area_entered.connect(_on_hurtbox_hit)


func _physics_process(delta: float) -> void:
	# Hit flash
	if _hit_flash_timer > 0.0:
		_hit_flash_timer -= delta
		var red   := _hit_flash_timer > hit_flash_duration * 0.5
		var blink := fmod(_hit_flash_timer, 0.2) > 0.1
		sprite.modulate = Color(1, 0.3 if red else 1, 0.3 if red else 1,
								0.3 if blink else 1.0)
		if _hit_flash_timer <= 0.0:
			sprite.modulate = Color.WHITE

	# Gravità sempre (lo slime è a terra)
	if not is_on_floor():
		velocity += get_gravity() * delta

	match state:
		State.PATROL:
			_update_patrol(delta)
			_update_cooldown_timer(delta)
			_check_for_player()
		State.PREPARE:
			_update_prepare(delta)
		State.JUMP:
			_update_jump(delta)
		State.COOLDOWN:
			_update_patrol(delta)
			_update_cooldown_timer(delta)

	move_and_slide()
	_handle_collisions()


# ══════════════════════════════════════════════
#  VITA E DANNO
# ══════════════════════════════════════════════

func take_damage(amount: int) -> void:
	health -= amount
	_hit_flash_timer = hit_flash_duration
	if health <= 0:
		_die()

func _die() -> void:
	queue_free()

func _on_hurtbox_hit(area: Area2D) -> void:
	if area.is_in_group("player_bullet"):
		var dmg = area.get("damage") if area.get("damage") != null else 1
		take_damage(dmg)
		area.queue_free()


# ══════════════════════════════════════════════
#  PATROL
# ══════════════════════════════════════════════

func _update_patrol(delta: float) -> void:
	var offset_x := global_position.x - home_origin.x
	if abs(offset_x) >= patrol_distance and sign(offset_x) == patrol_dir:
		patrol_dir *= -1

	velocity.x         = patrol_speed * patrol_dir
	sprite.flip_h      = patrol_dir > 0
	sprite.speed_scale = 0.8


func _update_cooldown_timer(delta: float) -> void:
	if cooldown_timer <= 0.0:
		return
	cooldown_timer -= delta
	if cooldown_timer < 0.0:
		cooldown_timer = 0.0
	if cooldown_timer == 0.0 and state == State.COOLDOWN:
		state = State.PATROL


func _check_for_player() -> void:
	if cooldown_timer > 0.0:
		return
	if player_in_range != null and is_instance_valid(player_in_range):
		target_player = player_in_range
		_start_prepare()


# ══════════════════════════════════════════════
#  PREPARE  (si "accovaccia" prima di saltare)
# ══════════════════════════════════════════════

func _start_prepare() -> void:
	state         = State.PREPARE
	prepare_timer = prepare_time
	velocity.x    = 0.0
	sprite.speed_scale = 0.3   # rallenta l'animazione → effetto carica

	# Guarda verso il player
	if is_instance_valid(target_player):
		var dx := target_player.global_position.x - global_position.x
		if dx != 0.0:
			patrol_dir    = sign(dx)
			sprite.flip_h = patrol_dir > 0


func _update_prepare(delta: float) -> void:
	velocity.x = 0.0
	prepare_timer -= delta
	if prepare_timer <= 0.0:
		if is_instance_valid(target_player):
			_start_jump()
		else:
			_return_to_patrol()


# ══════════════════════════════════════════════
#  JUMP  (salto verso il player)
# ══════════════════════════════════════════════

func _start_jump() -> void:
	if not is_instance_valid(target_player):
		_return_to_patrol()
		return

	state        = State.JUMP
	_already_hit = false

	var dx := target_player.global_position.x - global_position.x
	patrol_dir    = sign(dx) if dx != 0 else patrol_dir
	sprite.flip_h = patrol_dir > 0
	sprite.speed_scale = 1.8   # animazione più veloce durante il salto

	velocity.x = patrol_dir * jump_speed
	velocity.y = jump_force


func _update_jump(_delta: float) -> void:
	# Il salto finisce quando atterra
	if is_on_floor() and velocity.y >= 0.0:
		_end_jump()


func _end_jump() -> void:
	state          = State.COOLDOWN
	cooldown_timer = attack_cooldown
	velocity.x     = 0.0
	sprite.speed_scale = 0.8


func _return_to_patrol() -> void:
	state          = State.PATROL
	sprite.speed_scale = 0.8
	velocity.x     = 0.0


# ══════════════════════════════════════════════
#  COLLISIONI  (danno al player durante il salto)
# ══════════════════════════════════════════════

func _handle_collisions() -> void:
	if state != State.JUMP or _already_hit:
		return

	for i in range(get_slide_collision_count()):
		var collision := get_slide_collision(i)
		var body      := collision.get_collider()
		if body == null:
			continue

		if body.is_in_group("player"):
			var hit_dir = (body.global_position - global_position).normalized()
			hit_dir.y = 0.0
			hit_dir   = hit_dir.normalized()
			if hit_dir == Vector2.ZERO:
				hit_dir = Vector2(patrol_dir, 0.0)

			if body.has_method("apply_damage"):
				body.apply_damage(damage_to_player)
			if body.has_method("apply_knockback"):
				body.apply_knockback(hit_dir * player_knockback_force)

			_already_hit = true
			_end_jump()
			break


# ══════════════════════════════════════════════
#  DETECTION
# ══════════════════════════════════════════════

func _on_detection_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = body

func _on_detection_body_exited(body: Node2D) -> void:
	if body == player_in_range:
		player_in_range = null
		if state == State.PREPARE:
			_return_to_patrol()
