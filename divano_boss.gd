extends CharacterBody2D

# ─────────────────────────────────────────────
#  DIVANO BOSS
#  Cutscene → Fase 1 (slam + bat) → Fase 2 (slam + bat + slime + scossa)
# ─────────────────────────────────────────────

@onready var sprite:         AnimatedSprite2D  = $Sprite
@onready var detection_area: Area2D            = $DetectionArea
@onready var hurtbox:        Area2D            = $HurtBox
@onready var contact_damage: Area2D            = $ContactDamage
@onready var shadow:         Sprite2D          = $Shadow
@onready var spawn_left:     Marker2D          = $SpawnLeft
@onready var spawn_right:    Marker2D          = $SpawnRight
@onready var spawn_center:   Marker2D          = $SpawnCenter
@onready var floor_ray:      RayCast2D         = $FloorRay
@onready var music_player:   AudioStreamPlayer = $AudioStreamPlayer

@export var bat_scene:              PackedScene
@export var slime_projectile_scene: PackedScene
@export var boss_music:             AudioStream

# ── Vita ──────────────────────────────────────
@export var max_health: int = 20
var health: int = 0
var _phase: int = 1

# ── Hit flash ─────────────────────────────────
@export var hit_flash_duration: float = 0.15
var _hit_flash_timer: float = 0.0

# ── Danno ─────────────────────────────────────
@export var slam_damage:           int   = 2
@export var slam_hit_radius:       float = 80.0
@export var contact_damage_amount: int   = 1

# ── Slam ──────────────────────────────────────
@export var slam_jump_force:    float = -1500.0
@export var slam_gravity_scale: float = 4.0
@export var slam_cooldown:      float = 3.0

# ── Bat spawn ─────────────────────────────────
@export var bat_spawn_cooldown: float = 5.0
@export var bats_per_spawn:     int   = 2

# ── Slime spawn (fase 2) ──────────────────────
@export var slime_spawn_cooldown: float = 6.0

# ── Scossa (fase 2) ───────────────────────────
@export var scossa_cooldown:    float = 5.0
@export var scossa_projectiles: int   = 5
@export var scossa_shake_time:  float = 0.6

# ── Camera shake ──────────────────────────────
@export var slam_shake_strength:   float = 12.0
@export var slam_shake_duration:   float = 0.4
@export var scossa_shake_strength: float = 6.0
@export var scossa_shake_duration: float = 0.3

# ── Cutscene ──────────────────────────────────
@export var cutscene_walk_speed:   float = 80.0   # velocità player durante la cutscene
@export var cutscene_stop_dist:    float = 130.0   # distanza a cui il player si ferma
@export var cutscene_look_time:    float = 2.0    # secondi che "guarda" il boss
@export var cutscene_pause_time:   float = 0.6    # pausa drammatica prima del wake up

enum State {
	SLEEPING,
	CUTSCENE,
	WAKING_UP,
	IDLE,
	SLAM_RISING,
	SLAM_FALLING,
	SLAM_LAND,
	SCOSSA,
	COOLDOWN
}

var state: State = State.SLEEPING
var player: Node2D = null

# Timer cutscene
var _cutscene_step:  int   = 0
var _cutscene_timer: float = 0.0

# Timer attacchi
var _slam_timer:     float = 0.0
var _bat_timer:      float = 0.0
var _scossa_timer:   float = 0.0
var _slime_timer:    float = 0.0
var _cooldown_timer: float = 0.0
var _state_timer:    float = 0.0

var _home_x:               float = 0.0
var _original_mask:        int   = 0
var _original_player_mask: int   = 0


func _ready() -> void:
	health         = max_health
	_home_x        = global_position.x
	_original_mask = collision_mask

	add_to_group("enemy")
	add_to_group("boss")

	sprite.play("idle")
	shadow.visible   = false
	shadow.top_level = true

	contact_damage.monitoring  = false
	contact_damage.monitorable = false

	detection_area.body_entered.connect(_on_detection_body_entered)
	hurtbox.area_entered.connect(_on_hurtbox_hit)
	contact_damage.body_entered.connect(_on_contact_body_entered)

	_slam_timer   = slam_cooldown
	_bat_timer    = bat_spawn_cooldown * 0.5
	_scossa_timer = scossa_cooldown
	_slime_timer  = slime_spawn_cooldown


