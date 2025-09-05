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

; -----------------------------------------------------------------------------
; This file defines the "actors" in the game - which may be enemies, enemy projectiles
; or things like moving platforms. Each actor has a Run routine and a Draw routine and both
; are normally called every frame.

; This separation allows you to call the Draw routine by itself without causing the actor
; to run its logic. This can be useful if you want to run the Run and Draw routines at separate
; times, or if the game design calls for having an actor be drawn but paused - such as if the
; game allowed for picking up and grabbing enemies.

; Actors are defined in actors.txt and tables are automatically put in actordata.s
; via a Python script.

; Most of the actors mostly just call routines from actorshared.s and chain multiple
; simple behaviors together to get something more complicated.

.include "snes.inc"
.include "global.inc"
.include "actorenum.s"
.include "blockenum.s"
.include "actorframedefine.inc"
.include "audio_enum.inc"
.include "tad-audio.inc"
.smart

.segment "C_ActorData"

.import DispActor16x16, DispActor8x8, DispActor8x8WithOffset, DispParticle8x8, DispParticle16x16, DispActorMeta
.import ActorWalk, ActorWalkOnPlatform, ActorFall, ActorGravity, ActorApplyXVelocity
.import ActorAutoBump, ActorTurnAround
.import PlayerActorCollision, PlayerActorCollisionHurt
.import FindFreeProjectileY, ActorApplyVelocity
.import ActorNegIfLeft
.import ActorTryUpInteraction, ActorTryDownInteraction
.import ActorCopyPosXY, InitActorX, InitActorY, ActorClearY
.import SharedEnemyCommon, SharedEnemyCommon_CustomDamage, ActorSafeRemoveX, ActorGetShotTest, ActorLookAtXY
.import PathfindTowardPlayer, ActorIsNextToSolid, TryForSpecificDistanceFromPlayer, GetDijkstraMapValueAtActor

.import CalculateActorVelocityFromAngleAndSpeed, DivideActorVelocityBy16, ActorMoveAndBumpAgainstWalls
.import MathSinTable, MathCosTable

.a16
.i16
.export DrawWalker
.proc DrawWalker
  lda retraces
  lsr
  lsr
  and #2
  add #$20|OAM_PRIORITY_2|OAM_COLOR_1
  jml DispActor16x16
.endproc

.a16
.i16
.export RunWalker
.proc RunWalker
  jml SharedEnemyCommon
.endproc

.a16
.i16
.export RunEnemyBullet
.proc RunEnemyBullet
	jsr ActorExpire
	jsl ActorApplyVelocity

	; Disappear when bumping into a wall
	lda ActorPX,x
	ldy ActorPY,x
	jsl GetLevelIndexXY
	phx
	tax
	lda f:BlockFlags,x
	plx
	asl
	bcc NoWall
		stz ActorType,x
	NoWall:

	lda #1
	jml PlayerActorCollisionHurt
.endproc

.a16
.i16
.export DrawEnemyBullet
.proc DrawEnemyBullet
	lda #OAM_PRIORITY_2 ; Draw ActorTileBase
	jml DispActor8x8
.endproc

; 
.export ActorExpire
.proc ActorExpire
  dec ActorTimer,x
  bne :+
    jsl ActorSafeRemoveX
  :
  rts
.endproc

.a16
.export ActorBecomePoof
.proc ActorBecomePoof
  jsl ActorSafeRemoveX
  jsl FindFreeParticleY
  bcc Exit
    lda #Particle::Poof
    sta ParticleType,y

    lda ActorPX,x
    sta ParticlePX,y

	lda ActorPY,x
    sta ParticlePY,y
Exit:
  rtl
.endproc

.a16
.export ActorLookAtPlayer
.proc ActorLookAtPlayer
	lda Player2+PlayerActive
	beq AimAtPlayer1
	lda Player1+PlayerActive
	beq AimAtPlayer2

	; 0 = Distance to player 1
	lda ActorPX,x
	sub Player1+PlayerPX
	abs
	sta 0
	lda ActorPY,x
	sub Player1+PlayerPY
	abs
	adc 0 ; Don't care about carry
	sta 0

	; 2 = Distance to player 2
	lda ActorPX,x
	sub Player2+PlayerPX
	abs
	sta 2
	lda ActorPY,x
	sub Player2+PlayerPY
	abs
	adc 2 ; Don't care about carry

	cmp 0
	bcc AimAtPlayer2

AimAtPlayer1:
	lda Player1+PlayerPX
	ldy Player1+PlayerPY
	jsl ActorLookAtXY
	sta ActorAngle,x
	rtl
AimAtPlayer2:
	lda Player2+PlayerPX
	ldy Player2+PlayerPY
	jsl ActorLookAtXY
	sta ActorAngle,x
	rtl
.endproc

; -----------------------------------------------

.a16
.i16
.export RunEnemyPortal
.proc RunEnemyPortal
	inc ActorTimer,x
	lda ActorTimer,x
	cmp #120 ; 30
	bcc No
		lda ActorVarB,x
		sta ActorType,x
		stz ActorVarB,x
		stz ActorTimer,x
		jsl InitActorX
	No:
	rtl
.endproc

.a16
.i16
.export DrawEnemyPortal
.proc DrawEnemyPortal
	lda ActorTimer,x
	cmp #15
	bcs Always
	lsr
	bcc :+
		rtl
	:
Always:
	lda ActorTimer,x
	lsr
	lsr
	and #%110
	tay
	lda Animation,y
	jml DispActor16x16

Animation:
	.word 11|(4<<4)|OAM_PRIORITY_2|(SP_ICON_PALETTE << OAM_COLOR_SHIFT)
	.word 11|(4<<4)|OAM_PRIORITY_2|(SP_ICON_PALETTE << OAM_COLOR_SHIFT)|OAM_XFLIP
	.word 11|(4<<4)|OAM_PRIORITY_2|(SP_ICON_PALETTE << OAM_COLOR_SHIFT)|OAM_XFLIP|OAM_YFLIP
	.word 11|(4<<4)|OAM_PRIORITY_2|(SP_ICON_PALETTE << OAM_COLOR_SHIFT)|OAM_YFLIP
