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
.include "actorenum.s"
.include "audio_enum.inc"
.include "tad-audio.inc"
.smart

.import BlockRunInteractionAbove, BlockRunInteractionBelow
.import BlockRunInteractionSide,  BlockRunInteractionInsideHead
.import BlockRunInteractionInsideBody
.import InitActorX, InitActorY

.import CalculateActorVelocityFromAngleAndSpeed, ActorApplyVelocity, ActorApplyXVelocity, ActorApplyYVelocity, DivideActorVelocityBy8, DivideActorVelocityBy16

.segment "ZEROPAGE"

.segment "C_Player"

.a16
.i16
.proc RunPlayer
  phk
  plb

  ; -------------------------------------------------------
  ; Change shoot direction when you press a direction

TargetAngle = 0
AbsDifference = 2
  ; Calculate target angle
  lsr PlayerShootAngle,x
  seta8
  tdc ; Clear accumulator, for the TAY
  lda keydown+1
  and #>(KEY_LEFT|KEY_RIGHT|KEY_UP|KEY_DOWN)
  beq NoTarget
    tay
    seta16 ; Switch to 16-bit to make the math easier
    lda TargetAngleTable,y
    and #255
    cmp #255
    beq NoTarget
    sta TargetAngle

    ; Implement the retargeting here
    lda PlayerShootAngle,x
    sub TargetAngle
    abs
    sta AbsDifference

    ; If the difference is small enough, just snap
    cmp #4
    bcs :+
      lda TargetAngle
      sta PlayerShootAngle,x
      bra NoTarget
    :

    cmp #128
    bcs :+
      lda PlayerShootAngle,x
      cmp TargetAngle
      bcc :+
        lda PlayerShootAngle,x
        sub #4
        sta PlayerShootAngle,x
        bra NoTarget
    :

    lda AbsDifference
    cmp #128
    bne :+
      lda PlayerShootAngle,x
      eor #128
      sta PlayerShootAngle,x
      bra NoTarget
    :
    bcc :+
      lda PlayerShootAngle,x
      cmp TargetAngle
      bcs :+
        lda PlayerShootAngle,x
        sub #4
        sta PlayerShootAngle,x
        bra NoTarget
    :

    lda PlayerShootAngle,x
    add #3
    sta PlayerShootAngle,x
NoTarget:
  seta16

  lda PlayerShootAngle,x
  and #255
  asl
  sta PlayerShootAngle,x

  ; -------------------------------------------------------
  ; Boosting

  lda keydown
  and #KEY_B
  beq :+
    lda PlayerBoostTimer,x
    bne :+
      lda PlayerShootAngle,x
      sta PlayerMoveAngle,x
      lda #5
      sta PlayerSpeed,x
      asl
      sta PlayerBoostTimer,x
  :
  lda PlayerBoostTimer,x
  bne :+
    lda PlayerSpeed,x
    cmp #3
    bcs @SlowDown
    bra NoBoostSlowDown
  :
    dec PlayerBoostTimer,x
    bne NoBoostSlowDown
@SlowDown:
      dec PlayerSpeed,x
      lda PlayerSpeed,x
      cmp #2
      beq NoBoostSlowDown
        lda #10
        sta PlayerBoostTimer,x
  NoBoostSlowDown:

  ; -------------------------------------------------------
  ; Shooting

  lda keynew
  and #KEY_Y
  beq NoShoot
    jsl FindFreeProjectileY
    bcc NoShoot
      lda #Actor::PlayerProjectile*2
      sta ActorType,y
      jsl InitActorY

      lda #0
      sta ActorProjectileType,y
      sta ActorTimer,y

      lda PlayerShootAngle,x
      sta ActorAngle,y
      lda #1
      sta ActorSpeed,y

      phx
      phy
      tyx
      jsl CalculateActorVelocityFromAngleAndSpeed
      .import DivideActorVelocityBy2
      jsl DivideActorVelocityBy2
      ply
      plx
      lda ActorVX,y
      asl
      asl
      asl
      add PlayerPX,x
      sta ActorPX,y

      lda ActorVY,y
      asl
      asl
      asl
      add PlayerPY,x
      sta ActorPY,y
  NoShoot:

  jsl CalculateActorVelocityFromAngleAndSpeed
  jsl DivideActorVelocityBy16
