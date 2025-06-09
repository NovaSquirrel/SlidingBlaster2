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

; This file mostly contains generic routines for actors to build their behaviors out of

.include "snes.inc"
.include "global.inc"
.include "blockenum.s"
.import ActorRun, ActorDraw, ActorAfterRun, ActorFlags, ActorWidthTable, ActorHeightTable, ActorBank, ActorGraphic, ActorPalette
.import ActorGetShot
.smart

.segment "C_ActorCommon"

.export RunAllActors
.proc RunAllActors
  setaxy16

  ldx #ActorStart
  stx LastNonEmpty
ActorLoop:
  ; Don't do anything if it's an empty slot
  lda ActorType,x
  beq @SkipEntity
    stx LastNonEmpty
    jsr ProcessOneActor
@SkipEntity:
  ; Next actor
  txa
  add #ActorStructSize
  tax
  cpx ActorIterationLimit
  bcc ActorLoop

  ; Decrease the limit if needed
  ; Data bank should point somewhere in banks $80-$BF so LastNonEmpty
  lda LastNonEmpty
  adc #ActorStructSize-1 ; Carry set here
  sta ActorIterationLimit

  ;------------------------------------

  ldx #ProjectileStart
ProjectileLoop:
  ; Don't do anything if it's an empty slot
  lda ActorType,x
  beq @SkipEntity
    jsr ProcessOneActor
@SkipEntity:
  ; Next actor
  txa
  add #ActorStructSize
  tax
  cpx #ProjectileEnd
  bcc ProjectileLoop

  ;------------------------------------

  jml RunAllParticles

; Call the Run and Draw routines on an actor
ProcessOneActor:
  ; Call the run and draw routines
  lda ActorType,x
  jsl CallRun
  lda ActorType,x
  jsl CallDraw
  rts

; Call the Actor run code
.a16
CallRun:
  phx
  tax
  seta8
  lda f:ActorBank+0,x
  pha
  plb ; Use code bank as data bank
  sta 2
  seta16
  lda f:ActorRun,x
  sta 0
  plx ; X now equals the Actor index base again

  ; Jump to it and return with an RTL
  jml [0]

; Call the Actor draw code
.a16
CallDraw:
  phx
  tax
  seta8
  lda f:ActorBank+1,x
  pha
  plb ; Use code bank as data bank
  sta 2
  seta16
  lda f:ActorDraw,x
  sta 0
  plx ; X now equals the Actor index base again

  ; Jump to the per-Actor routine and return with an RTL
  jml [0]
.endproc

.export SharedEnemyCommon
.a16
.i16
SharedEnemyCommon:
  jsl PlayerActorCollisionHurt
  jsl ActorGetShot
  rtl

.pushseg
.segment "C_ParticleCode"
.a16
.i16
.import ParticleRun, ParticleDraw
assert_same_banks RunAllParticles, ParticleRun
assert_same_banks RunAllParticles, ParticleDraw
.proc RunAllParticles
  phk
  plb

  ldx #ParticleStart
Loop:
  lda ParticleType,x
  beq SkipEntity   ; Skip if empty

  ; Call the run and draw routines
  asl
  pha
  pea :+ -1
    tay
    lda ParticleRun,y
    pha
    rts
  :
  pla
  pea :+ -1
    tay
    lda ParticleDraw,y
    pha
    rts
  :
SkipEntity:
  ; Next particle
  txa
  add #ParticleStructSize
  tax
  cpx ParticleIterationLimit
  bcc Loop

  ; Decrease the limit if needed
  lda LastNonEmpty
  adc #ParticleStructSize-1 ; Carry set here
  sta ParticleIterationLimit
  rtl
.endproc
.popseg


.a16
.i16
.proc FindFreeActorX
  phy
  lda #ActorStart
  clc
Loop:
  tax
  ldy ActorType,x ; Don't care what gets loaded into Y, but it will set flags
  beq Found
  adc #ActorStructSize
  cmp #ActorEnd   ; Carry should always be clear at this point
  bcc Loop
