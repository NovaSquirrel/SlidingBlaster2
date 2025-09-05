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
.include "paletteenum.s"
.include "actorenum.s"
.smart
.import GameMainLoop, UploadLevelGraphics

.segment "C_LevelDecompress"

; Accumulator = level number
; Make sure the screen is off before calling this routine!
.a16
.i16
.export StartLevel, StartLevelFromDoor
.proc StartLevel
  sta LevelNumber

  setaxy16
::StartLevelFromDoor:
  ldx #$1ff
  txs ; Reset the stack pointer so no cleanup is needed
  jsr StartLevelCommon
  jsl UploadLevelGraphics
  jml GameMainLoop
.endproc

; Stuff that's done whether a level is started from scratch or resumed
.proc StartLevelCommon
  jsl DecompressLevel
  phk ; Change the data bank back to something with the first 8KB of RAM visible
  plb
  rts
.endproc

; .----------------------------------------------------------------------------
; | Header parsing
; '----------------------------------------------------------------------------
; Loads the level whose header is pointed to by LevelHeaderPointer
.a16
.i16
.export DecompressLevel
.proc DecompressLevel
  ; Clear out some buffers before the level loads stuff into them

  ldx #Player1
  jsr ResetPlayerVariables
  ldx #Player2
  jsr ResetPlayerVariables

  ; Init Actor, particle memory
  ldx #ActorStart
  ldy #ParticleEnd-ActorStart
  jsl MemClear

  ; Clear level buffer
  ldx #.loword(LevelBuf)
  ldy #LevelBuf_End - LevelBuf
  jsl MemClear7F

  ; ------------ Initialize variables ------------
  ; Clear a bunch of stuff in one go that's in contiguous space in memory
  ldx #LevelZeroWhenLoad_Start
  ldy #LevelZeroWhenLoad_End-LevelZeroWhenLoad_Start
  jsl MemClear

  lda LevelNumber
  asl
  adc LevelNumber
  tax
  seta8
  ; Health
  lda #20
  sta Player1+PlayerHealth
  sta Player2+PlayerHealth
  sta Player1+PlayerActive

  ; Set up the level pointer
  lda f:LevelSequence+0,x
  sta LevelHeaderPointer+0
  lda f:LevelSequence+1,x
  sta LevelHeaderPointer+1
  lda f:LevelSequence+2,x
  sta LevelHeaderPointer+2
  cmp #$ff
  bne :+
    dec LevelNumber
    lda LevelNumber
    jmp StartLevel
  :

  ; -----------------------------------

  ; Parse the level header

  ; Music and starting player direction
  lda [LevelHeaderPointer]

  ldy #1
  ; Starting X position
  lda [LevelHeaderPointer],y
  sta Player1+PlayerPX+1
  lda #$80
  sta Player1+PlayerPX+0
  stz Player1+PlayerPXSub

  iny ; Y = 2
  ; Starting Y position
  lda [LevelHeaderPointer],y
  sta Player1+PlayerPY+1
  lda #$80
  sta Player1+PlayerPY+0
  stz Player1+PlayerPYSub

  ; Unused, a good place to put flags
  iny ; Y = 3
  lda [LevelHeaderPointer],y

  ; Background color
  iny ; Y = 4
  stz CGADDR
  lda [LevelHeaderPointer],y
  sta LevelBackgroundColor+0
  sta CGDATA
  iny ; Y = 5
  lda [LevelHeaderPointer],y
  sta LevelBackgroundColor+1
  sta CGDATA

  ; Actor wave count
  iny ; Y = 6
  lda [LevelHeaderPointer],y
  sta ActorWaveCount
  stz ActorWaveNumber

  ; Actor tilesets
  iny ; Y = 7
: lda [LevelHeaderPointer],y
  sta ActorTilesetSlots-7,y
  iny
  cpy #7+8 ;15
  bne :-

  ; Actor palettes
  ; Y = 15
: lda [LevelHeaderPointer],y
  sta ActorPaletteSlots-14,y
  iny
  cpy #15+3 ;18
  bne :-
  lda #Palette::Icons
  sta ActorPaletteSlots + 3
  ; Y = 18

  ; Actor data pointer
  lda [LevelHeaderPointer],y
  sta LevelActorPointer+0
  iny
  lda [LevelHeaderPointer],y
  sta LevelActorPointer+1

  ; Level data is at the end
  iny
  lda [LevelHeaderPointer],y
  sta LevelDataPointer+0
  iny
  lda [LevelHeaderPointer],y
  sta LevelDataPointer+1

  ; Copy over the bank number
  lda LevelHeaderPointer+2
  sta LevelActorPointer+2
  sta LevelDataPointer+2

  ; -----------------------------------
  ; Decompress the data

  setaxy16
  .import SFX_LZ4_decompress
  ldx LevelDataPointer             ; Input address
  ldy #.loword(DecompressBuffer)   ; Output address
  lda LevelDataPointer+2           ; Input bank
  and #255
  ora #(^DecompressBuffer <<8)     ; Output bank
  jsl SFX_LZ4_decompress

  ; Point the data bank at bank $7F, where DecompressBuffer is
  ph2banks DecompressBuffer, DecompressBuffer
  plb
  plb

  ; Initialize the two indices
  ldx #0
  txy

  ; Expand the decompressed level out so that each block is two bytes
  ; and convert it to column major.
