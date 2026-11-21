; Indianapolis 500 WHDLoad Slave V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; Chunky view (68040/060, cockpit view): between fast_view_begin and
; view_flush the CPU versions write one byte per pixel (colour index) into
; a 320 x 124 buffer in fast memory instead of the planes; view_flush then
; converts it into the 4 planes of the view rows (c2p). The bytes are the
; planes' bits, so the result is the same picture. G_DRAW_BACK stays the chip
; back buffer: the background builds its plane 2 there first.

chunky_enable:  dc.b 1                  ; 0: the planar CPU versions as before
chunky_on:      dc.b 0                  ; set while the view is drawn as bytes
chunky_frame:   dc.b 0                  ; this frame's view is bytes (until view_flush)
        even
chunky_base:    dc.l 0                  ; view row 0, x 0
p2c_base:       dc.l 0                  ; p2ctab in ExpMem
ctab:           ds.b 16                 ; colour of each pixel of a word
ptab:           ds.b 16
mtab:           ds.b 16                 ; c_mask_blit: colours of a word
mb_base:        dc.l 0                  ; mask blit cache (MB_OFF)
mb_next:        dc.w 0                  ; entry replaced next
        ifd INTERP
c2p_t2:         dc.l 0                  ; c2p table, entry of pixels 0, 0
        endif

; D0-D3 = plane words 0-3, A0 = 16 bytes: the colour index of each pixel,
; leftmost first. D0-D3 are lost. Per 8 pixels the p2c rows of the four
; plane bytes (one byte 0 or 1 per pixel), each doubled before the next.
ctable: movem.l d4-d6/a0-a1,-(sp)
        movea.l p2c_base(pc),a1
        rol.w #8,d0                     ; pixels 0-7 first
        rol.w #8,d1
        rol.w #8,d2
        rol.w #8,d3
        bsr.s .p8
        rol.w #8,d0
        rol.w #8,d1
        rol.w #8,d2
        rol.w #8,d3
        bsr.s .p8
        movem.l (sp)+,d4-d6/a0-a1
        rts
.p8:    moveq #0,d6
        move.b d3,d6
        lsl.w #3,d6
        move.l (a1,d6.w),d4
        move.l 4(a1,d6.w),d5
        moveq #0,d6
        move.b d2,d6
        lsl.w #3,d6
        add.l d4,d4
        add.l d5,d5
        or.l (a1,d6.w),d4
        or.l 4(a1,d6.w),d5
        moveq #0,d6
        move.b d1,d6
        lsl.w #3,d6
        add.l d4,d4
        add.l d5,d5
        or.l (a1,d6.w),d4
        or.l 4(a1,d6.w),d5
        moveq #0,d6
        move.b d0,d6
        lsl.w #3,d6
        add.l d4,d4
        add.l d5,d5
        or.l (a1,d6.w),d4
        or.l 4(a1,d6.w),d5
        move.l d4,(a0)+
        move.l d5,(a0)+
        rts

; One word: A0 = its first pixel, D4 = mask, A2 = 16 colours. Uses D3, D4.
cword:  cmp.w #$ffff,d4
        bne.s .part
        move.l (a2),(a0)
        move.l 4(a2),4(a0)
        move.l 8(a2),8(a0)
        move.l 12(a2),12(a0)
        rts
.part:  moveq #0,d3
        bra.s .test
.bit:   add.w d4,d4
        bcc.s .next
        move.b (a2,d3.w),(a0,d3.w)
.next:  addq.w #1,d3
.test:  tst.w d4
        bne.s .bit
        rts

; One span as the planar fills: A6 = row, D2 = byte offset of the first word,
; D7 = words - 1, D0/D1 = first and last mask, D5 = mask of the middle words,
; A2 = 16 colours. Uses A0, D3, D4, D7.
cspan:  movea.l a6,a0
        move.w d2,d3
        ext.l d3
        lsl.l #3,d3
        adda.l d3,a0
        tst.w d7
        bgt.s .multi
        move.w d0,d4
        and.w d1,d4
        bra.s cword
.multi: move.w d0,d4
        bsr.s cword
        lea 16(a0),a0
        subq.w #1,d7
        bra.s .in
.mid:   move.w d5,d4
        bsr.s cword
        lea 16(a0),a0
.in:    dbra d7,.mid
        move.w d1,d4
        bra.s cword

; Chunky row of view row D0 into A6.
crow:   movea.l chunky_base(pc),a6
        muls.w #VIEW_W,d0
        adda.l d0,a6
        rts