NotFound:
  ply
  clc
  rtl
Found:
  ply
  ; Increase the portion of the actor list that should be iterated
  adc #ActorStructSize ; Should still be carry clear here since it was clear in loop
  cmp ActorIterationLimit
  bcc :+
    sta ActorIterationLimit
  :
  seta16
  sec
  rtl
.endproc

.a16
.i16
.proc FindFreeActorY
  phx
  lda #ActorStart
  clc
Loop:
  tay
  ldx ActorType,y ; Don't care what gets loaded into X, but it will set flags
  beq Found
  adc #ActorStructSize  ; Carry should always be clear at this point
  cmp #ActorEnd
  bcc Loop
NotFound:
  plx
  clc
  rtl
Found:
  plx
  ; Increase the portion of the actor list that should be iterated
  adc #ActorStructSize ; Should still be carry clear here since it was clear in loop
  cmp ActorIterationLimit
  bcc :+
    sta ActorIterationLimit
  :
  seta16
  sec
  rtl
.endproc


.a16
.i16
.proc FindFreeParticleY
  phx
  lda #ParticleStart
  clc
Loop:
  tay
  ldx ParticleType,y ; Don't care what gets loaded into X, but it will set flags
  beq Found
  adc #ParticleStructSize  ; Carry should always be clear at this point
  cmp #ParticleEnd
  bcc Loop
NotFound:
  plx
  clc
  rtl
Found:
  plx

  ; Increase the portion of the particle list that should be iterated
  adc #ParticleStructSize ; Should still be carry clear here since it was clear in loop
  cmp ParticleIterationLimit
  bcc :+
    sta ParticleIterationLimit
  :
  lda #0
  sta ParticleTimer,y
  sta ParticleVX,y
  sta ParticleVY,y
  sec
  rtl
.endproc

.export ActorApplyVelocity, ActorApplyXVelocity, ActorApplyYVelocity
.proc ActorApplyVelocity
  lda ActorPXSub,x
  add ActorVXSub,x
  sta ActorPXSub,x
  lda ActorPX+1,x
  adc ActorVX+1,x
  sta ActorPX+1,x
::ActorApplyYVelocity:
  lda ActorPYSub,x
  add ActorVYSub,x
  sta ActorPYSub,x
  lda ActorPY+1,x
  adc ActorVY+1,x
  sta ActorPY+1,x
  rtl
.endproc

.proc ActorApplyXVelocity
  lda ActorPXSub,x
  add ActorVXSub,x
  sta ActorPXSub,x
  lda ActorPX+1,x
  adc ActorVX+1,x
  sta ActorPX+1,x
  rtl
.endproc

; Look up the block at a coordinate and run the interaction routine it has, if applicable
; A = X coordinate, Y = Y coordinate
.export ActorTryUpInteraction
.import BlockRunInteractionActorTopBottom
.proc ActorTryUpInteraction
  jsl GetLevelIndexXY
  phx
  tax
  lda f:BlockFlags,x
  sta BlockFlag
  plx
  jsl BlockRunInteractionActorTopBottom
  lda BlockFlag
  rtl
.endproc

; Look up the block at a coordinate and run the interaction routine it has, if applicable
; A = X coordinate, Y = Y coordinate
.export ActorTryDownInteraction
.proc ActorTryDownInteraction
  jsl GetLevelIndexXY
  phx
  tax
  lda f:BlockFlags,x
  sta BlockFlag
  plx
  jsl BlockRunInteractionActorTopBottom
  lda BlockFlag
  rtl
.endproc

; Look up the block at a coordinate and run the interaction routine it has, if applicable
; A = X coordinate, Y = Y coordinate
.export ActorTrySideInteraction
.import BlockRunInteractionActorSide
.proc ActorTrySideInteraction
  jsl GetLevelIndexXY
  phx
  tax
  lda f:BlockFlags,x
  sta BlockFlag
  plx
  jsl BlockRunInteractionActorSide
  lda BlockFlag
  rtl
