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

  random1:  .res 2
  random2:  .res 2

  ; These hold the last value written to these registers, allowing you to get what value it was
  HDMASTART_Mirror: .res 1
  CGWSEL_Mirror: .res 1
  CGADSUB_Mirror: .res 1

  BlockFlag:     .res 2 ; Contains block class, solid flags, and interaction set
  BlockTemp:     .res 4 ; Temporary bytes for block interaction routines specifically

  OamPtr:           .res 2 ; Current index into OAM and OAMHI
  TempVal:          .res 4
  TouchTemp:        .res 8

  LevelHeaderPointer: .res 3 ; For starting the same level from a checkpoint, or other purposes
  LevelDataPointer:  .res 3 ; pointer to the actual level data
  LevelActorPointer: .res 3 ; actor pointer for this level

  ActorIterationLimit:    .res 2 ; Ending point for RunAllActors
  ParticleIterationLimit: .res 2 ; Ending point for RunAllParticles

.segment "BSS" ; First 8KB of RAM
; ---------------------------------------------------------
; Actor related variables

.struct
	ParticleType     .word
	ParticlePXSub    .res 1   ; 12.12
	ParticlePX       .res 2
	ParticlePXUnused .res 1
	ParticlePYSub    .res 1   ; 12.12
	ParticlePY       .res 2
	ParticlePYUnused .res 1
	ParticleVXSub    .res 1   ; 12.12
	ParticleVX       .res 2
	ParticleVXUnused .res 1
	ParticleVYSub    .res 1   ; 12.12
	ParticleVY       .res 2
	ParticleVYUnused .res 1
	ParticleTimer    .word
	ParticleVariable .word
; The "Unused" position bytes allow doing 32-bit adds instead of having to drop down to an 8-bit accumulator to do 24-bit adds
.endstruct
ParticleStructSize = ParticleVariable+.sizeof(ParticleVariable)

ActorType = ParticleType
ActorPXSub = ParticlePXSub
ActorPX    = ParticlePX
ActorPYSub = ParticlePYSub
ActorPY    = ParticlePY
ActorVXSub = ParticleVXSub
ActorVX    = ParticleVX
ActorVYSub = ParticleVYSub
ActorVY    = ParticleVY
ActorTimer = ParticleTimer
ActorVarA = ParticleVariable
.struct
	.res ParticleStructSize
	ActorVarB   .word
	ActorVarC   .word 
	ActorVarD   .word
	ActorAngle  .word ; 256 angles; always multiplied by 2 here
	ActorWidth  .word
	ActorHeight .word
	ActorHealth .word
	ActorSpeed  .word
	ActorHitShake .word
	ActorTileBase .word ; Base tile number for OAM, including the palette picked. Can also set the OAM_XFLIP or OAM_YFLIP bits
.endstruct
ActorStructSize = ActorTileBase+.sizeof(ActorTileBase)
ActorProjectileType = ActorHealth ; Reuse this since player projectiles don't get damaged

PlayerType       = ActorType
PlayerPXSub      = ActorPXSub
PlayerPX         = ActorPX
PlayerPYSub      = ActorPYSub
PlayerPY         = ActorPY
PlayerVXSub      = ActorVXSub
PlayerVX         = ActorVX
PlayerVYSub      = ActorVYSub
PlayerVY         = ActorVY
PlayerBoostTimer = ActorTimer
PlayerAmmo       = ActorVarA
PlayerCursorPX   = ActorVarB
PlayerCursorPY   = ActorVarC
PlayerShootAngle = ActorVarD
PlayerMoveAngle  = ActorAngle
PlayerWidth      = ActorWidth
PlayerHeight     = ActorHeight
PlayerHealth     = ActorHealth
PlayerSpeed      = ActorSpeed
PlayerTileBase   = ActorTileBase
.struct
	.res ActorStructSize
	PlayerUsingAMouse  .byte     ; 0 for regular controller, 128 for mouse, 129 for hyperkin mouse
	PlayerMouseSensitivity .byte ; Sensitivity the player wants; will cycle between sensitivity options until it lands on this one. Should be shifted left by 4
	PlayerControlStyle .byte     ; 0 for simple, 128 for cursor
	PlayerStatusTop     .res 5*2
	PlayerStatusBottom  .res 5*2
	PlayerStatusRedraw  .word
	PlayerFrameID      .word
	PlayerFrameIDLast  .word
	PlayerFrameAddress .word
	PlayerNoAmmoMessage .word ; If nonzero, show a message saying you have no ammo
	PlayerNoAmmoPity    .word ; Counts up to 240 and then resets
	PlayerKeyDown      .word
	PlayerKeyLast      .word
	PlayerKeyNew       .word
	PlayerCursorVX     .word
	PlayerCursorVY     .word
