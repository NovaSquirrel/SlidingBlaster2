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
.include "actorframedefine.inc"
.smart

.segment "C_Player"

.import DispActor16x16, DispActorMeta, MathCosTable, MathSinTable

SHOOT_CURSOR_TILE_ID = 0
NORMAL_CURSOR_TILE_ID = 2
PLAYER1_TILE_ID = 4
PLAYER2_TILE_ID = 6
CANNON_TILE_ID = 8
FAN_TILE_ID    = 12


.a16
.i16
.export DrawPlayer
.proc DrawPlayer
BaseX = 0
BaseY = 2
FanTile = 4
FanXOffset = 6
CannonX = 8
CannonY = 10
CannonTile = 12
  phk
  plb

  lda PlayerPX,x
  lsr
  lsr
  lsr
  lsr
  sub #8
  sta BaseX

  lda PlayerPY,x
  lsr
  lsr
  lsr
  lsr
  sub #8
  sta BaseY

  lda framecount
  lsr
  lsr
  and #%11
  asl
  tay
  lda FanAnimationTile,y
  sta FanTile
  lda FanAnimationXOffset,y
  sta FanXOffset

  phx
  lda PlayerShootAngle,x
  tax
  lda f:MathCosTable,x
  php
  lsr
  lsr
  xba
  and #%00111111
  plp
  bpl :+
    ora #%11000000
  :
  sta CannonX
  lda f:MathSinTable,x
  php
  lsr
  lsr
  xba
  and #%00111111
  plp
  bpl :+
    ora #%11000000
  :
  sta CannonY
  plx

  lda PlayerShootAngle,x ; .......n nnnnnnn0
  add #32
  asl                    ; ......nn nnnnnn00
  asl                    ; .....nnn nnnnn000
  xba
  pha
  and #3
  add #CANNON_TILE_ID
  sta CannonTile
  pla
  and #4
  beq :+
    lda #OAM_XFLIP | OAM_YFLIP
    tsb CannonTile
  :

  ldy OamPtr
  lda #PLAYER1_TILE_ID | OAM_PRIORITY_2
  sta OAM_TILE+(4*2),y ; 16-bit, combined with attribute
  lda FanTile
  sta OAM_TILE+(4*0),y
  sta OAM_TILE+(4*1),y
  lda CannonTile
  sta OAM_TILE+(4*3),y ; Cannon

  seta8
  lda BaseX
  sta OAM_XPOS+(4*2),y
  add FanXOffset
  sta OAM_XPOS+(4*0),y
  add #8+3
  sta OAM_XPOS+(4*1),y
  lda BaseX
  add #4
  add CannonX
  sta OAM_XPOS+(4*3),y

  lda BaseY
  sta OAM_YPOS+(4*2),y
  sta OAM_YPOS+(4*0),y
  sta OAM_YPOS+(4*1),y
  sta OAM_YPOS+(4*3),y ; Cannon
  lda BaseY
  add #4
  add CannonY
  sta OAM_YPOS+(4*3),y

  lda #2 ; 16x16
  sta OAMHI+1+(4*2),y
  tdc ; 8x8
  sta OAMHI+1+(4*0),y
  sta OAMHI+1+(4*1),y
  sta OAMHI+1+(4*3),y ; Cannon
  seta16_clc

  tya
  adc #4*4 ; Carry cleared above
  sta OamPtr

  rtl

FanAnimationTile:
  .word FAN_TILE_ID + OAM_PRIORITY_2
  .word FAN_TILE_ID + OAM_PRIORITY_2 + 1
  .word FAN_TILE_ID + OAM_PRIORITY_2 + 2
  .word FAN_TILE_ID + OAM_PRIORITY_2 + 1 + OAM_XFLIP
FanAnimationXOffset:
  .word 0, 0, 0, .loword(-3)
.endproc
