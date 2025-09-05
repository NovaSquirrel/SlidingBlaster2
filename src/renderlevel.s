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

; This file contains code to draw the 16x16 blocks that levels are made up of.
; RenderLevelScreens will draw the whoel screen, and the other code handles updating
; the screen during scrolling.

.include "snes.inc"
.include "global.inc"
.include "actorenum.s"
.smart
.global LevelBuf
.import BlockTopLeft, BlockTopRight, BlockBottomLeft, BlockBottomRight
.import UpdatePlayerStatusTiles

.segment "C_Player"

COMMON_BASE = 0
RUG_BASE = 512
CLOUD_TILE = RUG_BASE + 16

.a16
.i16
.proc RenderLevelScreen
	; Clear out the status bars
	ldy #BackgroundBG
	lda #RUG_BASE + 1 + BG_PRIORITY + (BG_MISC_PALETTE << BG_COLOR_SHIFT)
	jsr RepeatPPUWrite32
	ldy #ForegroundBG
	lda #0
	jsr RepeatPPUWrite32
	ldy #BackgroundBG + 25*32
	lda #RUG_BASE + 1 + BG_PRIORITY + (BG_MISC_PALETTE << BG_COLOR_SHIFT)
	ldx #3*32
	jsr RepeatPPUWrite
	ldy #ForegroundBG + 25*32
	lda #0
	ldx #3*32
	jsr RepeatPPUWrite

	; Goal board
	lda #ForegroundBG + 25*32 + 13
	sta PPUADDR
	lda #COMMON_BASE + 6*16 + 10 + BG_PRIORITY + (BG_MISC_PALETTE << BG_COLOR_SHIFT)
	sta PPUDATA
	ina
	sta PPUDATA
	ina
	sta PPUDATA
	ina
	sta PPUDATA
	ina
	sta PPUDATA
	ina
	sta PPUDATA
	lda #ForegroundBG + 26*32 + 13
	sta PPUADDR
	lda #COMMON_BASE + 7*16 + 10 + BG_PRIORITY + (BG_MISC_PALETTE << BG_COLOR_SHIFT)
	sta PPUDATA
	ina
	sta PPUDATA
	ina
	sta PPUDATA
	ina
	sta PPUDATA
	ina
	sta PPUDATA
	ina
	sta PPUDATA

	; Clouds
	ldx #0
	lda #CLOUD_TILE + BG_PRIORITY + (BG_MISC_PALETTE << BG_COLOR_SHIFT)
	sta PPUDATA
:	ldy CloudPositions,x
	bmi :+
	sty PPUADDR
	sta PPUDATA
	ina
	sta PPUDATA
	ina
	and #$ffff ^ 4
	inx
	inx
	bra :-
:

	ldx #Player1
	jsl UpdatePlayerStatusTiles
	ldx #Player2
	jsl UpdatePlayerStatusTiles

	ph2banks LevelBuf, LevelBuf
	plb
	plb

	; Actually render the level
	ColumnsLeft = 0
	lda #ForegroundBG + 1*32
	sta f:PPUADDR
	ldy #0
LevelRenderLoop:
	lda #16
	sta ColumnsLeft
:	ldx LevelBuf,y
	iny
	iny
	lda f:BlockTopLeft,x
	sta f:PPUDATA
	lda f:BlockTopRight,x
	sta f:PPUDATA
	dec ColumnsLeft
	bne :-

	tya
	sub #16*2
	tay
	lda #16
	sta ColumnsLeft
:	ldx LevelBuf,y
	iny
	iny
	lda f:BlockBottomLeft,x
	sta f:PPUDATA
	lda f:BlockBottomRight,x
	sta f:PPUDATA
	dec ColumnsLeft
	bne :-

	cpy #12*16*2
	bcc LevelRenderLoop

; -----------------------------------------------

	; Render the background
	lda #BackgroundBG + 1*32
	sta f:PPUADDR
	ldy #0
BackgroundRenderLoop:
	lda #16
	sta ColumnsLeft
:	ldx BackLevelBuf,y
	iny
	iny
	lda #16 + 4 + 512 + (BG_GREEN_GRAY_BROWN << BG_COLOR_SHIFT)
	sta f:PPUDATA
	lda #16 + 5 + 512 + (BG_GREEN_GRAY_BROWN << BG_COLOR_SHIFT)
	sta f:PPUDATA
	dec ColumnsLeft
	bne :-

	tya
	sub #16*2
	tay
	lda #16
	sta ColumnsLeft
:	ldx LevelBuf,y
	iny
	iny
	lda #16 + 6 + 512 + (BG_GREEN_GRAY_BROWN << BG_COLOR_SHIFT)
	sta f:PPUDATA
	lda #16 + 7 + 512 + (BG_GREEN_GRAY_BROWN << BG_COLOR_SHIFT)
	sta f:PPUDATA
	dec ColumnsLeft
	bne :-

	cpy #12*16*2
	bcc BackgroundRenderLoop

	phk
	plb

	jsl UpdateWaveNumber

	rtl

CloudPositions:
	.word BackgroundBG + 25*32 + 0
	.word BackgroundBG + 25*32 + 2
	.word BackgroundBG + 25*32 + 7
	.word BackgroundBG + 25*32 + 10
	.word BackgroundBG + 25*32 + 24
	.word BackgroundBG + 25*32 + 15
	.word BackgroundBG + 25*32 + 28
	.word BackgroundBG + 25*32 + 21
	.word $ffff
.endproc

.a16
.i16
RepeatPPUWrite32:
	ldx #32
RepeatPPUWrite:
	sty PPUADDR
:	sta PPUDATA
	dex
	bne :-
	rts

.a16
.i16
.export UpdateWaveNumber
.proc UpdateWaveNumber
ADDRESS = 0 ; Offset for scatter buffer
DATA    = 2 ; Offset for scatter buffer 
	ldx ScatterUpdateLength

	lda #ForegroundBG + 25*32 + 17
	sta ScatterUpdateBuffer+(4*0)+ADDRESS,x
	lda ActorWaveNumber
	add #COMMON_BASE + 6*16 + 1 + BG_PRIORITY + (BG_MISC_PALETTE << BG_COLOR_SHIFT)
	sta ScatterUpdateBuffer+(4*0)+DATA,x

	lda #ForegroundBG + 26*32 + 17
	sta ScatterUpdateBuffer+(4*1)+ADDRESS,x
	lda ActorWaveNumber
	add #COMMON_BASE + 7*16 + 1 + BG_PRIORITY + (BG_MISC_PALETTE << BG_COLOR_SHIFT)
	sta ScatterUpdateBuffer+(4*1)+DATA,x

	txa
	add #8
	sta ScatterUpdateLength
	rtl
.endproc
