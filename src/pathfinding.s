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
.include "blockenum.s"
.smart

.segment "C_Pathfinding"

; A = Potential Dijkstra map index
.macro CheckPotentialTile Map
	.local @Skip, @AddToQueue, @Wall
	tax

	; If this index already has a distance on it, skip
	lda Map,x
	and #255
	cmp #255
	bne @Skip

	; It's 255, so it hasn't been checked yet
	stx PotentialDijkstraMapIndex
	; Convert to level buffer index and check the level; is that tile solid?
	txa
	asl
	tax
	lda LevelBuf,x
	tax
	lda f:BlockFlags,x
	bmi @Wall
@AddToQueue:
	; Not solid, so assign a distance and add it to the queue
	ldx DijkstraMapQueueWriteIndex
	seta8
	; Put the index into the queue
	lda PotentialDijkstraMapIndex
	sta DijkstraMapQueueBuffer,x
	inc DijkstraMapQueueWriteIndex

	; Copy the distance over, but incremented
	ldx CurrentDijkstraMapIndex
	lda Map,x
	ina
	ldx PotentialDijkstraMapIndex
	sta Map,x
	seta16
	bra @Skip
@Wall:
	; If it's a wall, mark it as maximum distance
	ldx PotentialDijkstraMapIndex
	seta8
	lda #254
	sta Map,x
	seta16
@Skip:
.endmacro

.macro RunPathfindingQueue Map
	.local ProcessLoop, @SkipLeft, @SkipRight, @SkipUp, @SkipDown, @StopEarly
	ldy DijkstraMapQueueReadIndex
ProcessLoop:
	lda DijkstraMapQueueBuffer,y
	iny
	and #255
	sta CurrentDijkstraMapIndex

	; Left
	bit #%00001111
	beq @SkipLeft
		lda CurrentDijkstraMapIndex
		dea
		CheckPotentialTile Map
	@SkipLeft:

	; --------

	; Right
	lda CurrentDijkstraMapIndex
	and #%00001111
	cmp #%00001111
	beq @SkipRight
		lda CurrentDijkstraMapIndex
		ina
		CheckPotentialTile Map
	@SkipRight:

	; --------

	; Up
	lda CurrentDijkstraMapIndex
	bit #%11110000
	beq @SkipUp
		sub #16
		CheckPotentialTile Map
	@SkipUp:

	; --------

	; Down
	lda CurrentDijkstraMapIndex
	cmp #12 << 4
	bcs @SkipDown
		add #16
		CheckPotentialTile Map
	@SkipDown:

	; --------

	; Still more to go?
	dec Limit
	beq @StopEarly
	cpy DijkstraMapQueueWriteIndex
	jne ProcessLoop
	stz DijkstraMapStatus
	lda WhichDijkstraMap
	eor #256
	sta WhichDijkstraMap
	rtl
@StopEarly:
	sty DijkstraMapQueueReadIndex
	rtl
.endmacro

.a16
.i16
.export UpdateDijkstraMaps
.proc UpdateDijkstraMaps
Limit = 0
CurrentDijkstraMapIndex = 2
PotentialDijkstraMapIndex = 4
	lda DijkstraMapStatus
	jeq InitDijkstraMap
Process:
	lda #16
	sta Limit

	lda WhichDijkstraMap ; Work on the map that isn't being currently used
	jeq Map2
Map1:
	RunPathfindingQueue LevelDijkstraMap1
Map2:
	RunPathfindingQueue LevelDijkstraMap2
	rtl

.a16
.i16
InitDijkstraMap:
	stz DijkstraMapQueueReadIndex
	lda #1
	sta DijkstraMapQueueWriteIndex
	inc DijkstraMapStatus ; Start processing next tick

	; -------------------------------
	; Clear out the map
	lda WhichDijkstraMap
	jeq @Clear2
@Clear1:
	lda #$ffff
	.repeat 96, I ; 16*12/2
	sta LevelDijkstraMap1+2*I
	.endrep
	jmp StartQueue
@Clear2:
	lda #$ffff
	.repeat 96, I
	sta LevelDijkstraMap2+2*I
	.endrep
	fallthrough StartQueue

; Write this after the map is cleared
StartQueue:
	; Start the queue out with the player position
	lda Player1+PlayerPX+1
	and #15
	sta 0
	lda Player1+PlayerPY+1
	and #15
	asl
	asl
	asl
	asl
	ora 0
	sta DijkstraMapQueueBuffer+0
	tax

	lda WhichDijkstraMap
	bne :+
		txa
		ora #256
		tax
	:
	seta8
	lda #1
	sta LevelDijkstraMap1,x
	seta16
	rtl
.endproc
