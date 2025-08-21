LEVEL_TILE_SIZE = 2

ForegroundBG  = $5c00
BackgroundBG  = $5800
ExtraBG       = $5400 ; Used for layer 3
SpriteCHRBase = $6000
BG1CHRBase    = $0000
BG2CHRBase    = $2000
BG3CHRBase    = $4000

; ------------------------------------
; Background palettes
BG_MISC_PALETTE    = 0
BG_RED_BLUE_YELLOW = 2
BG_GREEN_GRAY_BROWN = 3
BG_ICON_PALETTE    = 7

; Sprite palettes
SP_PLAYER1_PALETTE  = 0
SP_PLAYER2_PALETTE  = 1
SP_CRITTER1_PALETTE = 2
SP_CRITTER2_PALETTE = 3
SP_ENEMY_PALETTE1   = 4
SP_ENEMY_PALETTE2   = 5
SP_ENEMY_PALETTE3   = 6
SP_ICON_PALETTE     = 7

; ------------------------------------
; What tile number points to the first tile in a given tileset, for a given layer

FG_TILE_BASE_COMMON = $000

SP_TILE_BASE_COMMON = $000
SP_TILE_BASE_PLAYER = $080

; ------------------------------------
; Game balance

AMMO_PICKUP_AMOUNT = 7
MAX_AMMO_AMOUNT = 99

HEALTH_PICKUP_AMOUNT = 10
MAX_HEALTH_AMOUNT = 99

SPEEDUP_PICKUP_TIME = 7*60

; ------------------------------------

GAMEPLAY_SPRITE_Y_OFFSET = 8

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
.global GetLevelIndexXY, GetBlockFlag
.global RenderLevelScreen
.global FadeIn, FadeOut, WaitKeysReady, UpdatePlayerKeys
.global MemClear, MemClear7F

.global RunPlayer, DrawPlayer, AdjustCamera
.global BlockFlags

.global ChangeBlock, DelayChangeBlock
.global GetBlockX, GetBlockY, GetBlockXCoord, GetBlockYCoord

.global PlaySoundEffect

.global FindFreeActorX, FindFreeActorY, FindFreeParticleY

.global RandomByte, VelocityLeftOrRight

DirectionKeys = KEY_LEFT|KEY_DOWN|KEY_UP|KEY_RIGHT

.enum ActorInitType
	Nothing
	LookAtPlayer
	LookAtCenter
	RandomAngle
.endenum
