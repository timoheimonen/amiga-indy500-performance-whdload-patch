; Indianapolis 500 WHDLoad Slave V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; Lines into the planes (installed on a 68040/060).
;
; line_draw draws each line with four line mode blits (one per plane). The CPU
; steps the same way as the blitter (error term 4*dmin-2*dmax, minor step when
; the error is not negative) and sets all four planes at each pixel.

; Replaces line_draw: D0/D1 = end point; the start point is G_LINE_X0/Y0. Ends
; in the game's code that makes the end point the next start. The original
; changes D0 and D1 only.
LINE_PIXEL      macro
        move.w \1(a0),d4
        eor.w \2,d4
        and.w d5,d4
        eor.w d4,\1(a0)
        endm
LINE_ALL        macro
        LINE_PIXEL 0,d0
        LINE_PIXEL FILL_PLANE,d1
        LINE_PIXEL 2*FILL_PLANE,d2
        LINE_PIXEL 3*FILL_PLANE,d3
        endm

cpu_line_draw:
        move.l d2,-(sp)                 ; popped by the game's tail
        move.w d0,G_LINE_X1
        move.w d1,G_LINE_Y1
        movem.l d3-d7/a0-a5,-(sp)
        btst #6,$dff002                 ; the last blit may still write
.idle:  btst #6,$dff002
        bne.s .idle
        move.w G_LINE_X0,d2
        move.w G_LINE_Y0,d3
        movea.l G_DRAW_BACK,a0          ; address and mask of the start
        move.w d3,d4
        muls.w #40,d4
        adda.l d4,a0
        lea VIEW_TOP(a0),a0
        move.w d2,d4
        asr.w #4,d4
        add.w d4,d4
        adda.w d4,a0
        movea.l a0,a4
        moveq #15,d4
        and.w d2,d4
        move.w #$8000,d5
        lsr.w d4,d5
        sub.w d2,d0                     ; dx
        sub.w d3,d1                     ; dy
        moveq #0,d6                     ; bit 0 x decrements, 1 y major,
        lea 40.w,a1                     ; 2 y decrements
        tst.w d1
        bpl.s .dy
        neg.w d1
        lea -40.w,a1
        bset #2,d6
.dy:    tst.w d0
        bpl.s .dx
        neg.w d0
        bset #0,d6
.dx:    cmp.w d1,d0
        bpl.s .xmaj
        exg d0,d1
        bset #1,d6
.xmaj:  moveq #1,d7                     ; BLTCON1 as the game's: LINE and
        btst #1,d6                      ; the octant
        bne.s .ycon
        ori.w #$10,d7
        btst #2,d6
        beq.s .xc1
        ori.w #$08,d7
.xc1:   btst #0,d6
        beq.s .con
        ori.w #$04,d7
        bra.s .con
.ycon:  btst #2,d6
        beq.s .yc1
        ori.w #$04,d7
.yc1:   btst #0,d6
        beq.s .con
        ori.w #$08,d7
.con:   move.w d1,d3                    ; d0 = dmax, d1 = dmin
        add.w d3,d3
        add.w d3,d3                     ; 4*dmin
        movea.w d3,a2                   ; error step without a minor step
        move.w d3,d4
        sub.w d0,d4
        sub.w d0,d4                     ; error = 4*dmin - 2*dmax
        move.w d4,d2
        sub.w d0,d2
        sub.w d0,d2                     ; 4*dmin - 4*dmax
        movea.w d2,a3                   ; error step with a minor step
        tst.w d4
        bpl.s .pos
        ori.w #$40,d7                   ; SIGN
.pos:   movem.w d2-d4/d7,-(sp)
        move.w d6,d1
        move.w d4,d6
        move.w d0,d7                    ; pixels - 1
        btst #0,chunky_on(pc)
        bne .chunky
        btst #0,d1
        bne.s .xdec
        btst #1,d1
        bne .yi
        bra.s .xi
.xdec:  btst #1,d1
        bne .yd
        bra .xd

.xi:    movem.w G_COLOUR,d0-d3
.xi_p:  LINE_ALL
        tst.w d6
        bmi.s .xi_s
        add.w a3,d6
        adda.l a1,a0
        bra.s .xi_m
