#!/usr/bin/env python3
from nts2shared import *

# Globals
default_palette = 0
default_base = 0
block = None
priority = False
all_blocks = []

# Read and process the file
with open("tools/backgroundblocks.txt") as f:
    text = [s.rstrip() for s in f.readlines()]

def saveBlock():
	if block == None:
		return

	all_blocks.append(block)

# Nametable format:
# Bit 0-9   - Character Number (000h-3FFh)
# Bit 10-12 - Palette Number   (0-7)
# Bit 13    - BG Priority      (0=Lower, 1=Higher)
# Bit 14    - X-Flip           (0=Normal, 1=Mirror horizontally)
# Bit 15    - Y-Flip           (0=Normal, 1=Mirror vertically)

for line in text:
	if not len(line):
		continue
	if line.startswith("#"): # comment
		continue
	if line.startswith("+"): # new block
		saveBlock()
		# Reset to prepare for the new block
		priority = False
		block = {"name": line[1:], "tiles": []}
		continue
	word, arg = separateFirstWord(line)
	# Miscellaneous directives
	if word == "alias":
		name, value = separateFirstWord(arg)
		aliases[name] = value

	# Tile info shared with several blocks
	elif word == "base":
		default_base = parseNumber(arg)
	elif word == "palette":
		default_palette = parseNumber(arg)

	# Specifying tiles and tile attributes
	elif word == "priority":
		priority = True
	elif word == "no_priority":
		priority = False
	elif word == "t": # add tiles
		split = arg.split(" ")
		for tile in split:
			block["tiles"].append(parseMetatileTile(tile, default_palette, default_base, priority))
	elif word == "w": # add four tiles at once
		tile = parseMetatileTile(arg, default_palette, default_base, priority)
		block["tiles"] = [tile, tile+1, tile+2, tile+3]
	elif word == "q": # add four tiles at once
		tile = parseMetatileTile(arg, default_palette, default_base, priority)
		block["tiles"] = [tile, tile+1, tile+16, tile+17]

# Save the last one
saveBlock()

# Generate the output that's actually usable in the game
outfile = open("src/backgroundblockdata.s", "w")

outfile.write('; This is automatically generated. Edit "backgroundblocks.txt" instead\n')
outfile.write('.include "backgroundblockenum.s"\n\n')
outfile.write('.export BackgroundBlockTopLeft, BackgroundBlockTopRight, BackgroundBlockBottomLeft, BackgroundBlockBottomRight\n')
outfile.write('\n.segment "BackgroundBlockGraphicData"\n\n')

# Block appearance information
corners = ["TopLeft", "TopRight", "BottomLeft", "BottomRight"]
for corner, cornername in enumerate(corners):
	outfile.write(".proc BackgroundBlock%s\n" % cornername)
	for b in all_blocks:
		outfile.write('  .word $%.4x ; %s\n' % (b['tiles'][corner], b['name']))
	outfile.write(".endproc\n\n")

outfile.close()

# Generate the enum in a separate file
outfile = open("src/backgroundblockenum.s", "w")
outfile.write('; This is automatically generated. Edit "backgroundblocks.txt" instead\n')
outfile.write('.enum BackgroundBlock\n')
for i, b in enumerate(all_blocks):
	outfile.write('  %s = %d\n' % (b['name'], i*2))
outfile.write('.endenum\n\n')

outfile.close()