.endproc

.proc SetActorSpeedAndVelocity
	ldy ActorHitShake,x
	beq :+
		lsr
	:
	sta ActorSpeed,x
	jsl CalculateActorVelocityFromAngleAndSpeed
	jsl DivideActorVelocityBy16
	rts
.endproc

.a16
.i16
.export RunPowerup
.proc RunPowerup
	inc ActorTimer,x
	lda ActorTimer,x
	cmp #60*7
	bcc :+
		stz ActorType,x
	:

	jsl PlayerActorCollision
	bcc NotTouched
        lda #SFX::collect_coin
        jsl PlaySoundEffect

		stz ActorType,x
		phy
		ldy ActorVarA,x
		lda PowerupHandlers,y
		ply
		pha
		rts
	NotTouched:
	rtl

PowerupHandlers:
	.addr PowerupAmmo-1
	.addr PowerupHealth-1
	.addr PowerupSpeed-1
	.addr PowerupBomb-1

PowerupAmmo:
	phx
	tyx
	lda PlayerAmmo,x
	add #AMMO_PICKUP_AMOUNT
	cmp #MAX_AMMO_AMOUNT
	bcc :+
		lda #MAX_AMMO_AMOUNT
	:
	sta PlayerAmmo,x
	.import UpdatePlayerAmmoTiles
	jsl UpdatePlayerAmmoTiles
	plx
	rtl
PowerupHealth:
	phx
	tyx
	lda PlayerHealth,x
	add #HEALTH_PICKUP_AMOUNT
	cmp #MAX_HEALTH_AMOUNT
	bcc :+
		lda #MAX_HEALTH_AMOUNT
	:
	sta PlayerHealth,x
	.import UpdatePlayerHealthTiles
	jsl UpdatePlayerHealthTiles
	plx
	rtl
PowerupSpeed:
	lda #SPEEDUP_PICKUP_TIME
	sta PlayerSpeedupTimer,y
	rtl
PowerupBomb:
	phx
	tyx
	lda #5
    .import HurtPlayer
    jsl HurtPlayer
	plx
	rtl
.endproc

.a16
.i16
.export DrawPowerup
.proc DrawPowerup
	lda ActorVarA,x
	add #$68|OAM_PRIORITY_2|(BG_ICON_PALETTE << OAM_COLOR_SHIFT)
	jml DispActor16x16
.endproc

.a16
.i16
.export RunEnemyCookie
.proc RunEnemyCookie
	lda #3
	jsr SetActorSpeedAndVelocity

	lda ActorAngle,x
	pha
	jsl ActorMoveAndBumpAgainstWalls
	pla
	cmp ActorAngle,x
	beq :+
		jsl RandomByte
		and #31*2
		sub #16*2
		add ActorAngle,x
		and #510
		sta ActorAngle,x
	:

	jml SharedEnemyCommon
.endproc

.a16
.i16
.export DrawEnemyCookie
.proc DrawEnemyCookie
	lda #$00|OAM_PRIORITY_2
	jml DispActor16x16
.endproc

.a16
.i16
.export RunEnemyBurger
.proc RunEnemyBurger
	jml SharedEnemyCommon
.endproc

.a16
.i16
.export DrawEnemyBurger
.proc DrawEnemyBurger
	lda #2|OAM_PRIORITY_2
	jml DispActor16x16
.endproc

.a16
.i16
.export RunEnemyFries
.proc RunEnemyFries
	jml SharedEnemyCommon
.endproc

.a16
.i16
.export DrawEnemyFries
.proc DrawEnemyFries
	lda #4|OAM_PRIORITY_2
	jml DispActor16x16
.endproc

.a16
.i16
.export RunEnemyFriesProjectile
.proc RunEnemyFriesProjectile
	rtl
.endproc

.a16
.i16
.export DrawEnemyFriesProjectile
.proc DrawEnemyFriesProjectile
	lda #8|OAM_PRIORITY_2
	jml DispActor16x16
.endproc

.a16
.i16
.export RunEnemyBadGuy
.proc RunEnemyBadGuy
	lda framecount
	and #64
	beq Nothing
	;lda framecount
	;and #63
	;bne :+
	;	jsl ActorLookAtPlayer
	;:

	jsl PathfindTowardPlayer
	lda #2
	jsr SetActorSpeedAndVelocity
	jsl ActorMoveAndBumpAgainstWalls

	.if 0
	lda ActorAngle,x
	pha
	jsl ActorMoveAndBumpAgainstWalls
	pla
	cmp ActorAngle,x
	beq :+
		jsl RandomByte
		and #31*2
		sub #16*2
		add ActorAngle,x
		and #510
		sta ActorAngle,x
	:
	.endif

Nothing:
	lda #4
	jml SharedEnemyCommon_CustomDamage
.endproc

.a16
.i16
.export DrawEnemyBadGuy
.proc DrawEnemyBadGuy
	lda #OAM_PRIORITY_2
	ora ActorTileBase,x
	sta ActorTileBase,x

	lda framecount
	and #64
	bne Walking
	lda framecount
	lsr
	lsr
	lsr
	and #%110
	tay
	lda Frames,y
.import DispActorMetaLeft
	jml DispActorMeta

Walking:
	ldy #.loword(FrameWalk1)
	lda framecount
	and #8
	beq :+
		ldy #.loword(FrameWalk2)
	:
	tya
	jml DispActorMeta

Frames:
	.addr Frame1, Frame2, Frame3, Frame2
Frame1:
	Row16x16 -8,0, 0, 2
	EndMetasprite
Frame2:
	Row16x16 -8,0, 4, 6
	EndMetasprite
Frame3:
	Row16x16 -8,0, 8, 10
	EndMetasprite