.endproc

; Calculate the position of the 16x16 Actor on-screen
; and whether it's visible in the first place
.a16
.proc ActorDrawPosition16x16
  lda ActorPX,x
  lsr
  lsr
  lsr
  lsr
  sub #8
  cmp #.loword(-1*16)
  bcs :+
  cmp #256
  bcs Invalid
: sta 0

  lda ActorPY,x
  lsr
  lsr
  lsr
  lsr
  add #-8+GAMEPLAY_SPRITE_Y_OFFSET
  cmp #.loword(-1*16)
  bcs :+
  cmp #15*16
  bcs Invalid
: sta 2
  sec
  rts
Invalid:
  clc
  rts
.endproc

; Calculate the position of the 8x8 Actor on-screen
; and whether it's visible in the first place
.a16
.proc ActorDrawPosition8x8
  lda ActorPX,x
  lsr
  lsr
  lsr
  lsr
  sub #4
  cmp #.loword(-1*16)
  bcs :+
  cmp #256
  bcs Invalid
: sta 0

  lda ActorPY,x
  lsr
  lsr
  lsr
  lsr
  add #-4+GAMEPLAY_SPRITE_Y_OFFSET
  cmp #.loword(-1*16)
  bcs :+
  cmp #15*16
  bcs Invalid
: sta 2
  sec
  rts
Invalid:
  clc
  rts
.endproc

; Calculate the position of the 8x8 Actor on-screen
; and whether it's visible in the first place
; Uses offsets from SpriteXYOffset
.a16
.proc ActorDrawPositionWithOffset8x8
  lda SpriteXYOffset
  and #255
  bit #128 ; Sign extend
  beq :+
    ora #$ff00
  :
  sta 0
  lda ActorPX,x
  lsr
  lsr
  lsr
  lsr
  add 0
  add #-4+GAMEPLAY_SPRITE_Y_OFFSET
  cmp #.loword(-1*16)
  bcs :+
  cmp #256
  bcs Invalid
: sta 0

  lda SpriteXYOffset+1
  and #255
  bit #128 ; Sign extend
  beq :+
    ora #$ff00
  :
  sta 2
  lda ActorPY,x
  lsr
  lsr
  lsr
  lsr
  adc #0 ; Why do I need to round Y and not X?
  add 2
  sub #9
  cmp #.loword(-1*16)
  bcs :+
  cmp #15*16
  bcs Invalid
: sta 2
  sec
  rts
Invalid:
  clc
  rts
.endproc

; A = tile to draw
.a16
.export DispActor16x16
.proc DispActor16x16
  sta 4 ; Tile number, including the attributes


  jsr ActorDrawPosition16x16
  bcs :+
    rtl
  :  

  ldy OamPtr
  lda 4
  eor ActorFlips,x
  sta OAM_TILE,y ; 16-bit, combined with attribute

  seta8
  lda 0
  sta OAM_XPOS,y
  lda 2
  sta OAM_YPOS,y

  ; Get the high bit of the calculated position and plug it in
  lda 1
  cmp #%00000001
  lda #1 ; 16x16 sprites
  rol
  sta OAMHI+1,y
  seta16_clc

  tya
  adc #4 ; Carry cleared above
  sta OamPtr
  rtl
.endproc

; A = tile to draw
.a16
.export DispActor8x8
.proc DispActor8x8
  sta 4

  stz SpriteXYOffset

  jsr ActorDrawPosition8x8
  bcs :+
    rtl
  :
CustomOffset:
  ldy OamPtr

  lda 4
  eor ActorFlips,x
  sta OAM_TILE,y ; 16-bit, combined with attribute

  seta8
  lda 0
  sta OAM_XPOS,y
  lda 2
  sta OAM_YPOS,y

  ; Get the high bit of the calculated position and plug it in
  lda 1
  cmp #%00000001
  lda #0 ; 8x8 sprites
  rol
  sta OAMHI+1,y
  seta16_clc

  tya
  adc #4 ; CLC above
  sta OamPtr
  rtl
