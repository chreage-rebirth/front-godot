###############################################################################
## Stigmee: The art to sanctuarize knowledge exchanges.
## Copyright 2021-2022 Corentin CAILLEAUD <corentin.cailleaud@caillef.com>
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

export var ROTATION_SPEED = 1
export var ZOOM_SPEED = 0.09
var zoom = 5

var dragging = false
var mouse_start_pos
var screen_start_position

func _ready():
	scale = Vector3.ONE * zoom
	Global.zoom = zoom
	set_process_input(true)

func _process(delta):
	input_keyboard(delta)

func _input(event):
	if event.is_action("drag"):
		if event.is_pressed():
			mouse_start_pos = event.position
			screen_start_position = Vector2(translation.x, translation.z)
			dragging = true
		else:
			dragging = false
	elif event is InputEventMouseMotion and dragging:
		var newPos: Vector2 = (zoom * (mouse_start_pos - event.position) + screen_start_position).normalized() / 10
		translate(Vector3(newPos.x, 0, newPos.y))

func input_keyboard(delta):
	if not Global.enable_orbit_camera:
		return
	var y_rotation = 0
	if Input.is_action_pressed("cam_left"):
		y_rotation -= 1
	if Input.is_action_pressed("cam_right"):
		y_rotation += 1
	rotate_object_local(Vector3.UP, y_rotation * ROTATION_SPEED * delta)
	if Input.is_action_pressed("cam_down"):
		var t = -transform.basis.y * 0.3
		translate(t)
	if Input.is_action_pressed("cam_up"):
		var t = transform.basis.y * 0.3
		translate(t)

func set_zoom(value):
	zoom = value
	zoom = clamp(zoom, 0.5, 10)
	Global.zoom = zoom
	scale = Vector3.ONE * zoom

func _unhandled_input(event):
	if not Global.enable_orbit_camera:
		return
	if event.is_action_pressed("cam_zoom_in"):
		zoom -= ZOOM_SPEED
	if event.is_action_pressed("cam_zoom_out"):
		zoom += ZOOM_SPEED
	set_zoom(zoom)
