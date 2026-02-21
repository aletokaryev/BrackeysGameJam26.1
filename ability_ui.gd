extends CanvasLayer

@onready var gun_icon: TextureRect = $HBoxContainer/GunIcon
@onready var remote_icon: TextureRect = $HBoxContainer/RemoteIcon
@onready var health_bar: ProgressBar = $HealthBar

func _ready() -> void:
	# finché il player non manda stato abilità, icone nascoste
	if gun_icon:
		gun_icon.visible = false
	if remote_icon:
		remote_icon.visible = false
	# la barra vita resta visibile, ma niente colore forzato qui;
	# verrà inizializzata da set_health()
	if health_bar:
		health_bar.show()

# ---- ABILITÀ ------------------------------------------------

func set_state(abilities: Dictionary, equipped: String) -> void:
	_set_icon(gun_icon, "gun", abilities, equipped)
	_set_icon(remote_icon, "gravity_flip", abilities, equipped)

func _set_icon(icon: TextureRect, ability_name: String, abilities: Dictionary, equipped: String) -> void:
	if icon == null:
		return

	var unlocked = abilities.get(ability_name, false)

	icon.visible = unlocked
	if not unlocked:
		return

	if ability_name == equipped:
		icon.modulate = Color(1, 1, 1, 1)      # pieno
	else:
		icon.modulate = Color(1, 1, 1, 0.3)    # “spenta”

# ---- VITA ---------------------------------------------------

func set_health(current: int, max_health: int) -> void:
	if health_bar == null:
		return

	max_health = max(max_health, 1)
	current = clamp(current, 0, max_health)

	health_bar.max_value = max_health
	health_bar.value = current

	# t = 1 → full HP; t = 0 → morto
	var t: float = float(current) / float(max_health)

	var full_col := Color(1.0, 0.0, 0.0)      # rosso pieno
	var empty_col := Color(0.3, 0.3, 0.3)     # grigio scuro

	health_bar.modulate = full_col.lerp(empty_col, 1.0 - t)
