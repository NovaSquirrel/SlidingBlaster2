#!/usr/bin/env python3
import PIL, sys, os
from PIL import Image

def separateFirstWord(text, lowercaseFirst=True):
	space = text.find(" ")
	command = text
	arg = ""
	if space >= 0:
		command = text[0:space]
		arg = text[space+1:]
	if lowercaseFirst:
		command = command.lower()
	return (command, arg)

with open("tools/photo_backgrounds.txt") as f:
    text = [s.rstrip() for s in f.readlines()]

background = None
all_backgrounds = []

BG_PIXEL_WIDTH = 256
BG_PIXEL_HEIGHT = 192
BG_TILE_WIDTH = BG_PIXEL_WIDTH // 8
BG_TILE_HEIGHT = BG_PIXEL_HEIGHT // 8
BASE_TILE_NUMBER = 0

def processBackground():
	if background == None:
		return
	# Expected to be exports from https://rilden.github.io/tiledpalettequant/

	# Load the palette
	# Each color is a 16x16 square on the palette image
	palette_lists = []
	palette_sets = []
	im = Image.open("backgrounds/"+background["pal"]).convert("RGBA")
	for palette_num in range(8):
		this_palette = []
		for color_num in range(4):
			this_palette.append(im.getpixel((color_num*16, palette_num*16)))
		palette_lists.append(this_palette)
		palette_sets.append(set(this_palette))
	im.close()

	# Load the actual background image
	tile_data = []
	palette_map = []
	im = Image.open("backgrounds/"+background["pic"]).convert("RGBA")
	for ty in range(BG_TILE_HEIGHT):
		for tx in range(BG_TILE_WIDTH):
			imtile = im.crop((tx*8, ty*8, tx*8+8, ty*8+8)).get_flattened_data()
			tile_colors = set(imtile)

			# Determine the palette
			which_palette = None
			for i, pal in enumerate(palette_sets):
				if tile_colors <= pal:
					which_palette = i
					break
			else:
				print("Can't match tile %d,%d on \"%s\" to any palettes" % (tx, ty, background["pic"]))
				sys.exit()
			palette_list = palette_lists[which_palette]
			tile_number = BASE_TILE_NUMBER + ty*BG_TILE_WIDTH+tx
			palette_map.append((which_palette << 2) | (tile_number >> 8))

			# Convert the tile to Game Boy format
			this_tile = []
			for py in range(8):
				sliver_low  = 0
				sliver_high = 0
				for px in range(8):
					pixel = palette_list.index(imtile[py*8+px])
					if pixel & 1:
						sliver_low |= 0x80 >> px
					if pixel & 2:
						sliver_high |= 0x80 >> px
				this_tile.append(sliver_low)
				this_tile.append(sliver_high)
			tile_data.extend(this_tile)
	im.close()

	background["palette_data"] = palette_lists
	background["palette_map"] = palette_map
	background["tile_data"] = tile_data
	all_backgrounds.append(background)

for line in text:
	if not len(line):
		continue
	if line.startswith("#"): # comment
		continue
	if line.startswith("+"): # new background
		processBackground()
		background = {"name": line[1:], "pic": None, "pal": None}
		continue
	word, arg = separateFirstWord(line)
	if word in ("pic", "pal"):
		background[word] = arg

processBackground()

# Generate the background enum
outfile = open("src/backgroundenum.inc", "w")
outfile.write('; This is automatically generated. Edit "photo_backgrounds.txt" instead\n')
outfile.write('.enum Background\n')
for i, b in enumerate(all_backgrounds):
	outfile.write('  %s = %d\n' % (b['name'], i))
outfile.write('.endenum\n\n')
outfile.close()

# Background directory and data
outfile = open("src/backgrounddata.s", "w")

outfile.write('; This is automatically generated. Edit "photo_backgrounds.txt" instead\n')
outfile.write('.include "snes.inc"\n.export BackgroundDirectory\n')
outfile.write('.proc BackgroundDirectory\n')
for background in all_backgrounds:
	outfile.write('.faraddr Background_%s_data\n' % background["name"])
outfile.write('.endproc\n')

for background in all_backgrounds:
	outfile.write('.segment "Background_%s"\n' % background["name"])
	outfile.write('Background_%s_data:\n' % background["name"])
	outfile.write('; Palette data\n')
	for palette in background["palette_data"]:
		outfile.write('.word %s\n' % ', '.join("RGB8(%d,%d,%d)" % (_[0], _[1], _[2]) for _ in palette))
	outfile.write('; Palette map\n')
	outfile.write('.byt %s\n' % ', '.join(str(_) for _ in background["palette_map"]))
	outfile.write('; Tile data\n')
	outfile.write('.byt %s\n' % ', '.join(str(_) for _ in background["tile_data"]))
	outfile.write('\n')

outfile.close()
