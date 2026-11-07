extends SceneTree
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var holder := Control.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(holder)
	var menu = load("res://scripts/horror_menu.gd").new()
	menu.qa_mode = true
	holder.add_child(menu)
	menu.show_page("extras")
	for i in 20: await process_frame
	root.get_texture().get_image().save_png("D:/CodexTemp/Blackweb-BossPass/extras-boss-link.png")
	var button: Button
	for node in menu.find_children("*","Button",true,false):
		if node.text == "Boss combat preview": button = node
	if button == null or not button.is_visible_in_tree() or button.get_global_rect().end.y > root.get_visible_rect().end.y:
		push_error("Boss preview entry is missing or clipped")
		quit(1)
		return
	print("BOSS_MENU_ENTRY visible and within viewport")
	quit()
