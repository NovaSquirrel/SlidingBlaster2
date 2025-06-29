#!/usr/bin/env python3
import xml.etree.ElementTree as ET # phone home
import glob, os
from readtiled import *

outfile = open("src/leveldata.s", "w")
outfile.write('; This is automatically generated. Edit the files in the levels directory instead.\n')
outfile.write('.include "snes.inc"\n')
outfile.write('.include "actorenum.s"\n')
outfile.write('.include "paletteenum.s"\n')
outfile.write('.include "graphicsenum.s"\n')
outfile.write('.segment "LevelData"\n\n')

# Read the actor definition file and get palette and tileset information from it
actor_tileset = {}
actor_palette = {}
with open("tools/actors.txt") as f:
	text = [s.rstrip() for s in f.readlines()]
	current_actor = None
	for line in text:
		if line.startswith("+"):
			current_actor = line[1:]
		if line.startswith("tileset "):
			actor_tileset[current_actor] = line[8:]
		elif line.startswith("palette "):
			actor_palette[current_actor] = line[8:]

actor_tilesets = {}

for f in sorted(glob.glob("levels/*.tmx")):
	plain_name = os.path.splitext(os.path.basename(f))[0]
	compressed_name = os.path.splitext(f)[0]+'.lz4'

	map = TiledMap(f)
	outfile.write('.export level_%s\n' % plain_name)
	outfile.write('level_%s:\n' % plain_name)

	actor_tilesets_needed = set()
	actor_palettes_needed = set()

	# Generate actor data first
	actor_data = ""
	for actor in sorted(map.actor_list, key=lambda r: r[1]):
		actor_tile, actor_x, actor_y, actor_xflip, actor_yflip, actor_properties = actor
		tileset_name, tileset_offset = actor_tile

		# Load if the tileset isn't already loaded
		if tileset_name not in actor_tilesets:
			actor_tilesets[tileset_name] = TiledMapTileset(os.path.dirname(f) + '/' + tileset_name)
		tileset_data = actor_tilesets[tileset_name].tiles[tileset_offset]

		actor_name = tileset_data['Name']
		this_actor_tileset = actor_tileset.get(actor_name)
		if this_actor_tileset:
			actor_tilesets_needed.add(this_actor_tileset)
		this_actor_palette = actor_palette.get(actor_name)
		if this_actor_palette and this_actor_palette != "Icons":
			actor_palettes_needed.add(this_actor_palette)

		if 'extra' in actor_properties:
			actor_data += "  .byt %d, %d|%d, Actor::%s, (%s)<<4\n" % (actor_x, (128 if actor_xflip else 0), actor_y-1, actor_name, actor_properties['extra'])
		else:
			actor_data += "  .byt %d, %d|%d, Actor::%s, 0\n" % (actor_x, (128 if actor_xflip else 0), actor_y-1, actor_name)
	actor_data += '  .byt 255\n'

	actor_tilesets_needed = list(actor_tilesets_needed)
	if len(actor_tilesets_needed) > 8:
		print("Too many actor tilesets used!", actor_tilesets_needed)
	else:
		actor_tilesets_needed.extend([None] * (8-len(actor_tilesets_needed)))
	actor_palettes_needed = list(actor_palettes_needed)
	if len(actor_palettes_needed) > 3:
		print("Too many actor palettes used!", actor_palettes_needed)
	else:
		actor_palettes_needed.extend([None] * (3-len(actor_palettes_needed)))

	# Write the level data
	outfile.write('  .byt 0 ; Music\n')
	outfile.write('  .byt %d, %d ; X and Y\n' % (map.start_x, map.start_y))
	outfile.write('  .byt 0 ; Flags\n')
	outfile.write('  .word RGB8(%d,%d,%d)\n' % (map.bgcolor[0], map.bgcolor[1], map.bgcolor[2]))
	outfile.write('  .byte %s\n' % ", ".join([(("GraphicsUpload::"+_) if _ else "255") for _ in actor_tilesets_needed]))
	outfile.write('  .byte %s\n' % ", ".join([(("Palette::"+_) if _ else "255") for _ in actor_palettes_needed]))
	outfile.write('  .word .loword(level_%s_sp)\n' % plain_name)
	outfile.write('  .word .loword(level_%s_fg)\n' % plain_name)
	outfile.write('level_%s_fg:\n' % plain_name)
	outfile.write('  .incbin "../%s"\n' % compressed_name.replace('\\', '/'))
	outfile.write('level_%s_sp:\n' % plain_name)
	outfile.write(actor_data)

	outfile.write('\n')
outfile.close()