func _physics_process(delta: float) -> void:
	# Hit flash
	if _hit_flash_timer > 0.0:
		_hit_flash_timer -= delta
		sprite.modulate = Color(1, 0.3, 0.3) if fmod(_hit_flash_timer, 0.06) > 0.03 else Color.WHITE
		if _hit_flash_timer <= 0.0:
			sprite.modulate = Color.WHITE

	# Gravità boss (solo quando non è in cutscene/sleeping)
	if state != State.SLEEPING and state != State.CUTSCENE:
		if not is_on_floor():
			var grav_mult := slam_gravity_scale if state == State.SLAM_FALLING else 1.0
			velocity += get_gravity() * grav_mult * delta
		else:
			if velocity.y > 0.0:
				velocity.y = 0.0

	match state:
		State.SLEEPING:     pass
		State.CUTSCENE:     _update_cutscene(delta)
		State.WAKING_UP:    _update_waking_up(delta)
		State.IDLE:         _update_idle(delta)
		State.SLAM_RISING:  _update_slam_rising(delta)
		State.SLAM_FALLING: _update_slam_falling(delta)
		State.SLAM_LAND:    _update_slam_land(delta)
		State.SCOSSA:       _update_scossa(delta)
		State.COOLDOWN:     _update_cooldown(delta)

	if state != State.SLEEPING and state != State.CUTSCENE:
		move_and_slide()
	_update_shadow()


# ══════════════════════════════════════════════
#  CUTSCENE
# ══════════════════════════════════════════════

func _start_cutscene() -> void:
	state           = State.CUTSCENE
	_cutscene_step  = 0
	_cutscene_timer = 0.0
	player.set_process_input(false)
	player.set_physics_process(false)
	# Disabilita collisione boss-player durante la cutscene
	_original_player_mask = player.collision_mask
	player.collision_mask = player.collision_mask & ~(1 << 2)   # ignora layer 3 (enemy/boss)
	collision_mask        = _original_mask & ~(1 << 1)          # ignora layer 2 (player)


func _update_cutscene(delta: float) -> void:
	_cutscene_timer -= delta

	match _cutscene_step:

		0:  # ── Player cammina verso il boss ──────────
			var dx  = global_position.x - player.global_position.x
			var dir = sign(dx)
			player.velocity.x  = dir * cutscene_walk_speed
			player.velocity    += player.get_gravity() * delta
			player.velocity.y   = min(player.velocity.y, 900.0)
			player.move_and_slide()
			# Animazione e flip
			player.anim.flip_h = dir < 0
			if player.anim.animation != "walk":
				player.anim.play("walk")
			# Vicino abbastanza → si ferma
			if abs(dx) < cutscene_stop_dist:
				player.velocity = Vector2.ZERO
				player.anim.play("idle")
				# Guarda verso il boss
				player.anim.flip_h = player.global_position.x > global_position.x
				_cutscene_step  = 1
				_cutscene_timer = cutscene_look_time

		1:  # ── Player guarda il boss, un po' confuso ─
			# Gira la testa avanti/indietro ogni 0.5s → effetto "huh?"
			if fmod(_cutscene_timer, 0.5) > 0.25:
				player.anim.flip_h = player.global_position.x > global_position.x
			else:
				player.anim.flip_h = player.global_position.x < global_position.x
			if _cutscene_timer <= 0.0:
				# Fissa lo sguardo sul boss
				player.anim.flip_h = player.global_position.x > global_position.x
				_cutscene_step  = 2
				_cutscene_timer = cutscene_pause_time

		2:  # ── Pausa drammatica → inizia la boss fight ─
			if _cutscene_timer <= 0.0:
				_end_cutscene()


func _end_cutscene() -> void:
	# Ripristina collisioni
	player.collision_mask = _original_player_mask
	collision_mask        = _original_mask
	# Riabilita player
	player.set_process_input(true)
	player.set_physics_process(true)
	player.anim.flip_h = player.global_position.x > global_position.x
	if boss_music != null:
		music_player.stream = boss_music
		music_player.play()
	_start_wake_up()


# ══════════════════════════════════════════════
#  VITA E DANNO
# ══════════════════════════════════════════════

