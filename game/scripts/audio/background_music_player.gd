class_name BackgroundMusicPlayer
extends AudioStreamPlayer

## Whether every assigned track repeats from its beginning after reaching the
## end. Compressed WAV tracks restart on `finished`, because enabling their
## AudioStreamWAV loop mode prevents Godot's QOA format from playing.
@export var loop_tracks: bool = true
## Target music loudness in decibels after a transition finishes.
@export_range(-40.0, 6.0, 0.5) var music_volume_db: float = -8.0
## Total fade-out plus fade-in time, in seconds, when changing tracks.
## Zero switches immediately.
@export_range(0.0, 5.0, 0.05) var transition_duration: float = 0.4
## Audio bus used for music. Missing bus names safely fall back to Master.
@export var music_bus: StringName = &"BGM"

var _source_stream: AudioStream
var _transition_tween: Tween


func _ready() -> void:
	bus = music_bus if AudioServer.get_bus_index(music_bus) >= 0 else &"Master"
	finished.connect(_on_track_finished)
	if stream == null:
		volume_db = music_volume_db
		return
	var initial_stream := stream
	stream = null
	play_track(initial_stream, true)


## Changes to one source track, optionally bypassing the configured crossfade.
## Re-requesting the currently playing source preserves its playback position.
func play_track(next_stream: AudioStream, immediate: bool = false) -> void:
	if next_stream == _source_stream and playing:
		return
	if is_instance_valid(_transition_tween):
		_transition_tween.kill()
		_transition_tween = null
	if next_stream == null:
		stop()
		stream = null
		_source_stream = null
		volume_db = music_volume_db
		return
	if immediate or not playing or transition_duration <= 0.0:
		_start_track(next_stream)
		volume_db = music_volume_db
		return
	var half_duration := transition_duration * 0.5
	_transition_tween = create_tween()
	_transition_tween.tween_property(
		self,
		"volume_db",
		-60.0,
		half_duration
	)
	_transition_tween.tween_callback(_start_track.bind(next_stream))
	_transition_tween.tween_property(
		self,
		"volume_db",
		music_volume_db,
		half_duration
	)
	_transition_tween.tween_callback(_finish_transition)


## Returns the original shared asset rather than its runtime looping duplicate.
func get_source_stream() -> AudioStream:
	return _source_stream


func _start_track(next_stream: AudioStream) -> void:
	_source_stream = next_stream
	stream = _make_playback_stream(next_stream)
	play()


func _finish_transition() -> void:
	_transition_tween = null


func _on_track_finished() -> void:
	if loop_tracks and _source_stream != null:
		play()


func _make_playback_stream(source: AudioStream) -> AudioStream:
	if not loop_tracks:
		return source
	if source is AudioStreamMP3:
		var mp3 := source.duplicate() as AudioStreamMP3
		mp3.loop = true
		return mp3
	return source
