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
.import SharedEnemyCommon, ActorSafeRemoveX, ActorGetShotTest, ActorLookAtXY

.import CalculateActorVelocityFromAngleAndSpeed, DivideActorVelocityBy16, ActorMoveAndBumpAgainstWalls

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
  ; Enemy bullets add the X velocity to their position, and hurt the player.
  ; They also disappear after a certain amount of time.
  jsr ActorExpire
  jsl ActorApplyXVelocity  
  jml PlayerActorCollisionHurt
.endproc

.a16
.i16
.export DrawEnemyBullet
.proc DrawEnemyBullet
  lda #$46|OAM_PRIORITY_2|OAM_COLOR_1
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
	lda Player1+PlayerPX
	ldy Player1+PlayerPY
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
	cmp #30 ;120
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
	lda framecount
	and #63
	bne :+
		jsl ActorLookAtPlayer
	:

	lda #1
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

Nothing:
	jml SharedEnemyCommon
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
	jml SharedEnemyCommon
.endproc

.a16
.i16
.export DrawEnemyPumpkin
.proc DrawEnemyPumpkin
	lda #12|OAM_PRIORITY_2
	jml DispActor16x16
.endproc

.a16
.i16
.export RunEnemySnowman
.proc RunEnemySnowman
	lda framecount
	and #15
	bne :+
		jsl ActorLookAtPlayer
		jsr FlipBasedOnAngle
	:

	lda #1
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
.export DrawEnemySnowman
.proc DrawEnemySnowman
	lda #$00|OAM_PRIORITY_2
	jml DispActor16x16
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
	rtl
.endproc

.a16
.i16
.export DrawEnemySnowball
.proc DrawEnemySnowball
	rtl
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
	jml SharedEnemyCommon
.endproc

.a16
.i16
.export DrawEnemyGreenPirate
.proc DrawEnemyGreenPirate
	lda #$02|OAM_PRIORITY_2
	jml DispActor16x16
.endproc

.a16
.i16
.export RunEnemySaladBowl
.proc RunEnemySaladBowl
	jml SharedEnemyCommon
.endproc

.a16
.i16
.export DrawEnemySaladBowl
.proc DrawEnemySaladBowl
	lda #$08|OAM_PRIORITY_2
	jml DispActor16x16
.endproc

.a16
.i16
.export RunEnemySaladProjectile
.proc RunEnemySaladProjectile
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
	rtl
.endproc

.a16
.i16
.export DrawEnemySaladRazor
.proc DrawEnemySaladRazor
	lda #14|OAM_PRIORITY_2
	jml DispActor16x16
.endproc

.a16
.i16
.export RunEnemyBalloon1
.proc RunEnemyBalloon1
	jml SharedEnemyCommon
.endproc

.a16
.i16
.export DrawEnemyBalloon1
.proc DrawEnemyBalloon1
	lda #0|OAM_PRIORITY_2
	jml DispActor16x16
.endproc

.a16
.i16
.export RunEnemyBalloon2
.proc RunEnemyBalloon2
	jml SharedEnemyCommon
.endproc

.a16
.i16
.export DrawEnemyBalloon2
.proc DrawEnemyBalloon2
	lda #4|OAM_PRIORITY_2
	jml DispActor16x16
.endproc

.a16
.i16
.export RunEnemyBalloon3
.proc RunEnemyBalloon3
	jml SharedEnemyCommon
.endproc

.a16
.i16
.export DrawEnemyBalloon3
.proc DrawEnemyBalloon3
	lda #8|OAM_PRIORITY_2
	jml DispActor16x16
.endproc

.a16
.i16
.export RunEnemyBalloon4
.proc RunEnemyBalloon4
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
	jml SharedEnemyCommon
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
	jml SharedEnemyCommon
.endproc

.a16
.i16
.export DrawEnemyDarkPirate
.proc DrawEnemyDarkPirate
	lda #10|OAM_PRIORITY_2
	jml DispActor16x16
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
