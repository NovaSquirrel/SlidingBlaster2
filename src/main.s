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
.include "audio_enum.inc"
.include "tad-audio.inc"
.smart
.export main, nmi_handler
.import RunAllActors, DrawPlayer, DrawStatusSprites
.import StartLevel, ResumeLevelFromCheckpoint

.segment "CODE"
;;
; Minimalist NMI handler that only acknowledges NMI and signals
; to the main thread that NMI has occurred.
.proc nmi_handler
  ; Because the INC and BIT instructions can't use 24-bit (f:)
  ; addresses, set the data bank to one that can access low RAM
  ; ($0000-$1FFF) and the PPU ($2100-$213F) with a 16-bit address.
  ; Only banks $00-$3F and $80-$BF can do this, not $40-$7D or
  ; $C0-$FF.  ($7E can access low RAM but not the PPU.)  But in a
  ; LoROM program no larger than 16 Mbit, the CODE segment is in a
  ; bank that can, so copy the data bank to the program bank.
  phb
  phk
  plb

  seta16
  inc a:retraces   ; Increase NMI count to notify main thread
  seta8
  bit a:NMISTATUS  ; Acknowledge NMI

  plb
  rti
.endproc


.segment "CODE"
; init.s sends us here
.proc main
  seta8
  setxy16
  phk
  plb

  ; Clear the first 512 of RAM bytes manually with a loop.
  ; This avoids the memory clear overwriting the return address on the stack!
  ldx #512-1
: stz 0, x
  dex
  bpl :-

  ; Clear the rest of the RAM
  ldx #512
  ldy #$10000 - 512
  jsl MemClear
  ldx #0
  txy ; 0 = 64KB
  jsl MemClear7F
  .a8
  jsl DetectMice

  ; In the same way that the CPU of the Commodore 64 computer can
  ; interact with a floppy disk only through the CPU in the 1541 disk
  ; drive, the main CPU of the Super NES can interact with the audio
  ; hardware only through the sound CPU.  When the system turns on,
  ; the sound CPU is running the IPL (initial program load), which is
  ; designed to receive data from the main CPU through communication
  ; ports at $2140-$2143.  Load a program and start it running.
  seta8
  setxy16
  phk
  plb

  jsl Tad_Init

;  lda #Song::gimo_297
;  jsr Tad_LoadSong

  seta8
  ; Clear palette
  stz CGADDR
  ldx #256
: stz CGDATA ; Write twice
  stz CGDATA
  dex
  bne :-

  ; Clear VRAM too
  seta16
  stz PPUADDR
  ldx #$8000 ; 32K words
: stz PPUDATA
  dex
  bne :-

  setaxy16

  ; Initialize random generator
  lda #42069
  sta random1
  dec
  sta random2

  .import ShowMainMenu
  jml ShowMainMenu

.endproc

.export StartNewGame
.proc StartNewGame
  setaxy16
  ldx #$1ff
  txs ; Reset the stack pointer so no cleanup is needed

  lda #0
 .import StartLevel
::ReloadLevel:
  jml StartLevel
.endproc

.export GameMainLoop
.proc GameMainLoop
  phk
  plb
  stz framecount
forever:

  ; Communicate with the audio driver
  seta8
  setxy16
  phk ; Make sure that DB can access RAM and registers
  plb
  jsl Tad_Process

  seta16
  inc framecount

  ; Update keys
  jsl UpdatePlayerKeys

;  lda keynew
;  and #KEY_START
;  beq :+
;    ; TODO: Insert some sort of pause screen here!
;  :

  seta16
  lda NeedLevelRerender
  lsr
  bcc :+
    jsl RenderLevelScreen
    seta8
    stz NeedLevelRerender
    seta16
  :

  ; Handle delayed block changes
  ldx #(MaxDelayedBlockEdits-1)*2
