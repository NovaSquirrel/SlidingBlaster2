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
.smart

.segment "C_ActorData"

.import DispActor16x16, DispActor8x8, DispActor8x8WithOffset, DispParticle8x8, DispParticle16x16
.import ActorWalk, ActorWalkOnPlatform, ActorFall, ActorGravity, ActorApplyXVelocity
.import ActorAutoBump, ActorLookAtPlayer, ActorTurnAround
.import PlayerActorCollision, PlayerActorCollisionHurt
.import FindFreeProjectileY, ActorApplyVelocity
.import ActorNegIfLeft
.import ActorTryUpInteraction, ActorTryDownInteraction
.import ActorCopyPosXY, InitActorY, ActorClearY
.import SharedEnemyCommon, ActorSafeRemoveX

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