.endproc

; A = tile to draw
; SpriteXYOffset = X,Y offsets
.a16
.proc DispActor8x8WithOffset
  sta 4

  jsr ActorDrawPositionWithOffset8x8
  bcs :+
    rtl
  :
  bra DispActor8x8::CustomOffset
.endproc
.export DispActor8x8WithOffset

.a16
.proc ParticleDrawPosition
  lda ParticlePX,x
  cmp #.loword(-1*256)
  bcs :+
  cmp #16*256
  bcs Invalid
: lsr
  lsr
  lsr
  lsr
  sub #4
  sta 0

  lda ParticlePY,x
  cmp #15*256
  bcs Invalid
  lsr
  lsr
  lsr
  lsr
  add #-4+GAMEPLAY_SPRITE_Y_OFFSET
  sta 2

  sec
  rts
Invalid:
  clc
  rts
.endproc

; For meta sprites
.a16
.proc ActorDrawPositionMeta
  lda ActorPX,x
  lsr
  lsr
  lsr
  lsr
  cmp #.loword(-1*16)
  bcs :+
  cmp #17*16
  bcs ParticleDrawPosition::Invalid
:
  ; No hardcoded offset
  sta 0

  lda ActorPY,x
  lsr
  lsr
  lsr
  lsr
  cmp #.loword(-1*256)
  bcs :+
  cmp #16*16
  bcs ParticleDrawPosition::Invalid
  ; No hardcoded offset
  sta 2

  sec
  rts
.endproc

; A = tile to draw
; Very similar to DispParticle8x8; maybe combine them somehow?
.a16
.export DispParticle16x16
.proc DispParticle16x16
  ldy OamPtr
  sta OAM_TILE,y ; 16-bit, combined with attribute

  jsr ParticleDrawPosition
  bcs :+
    rtl
  :  

  seta8
  lda 0
  sta OAM_XPOS,y
  lda 2
  sta OAM_YPOS,y

  ; Get the high bit of the calculated position and plug it in
  lda 1
  cmp #%00001000
  lda #1 ; 8x8 sprites
  rol
  sta OAMHI+1,y
  seta16

  tya
  add #4
  sta OamPtr
  rtl
.endproc


; A = tile to draw
.a16
.export DispParticle8x8
.proc DispParticle8x8
  ldy OamPtr
  sta OAM_TILE,y ; 16-bit, combined with attribute

  jsr ParticleDrawPosition
  bcs :+
    rtl
  :  

  seta8
  lda 0
  sta OAM_XPOS,y
  lda 2
  sta OAM_YPOS,y

  ; Get the high bit of the calculated position and plug it in
  lda 1
  cmp #%00001000
  lda #0 ; 8x8 sprites
  rol
  sta OAMHI+1,y
  seta16

  tya
  add #4
  sta OamPtr
  rtl
.endproc

; For meta sprites
.a16
.i16
.export DispActorMeta
.proc DispActorMeta
BasePixelX = 0
BasePixelY = 2
Pointer = 4
CurrentX = 6
CurrentY = 8
WidthUnit= 10
Count    = 12
TempTile = 14
  sta Pointer

  lda #8 ; Always go rightwards for now
  sta WidthUnit

  ldy OamPtr

  ; Get the base pixel positions
  jsr ActorDrawPositionMeta
  bcs :+
    rtl
  :

StripStart:
  ; Size bit and count
  lda (Pointer)
  inc Pointer
  and #255
  cmp #255
  beq Exit
  pha ; Save size bit
  and #15
  sta Count

  pla
  and #128
  bne SixteenStripStart

  ; X
  lda (Pointer)
  ; Negate if WidthUnit goes left
  bit WidthUnit
  bpl :+
    neg
  :
  add BasePixelX
  sub #4
  sta CurrentX
  inc Pointer
  inc Pointer

  ; Y
  lda (Pointer)
  add BasePixelY
  add #-4+GAMEPLAY_SPRITE_Y_OFFSET
  sta CurrentY
  inc Pointer
  inc Pointer

