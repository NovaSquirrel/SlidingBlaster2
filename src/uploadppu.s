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
  ldx #OAMHI
  stx DMAADDR+$00
  lda #1
  sta COPYSTART
  rtl
oam_source:
  .byt $f0
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
  stz SpriteTileBase

KeepOffset:
  ; Calculate the address
  and #255
  ; Multiply by 7 by subtracting the original value from value*8
  pha
  asl
  asl
  asl
  sub 1,s
  tax
  pla

  ; Now access the stuff from GraphicsDirectory:
  ; ppp dd ss - pointer, destination, size

  ; Destination address
  lda f:GraphicsDirectory+3,x
  add SpriteTileBase
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

::DoGraphicUploadWithOffset: ; Alternate entrance for using destination address offsets
  phx
  php
  setaxy16
  bra KeepOffset

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
  stz HDMASTART

  ; Fix the background color
  stz CGADDR
  lda LevelBackgroundColor+0
  sta CGDATA
  lda LevelBackgroundColor+1
  sta CGDATA

  ; DMA for the status bar gradient
  lda #^ColorChangeHDMATable
  sta DMAADDRBANK + $70
  sta HDMAINDBANK + $70
  sta DMAADDRBANK + $60
  lda #^CloudScrollX
  sta HDMAINDBANK + $60

  lda #%11000000
  sta HDMASTART_Mirror

  stz BGSCROLLX
  stz BGSCROLLX
  stz BGSCROLLX + 2
  stz BGSCROLLX + 2
  lda #<-1
  sta BGSCROLLY
  stz BGSCROLLY
  sta BGSCROLLY + 2
  stz BGSCROLLY + 2

  setaxy16
  lda #.loword(ColorChangeHDMATable)
  sta DMAADDR + $70
  lda #(<CGADDR << 8) | DMA_0011 | DMA_FORWARD | DMA_INDIRECT
  sta DMAMODE + $70
  lda #.loword(BG2ScrollXHDMATable)
  sta DMAADDR + $60
  lda #(<(BGSCROLLX+2) << 8) | DMA_00 | DMA_FORWARD | DMA_INDIRECT
  sta DMAMODE + $60

  ; Upload graphics
  lda #GraphicsUpload::CommonBackground
  jsl DoGraphicUpload
  lda #GraphicsUpload::LevelForeground
  jsl DoGraphicUpload

  lda #GraphicsUpload::CityRug
  jsl DoGraphicUpload

  lda #GraphicsUpload::CommonSprites
  jsl DoGraphicUpload

  ; Upload level actor graphics
  ldx #ACTOR_TILESET_SLOT_COUNT-1
UploadActorTilesetLoop:
  lda ActorTilesetSlots,x
  and #255
  cmp #255
  beq :+
  txa ; 00000000 00000ttt
  xba ; 00000ttt 00000000
  asl ; 0000ttt0 00000000
  sta SpriteTileBase

  lda ActorTilesetSlots,x
  jsl DoGraphicUploadWithOffset
: dex
  bpl UploadActorTilesetLoop

  ; Upload palettes
  lda #Palette::Miscellaneous
  ldy #0
  jsl DoPaletteUpload
  lda #Palette::RedBlueYellow
  ldy #2
  jsl DoPaletteUpload
  lda #Palette::GreenGrayBrown
  ldy #3
  jsl DoPaletteUpload
  lda #Palette::Icons
  ldy #7
  jsl DoPaletteUpload

  ; Player palettes
  lda #Palette::PlayerToy2
  ldy #8
  jsl DoPaletteUpload
  lda #Palette::PlayerToy
  ldy #9
  jsl DoPaletteUpload
  ; 10 and 11 are character sprite graphics

  seta8
  ; Upload actor palettes
  lda ActorPaletteSlots+0
  bmi :+
  ldy #12
  jsl DoPaletteUpload
: lda ActorPaletteSlots+1
  bmi :+
  ldy #13
  jsl DoPaletteUpload
: lda ActorPaletteSlots+2
  bmi :+
  ldy #14
  jsl DoPaletteUpload
