extends Node

const LOGICAL_SIZE := Vector2(1920.0, 1080.0)

var _content_root: Control
var _canvas_layer: CanvasLayer


func _ready() -> void:
	_content_root = get_parent() as Control
	if _content_root == null:
		push_error("LogicalUiScaler must be a child of the UI's root Control.")
		return
	_canvas_layer = _content_root.get_parent() as CanvasLayer
	get_viewport().size_changed.connect(_apply_logical_layout)
	_apply_logical_layout()


func _exit_tree() -> void:
	var viewport := get_viewport()
	if (
		viewport != null
		and viewport.size_changed.is_connected(_apply_logical_layout)
	):
		viewport.size_changed.disconnect(_apply_logical_layout)


func _apply_logical_layout() -> void:
	if _content_root == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	var uniform_scale := minf(
		viewport_size.x / LOGICAL_SIZE.x,
		viewport_size.y / LOGICAL_SIZE.y
	)
	var display_scale := Vector2.ONE * maxf(uniform_scale, 0.01)
	var display_offset := (
		viewport_size - LOGICAL_SIZE * display_scale
	) * 0.5

	_content_root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_content_root.position = Vector2.ZERO
	_content_root.size = LOGICAL_SIZE
	if _canvas_layer != null:
		_content_root.scale = Vector2.ONE
		_canvas_layer.scale = display_scale
		_canvas_layer.offset = display_offset
	else:
		_content_root.scale = display_scale
		_content_root.position = display_offset
