extends Node2D

signal cache_ready

var _viewport: SubViewport
var _sprite: Sprite2D
var _generation: int = 0
var _raster_scale: float = 1.0


func _ready() -> void:
	_ensure_nodes()


## Renders a deterministic CanvasItem once, then reuses its texture without
## replaying the source's individual canvas commands every visible frame.
func rebuild(
	painter: Node2D,
	bounds: Rect2,
	raster_scale: float = 1.0
) -> void:
	_ensure_nodes()
	_generation += 1
	var generation := _generation
	_sprite.visible = false
	_raster_scale = clampf(raster_scale, 0.25, 2.0)

	for child in _viewport.get_children():
		_viewport.remove_child(child)
		child.free()

	var pixel_bounds := _snap_bounds_to_pixels(bounds)
	var texture_size := Vector2i(
		maxi(roundi(pixel_bounds.size.x * _raster_scale), 1),
		maxi(roundi(pixel_bounds.size.y * _raster_scale), 1)
	)
	var effective_scale := Vector2(texture_size) / pixel_bounds.size
	_viewport.size = texture_size
	painter.position = -pixel_bounds.position * effective_scale
	painter.scale = effective_scale
	_viewport.add_child(painter)
	_sprite.position = pixel_bounds.position
	_sprite.scale = Vector2.ONE / effective_scale
	_sprite.texture = _viewport.get_texture()
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_finish_capture(generation)


func invalidate() -> void:
	_generation += 1
	if is_instance_valid(_sprite):
		_sprite.visible = false


func is_cache_visible() -> bool:
	return is_instance_valid(_sprite) and _sprite.visible


func get_cache_size() -> Vector2i:
	if not is_instance_valid(_viewport):
		return Vector2i.ZERO
	return _viewport.size


func get_raster_scale() -> float:
	return _raster_scale


func _ensure_nodes() -> void:
	if is_instance_valid(_viewport):
		return

	_viewport = SubViewport.new()
	_viewport.name = "StaticRenderViewport"
	_viewport.transparent_bg = true
	_viewport.disable_3d = true
	_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)

	_sprite = Sprite2D.new()
	_sprite.name = "CachedVisual"
	_sprite.centered = false
	_sprite.show_behind_parent = true
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.visible = false
	add_child(_sprite)


func _finish_capture(generation: int) -> void:
	# Keep the immediate CanvasItem path visible through two complete process
	# frames so the render target is populated before the cached sprite replaces
	# it, including on single-threaded web builds.
	await get_tree().process_frame
	await get_tree().process_frame
	if generation != _generation or not is_instance_valid(_viewport):
		return
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_sprite.visible = true
	cache_ready.emit()


func _snap_bounds_to_pixels(bounds: Rect2) -> Rect2:
	var snapped_position := Vector2(
		floorf(bounds.position.x),
		floorf(bounds.position.y)
	)
	var snapped_end := Vector2(
		ceilf(bounds.end.x),
		ceilf(bounds.end.y)
	)
	return Rect2(snapped_position, snapped_end - snapped_position)
