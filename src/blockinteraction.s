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

.export BlockBricks
.export BlockSpikes

; Export the interaction runners
.export BlockRunInteractionAbove, BlockRunInteractionBelow
.export BlockRunInteractionSide, BlockRunInteractionInsideHead
.export BlockRunInteractionInsideBody, BlockRunInteractionActorInside
.export BlockRunInteractionActorTopBottom, BlockRunInteractionActorSide

; .-------------------------------------
; | Runners for interactions
; '-------------------------------------

.a16
.i16
.import BlockInteractionAbove
.proc BlockRunInteractionAbove
  and #255 ; Get the interaction set only
  beq Skip

  phb
  phk ; Data bank = program bank
  plb
  asl
  tax
  jsr (.loword(BlockInteractionAbove),x)
  plb
Skip:
  rtl
.endproc

.a16
.i16
.import BlockInteractionBelow
.proc BlockRunInteractionBelow
  and #255 ; Get the interaction set only
  beq Skip

  phb
  phk ; Data bank = program bank
  plb
  asl
  tax
  jsr (.loword(BlockInteractionBelow),x)
  plb
Skip:
  rtl
.endproc

.a16
.i16
.import BlockInteractionSide
.proc BlockRunInteractionSide
  and #255 ; Get the interaction set only
  beq Skip

  phb
  phk ; Data bank = program bank
  plb
  asl
  tax
  jsr (.loword(BlockInteractionSide),x)
  plb
Skip:
  rtl
.endproc


.a16
.i16
.import BlockInteractionInsideHead
.proc BlockRunInteractionInsideHead
  and #255 ; Get the interaction set only
  beq Skip

  phb
  phk ; Data bank = program bank
  plb
  asl
  tax
  jsr (.loword(BlockInteractionInsideHead),x)
  plb
Skip:
  rtl
.endproc

.a16
.i16
.import BlockInteractionInsideBody
.proc BlockRunInteractionInsideBody
  and #255 ; Get the interaction set only
  beq Skip

  phb
  phk ; Data bank = program bank
  plb
  asl
  tax
  jsr (.loword(BlockInteractionInsideBody),x)
  plb
Skip:
  rtl
.endproc

.a16
.i16
.import BlockInteractionActorInside
.proc BlockRunInteractionActorInside
  and #255 ; Get the interaction set only
  beq Skip

  phb
  phk ; Data bank = program bank
  plb
  asl
  tax
  jsr (.loword(BlockInteractionActorInside),x)
  plb
Skip:
  rtl
.endproc

; Pass in a block flag word and it will run the interaction
.a16
.i16
.import BlockInteractionActorTopBottom
.proc BlockRunInteractionActorTopBottom
  and #255 ; Get the interaction set only
  beq Skip

  phb
  phk ; Data bank = program bank
  plb
  asl
  tay
  lda BlockInteractionActorTopBottom,y
  jsr Call
  plb
Skip:
  rtl

Call: ; Could use the RTS trick here instead
  sta TempVal
  jmp (TempVal)
.endproc

; Pass in a block flag word and it will run the interaction
.a16
.i16
.import BlockInteractionActorSide
.proc BlockRunInteractionActorSide
  and #255 ; Get the interaction set only
  beq Skip

  phb
  phk ; Data bank = program bank
  plb
  asl
  tay
  lda BlockInteractionActorSide,y
  jsr BlockRunInteractionActorTopBottom::Call
  plb
Skip:
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

.proc BlockBricks
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
    lda DelayedBlockEditAddr,x
    cmp LevelBlockPtr
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

