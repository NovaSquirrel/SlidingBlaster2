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
CannonOffX = 8
CannonOffY = 10
CannonTile = 12

; X positions, to make it easier to get the high X bit from them
Fan1X = 14
Fan2X = 16
CannonX = 18
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
  add #-8+GAMEPLAY_SPRITE_Y_OFFSET
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
    ora #%1111111111000000
  :
  sta CannonOffX
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
  sta CannonOffY
  plx

  lda PlayerShootAngle,x ; .......n nnnnnnn0
  add #32
  asl                    ; ......nn nnnnnn00
  asl                    ; .....nnn nnnnn000
  xba
  pha
  and #3
  add #CANNON_TILE_ID | OAM_PRIORITY_2
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
 
  ; Calculate sprite X positions in 16-bit mode
  lda BaseX
  add FanXOffset
  sta Fan1X
  add #8+3
  sta Fan2X
  lda BaseX
  add #4
  add CannonOffX
  sta CannonX

  seta8
  lda BaseX
  sta OAM_XPOS+(4*2),y
  lda Fan1X
  sta OAM_XPOS+(4*0),y
  lda Fan2X
  sta OAM_XPOS+(4*1),y
  lda CannonX
  sta OAM_XPOS+(4*3),y ; Cannon

  lda BaseY
  sta OAM_YPOS+(4*2),y
  sta OAM_YPOS+(4*0),y
  sta OAM_YPOS+(4*1),y
  sta OAM_YPOS+(4*3),y ; Cannon
  lda BaseY
  add #4
  add CannonOffY
  sta OAM_YPOS+(4*3),y

  lda #1 ; 16x16
  asl BaseX+1
  rol
  sta OAMHI+1+(4*2),y
  tdc ; 8x8
  asl Fan1X+1
  rol
  sta OAMHI+1+(4*0),y
  tdc
  asl Fan2X+1
  rol
  sta OAMHI+1+(4*1),y
  tdc
  asl CannonX+1
  rol
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

.a16
.i16
.export UpdatePlayerStatusTiles
.proc UpdatePlayerStatusTiles
  jsl UpdatePlayerAmmoTiles
  jsl UpdatePlayerHealthTiles
  fallthrough UpdatePlayerWeaponTiles
.endproc
.a16
.i16
.proc UpdatePlayerWeaponTiles
  lda #FG_TILE_BASE_COMMON + 16*4 + (BG_ICON_PALETTE << BG_COLOR_SHIFT) + BG_PRIORITY
  sta PlayerStatusTop+3*2,x
  inc
  sta PlayerStatusTop+4*2,x
  lda #FG_TILE_BASE_COMMON + 16*5 + (BG_ICON_PALETTE << BG_COLOR_SHIFT) + BG_PRIORITY
  sta PlayerStatusBottom+3*2,x
  inc
  sta PlayerStatusBottom+4*2,x

  inc PlayerStatusRedraw,x
  rtl
.endproc

.a16
.i16
.export UpdatePlayerAmmoTiles
.proc UpdatePlayerAmmoTiles
  lda #FG_TILE_BASE_COMMON + 16 + 10 + (BG_ICON_PALETTE << BG_COLOR_SHIFT) + BG_PRIORITY
  sta PlayerStatusTop,x

  phx
  lda PlayerAmmo,x
  tax
  lda f:BCD100Table,x
  plx
  and #255
  tay
  lsr
  lsr
  lsr
  lsr
  ora #FG_TILE_BASE_COMMON + 16 + (BG_ICON_PALETTE << BG_COLOR_SHIFT) + BG_PRIORITY
  sta PlayerStatusTop+2,x
  tya
  and #15
  ora #FG_TILE_BASE_COMMON + 16 + (BG_ICON_PALETTE << BG_COLOR_SHIFT) + BG_PRIORITY
  sta PlayerStatusTop+4,x

  inc PlayerStatusRedraw,x
  rtl
.endproc

.a16
.i16
.export UpdatePlayerHealthTiles
.proc UpdatePlayerHealthTiles
  lda #FG_TILE_BASE_COMMON + 16 + 11 + (BG_ICON_PALETTE << BG_COLOR_SHIFT) + BG_PRIORITY
  sta PlayerStatusBottom,x

  phx
  lda PlayerHealth,x
  tax
  lda f:BCD100Table,x
  plx
  and #255
  tay
  lsr
  lsr
  lsr
  lsr
  ora #FG_TILE_BASE_COMMON + 16 + (BG_ICON_PALETTE << BG_COLOR_SHIFT) + BG_PRIORITY
  sta PlayerStatusBottom+2,x
  tya
  and #15
  ora #FG_TILE_BASE_COMMON + 16 + (BG_ICON_PALETTE << BG_COLOR_SHIFT) + BG_PRIORITY
  sta PlayerStatusBottom+4,x

  inc PlayerStatusRedraw,x
  rtl
