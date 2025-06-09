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

; This file covers code to handle interacting with level blocks
; in different ways. These interactions are listed in blocks.txt

.include "snes.inc"
.include "global.inc"
.include "blockenum.s"
.include "actorenum.s"
.include "audio_enum.inc"
.include "tad-audio.inc"
.smart

.segment "C_BlockInteraction"

.export BlockBreakableShot
.export BlockSpikes
.export BlockGetAmmo, BlockGetHealth, BlockGetSpeed, BlockGetDamage

; Export the interaction runners
.export BlockRunInteractionBump, BlockRunInteractionInside, BlockRunInteractionActorInside
.export BlockRunInteractionShot, BlockRunInteractionActorBump

; .-------------------------------------
; | Runners for interactions
; '-------------------------------------

CallA:
  sta TempVal
  jmp (TempVal)

.a16
.i16
.import BlockInteractionBump
.proc BlockRunInteractionBump
  phb
  phx
  tax
  lda f:BlockFlags,x
  and #255 ; Get the interaction set only
  beq Skip

  phk ; Data bank = program bank
  plb
  asl
  tax
  lda BlockInteractionBump,x
  plx
  jsr CallA
  plb
  rtl

Skip:
  plx
  plb
  rtl
.endproc

.a16
.i16
.import BlockInteractionShot
.proc BlockRunInteractionShot
  phb
  phx
  tax
  lda f:BlockFlags,x
  and #255 ; Get the interaction set only
  beq Skip

  phk ; Data bank = program bank
  plb
  asl
  tax
  lda BlockInteractionShot,x
  plx
  jsr CallA
  plb
  rtl

Skip:
  plx
  plb
  rtl
.endproc

.a16
.i16
.import BlockInteractionInside
.proc BlockRunInteractionInside
  phb
  phx
  tax
  lda f:BlockFlags,x
  and #255 ; Get the interaction set only
  beq Skip

  phk ; Data bank = program bank
  plb
  asl
  tax
  lda BlockInteractionInside,x
  plx
  jsr CallA
  plb
  rtl

Skip:
  plx
  plb
  rtl
.endproc

.a16
.i16
.import BlockInteractionActorInside
.proc BlockRunInteractionActorInside
  phb
  phx
  tax
  lda f:BlockFlags,x
  and #255 ; Get the interaction set only
  beq Skip

  phk ; Data bank = program bank
  plb
  asl
  tax
  lda BlockInteractionActorInside,x
  plx
  jsr CallA
  plb
  rtl

Skip:
  plx
  plb
  rtl
.endproc

.a16
.i16
.import BlockInteractionActorBump
.proc BlockRunInteractionActorBump
  phb
  phx
  tax
  lda f:BlockFlags,x
  and #255 ; Get the interaction set only
  beq Skip

  phk ; Data bank = program bank
  plb
  asl
  tax
  lda BlockInteractionActorBump,x
  plx
  jsr CallA
  plb
  rtl

Skip:
  plx
  plb
  rtl
.endproc

; -------------------------------------

.proc BlockHeart
  seta8
  lda PlayerHealth
  cmp #4
  bcs Full
    ; Play the sound effect
    lda #SFX::collect_item
    jsl PlaySoundEffect

    lda #4
    sta PlayerHealth
    seta16
    lda #Block::Empty
    jsl ChangeBlock
  Full:
  seta16
  rts
.endproc

.proc BlockSmallHeart
  seta8
  ; Play the sound effect
  lda #SFX::collect_item
  jsl PlaySoundEffect

  lda PlayerHealth
  cmp #4
  bcs Full
    inc PlayerHealth
    seta16
    lda #Block::Empty
    jsl ChangeBlock
  Full:
  seta16
  rts
.endproc

.a16
.proc PoofAtBlock
  ; Need a free slot first
  jsl FindFreeParticleY
  bcs :+
    rts
  :
  lda #Particle::Poof
  sta ParticleType,y

  ; Position it where the block is
  jsl GetBlockXCoord
;  ora #$80 <-- was $80 for BlockPushForwardCleanup - why?
  ora #$40 ; <-- Cancels out offset in object.s ParticleDrawPosition - maybe just not have the offset?
  sta ParticlePX,y

  ; For a 16x16 particle
  jsl GetBlockYCoord
  ora #$40
  sta ParticlePY,y
  rts
.endproc

.proc BlockBreakableShot
  seta8
  ; Play the sound effect
  lda #SFX::brick_break
  jsl PlaySoundEffect
  seta16

  lda #Block::Empty
  jsl ChangeBlock
  jsr PoofAtBlock
  rts
.endproc

.proc BlockSpikes
  .import HurtPlayer
  jsl HurtPlayer
  rts
.endproc

.a16
.proc BlockGetAmmo
  lda #60*10
  sta BlockTemp ; Timer
  lda #Block::AmmoPickup
  jsl DelayChangeBlock

  lda #Block::Empty
  jsl ChangeBlock

  lda PlayerAmmo,x
  add #5
  cmp #99
  bcc :+
    lda #99
  :
  sta PlayerAmmo,x
  .import UpdatePlayerAmmoTiles
  jsl UpdatePlayerAmmoTiles
  rts
.endproc

.a16
.proc BlockGetHealth
  lda #Block::Empty
  jsl ChangeBlock
  rts
.endproc

.a16
.proc BlockGetSpeed
  lda #Block::Empty
  jsl ChangeBlock
  rts
.endproc

.a16
.proc BlockGetDamage
  lda #Block::Empty
  jsl ChangeBlock
  rts
.endproc

.a16
.proc ParticleAtBlock
  jsl GetBlockXCoord
  ora #$80
  sta ParticlePX,y

  jsl GetBlockYCoord
  ora #$80
  sta ParticlePY,y
  rts
.endproc

.proc FindDelayedEditForBlock
  ldx #(MaxDelayedBlockEdits-1)*2
DelayedBlockLoop:
  ; Only delayed blocks with nonzero timers are valid slots
  lda DelayedBlockEditTime,x
  beq :+
    ; Is it this block?
    tya
    cmp DelayedBlockEditAddr,x
    beq Yes
: dex
  dex
  bpl DelayedBlockLoop
  clc
  rts
Yes:
  sec
  rts
.endproc

