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
.include "graphicsenum.s"
.include "paletteenum.s"
.smart
.i16

.segment "CODE"
;;
; Clears 2048 bytes ($1000 words) of video memory to a constant
; value.  This can be one nametable, 128 2bpp tiles, 64 4bpp tiles,
; or 32 8bpp tiles.  Must be called during vertical or forced blank.
; @param X starting address of nametable in VRAM (16-bit)
; @param Y value to write (16-bit)
.proc ppu_clear_nt
  seta16
  sty $0000
  ldy #1024        ; number of bytes to clear
  
  ; Clear low bytes
  seta8
  stz PPUCTRL      ; +1 on PPUDATA low byte write
  lda #$00         ; point at low byte of Y
  jsl doonedma
  
  lda #INC_DATAHI  ; +1 on PPUDATA high byte write
  sta PPUCTRL
  lda #$01         ; point at high byte of Y
doonedma:
  stx PPUADDR
  sta DMAADDR
  ora #<PPUDATA
  sta DMAPPUREG
  lda #DMA_CONST|DMA_LINEAR
  sta DMAMODE
  sty DMALEN
  stz DMAADDRHI
  stz DMAADDRBANK
  lda #$01
  sta COPYSTART
  rtl
.endproc

;;
; Converts high OAM (sizes and X sign bits) to the packed format
; expected by the S-PPU, and clears the next 3 sprites' high OAM
; bits for use with ppu_copy_oam_partial. Skips unused sprites.
.proc ppu_pack_oamhi_partial
  ldx OamPtr
  ldy #3
  seta8
  stz 1 ; Because of the 16-bit "dec 0" later

: cpx #512 ; Don't go past the end of OAM
  bcs Exit
  lda #1   ; High X bit set
  sta OAMHI+1,x
  lda #$f0 ; Y position if offscreen
  sta OAM+1,x
  inx
  inx
  inx
  inx
  dey
  bne :-
Exit:
  stx OamPtr

  ; -----------------------------------
  ; Counter for how many times to do this
  seta16
  txa
  lsr
  lsr
  lsr
  lsr
  sta 0

  setxy16
  ldx #0
  txy
packloop:
  ; Pack four sprites' size+xhi bits from OAMHI
  sep #$20
  lda OAMHI+13,y
  asl a
  asl a
  ora OAMHI+9,y
  asl a
  asl a
  ora OAMHI+5,y
  asl a
  asl a
  ora OAMHI+1,y
  sta OAMHI,x
  rep #$21  ; seta16 + clc for following addition

  ; Move to the next set of 4 OAM entries
  inx
  tya
  adc #16
  tay

  ; Done yet?
  dec 0
  bne packloop

  ; -----------------------------------
  ; Skip over the unused sprites and just
  ; put in high X bits set to 1 instead of
  ; trying to pack them
  seta8
  lda #%01010101
: cpx #32
  beq done
  sta OAMHI,x
  inx
  bra :-
done:
  rtl
.endproc

;;
; Converts high OAM (sizes and X sign bits) to the packed format
; expected by the S-PPU.
.proc ppu_pack_oamhi
  setxy16
  ldx #0
  txy
packloop:
  ; pack four sprites' size+xhi bits from OAMHI
  sep #$20
  lda OAMHI+13,y
  asl a
  asl a
  ora OAMHI+9,y
  asl a
  asl a
  ora OAMHI+5,y
  asl a
  asl a
  ora OAMHI+1,y
  sta OAMHI,x
  rep #$21  ; seta16 + clc for following addition

  ; move to the next set of 4 OAM entries
  inx
  tya
  adc #16
  tay
  
  ; done yet?
  cpx #32  ; 128 sprites divided by 4 sprites per byte
  bcc packloop
  rtl
.endproc

;;
; Moves remaining entries in the CPU's local copy of OAM to
; (-128, 225) to get them offscreen.
; @param X index of first sprite in OAM (0-508)
.proc ppu_clear_oam
  setaxy16
lowoamloop:
  lda #(225 << 8) | <-128
  sta OAM,x
  lda #$0100  ; bit 8: offscreen
  sta OAMHI,x
  inx
  inx
  inx
  inx
  cpx #512  ; 128 sprites times 4 bytes per sprite
  bcc lowoamloop
  rtl
.endproc

