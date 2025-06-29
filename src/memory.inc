.globalzp retraces
.globalzp framecount
.globalzp BlockFlag
.globalzp BlockTemp

.globalzp OamPtr
.globalzp TempVal
.globalzp TouchTemp
.globalzp LevelDataPointer, LevelHeaderPointer

SCATTER_BUFFER_LENGTH = 128
.global ScatterUpdateLength
.global ScatterUpdateBuffer

MaxDelayedBlockEdits = 17
.global DelayedBlockEditType
.global DelayedBlockEditTime
.global DelayedBlockEditAddr

LEVEL_WIDTH = 16
LEVEL_HEIGHT = 12
LEVEL_BUFFER_SIZE = LEVEL_WIDTH * LEVEL_HEIGHT * 2
.global LevelBuf, BackLevelBuf, LevelBufSolidTile
.global LevelBuf_End
.global LevelActorList

.global OAM
.global OAMHI
OAM_XPOS = OAM+0
OAM_YPOS = OAM+1
OAM_TILE = OAM+2
OAM_ATTR = OAM+3

; ---------------------------------------------------------

ActorCount = 32
ProjectileCount = 8
ParticleCount = 20
PlayerCount = 2

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

; Storage
.global ActorStart
.global ActorEnd
.global ProjectileStart
.global ProjectileEnd
.global ParticleStart
.global ParticleEnd
.global Player1, Player2

; ---------------------------------------------------------

.enum PlayerProjectileType
  Bullet
.endenum

; ---------------------------------------------------------

.globalzp ActorIterationLimit
.globalzp ParticleIterationLimit
.global LastNonEmpty

.global NeedLevelReload
.global NeedLevelRerender

.global LevelZeroWhenLoad_Start
.global LevelZeroWhenLoad_End

.global LevelBackgroundColor
.global LevelBackgroundId
.globalzp LevelActorPointer
.global LevelFadeIn

.globalzp random1
.globalzp random2
.globalzp HDMASTART_Mirror, CGWSEL_Mirror, CGADSUB_Mirror

.global LevelActorBuffer

.global CursorX
.global CursorY
.global AutoRepeatTimer

.global SpriteXYOffset
.global SpriteTileBase

.global DecompressBuffer, Player1CharacterGraphics, Player2CharacterGraphics

.global RedKeys, GreenKeys, BlueKeys, YellowKeys

ACTOR_TILESET_SLOT_COUNT = 8
.global ActorTilesetSlots
ACTOR_PALETTE_SLOT_COUNT = 4
.global ActorPaletteSlots

; HDMA variables
.global CloudScrollX, ZeroSource
