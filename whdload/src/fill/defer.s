; Indianapolis 500 WHDLoad Slave V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; Deferred line wait (CPUs without the CPU lines). Every blit of the game is
; waited for at its end, and the next blitter routine writes the registers at
; entry. Between view_setup and the end of the 3D view (frame_loop $C09144)
; line_draw_to returns without waiting for the blit of its last plane, so the
; blitter draws it while the CPU transforms and clips the next line. In that
; window only the lines and the three polygon fills use the blitter and no
; CPU code writes the draw buffer (the background, first in the window, comes
; after a wait), so these four wait before their first register write, and
; the end of the window waits for the blitter.

; Replaces "jsr view_setup" in frame_loop.
defer_begin:
        move.l a0,-(sp)
        lea blit_defer(pc),a0
        st (a0)
        movea.l (sp)+,a0
        jmp F_VIEW_SETUP

; Replaces "btst.b #0,$C093E3.l" after the 3D view (keeps its flags).
defer_end:
        move.l a0,-(sp)
        lea blit_defer(pc),a0
        sf (a0)
        movea.l (sp)+,a0
        bsr.s blit_idle
        btst #0,G_VIEW_FLAGS
        rts

; Replaces the wait after the last plane of line_draw_to.
line_end:
        btst #0,blit_defer(pc)
        beq.s blit_idle
        rts

blit_idle:
        btst #6,$dff002
.wait:  btst #6,$dff002
        bne.s .wait
        rts

; Replace the first blitter register write of line_draw_to and the fills.
sync_line:
        bsr.s blit_idle
        move.w d1,$dff062
        rts
sync_fill:
        bsr.s blit_idle
        move.w #$5ac,$40(a0)
        rts
sync_pattern:
        bsr.s blit_idle
        move.w #$7ac,$40(a0)
        rts

blit_defer:     dc.b 0
        even
