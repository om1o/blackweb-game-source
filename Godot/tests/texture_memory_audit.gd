extends SceneTree
func _initialize() -> void:
	var paths: Array[String] = []
	for name in ["blood_goo_decal_v1", "blood_goo_smears_v2", "blood_variants_v3", "ceiling_silk_v2", "corner_web_v1", "goo_variants_v3", "candy_wrapper_aged_v1", "blackweb_menu_corridor_v1"]:
		paths.append("res://assets/generated/"+name+".png")
	for name in ["albedo", "arm", "nor_gl"]:
		paths.append("res://assets/third_party/poly_haven/brown_leather/brown_leather_"+name+"_2k.jpg")
	var rows: Array = []
	var before := 0
	var after := 0
	var retained: Array[Texture2D] = []
	var previous := "D:/CodexTemp/Blackweb-SmoothCombat/previous-texture-cache"
	for path in paths:
		var memory := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED)
		var texture := load(path) as Texture2D
		retained.append(texture)
		var compressed_bytes := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED)-memory
		var current := texture.get_image()
		var old_path := ""
		for file in DirAccess.get_files_at(previous):
			if file.begins_with(path.get_file()+"-"): old_path = previous.path_join(file)
		memory = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED)
		var old_texture := load(old_path) as Texture2D
		retained.append(old_texture)
		var original_bytes := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED)-memory
		var original := old_texture.get_image()
		# ANGLE returns decompressed readback images; DXT pads to 4-pixel blocks.
		var config := ConfigFile.new()
		config.load(path+".import")
		var difference := (original.get_size()-current.get_size()).abs()
		if difference.x > 3 or difference.y > 3 or config.get_value("params","compress/mode") != 2:
			push_error("Texture dimensions or GPU compression failed: "+path)
			quit(1)
			return
		before += original_bytes
		after += compressed_bytes
		rows.append({"path":path,"width":current.get_width(),"height":current.get_height(),"before_bytes":original_bytes,"after_bytes":compressed_bytes})
	var result := {"kind":"RenderingServer texture-memory counter deltas while retaining all compared textures; not whole-process RAM or FPS","before_bytes":before,"after_bytes":after,"textures":rows}
	FileAccess.open("D:/CodexTemp/Blackweb-SmoothCombat/texture-memory.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("TEXTURE_MEMORY ", before, " -> ", after)
	quit()
