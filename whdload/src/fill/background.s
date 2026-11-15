; Indianapolis 500 WHDLoad Slave V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; Background (sky and ground) with the CPU (installed on a 68040/060): plane 2
; as the blits make it (cleared rows, the band line and fill, set rows), then
; the background tail (fill/bgtail.s, or chunky/c2p.s in the chunky view).

; Replaces the whole background routine on a 68040/060 (D0 = horizon index,
; D1 = bank, negative for the other direction). Plane 2: rows above the band
; cleared, rows from the band end set, and the band as the blits make it: a
; one dot per row line (BLTCON1 $5F or $5B: 320 steps, x major, error 8b-638
; with 8b and 8b-1276, a dot on the first step and after each y step, the
; pixel index running on through the row ends) then a descending fill of the
; band rows (exclusive from the right, or inclusive with fill carry 1 for a
; negative bank). Then the tail below does planes 0, 1 and 3. With the AGA
; view (aga_hw) plane 2 comes from the view matrix instead (bg_line).
cpu_background:
        movem.l d2-d7/a2-a5,-(sp)
        ifd INTERP
        btst #0,aga_hw(pc)
        beq.s .tables
        bsr bg_line                     ; the AGA view: from the matrix
        bra .tail
.tables:
        endif
        add.w d0,d0
        lea G_BG_HORIZON,a0
        move.w (a0,d0.w),d2             ; h
        moveq #0,d7                     ; fill state at each row start
        add.w d1,d1
        bpl.s .pos
        neg.w d1
        moveq #-1,d7                    ; negative bank: inclusive, carry 1
.pos:   lea G_BG_BAND,a0
        move.w (a0,d1.w),d3             ; b
        btst #6,$dff002                 ; a blit may still write the buffer
.idle:  btst #6,$dff002
        bne.s .idle
        movea.l G_DRAW_BACK,a1
        adda.l #VIEW_TOP+2*FILL_PLANE,a1        ; plane 2, view row 0
        move.w d2,d0
        add.w d3,d0
        movea.w d0,a5                   ; h + b: first row below the band
        mulu.w #10,d0
        movea.l a1,a0
        moveq #0,d1
        bra.s .clr_in
.clr:   move.l d1,(a0)+                 ; rows above the band end: 0
.clr_in:
        dbra d0,.clr
        tst.w d3
        beq .below
        ; The line. D4 = pixel index from view row 0, D5 = error.
        move.w d3,d0
        lsl.w #3,d0
        movea.w d0,a2                   ; BMOD = 8b
        sub.w #1276,d0
        movea.w d0,a4                   ; AMOD = 8b - 1276
        move.w a5,d4
        mulu.w #320,d4
        movea.w #-1,a3                  ; x step
        moveq #-16,d0                   ; x 304 of row h+b-1
        tst.w d7
        beq.s .ldir
        movea.w #1,a3
        move.w #-320,d0                 ; x 0 of row h+b-1
.ldir:  add.l d0,d4
        move.w a2,d5
        sub.w #638,d5                   ; error 4 dmin - 2 dmax (negative)
        move.w #319,d6
.wr:    move.l d4,d1                    ; one dot: first pixel of a row
        asr.l #3,d1
        move.w d4,d0
        not.w d0
        bset d0,(a1,d1.l)
.nw:    tst.w d5
        bmi.s .bm
        add.w a4,d5
        add.l a3,d4
        sub.l #320,d4                   ; y step: the next pixel is a dot
        dbra d6,.wr
        bra.s .fill
.bm:    add.w a2,d5
        add.l a3,d4
        dbra d6,.nw
        ; The fill: rows h-b to h+b-1, each from its last word to its first.
.fill:  move.w d2,d0
        sub.w d3,d0
        mulu.w #40,d0
        lea 40(a1,d0.l),a0              ; end of row h-b
        move.w d3,d6
        add.w d6,d6
        subq.w #1,d6                    ; 2b rows
.frow:  move.w d7,d4                    ; fill state
        moveq #19,d5
.fw:    move.w -(a0),d0
        bne.s .fbits
        move.w d4,(a0)
        dbra d5,.fw
        bra.s .fend
.fbits: move.w d0,d1                    ; d1 = parity of bits 0..i at bit i
        move.w d1,d2
        add.w d2,d2
        eor.w d2,d1
        move.w d1,d2
        lsl.w #2,d2
        eor.w d2,d1
        move.w d1,d2
        lsl.w #4,d2
        eor.w d2,d1
        move.w d1,d2
        lsl.w #8,d2
        eor.w d2,d1
        move.w d1,d2
        eor.w d4,d2                     ; exclusive: the state after each bit
        tst.w d7
        beq.s .excl
        or.w d0,d2                      ; inclusive: and the edge bits
.excl:  move.w d2,(a0)
        tst.w d1
        bpl.s .same
        not.w d4                        ; odd number of edges in the word
.same:  dbra d5,.fw
.fend:  lea 80(a0),a0                   ; end of the next row
        dbra d6,.frow
        lea $dff000,a0                  ; registers the line blit leaves
        move.w #$28,$60(a0)
        move.w a2,$62(a0)
        move.w #$8000,$74(a0)
.below: move.w a5,d0                    ; rows from the band end: all ones
        mulu.w #40,d0
        lea (a1,d0.l),a0
        move.w #124,d0
        sub.w a5,d0
        mulu.w #10,d0
        moveq #-1,d1
        bra.s .set_in
.set:   move.l d1,(a0)+
.set_in:
        dbra d0,.set
.tail:  movem.l (sp)+,d2-d7/a2-a5
        btst #0,chunky_on(pc)
        bne c_background_tail
        bra cpu_background_tail
