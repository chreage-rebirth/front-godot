###############################################################################
## Stigmee: The art to sanctuarize knowledge exchanges.
## Copyright 2021-2022 Corentin CAILLEAUD <corentin.cailleaud@caillef.com>
## Copyright 2021-2022 Quentin Quadrat <lecrapouille@gmail.com>
##
## This file is part of Stigmee.
##
## Stigmee is free software: you can redistribute it and/or modify it
## under the terms of the GNU General Public License as published by
## the Free Software Foundation, either version 3 of the License, or
## (at your option) any later version.
##
## This program is distributed in the hope that it will be useful, but
## WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
## General Public License for more details.
##
## You should have received a copy of the GNU General Public License
## along with this program.  If not, see http://www.gnu.org/licenses/.
###############################################################################

extends Spatial

# ==============================================================================
#
# ==============================================================================
const NODE = preload("res://strand/Node/Node.tscn")
const BROWSER_EVENTS = ["prev_node", "next_node", "home", "browser_close", "browser_event"]
const FETCHING_TITLE_PLACEHOLDER = "Fetching title..."

# ==============================================================================
# Clickable moving spheres holding an URL
# ==============================================================================
const NB_NODES = 21
var nodes = []
var physicalNodes = []
var nodes_data = {}
var current_node_id = 0
var current_url
var current_name
var placing_node : bool = false

# Chromium Embedded Framework (CEF) BrowserView
var current_tab = null

# ==============================================================================
# ???
# ==============================================================================
var SAVE_PATH
var mouse_pressed : bool = false
var requested_title = {}
var is_open = false

# ==============================================================================
# "on init" event called by the SceneManager state machine.
# ==============================================================================
func load_scene():
	$Interface.visible = false
	init_events()
	$StrandGeneration.init()

# ==============================================================================
# "on entry" event called by the SceneManager state machine.
# ==============================================================================
func open_scene(data):
	is_open = true
	var strand_id = data.strand_id
	SAVE_PATH = Global.STRAND_SAVE % strand_id
	Global.edit_mode = false

	hide_UI()
	$AutofillLinkPanel/VBoxContainer/HBoxContainer/Keyword.text = ""
	$Menu.visible = true
	$StrandGeneration.visible = true
	$GeneratedStrand.visible = true

	place_nodes($StrandGeneration.get_river())
	load_links()
	self.visible = true

# ==============================================================================
# Remove dynamic spheres that hold URLs.
# ==============================================================================
func clear_nodes():
	for elem in physicalNodes:
		self.remove_child(elem)
	physicalNodes.clear()

# ==============================================================================
# "on leaving" event called by the SceneManager state machine.
# ==============================================================================
func close_scene():
	is_open = false
	clear_nodes()
	self.visible = false
	for child in get_children():
		child.visible = false

# ==============================================================================
# Connect signals of the browser GUI to functions
# ==============================================================================
func init_events():
	var browser_controller = $Interface/Browser
	for event in BROWSER_EVENTS:
		browser_controller.connect(event, self, event)
	var save_link_btn = find_node("SaveLinkBtn")
	save_link_btn.connect("save_link", self, "save_link")

# ==============================================================================
# 
# ==============================================================================
func save_link(name):
	current_url = ""
	if current_tab != null:
		current_url = current_tab.get_url()
	browser_close()
	placing_node = true
	current_name = name
	Global.edit_mode = true
	$Hint/HintAddResource.visible = true

# ==============================================================================
# Make the CEF browser reacts from mouse and keyboard events.
# ==============================================================================
func browser_event(event):
	if current_tab == null:
		return

	if event is InputEventMouseButton:
		if event.button_index == BUTTON_WHEEL_UP:
			current_tab.on_mouse_wheel(5)
		elif event.button_index == BUTTON_WHEEL_DOWN:
			current_tab.on_mouse_wheel(-5)
		elif event.button_index == BUTTON_LEFT:
			mouse_pressed = event.pressed
			if event.pressed == true:
				current_tab.on_mouse_left_down()
			else:
				current_tab.on_mouse_left_up()
		elif event.button_index == BUTTON_RIGHT:
			mouse_pressed = event.pressed
			if event.pressed == true:
				current_tab.on_mouse_right_down()
			else:
				current_tab.on_mouse_right_up()
		else:
			mouse_pressed = event.pressed
			if event.pressed == true:
				current_tab.on_mouse_middle_down()
			else:
				current_tab.on_mouse_middle_up()

	elif event is InputEventMouseMotion:
		if mouse_pressed == true :
			current_tab.on_mouse_left_down()
		current_tab.on_mouse_moved(event.position.x, event.position.y)

