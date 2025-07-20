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

SHOOT_CURSOR_TILE_ID = 14
NORMAL_CURSOR_TILE_ID = $20
CANNON_TILE_ID = (12|$20)

.a16
.i16
.export DrawPlayer
.proc DrawPlayer
BaseX = 0
BaseY = 2
EdgeTile = 4
EdgeX = 6
CannonOffX = 8
CannonOffY = 10
CannonTile = 12
PlayerTile = 14

; 16-bit X positions, to make it easier to get the high X bit from them
CannonX = 16
  phk
  plb

  ; -------------------------------------------------------
  ; First, potentially draw the cursor
  bit8 PlayerControlStyle,x
  bpl NoCursor
    ldy OamPtr
    lda #SHOOT_CURSOR_TILE_ID | OAM_PRIORITY_2
    sta OAM_TILE,y
    lda PlayerCursorPX,x
    lsr
    lsr
    lsr
    lsr
    sub #6
    sta 0
    lda PlayerCursorPY,x
    lsr
    lsr
    lsr
    lsr
    add #-8+GAMEPLAY_SPRITE_Y_OFFSET+2
    sta 2
    seta8
    lda 0
    sta OAM_XPOS,y
    lda 2
    sta OAM_YPOS,y

    lsr 1
    lda #1
    rol
    sta OAMHI+1,y
    seta16_clc
    tya
    adc #4
    sta OamPtr
  NoCursor:

  ; -------------------------------------------------------

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

  lda PlayerMoveAngle,x
  add #32
  lsr
  lsr
  lsr
  lsr
  lsr
  and #%1110
  tay
  lda PlayerAngleTiles,y
  sta PlayerTile
  lda PlayerEdgeTiles,y
  sta EdgeTile
  lda PlayerEdgeOffsets,y
  add BaseX
  sta EdgeX

  ; -------------------------------------------------------
  ; Calculate cannon positions
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

  ; -------------------------------------------------------

  ldy OamPtr
  lda PlayerTile
  sta OAM_TILE+(4*0),y ; 16-bit, combined with attribute
  lda CannonTile
  sta OAM_TILE+(4*1),y ; Cannon

  ; Calculate sprite X positions in 16-bit mode
  lda BaseX
  add #4
  add CannonOffX
  sta CannonX

  seta8
  lda BaseX
  sta OAM_XPOS+(4*0),y
  lda CannonX
  sta OAM_XPOS+(4*1),y ; Cannon
  lda EdgeX
  sta OAM_XPOS+(4*2),y ; Edge

  lda BaseY
  sta OAM_YPOS+(4*0),y ; Player
  sta OAM_YPOS+(4*2),y ; Edge
  lda BaseY
  add #4
  add CannonOffY
  sta OAM_YPOS+(4*1),y ; Cannon

  ; Hide edge sprite if it isn't needed
  lda EdgeTile+1
  sta OAM_TILE+(4*2)+1,y ; Edge
  lda EdgeTile
  sta OAM_TILE+(4*2),y ; Edge
  bne :+
    lda #$f0
    sta OAM_YPOS+(4*2),y
  :

  ; High OAM bits
  lda BaseX+1
  lsr
  lda #1 ; 16x16 - and leave BaseX unchanged for the "no ammo" message
  rol
  sta OAMHI+1+(4*0),y
  tdc
  lsr CannonX+1
  rol
  sta OAMHI+1+(4*1),y ; Cannon
  tdc
  lsr EdgeX+1
  rol
  sta OAMHI+1+(4*2),y ; Edge
  seta16_clc

  tya
  adc #3*4 ; Carry cleared above
  sta OamPtr

  ; ---------------------------------------------
  ; Show "No ammo" message if needed
  NoAmmoX1 = CannonOffX
  NoAmmoX2 = CannonOffY
  lda PlayerNoAmmoMessage,x
  beq DontShowNoAmmoMessage
  dec PlayerNoAmmoMessage,x
  ldy OamPtr
  lda #(4*16 + 13) | OAM_PRIORITY_2
  sta OAM_TILE+(4*0),y
  ina
  sta OAM_TILE+(4*1),y

  lda BaseX
  sub #4
  sta NoAmmoX1
  add #8
  sta NoAmmoX2
  seta8
  lda BaseY
  sub #16
  sta OAM_YPOS+(4*0),y
  sta OAM_YPOS+(4*1),y
  lda NoAmmoX1
  sta OAM_XPOS+(4*0),y
  lda NoAmmoX2
  sta OAM_XPOS+(4*1),y

  ; High OAM
  lda #1
  lsr NoAmmoX1+1
  rol
  sta OAMHI+1+(4*0),y
  lda #1
  lsr NoAmmoX2+1
  rol
  sta OAMHI+1+(4*1),y
  seta16_clc

  tya
  adc #2*4
  sta OamPtr
DontShowNoAmmoMessage:
  rtl

PlayerAngleTiles:
  .word 4 | OAM_PRIORITY_2
  .word 2 | OAM_PRIORITY_2
  .word 0 | OAM_PRIORITY_2
  .word 2 | OAM_PRIORITY_2 | OAM_XFLIP
  .word 4 | OAM_PRIORITY_2 | OAM_XFLIP
  .word 6 | OAM_PRIORITY_2 | OAM_XFLIP
  .word 8 | OAM_PRIORITY_2
  .word 6 | OAM_PRIORITY_2
PlayerEdgeTiles:
  .word $1A | OAM_PRIORITY_2
  .word 0
  .word 0
  .word 0
  .word $1A | OAM_PRIORITY_2 | OAM_XFLIP
  .word $0A | OAM_PRIORITY_2 | OAM_XFLIP
  .word 0
  .word $0A | OAM_PRIORITY_2
PlayerEdgeOffsets:
  .word .loword(-8), 0, 0, 0, 16, 16, 0, .loword(-8)
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
