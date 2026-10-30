extends CanvasLayer


func set_score(value: int) -> void:
    $ScoreLabel.text = "Score: %d" % value
