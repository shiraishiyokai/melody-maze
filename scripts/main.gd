# Main entry point — redirects to main menu.
extends Control


func _ready() -> void:
	call_deferred("_goto_menu")


func _goto_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")