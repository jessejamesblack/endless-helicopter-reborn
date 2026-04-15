extends Control

func _ready() -> void:
    $PlayButton.pressed.connect(_on_start_pressed)
    $ScoresButton.pressed.connect(_on_scores_pressed)

func _on_start_pressed() -> void:
    get_tree().change_scene_to_file("res://scenes/game/main/main.tscn")

func _on_scores_pressed() -> void:
    get_tree().change_scene_to_file("res://scenes/ui/leaderboard/leaderboard_screen.tscn")
