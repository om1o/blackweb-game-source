extends SceneTree
## Reports real imported dimensions, mip chains and compression, not PNG sizes.
func _initialize() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../Docs/EnvironmentArtManifest.json"))
	var rows := []
	var good := true
	for asset in manifest.assets:
		var texture := load(asset.path) as Texture2D
		if texture == null:
			good = false
			continue
		var image := texture.get_image()
		var normal: bool = str(asset.path).contains("NormalGL") or str(asset.path).contains("normal_opengl")
		good = good and image.get_width() <= 2048 and image.get_height() <= 2048 and image.has_mipmaps()
		if normal: good = good and image.get_format() == Image.FORMAT_RGTC_RG and image.is_compressed()
		rows.append({"path": asset.path, "width": image.get_width(), "height": image.get_height(),
			"mipmaps": image.has_mipmaps(), "compressed": image.is_compressed(), "format": image.get_format(),
			"stored_image_data_bytes": image.get_data_size(), "normal": normal})
	var report := {"passed": good, "assets": rows, "limits": "Imported image payload format and size; not whole-process VRAM or frame performance."}
	var output := FileAccess.open("res://../Evidence/environment-imported-textures.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "  "))
	print(JSON.stringify(report))
	quit(0 if good else 1)
