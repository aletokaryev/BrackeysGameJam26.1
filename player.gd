extends CharacterBody2D

@onready var anim:   AnimatedSprite2D = $Sprite2D
@onready var muzzle: Marker2D         = $Muzzle

# ── Movimento ─────────────────────────────────
const SPEED        = 220.0
const ACCELERATION = 2200.0   # alto = responsivo, basso = scivoloso
const DECELERATION = 2800.0   # alto = si ferma subito
const AIR_CONTROL  = 0.65     # controllo in aria (0-1)
const JUMP_VELOCITY = -460.0

# ── Jump feel ─────────────────────────────────
@export var coyote_time:             float = 0.12
@export var jump_buffer_time:        float = 0.12
@export var fall_gravity_multiplier: float = 1.8
@export var low_jump_multiplier:     float = 2.2
@export var max_fall_speed:          float = 900.0

var coyote_timer:     float = 0.0
var jump_buffer_timer: float = 0.0

# ── Sparo ─────────────────────────────────────
@export var bullet_scene:   PackedScene
@export var shoot_cooldown: float = 0.5
var _shoot_cd_timer: float = 0.0

@export var cooldown_bar: ProgressBar

# ── HUD / Ability UI ──────────────────────────
@export var ability_ui_path: NodePath
@onready var ability_ui: CanvasLayer = get_node_or_null(ability_ui_path)

var equipped_ability: String = ""

# ── Vita ──────────────────────────────────────
@export var max_health: int = 5
var health: int = 0

# ── Invincibilità ─────────────────────────────
@export var invincibility_duration: float = 0.8
var _invincible_timer: float = 0.0

# ── Knockback ─────────────────────────────────
# Il knockback è separato dalla velocity normale
# e decade da solo — non sovrascrive mai il movimento
@export var knockback_decay: float = 1200.0
var _knockback: Vector2 = Vector2.ZERO

func apply_knockback(force: Vector2) -> void:
	_knockback = force
	velocity.y = 0.0   # azzera solo Y per evitare volo

func apply_damage(amount: int) -> void:
	if _invincible_timer > 0.0:
		return
	health = max(health - amount, 0)
	_invincible_timer = invincibility_duration
	_update_health_ui()
	if health <= 0:
		_die()

func heal(amount: int) -> void:
	health = min(health + amount, max_health)
	_update_health_ui()

func _die() -> void:
	get_tree().reload_current_scene()

func _update_health_ui() -> void:
	if ability_ui and ability_ui.has_method("set_health"):
		ability_ui.set_health(health, max_health)

# ── Abilità ───────────────────────────────────
var abilities := {
	"gun": false,
	"gravity_flip": false,
}
var ability_order: Array[String] = ["gun", "gravity_flip"]

func unlock_ability(ability_name: String) -> void:
	abilities[ability_name] = true
	if equipped_ability == "":
		equipped_ability = ability_name
	_update_ability_ui()

func has_ability(ability_name: String) -> bool:
	return abilities.get(ability_name, false)

func _switch_ability() -> void:
	var unlocked: Array[String] = []
	for a in ability_order:
		if abilities.get(a, false):
			unlocked.append(a)
	if unlocked.is_empty():
		return
	if equipped_ability == "" or not unlocked.has(equipped_ability):
		equipped_ability = unlocked[0]
	else:
		var idx := unlocked.find(equipped_ability)
		equipped_ability = unlocked[(idx + 1) % unlocked.size()]
	_update_ability_ui()

func _update_ability_ui() -> void:
	if ability_ui and ability_ui.has_method("set_state"):
		ability_ui.set_state(abilities, equipped_ability)

# ── Mira ──────────────────────────────────────
const AIR_DEADZONE := 30.0
var facing_dir: int = 1
var aim_dir: Vector2 = Vector2.RIGHT

func _update_aim_direction() -> void:
	var stick_vec := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	if stick_vec.length() > 0.2:
		aim_dir = stick_vec.normalized()
	else:
		var mouse_pos := get_global_mouse_position()
		var dir := mouse_pos - muzzle.global_position
		if dir.length() > 0.01:
			aim_dir = dir.normalized()
	if abs(aim_dir.x) > 0.1:
		facing_dir = sign(aim_dir.x)

# ── Animazioni ────────────────────────────────
var current_anim: String = ""

func _set_anim(anim_name: String) -> void:
	if current_anim == anim_name:
		return
	current_anim = anim_name
	anim.play(anim_name)
	anim.speed_scale = 1.0


# ══════════════════════════════════════════════
#  READY
# ══════════════════════════════════════════════

func _ready() -> void:
	health = max_health
	add_to_group("player")
	_set_anim("idle")
	call_deferred("_sync_hud_initial")

func _sync_hud_initial() -> void:
	_update_ability_ui()
	_update_health_ui()