FrameWalk1:
	Row8x8 -12,-4, $00,$01,$02,$03
	Row8x8 -12, 4, $10,12,$12,$13
	EndMetasprite
FrameWalk2:
	Row8x8 -12,-4, $00,$01,$02,$03
	Row8x8 -12, 4, $10,$11,13,$13
	EndMetasprite
.endproc

.a16
.i16
.export RunEnemyPumpkin
.proc RunEnemyPumpkin
	jsl PathfindTowardPlayer
	jsl GetDijkstraMapValueAtActor
	jsr SetActorSpeedAndVelocity
	jsl ActorMoveAndBumpAgainstWalls

	lda #4
	jml SharedEnemyCommon_CustomDamage
.endproc

.a16
.i16
.export DrawEnemyPumpkin
.proc DrawEnemyPumpkin
	lda framecount
	lsr
	lsr
	and #2
	add #12|OAM_PRIORITY_2
	jml DispActor16x16
.endproc

.a16
.i16
.export RunEnemySnowman
.proc RunEnemySnowman
	lda ActorVarA,x
	beq NotPathfinding
		jsl PathfindTowardPlayer

		jsl ActorIsNextToSolid
		bcs DontStopPathfinding

		lda ActorTimer,x
		beq :+
			dec ActorTimer,x
		:
		bne DontStopPathfinding
		stz ActorVarA,x
		bra DontStopPathfinding
	NotPathfinding:

	lda framecount
	and #15
	bne :+
		jsl ActorLookAtPlayer
		jsr FlipBasedOnAngle
	:
DontStopPathfinding:

	lda #1
	jsr SetActorSpeedAndVelocity

	lda ActorAngle,x
	pha
	jsl ActorMoveAndBumpAgainstWalls
	pla
	cmp ActorAngle,x
	beq :+
		lda #1
		sta ActorVarA,x
		lda #100
		sta ActorTimer,x
	:

	lda framecount
	and #127
	bne NoShoot
	jsl FindFreeActorY
	bcc NoShoot
		jsl ActorClearY
		lda #Actor::EnemySnowball*2
		sta ActorType,y
		jsl InitActorY

		lda ActorPX,x
		sta ActorPX,y
		lda ActorPY,x
		sta ActorPY,y
		stx ActorVarA,y

		lda #60
		sta ActorTimer,y
	NoShoot:

	jml SharedEnemyCommon
.endproc

.a16
.i16
.export DrawEnemySnowman
.proc DrawEnemySnowman
	lda ActorPY,x
	pha
	lda framecount
	lsr
	lsr
	pha
	asl
	and #%1110
	tay
	lda Bounce,y
	add ActorPY,x
	sta ActorPY,x
	pla
	and #%110
	tay
	lda Animation,y
	jsl DispActor16x16

	pla
	sta ActorPY,x
	rtl
Animation:
	.word 0|OAM_PRIORITY_2
	.word 0|OAM_PRIORITY_2
	.word 0|OAM_PRIORITY_2
	.word 13|OAM_PRIORITY_2
Bounce:
	.word .loword(-1*16)
	.word .loword(-2*16)
	.word .loword(-3*16)
	.word .loword(-2*16)
	.word .loword(-1*16)
	.word 0
	.word 0
	.word 0
.endproc

.a16
.i16
.export RunEnemyProSnowman
.proc RunEnemyProSnowman
	lda framecount
	and #7
	bne NoSpeedup

	lda ActorVarA,x
	lda ActorAngle,x
	add ActorVarA,x
	and #510
	sta ActorAngle,x

	lda ActorSpeed,x
	cmp #10
	bcs :+
		inc ActorSpeed,x
	NoSpeedup:
		lda ActorSpeed,x
	:
	jsr SetActorSpeedAndVelocity

	; ---

	lda ActorAngle,x
	pha
	jsl ActorMoveAndBumpAgainstWalls
	pla
	cmp ActorAngle,x
	beq :+
		lda #1
		sta ActorSpeed,x

		jsl RandomByte
		and #63*2
		sub #32*2
		add ActorAngle,x
		and #510
		sta ActorAngle,x

		; Change the turn amount
		jsl RandomByte
		and #15*2
		sub #8*2
		sta ActorVarA,x
	:

	jsr FlipBasedOnAngle

	; Become board-less snowman
	lda #2
	jsl PlayerActorCollisionHurt
	jsl ActorGetShotTest
	bcc :+
		.importzp ActorGetShotTest_ProjectileIndex
		ldy ActorGetShotTest_ProjectileIndex
		lda #0
		sta ActorType,y
		lda #Actor::EnemySnowman*2
		sta ActorType,x

		; Create the snowboard that flies away
		jsl FindFreeActorY
		bcc NoBoard
			jsl ActorClearY
			lda #Actor::EnemyProSnowmanBoard*2
			sta ActorType,y
			jsl InitActorY

			lda ActorPX,x
			sta ActorPX,y
			lda ActorPY,x
			sta ActorPY,y

			jsl RandomByte
			and #31
			jsl VelocityLeftOrRight
			sta ActorVX,y
			lda #.loword(-$20)
			sta ActorVY,y
	  NoBoard:
	:
	rtl
.endproc

.a16
.i16
.export DrawEnemyProSnowman
.proc DrawEnemyProSnowman
	lda framecount
	lsr
	lsr
	lsr
	lsr
	and #%110
	tay
	lda Frames,y
	jml DispActor16x16
Frames:
	.word $02|OAM_PRIORITY_2
	.word $04|OAM_PRIORITY_2
	.word $02|OAM_PRIORITY_2
	.word $06|OAM_PRIORITY_2
.endproc

.a16
.i16
.export RunEnemySnowball
.proc RunEnemySnowball
	lda ActorVarB,x
	bne ThrownAlready
	dec ActorTimer,x

	lda framecount
	lsr
	and #%1110
	tay
	lda Bounce,y
	sta 0

	ldy ActorVarA,x
	lda ActorType,y
	cmp #Actor::EnemySnowman*2
	bne Throw ; Immediately throw if the snowman is gone

	lda ActorPX,y
	sta ActorPX,x
	lda ActorPY,y
	add 0
	sta ActorPY,x

	; When it reaches zero, aim at player
	lda ActorTimer,x
	bne Exit
