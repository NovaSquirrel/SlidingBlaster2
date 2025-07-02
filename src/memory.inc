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

.globalzp ParticleType, ParticlePXSub, ParticlePX, ParticlePYSub, ParticlePY, ParticleVXSub, ParticleVX, ParticleVYSub, ParticleVY, ParticleTimer, ParticleVariable
.globalzp ParticleStructSize
.globalzp ActorType, ActorPXSub, ActorPX, ActorPYSub, ActorPY, ActorVXSub, ActorVX, ActorVYSub, ActorVY, ActorTimer, ActorVarA, ActorVarB, ActorVarC, ActorVarD, ActorAngle, ActorWidth, ActorHeight, ActorHealth, ActorSpeed, ActorHitShake, ActorTileBase
.globalzp ActorStructSize
.globalzp ActorProjectileType
.globalzp PlayerType, PlayerPXSub, PlayerPX, PlayerPYSub, PlayerPY, PlayerVXSub, PlayerVX, PlayerVYSub, PlayerVY, PlayerBoostTimer, PlayerAmmo, PlayerCursorPX, PlayerCursorPY, PlayerShootAngle, PlayerMoveAngle, PlayerWidth, PlayerHeight, PlayerHealth, PlayerSpeed, PlayerTileBase, PlayerUsingAMouse, PlayerMouseSensitivity, PlayerControlStyle, PlayerStatusTop, PlayerStatusBottom, PlayerStatusRedraw, PlayerFrameID, PlayerFrameIDLast, PlayerFrameAddress, PlayerNoAmmoMessage, PlayerNoAmmoPity, PlayerKeyDown, PlayerKeyLast, PlayerKeyNew, PlayerCursorVX, PlayerCursorVY
.globalzp PlayerStructSize

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
.global ActorWaveCount
.global ActorWaveNumber

; HDMA variables
.global CloudScrollX, ZeroSource
