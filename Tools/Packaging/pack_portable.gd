extends SceneTree

func _initialize() -> void:
	var manifest_path := ""
	var output_path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--manifest="): manifest_path = arg.trim_prefix("--manifest=")
		if arg.begins_with("--output="): output_path = arg.trim_prefix("--output=")
	if manifest_path.is_empty() or output_path.is_empty():
		_fail("Expected --manifest=<json> and --output=<pck>.")
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not parsed is Array or parsed.is_empty():
		_fail("Invalid or empty input manifest.")
		return
	var packer := PCKPacker.new()
	var err := packer.pck_start(output_path)
	if err != OK:
		_fail("Could not start pack: %s" % error_string(err))
		return
	var count := 0
	var bytes := 0
	for entry in parsed:
		var source := str(entry.source)
		var destination := str(entry.path)
		var source_file := FileAccess.open(source, FileAccess.READ)
		if source_file == null or source_file.get_length() != int(entry.bytes):
			_fail("Missing or changed input: " + source)
			return
		source_file.close()
		err = packer.add_file(destination, source)
		if err != OK:
			_fail("Could not add %s: %s" % [destination, error_string(err)])
			return
		count += 1
		bytes += int(entry.bytes)
		if count % 200 == 0: print("PACK_PROGRESS files=%d bytes=%d" % [count, bytes])
	err = packer.flush()
	if err != OK:
		_fail("Could not finish pack: " + error_string(err))
		return
	print("PACK_COMPLETE files=%d input_bytes=%d output=%s" % [count, bytes, output_path])
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