; Calculates some of the math ahead of time to use in ppu_copy_oam_partial
.proc prepare_ppu_copy_oam_partial
OamPartialCopy512Sub        = 10
OamPartialCopyDivide16      = 12
OamPartialCopyDivide16Rsb32 = 14
  seta16
  lda #512
  sub OamPtr
  sta OamPartialCopy512Sub
  lda OamPtr
  lsr
  lsr
  lsr
  lsr
  sta OamPartialCopyDivide16
  rsb #32
  sta OamPartialCopyDivide16Rsb32
  rtl
.endproc

;;
; Copies packed OAM data to the S-PPU using DMA channel 0
; and hides unused sprites using DMA channel 1
.proc ppu_copy_oam_partial
OamPartialCopy512Sub        = 10
OamPartialCopyDivide16      = 12
OamPartialCopyDivide16Rsb32 = 14
  .a8
  .i16
  ldx OamPtr                     ; If OAM is actually completely full (somehow),
  cpx #512                       ; then don't use this routine because it'll break
  bcs ppu_copy_oam               ; (because a DMA length of "zero" is actually 64KB)

  ldx #DMAMODE_OAMDATA           ; Actually copy in OAM
  stx DMAMODE+$00
  ldx #DMAMODE_OAMDATA|DMA_CONST ; Copy in a fixed source byte
  stx DMAMODE+$10

  ldx OamPtr                     ; Copy in the used part of the OAM buffer
  stx DMALEN+$00
  ldx OamPartialCopy512Sub
  stx DMALEN+$10

  ldx #OAM
  stx DMAADDR+$00
  ldx #.loword(oam_source)
  stx DMAADDR+$10

  lda #^oam_source
  sta DMAADDRBANK+$00
  sta DMAADDRBANK+$10

  lda #3
  sta COPYSTART
  ; ---------------------------

  ldx OamPartialCopyDivide16
  stx DMALEN+$00
  ldx OamPartialCopyDivide16Rsb32
  stx DMALEN+$10
  ldx #OAMHI
  stx DMAADDR+$00
  ldx #.loword(hi_source)
  stx DMAADDR+$10
  lda #3
  sta COPYSTART
  rtl
oam_source:
  .byt $f0
hi_source:
  .byt %01010101 ; upper bit on all X positions set
.endproc

;;
; Copies packed OAM data to the S-PPU using DMA channel 0.
.proc ppu_copy_oam
  setaxy16
  lda #DMAMODE_OAMDATA
  ldx #OAM
  ldy #544
  ; falls through to ppu_copy
.endproc

;;
; Copies data to the S-PPU using DMA channel 0.
; @param X source address
; @param DBR source bank
; @param Y number of bytes to copy
; @param A 15-8: destination PPU register; 7-0: DMA mode
;        useful constants:
; DMAMODE_PPUDATA, DMAMODE_CGDATA, DMAMODE_OAMDATA
.proc ppu_copy
  php
  setaxy16
  sta DMAMODE
  stx DMAADDR
  sty DMALEN
  seta8
  phb
  pla
  sta DMAADDRBANK
  lda #%00000001
  sta COPYSTART
  plp
  rtl
.endproc

;;
; Uploads a specific graphic asset to VRAM
; @param A graphic number (0-255)
.import GraphicsDirectory
.proc DoGraphicUpload
  phx
  php
  setaxy16
  ; Calculate the address
  and #255
  ; Multiply by 7 by subtracting the original value from value*8
  sta 0
  asl
  asl
  asl
  sub 0
  tax

  ; Now access the stuff from GraphicsDirectory:
  ; ppp dd ss - pointer, destination, size

  ; Destination address
  lda f:GraphicsDirectory+3,x
  sta PPUADDR

  ; Size can indicate that it's compressed
  lda f:GraphicsDirectory+5,x
  bmi Compressed
  sta DMALEN

  ; Upload to VRAM
  lda #DMAMODE_PPUDATA
  sta DMAMODE

  ; Source address
  lda f:GraphicsDirectory+0,x
  sta DMAADDR

  ; Source bank
  seta8
  lda f:GraphicsDirectory+2,x
  sta DMAADDRBANK

  ; Initiate the transfer
  lda #%00000001
  sta COPYSTART

  plp
  plx
  rtl

.a16
.i16
Compressed:
  phy ; This is trashed by the decompress routine

  lda f:GraphicsDirectory+0,x ; Source address
  pha
  lda f:GraphicsDirectory+2,x ; Source bank, don't care about high byte
  plx
  .import LZ4_DecompressToVRAM
  jsl LZ4_DecompressToVRAM

  ply
  plp
  plx
  rtl
.endproc