.a16
StripLoop:
  ; Now read off a series of tiles
  lda (Pointer)
  and #64
  bne StripSkip

  jsr StripLoopCommon
  .a8
  lda #0
  rol
  sta OAMHI+1,y
  seta16

  ; Next sprite
  iny
  iny
  iny
  iny
StripSkip:
  inc Pointer

  lda CurrentX
  add WidthUnit
  sta CurrentX
  dec Count
  bne StripLoop
  bra StripStart
  
Exit:
  sty OamPtr
  rtl

; -------------------------------------

.a16
SixteenStripStart:
  ; Use 16 pixel units instead
  asl WidthUnit

  ; X
  lda (Pointer)
  ; Negate if WidthUnit goes left
  bit WidthUnit
  bpl :+
    neg
  :
  add BasePixelX
  sub #8
  sta CurrentX
  inc Pointer
  inc Pointer

  ; Y
  lda (Pointer)
  add BasePixelY
  add #-8+GAMEPLAY_SPRITE_Y_OFFSET
  sta CurrentY
  inc Pointer
  inc Pointer

SixteenStripLoop:
  ; Now read off a series of tiles
  lda (Pointer)
  and #64
  bne SixteenStripSkip

  jsr StripLoopCommon
  .a8
  lda #1
  rol
  sta OAMHI+1,y
  seta16

  ; Next sprite
  iny
  iny
  iny
  iny
SixteenStripSkip:
  inc Pointer

  lda CurrentX
  add WidthUnit
  sta CurrentX
  dec Count
  bne SixteenStripLoop

  ; Set WidthUnit back to how it was
  lda WidthUnit
  asl
  ror WidthUnit
  jmp StripStart

.a16
StripLoopCommon:
  lda (Pointer)
  pha
  and #31
  ora SpriteTileBase
  sta TempTile
  pla
  and #%11000000 ; The X and Y flip bits
  xba            ; Shift them over to where they are in the attributes
  eor TempTile
  sta OAM_TILE,y

  seta8
  lda CurrentX
  sta OAM_XPOS,y
  lda CurrentY
  sta OAM_YPOS,y
  lda CurrentX+1
  cmp #%00000001
  rts
.endproc

; Tests if two actors overlap
; Inputs: Actor pointers X and Y
.export TwoActorCollision
.a16
.i16
.proc TwoActorCollision
AWidth   = TouchTemp+0
  ; Test Y positions

  ; Actor 1's top edge should not be below actor 2's bottom edge
  lda ActorPY,x
  sub ActorHeight,x
  cmp ActorPY,y
  bcs No

  ; Actor 2's top edge should not be below actor 1's bottom edge
  lda ActorPY,y
  sub ActorHeight,y
  cmp ActorPY,x
  bcs No

  ; Test X positions

  ; The two actors' widths are added together, so just do this math now
  lda ActorWidth,x
  adc ActorWidth,y ; Carry clear - guaranteed by the bcs above
  sta AWidth

  ; Assert that (abs(a.x - b.x) * 2 < (a.width + b.width))
  lda ActorPX,x
  sub ActorPX,y
  bpl :+       ; Take the absolute value
    eor #$ffff
    ina
  :
  asl
  cmp AWidth
  bcs No

  ; -----------------------------------

Yes:
  sec
  rtl
No:
  clc
  rtl
.endproc


