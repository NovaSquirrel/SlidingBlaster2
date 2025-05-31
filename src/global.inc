LEVEL_TILE_SIZE = 2

ForegroundBG  = $5c00
BackgroundBG  = $5800
ExtraBG       = $5400 ; Used for layer 3
SpriteCHRBase = $6000
BG1CHRBase    = $0000
BG2CHRBase    = $2000
BG3CHRBase    = $4000

PlayerHeight = 28*16
PlayerCollideWidth = 8*16

; ------------------------------------
; Palettes
COMMON_PALETTE = 0
PLAYER_PALETTE = 1

; ------------------------------------

; Include handy macros
.include "macros.s"
.include "memory.inc"

; main.s
.global main, nmi_handler, irq_handler

; uploadppu.s
.global ppu_copy_oam, ppu_pack_oamhi, ppu_clear_oam
.global ppu_copy, ppu_clear_nt, ppu_vsync, WaitVblank
.global prepare_ppu_copy_oam_partial, ppu_copy_oam_partial, ppu_pack_oamhi_partial
.global DoGraphicUpload, DoPaletteUpload
.global WritePPUIncreasing, WritePPURepeated, SkipPPUWords

; Common
.global GetLevelColumnPtr, GetLevelPtrXY, GetBlockFlag
.global RenderLevelScreen
.global FadeIn, FadeOut, WaitKeysReady
.global MemClear, MemClear7F

.global RunPlayer, DrawPlayer, DrawPlayerStatus, AdjustCamera
.global BlockFlags

.global ChangeBlock, DelayChangeBlock
.global GetBlockX, GetBlockY, GetBlockXCoord, GetBlockYCoord

.global PlaySoundEffect

; Flags
.enum ActorFlag
  Priority      = %1100000000000000 ; Priority bits
  Essential     = %1000000000000000 
  Primary       = %0100000000000000
  Secondary     = %0000000000000000
.endenum

.global FindFreeActorX, FindFreeActorY, FindFreeParticleY

.global RandomByte, VelocityLeftOrRight

DirectionKeys = KEY_LEFT|KEY_DOWN|KEY_UP|KEY_RIGHT
