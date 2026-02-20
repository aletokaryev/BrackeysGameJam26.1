extends CanvasLayer

@export var player: Node2D
@onready var darkness_rect: ColorRect = $DarknessRect

func _process(delta: float) -> void:
	if player == null:
		return

	var mat := darkness_rect.material
	if mat is ShaderMaterial:
		var vp_size = get_viewport().get_visible_rect().size
		var screen_pos = player.get_global_transform_with_canvas().origin
		var uv = screen_pos / vp_size   # da pixel a [0..1]
		mat.set_shader_parameter("light_pos", uv)
