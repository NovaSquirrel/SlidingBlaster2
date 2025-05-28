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
.import InitActorX

.segment "ZEROPAGE"

.segment "C_Player"

.a16
.i16
.proc RunPlayer
  phk
  plb
  ; TODO
  rtl
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
.export FindFreeProjectileX
.proc FindFreeProjectileX
  phy
  lda #ProjectileStart
  clc
Loop:
  tax
  ldy ActorType,x ; Don't care what gets loaded into Y, but it will set flags
  beq Found
  adc #ActorSize
  cmp #ProjectileEnd ; Carry should always be clear at this point
  bcc Loop
NotFound:
  ply
  clc
  rtl
Found:
  ply
  sec
  rtl
.endproc
