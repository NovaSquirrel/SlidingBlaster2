#!/usr/bin/env python3
import xml.etree.ElementTree as ET # phone home
import sys, os
from readtiled import *

# Get tileset info
def get_name_mapping_from_tsx(filename):
	tileset_tree = ET.parse(filename)
	tileset_root = tileset_tree.getroot()
	name_for_tiled_id = {}
	for t in tileset_root:
		if t.tag == 'tile':
			assert t[0].tag == 'properties'
			for p in t[0]: # properties
				assert p.tag == 'property'
				if p.attrib['name'] == 'Name':
					name_for_tiled_id[int(t.attrib['id'])] = p.attrib['value']
	return name_for_tiled_id
name_for_tiled_fg_id = get_name_mapping_from_tsx("levels/tiles/level.tsx")
name_for_tiled_bg_id = get_name_mapping_from_tsx("levels/tiles/background.tsx")

# Read the block enum to translate names to IDs
define_file = open("src/blockenum.s")
define_lines = [x.strip() for x in define_file.readlines()]
define_file.close()
id_for_fg_block = {}
block_count = 0
in_enum = False
for i in define_lines:
	if i.strip() == '.enum Block':
		in_enum = True
	elif i.strip() == '.endenum':
		in_enum = False
	elif in_enum:
		id_for_fg_block[i.strip().split(' ')[0]] = block_count
		block_count += 1

# Read the background block enum to translate names to IDs
define_file = open("src/backgroundblockenum.s")
define_lines = [x.strip() for x in define_file.readlines()]
define_file.close()
id_for_bg_block = {}
block_count = 0
in_enum = False
for i in define_lines:
	if i.strip() == '.enum BackgroundBlock':
		in_enum = True
	elif i.strip() == '.endenum':
		in_enum = False
	elif in_enum:
		id_for_bg_block[i.strip().split(' ')[0]] = block_count
		block_count += 1

if len(sys.argv) != 3:
	print("levelconvert.py input.tmx output.bin")
else:
	outfile = open(sys.argv[2], "wb")
	tree = ET.parse(sys.argv[1])
	root = tree.getroot()

	map_width  = int(root.attrib['width'])
	map_height = int(root.attrib['height'])
	fg_map_data = []
	bg_map_data = []

	# Keep track of the mapping between the tile numbers and different tilesets
	tileset_first_gid = []
	tileset_filename  = []

	# Find what tileset a tile belongs to, and the offset within it
	def identify_gid(tilenum):
		if tilenum > 0:
			for i in range(len(tileset_first_gid)):
				if tilenum >= tileset_first_gid[i]:
					within = tilenum-tileset_first_gid[i]
					return (tileset_filename[i], within)
		return None

	# Parse the map file
	for e in root:
		if e.tag == 'tileset':
			# Keep track of what tile numbers belong to what tile sheets
			tileset_first_gid.insert(0, int(e.attrib['firstgid']))
			tileset_filename.insert(0, e.attrib['source'])
		elif e.tag == 'layer':
			is_background = e.attrib["name"] == "Background"
			map_data = bg_map_data if is_background else fg_map_data
			name_for_tiled_id = name_for_tiled_bg_id if is_background else name_for_tiled_fg_id
			id_for_block = id_for_bg_block if is_background else id_for_fg_block

			# Parse tile layers
			for d in e: # Go through the layer's data
				if d.tag == 'properties':
					for p in d:
						pass
				elif d.tag == 'data':
					assert d.attrib['encoding'] == 'csv'
					for line in [x for x in d.text.splitlines() if len(x)]:
						row = []
						for t in line.split(','):
							if not len(t):
								continue
							if int(t) <= 0:
								row.append(id_for_block['Empty'])
							else:
								gid = int(t)
								filename, offset = identify_gid(gid)

								row.append(id_for_block[name_for_tiled_id[offset]])
						map_data.append(row)

	for row in fg_map_data:
		outfile.write(bytes(row))
	for row in bg_map_data:
		outfile.write(bytes(row))
	outfile.close()