;;
; Uploads a specific palette asset to CGRAM
; locals: 0, 1
; @param A palette number (0-255)
; @param Y palette to upload to (0-15)
.import PaletteList
.proc DoPaletteUpload
  php
  setaxy16

  ; Calculate the address of the palette data
  and #255
  ; Multiply by 30
  sta 0
  asl
  asl
  asl
  asl
  sub 0
  asl
  add #PaletteList & $ffff
  ; Source address
  sta DMAADDR

  ; Upload to CGRAM
  lda #DMAMODE_CGDATA
  sta DMAMODE

  ; Size
  lda #15*2
  sta DMALEN

  ; Source bank
  seta8
  lda #^PaletteList
  sta DMAADDRBANK

  ; Destination address
  tya
  ; Multiply by 16 and add 1
  asl
  asl
  asl
  sec
  rol
  sta CGADDR

  ; Initiate the transfer
  lda #%00000001
  sta COPYSTART

  plp
  rtl
.endproc

; Upload level graphics and palettes,
; and also set PPU settings correctly for levels
.export UploadLevelGraphics
.proc UploadLevelGraphics
  seta8
  stz HDMASTART_Mirror
  stz HDMASTART

  ; Fix the background color
  stz CGADDR
  lda LevelBackgroundColor+0
  sta CGDATA
  lda LevelBackgroundColor+1
  sta CGDATA

  setaxy16
  ; Upload graphics
  lda #GraphicsUpload::SolidTiles
  jsl DoGraphicUpload

  lda #GraphicsUpload::GreenBrown
  jsl DoGraphicUpload

  lda #GraphicsUpload::YellowBlue
  jsl DoGraphicUpload

  lda #GraphicsUpload::Red
  jsl DoGraphicUpload

  lda #GraphicsUpload::CommonSprites
  jsl DoGraphicUpload

;  lda #GraphicsUpload::Enemy2
;  jsl DoGraphicUpload

  ; Upload palettes
  lda #Palette::GreenBrown
  ldy #0
  jsl DoPaletteUpload

  lda #Palette::YellowBlue
  ldy #1
  jsl DoPaletteUpload

  lda #Palette::Red
  ldy #2
  jsl DoPaletteUpload

  lda #Palette::PlayerToy
  ldy #8
  jsl DoPaletteUpload

  lda #Palette::Enemy1
  ldy #9
  jsl DoPaletteUpload

  lda #Palette::Enemy2
  ldy #10
  jsl DoPaletteUpload

  ; .------------------------------------.
  ; | Set up PPU registers for level use |
  ; '------------------------------------'
  seta8
  lda #1
  sta BGMODE       ; mode 1

  lda #(BG1CHRBase>>12)|((BG2CHRBase>>12)<<4)
  sta BGCHRADDR+0  ; bg plane 0 CHR at $0000, plane 1 CHR at $2000
  lda #BG3CHRBase>>12
  sta BGCHRADDR+1  ; bg plane 2 CHR at $2000

  lda #SpriteCHRBase >> 13
  sta OBSEL      ; sprite CHR at $6000, sprites are 8x8 and 16x16

  lda #1 | ((ForegroundBG >> 10)<<2)
  sta NTADDR+0   ; plane 0 nametable, 2 screens wide

  lda #1 | ((BackgroundBG >> 10)<<2)
  sta NTADDR+1   ; plane 1 nametable, 2 screens wide

  lda #0 | ((ExtraBG >> 10)<<2)
  sta NTADDR+2   ; plane 2 nametable, 1 screen

  stz PPURES

  lda #%00010011  ; enable sprites, plane 0 and 1
  sta BLENDMAIN
  stz BLENDSUB    ; disable subscreen

  lda #VBLANK_NMI|AUTOREAD  ; disable htime/vtime IRQ
  sta PPUNMI

  stz CGWSEL
  stz CGWSEL_Mirror
  stz CGADSUB
  stz CGADSUB_Mirror

  setaxy16
  jml RenderLevelScreen
.endproc

; Write increasing values to VRAM
.export WritePPUIncreasing
.proc WritePPUIncreasing
: sta PPUDATA
  ina
  dex
  bne :-
  rtl
.endproc

; Write the same value to VRAM repeatedly
.export WritePPURepeated
.proc WritePPURepeated
: sta PPUDATA
  dex
  bne :-
  rtl
.endproc

; Skip forward some amount of VRAM words
.export SkipPPUWords
.proc SkipPPUWords
: bit PPUDATARD
  dex
  bne :-
  rtl
.endproc
