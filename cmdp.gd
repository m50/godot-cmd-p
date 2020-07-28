tool
extends EditorPlugin

const EXPAND_AMT = 25
const file_search = "ui_file_search"
const scene = preload("res://addons/CmdP/CmdP.tscn")
const listEntryScene = preload("res://addons/CmdP/ListEntry.tscn")

var cur_sel_label
var search_text = ""
var search_val = ""
var paths = []

var interface
var entries
var search: LineEdit

func _enter_tree():
	get_editor_interface().get_resource_filesystem().connect("filesystem_changed", self, "_on_filesystem_changed")
	search_dirs(get_editor_interface().get_resource_filesystem().get_filesystem())
	if InputMap.has_action(file_search):
		return;
	InputMap.add_action(file_search);
	var input_event = InputEventKey.new();
	input_event.scancode = KEY_P
	if OS.get_name() == "OSX":
		input_event.command = true
	else:
		input_event.control = true
	InputMap.action_add_event(file_search, input_event);

func _exit_tree():
	if InputMap.has_action(file_search):
		InputMap.erase_action(file_search)

func _input(event):
	if event.is_action_pressed(file_search):
		interface = scene.instance();
		search = interface.get_node("PanelContainer/Organizer/Search")
		entries = interface.get_node("PanelContainer/Organizer/Entries/List")
		interface.rect_size.y = 42
		search.connect("text_changed", self, "_on_text_changed")
		search.connect("text_entered", self, "_on_text_entered")
		add_child(interface)
		search.grab_focus()
		get_editor_interface().get_resource_filesystem().scan()
		return

	if !interface:
		return

	if event.is_action_pressed("ui_cancel"):
		interface.queue_free()
		return

	var children: Array = entries.get_children();
	var selnext = false;
	if event.is_action("ui_up"):
		children.invert()
		for c in children:
			if selnext:
				select_entry(c)
				return
			if c.text == search_val:
				selnext = true
	elif event.is_action("ui_down"):
		for c in children:
			if selnext:
				select_entry(c)
				return
			if c.text == search_val:
				selnext = true


func _on_filesystem_changed():
	search_dirs(get_editor_interface().get_resource_filesystem().get_filesystem())

func _on_text_changed(new_text: String):
	search_text = "*%s*" % insert_between_every_char(new_text, "*").to_lower()
	if new_text.length() == 0:
		search_text = ""

	var search_arr = []
	for p in paths:
		if p.to_lower().match(search_text) && !search_arr.has(p):
			search_arr.append(p)

	search_val = ""
	search_arr.sort_custom(self, "_similarity_sort")
	if search_arr.size() > 0:
		search_val = search_arr[0]

	clear_entries()
	for s in search_arr:
		add_entry(s)

func _on_text_entered(search):
	var editor = get_editor_interface()
	editor.save_scene();
	if search_val.ends_with(".tscn"):
		editor.open_scene_from_path(search_val)
	interface.queue_free()

func _similarity_sort(a, b):
	var s = search_text.replace("*", "")
	if s.is_subsequence_ofi(a) and not s.is_subsequence_ofi(b):
		return true

	var asim = a.similarity(s)
	var bsim = b.similarity(s)

	return asim > bsim

func search_dirs(dir: EditorFileSystemDirectory):
	for idx in dir.get_subdir_count():
		search_dirs(dir.get_subdir(idx))
	for idx in dir.get_file_count():
		var file_type = dir.get_file_type(idx)
		if file_type == "PackedScene":
			var path = dir.get_file_path(idx)
			if !path.match("*addon*"):
				paths.append(path)

func clear_entries():
	for c in entries.get_children():
		c.free()
	interface.get_child(0).rect_size.y = 47

func add_entry(text: String):
	var l = listEntryScene.instance()
	l.text = text
	entries.add_child(l)
	unselect_entry(l)
	if l.text == search_val:
		select_entry(l)
	if interface.get_child(0).rect_size.y < 300:
		interface.get_child(0).rect_size.y += EXPAND_AMT
	l.connect("pressed", self, "_on_pressed", [l])
	return l

func insert_between_every_char(text, chr) -> String:
	if len(text) == 0:
		return ""
	var result = text[0]
	for i in range(1, len(text)):
		result += chr
		result += text[i]
	return result

func select_entry(entry):
	if !entry:
		return
	entry.get_node("Highlight").visible = true
	search_val = entry.text
	unselect_entry(cur_sel_label)
	cur_sel_label = entry

func unselect_entry(entry):
	if !entry:
		return
	entry.get_node("Highlight").visible = false

func _on_pressed(entry):
	select_entry(entry)
	_on_text_entered(entry.text)
