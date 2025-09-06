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
.include "tad-audio.inc"
.smart
.segment "CODE"

.a16
.i16
.export ShowMainMenu
.proc ShowMainMenu
	setxy16
	seta8
	stz HDMASTART
	ldx #$1ff
	txs ; Reset the stack pointer so no cleanup is needed
	
	; Fix the background color
	stz CGADDR
	lda #<RGB8($92, $ea, $fd)
	sta CGDATA
	lda #>RGB8($92, $ea, $fd)
	sta CGDATA
	
	stz BGSCROLLX
	stz BGSCROLLX
	lda #<-1
	sta BGSCROLLY
	stz BGSCROLLY
	
	setaxy16

	; Upload graphics
	lda #GraphicsUpload::MainMenu
	jsl DoGraphicUpload
	lda #GraphicsUpload::CommonSprites
	jsl DoGraphicUpload

	; Upload palettes
	lda #Palette::Icons
	ldy #0
	jsl DoPaletteUpload
	lda #Palette::PlayerToy2
	ldy #8
	jsl DoPaletteUpload
	lda #Palette::PlayerToy
	ldy #9
	jsl DoPaletteUpload

	; .------------------------------------.
	; | Set up PPU registers for level use |
	; '------------------------------------'
	seta8
	lda #1
	sta BGMODE ; mode 1
	
	lda #(BG1CHRBase>>12)|((BG2CHRBase>>12)<<4)
	sta BGCHRADDR+0
	
	lda #SpriteCHRBase >> 13 ; Sprites are 8x8 and 16x16
	sta OBSEL
	
	lda #0 | ((ForegroundBG >> 10)<<2)
	sta NTADDR+0   ; plane 0 nametable, 1 screen
	
	stz PPURES
	
	lda #%00010001  ; enable plane 0 and sprites
	sta BLENDMAIN
	stz BLENDSUB    ; disable subscreen
	
	lda #VBLANK_NMI|AUTOREAD  ; disable htime/vtime IRQ
	sta PPUNMI
	
	stz CGWSEL
	stz CGWSEL_Mirror
	stz CGADSUB
	stz CGADSUB_Mirror

	ldx #ForegroundBG
	ldy #' '
	jsl ppu_clear_nt ; Leaves accumulator 8-bit
	setaxy16

	; -------------------------------------------------------------------------
	; - Set up the screen
	phk
	plb

	; Add borders
	lda #ForegroundBG
	jsr TopBottomBorder
	lda #ForegroundBG + 32*26
	jsr TopBottomBorder
	seta8
	lda #VRAM_DOWN | INC_DATAHI
	sta PPUCTRL
	seta16
	lda #ForegroundBG + 64
	jsr LeftRightBorder
	lda #ForegroundBG + 30 + 64
	jsr LeftRightBorder
	seta8
	lda #INC_DATAHI
	sta PPUCTRL
	seta16

	; Add text
	ldx #.loword(TopString)
	ldy #ForegroundBG + (3) + (3*32)
	jsr PutString
	ldx #.loword(BottomString)
	ldy #ForegroundBG + (3) + (22*32)
	jsr PutString

	; Controller icons
	seta16
	lda #ForegroundBG + (13) + (7*32)
	sta PPUADDR
	lda Player1+PlayerUsingAMouse
	and #255
	cmp #1
	tdc
	rol
	asl
	adc #8
	sta PPUDATA
	ina
	sta PPUDATA
	pha
	lda #ForegroundBG + (13) + (8*32)
	sta PPUADDR
	pla
	add #15
	sta PPUDATA
	ina
	sta PPUDATA

	lda #ForegroundBG + (13) + (10*32)
	sta PPUADDR
	lda Player2+PlayerUsingAMouse
	and #255
	cmp #1
	tdc
	rol
	asl
	adc #8
	sta PPUDATA
	ina
	sta PPUDATA
	pha
	lda #ForegroundBG + (13) + (11*32)
	sta PPUADDR
	pla
	add #15
	sta PPUDATA
	ina
	sta PPUDATA

	; -------------------------------------------------------------------------
	; - Loop
	stz Player1Critter
	lda #1
	sta Player2Critter

	Bright = TouchTemp
	Player1Cursor = TouchTemp+2
	Player2Cursor = TouchTemp+4
	stz Bright
	stz Player1Cursor
	stz Player2Cursor