.endstruct
PlayerStructSize = PlayerCursorVY+.sizeof(PlayerCursorVY)

  Player1: .res PlayerStructSize
  Player2: .res PlayerStructSize
  ActorStart: .res ActorCount*ActorStructSize
  ActorEnd:
  ProjectileStart: .res ProjectileCount*ActorStructSize
  ProjectileEnd:

  ; For less important, light entities
  ParticleStart: .res ParticleCount*ParticleStructSize
  ParticleEnd:

  LastNonEmpty:          .res 2 ; For actor iteration
; ---------------------------------------------------------

  NeedLevelReload:       .res 1 ; If set, decode LevelNumber again
  NeedLevelRerender:     .res 1 ; If set, rerender the level again
  OAM:   .res 512
  OAMHI: .res 512
  ; OAMHI contains bit 8 of X (the horizontal position) and the size
  ; bit for each sprite.  It's a bit wasteful of memory, as the
  ; 512-byte OAMHI needs to be packed by software into 32 bytes before
  ; being sent to the PPU, but it makes sprite drawing code much
  ; simpler.

  PlayerDrawX: .res 1
  PlayerDrawY: .res 1

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
  SpriteTileBase: .res 2

; All of these are cleared in one go at the start of level decompression
LevelZeroWhenLoad_Start:
  LevelFadeIn:            .res 1 ; Timer for fading the level in

  ; List of tilemap changes to make in vblank (for ChangeBlock)
  ScatterUpdateLength: .res 2
  ScatterUpdateBuffer: .res SCATTER_BUFFER_LENGTH ; Alternates between 2 bytes for a VRAM address, 2 bytes for VRAM data

  ; Delayed ChangeBlock updates
  DelayedBlockEditType: .res MaxDelayedBlockEdits*2 ; Block type to put in
  DelayedBlockEditAddr: .res MaxDelayedBlockEdits*2 ; Address to put the block at
  DelayedBlockEditTime: .res MaxDelayedBlockEdits*2 ; Time left until the change

  ; Number of keys
  RedKeys:    .res 1
  GreenKeys:  .res 1
  BlueKeys:   .res 1
  YellowKeys: .res 1


  ; Pathfinding
  DijkstraMapQueueReadIndex: .res 2
  DijkstraMapQueueWriteIndex: .res 2
  DijkstraMapStatus: .res 2

LevelZeroWhenLoad_End:

  ActorTilesetSlots:    .res ACTOR_TILESET_SLOT_COUNT
  ActorPaletteSlots:    .res ACTOR_PALETTE_SLOT_COUNT ; Last one is always the icon palette
  ActorWaveCount:       .res 1
  ActorWaveNumber:      .res 1

  CursorX:       .res 2
  CursorY:       .res 2
  AutoRepeatTimer: .res 1

  ; Current level
  LevelBuf:     .res LEVEL_BUFFER_SIZE
  BackLevelBuf: .res LEVEL_BUFFER_SIZE
  LevelBufSolidTile: .res 2 ; Solid tile that can be pointed to when coordinates are out of bounds
  LevelBuf_End:

  ; Pathfinding
  DijkstraMapQueueBuffer: .res LEVEL_WIDTH * LEVEL_HEIGHT + 1
  WhichDijkstraMap:  .res 2 ; 0 or 256 - which one actors should actually actively look at
  LevelDijkstraMap1: .res 256 ; Only the first 192 bytes are used
  LevelDijkstraMap2: .res 192

.segment "BSS7E"

.segment "BSS7F"
  DecompressBuffer: .res 8192
  Player1CharacterGraphics: .res 8192 ; Room for 16 frames
  Player2CharacterGraphics: .res 8192 ; Room for 16 frames

  CloudScrollX: .res 2
  ZeroSource:   .res 2