.export PlayerActorCollision
.a16
.i16
.proc PlayerActorCollision
.if 0
AWidth   = TouchTemp+0
  ; Actor's bottom edge should not be above player's top edge
  lda ActorPY,x
  cmp PlayerPYTop
  bcc No

  lda ActorWidth,x
  lsr
  sta AWidth

  ; Actor's left edge should not be more right than the player's right edge
  lda ActorPX,x
  sec
  sbc AWidth
  cmp PlayerPXRight
  bcs No

  ; Actor's right edge should not be more left than the player's left edge
  lda ActorPX,x
  sec
  adc AWidth
  cmp PlayerPXLeft
  bcc No

  ; Actor's top edge should not be below the player's bottom edge
  lda ActorPY,x
  sub ActorHeight,x
  cmp PlayerPY
  bcs No

Yes:
  sec
  rtl
.endif
No:
  clc
  rtl
.endproc

.export PlayerActorCollisionHurt
.a16
.i16
.proc PlayerActorCollisionHurt
  ; If touching the player, hurt them
  jsl PlayerActorCollision
  bcc :+
    .import HurtPlayer
    jml HurtPlayer
  :
Exit:
  rtl
.endproc

.export ActorClearX
.a16
.i16
.proc ActorClearX
  stz ActorVarA,x
  stz ActorVarB,x
  stz ActorVarC,x
  stz ActorVarD,x
  stz ActorVX,x
  stz ActorVXSub,x ; 24-bit variable
  stz ActorVY,x
  stz ActorVYSub,x ; 24-bit variable
  stz ActorTimer,x
  stz ActorFlips,x
  rtl
.endproc

.export ActorClearY
.a16
.i16
.proc ActorClearY
  phx
  tyx
  jsl ActorClearX
  plx
  rtl
.endproc

; Counts the amount of a certain actor that currently exists
; inputs: A (actor type * 2)
; outputs: Y (count)
; locals: 0
.export CountActorAmount
.a16
.i16
.proc CountActorAmount
  phx
  sta 0  ; 0 = object num
  ldy #0 ; Y = counter for number of matching objects

  ldx #ActorStart
Loop:
  lda ActorType,x
  cmp 0
  bne :+
    iny
  :
  txa
  add #ActorStructSize
  tax
  cpx #ActorEnd
  bne Loop

  plx
  tya
  rtl
.endproc

; Counts the amount of a certain projectile actor that currently exists
; TODO: maybe measure the projectile type, instead of the actor type?
; inputs: A (actor type * 2)
; outputs: Y (count)
; locals: 0
.export CountProjectileAmount
.a16
.i16
.proc CountProjectileAmount
  phx
  sta 0  ; 0 = object num
  ldy #0 ; Y = counter for number of matching objects

  ldx #ProjectileStart
Loop:
  lda ActorType,x
  cmp 0
  bne :+
    iny
  :
  txa
  add #ActorStructSize
  tax
  cpx #ProjectileEnd
  bne Loop

  plx
  tya
  rtl
.endproc



.export ActorCopyPosXY
.a16
.i16
.proc ActorCopyPosXY
  lda ActorPXSub,x
  sta ActorPXSub,y
  lda ActorPX,x
  sta ActorPX,y
  lda ActorPYSub,x
  sta ActorPYSub,y
  lda ActorPY,x
  sta ActorPY,y
  rtl
.endproc

; Removes an actor, and does any cleanup required
.export ActorSafeRemoveX
.a16
.i16
.proc ActorSafeRemoveX
  ; Can put a deconstructor call here, or make it deallocate resources
  stz ActorType,x
  rtl
.endproc

.export ActorSafeRemoveY
.proc ActorSafeRemoveY
  phx
  tyx
  jsl ActorSafeRemoveX
  plx
  rtl
.endproc

.a16
.i16
.export InitActorX
.proc InitActorX
  ; You could insert something here that calls a constructor of some sort
  ; Fall into UpdateActorSizeX
.endproc
.export UpdateActorSizeX
.proc UpdateActorSizeX
  phx
  phy
  txy
  lda ActorType,x
  tax
  lda f:ActorWidthTable,x
  sta ActorWidth,y
  lda f:ActorHeightTable,x
  sta ActorHeight,y
  ply
  plx
  rtl
