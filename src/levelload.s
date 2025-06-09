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
.import GameMainLoop, UploadLevelGraphics

.segment "C_LevelDecompress"

; Accumulator = level number
.a16
.i16
.export StartLevel, StartLevelFromDoor
.proc StartLevel
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

  ; Init player, actor, particle memory
  ldx #Player1
  ldy #ParticleEnd-Player1
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

  seta8
  ; Health
  lda #20
  sta Player1+PlayerHealth
  sta Player2+PlayerHealth

  ; TODO
  .import level_demo
  lda #<level_demo
  sta LevelHeaderPointer+0
  lda #>level_demo
  sta LevelHeaderPointer+1
  lda #^level_demo
  sta LevelHeaderPointer+2

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

  ; Actor data pointer
  iny ; Y = 6
  lda [LevelHeaderPointer],y
  sta LevelActorPointer+0
  iny ; Y = 7
  lda [LevelHeaderPointer],y
  sta LevelActorPointer+1

  ; Level data is at the end
  iny ; Y = 8
  lda [LevelHeaderPointer],y
  sta LevelDataPointer+0
  iny ; Y = 9
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

  ; Initialize gameplay variables
  lda #2
  sta Player1+PlayerSpeed

  rtl
.endproc