Loop:
	jsl WaitVblank
	seta8
	jsl ppu_copy_oam_partial ; needs a8

	lda Bright
	sta PPUBRIGHT
	cmp #15
	bcs :+
		inc Bright
	:

	seta16
	; -------------------------------------------------------------------------
	; - Update background

	; Show player 1 character icon
	lda #ForegroundBG + (16) + (7*32)
	sta PPUADDR
	lda Player1Critter
	asl
	adc #2
	sta PPUDATA
	ina
	sta PPUDATA
	pha
	lda #ForegroundBG + (16) + (8*32)
	sta PPUADDR
	pla
	add #15
	sta PPUDATA
	ina
	sta PPUDATA

	; Show player 2 character icon
	lda #ForegroundBG + (16) + (10*32)
	sta PPUADDR
	lda Player2Critter
	asl
	adc #2
	sta PPUDATA
	ina
	sta PPUDATA
	pha
	lda #ForegroundBG + (16) + (11*32)
	sta PPUADDR
	pla
	add #15
	sta PPUDATA
	ina
	sta PPUDATA

	; -------------------------------------------
	; - Controls

	jsl UpdatePlayerKeys

	ldx #Player1
	jsr RunPlayerForMenu
	ldx #Player2
	jsr RunPlayerForMenu

	; -------------------------------------------
	; - Sprites

	lda #13 | 16 | (SP_PLAYER1_PALETTE << OAM_COLOR_SHIFT) | OAM_PRIORITY_2
    sta OAM_TILE+(4*0)
	lda #13 | 16 | (SP_PLAYER2_PALETTE << OAM_COLOR_SHIFT) | OAM_PRIORITY_2
    sta OAM_TILE+(4*1)
	lda #32 | (SP_PLAYER1_PALETTE << OAM_COLOR_SHIFT) | OAM_PRIORITY_2
    sta OAM_TILE+(4*2)
	lda #32 | (SP_PLAYER1_PALETTE << OAM_COLOR_SHIFT) | OAM_PRIORITY_2
    sta OAM_TILE+(4*3)

	seta8
	lda #4*8
    sta OAM_XPOS + (4*0)
	lda #27*8
    sta OAM_XPOS + (4*1)

	lda Player1Cursor
	asl
	asl
	asl
	asl
	adc #14*8
    sta OAM_YPOS + (4*0)

	lda Player2Cursor
	asl
	asl
	asl
	asl
	adc #14*8
    sta OAM_YPOS + (4*1)
	seta16

    stz OAMHI+1 + (4*0)
    stz OAMHI+1 + (4*1)
	lda #2 ; 16x16 sprites
    stz OAMHI+1 + (4*2)
    stz OAMHI+1 + (4*3)

	lda #16
	sta OamPtr

	; -------------------------------------------
	; - Communicate with the audio driver
	seta8
	setxy16
	phk ; Make sure that DB can access RAM and registers
	plb
	jsl Tad_Process
	seta16

	jsl ppu_pack_oamhi_partial
	.a8 ; (does seta8)
	jsl prepare_ppu_copy_oam_partial
	jmp Loop

.a16
TopBottomBorder:
	sta PPUADDR
	ldx #16
:	lda #14
	sta PPUDATA
	ina
	sta PPUDATA
	dex
	bne :-
	ldx #16
:	lda #14|16
	sta PPUDATA
	ina
	sta PPUDATA
	dex
	bne :-
	rts
