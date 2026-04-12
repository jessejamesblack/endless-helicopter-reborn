extends Control

func _ready() -> void:
    var high_score: int = 0
    if FileAccess.file_exists("user://highscore.save"):
        var file = FileAccess.open("user://highscore.save", FileAccess.READ)
        high_score = file.get_64()
        
    $VBoxContainer/HighScoreLabel.text = "High Score: %d" % high_score
    
    $VBoxContainer/StartButton.pressed.connect(_on_start_pressed)

func _on_start_pressed() -> void:
    get_tree().change_scene_to_file("res://main.tscn")