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

const NB_CORNERS = 6
const START_ANGLE = PI / 2
const CORNER_RADIUS = 2 * PI / NB_CORNERS
const NB_RINGS = 50
const SCALE = 3

const SPEED = 0

const MAP_INTENSITY = 3 # height of mountains
const MAP_PERIOD = 20 # size of mountains
const MAP_PERSISTENCE = 0.1 # 0.1 = smooth, 1 = not smooth

var noise

var st
var vertexes = []
var m

const RIVER_CIRCLES = []
const RIVER_LENGTH = 100
const RIVER_RADIUS = 3
const RIVER_AMPLITUDE_Y = 4

func generate_river(size, radius):
	RIVER_CIRCLES.clear()
	var half_size = size / 2
	var x = -half_size
	var y = rand_range(0,3)
	var r = radius
	while x < half_size:
		RIVER_CIRCLES.append({ pos=Vector2(x,sin(y)*RIVER_AMPLITUDE_Y), radius=r })
		x += r / 2
		y += 0.10

func get_noise(x,y):
	var pos = Vector2(x,y)
	for circ in RIVER_CIRCLES:
		if pos.distance_squared_to(circ.pos) < circ.radius:
			return -2 * MAP_INTENSITY
	return noise.get_noise_2d(x, y) * MAP_INTENSITY + 0.5

func flatten_world(array):
	for i in range(1,array.size() -1):
		var curr = array[i]
		if curr.y <= -2 * MAP_INTENSITY:
			continue
		var prev = array[i - 1]
		var next = array[i + 1]
		if abs((curr.y + prev.y + next.y) / 3 - curr.y) > 0.2:
			array[i].y = (curr.y + prev.y + next.y) / 3

func get_ring_positions(layer):
	if layer == 0:
		return [ Vector3(0, get_noise(0, 0), 0) ]
	var array = []
	var corners = []

	# Add 6 corners
	var angle = START_ANGLE
	for _i in range(NB_CORNERS):
		corners.append(layer * Vector3(cos(angle), 0, -sin(angle)) * SCALE)
		angle -= CORNER_RADIUS

	# from each corner, compute middle points
	var size = corners.size()
	var pos
	for i in size:
		pos = corners[i]
		pos.y = get_noise(pos.x, pos.z)
		array.append(pos)
		var next = corners[0 if i + 1 >= size else (i + 1)]
		var dist = (next - corners[i]) / layer
		for j in range(1, layer):
			pos = corners[i] + j * dist
			pos.y = get_noise(pos.x, pos.z)
			array.append(pos)
	return array

func generate_vertexes(size):
	vertexes.clear()
	for i in range(size):
		vertexes.append_array(get_ring_positions(i))

func init_noise():
	noise = OpenSimplexNoise.new()
	noise.seed = randi()
	noise.octaves = 9
	noise.period = MAP_PERIOD
	noise.persistence = MAP_PERSISTENCE

func init():
	init_noise()
	generate_river(RIVER_LENGTH, RIVER_RADIUS)
	generate_vertexes(NB_RINGS)
	for i in range(1,5):
		flatten_world(vertexes)

func add_vertex(vertex):
	st.add_uv(Vector2(vertex.x, vertex.z))
	st.add_vertex(vertex)

func add_triangle(first, second, third):
	add_vertex(vertexes[first])
	add_vertex(vertexes[second])
	add_vertex(vertexes[third])

func generate_triangles_ring(level, root, start, nb_nodes):
	var base_root = root
	var value_max_nodes = start + nb_nodes
	for i in range(start, value_max_nodes, level):
		for j in range(0, level):
			var node1 = i + j
			var node2 = i + j + 1 if i + j + 1 <= value_max_nodes else start
			var node3 = root + j if root + j < start else base_root
			add_triangle(node1, node2, node3)
			if SPEED:
				yield(get_tree().create_timer(SPEED), "timeout")
			if j != level - 1:
				node1 = i + 1 + j
				node2 = root + j + 1 if root + j + 1 < start else base_root
				node3 = root + j
				add_triangle(node1, node2, node3)
				if SPEED:
					yield(get_tree().create_timer(SPEED), "timeout")
		root += level - 1
	if level == 1:
		add_triangle(6, 1, 0)

func generate_world():
	var level = 1
	var root = 0
	var start = 1
	var nb_nodes = 5
	for i in range(1, NB_RINGS):
		generate_triangles_ring(level, root, start, nb_nodes)
		level += 1
		root = start
		start += nb_nodes + 1
		nb_nodes += 6

func generate():
	if m:
		remove_child(m)
	m = MeshInstance.new()
	add_child(m)
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	generate_world()
	st.generate_normals()
	st.generate_tangents()
	m.mesh = st.commit()

func build_island():
	init()
	generate()

func _ready():
	build_island()

func _process(delta):
	get_input_keyboard(delta)

func get_input_keyboard(delta):
	if Input.is_action_pressed("generate"):
		build_island()

func get_river():
	return RIVER_CIRCLES