.xi_s:  add.w a2,d6
.xi_m:  ror.w #1,d5
        bcc.s .xi_n
        addq.l #2,a0
.xi_n:  dbra d7,.xi_p
        bra .done
.xd:    movem.w G_COLOUR,d0-d3
.xd_p:  LINE_ALL
        tst.w d6
        bmi.s .xd_s
        add.w a3,d6
        adda.l a1,a0
        bra.s .xd_m
.xd_s:  add.w a2,d6
.xd_m:  rol.w #1,d5
        bcc.s .xd_n
        subq.l #2,a0
.xd_n:  dbra d7,.xd_p
        bra .done
.yi:    movem.w G_COLOUR,d0-d3
.yi_p:  LINE_ALL
        tst.w d6
        bmi.s .yi_s
        add.w a3,d6
        ror.w #1,d5
        bcc.s .yi_m
        addq.l #2,a0
        bra.s .yi_m
.yi_s:  add.w a2,d6
.yi_m:  adda.l a1,a0
        dbra d7,.yi_p
        bra .done
.yd:    movem.w G_COLOUR,d0-d3
.yd_p:  LINE_ALL
        tst.w d6
        bmi.s .yd_s
        add.w a3,d6
        rol.w #1,d5
        bcc.s .yd_m
        subq.l #2,a0
        bra.s .yd_m
.yd_s:  add.w a2,d6
.yd_m:  adda.l a1,a0
        dbra d7,.yd_p
        bra .done
        ; Chunky view: the same pixels, one byte each (colour from ctab by x).
.chunky:
        move.w d1,d5                    ; octant bits
        movem.w G_COLOUR,d0-d3
        lea ctab(pc),a0
        bsr ctable
        ifd INTERP
        btst #0,ls_on(pc)
        beq.s .cgame
        bsr xline                       ; a segment of a line primitive
        bra .cend
.cgame:
        endif
        movea.l chunky_base(pc),a0
        move.w G_LINE_Y0,d0
        muls.w #VIEW_W,d0
        adda.l d0,a0
        move.w G_LINE_X0,d3             ; x
        adda.w d3,a0
        lea ctab(pc),a5
        moveq #1,d4                     ; x step
        btst #0,d5
        beq.s .cxi
        moveq #-1,d4
.cxi:   lea VIEW_W.w,a1                 ; y step
        btst #2,d5
        beq.s .cyi
        lea -VIEW_W.w,a1
.cyi:   btst #1,d5
        bne.s .cy
.cx_p:  moveq #15,d0
        and.w d3,d0
        move.b (a5,d0.w),(a0)
        tst.w d6
        bmi.s .cx_s
        add.w a3,d6
        adda.l a1,a0
        bra.s .cx_m
.cx_s:  add.w a2,d6
.cx_m:  add.w d4,d3
        adda.w d4,a0
        dbra d7,.cx_p
        bra.s .cend
.cy:
.cy_p:  moveq #15,d0
        and.w d3,d0
        move.b (a5,d0.w),(a0)
        tst.w d6
        bmi.s .cy_s
        add.w a3,d6
        add.w d4,d3
        adda.w d4,a0
        bra.s .cy_m
.cy_s:  add.w a2,d6
.cy_m:  adda.l a1,a0
        dbra d7,.cy_p
.cend:
.done:
        ifd INTERP
        lea ls_on(pc),a0
        sf (a0)
        endif
        movem.w (sp)+,d2-d4/d7          ; blitter state as the game's last
        lea $dff000,a1                  ; plane blit leaves it
        move.w d3,$62(a1)
        ext.l d4
        move.l d4,$50(a1)
        moveq #40,d0
        move.w d0,$60(a1)
        move.w d0,$66(a1)
        move.w d2,$64(a1)
        move.w G_LINE_CON0,$40(a1)
        move.w d7,$42(a1)
        move.w #$8000,$74(a1)
        move.w G_COLOUR+6,$72(a1)
        lea 3*FILL_PLANE(a4),a4
        move.l a4,$48(a1)
        move.l a4,$54(a1)
        movem.l (sp)+,d3-d7/a0-a5
        jmp F_LINE_TAIL
