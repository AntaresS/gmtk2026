class_name QiDensityProfile
extends Resource

enum Density {
	SMALL,
	MEDIUM,
	LARGE,
}

## Stable density identity used by generation tests and future presentation
## systems. Size, value, and duration remain data-driven below.
@export var density: Density = Density.SMALL
## Short designer-facing name for this density profile.
@export var display_name: String = "Small"
## Qi granted after this pickup finishes absorbing.
@export_range(1, 1000, 1) var qi_value: int = 10
## Continuous time, in seconds, the player must remain in absorption range.
## Progress is retained whenever the player leaves the radius.
@export_range(0.05, 10.0, 0.05) var absorption_duration_seconds: float = 0.45
## Multiplier applied to the shared pickup visual. Larger values make denser
## qi immediately readable without changing the player's absorption radius.
@export_range(0.5, 3.0, 0.05) var visual_scale: float = 0.75
## Main visual color used for the core, glow, tether, and progress ring.
@export var color: Color = Color("7dffd8")
## Relative deterministic spawn weight. Zero excludes this density from random
## generation while keeping the profile available for placed instances.
@export_range(0.0, 100.0, 0.1) var spawn_weight: float = 70.0