# ==============================================================================
#
# ==============================================================================
func hide_UI():
	$Hint/HintAddResource.visible = false
	$AutofillLinkPanel.visible = false
	$Menu.visible = false
	$Interface.visible = false

# ==============================================================================
#
# ==============================================================================
func get_next_empty_node_id():
	for i in range(0, len(physicalNodes) - 1):
		if not str(i) in nodes_data:
			return i
	return -1

# ==============================================================================
# 
# ==============================================================================
func instanciate_node(x, y, z):
	var node = NODE.instance()
	add_child(node)
	node.translate(Vector3(x,y,z))
	node.scale_object_local(Vector3(4,4,4))
	return node

func place_node(node, side):
	var x = node.realPos.x
	var y = node.realPos.y + 7
	var z = node.realPos.z + side * node.radius * 3 + node.radius
	var n = instanciate_node(x, y, z)
	physicalNodes.append(n)
	n.set_data(physicalNodes.size() - 1, null)

func place_nodes(river_nodes):
	var ratio = round(river_nodes.size() / NB_NODES)
	var current_node = 2
	nodes = []
	while nodes.size() <= NB_NODES:
		nodes.append(river_nodes[current_node])
		current_node += ratio

	var side = 1
	for id in range(0, NB_NODES):
		place_node(nodes[id], side)
		side = -1 if side == 1 else 1

# ==============================================================================
# Parse the HTML document looking for the title field and display the title
# ==============================================================================
func request_html_title(id, url):
	var newHttp = HTTPRequest.new()
	add_child(newHttp)
	newHttp.request(url)
	var response = yield (newHttp, "request_completed")
	var body = response[3]
	if not body:
		assign_link_to_node(url, id, "")
		return
	var content = body.get_string_from_utf8()
	if not "<title>" in content:
		assign_link_to_node(url, id, "")
		return
	var title = content.split("<title>")[1].split("</title>")[0]
	nodes_data[str(id)].title = title
	if nodes_data[str(id)].custom_name == FETCHING_TITLE_PLACEHOLDER:
		assign_link_to_node(url, id, title.substr(0, 15))
	$Interface/Browser/TopBar/ColorRect/Title.text = title
	remove_child(newHttp)

# ==============================================================================
# Make the moving sphere holds the given URL
# ==============================================================================
func assign_link_to_node(url, id, name):
	var data = {}
	data.url = url
	if name.begins_with("https://"):
		name = FETCHING_TITLE_PLACEHOLDER
		request_html_title(id, url)
	data.custom_name = name
	if !data.has("custom_name"):
		data.custom_name = url
	physicalNodes[id].set_data(id, data.custom_name)
	nodes_data[str(id)] = data
	save_links()

# ==============================================================================
# Save URLs inside a json file
# ==============================================================================
func save_links():
	var save_game = File.new()
	save_game.open(SAVE_PATH, File.WRITE)
	save_game.store_line(to_json(nodes_data))
	save_game.close()

# ==============================================================================
# Load URLs inside from a json file
# ==============================================================================
func load_links():
	var save_game = File.new()
	if not save_game.file_exists(SAVE_PATH):
		return
	save_game.open(SAVE_PATH, File.READ)
	nodes_data = parse_json(save_game.get_line())
	for key in nodes_data:
		var data = nodes_data[key]
		physicalNodes[int(key)].set_data(int(key), data.custom_name)
	save_game.close()