Throw:
	jsl ActorLookAtPlayer
	lda #4
	sta ActorVarB,x
	jsr SetActorSpeedAndVelocity
	lda #100
	sta ActorTimer,x

Exit:
	rtl

ThrownAlready:
	jmp RunEnemyBullet

Bounce:
	.word .loword((-$080)-1*16)
	.word .loword((-$080)-3*16)
	.word .loword((-$080)-5*16)
	.word .loword((-$080)-6*16)
	.word .loword((-$080)-5*16)
	.word .loword((-$080)-3*16)
	.word .loword((-$080)-0*16)
	.word .loword((-$080)-0*16)

;	.word .loword((-$080)-1*16)
;	.word .loword((-$080)-2*16)
;	.word .loword((-$080)-3*16)
;	.word .loword((-$080)-2*16)
;	.word .loword((-$080)-1*16)
;	.word .loword((-$080)-0*16)
;	.word .loword((-$080)-0*16)
;	.word .loword((-$080)-0*16)
.endproc

.a16
.i16
.export DrawEnemySnowball
.proc DrawEnemySnowball
	lda #9|OAM_PRIORITY_2
	jml DispActor8x8
.endproc

.a16
.i16
.export RunEnemyProSnowmanBoard
.proc RunEnemyProSnowmanBoard
	lda ActorPX,x
	add ActorVX,x
	sta ActorPX,x

	lda ActorPY,x
	add ActorVY,x
	sta ActorPY,x
	cmp #12*256
	bcs Gone

	lda ActorVY,x
	add #4
	sta ActorVY,x
	rtl
Gone:
	stz ActorType,x
	rtl

.endproc

.a16
.i16
.export DrawEnemyProSnowmanBoard
.proc DrawEnemyProSnowmanBoard
	lda framecount
	and #%110
	tay
	lda Frames,y
	pha
	rts
Frames:
	.addr FrameHorizontal-1
	.addr FrameDiagonal1-1
	.addr FrameVertical-1
	.addr FrameDiagonal2-1

FrameHorizontal:
	lda #.loword((-4 & 255) | (-4 << 8))
	sta SpriteXYOffset
	lda #$18|OAM_PRIORITY_2
	jsl DispActor8x8WithOffset
	lda #.loword((4 & 255) | (-4 << 8))
	sta SpriteXYOffset
	lda #$19|OAM_PRIORITY_2
	jml DispActor8x8WithOffset
FrameDiagonal1:
	lda #10|OAM_PRIORITY_2
	jml DispActor16x16
FrameVertical:
	lda #.loword(-8 << 8)
	sta SpriteXYOffset
	lda #$0C|OAM_PRIORITY_2
	jsl DispActor8x8WithOffset
	lda #.loword(0 << 8)
	sta SpriteXYOffset
	lda #$1C|OAM_PRIORITY_2
	jml DispActor8x8WithOffset
FrameDiagonal2:
	lda #10|OAM_PRIORITY_2|OAM_XFLIP
	jml DispActor16x16
.endproc

.a16
.i16
.export RunEnemyGreenPirate
.proc RunEnemyGreenPirate
	lda framecount
	and #$1FF
	bne :+
		jsl RandomByte
		and #3
		sta ActorVarC,x
	:

	lda ActorVarC,x
	add #3
	jsl TryForSpecificDistanceFromPlayer

	jsl GetDijkstraMapValueAtActor
	sub #4
	beq NoMove
	abs
	cmp #8
	bcc :+
		lda #8
	:
	jsr SetActorSpeedAndVelocity
	jsl ActorMoveAndBumpAgainstWalls
NoMove:

	lda framecount
	and #%111
	bne NoAim
	lda ActorAngle,x
	pha
	jsl ActorLookAtPlayer
	sta ActorVarA,x
	jsr FlipBasedOnAngle
	pla
	sta ActorAngle,x
NoAim:

	jsl RandomByte
	and #3
	bne :+
	lda framecount
	and #63
	bne :+
		lda #60
		sta ActorVarB,x
	:

	lda ActorVarB,x
	beq NoShoot
	dec ActorVarB,x
	bne NoShoot
	jsl FindFreeActorY
	bcc NoShoot
		jsl ActorClearY
		lda #Actor::EnemyBullet*2
		sta ActorType,y
		jsl InitActorY

		lda ActorPX,x
		sta ActorPX,y
		lda ActorPY,x
		sta ActorPY,y
		lda ActorVarA,x
		sta ActorAngle,y
		lda #(SP_ICON_PALETTE << OAM_COLOR_SHIFT) | 11 | 32
		sta ActorTileBase,y
		lda #120
		sta ActorTimer,y

		phx
		phy
		tyx
		lda #4
		jsr SetActorSpeedAndVelocity
		ply
		plx
		lda ActorVX,y
		asl
		asl
		asl
		asl
		add ActorPX,y
		sta ActorPX,y
		lda ActorVY,y
		asl
		asl
		asl
		asl
		add ActorPY,y
		sta ActorPY,y
	NoShoot:

	jml SharedEnemyCommon
.endproc

.a16
.i16
.export DrawEnemyGreenPirate
.proc DrawEnemyGreenPirate
	lda #.loword(CannonFrames)
	jsr DrawEnemyCannon

	; Draw enemy
	lda ActorAngle,x
	add #32
	lsr
	lsr
	lsr
	lsr
	lsr
	lsr
	and #%110
	tay
	lda Frames,y
	jml DispActor16x16
Frames:
	.word 2|OAM_PRIORITY_2
	.word 4|OAM_PRIORITY_2
	.word 2|OAM_PRIORITY_2
	.word 0|OAM_PRIORITY_2
