.globalzp retraces
.globalzp framecount
.globalzp keydown
.globalzp keylast
.globalzp keynew
.globalzp LevelBlockPtr
.globalzp BlockFlag
.globalzp BlockRealX
.globalzp BlockRealY
.globalzp BlockTemp

.globalzp PlayerPX
.globalzp PlayerPXLeft
.globalzp PlayerPXRight
.globalzp PlayerPY
.globalzp PlayerPYTop
.globalzp PlayerVX
.globalzp PlayerVY
.globalzp PlayerHealth
.global PlayerInvincible
.globalzp OamPtr
.globalzp TempVal
.globalzp TouchTemp
.globalzp LevelDataPointer, LevelHeaderPointer
.globalzp ForceControllerBits
.globalzp ForceControllerTime

.global PlayerDrawX
.global PlayerDrawY
.global PlayerOAMIndex

SCATTER_BUFFER_LENGTH = 128
.global ScatterUpdateLength
.global ScatterUpdateBuffer

MaxDelayedBlockEdits = 15
.global DelayedBlockEditType
.global DelayedBlockEditTime
.global DelayedBlockEditAddr

.global LevelBuf
.global LevelBuf_End
.global LevelActorList

.global OAM
.global OAMHI
OAM_XPOS = OAM+0
OAM_YPOS = OAM+1
OAM_TILE = OAM+2
OAM_ATTR = OAM+3

ActorLen = 32
ProjectileLen = 8
.global ActorStart
.globalzp ActorSize
.global ActorEnd
.globalzp ActorType
.globalzp ActorPX
.globalzp ActorPY
.globalzp ActorVX
.globalzp ActorVY
.globalzp ActorVarA
.globalzp ActorVarB
.globalzp ActorVarC
.globalzp ActorDirection
.globalzp ActorIndexInLevel
.globalzp ActorTimer
.globalzp ActorOnGround
.globalzp ActorOnScreen
.globalzp ActorProjectileType
.globalzp ActorWidth
.globalzp ActorHeight
.global ProjectileStart
.global ProjectileEnd

.enum PlayerProjectileType
  Bullet
.endenum

ParticleLen = 20
.global ParticleStart
.globalzp ParticleSize
.global ParticleEnd
.globalzp ParticleType
.globalzp ParticlePX
.globalzp ParticlePY
.globalzp ParticleVX
.globalzp ParticleVY
.globalzp ParticleTimer
.globalzp ParticleVariable

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

.global DecompressBuffer

.global RedKeys, GreenKeys, BlueKeys, YellowKeys
