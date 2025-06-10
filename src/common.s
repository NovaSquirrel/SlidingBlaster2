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

; Sets Y to point to a specific coordinate in the level
; input: A (X position in 12.4 format), Y (Y position in 12.4 format)
; output: Y is set, also A = block at column,row
.a16
.i16
.proc GetLevelIndexXY
  ; LevelBuf index format:
  ; 0000000y yyyxxxx0
  cmp #LEVEL_WIDTH << 8
  bcs OutOfBounds
  cpy #LEVEL_HEIGHT << 8
  bcs OutOfBounds
  ; X position      0000XXXX xxxxxxxx
  xba             ; xxxxxxxx 0000XXXX
  asl             ; xxxxxxx0 000XXXX0
  and #%11110     ; 00000000 000XXXX0
  pha

  ; Y position
  tya             ; 0000YYYY yyyyyyyy
  lsr             ; 00000YYY Yyyyyyyy
  lsr             ; 000000YY YYyyyyyy
  lsr             ; 0000000Y YYYyyyyy
  and #%111100000 ; 0000000Y YYY00000
  ora 1,s         ; 0000000Y YYYXXXX0 
  tay
  pla ; Clean up the stack

  lda LevelBuf,y
  rtl

OutOfBounds:
  ldy #LevelBufSolidTile - LevelBuf
  lda #Block::BlueEngraved ; Can be anything solid
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
; input: A (new block), Y (index of block to change)
; locals: BlockTemp
.a16
.i16
.proc ChangeBlock
ADDRESS = 0 ; Offset for scatter buffer
DATA    = 2 ; Offset for scatter buffer 
BlockType = BlockTemp
Temp2     = BlockTemp+2
  phx
  phy
  php
  setaxy16
  sta LevelBuf,y ; Make the change in the level buffer itself
  sta BlockType

  lda ScatterUpdateLength
  cmp #SCATTER_BUFFER_LENGTH - (4*4) + 1 ; There needs to be enough room for four tiles
  bcc :+
    ; If not, try to do it later
    lda #1
    sta BlockTemp ; Timer
    lda BlockType
    jsl DelayChangeBlock ; Takes A and Y just like ChangeBlock
    jmp Exit
  :

  ; -----------------------------------

  ; Copy the block appearance into the update buffer
  phy
  ldy ScatterUpdateLength
  ldx BlockType
  .import BlockTopLeft, BlockTopRight, BlockBottomLeft, BlockBottomRight
  lda f:BlockTopLeft,x
  sta ScatterUpdateBuffer+(4*0)+DATA,y
  lda f:BlockTopRight,x
  sta ScatterUpdateBuffer+(4*1)+DATA,y
  lda f:BlockBottomLeft,x
  sta ScatterUpdateBuffer+(4*2)+DATA,y
  lda f:BlockBottomRight,x
  sta ScatterUpdateBuffer+(4*3)+DATA,y
  tyx
  ply
  ldx ScatterUpdateLength

  ; Now calculate the PPU address
  ; Index is        0000000yyyyxxxx0
  ; Needs to become 0....pyyyyyxxxxx
  tya
  and                    #%111100000
  asl
  sta ScatterUpdateBuffer+(4*0)+ADDRESS,x
  tya
  and                    #%000011110
  ora ScatterUpdateBuffer+(4*0)+ADDRESS,x
  add #ForegroundBG+32
  sta ScatterUpdateBuffer+(4*0)+ADDRESS,x
  ; Set up the addresses for the other three tiles
  ina
  sta ScatterUpdateBuffer+(4*1)+ADDRESS,x
  add #31
  sta ScatterUpdateBuffer+(4*2)+ADDRESS,x
  ina
  sta ScatterUpdateBuffer+(4*3)+ADDRESS,x

  txa
  adc #16 ; Carry guaranteed to be clear due to the above "add"
  sta ScatterUpdateLength

  ; Restore registers
Exit:
  plp
  ply
  plx
  rtl
.endproc


; Changes a block, in the future!
; input: A (new block), Y (block to change), BlockTemp (Time amount)
.a16
.i16
.proc DelayChangeBlock
  phx
  phy

  pha

  ; Find an unused slot
  ldx #(MaxDelayedBlockEdits-1)*2
DelayedBlockLoop:
  lda DelayedBlockEditTime,x
  beq Found                  ; Found an empty slot!
  dex
  dex
  bpl DelayedBlockLoop
  bra Fail

Found:
  pla
  sta DelayedBlockEditType,x

  lda BlockTemp
  sta DelayedBlockEditTime,x

  tya
  sta DelayedBlockEditAddr,x
Exit:
  ply
  plx
  rtl
Fail:
  pla
  ply
  plx
  rtl
.endproc


; Gets the column number of Y
.a16
.proc GetBlockX
  ; LevelBuf index format:
  ; 0000000y yyyxxxx0
  tya
  lsr
  and #15
  rtl
.endproc


; Set accumulator to X coordinate of Y
.a16
.proc GetBlockXCoord
  ; LevelBuf index format:
  ; 0000000y yyyxxxx0
  tya
  lsr
  and #15
  xba
  rtl
.endproc

; Get the row number of Y
.a16
.proc GetBlockY
  ; LevelBuf index format:
  ; 0000000y yyyxxxx0
  tya
  asl
  asl
  asl
  xba
  and #$ff00
  rtl
.endproc

; Set accumulator to Y coordinate of LevelBlockPtr
.a16
.proc GetBlockYCoord
  ; LevelBuf index format:
  ; 0000000y yyyxxxx0
  tya
  asl
  asl
  asl
  and #$ff00
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

  jsl UpdatePlayerKeys

  stz OamPtr
  plp
  rtl
.endproc

.a16
.proc UpdatePlayerKeys
  lda Player1+PlayerKeyDown
  sta Player1+PlayerKeyLast
  lda JOY1CUR
  sta Player1+PlayerKeyDown
  lda Player1+PlayerKeyLast
  eor #$ffff
  and Player1+PlayerKeyDown
  sta Player1+PlayerKeyNew

  lda Player2+PlayerKeyDown
  sta Player2+PlayerKeyLast
  lda JOY2CUR
  sta Player2+PlayerKeyDown
  lda Player2+PlayerKeyLast
  eor #$ffff
  and Player2+PlayerKeyDown
  sta Player2+PlayerKeyNew
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

.if 0
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
.endif