CannonFrames:
	.word 6|OAM_PRIORITY_2
	.word 7|OAM_PRIORITY_2
	.word 6|16|OAM_PRIORITY_2
	.word 7|16|OAM_PRIORITY_2
	.word 6|OAM_PRIORITY_2 | OAM_XFLIP | OAM_YFLIP
	.word 7|OAM_PRIORITY_2 | OAM_XFLIP | OAM_YFLIP
	.word 6|16|OAM_PRIORITY_2 | OAM_XFLIP | OAM_YFLIP
	.word 7|16|OAM_PRIORITY_2 | OAM_XFLIP | OAM_YFLIP
.endproc

.a16
.i16
.proc DrawEnemyCannon
CannonOffX = 0
CannonOffY = 2
CannonTile = 4
Temp = 4
	sta CannonTile
	phx
	lda ActorVarA,x
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
	
	lda ActorVarA,x        ; .......n nnnnnnn0
	add #32
	asl                    ; ......nn nnnnnn00
	asl                    ; .....nnn nnnnn000
	asl
	xba
	and #%1110
	add CannonTile
	tay
	lda a:0,y
	sta CannonTile

	ldy OamPtr
	lda ActorTileBase,x
	and #.loword(~(OAM_XFLIP | OAM_YFLIP))
	ora CannonTile
	sta OAM_TILE,y ; 16-bit, combined with attribute
	lda #(SP_ICON_PALETTE << OAM_COLOR_SHIFT) | OAM_PRIORITY_2 | 32 | 10
	sta OAM_TILE+4,y

	; Calculate sprite X positions in 16-bit mode
	lda ActorPX,x
	lsr
	lsr
	lsr
	lsr
	sub #4
	add CannonOffX
	sta CannonOffX

	lda ActorPY,x
	lsr
	lsr
	lsr
	lsr
	add #-4+GAMEPLAY_SPRITE_Y_OFFSET
	add CannonOffY
	sta CannonOffY
	
	seta8
	lda CannonOffX
	sta OAM_XPOS,y
	sta OAM_XPOS+4,y
	
	lda CannonOffY
	sta OAM_YPOS,y

	lda ActorVarB,x
	beq :+
		phy
		tdc
		lda framecount
		and #31
		tay
		lda WarningCircle+8,y
		add CannonOffX
		sta Temp
		lda WarningCircle,y
		add CannonOffY
		ply
		sta OAM_YPOS+4,y

		lda Temp
		sta OAM_XPOS+4,y
	:
	
	; High OAM bits
	tdc
	lsr CannonOffX+1
	rol
	sta OAMHI+1+0,y
	sta OAMHI+1+4,y
	seta16_clc
	tya
	adc #4 ; Carry cleared above
	sta OamPtr

	lda ActorVarB,x
	beq :+
		tya
		adc #8 ; Carry should still be clear!
		sta OamPtr
	:
	rts

WarningCircle:
	.lobytes 0, 2, 3, 4, 6, 7, 7, 8, 8, 8, 7, 7, 6, 4, 3, 2, 0, -2, -3, -4, -6, -7, -7, -8, -8, -8, -7, -7, -6, -4, -3, -2, 0, 2, 3, 4, 6, 7, 7, 8
.endproc

.a16
.i16
.export RunEnemySaladBowl
.proc RunEnemySaladBowl
	lda #1
	jsr SetActorSpeedAndVelocity

	lda ActorAngle,x
	pha
	jsl ActorMoveAndBumpAgainstWalls
	pla
	cmp ActorAngle,x
	beq NoBump
		jsl RandomByte
		and #63*2
		sub #32*2
		add ActorAngle,x
		and #510
		sta ActorAngle,x

		lda ActorTimer,x
		bne NoDrop
			jsl FindFreeActorY
			bcc NoDrop
				jsl ActorClearY
				lda #Actor::EnemySaladProjectile*2
				sta ActorType,y

				; Gradually have more razors in the salad
				lda ActorVarC,x
				add #4
				sta ActorVarC,x

				jsl RandomByte
				add ActorVarC,x
				cmp #200
				bcc :+
					lda #Actor::EnemySaladRazor*2
					sta ActorType,y
				:
				jsl InitActorY

				lda ActorPX,x
				sta ActorPX,y
				lda ActorPY,x
				sta ActorPY,y

				lda #100
				sta ActorTimer,x
		NoDrop:
	NoBump:

	lda ActorTimer,x
	beq :+
		dec ActorTimer,x
	:

	jml SharedEnemyCommon
.endproc

.a16
.i16
.export DrawEnemySaladBowl
.proc DrawEnemySaladBowl
	lda ActorTimer,x
	bne :+
	lda #$08|OAM_PRIORITY_2
	jml DispActor16x16
:	lda #$0A|OAM_PRIORITY_2
	jml DispActor16x16
.endproc

.a16
.i16
.export RunEnemySaladProjectile
.proc RunEnemySaladProjectile
	inc ActorTimer,x
	lda ActorTimer,x
	cmp #60*10
	bcc :+
		stz ActorType,x
	:

	jsl PlayerActorCollision
	bcc :+
		stz ActorType,x

		lda PlayerMoveAngle,y
		add #256
		and #510
		sta PlayerMoveAngle,y
	:
	rtl
.endproc

.a16
.i16
.export DrawEnemySaladProjectile
.proc DrawEnemySaladProjectile
	lda #12|OAM_PRIORITY_2
	jml DispActor16x16
.endproc

.a16
.i16
.export RunEnemySaladRazor
.proc RunEnemySaladRazor
	inc ActorTimer,x
	lda ActorTimer,x
	cmp #60*15
	bcc :+
		stz ActorType,x
	:

	lda #5
	jsl PlayerActorCollisionHurt
	bcc :+
		stz ActorType,x

		lda PlayerMoveAngle,y
		add #256
		and #510
		sta PlayerMoveAngle,y
	:
	rtl
