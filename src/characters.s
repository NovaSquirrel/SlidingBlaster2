; Sliding Blaster 2
; Copyright (C) 2025 NovaSquirrel
;
; This program is free software: you can redistribute it and/or
; modify it under the terms of the GNU General Public License as
; published by the Free Software Foundation; either version 3 of the
; License, or (at your option) any later version.
;
; This program is distributed in the hope that it will be useful, but
; WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
; General Public License for more details.
;
; You should have received a copy of the GNU General Public License
; along with this program.  If not, see <http://www.gnu.org/licenses/>.
;
.include "snes.inc"
.include "global.inc"
.include "paletteenum.s"
.smart
.import SFX_LZ4_decompress

.segment "C_Player"

; A = Character index (0 to 2)
; Y = Player index (0 or 1)
.a16
.i16
.export SetupAnimatedCharacter
.proc SetupAnimatedCharacter
TableData = 2
	phx
	asl ; * 4
	asl
	tax
	lda f:CharacterData,x
	sta TableData
	lda f:CharacterData+2,x
	sta TableData+2

	phy
	tya
	add #10 ; Upload to palette 10 or 11 based on player number
	tay
    lda TableData+3
	and #255
	jsl DoPaletteUpload
	; Switch which destination buffer is used based on player number
	pla
	asl
	tay
	lda Destinations,y
	tay ; Bottom 16 bits of destination

	lda TableData+2
	and #$00FF ; Source bank byte
	ora #$7F00 ; Destination bank byte
	ldx TableData ; Bottom 16 bits of source
	jsl SFX_LZ4_decompress

	plx
	rtl

CharacterData:
	.faraddr AlexGraphics
	.byt Palette::CharacterAlex

	.faraddr IchugoGraphics
	.byt Palette::CharacterIchugo

	.faraddr RocketGraphics
	.byt Palette::CharacterRocket

Destinations:
	.addr Player1CharacterGraphics
	.addr Player2CharacterGraphics
.endproc

.segment "Alex"
AlexGraphics:
	.incbin "../tilesetsX/lz4/Alex.chr.lz4"
.segment "Ichugo"
IchugoGraphics:
	.incbin "../tilesetsX/lz4/Ichugo.chr.lz4"
.segment "Rocket"
RocketGraphics:
	.incbin "../tilesetsX/lz4/Rocket.chr.lz4"
