extends CharacterBody2D

@onready var character_body_2d: CharacterBody2D = $"."
@onready var anim: AnimatedSprite2D = $Sprite2D
@onready var muzzle: Marker2D = $Muzzle

const SPEED = 300.0
const JUMP_VELOCITY = -450.0

@export var bullet_scene: PackedScene

@export var shoot_cooldown: float = 0.5
var _shoot_cd_timer: float = 0.0

@export var cooldown_bar: ProgressBar


@export var knockback_decay: float = 800.0
var knockback: Vector2 = Vector2.ZERO

func apply_knockback(force: Vector2) -> void:
	velocity.y = 0.0 
	knockback = force

var facing_dir: int = 1 

var abilities := {
	"gun" : false,
	# "gravity_flip" : false,
	# "light" : false,
}

func unlock_ability(name: String) -> void:
	abilities[name] = true
	print("Abilità sbloccata: ", name)

func has_ability(name: String) -> bool:
	return abilities.get(name, false)

func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("shifter"):
		activate_shifter()
	
	# COOLDOWN SPARO ---------------------------------
	if _shoot_cd_timer > 0.0:
		_shoot_cd_timer -= delta
		if _shoot_cd_timer < 0.0:
			_shoot_cd_timer = 0.0

	if cooldown_bar and shoot_cooldown > 0.0:
		var ratio := 1.0 - (_shoot_cd_timer / shoot_cooldown)
		ratio = clamp(ratio, 0.0, 1.0)
		cooldown_bar.value = ratio

	# FISICA BASE ------------------------------------
	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_just_pressed("salto") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var direction := Input.get_axis("dietro", "avanti")
	if direction != 0:
		velocity.x = direction * SPEED
		facing_dir = direction
		anim.play("walk")
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		if is_on_floor():
			anim.play("idle")

	anim.flip_h = facing_dir < 0

	# APPLICA IL KNOCKBACK QUI -----------------------
	if knockback != Vector2.ZERO:
		velocity += knockback
		knockback = knockback.move_toward(Vector2.ZERO, knockback_decay * delta)

	# SPARO ------------------------------------------
	if Input.is_action_just_pressed("shoot") and _shoot_cd_timer == 0.0 and has_ability("gun"):
		shoot()
		_shoot_cd_timer = shoot_cooldown

	move_and_slide()


func activate_shifter() -> void:
	get_tree().call_group("shiftable", "shift")


func shoot() -> void:
	if bullet_scene == null:
		return

	var bullet := bullet_scene.instantiate()

	bullet.global_position = muzzle.global_position

	var dir: Vector2 = Vector2(facing_dir, 0).normalized()

	bullet.velocity = dir * bullet.speed

	if facing_dir == 1:
		bullet.rotation = 0.0
	else:
		bullet.rotation = PI

	get_tree().current_scene.add_child(bullet)
