extends Control

@onready var play_button: Button = $VBoxContainer/Play
@onready var quit_button: Button = $VBoxContainer/Quit
@onready var music: AudioStreamPlayer = $Music
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var title: Label = $VBoxContainer/Title

@export var game_scene: PackedScene

func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	play_button.mouse_entered.connect(_on_button_hover.bind(play_button))
	quit_button.mouse_entered.connect(_on_button_hover.bind(quit_button))
	play_button.mouse_exited.connect(_on_button_exit.bind(play_button))
	quit_button.mouse_exited.connect(_on_button_exit.bind(quit_button))

	if music:
		music.play()

	_fade_in()

func _fade_in() -> void:
	modulate = Color(1,1,1,0)
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.6)

func _on_play_pressed() -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	await tween.finished

	get_tree().change_scene_to_packed(game_scene)

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_button_hover(button: Button) -> void:
	var tween = create_tween()
	tween.tween_property(button, "scale", Vector2(1.1,1.1), 0.1)

func _on_button_exit(button: Button) -> void:
	var tween = create_tween()
	tween.tween_property(button, "scale", Vector2(1,1), 0.1)
