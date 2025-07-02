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
.import ActorAutoBump, ActorLookAtPlayer, ActorTurnAround
.import PlayerActorCollision, PlayerActorCollisionHurt
.import FindFreeProjectileY, ActorApplyVelocity
.import ActorNegIfLeft
.import ActorTryUpInteraction, ActorTryDownInteraction
.import ActorCopyPosXY, InitActorX, InitActorY, ActorClearY
.import SharedEnemyCommon, ActorSafeRemoveX

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
    lda ActorWidth,x
    lsr
    rsb ActorPX,x
    add #4*16
    sta ParticlePX,y
    lda ActorPY,x
    sub ActorHeight,x
    add #4*16
    sta ParticlePY,y
Exit:
  rtl
.endproc

; -----------------------------------------------

.a16
.i16
.export RunEnemyPortal
.proc RunEnemyPortal
	inc ActorTimer,x
	lda ActorTimer,x
	cmp #120
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

.a16
.i16
.export RunEnemyCookie
.proc RunEnemyCookie
	lda #3
	sta ActorSpeed,x
	jsl CalculateActorVelocityFromAngleAndSpeed
	jsl DivideActorVelocityBy16

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

	rtl
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
	rtl
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
	rtl
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
	rtl
.endproc

.a16
.i16
.export DrawEnemyBadGuy
.proc DrawEnemyBadGuy
	lda #OAM_PRIORITY_2
	ora ActorTileBase,x
	sta ActorTileBase,x

	lda framecount
	lsr
	lsr
	lsr
	and #%110
	tay
	lda Frames,y
.import DispActorMetaLeft
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
.endproc

.a16
.i16
.export RunEnemyPumpkin
.proc RunEnemyPumpkin
	rtl
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
	rtl
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
	rtl
.endproc

.a16
.i16
.export DrawEnemyProSnowman
.proc DrawEnemyProSnowman
	lda #$02|OAM_PRIORITY_2
	jml DispActor16x16
.endproc

.a16
.i16
.export RunEnemyGreenPirate
.proc RunEnemyGreenPirate
	rtl
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
	rtl
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
	rtl
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
	rtl
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
	rtl
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
	rtl
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
	rtl
.endproc

.a16
.i16
.export DrawEnemyHotWheel
.proc DrawEnemyHotWheel
	lda #0|OAM_PRIORITY_2
	jml DispActor16x16
.endproc

.a16
.i16
.export RunEnemyBunnyROM
.proc RunEnemyBunnyROM
	rtl
.endproc

.a16
.i16
.export DrawEnemyBunnyROM
.proc DrawEnemyBunnyROM
	lda #8|OAM_PRIORITY_2
	jml DispActor16x16
.endproc

.a16
.i16
.export RunEnemyRedCannon
.proc RunEnemyRedCannon
	rtl
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
	rtl
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
	rtl
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
	rtl
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
	rtl
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
	rtl
.endproc

.a16
.i16
.export DrawEnemyCookieWolf
.proc DrawEnemyCookieWolf
	lda #0|OAM_PRIORITY_2
	jml DispActor16x16
.endproc

.a16
.i16
.export RunEnemyCookieWolfBox
.proc RunEnemyCookieWolfBox
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
	rtl
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
  add #$4a|OAM_PRIORITY_2|OAM_COLOR_1
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