.endproc

.a16
.i16
.export DrawEnemySaladRazor
.proc DrawEnemySaladRazor
	lda #14|OAM_PRIORITY_2
	jml DispActor16x16
.endproc

; Big circles
.a16
.i16
.export RunEnemyBalloon1
.proc RunEnemyBalloon1
	lda ActorAngle,x
	add #2
	and #511
	sta ActorAngle,x

	lda #8
	jsr SetActorSpeedAndVelocity
	lda ActorAngle,x
	jsl ActorMoveAndBumpAgainstWalls
	jml SharedEnemyCommon
.endproc

.a16
.i16
.export DrawEnemyBalloon1
.proc DrawEnemyBalloon1
	lda #0|OAM_PRIORITY_2
	jml DispActor16x16
.endproc

; Bigger circles?
.a16
.i16
.export RunEnemyBalloon2
.proc RunEnemyBalloon2
	lda framecount
	and #3
	bne :+
		lda ActorAngle,x
		add #2
		and #511
		sta ActorAngle,x
	:

	lda #4
	jsr SetActorSpeedAndVelocity
	lda ActorAngle,x
	jsl ActorMoveAndBumpAgainstWalls
	jml SharedEnemyCommon
.endproc

.a16
.i16
.export DrawEnemyBalloon2
.proc DrawEnemyBalloon2
	lda #4|OAM_PRIORITY_2
	jml DispActor16x16
.endproc

; Aim towards player
.a16
.i16
.export RunEnemyBalloon3
.proc RunEnemyBalloon3
	lda framecount
	and #1
	bne No
		lda ActorAngle,x
		pha
		jsl ActorLookAtPlayer
		sta 0
		pla
		sta ActorAngle,x
		cmp 0
		bcs :+
			add #8
			bra :++
		:
			sub #8
		:
		and #511
		sta ActorAngle,x
	No:

	lda #7
	jsr SetActorSpeedAndVelocity
	lda ActorAngle,x
	jsl ActorMoveAndBumpAgainstWalls
	jml SharedEnemyCommon
.endproc

.a16
.i16
.export DrawEnemyBalloon3
.proc DrawEnemyBalloon3
	lda #8|OAM_PRIORITY_2
	jml DispActor16x16
.endproc

; Bounce
.a16
.i16
.export RunEnemyBalloon4
.proc RunEnemyBalloon4
	jsl RandomByte
	and #3
	bne :+
		jsl RandomByte
		and #15*2
		sub #4*2
		add ActorAngle,x
		and #511
		sta ActorAngle,x
	:

	lda #4
	jsr SetActorSpeedAndVelocity
	lda ActorAngle,x
	jsl ActorMoveAndBumpAgainstWalls
	jml SharedEnemyCommon
.endproc

.a16
.i16
.export DrawEnemyBalloon4
.proc DrawEnemyBalloon4
	lda #12|OAM_PRIORITY_2
	jml DispActor16x16
.endproc

.a16
.i16
.export RunEnemyHotWheel
.proc RunEnemyHotWheel
	lda ActorVarA,x ; Waiting state
	beq NotBoosting
		dec ActorTimer,x
		bne Nothing
		stz ActorVarA,x
		lda #18
		sta ActorSpeed,x
		jsl ActorLookAtPlayer
	NotBoosting:

	lda framecount
	and #63
	bne NoBoost
		lda ActorSpeed,x
		cmp #3
		bne NoBoost
		jsl RandomByte
		and #3
		bne NoBoost
			lda #60
			sta ActorVarA,x  ; In the waiting state
			sta ActorTimer,x
	NoBoost:

	lda ActorSpeed,x
	bne :+
		lda #3
		sta ActorSpeed,x
	:
	cmp #4
	bcc :+
		lda framecount
		and #31
		bne :+
			dec ActorSpeed,x
	:
	
	lda ActorSpeed,x
	jsr SetActorSpeedAndVelocity

	lda ActorAngle,x
	pha
	jsl ActorMoveAndBumpAgainstWalls
	pla
	cmp ActorAngle,x
	beq :+
		jsl RandomByte
		and #63*2
		sub #32*2
		add ActorAngle,x
		and #510
		sta ActorAngle,x
	:

	jsr FlipBasedOnAngle
Nothing:
	jml SharedEnemyCommon
.endproc

.a16
.i16
.export DrawEnemyHotWheel
.proc DrawEnemyHotWheel
	lda framecount
	lsr
	lsr
	and #%110
	ora #OAM_PRIORITY_2
	jml DispActor16x16
.endproc

.a16
.i16
.export RunEnemyBunnyROM
.proc RunEnemyBunnyROM
	lda ActorVarA,x
	beq NotBoosting
		dec ActorTimer,x
		bne Nothing
		stz ActorVarA,x
		lda #12
		sta ActorSpeed,x
		jsl ActorLookAtPlayer
	NotBoosting:

	lda framecount
	and #63
	bne NoBoost
		lda ActorSpeed,x
		cmp #3
		bne NoBoost
		jsl RandomByte
		and #3
		bne NoBoost
			lda #15
			sta ActorVarA,x
			sta ActorTimer,x
	NoBoost:

	lda ActorSpeed,x
	bne :+
		lda #3
		sta ActorSpeed,x
	:
	cmp #4
	bcc :+
		lda framecount
		and #31
		bne :+
			dec ActorSpeed,x
	:
	
	lda ActorSpeed,x
	jsr SetActorSpeedAndVelocity

	lda ActorAngle,x
	pha
	jsl ActorMoveAndBumpAgainstWalls
	pla
	cmp ActorAngle,x
	beq :+
		jsl RandomByte
		and #31*2
		sub #16*2
		add ActorAngle,x
		and #510
		sta ActorAngle,x
	:

	jsr FlipBasedOnAngle
Nothing:
	lda #3
	jml SharedEnemyCommon_CustomDamage
.endproc