: lda #Palette::Icons
  ldy #15
  jsl DoPaletteUpload

  ; .------------------------------------.
  ; | Set up PPU registers for level use |
  ; '------------------------------------'
  lda #1
  sta BGMODE       ; mode 1

  lda #(BG1CHRBase>>12)|((BG2CHRBase>>12)<<4)
  sta BGCHRADDR+0
  lda #BG3CHRBase>>12
  sta BGCHRADDR+1

  lda #SpriteCHRBase >> 13 ; Sprites are 8x8 and 16x16
  sta OBSEL

  lda #0 | ((ForegroundBG >> 10)<<2)
  sta NTADDR+0   ; plane 0 nametable, 1 screen

  lda #0 | ((BackgroundBG >> 10)<<2)
  sta NTADDR+1   ; plane 1 nametable, 1 screen

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

  .import SetupAnimatedCharacter
  lda #1
  ldy #0
  jsl SetupAnimatedCharacter
  lda #0
  ldy #1
  jsl SetupAnimatedCharacter
  ; Force the frames to be copied
  lda #255
  sta Player1+PlayerFrameIDLast
  sta Player2+PlayerFrameIDLast

  jml RenderLevelScreen
.endproc

.proc ColorChangeHDMATable
INDEX = $0101
  .byt $80 | 8,  <Top, >Top
  .byt 128,      <Middle, >Middle
  .byt 64,       <Middle, >Middle
  .byt $80 | 24, <Bottom, >Bottom
  .byt 0

Top:
  .word INDEX, RGB8(19, 19,  19)
  .word INDEX, RGB8(12, 241, 255)
  .word INDEX, RGB8(0,  152, 220)
  .word INDEX, RGB8(0,  152, 220)
  .word INDEX, RGB8(0,  152, 220)
  .word INDEX, RGB8(0,  105, 170)
  .word INDEX, RGB8(0,  57,  109)
  .word INDEX, RGB8(19, 19,  19)
Middle:
  .word INDEX, RGB8(255, 255, 255)
Bottom:
  ; TODO: Make this gradient look nicer??
;  .word INDEX, RGB8(19,  19,  19)
  .word INDEX, RGB8(0,   152, 220)
  .word INDEX, RGB8(0,   157, 222)
  .word INDEX, RGB8(1,   163, 224)
  .word INDEX, RGB8(1,   163, 224)
  .word INDEX, RGB8(2,   169, 227)
  .word INDEX, RGB8(3,   175, 229)
  .word INDEX, RGB8(3,   175, 229)
  .word INDEX, RGB8(4,   181, 231)
;  .word INDEX, RGB8(4,   187, 234)
  .word INDEX, RGB8(5,   193, 236)
  .word INDEX, RGB8(5,   193, 236)
  .word INDEX, RGB8(6,   199, 238)
  .word INDEX, RGB8(7,   205, 241)
  .word INDEX, RGB8(8,   211, 243)
  .word INDEX, RGB8(8,   211, 243)
  .word INDEX, RGB8(8,   217, 245)
  .word INDEX, RGB8(9,   233, 248)
;  .word INDEX, RGB8(10,  229, 250)
;  .word INDEX, RGB8(10,  229, 250)
;  .word INDEX, RGB8(11,  235, 252)
;  .word INDEX, RGB8(12,  241, 255)

  .word INDEX, RGB8(19,  19,  19)

  .word INDEX, RGB8(211, 252, 126)
  .word INDEX, RGB8(153, 230, 95)
  .word INDEX, RGB8(90,  197, 79)
  .word INDEX, RGB8(90,  197, 79)
  .word INDEX, RGB8(51,  152, 75)
  .word INDEX, RGB8(30,  111, 80)
  .word INDEX, RGB8(19,  19,  19)
.endproc
.proc BG2ScrollXHDMATable
  .byt 128
  .addr ZeroSource
  .byt 200-128
  .addr ZeroSource
  .byt 1
  .addr CloudScrollX
  .byt 0
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