.endproc

.a16
.i16
.export InitActorY
.proc InitActorY
  ; You could insert something here that calls a constructor of some sort
  ; Fall into UpdateActorSizeY
.endproc
.export UpdateActorSizeY
.proc UpdateActorSizeY
  phx
  phy
  tyx
  lda ActorType,x
  tax
  lda f:ActorWidthTable,x
  sta ActorWidth,y
  lda f:ActorHeightTable,x
  sta ActorHeight,y
  ply
  plx
  rtl
.endproc

.a16
.i16
.export CalculateActorVelocityFromAngleAndSpeed
.proc CalculateActorVelocityFromAngleAndSpeed
  lda ActorSpeed,x
  ldy ActorAngle,x
  jsl SpeedAngle2Offset256
  lda 0
  sta PlayerVXSub,x
  lda 1
  sta PlayerVX,x
  lda 3
  sta PlayerVYSub,x
  lda 4
  sta PlayerVY,x
  rtl
.endproc

; Calculates a horizontal and vertical speed from a speed and an angle
; input: A (speed) Y (angle, 0-255 times 2)
; output: 0,1,2 (X position), 3,4,5 (Y position)
.import MathSinTable, MathCosTable
.export SpeedAngle2Offset256
.proc SpeedAngle2Offset256
  php

  phb
  phk
  plb
  seta8
  sta M7MUL ; 8-bit factor

  lda MathCosTable+0,y
  sta M7MCAND ; 16-bit factor
  lda MathCosTable+1,y
  sta M7MCAND

  lda M7PRODLO
  sta 0
  lda M7PRODHI
  sta 1
  lda M7PRODBANK
  sta 2

  ; --------

  lda MathSinTable+0,y
  sta M7MCAND ; 16-bit factor
  lda MathSinTable+1,y
  sta M7MCAND

  lda M7PRODLO
  sta 3
  lda M7PRODHI
  sta 4
  lda M7PRODBANK
  sta 5
  plb
  plp
  rtl
.endproc

.a16
.i16
.export DivideActorVelocityBy2
.proc DivideActorVelocityBy2
  lda PlayerVX,x
  php
  lsr PlayerVX+1,x
  ror PlayerVXSub,x
  plp
  bpl :+
    lda PlayerVX,x
    ora #$8000
    sta PlayerVX,x
  :

  lda PlayerVY,x
  php
  lsr PlayerVY+1,x
  ror PlayerVYSub,x
  plp
  bpl :+
    lda PlayerVY,x
    ora #$8000
    sta PlayerVY,x
  :
  rtl
.endproc

.a16
.i16
.export DivideActorVelocityBy8
.proc DivideActorVelocityBy8
  lda PlayerVX,x
  php
  .repeat 3
  lsr PlayerVX+1,x
  ror PlayerVXSub,x
  .endrep
  plp
  bpl :+
    lda PlayerVX,x
    ora #$e000
    sta PlayerVX,x
  :

  lda PlayerVY,x
  php
  .repeat 3
  lsr PlayerVY+1,x
  ror PlayerVYSub,x
  .endrep
  plp
  bpl :+
    lda PlayerVY,x
    ora #$e000
    sta PlayerVY,x
  :
  rtl
.endproc

.a16
.i16
.export DivideActorVelocityBy16
.proc DivideActorVelocityBy16
  lda PlayerVX,x
  php
  .repeat 4
  lsr PlayerVX+1,x
  ror PlayerVXSub,x
  .endrep
  plp
  bpl :+
    lda PlayerVX,x
    ora #$f000
    sta PlayerVX,x
  :

  lda PlayerVY,x
  php
  .repeat 4
  lsr PlayerVY+1,x
  ror PlayerVYSub,x
  .endrep
  plp
  bpl :+
    lda PlayerVY,x
    ora #$f000
    sta PlayerVY,x
  :
  rtl
.endproc