func take_damage(amount: int) -> void:
	if state == State.SLEEPING or state == State.CUTSCENE or state == State.WAKING_UP:
		return
	health -= amount
	_hit_flash_timer = hit_flash_duration
	if health <= 0:
		_die()
		return
	if _phase == 1 and health <= max_health / 2:
		_start_phase_2()

func _die() -> void:
	if boss_music != null:
		music_player.stop()
	shadow.queue_free()
	queue_free()

func _on_hurtbox_hit(area: Area2D) -> void:
	if area.is_in_group("player_bullet"):
		var dmg = area.get("damage") if area.get("damage") != null else 1
		take_damage(dmg)
		area.queue_free()

func _on_contact_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		if body.has_method("apply_damage"):
			body.apply_damage(contact_damage_amount)


# ══════════════════════════════════════════════
#  CAMERA SHAKE
# ══════════════════════════════════════════════

func _camera_shake(strength: float, duration: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	var tween := get_tree().create_tween()
	var steps := int(duration / 0.05)
	for i in range(steps):
		tween.tween_property(camera, "offset", Vector2(
			randf_range(-strength, strength),
			randf_range(-strength, strength)
		), 0.05)
	tween.tween_property(camera, "offset", Vector2.ZERO, 0.05)


# ══════════════════════════════════════════════
#  WAKE UP
# ══════════════════════════════════════════════

func _start_wake_up() -> void:
	state = State.WAKING_UP
	sprite.play("wake_up")
	if sprite.animation_finished.is_connected(_on_wake_up_finished):
		sprite.animation_finished.disconnect(_on_wake_up_finished)
	sprite.animation_finished.connect(_on_wake_up_finished, CONNECT_ONE_SHOT)

func _on_wake_up_finished() -> void:
	_enter_idle()

func _update_waking_up(_delta: float) -> void:
	velocity.x = 0.0


# ══════════════════════════════════════════════
#  IDLE
# ══════════════════════════════════════════════

func _enter_idle() -> void:
	state = State.IDLE
	velocity.x = 0.0

func _update_idle(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return

	_slam_timer = max(_slam_timer - delta, 0.0)
	_bat_timer  = max(_bat_timer  - delta, 0.0)
	if _phase == 2:
		_scossa_timer = max(_scossa_timer - delta, 0.0)
		_slime_timer  = max(_slime_timer  - delta, 0.0)

	# Priorità: scossa > slam > slime > bat
	if _phase == 2 and _scossa_timer <= 0.0:
		_start_scossa()
	elif _slam_timer <= 0.0:
		_start_slam()
	elif _phase == 2 and _slime_timer <= 0.0:
		_spawn_slime()
		_slime_timer = slime_spawn_cooldown
	elif _bat_timer <= 0.0:
		_spawn_bats()
		_bat_timer = bat_spawn_cooldown


# ══════════════════════════════════════════════
#  SLAM — stile Hollow Knight
# ══════════════════════════════════════════════

func _start_slam() -> void:
	if player == null or not is_instance_valid(player):
		return
	state          = State.SLAM_RISING
	_slam_timer    = slam_cooldown
	velocity.y     = slam_jump_force
	velocity.x     = 0.0
	shadow.visible = true
	# Boss e player si ignorano fisicamente durante il volo
	collision_mask        = _original_mask & ~(1 << 1)
	_original_player_mask = player.collision_mask
	player.collision_mask = player.collision_mask & ~(1 << 2)


func _update_slam_rising(_delta: float) -> void:
	if player != null and is_instance_valid(player):
		var dx := player.global_position.x - global_position.x
		velocity.x = move_toward(velocity.x, sign(dx) * 80.0, 20.0)
	if velocity.y >= 0.0:
		state      = State.SLAM_FALLING
		velocity.x = 0.0


func _update_slam_falling(_delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 30.0)
	if is_on_floor():
		_do_slam_land()


func _do_slam_land() -> void:
	state    = State.SLAM_LAND
	velocity = Vector2.ZERO
	collision_mask = _original_mask
	if player != null and is_instance_valid(player):
		player.collision_mask = _original_player_mask
	shadow.visible = false
	_state_timer   = 0.6
	_camera_shake(slam_shake_strength, slam_shake_duration)
	if player != null and is_instance_valid(player):
		var dist := global_position.distance_to(player.global_position)
		if dist <= slam_hit_radius:
			if player.has_method("apply_damage"):
				player.apply_damage(slam_damage)


func _update_slam_land(delta: float) -> void:
	_state_timer -= delta
	if _state_timer <= 0.0:
		_enter_idle()


# ══════════════════════════════════════════════
#  SCOSSA (fase 2)
# ══════════════════════════════════════════════

func _start_scossa() -> void:
	state         = State.SCOSSA
	_scossa_timer = scossa_cooldown
	_state_timer  = scossa_shake_time
	velocity.x    = 0.0
	var tween := get_tree().create_tween()
	tween.set_loops(int(scossa_shake_time / 0.1))
	tween.tween_property(sprite, "position:x",  5.0, 0.05)
	tween.tween_property(sprite, "position:x", -5.0, 0.05)
	tween.finished.connect(func(): sprite.position.x = 0.0, CONNECT_ONE_SHOT)


func _update_scossa(delta: float) -> void:
	_state_timer -= delta
	if _state_timer <= 0.0:
		sprite.position.x = 0.0
		_do_scossa()
		_enter_idle()


func _do_scossa() -> void:
	if slime_projectile_scene == null:
		return
	_camera_shake(scossa_shake_strength, scossa_shake_duration)
	for i in range(scossa_projectiles):
		var t     := float(i) / float(scossa_projectiles - 1)
		var angle := deg_to_rad(-135.0 + 270.0 * t)
		var dir   := Vector2(sin(angle), -cos(angle))
		var proj  := slime_projectile_scene.instantiate()
		proj.global_position = global_position
		proj.launch(dir)
		get_tree().current_scene.add_child(proj)


# ══════════════════════════════════════════════
#  SPAWN NEMICI
# ══════════════════════════════════════════════

func _spawn_bats() -> void:
	if bat_scene == null:
		return
	if get_tree().get_nodes_in_group("boss_bat").size() > 0:
		return
	var points := [spawn_left.global_position, spawn_right.global_position]
	for i in range(bats_per_spawn):
		var bat := bat_scene.instantiate()
		bat.global_position = points[i % points.size()]
		get_tree().current_scene.add_child(bat)
		bat.add_to_group("boss_bat")
	_bat_timer = bat_spawn_cooldown


func _spawn_slime() -> void:
	if slime_projectile_scene == null or player == null:
		return
	var proj := slime_projectile_scene.instantiate()
	proj.global_position = spawn_center.global_position
	var dir := (player.global_position - spawn_center.global_position).normalized()
	proj.launch(dir)
	get_tree().current_scene.add_child(proj)


# ══════════════════════════════════════════════
#  FASE 2
# ══════════════════════════════════════════════

func _start_phase_2() -> void:
	_phase   = 2
	state    = State.WAKING_UP
	velocity = Vector2.ZERO
	sprite.play("wake_up")
	if sprite.animation_finished.is_connected(_on_wake_up_finished):
		sprite.animation_finished.disconnect(_on_wake_up_finished)
	if sprite.animation_finished.is_connected(_on_phase2_wake_finished):
		sprite.animation_finished.disconnect(_on_phase2_wake_finished)
	sprite.animation_finished.connect(_on_phase2_wake_finished, CONNECT_ONE_SHOT)

func _on_phase2_wake_finished() -> void:
	sprite.play("fase2")
	_enter_idle()


# ══════════════════════════════════════════════
#  COOLDOWN
# ══════════════════════════════════════════════

func _update_cooldown(delta: float) -> void:
	_cooldown_timer -= delta
	if _cooldown_timer <= 0.0:
		_enter_idle()


# ══════════════════════════════════════════════
#  OMBRA
# ══════════════════════════════════════════════

func _update_shadow() -> void:
	if not shadow.visible:
		return
	if floor_ray.is_colliding():
		shadow.global_position = Vector2(
			global_position.x,
			floor_ray.get_collision_point().y
		)
	else:
		shadow.global_position.x = global_position.x
	var height       = shadow.global_position.y - global_position.y
	var scale_factor = clamp(height / 300.0, 0.1, 1.0)
	shadow.scale      = Vector2(scale_factor, scale_factor * 0.3)


# ══════════════════════════════════════════════
#  DETECTION
# ══════════════════════════════════════════════

func _on_detection_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and state == State.SLEEPING:
		player = body
		_start_cutscene()