# ==============================================================================
# Click on a moving sphere holding and URL
# ==============================================================================
func click_node(node_id):
	current_node_id = node_id
	if placing_node:
		assign_link_to_node(current_url, current_node_id, current_name)
		placing_node = false
		current_name = ""
		$Hint/HintAddResource.visible = false
		current_url = null
		Global.edit_mode = false
		request_html_title(current_node_id, current_url)
		return
	var url = Global.DEFAULT_SEARCH_ENGINE_URL
	if nodes_data.has(str(node_id)):
		url = nodes_data[str(node_id)].url
	load_link(url, "tab1") # FIXME constant name
	if not "title" in nodes_data[str(node_id)]:
		request_html_title(node_id, url)
		$Interface/Browser/TopBar/ColorRect/Title.text = ""
	else:
		$Interface/Browser/TopBar/ColorRect/Title.text = nodes_data[str(node_id)].title

# ==============================================================================
# Callback when the URL has been loaded
# ==============================================================================
func _on_page_loaded(node):
	print("The browser " + node.name + " has loaded " + node.get_url())
	#$Interface.visible = true

# ==============================================================================
# Create a new CEF browser and load the given URL.
# param[in] link: the desired URL
# param[in] name: the browser name
# ==============================================================================
func load_link(link : String, name : String):
	# Set the page dimension
	var size = $Interface/Browser/Panel.get_size()
	$Interface/Browser/Panel/Texture.set_size(size)
	# Create a new CEF browser and load the URL
	current_tab = $CEF.create_browser(link, name, size.x, size.y)
	# Make the CEF texture displayed by the node knowing how to do it
	$Interface/Browser/Panel/Texture.texture = current_tab.get_texture()
	$Interface.visible = true

# ==============================================================================
# Display the previously loaded page
# ==============================================================================
func browser_close():
	$Interface.visible = false

# ==============================================================================
# Display the previously loaded page
# ==============================================================================
func prev_node():
	if current_tab != null:
		current_tab.previous_page()

# ==============================================================================
# Display the next loaded page
# ==============================================================================
func next_node():
	if current_tab != null:
		current_tab.next_page()

# ==============================================================================
# Load the home page URL
# ==============================================================================
func home():
	load_link(Global.DEFAULT_SEARCH_ENGINE_URL, "home")

# ==============================================================================
# Event whent the CEF is opened: load the home page.
# ==============================================================================
func _on_OpenBrowser_pressed():
	home()

# ==============================================================================
# ??? Which button ?
# ==============================================================================
func _on_StigmarkButton_pressed():
	$AutofillLinkPanel.visible = not $AutofillLinkPanel.visible

# ==============================================================================
# The user has pressed on the Stigmark search button.
# ==============================================================================
func _on_StigmarkSearch_pressed():
	var keyword = $AutofillLinkPanel/VBoxContainer/HBoxContainer/Keyword.text
	if len(keyword) == 0:
		return
	$Stigmark.search_async(keyword)
	$AutofillLinkPanel/VBoxContainer/HBoxContainer/Keyword.text = ""
	$AutofillLinkPanel.visible = false

# ==============================================================================
# The user has pressed on the Stigmark search button.
# ==============================================================================
func _on_Stigmark_on_search(collections):
	for collection in collections:
		var urls = collection.urls
		for url in urls:
			var id = get_next_empty_node_id()
			if id != -1:
				assign_link_to_node(url.uri, id, url.uri)
			print(url)

# ==============================================================================
# Make the CEF browser reacts from mouse and keyboard events.
# ==============================================================================
func _unhandled_input(event):
	if current_tab == null:
		return
	if event is InputEventKey:
		if event.unicode != 0:
			current_tab.on_key_pressed(event.unicode, event.pressed, event.shift, event.alt, event.control)
		else:
			current_tab.on_key_pressed(event.scancode, event.pressed, event.shift, event.alt, event.control)
	if event.is_action_pressed("ui_cancel"):
		if $Interface.visible:
			browser_close()
		else:
			find_parent("SceneManager").switch_to_island()

# ==============================================================================
# "on update" event: allow or not the user to control the camera only when no
# browser is displayed.
# ==============================================================================
func _process(_delta):
	Global.enable_orbit_camera = $Interface.visible and not $AutofillLinkPanel.visible
	pass

# ==============================================================================
# When leaving Godot, release CEF which will also release its browsers.
# ==============================================================================
func _on_Spatial_tree_exiting():
	$CEF.shutdown()
	print("CEF stopped")