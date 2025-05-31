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

; Format for 16-bit X and Y positions and speeds:
; HHHHHHHH LLLLSSSS
; |||||||| ||||++++ - subpixels
; ++++++++ ++++------ actual pixels

.include "memory.inc"

.segment "ZEROPAGE"
  retraces: .res 2
  framecount: .res 2  ; Only increases every iteration of the main loop

  keydown:  .res 2
  keylast:  .res 2
  keynew:   .res 2

  random1:  .res 2
  random2:  .res 2

  ; These hold the last value written to these registers, allowing you to get what value it was
  HDMASTART_Mirror: .res 1
  CGWSEL_Mirror: .res 1
  CGADSUB_Mirror: .res 1

  LevelBlockPtr: .res 3 ; Pointer to one block or a column of blocks. 00xxxxxxxxyyyyy0
  BlockFlag:     .res 2 ; Contains block class, solid flags, and interaction set
  BlockTemp:     .res 4 ; Temporary bytes for block interaction routines specifically

  PlayerPX:        .res 2 ; \ player X and Y positions
  PlayerPY:        .res 2 ; /

  PlayerVX:        .res 2 ; \
  PlayerVY:        .res 2 ; /

  ; Precomputed hitbox edges to speed up collision detection with the player
  PlayerPXLeft:    .res 2 ; 
  PlayerPXRight:   .res 2 ;
  PlayerPYTop:     .res 2 ; Y position for the top of the player

  ForceControllerBits: .res 2
  ForceControllerTime: .res 1

  PlayerHealth:     .res 1     ; current health, measured in half hearts

  OamPtr:           .res 2 ; Current index into OAM and OAMHI
  TempVal:          .res 4
  TouchTemp:        .res 8

  LevelHeaderPointer: .res 3 ; For starting the same level from a checkpoint, or other purposes
  LevelDataPointer:  .res 3 ; pointer to the actual level data
  LevelActorPointer: .res 3 ; actor pointer for this level

  ActorIterationLimit:    .res 2 ; Ending point for RunAllActors
  ParticleIterationLimit: .res 2 ; Ending point for RunAllParticles

.segment "BSS" ; First 8KB of RAM
  ActorType         = 0 ; Actor type ID
  ActorPX           = ActorType+2 ; 12.12
  ActorPY           = ActorPX+3   ; 12.12
  ActorVX           = ActorPY+3   ; 12.12
  ActorVY           = ActorVX+3   ; 12.12
  ActorAngle        = ActorVY+3   ; 0-510, even numbers only
  ActorTimer        = ActorAngle+2
  ActorHealth       = ActorTimer+2
  ActorVarA         = ActorHealth+2
  ActorVarB         = ActorVarA+2
  ActorVarC         = ActorVarB+2
  ActorVarD         = ActorVarC+2
  ActorWidth        = ActorVarD+2
  ActorHeight       = ActorWidth+2
  ActorFlips        = ActorHeight+2 ; OAM attribute bits to toggle; store 0 or OAM_XFLIP or OAM_YFLIP

  ActorSize         = ActorFlips+2
  ActorProjectileType = ActorHealth ; Reuse this since player projectiles don't get damaged

  ActorStart: .res ActorLen*ActorSize
  ActorEnd:
  ProjectileStart: .res ProjectileLen*ActorSize
  ProjectileEnd:

  ; For less important, light entities
  ParticleSize = 7*2
  ParticleStart: .res ParticleLen*ParticleSize
  ParticleEnd:

  ParticleType       = 0
  ParticlePX         = 2
  ParticlePY         = 4
  ParticleVX         = 6
  ParticleVY         = 8
  ParticleTimer      = 10
  ParticleVariable   = 12

  LastNonEmpty:          .res 2 ; For actor iteration

  NeedLevelReload:       .res 1 ; If set, decode LevelNumber again
  NeedLevelRerender:     .res 1 ; If set, rerender the level again
  OAM:   .res 512
  OAMHI: .res 512
  ; OAMHI contains bit 8 of X (the horizontal position) and the size
  ; bit for each sprite.  It's a bit wasteful of memory, as the
  ; 512-byte OAMHI needs to be packed by software into 32 bytes before
  ; being sent to the PPU, but it makes sprite drawing code much
  ; simpler.

  ScrollXLimit: .res 2
  ScrollYLimit: .res 2

  PlayerDrawX: .res 1
  PlayerDrawY: .res 1
  PlayerOAMIndex: .res 2

  ; Mirrors, for effects
  FGScrollXPixels: .res 2
  FGScrollYPixels: .res 2
  BGScrollXPixels: .res 2
  BGScrollYPixels: .res 2

  LevelBackgroundColor:   .res 2 ; Palette entry
  LevelBackgroundId:      .res 1 ; Backgrounds specified in backgrounds.txt

  OldScrollX: .res 2
  OldScrollY: .res 2

  SpriteXYOffset: .res 2

; All of these are cleared in one go at the start of level decompression
LevelZeroWhenLoad_Start:
  ScreenFlags:            .res (16)*(16+1) ; 256*256

  VerticalScrollEnabled:  .res 1 ; Enable vertical scrolling
  LevelFadeIn:            .res 1 ; Timer for fading the level in

  PlayerOnLadder:      .res 1

  PlayerOnSlope:       .res 1 ; Nonzero if the player is on a slope
  PlayerSlopeType:     .res 2 ; Type of slope the player is on, if they are on one

  PlayerCameraTargetY: .res 2 ; Y position to target with the camera

  ; List of tilemap changes to make in vblank (for ChangeBlock)
  ScatterUpdateLength: .res 2
  ScatterUpdateBuffer: .res SCATTER_BUFFER_LENGTH ; Alternates between 2 bytes for a VRAM address, 2 bytes for VRAM data

  ; Delayed ChangeBlock updates
  DelayedBlockEditType: .res MaxDelayedBlockEdits*2 ; Block type to put in
  DelayedBlockEditAddr: .res MaxDelayedBlockEdits*2 ; Address to put the block at
  DelayedBlockEditTime: .res MaxDelayedBlockEdits*2 ; Time left until the change

  PlayerInvincible: .res 1     ; timer for player invincibility

  ; Number of keys
  RedKeys:    .res 1
  GreenKeys:  .res 1
  BlueKeys:   .res 1
  YellowKeys: .res 1
LevelZeroWhenLoad_End:

  CursorX:       .res 2
  CursorY:       .res 2
  AutoRepeatTimer: .res 1

.segment "BSS7E"

.segment "BSS7F"
  LevelBuf:    .res 256*32*2 ; 16KB
  LevelBuf_End:

  DecompressBuffer: .res 8192
