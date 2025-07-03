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
.include "actorenum.s"
.include "blockenum.s"
.include "audio_enum.inc"
.include "tad-audio.inc"
.smart

.import ActorBecomePoof, ActorTurnAround, TwoActorCollision, DispActor8x8, DispActor8x8WithOffset, DispActor16x16, ActorExpire
.import PlayerActorCollision, ActorApplyVelocity, ActorApplyXVelocity, PlayerNegIfLeft
.import DispParticle8x8

.segment "C_ActorData"
CommonTileBase = $40

.a16
.i16
.export RunPlayerProjectile
.proc RunPlayerProjectile
  lda ActorProjectileType,x
  asl
  tay
  lda RunPlayerProjectileTable,y
  pha
  rts
.endproc

RunPlayerProjectileTable:
  .word .loword(RunProjectileBullet-1)

.a16
.i16
.export DrawPlayerProjectile
.proc DrawPlayerProjectile
  lda ActorProjectileType,x
  asl
  tay
  lda DrawPlayerProjectileTable,y
  pha
  rts
.endproc

DrawPlayerProjectileTable:
  .word .loword(DrawProjectileBullet-1)

.a16
.i16
.proc RunProjectileBullet
  jsl ActorApplyVelocity

  .if 0
  inc ActorTimer,x
  lda ActorTimer,x
  cmp #85
  bne :+
    stz ActorType,x
  :
  .endif

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
    lda LevelBuf,y
    cmp #Block::Breakable
    bne :+
      seta8
      ; Play the sound effect
      lda #SFX::brick_break
      jsl PlaySoundEffect
      seta16

      lda #60*10
      sta BlockTemp ; Timer
      lda #Block::Breakable
      jsl DelayChangeBlock

      lda #Block::Empty
      jsl ChangeBlock
    :
    stz ActorType,x
  NoWall:
  rtl
.endproc

.a16
.i16
.proc DrawProjectileBullet
  lda #$1F|OAM_PRIORITY_2|OAM_COLOR_0
  jml DispActor8x8
.endproc

; Check for a collision with a player projectile
; and run the default handler for it
.export ActorGetShot
.proc ActorGetShot
  jsl ActorGetShotTest
  bcc :+
  jsl ActorGotShot
: rtl
.endproc

.a16
.export ActorGetShotTest
.proc ActorGetShotTest
ProjectileIndex = TempVal
ProjectileType  = 0
  ldy #ProjectileStart
Loop:
  lda ActorType,y
  beq NotProjectile  

  jsl TwoActorCollision
  bcc :+
    lda ActorProjectileType,y
    sta ProjectileType
    sty ProjectileIndex
    sec ; Set = Actor was hit by projectile
    rtl
  :

NotProjectile:
  tya
  add #ActorStructSize
  tay
  cpy #ProjectileEnd
  bne Loop

  clc ; Clear = Actor was not hit by projectile
  rtl
.endproc

.proc ActorGotShot
ProjectileIndex = ActorGetShotTest::ProjectileIndex
ProjectileType  = ActorGetShotTest::ProjectileType
  phk
  plb
  lda ProjectileType
  asl
  tay
  lda HitProjectileResponse,y
  pha
  ldy ProjectileIndex
  rts

Damage:
  lda #0
  sta ActorType,y
  seta8
  ; Play the sound effect
  lda #SFX::menu_cursor
  jsl PlaySoundEffect
  seta16

  lda ActorHealth,x
  sub #16
  sta ActorHealth,x
  beq Die
  bcs NoDie
Die:
  jml ActorBecomePoof
NoDie:
  lda #15
  sta ActorHitShake,x
  rtl

HitProjectileResponse:
  .word .loword(Damage-1)
.endproc
ActorGetShotTest_ProjectileIndex = ActorGetShotTest::ProjectileIndex
ActorGetShotTest_ProjectileType = ActorGetShotTest::ProjectileType
.exportzp ActorGetShotTest_ProjectileIndex
.exportzp ActorGetShotTest_ProjectileType