# ══════════════════════════════════════════════
#  LOOP PRINCIPALE
# ══════════════════════════════════════════════

func _physics_process(delta: float) -> void:

	# ── Invincibilità flash ────────────────────
	if _invincible_timer > 0.0:
		_invincible_timer -= delta
		anim.modulate.a = 0.3 if fmod(_invincible_timer, 0.2) > 0.1 else 1.0
		if _invincible_timer <= 0.0:
			anim.modulate.a = 1.0

	# ── Input abilità e debug ──────────────────
	if Input.is_action_just_pressed("debug_damage"):
		apply_damage(1)
	if Input.is_action_just_pressed("switch_ability"):
		_switch_ability()
	if Input.is_action_just_pressed("shifter"):
		activate_shifter()

	# ── Cooldown sparo ─────────────────────────
	_shoot_cd_timer = max(_shoot_cd_timer - delta, 0.0)
	if cooldown_bar and shoot_cooldown > 0.0:
		cooldown_bar.value = clamp(1.0 - (_shoot_cd_timer / shoot_cooldown), 0.0, 1.0)

	# ── Coyote time ────────────────────────────
	if is_on_floor():
		coyote_timer = coyote_time
	else:
		coyote_timer = max(coyote_timer - delta, 0.0)

	# ── Jump buffer ────────────────────────────
	if Input.is_action_just_pressed("salto"):
		jump_buffer_timer = jump_buffer_time
	else:
		jump_buffer_timer = max(jump_buffer_timer - delta, 0.0)

	# ── Gravità variabile ──────────────────────
	if not is_on_floor():
		var gravity := get_gravity()
		if velocity.y > 0.0:
			gravity *= fall_gravity_multiplier        # cade più pesante
		elif velocity.y < 0.0 and not Input.is_action_pressed("salto"):
			gravity *= low_jump_multiplier            # salto corto se lasci subito
		velocity += gravity * delta
		velocity.y = min(velocity.y, max_fall_speed)
	else:
		if velocity.y > 0.0:
			velocity.y = 0.0

	# ── Salto ──────────────────────────────────
	if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
		velocity.y    = JUMP_VELOCITY
		jump_buffer_timer = 0.0
		coyote_timer  = 0.0

	# ── Movimento orizzontale ──────────────────
	var direction := Input.get_axis("dietro", "avanti")
	var on_floor  := is_on_floor()

	# Se il knockback è attivo non accettiamo input orizzontale
	if _knockback != Vector2.ZERO:
		_knockback = _knockback.move_toward(Vector2.ZERO, knockback_decay * delta)
		velocity.x = _knockback.x
	else:
		var accel_mult := AIR_CONTROL if not on_floor else 1.0
		if direction != 0:
			velocity.x = move_toward(
				velocity.x,
				direction * SPEED,
				ACCELERATION * accel_mult * delta
			)
		else:
			# A terra frena subito, in aria mantiene il momentum
			var decel := DECELERATION if on_floor else DECELERATION * 0.15
			velocity.x = move_toward(velocity.x, 0.0, decel * delta)

	move_and_slide()

	# ── Aggiorna on_floor dopo move_and_slide ──
	on_floor = is_on_floor()

	# ── Animazioni ────────────────────────────
	if not on_floor:
		if velocity.y < -AIR_DEADZONE:
			_set_anim("jump")
		elif velocity.y > AIR_DEADZONE:
			_set_anim("fall")
	else:
		if abs(velocity.x) > 10.0:
			_set_anim("walk")
			anim.speed_scale = clamp(abs(velocity.x) / SPEED, 0.5, 1.2)
		else:
			_set_anim("idle")

	# ── Mira e flip ───────────────────────────
	_update_aim_direction()
	anim.flip_h = facing_dir < 0

	# ── Sparo ─────────────────────────────────
	if Input.is_action_just_pressed("shoot") \
		and _shoot_cd_timer == 0.0 \
		and equipped_ability == "gun" \
		and abilities.get("gun", false):
		shoot()
		_shoot_cd_timer = shoot_cooldown


# ══════════════════════════════════════════════
#  ABILITÀ
# ══════════════════════════════════════════════

func activate_shifter() -> void:
	if equipped_ability == "gravity_flip" and abilities.get("gravity_flip", false):
		get_tree().call_group("shiftable", "try_shift", global_position)

func shoot() -> void:
	if bullet_scene == null:
		return
	var bullet := bullet_scene.instantiate()
	bullet.global_position = muzzle.global_position
	var dir := aim_dir
	if dir == Vector2.ZERO:
		dir = Vector2(facing_dir, 0).normalized()
	bullet.velocity = dir * bullet.speed
	bullet.rotation  = dir.angle()
	get_tree().current_scene.add_child(bullet)
