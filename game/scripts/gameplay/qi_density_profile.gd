class_name QiDensityProfile
extends Resource

## Qi granted as soon as the player touches this pickup.
@export_range(1, 1000, 1) var qi_value: int = 10
## Multiplier applied to the shared pickup visual.
@export_range(0.5, 3.0, 0.05) var visual_scale: float = 0.75
## Main visual color used for the pickup core and glow.
@export var color: Color = Color("7dffd8")
## Percentage chance from 0 to 100 that one candidate qi location becomes a
## pickup. Five means roughly five percent of generated locations are occupied.
@export_range(0.0, 100.0, 0.1) var spawn_weight: float = 5.0
