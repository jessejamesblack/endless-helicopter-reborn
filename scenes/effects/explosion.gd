extends Node2D

@export var normal_outer_peak_scale: float = 2.8
@export var large_outer_peak_scale: float = 4.1
@export var blast_outer_peak_scale: float = 6.2
@export var normal_shockwave_scale: float = 3.6
@export var large_shockwave_scale: float = 5.4
@export var blast_shockwave_scale: float = 8.2
@export var normal_expand_time: float = 0.30
@export var large_expand_time: float = 0.38
@export var blast_expand_time: float = 0.52
@export var normal_fade_time: float = 0.48
@export var large_fade_time: float = 0.62
@export var blast_fade_time: float = 0.82

@onready var shockwave: Sprite2D = $Shockwave
@onready var outer_burst: Sprite2D = $OuterBurst
@onready var inner_burst: Sprite2D = $InnerBurst
@onready var core_flash: Sprite2D = $CoreFlash
@onready var death_sound: AudioStreamPlayer = $DeathSound

var _is_large: bool = false
var _is_blast: bool = false

func configure(is_large: bool = false, is_blast: bool = false) -> void:
	_is_large = is_large or is_blast
	_is_blast = is_blast

func _ready() -> void:
	z_index = 20
	rotation = randf_range(-0.28, 0.28)

	var initial_scale := 0.42 if _is_blast else (0.28 if _is_large else 0.18)
	var inner_initial_scale := initial_scale * 0.64
	var core_initial_scale := inner_initial_scale * 0.7
	var outer_peak_scale := blast_outer_peak_scale if _is_blast else (large_outer_peak_scale if _is_large else normal_outer_peak_scale)
	var shockwave_peak_scale := blast_shockwave_scale if _is_blast else (large_shockwave_scale if _is_large else normal_shockwave_scale)
	var expand_time := blast_expand_time if _is_blast else (large_expand_time if _is_large else normal_expand_time)
	var fade_time := blast_fade_time if _is_blast else (large_fade_time if _is_large else normal_fade_time)

	outer_burst.scale = Vector2.ONE * initial_scale
	inner_burst.scale = Vector2.ONE * inner_initial_scale
	core_flash.scale = Vector2.ONE * core_initial_scale
	shockwave.scale = Vector2.ONE * (initial_scale * 0.52)

	outer_burst.modulate = Color(1.0, 0.68, 0.24, 1.0)
	inner_burst.modulate = Color(1.0, 0.95, 0.74, 0.96)
	core_flash.modulate = Color(1.0, 0.99, 0.9, 0.0)
	shockwave.modulate = Color(1.0, 0.9, 0.7, 0.0)

	if death_sound != null:
		death_sound.pitch_scale = 0.85 if _is_blast else (0.93 if _is_large else 1.0)
		death_sound.volume_db = 2.0 if _is_blast else (0.0 if _is_large else -1.5)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(outer_burst, "scale", Vector2.ONE * outer_peak_scale, expand_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(outer_burst, "modulate", Color(0.82, 0.17, 0.05, 0.0), fade_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(outer_burst, "rotation", randf_range(-0.45, 0.45), expand_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	tween.tween_property(inner_burst, "scale", Vector2.ONE * (outer_peak_scale * 0.68), expand_time * 0.82).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(inner_burst, "modulate", Color(1.0, 0.62, 0.16, 0.0), fade_time * 0.84).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(inner_burst, "rotation", randf_range(-0.25, 0.25), expand_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	tween.tween_property(core_flash, "modulate", Color(1.0, 0.99, 0.92, 0.96), 0.05).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(core_flash, "scale", Vector2.ONE * (outer_peak_scale * 0.42), expand_time * 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(core_flash, "modulate", Color(1.0, 0.9, 0.72, 0.0), fade_time * 0.58).set_delay(0.06).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	tween.tween_property(shockwave, "modulate", Color(1.0, 0.94, 0.76, 0.58 if _is_blast else 0.38), 0.06).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(shockwave, "scale", Vector2.ONE * shockwave_peak_scale, fade_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(shockwave, "modulate", Color(1.0, 0.68, 0.28, 0.0), fade_time).set_delay(0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	await tween.finished
	queue_free()
