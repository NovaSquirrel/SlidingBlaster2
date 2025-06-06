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
.smart

.code

; Sets LevelBlockPtr to the start of a given column in the level, then reads a specific row
; input: A (column), Y (row)
; output: LevelBlockPtr is set, also A = block at column,row
; Verify that LevelBlockPtr+2 is #^LevelBuf
.a16
.proc GetLevelColumnPtr
  ; Multiply by 32 (level height) and then once more for 16-bit values
  and #255
  asl ; * 2
  asl ; * 4
  asl ; * 8
  asl ; * 16
  asl ; * 32
  asl ; * 64
  sta LevelBlockPtr

  lda [LevelBlockPtr],y
  rtl
.endproc

; Sets LevelBlockPtr to point to a specific coordinate in the level
; input: A (X position in 12.4 format), Y (Y position in 12.4 format)
; output: LevelBlockPtr is set, also A = block at column,row
; Verify that LevelBlockPtr+2 is #^LevelBuf
.a16
.i16
.proc GetLevelPtrXY
  ; X position * 64
  lsr
  lsr
  and #%0011111111000000
  sta LevelBlockPtr
  ; 00xxxxxxxx000000

  ; Y position
  tya
  xba
  asl
  and #63
  tsb LevelBlockPtr
  ; 00xxxxxxxxyyyyy0

  lda [LevelBlockPtr]
  rtl
.endproc

; Get BlockFlag for the block ID in the accumulator
.a16
.i16
.proc GetBlockFlag
  tax
  lda f:BlockFlags,x
  sta BlockFlag
  rtl
.endproc

; Wait for a Vblank using WAI instead of a busy loop
.proc WaitVblank
  php
  seta8
loop1:
  bit VBLSTATUS  ; Wait for leaving previous vblank
  bmi loop1
loop2:
  wai
  bit VBLSTATUS  ; Wait for start of this vblank
  bpl loop2
  plp
  rtl
.endproc


; Changes a block in the level immediately and queues a PPU update.
; input: A (new block), LevelBlockPtr (block to change)
; locals: BlockTemp
.a16
.i16
.proc ChangeBlock
ADDRESS = 0
DATA    = 2
Temp    = BlockTemp
; Could reserve a second variable to avoid calling GetBlockX twice
  phx
  phy
  php
  setaxy16
  sta [LevelBlockPtr] ; Make the change in the level buffer itself

  ldy ScatterUpdateLength
  cpy #SCATTER_BUFFER_LENGTH - (4*4) + 1 ; There needs to be enough room for four tiles
  bcc :+
    ; Instead try to do it later
    ldy #1
    sty BlockTemp
    jsl DelayChangeBlock ; Takes A and LevelBlockPtr just like ChangeBlock
    jmp Exit
  :

  ; From this point on in the routine, Y = index to write into the scatter buffer

  ; Save block number in X specifically, for 24-bit Absolute Indexed
  tax
  ; Now the accumulator is free to do other things

  ; -----------------------------------

  ; Copy the block appearance into the update buffer
  .import BlockTopLeft, BlockTopRight, BlockBottomLeft, BlockBottomRight
  lda f:BlockTopLeft,x
  sta ScatterUpdateBuffer+(4*0)+DATA,y
  lda f:BlockTopRight,x
  sta ScatterUpdateBuffer+(4*1)+DATA,y
  lda f:BlockBottomLeft,x
  sta ScatterUpdateBuffer+(4*2)+DATA,y
  lda f:BlockBottomRight,x
  sta ScatterUpdateBuffer+(4*3)+DATA,y

  ; Now calculate the PPU address
  ; LevelBlockPtr is 00xxxxxxxxyyyyy0 (for horizontal levels)
  ; Needs to become  0....pyyyyyxxxxx
  lda Temp ; still GetBlockY's result
  asl
  and #%11110 ; Grab Y & 15
  asl
  asl
  asl
  asl
  asl
  ora #ForegroundBG
  sta ScatterUpdateBuffer+(4*0)+ADDRESS,y

CalculateRestOfAddress:
  ; Add in X
  jsl GetBlockX
  pha
  and #15
  asl
  ora ScatterUpdateBuffer+(4*0)+ADDRESS,y
  sta ScatterUpdateBuffer+(4*0)+ADDRESS,y
  ina
  sta ScatterUpdateBuffer+(4*1)+ADDRESS,y

  ; Choose second screen if needed
  pla
  and #16
  beq :+
    lda ScatterUpdateBuffer+(4*0)+ADDRESS,y
    ora #2048>>1
    sta ScatterUpdateBuffer+(4*0)+ADDRESS,y
    lda ScatterUpdateBuffer+(4*1)+ADDRESS,y
    ora #2048>>1
    sta ScatterUpdateBuffer+(4*1)+ADDRESS,y
  :

  ; Precalculate the bottom row
  lda ScatterUpdateBuffer+(4*0)+ADDRESS,y
  add #(32*2)>>1
  sta ScatterUpdateBuffer+(4*2)+ADDRESS,y
  ina
  sta ScatterUpdateBuffer+(4*3)+ADDRESS,y

  tya
  adc #16 ; Carry guaranteed to be clear
  sta ScatterUpdateLength

  ; Restore registers
Exit:
  plp
  ply
  plx
  rtl
.endproc


; Changes a block, in the future!
; input: A (new block), LevelBlockPtr (block to change), BlockTemp (Time amount)
.a16
.i16
.proc DelayChangeBlock
  phx
  phy

  ; Find an unused slot
  ldx #(MaxDelayedBlockEdits-1)*2
DelayedBlockLoop:
  ldy DelayedBlockEditTime,x ; Load Y to set flags only
  beq Found                  ; Found an empty slot!
  dex
  dex
  bpl DelayedBlockLoop
  bra Exit ; Fail