LeftRightBorder:
	sta PPUADDR
	pha
	ldx #16
:	lda #14
	sta PPUDATA
	lda #14|16
	sta PPUDATA
	dex
	bne :-
	pla
	ina
	sta PPUADDR
	ldx #16
:	lda #15
	sta PPUDATA
	lda #15|16
	sta PPUDATA
	dex
	bne :-
	rts


.macro line26
	.repeat 26
	.byt 16
	.endrep
	.byt 1
.endmacro

TopString:
	.byt "Sliding Blaster 2 demo",1
	.byt .sprintf("Build day %d", (.time / 86400) - 20241),1
	.byt 1
	line26
	.byt "Player 1:",1,1
	line26
	.byt "Player 2:",1,1
	line26
	.byt 1
	.byt "   Start with 1 player",1,1
	.byt "   Start with 2 players",1,1
	.byt "   Change character",1,1
	.byt "   Mouse sensitivity",1,1
	.byt 0
BottomString:
	line26
	.byt 1
	.byt "https://novasquirrel.com",0
.endproc

.a16
.i16
.proc RunPlayerForMenu
PlayerNumber = TouchTemp+6
	phk
	plb

	tdc
	cpx #.loword(Player2)
	rol
	sta PlayerNumber
	tay

	bit8 PlayerUsingAMouse,x
	jmi MouseMode
ControllerMode:
	lda PlayerKeyNew,x
	and #KEY_UP
	beq @NotUp
		lda ShowMainMenu::Player1Cursor,y
		dec
		bpl :+
			lda #2
		:
		sta ShowMainMenu::Player1Cursor,y
	@NotUp:

	lda PlayerKeyNew,x
	and #KEY_DOWN
	beq @NotDown
		lda ShowMainMenu::Player1Cursor,y
		ina
		cmp #3
		bne :+
			tdc
		:
		sta ShowMainMenu::Player1Cursor,y
	@NotDown:

	lda PlayerKeyNew,x
	and #KEY_A | KEY_B | KEY_START
	beq @NotA
		lda ShowMainMenu::Player1Cursor,y
		phy
		asl
		tay
		lda CommandPointers,y
		ply
		pha
		rts
	@NotA:

	rts
MouseMode:

	rts

; ---------------------------------------------------------
CommandPointers:
	.addr Start1Player-1
	.addr Start2Player-1
	.addr ChangeCharacter-1
	.addr ChangeSensitivity-1

.import StartNewGame
Start1Player:
	jsr FadeOut
	.a8
	lda #1
	sta Player1+PlayerActive
	stz Player2+PlayerActive
	jml StartNewGame
Start2Player:
	jsr FadeOut
	.a8
	lda #1
	sta Player1+PlayerActive
	sta Player2+PlayerActive
	jml StartNewGame
.a16
ChangeCharacter:
	lda Player1Critter,y
	ina
	cmp #3
	bne :+
		tdc
	:
	sta Player1Critter,y
	rts
ChangeSensitivity:
	lda PlayerMouseSensitivity,x
	add #16
	cmp #16*3
	bne :+
		tdc
	:
	sta PlayerMouseSensitivity,x
	rts

FadeOut:
	seta8
	lda #14
	sta 0
:	jsl WaitVblank
	lda 0
	sta PPUBRIGHT
	dec 0
	bne :-
	jsl WaitVblank
	lda #FORCEBLANK
	sta PPUBRIGHT
	rts
.endproc

.a16
.i16
.proc PutString
Temp = 0
	sty PPUADDR
	sty Temp
Loop:
	lda 0,x
	inx
	and #255
	beq Exit
	cmp #1 ; New line
	bne :+
		lda Temp
		adc #32 - 1 ; Carry is set
		sta Temp
		sta PPUADDR
		bra Loop
	:
	sta PPUDATA
	bra Loop
Exit:
	rts
.endproc
