class_name PlayerController
extends CharacterBody2D

@export_category("Forward Movement")
## Normal automatic forward travel speed in world pixels per second.
@export var base_forward_speed: float = 260.0
## Target forward speed, in pixels per second, while speed_up is held.
@export var boosted_forward_speed: float = 420.0
## Target forward speed, in pixels per second, while slow_down is held. Values
## at or below zero are clamped to preserve forward movement.
@export var slowed_forward_speed: float = 110.0
## Rate, in pixels per second squared, used to approach any target forward
## speed instead of changing speed instantly.
@export var forward_acceleration: float = 360.0

@export_category("Lateral Movement")
## Maximum left/right travel speed in world pixels per second.
@export var lateral_speed: float = 260.0
## Rate, in pixels per second squared, used to approach the requested lateral
## velocity and return to rest.
@export var lateral_acceleration: float = 900.0
## Playable half-width measured from road center in world pixels. InfiniteWorld
## replaces this at startup with its shared WorldChunkConfig road width.
@export var road_half_width: float = 224.0
## Margin, in world pixels, kept between the player's center and each road edge
## so the visual and collision shape remain inside the playable strip.
@export var horizontal_clearance: float = 22.0

var current_forward_speed: float = 0.0
var distance_traveled: float = 0.0


func _ready() -> void:
	current_forward_speed = maxf(base_forward_speed, 1.0)


func _physics_process(delta: float) -> void:
	var lateral_input := Input.get_axis("move_left", "move_right")
	var target_lateral_velocity := lateral_input * lateral_speed
	velocity.x = move_toward(
		velocity.x,
		target_lateral_velocity,
		lateral_acceleration * delta
	)

	var target_forward_speed := _get_target_forward_speed()
	current_forward_speed = move_toward(
		current_forward_speed,
		target_forward_speed,
		forward_acceleration * delta
	)
	current_forward_speed = maxf(current_forward_speed, 1.0)
	velocity.y = -current_forward_speed

	move_and_slide()
	global_position.x = clampf(
		global_position.x,
		-road_half_width + horizontal_clearance,
		road_half_width - horizontal_clearance
	)
	distance_traveled += current_forward_speed * delta


func _get_target_forward_speed() -> float:
	var speeding_up := Input.is_action_pressed("speed_up")
	var slowing_down := Input.is_action_pressed("slow_down")

	if speeding_up == slowing_down:
		return maxf(base_forward_speed, 1.0)
	if speeding_up:
		return maxf(boosted_forward_speed, 1.0)
	return maxf(slowed_forward_speed, 1.0)
