; Indianapolis 500 WHDLoad Slave V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; Spans of the polygon being filled from its recorded corners (hspans) and the
; projection with sub-pixel precision (hproj).

        machine 68020

; The spans of the polygon being filled (pe_vl) for the AGA view into
; hs_l / hs_r for the rows hs_y0-hs_y1 (hscan). A recorded polygon
; (closed, not pe_bad) gets its corners in camera space at 1/16 unit
; (hcorner), is clipped there when a corner is outside the view (near
; plane at depth 1, a cone twice the view) and projected with 1/16 pixel
; and 1/256 row precision; other polygons get the game's spans. Forgets
; the polygon. All registers kept.
hspans:
        movem.l d0-d7/a0-a6,-(sp)
        move.w pe_n(pc),d6
        cmp.w #3,d6
        bcs .game
        tst.b pe_bad(pc)
        bne .game
        lea pe_vl(pc),a1
        add.w d6,d6
        move.w (a1,d6.w),d0
        cmp.w (a1),d0
        bne .game                       ; not closed
        lsr.w #1,d6                     ; corners
        movea.l pe_base(pc),a2
        move.w d6,d7
        subq.w #1,d7
        moveq #0,d5                     ; outcodes of the corners
        lea hp_a(pc),a0
.cr:    move.w (a1)+,d0
        or.w 8(a2,d0.w),d5
        bsr hcorner
        dbra d7,.cr
        lea hp_a(pc),a0
        andi.w #31,d5
        bne.s .clip
        lea hp_p(pc),a3                 ; all in the view: |x'|, |y'| up to
        move.w d6,d7                    ; the depth + 3 units, depth up to
        subq.w #1,d7                    ; 2^19 + 48, so one divide each
.pd:    move.l (a0)+,d2
        move.l (a0)+,d0
        muls.l #VIEW_W*8,d0
        divs.l d2,d0
        add.l #VIEW_W*8,d0
        move.l d0,(a3)+                 ; x x 16
        move.l (a0)+,d0
        muls.l #62*64,d0
        divs.l d2,d0
        asl.l #2,d0
        neg.l d0
        add.l #62*256,d0
        move.l d0,(a3)+                 ; y x 256 (1/64 row steps)
        dbra d7,.pd
        bra.s .scan
.clip:  lea fc_zn(pc),a1
        moveq #16,d0                    ; depth 1
        move.l d0,(a1)
        lea hp_b(pc),a1
        moveq #0,d7                     ; the near plane
        bsr fclip
        exg a0,a1
        lea .cpl(pc),a4
        btst #0,d5
        beq.s .cp
        moveq #%11110,d5                ; a corner behind: all planes
.cp:    move.w (a4)+,d0                 ; a side plane only when a corner
        bmi.s .cpe                      ; is outside the view there (inside
        move.w (a4)+,d7                 ; the view is inside the cone)
        btst d0,d5
        beq.s .cp
        bsr fclip
        exg a0,a1
        bra.s .cp
.cpe:   cmp.w #3,d6
        bcs.s .none
        bsr hproj
.scan:  bsr hscan
        bra.s .out
.none:  lea hs_y0(pc),a0
        move.l #$00010000,(a0)          ; no rows
        bra.s .out
.cpl:   dc.w 1,1,3,2,2,3,4,4,-1         ; outcode bit, fclip plane
.game:  lea hs_y0(pc),a0                ; the game's spans
        move.w G_SPAN_YMIN,d2
        move.w G_SPAN_YMAX,d3
        move.w d2,(a0)+
        move.w d3,(a0)
        cmp.w d3,d2
        bgt.s .out
        lea G_SPAN_LEFT,a1
        lea hs_l(pc),a4
        lea hs_r(pc),a5
.gr:    move.w (a1,d2.w*2),d0
        move.w $1fc(a1,d2.w*2),d1
        cmp.w d1,d0
        ble.s .go
        exg d0,d1
.go:    move.w d0,(a4,d2.w*2)
        move.w d1,(a5,d2.w*2)
        addq.w #1,d2
        cmp.w d3,d2
        ble.s .gr
.out:   bsr pe_drop
        movem.l (sp)+,d0-d7/a0-a6
        rts

; A0 = D6 corners (longs: depth from 16, x' and y' up to twice the depth,
; up to 2^21) -> hp_p: x = 160 + 160 x' / depth and y = 62 - 62 y' /
; depth, x 16 and x 256 (longs, truncated). Uses D0-D3, D7, A0, A2.
hproj:
        lea hp_p(pc),a2
        move.w d6,d7
        subq.w #1,d7
.pc:    move.l (a0)+,d2
        move.l (a0)+,d0
        moveq #VIEW_W/32,d1
        bsr.s .pd
        add.l #VIEW_W*8,d0
        move.l d0,(a2)+
        move.l (a0)+,d0
        moveq #62,d1
        bsr.s .pd
        neg.l d0
        add.l #62*256,d0
        move.l d0,(a2)+
        dbra d7,.pc
        rts
.pd:    move.l d0,d3                    ; D1 x 256 x D0 / D2, truncated
        bpl.s .pa
        neg.l d3
.pa:    cmp.l #$20000,d3
        bcc.s .p2
        asl.l #8,d0                     ; |D0| < 2^17: one divide
        muls.l d1,d0
        divs.l d2,d0
        rts
.p2:    asl.l #8,d0                     ; else two to stay in 32 bits
        divsl.l d2,d3:d0
        muls.l d1,d0
        muls.l d1,d3
        divs.l d2,d3
        add.l d3,d0
        rts

        machine 68000
