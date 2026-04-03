extends Node2D

# ═══════════════════════════════════════════════════════════════════════════════
# Main Entry Point
# 모든 화면은 동적으로 생성되고 교체됩니다.
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	_show_splash()


func _show_splash() -> void:
	var splash := SplashScreen.new()
	splash.transition_requested.connect(_on_transition)
	add_child(splash)


func _on_transition(next_screen: Node) -> void:
	# 기존 화면 제거
	for child in get_children():
		child.queue_free()
	
	# 새 화면 추가
	if next_screen.has_signal("transition_requested"):
		next_screen.transition_requested.connect(_on_transition)
	add_child(next_screen)