DecompressLoop:
  lda DecompressBuffer,y
  ; Move right one block in the decompressed data
  iny
  cpy #LEVEL_WIDTH * LEVEL_HEIGHT * 2 ; Went past the end of the decompressed data?
  bcs DoneExpanding
  and #255
  asl
  sta f:LevelBuf,x
  inx
  inx
  cpx #LEVEL_BUFFER_SIZE
  bne :+
    ldx #BackLevelBuf - LevelBuf ; Skip ahead
  :
  bra DecompressLoop
DoneExpanding:

  lda #Block::BlueEngraved ; Any solid block will do
  sta LevelBufSolidTile

  phk
  plb

  ; Initialize variables for optimizations
  lda #ActorEnd
  sta ActorIterationLimit
  lda #ParticleEnd
  sta ParticleIterationLimit

  ; Initialize gameplay variables here
  jsr SpawnLevelActors

  rtl
.endproc

.proc ResetPlayerVariables
  stz PlayerPXSub,x
  stz PlayerPX,x
  stz PlayerPYSub,x
  stz PlayerPY,x
  stz PlayerVXSub,x
  stz PlayerVX,x
  stz PlayerVYSub,x
  stz PlayerVY,x
  stz PlayerBoostTimer,x
  stz PlayerAmmo,x
  stz PlayerShootAngle,x
  stz PlayerMoveAngle,x
  stz PlayerWidth,x
  stz PlayerHeight,x
  stz PlayerHealth,x
  lda #2
  sta PlayerSpeed,x
  stz PlayerTileBase,x
  stz PlayerStatusTop+0*2,x
  stz PlayerStatusTop+1*2,x
  stz PlayerStatusTop+2*2,x
  stz PlayerStatusTop+3*2,x
  stz PlayerStatusTop+4*2,x
  stz PlayerStatusTop+5*2,x
  stz PlayerStatusBottom+0*2,x
  stz PlayerStatusBottom+1*2,x
  stz PlayerStatusBottom+2*2,x
  stz PlayerStatusBottom+3*2,x
  stz PlayerStatusBottom+4*2,x
  stz PlayerStatusBottom+5*2,x
  stz PlayerFrameID,x
  stz PlayerFrameIDLast,x
  stz PlayerNoAmmoMessage,x
  stz PlayerNoAmmoPity,x
  stz PlayerKeyDown,x
  stz PlayerKeyLast,x
  stz PlayerKeyNew,x
  stz PlayerSpeedupTimer,x
  stz PlayerHurtTimer,x
  rts
.endproc

.import ActorClearX, InitActorX
.a16
.i16
.export SpawnLevelActors
.proc SpawnLevelActors
	ldy #0
Loop:
	; Format: x|(y<<4), type, extra
	lda [LevelActorPointer],y
	and #255
	cmp #255 ; End of the list
	bne :+
	Exit:
		tya
		sec ; Skip past the 255
		adc LevelActorPointer
		sta LevelActorPointer
		rts
	:
	jsl FindFreeActorX
	bcc Exit

	; Position byte
	stz ActorPXSub,x
	stz ActorPYSub,x
	lda [LevelActorPointer],y
	and #255
	pha
	and #$0f
	xba
	ora #$80
	sta ActorPX,x
	pla
	and #$f0
	lsr
	lsr
	lsr
	lsr
	xba
	ora #$80
	sta ActorPY,x

	jsl ActorClearX

	lda #Actor::EnemyPortal*2
	sta ActorType,x

	; Type byte
	iny
	lda [LevelActorPointer],y
	and #255
	asl
	sta ActorVarB,x

	; Extra byte
	iny
	lda [LevelActorPointer],y
	and #255
	sta ActorVarA,x

	iny
	bra Loop
.endproc

LevelSequence:
  .import level_real, level_maze, level_maze2, level_park, level_win
  .faraddr level_real
  .faraddr level_maze
  .faraddr level_maze2
  .faraddr level_park
  .faraddr level_win
  .faraddr $ffffff

