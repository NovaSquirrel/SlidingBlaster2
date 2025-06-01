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

; This file contains code to draw the 16x16 blocks that levels are made up of.
; RenderLevelScreens will draw the whoel screen, and the other code handles updating
; the screen during scrolling.

.include "snes.inc"
.include "global.inc"
.include "actorenum.s"
.smart
.global LevelBuf
.import BlockTopLeft, BlockTopRight, BlockBottomLeft, BlockBottomRight
.import ActorSafeRemoveX

.segment "C_Player"

.a16
.i16
.proc RenderLevelScreen
  ; TODO: Actually render the level
  rtl
.endproc