.a16
.i16
.export DrawEnemyBunnyROM
.proc DrawEnemyBunnyROM
	lda ActorVarA,x
	bne ChargingUp
	lda #8|OAM_PRIORITY_2
	jml DispActor16x16
ChargingUp:
	lda framecount
	lsr
	and #2
	add #8|OAM_PRIORITY_2
	jml DispActor16x16
.endproc

.a16
.i16
.export RunEnemyRedCannon
.proc RunEnemyRedCannon
	jml SharedEnemyCommon
.endproc

.a16
.i16
.export DrawEnemyRedCannon
.proc DrawEnemyRedCannon
	lda #0|OAM_PRIORITY_2
	jml DispActor16x16
.endproc

.a16
.i16
.export RunEnemyRedCannonBall
.proc RunEnemyRedCannonBall
	jml SharedEnemyCommon
.endproc

.a16
.i16
.export DrawEnemyRedCannonBall
.proc DrawEnemyRedCannonBall
	lda #8|OAM_PRIORITY_2
	jml DispActor16x16
.endproc

.a16
.i16
.export RunEnemyBlueCannon
.proc RunEnemyBlueCannon
	rtl
.endproc

.a16
.i16
.export DrawEnemyBlueCannon
.proc DrawEnemyBlueCannon
	lda #0|OAM_PRIORITY_2
	jml DispActor16x16
.endproc

.a16
.i16
.export RunEnemyBlueCannonBall
.proc RunEnemyBlueCannonBall
	rtl
.endproc

.a16
.i16
.export DrawEnemyBlueCannonBall
.proc DrawEnemyBlueCannonBall
	lda #8|OAM_PRIORITY_2
	jml DispActor16x16
.endproc


.a16
.i16
.export RunEnemyBluePunch
.proc RunEnemyBluePunch
	rtl
.endproc

.a16
.i16
.export DrawEnemyBluePunch
.proc DrawEnemyBluePunch
	lda #10|OAM_PRIORITY_2
	jml DispActor16x16
.endproc

.a16
.i16
.export RunEnemyRedPunch
.proc RunEnemyRedPunch
	rtl
.endproc

.a16
.i16
.export DrawEnemyRedPunch
.proc DrawEnemyRedPunch
	lda #10|OAM_PRIORITY_2
	jml DispActor16x16
.endproc

.a16
.i16
.export RunEnemyBluePooChi
.proc RunEnemyBluePooChi
	lda #5
	jsr SetActorSpeedAndVelocity

	lda ActorAngle,x
	pha
	jsl ActorMoveAndBumpAgainstWalls
	pla
	cmp ActorAngle,x
	beq :+
		jsl RandomByte
		and #31*2
		sub #16*2
		add ActorAngle,x
		and #510
		sta ActorAngle,x
	:

	jsr FlipBasedOnAngle
	jml SharedEnemyCommon
.endproc

.proc FlipBasedOnAngle
	lda ActorAngle,x
	sub #128
	and #510
	cmp #256
	bcs :+
	lda ActorTileBase,x
	ora #OAM_XFLIP
	sta ActorTileBase,x
	rts
:	lda ActorTileBase,x
	and #.loword(~OAM_XFLIP)
	sta ActorTileBase,x
	rts
.endproc

.a16
.i16
.export DrawEnemyBluePooChi
.proc DrawEnemyBluePooChi
	lda framecount
	lsr
	lsr
	lsr
	and #%10
	ora #$00|OAM_PRIORITY_2
	jml DispActor16x16
.endproc

.a16
.i16
.export RunEnemyRedPooChi
.proc RunEnemyRedPooChi
	jml SharedEnemyCommon
.endproc

.a16
.i16
.export DrawEnemyRedPooChi
.proc DrawEnemyRedPooChi
	lda #4|OAM_PRIORITY_2
	jml DispActor16x16
.endproc

.a16
.i16
.export RunEnemyDarkPirate
.proc RunEnemyDarkPirate
	lda framecount
	and #$1FF
	bne :+
		jsl RandomByte
		and #3
		sta ActorVarC,x
	:

	lda ActorVarC,x
	add #7
	jsl TryForSpecificDistanceFromPlayer

	jsl GetDijkstraMapValueAtActor
	sub #8
	beq NoMove
	abs
	asl
	cmp #8
	bcc :+
		lda #8
	:
	jsr SetActorSpeedAndVelocity
	jsl ActorMoveAndBumpAgainstWalls
NoMove:

	lda framecount
	and #%111
	bne NoAim
	lda ActorAngle,x
	pha
	jsl ActorLookAtPlayer
	sta ActorVarA,x
	jsr FlipBasedOnAngle
	pla
	sta ActorAngle,x
NoAim:

	jsl RandomByte
	and #3
	bne :+
	lda framecount
	and #63
	bne :+
		lda #60
		sta ActorVarB,x
	:

	lda ActorVarB,x
	beq NoShoot
	dec ActorVarB,x
	bne NoShoot
	jsl FindFreeActorY
	bcc NoShoot
		jsl ActorClearY
		lda #Actor::EnemyBullet*2
		sta ActorType,y
		jsl InitActorY

		lda ActorPX,x
		sta ActorPX,y
		lda ActorPY,x
		sta ActorPY,y
		jsl RandomByte
		and #15*2
		sub #8*2
		add ActorVarA,x
		and #511
		sta ActorAngle,y
		lda #(SP_ICON_PALETTE << OAM_COLOR_SHIFT) | 12 | 16
		sta ActorTileBase,y
		lda #240
		sta ActorTimer,y

		phx
		phy
		tyx
		lda #6
		jsr SetActorSpeedAndVelocity
		ply
		plx
		lda ActorVX,y
		asl
		asl
		asl
		add ActorPX,y
		sta ActorPX,y
		lda ActorVY,y
		asl
		asl
		asl
		add ActorPY,y
		sta ActorPY,y
	NoShoot:

	jml SharedEnemyCommon
.endproc

