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

  ; Set up faster access to DMA registers
  lda #DMAMODE
  tcd

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