.endproc

BCD100Table:
  .byt $00, $01, $02, $03, $04, $05, $06, $07, $08, $09, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19
  .byt $20, $21, $22, $23, $24, $25, $26, $27, $28, $29, $30, $31, $32, $33, $34, $35, $36, $37, $38, $39
  .byt $40, $41, $42, $43, $44, $45, $46, $47, $48, $49, $50, $51, $52, $53, $54, $55, $56, $57, $58, $59
  .byt $60, $61, $62, $63, $64, $65, $66, $67, $68, $69, $70, $71, $72, $73, $74, $75, $76, $77, $78, $79
  .byt $80, $81, $82, $83, $84, $85, $86, $87, $88, $89, $90, $91, $92, $93, $94, $95, $96, $97, $98, $99

.a16
.i16
.export DrawStatusSprites
.proc DrawStatusSprites
  ldy OamPtr

  ; ---------------------------------------------------------------------------
  ; Player 1 active
  lda #$0200  ; Use 16x16 sprites
  sta OAMHI+(4*0),y
  sta OAMHI+(4*1),y
  sta OAMHI+(4*2),y
  sta OAMHI+(4*3),y
  sta OAMHI+(4*4),y

  lda #SP_TILE_BASE_PLAYER + (SP_CRITTER1_PALETTE << OAM_COLOR_SHIFT) + OAM_PRIORITY_3
  sta OAM_TILE+(4*0),y
  lda #SP_TILE_BASE_PLAYER + 2 + (SP_CRITTER1_PALETTE << OAM_COLOR_SHIFT) + OAM_PRIORITY_3
  sta OAM_TILE+(4*1),y
  lda #SP_TILE_BASE_PLAYER + 4 + (SP_CRITTER1_PALETTE << OAM_COLOR_SHIFT) + OAM_PRIORITY_3
  sta OAM_TILE+(4*2),y
  lda #SP_TILE_BASE_PLAYER + 6 + (SP_CRITTER1_PALETTE << OAM_COLOR_SHIFT) + OAM_PRIORITY_3
  sta OAM_TILE+(4*3),y
  
  seta8
  lda #8
  sta OAM_XPOS+(4*0),y
  sta OAM_XPOS+(4*2),y
  lda #8+16
  sta OAM_XPOS+(4*1),y
  sta OAM_XPOS+(4*3),y

  lda #184
  sta OAM_YPOS+(4*0),y
  sta OAM_YPOS+(4*1),y
  add #16
  sta OAM_YPOS+(4*2),y
  sta OAM_YPOS+(4*3),y
  seta16

  tya
  add #4*4
  sta OamPtr
  tay
  ; ---------------------------------------------------------------------------
  ; Player 2 active
  lda #$0200  ; Use 16x16 sprites
  sta OAMHI+(4*0),y
  sta OAMHI+(4*1),y
  sta OAMHI+(4*2),y
  sta OAMHI+(4*3),y
  sta OAMHI+(4*4),y

  lda #SP_TILE_BASE_PLAYER + 2 + 8 + (SP_CRITTER2_PALETTE << OAM_COLOR_SHIFT) + OAM_PRIORITY_3 + OAM_XFLIP
  sta OAM_TILE+(4*0),y
  lda #SP_TILE_BASE_PLAYER + 0 + 8 + (SP_CRITTER2_PALETTE << OAM_COLOR_SHIFT) + OAM_PRIORITY_3 + OAM_XFLIP
  sta OAM_TILE+(4*1),y
  lda #SP_TILE_BASE_PLAYER + 6 + 8+ (SP_CRITTER2_PALETTE << OAM_COLOR_SHIFT) + OAM_PRIORITY_3 + OAM_XFLIP
  sta OAM_TILE+(4*2),y
  lda #SP_TILE_BASE_PLAYER + 4 + 8 + (SP_CRITTER2_PALETTE << OAM_COLOR_SHIFT) + OAM_PRIORITY_3 + OAM_XFLIP
  sta OAM_TILE+(4*3),y
  
  seta8
  lda #216
  sta OAM_XPOS+(4*0),y
  sta OAM_XPOS+(4*2),y
  lda #216+16
  sta OAM_XPOS+(4*1),y
  sta OAM_XPOS+(4*3),y

  lda #184
  sta OAM_YPOS+(4*0),y
  sta OAM_YPOS+(4*1),y
  add #16
  sta OAM_YPOS+(4*2),y
  sta OAM_YPOS+(4*3),y
  seta16

  tya
  add #4*4
  sta OamPtr
  ; ---------------------------------------------------------------------------
  rtl
.endproc