.a16
.i16
.export DrawEnemyDarkPirate
.proc DrawEnemyDarkPirate
	lda #.loword(CannonFrames)
	jsr DrawEnemyCannon

	lda PlayerMoveAngle,x
	add #32
	lsr
	lsr
	lsr
	lsr
	lsr
	lsr
	and #%110
	tay
	lda Frames,y
	jml DispActor16x16
Frames:
	.word 10|OAM_PRIORITY_2
	.word 12|OAM_PRIORITY_2
	.word 10|OAM_PRIORITY_2
	.word 8|OAM_PRIORITY_2
CannonFrames:
	.word 14|OAM_PRIORITY_2
	.word 15|OAM_PRIORITY_2
	.word 14|16|OAM_PRIORITY_2
	.word 15|16|OAM_PRIORITY_2
	.word 14|OAM_PRIORITY_2 | OAM_XFLIP | OAM_YFLIP
	.word 15|OAM_PRIORITY_2 | OAM_XFLIP | OAM_YFLIP
	.word 14|16|OAM_PRIORITY_2 | OAM_XFLIP | OAM_YFLIP
	.word 15|16|OAM_PRIORITY_2 | OAM_XFLIP | OAM_YFLIP
.endproc

.a16
.i16
.export RunEnemyCookieWolf
.proc RunEnemyCookieWolf
	lda ActorVarA,x ; Cookie making state
	beq NotMakingCookiesNow
		dec ActorTimer,x
		beq :+
			jml SharedEnemyCommon 
		:
		jsl FindFreeActorY
		bcc NoBox
			jsl ActorClearY
			lda #Actor::EnemyCookieWolfBox*2
			sta ActorType,y
			lda ActorPX,x
			sta ActorPX,y
			lda ActorPY,x
			sta ActorPY,y
			jsl InitActorY
		NoBox:
		stz ActorVarA,x
		jml SharedEnemyCommon
NotMakingCookiesNow:

	lda framecount
	and #63
	bne DontMakeCookies
	jsl RandomByte
	and #3
	bne DontMakeCookies
		; Are there too many cookies already?
		phx
		ldy #0
		ldx #ActorStart
	:	lda ActorType,x
		cmp #Actor::EnemyCookie*2
		bne :+
			iny
		:
		txa
		add #ActorStructSize
		tax
		cpx ActorIterationLimit
		bne :--
		plx
		cpy #10
		bcs DontMakeCookies
	
		lda #60
		sta ActorVarA,x
		sta ActorTimer,x
		jml SharedEnemyCommon
DontMakeCookies:
	lda #2
	jsr SetActorSpeedAndVelocity

	lda ActorAngle,x
	pha
	jsl ActorMoveAndBumpAgainstWalls
	pla
	cmp ActorAngle,x
	beq :+
		jsl RandomByte
		and #63*2
		sub #32*2
		add ActorAngle,x
		and #510
		sta ActorAngle,x
	:

	jml SharedEnemyCommon
.endproc

.a16
.i16
.export DrawEnemyCookieWolf
.proc DrawEnemyCookieWolf
	lda ActorVarA,x
	bne :+
	lda #0|OAM_PRIORITY_2
	jml DispActor16x16
: 	lda #2|OAM_PRIORITY_2
	jml DispActor16x16
.endproc

.a16
.i16
.export RunEnemyCookieWolfBox
.proc RunEnemyCookieWolfBox
	inc ActorTimer,x
	lda ActorTimer,x
	cmp #60
	bcc No
		lda #Actor::EnemyCookie*2
		sta ActorType,x
		jsl InitActorX
	No:
	rtl
.endproc

.a16
.i16
.export DrawEnemyCookieWolfBox
.proc DrawEnemyCookieWolfBox
	lda #4|OAM_PRIORITY_2
	jml DispActor16x16
.endproc

.a16
.i16
.export RunEnemyTeapot
.proc RunEnemyTeapot
	jml SharedEnemyCommon
.endproc

.a16
.i16
.export DrawEnemyTeapot
.proc DrawEnemyTeapot
	rtl
.endproc

; -------------------------------------
; Particles! These are like actors but they don't have as many
; variables. They work the same way with a Run and Draw routine
; and they can call some of the Actor routines.
.pushseg
.segment "C_ParticleCode"
.a16
.i16
.export DrawPoofParticle
.proc DrawPoofParticle
  lda ParticleTimer,x
  lsr
  and #%110
  add #$60|OAM_PRIORITY_2|(SP_PLAYER1_PALETTE << OAM_COLOR_SHIFT)
  jsl DispParticle16x16
  rts
.endproc

.a16
.i16
.export RunPoofParticle
.proc RunPoofParticle
  inc ParticleTimer,x
  lda ParticleTimer,x
  cmp #4*2
  bne :+
    stz ParticleType,x
  :
  rts
.endproc

.a16
.i16
.export DrawPrizeParticle
.proc DrawPrizeParticle
  lda ParticleTimer,x
  lsr
  lsr
  lsr
  and #3
  add #$66|OAM_PRIORITY_2|OAM_COLOR_2
  jsl DispParticle8x8
  rts
.endproc

.a16
.i16
.export RunPrizeParticle
.proc RunPrizeParticle
  lda ParticleVY,x
  add #2
  sta ParticleVY,x
  add ParticlePY,x
  sta ParticlePY,x

  dec ParticleTimer,x
  bne :+
    stz ParticleType,x
  :
  rts
.endproc

.a16
.i16
.export RunParticleDisappear
.proc RunParticleDisappear
  dec ParticleTimer,x
  bne :+
    stz ParticleType,x
  :
  rts
.endproc

.a16
.i16
.export DrawSmokeParticle
.proc DrawSmokeParticle
  jsl RandomByte
  and #$11
  sta 0
  jsl RandomByte
  xba
  and #OAM_XFLIP|OAM_YFLIP
  ora 0
  ora #$26+OAM_PRIORITY_2
  jsl DispParticle8x8
  rts
.endproc

.popseg
