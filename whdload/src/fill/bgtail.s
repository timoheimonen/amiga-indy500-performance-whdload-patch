; Indianapolis 500 WHDLoad Slave V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; Background tail (every CPU). The background (sky and ground) ends with three
; whole view blits: plane 3 = NOT plane 2 and planes 0 and 1 all ones. The CPU
; writes them with long words (planes 0 and 1 while the blitter still builds
; plane 2).

; Replaces the last three blits of the background routine ($C14CC6), reached
; by jmp while the blit that sets the ground rows of plane 2 may still run.
; The original changes only D0-D4.
cpu_background_tail:
        movem.l d5-d7/a0-a2,-(sp)
        movea.l G_DRAW_BACK,a0
        lea VIEW_TOP(a0),a0             ; plane 0
        lea FILL_PLANE(a0),a1           ; plane 1
        moveq #-1,d0
        move.w #VIEW_LONGS/8-1,d7
.ones:  rept 8
        move.l d0,(a0)+
        move.l d0,(a1)+
        endr
        dbra d7,.ones
        lea FILL_PLANE*2-VIEW_LONGS*4(a0),a0    ; plane 2
        lea FILL_PLANE(a0),a1           ; plane 3
        btst #6,$dff002
.idle:  btst #6,$dff002
        bne.s .idle
        move.w #VIEW_LONGS/8-1,d7
.not:   rept 8
        move.l (a0)+,d0
        not.l d0
        move.l d0,(a1)+
        endr
        dbra d7,.not
        lea $dff000,a2                  ; blitter state as the original leaves it
        move.w #$1ff,$40(a2)
        clr.w $42(a2)
        clr.w $64(a2)
        clr.w $66(a2)
        movem.l (sp)+,d5-d7/a0-a2
        rts
