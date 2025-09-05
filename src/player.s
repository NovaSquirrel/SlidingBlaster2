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

.import BlockRunInteractionBump
.import BlockRunInteractionInside
.import InitActorX, InitActorY, GetAngle512, ActorClearY

.import CalculateActorVelocityFromAngleAndSpeed, ActorApplyVelocity, ActorApplyXVelocity, ActorApplyYVelocity, DivideActorVelocityBy8, DivideActorVelocityBy16, ActorMoveAndBumpAgainstWalls

.segment "ZEROPAGE"

.segment "C_Player"

.a16
.i16
.proc RunPlayer
PlayerNumber = TouchTemp
  phk
  plb

  tdc
  cpy #.loword(Player2)
  rol
  sta PlayerNumber

  ; -------------------------------------------------------
  ; Change shoot direction when you press a direction
  bit8 PlayerUsingAMouse,x
  jmi MouseMode

TargetAngle = 0
AbsDifference = 2
  ; Calculate target angle
  lsr PlayerShootAngle,x
  seta8
  tdc ; Clear accumulator, for the TAY
  lda PlayerKeyDown+1,x
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
    add #4
    sta PlayerShootAngle,x
NoTarget:
  seta16

  lda PlayerShootAngle,x
  and #255
  asl
  sta PlayerShootAngle,x
  jmp ControlMethodEnd

MouseMode:
  seta8
  lda #0 << 4
  sta PlayerMouseSensitivity,x
  seta16

  ldy PlayerNumber
  jsl ReadMouseForPlayerY

  ; Convert to two's complement
  lda 0
  and #255
  bit #128
  beq :+
    eor #$FF7F
    sec
    adc #0
  :
  asl
  asl
  add PlayerCursorPY,x
  sta PlayerCursorPY,x
  adc #$8000         ; Apply an offset so that I don't need a separate check for being too close to the left edge and going past it
  cmp #$8000 + $080
  bcs :+
    lda #$0040
    sta PlayerCursorPY,x
  :
  cmp #$8000 + $D80
  bcc :+
    lda #$0C80
    sta PlayerCursorPY,x
  :

  lda 1
  and #255
  bit #128
  beq :+
    eor #$FF7F
    sec
    adc #0
  :
  asl
  asl
  add PlayerCursorPX,x
  sta PlayerCursorPX,x
  adc #$8000
  cmp #$8000 + $080
  bcs :+
    lda #$0040
    sta PlayerCursorPX,x
  :
  cmp #$8000 + $F80
  bcc :+
    lda #$0FC0
    sta PlayerCursorPX,x
  :

  ; Point cannon at cursor
  lda PlayerCursorPX,x
  sub PlayerPX,x
  sta 0
  lda PlayerCursorPY,x
  sub PlayerPY,x
  sta 2
  jsl GetAngle512
  and #$1FE
  sta PlayerShootAngle,x
ControlMethodEnd:

  ; -------------------------------------------------------
  ; Boosting

  lda PlayerSpeedupTimer,x
  beq :+
    dec PlayerSpeedupTimer,x
  :

  lda PlayerKeyDown,x
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

      lda PlayerSpeedupTimer,x
      beq @NoSpeedup
         lda #7
         sta PlayerSpeed,x
         lsr PlayerBoostTimer,x
      @NoSpeedup:
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
        lda PlayerSpeedupTimer,x
        bne NoBoostSlowDown
        lda #10
        sta PlayerBoostTimer,x
  NoBoostSlowDown:

  ; -------------------------------------------------------
  ; Shooting

  ; Give the player 1 ammo after 4 seconds of having none as a little bit of help
  lda PlayerAmmo,x
  bne :+
    inc PlayerNoAmmoPity,x
    lda PlayerNoAmmoPity,x
    cmp #240
    bcc DontResetNoAmmoPity
    inc PlayerAmmo,x
    jsl UpdatePlayerAmmoTiles
  :
  stz PlayerNoAmmoPity,x
  DontResetNoAmmoPity:

  lda PlayerKeyNew,x
  and #KEY_Y
  beq NoShoot
    lda PlayerAmmo,x
    bne HaveAmmo
      lda #60
      sta PlayerNoAmmoMessage,x
      bra NoShoot
    HaveAmmo:
    stz PlayerNoAmmoMessage,x
    dec PlayerAmmo,x
    .import UpdatePlayerAmmoTiles
    jsl UpdatePlayerAmmoTiles

    ; Play the sound effect
    lda #SFX::fire_arrow
    jsl PlaySoundEffect

    jsl FindFreeProjectileY
    bcc NoShoot
      jsl ActorClearY
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
  jsl ActorMoveAndBumpAgainstWalls

  ; Try running interaction with the thing you're on top of
  lda ActorPX,x
  ldy ActorPY,x
  jsl GetLevelIndexXY
  jsl BlockRunInteractionInside

  lda PlayerHurtTimer,x
  beq :+
    dec PlayerHurtTimer,x
  :

  rtl

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
  pha
  php
  lda PlayerHealth,x
  beq NoHealth
	; 1,s = flags
	; 2,s = saved damage
	sub 2,s
	bcs :+
		tdc
	:
	sta PlayerHealth,x

    ; Play the sound effect
    lda #SFX::player_hurt
    jsl PlaySoundEffect

	.import UpdatePlayerHealthTiles
	jsl UpdatePlayerHealthTiles
  NoHealth:
  plp
  pla
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

; Y = 0 or 1 for first or second player
; X = pointer to player struct
.proc ReadMouseForPlayerY
  php
  seta8

  ; Copy the left and right mouse buttons to where the Y and B buttons would go
  lda PlayerKeyDown,x
  and #$80 | $40
  sta PlayerKeyDown+1,x
  lda PlayerKeyNew,x
  and #$80 | $40
  sta PlayerKeyNew+1,x

  ; If it's a Hyperkin mouse, add a bunch of delays
  lda PlayerUsingAMouse,x
  lsr
  bcs HyperkinMouse

  lda #1
  sta 0
: lda $4016,y
  lsr
  rol 0
  bcc :-

  lda #1
  sta 1
: lda $4016,y
  lsr
  rol 1
  bcc :-

WasHyperkinMouse:
  ; Hyperkin mouse doesn't let game change the sensitivity
  ; but trying anyway should be good in the case where the Hyperkin mouse gets detected by mistake?
  lda #%100000
  sta PlayerMouseSensitivity,x

  ; If the sensitivity reported isn't the right one, cycle to the next sensitivity
  lda PlayerKeyDown,x
  and #%110000
  cmp PlayerMouseSensitivity,x
  beq :+
    lda #1
    sta $4016
    lda $4016,y
    stz $4016
  :
  plp
  rtl

; -----------------------------------------------------
; The microcontroller in the Hyperkin mouse is slooooow
HyperkinMouse:
  lda #1
  sta 0
: lda $4016,y
  lsr         ; 12
  rol 0       ; 34
  jsr Delay
  bcc :-

  lda #1
  sta 1
: lda $4016,y
  lsr
  rol 1
  jsr Delay
  bcc :-
  bra WasHyperkinMouse

Delay:
  ; Will add 80 cycles by itself due to the JSR and RTS
  ; So 170-(46+80) = 44, which would be covered by four NOPs
  nop
  nop
  nop
  nop
  nop ; Extra nop for safety
  rts
.endproc