HITBOX_SIZE = 6

  ; -------------------------------------------------------
  ; Bounce off of the left and right of the playfield
  lda PlayerVX,x
  bpl NotOffLeft
  lda PlayerPX,x
  cmp #$0080
  bcs NotOffLeft
  FlipFromScreenEdgeLR:
    lda #256
    sub PlayerMoveAngle,x
    and #510
    sta PlayerMoveAngle,x
    bra NoHorizontalMovement
  NotOffLeft:

  lda PlayerVX,x
  bmi NotOffRight
  lda PlayerPX,x
  cmp #$0F80
  bcs FlipFromScreenEdgeLR
  NotOffRight:

  ; -------------------------------------------------------
  ; Bounce horizontally off of solid blocks
  lda PlayerVX,x
  beq NoHorizontalMovement
  lda #HITBOX_SIZE*16
  sta 0
  lda PlayerVX,x
  bpl :+
    lda #.loword(-HITBOX_SIZE*16)
    sta 0
  :
  lda PlayerPY,x
  sub #HITBOX_SIZE/2*16
  tay
  lda PlayerPX,x
  add 0
  pha
  phy
  jsr TrySideInteraction
  bcc :+
    pla
    pla
    bra NoHorizontalMovement
  :
  pla
  add #HITBOX_SIZE*16
  tay
  pla
  jsr TrySideInteraction
NoHorizontalMovement:

  ; -------------------------------------------------------
  ; Bounce off of the top and bottom of playfield
  lda PlayerVY,x
  bpl NotOffTop
  lda PlayerPY,x
  cmp #$0080
  bcs NotOffTop
  FlipFromScreenEdgeUD:
    lda PlayerMoveAngle,x
    eor #$ffff
    ina
    and #510
    sta PlayerMoveAngle,x
    bra NoVerticalMovement
  NotOffTop:

  lda PlayerVY,x
  bmi NotOffBottom
  lda PlayerPY,x
  cmp #$0B80
  bcs FlipFromScreenEdgeUD
  NotOffBottom:

  ; -------------------------------------------------------
  ; Bounce vertically off of solid blocks
  lda PlayerVY,x
  beq NoVerticalMovement
  lda #HITBOX_SIZE*16
  sta 0
  lda PlayerVY,x
  bpl :+
    lda #.loword(-HITBOX_SIZE*16)
    sta 0
  :
  lda PlayerPY,x
  add 0
  tay
  lda PlayerPX,x
  sub #HITBOX_SIZE/2*16
  phy
  pha
  jsr TryVertInteraction
  bcc :+
    pla
    pla
    bra NoVerticalMovement
  :
  pla
  add #HITBOX_SIZE*16
  ply
  bcs NoVerticalMovement
  jsr TryVertInteraction
NoVerticalMovement:

  ; -------------------------------------------------------
  jsl ActorApplyVelocity
  rtl

TrySideInteraction:
  jsl GetLevelIndexXY
  beq NoBumpHoriz
    lda #256
    sub PlayerMoveAngle,x
    and #510
    sta PlayerMoveAngle,x
    sec
    rts
  NoBumpHoriz:
  clc
  rts

TryVertInteraction:
  jsl GetLevelIndexXY
  beq NoBumpVert
    lda PlayerMoveAngle,x
    eor #$ffff
    ina
    and #510
    sta PlayerMoveAngle,x
    sec
    rts
  NoBumpVert:
  clc
  rts

TargetAngleTable:
  .byt 255 ; udlr
  .byt 0   ; udlR East
  .byt 128 ; udLr West
  .byt 255 ; udLR
  .byt 64  ; uDlr South
  .byt 32  ; uDlR Southeast
  .byt 96  ; uDLr Southwest
  .byt 255 ; uDLR
  .byt 192 ; Udlr North
  .byt 224 ; UdlR Northeast
  .byt 160 ; UdLr Northwest
  .byt 255 ; UdLR
  .byt 255 ; UDlr
  .byt 255 ; UDlR
  .byt 255 ; UDLr
  .byt 255 ; UDLR
.endproc

; Damages the player
.export HurtPlayer
.proc HurtPlayer
  php
  seta8
  lda PlayerHealth
  beq :+
  lda PlayerInvincible
  bne :+
    dec PlayerHealth
    lda #160
    sta PlayerInvincible

    ; Play the sound effect
    lda #SFX::player_hurt
    jsl PlaySoundEffect
  :
  plp
  rtl
.endproc

.a16
.i16
.export FindFreeProjectileY
.proc FindFreeProjectileY
  phx
  lda #ProjectileStart
  clc
Loop:
  tay
  ldx ActorType,y ; Don't care what gets loaded into Y, but it will set flags
  beq Found
  adc #ActorStructSize
  cmp #ProjectileEnd ; Carry should always be clear at this point
  bcc Loop
NotFound:
  plx
  clc
  rtl
Found:
  plx
  sec
  rtl
.endproc
