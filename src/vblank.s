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

; This file has the game's vblank handling code,
; and is included by main.s

VblankHandler:
  seta16

  lda Player1+PlayerFrameID
  cmp Player1+PlayerFrameIDLast
  sta Player1+PlayerFrameIDLast
  beq :+
    xba ; * 256
    asl ; * 512
    adc #.loword(Player1CharacterGraphics)
    sta Player1+PlayerFrameAddress
  :
  lda Player2+PlayerFrameID
  cmp Player2+PlayerFrameIDLast
  sta Player2+PlayerFrameIDLast
  beq :+
    xba ; * 256
    asl ; * 512
    adc #.loword(Player2CharacterGraphics)
    sta Player2+PlayerFrameAddress
  :

  ; Pack the second OAM table together into the format the PPU expects
  jsl ppu_pack_oamhi_partial
  .a8 ; (does seta8)

  ; And then prepare the DMA values we'll use in ppu_copy_oam_partial
  ; which we can call once we're in vblank
  jsl prepare_ppu_copy_oam_partial
  seta8
  jsl WaitVblank
  ; AXY size preserved, so still .a8 .i16
  jsl ppu_copy_oam_partial
  setaxy16

  ; Player 1 status
  lda Player1+PlayerStatusRedraw
  beq :+
    lda #ForegroundBG + 25*32 + 4
    sta PPUADDR
    .repeat 5, I
      lda Player1+PlayerStatusTop+2*I
      sta PPUDATA
    .endrep
    lda #ForegroundBG + 26*32 + 4
    sta PPUADDR
    .repeat 5, I
      lda Player1+PlayerStatusBottom+2*I
      sta PPUDATA
    .endrep
    stz Player1+PlayerStatusRedraw
  :

  ; Player 2 status
  lda Player2+PlayerStatusRedraw
  beq :+
    lda #ForegroundBG + 25*32 + 23
    sta PPUADDR
    .repeat 5, I
      lda Player2+PlayerStatusTop+2*I
      sta PPUDATA
    .endrep
    lda #ForegroundBG + 26*32 + 23
    sta PPUADDR
    .repeat 5, I
      lda Player2+PlayerStatusBottom+2*I
      sta PPUDATA
    .endrep
    stz Player2+PlayerStatusRedraw
  :

  ; Set up faster access to DMA registers
  lda #DMAMODE
  tcd
  lda #DMAMODE_PPUDATA
  sta <DMAMODE+$00
  sta <DMAMODE+$10

  ; Player frame uploads
  lda Player1+PlayerFrameAddress
  beq :+
    sta <DMAADDR+$00
    ora #256
    sta <DMAADDR+$10

    lda #32*8 ; 8 tiles for each DMA
    sta <DMALEN+$00
    sta <DMALEN+$10

    lda #SpriteCHRBase + (SP_TILE_BASE_PLAYER) * 32 / 2
    sta PPUADDR
    seta8
    lda #^Player1CharacterGraphics
    sta <DMAADDRBANK+$00
    sta <DMAADDRBANK+$10

    lda #%00000001
    sta COPYSTART

    ; Bottom row -------------------
    ldx #SpriteCHRBase + (SP_TILE_BASE_PLAYER + 16) * 32 / 2
    stx PPUADDR
    lda #%00000010
    sta COPYSTART
    seta16
  :
  lda Player2+PlayerFrameAddress
  beq :+
    sta <DMAADDR+$00
    ora #256
    sta <DMAADDR+$10

    lda #32*8 ; 8 tiles for each DMA
    sta <DMALEN+$00
    sta <DMALEN+$10

    lda #SpriteCHRBase + (SP_TILE_BASE_PLAYER + 8) * 32 / 2
    sta PPUADDR
    seta8
    lda #^Player2CharacterGraphics
    sta <DMAADDRBANK+$00
    sta <DMAADDRBANK+$10

    lda #%00000001
    sta COPYSTART

    ; Bottom row -------------------
    ldx #SpriteCHRBase + (SP_TILE_BASE_PLAYER + 16 + 8) * 32 / 2
    stx PPUADDR
    lda #%00000010
    sta COPYSTART
    seta16
  :

  ; ----------------
  ; Do block updates (or any other tilemap updates that are needed)
  lda ScatterUpdateLength
  beq ScatterBufferEmpty
    sta <DMALEN

    lda #(<PPUADDR << 8) | DMA_0123 | DMA_FORWARD ; Alternate between writing to PPUADDR and PPUDATA
    sta <DMAMODE
    lda #.loword(ScatterUpdateBuffer)
    sta <DMAADDR

    seta8
    lda #^ScatterUpdateBuffer
    sta <DMAADDRBANK
    lda #%00000001
    sta COPYSTART
    seta16
  ScatterBufferEmpty:

  lda #0
  tcd

EndOfVblank:

  ; Will seta8 afterward
