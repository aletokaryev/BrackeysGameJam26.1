extends CharacterBody2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection_area: Area2D   = $DetectionArea

@export var patrol_distance:   float = 96.0
@export var patrol_speed:      float = 40.0
@export var wiggle_amplitude:  float = 8.0
@export var wiggle_speed:      float = 4.0

@export var charge_time:         float = 0.35
@export var dive_speed:          float = 400.0
@export var attack_cooldown:     float = 1.5

@export var bat_knockback_speed:   float = 280.0
@export var bat_knockback_decay:   float = 600.0
@export var player_knockback_force: float = 320.0

enum State { PATROL, CHARGE, DIVE, COOLDOWN }

var state: State = State.PATROL

var home_origin: Vector2 
var patrol_dir: int = -1   

var wiggle_phase: float = 0.0
var charge_timer: float = 0.0
var cooldown_timer: float = 0.0

var dive_dir: Vector2 = Vector2.ZERO

var bat_knockback: Vector2 = Vector2.ZERO

var player_in_range: Node2D = null
var target_player:   Node2D = null


func _ready() -> void:
	home_origin  = global_position
	wiggle_phase = randf() * TAU

	sprite.play("ali")
	sprite.speed_scale = 1.0
	sprite.flip_h = patrol_dir > 0

	detection_area.body_entered.connect(_on_detection_body_entered)
	detection_area.body_exited.connect(_on_detection_body_exited)


# ══════════════════════════════════════════════
func _physics_process(delta: float) -> void:
	if bat_knockback != Vector2.ZERO:
		velocity += bat_knockback
		bat_knockback = bat_knockback.move_toward(Vector2.ZERO, bat_knockback_decay * delta)

	match state:
		State.PATROL:
			_update_patrol(delta)
			_update_cooldown_timer(delta)
			_check_for_player()
		State.CHARGE:
			_update_charge(delta)
		State.DIVE:
			_update_dive(delta)
		State.COOLDOWN:
			_update_patrol(delta)
			_update_cooldown_timer(delta)

	move_and_slide()
	_handle_collisions()



func _update_patrol(delta: float) -> void:
	var offset_x := global_position.x - home_origin.x
	if abs(offset_x) >= patrol_distance and sign(offset_x) == patrol_dir:
		patrol_dir *= -1

	velocity.x = patrol_speed * patrol_dir

	wiggle_phase += wiggle_speed * delta
	var target_y := home_origin.y + sin(wiggle_phase) * wiggle_amplitude
	velocity.y   = (target_y - global_position.y) / delta

	sprite.flip_h      = patrol_dir > 0
	sprite.speed_scale = 1.0


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
		state         = State.CHARGE
		charge_timer  = charge_time

		sprite.speed_scale = 2.5

		var dx := target_player.global_position.x - global_position.x
		if dx != 0.0:
			patrol_dir    = sign(dx)
			sprite.flip_h = patrol_dir > 0


func _update_charge(delta: float) -> void:
	velocity = Vector2.ZERO

	charge_timer -= delta
	if charge_timer <= 0.0:
		if is_instance_valid(target_player):
			_start_dive()
		else:
			_return_to_patrol()


func _start_dive() -> void:
	if not is_instance_valid(target_player):
		_return_to_patrol()
		return

	dive_dir = (target_player.global_position - global_position).normalized()
	if dive_dir == Vector2.ZERO:
		dive_dir = Vector2(patrol_dir, 0.0)

	if abs(dive_dir.x) > 0.01:
		patrol_dir    = sign(dive_dir.x)
	sprite.flip_h      = patrol_dir > 0
	sprite.speed_scale = 3.0

	state    = State.DIVE
	velocity = dive_dir * dive_speed


func _update_dive(_delta: float) -> void:
	if (global_position - home_origin).length() > patrol_distance * 3.0:
		_end_dive()
		return


func _end_dive() -> void:
	state          = State.COOLDOWN
	cooldown_timer = attack_cooldown
	sprite.speed_scale = 1.0
	velocity = Vector2.ZERO


func _return_to_patrol() -> void:
	state              = State.PATROL
	sprite.speed_scale = 1.0
	velocity           = Vector2.ZERO


func _handle_collisions() -> void:
	for i in range(get_slide_collision_count()):
		var collision := get_slide_collision(i)
		var body      := collision.get_collider()
		if body == null:
			continue

		if state == State.DIVE:
			if body.is_in_group("player"):
				var hit_dir = (body.global_position - global_position).normalized()
				if hit_dir == Vector2.ZERO:
					hit_dir = Vector2(patrol_dir, 0.0)
				hit_dir.y = clamp(hit_dir.y, -0.2, 0.5)
				hit_dir = hit_dir.normalized()
				if body.has_method("apply_knockback"):
					body.apply_knockback(hit_dir * player_knockback_force)
				bat_knockback = -hit_dir * bat_knockback_speed

				_end_dive()
				break

			else:
				_end_dive()
				break


func _on_detection_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = body


func _on_detection_body_exited(body: Node2D) -> void:
	if body == player_in_range:
		player_in_range = null

		if state == State.CHARGE:
			_return_to_patrol()