DelayedBlockLoop:
  ; Count down the timer, if there is a timer
  lda DelayedBlockEditTime,x
  beq @NoBlock
    dec DelayedBlockEditTime,x
    bne @NoBlock
    ; Hit zero? Make the change
    lda DelayedBlockEditAddr,x
    tay
    lda DelayedBlockEditType,x
    jsl ChangeBlock
  @NoBlock:
  dex
  dex
  bpl DelayedBlockLoop

  stz OamPtr

  jsl DrawStatusSprites

  lda Player1+PlayerActive
  beq :+
    ldx #Player1
    jsl RunPlayer
    ldx #Player1
    jsl DrawPlayer
  :

  lda Player2+PlayerActive
  beq :+
    ldx #Player2
    jsl RunPlayer
    ldx #Player2
    jsl DrawPlayer
  :

  jsl RunAllActors

  setaxy16

  .import UpdateDijkstraMaps
  jsl UpdateDijkstraMaps


  lda Player1+PlayerKeyNew
  and #KEY_SELECT
  bne NextLevel

  lda ActorWaveNextTimer
  cmp #60
  bcc NotNextWave
    stz ActorWaveNextTimer
    inc ActorWaveNumber
    lda ActorWaveNumber
    cmp ActorWaveCount
    bcc NotNextLevel
  NextLevel:
      seta8
      lda #$0e
      sta 0
    : jsl WaitVblank
      lda 0
      sta PPUBRIGHT
      dec 0
      bpl :-
      lda #FORCEBLANK
      sta PPUBRIGHT
      seta16

      lda LevelNumber
      ina
      jmp ReloadLevel
    NotNextLevel:

    .import UpdateWaveNumber, SpawnLevelActors
    jsl SpawnLevelActors

    jsl UpdateWaveNumber

    .import ApplyHealthPickup
    lda Player1+PlayerActive
    beq :+
      ldy #Player1
      jsl ApplyHealthPickup
    :
    lda Player2+PlayerActive
    beq :+
	  ldy #Player2
      jsl ApplyHealthPickup
    :

  NotNextWave:

  ; Include code for handling the vblank
  ; and updating PPU memory.
  .include "vblank.s"

  seta8
  ; Turn on rendering
  lda LevelFadeIn
  sta PPUBRIGHT
  cmp #$0f
  beq :+
    inc LevelFadeIn
  :
  lda HDMASTART_Mirror
  sta HDMASTART

  ; Wait for control reading to finish
  lda #$01
padwait:
  bit VBLSTATUS
  bne padwait

  seta16
  lda framecount
  lsr
  lsr
  lsr
  lsr
  lsr
  lsr
  sta f:CloudScrollX

  ; Clean up now that the code that needs to happen in vblank is over
  stz ScatterUpdateLength
  stz Player1+PlayerFrameAddress
  stz Player2+PlayerFrameAddress

  ; Go on with game logic again
  jmp forever
.endproc

; Auto read is off at this point
; Detects which controllers the user has plugged in; probably overly cautious with timing
.a8
.i16
.proc DetectMice
  ; Try changing the sensitivity, in case that's required to initialize the mouse somehow
  lda #1
  sta $4016
  lda $4016
  lda $4017
  stz $4016

  ; Check each controller
  ldx #Player1
  ldy #0
  jsr CheckPlayer
  ldx #Player2
  ldy #1
  jsr CheckPlayer

  rtl

CheckPlayer:
  stz PlayerUsingAMouse,x
  stz PlayerControlStyle,x
  lda #2 << 4
  sta PlayerMouseSensitivity,x

  jsr ResetController
  jsr ReadByteSlowly
  jsr ReadByteSlowly
  and #$F
  cmp #$1
  bne @NotMouse
  lda #128
  sta PlayerControlStyle,x
  sta PlayerUsingAMouse,x

  ; Read and discard X and Y movement
  jsr ReadByteSlowly
  jsr ReadByteSlowly

  ; Official mouse has all 1s after the first 32 bits
  ; Hyperkin mouse has a single 1 and then all 0s after the first 32 bits
  jsr ReadByteSlowly
  cmp #$80
  bne @OfficialMouse
  inc PlayerUsingAMouse,x ; Mark it as potentially Hyperkin
@OfficialMouse:
@NotMouse:
  rts

ResetController:
  lda #1
  sta $4016
  jsr WasteTime
  lsr
  sta $4016
  jsr WasteTime
  rts

ReadByteSlowly:
  lda #1
  sta 0
: lda $4016,y
  lsr
  rol 0
  jsr WasteTime
  bcc :-
  lda 0
  jsr WasteTime
  jsr WasteTime
WasteTime:
  jsr :+
: rts
.endproc