Found:
  sta DelayedBlockEditType,x

  lda BlockTemp
  sta DelayedBlockEditTime,x

  lda LevelBlockPtr
  sta DelayedBlockEditAddr,x

Exit:
  ply
  plx
  rtl
.endproc


; Gets the column number of LevelBlockPtr
.a16
.proc GetBlockX
  lda LevelBlockPtr ; Get level column
  asl
  asl
  xba
  and #255
  rtl
.endproc


; Set accumulator to X coordinate of LevelBlockPtr
.a16
.proc GetBlockXCoord
  lda LevelBlockPtr ; Get level column
  asl
  asl
  and #$ff00
  rtl
.endproc

.a16
.export GetBlockXCoord_Vertical
.proc GetBlockXCoord_Vertical
  ; 00xxxxxyyyyyyyy0
  lda LevelBlockPtr ; Get level column
  lsr
  and #%11111 * 256
  rtl
.endproc

; Get the row number of LevelBlockPtr
.a16
.proc GetBlockY
  lda LevelBlockPtr ; Get level row
  lsr
  and #31
  rtl
.endproc

; Set accumulator to Y coordinate of LevelBlockPtr
.a16
.proc GetBlockYCoord
  lda LevelBlockPtr ; Get level row
  lsr
  and #31
  xba
  rtl
.endproc

.a16
.export GetBlockYCoord_Vertical
.proc GetBlockYCoord_Vertical
  ; 00xxxxxyyyyyyyy0
  lda LevelBlockPtr ; Get level row
  lsr
  and #255
  xba
  rtl
.endproc

; Random number generator
; From http://wiki.nesdev.com/w/index.php/Random_number_generator/Linear_feedback_shift_register_(advanced)#Overlapped_24_and_32_bit_LFSR
; output: A (random number)
.proc RandomByte
  phx ; Needed because setaxy8 will clear the high byte of X
  phy
  php
  setaxy8
  tdc ; Clear A, including the high byte

  seed = random1
  ; rotate the middle bytes left
  ldy seed+2 ; will move to seed+3 at the end
  lda seed+1
  sta seed+2
  ; compute seed+1 ($C5>>1 = %1100010)
  lda seed+3 ; original high byte
  lsr
  sta seed+1 ; reverse: 100011
  lsr
  lsr
  lsr
  lsr
  eor seed+1
  lsr
  eor seed+1
  eor seed+0 ; combine with original low byte
  sta seed+1
  ; compute seed+0 ($C5 = %11000101)
  lda seed+3 ; original high byte
  asl
  eor seed+3
  asl
  asl
  asl
  asl
  eor seed+3
  asl
  asl
  eor seed+3
  sty seed+3 ; finish rotating byte 2 into 3
  sta seed+0

  plp
  ply
  plx
  rtl
.endproc

; Randomly negates the input you give it
.a16
.proc VelocityLeftOrRight
  pha
  jsl RandomByte
  lsr
  bcc Right
Left:
  pla
  eor #$ffff
  ina
  rtl
Right:
  pla
  rtl
.endproc

.a16
.proc FadeIn
  php

  seta8
  lda #$1
: pha
  jsl WaitVblank
  pla
  sta PPUBRIGHT
  ina
  ina
  cmp #$0f+2
  bne :-

  plp
  rtl
.endproc

.a16
.proc FadeOut
  php

  seta8
  lda #$11
: pha
  jsl WaitVblank
  pla
  dea
  dea
  sta PPUBRIGHT
  bpl :-
  lda #FORCEBLANK
  sta PPUBRIGHT

  plp
  rtl
.endproc

.proc WaitKeysReady
  php
  seta8
  ; Wait for the controller to be ready
  lda #$01
padwait:
  bit VBLSTATUS
  bne padwait
  seta16

  ; -----------------------------------

  lda keydown
  sta keylast
  lda JOY1CUR
  sta keydown
  lda keylast
  eor #$ffff
  and keydown
  sta keynew
  stz OamPtr
  plp
  rtl
.endproc

; Quickly clears a section of WRAM
; Inputs: X (address), Y (size)
.i16
.proc MemClear
  php
  seta8
  stz WMADDH ; high bit of WRAM address
UseHighHalf:
  stx WMADDL ; WRAM address, bottom 16 bits
  sty DMALEN

  ldx #DMAMODE_RAMFILL
ZeroSource:
  stx DMAMODE

  ldx #.loword(ZeroSource+1)
  stx DMAADDR
  lda #^MemClear
  sta DMAADDRBANK

  lda #$01
  sta COPYSTART
  plp
  rtl
.endproc

; Quickly clears a section of the second 64KB of RAM
; Inputs: X (address), Y (size)
.i16
.a16
.proc MemClear7F
  php
  seta8
  lda #1
  sta WMADDH
  bra MemClear::UseHighHalf
.endproc

.export KeyRepeat
.proc KeyRepeat
  php
  seta8
  lda keydown+1
  beq NoAutorepeat
  cmp keylast+1
  bne NoAutorepeat
  inc AutoRepeatTimer
  lda AutoRepeatTimer
  cmp #12
  bcc SkipNoAutorepeat

  lda retraces
  and #3
  bne :+
    lda keydown+1
    and #>(KEY_LEFT|KEY_RIGHT|KEY_UP|KEY_DOWN)
    sta keynew+1
  :

  ; Keep it from going up to 255 and resetting
  dec AutoRepeatTimer
  bne SkipNoAutorepeat
NoAutorepeat:
  stz AutoRepeatTimer
SkipNoAutorepeat:
  plp
  rtl
.endproc
