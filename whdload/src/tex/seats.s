; Indianapolis 500 WHDLoad Slave V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; Seats on the grandstands the game draws without a crowd (st_ent_a,
; st_ent_b, tex_seats) and their texture (st_paint).

        machine 68020

; The two entries of the game's shape_polys_pattern, called from them
; (jsr, then rts): the game draws the stands with its crowd pattern in a
; race, the first entry's also in qualifying, and plain otherwise with
; the routine of the plain track polygons. As the game, with st_plain set
; while that routine draws them.
st_ent_a:
        tst.w G_RACE_MODE
        beq.s st_run
st_pat: jmp F_PAT_BODY
st_ent_b:
        cmpi.w #2,G_RACE_MODE
        beq.s st_pat
st_run: move.l a0,-(sp)
        lea st_plain(pc),a0
        st (a0)
        movea.l (sp)+,a0
        jsr F_POLYS_TRACK
        move.l a0,-(sp)
        lea st_plain(pc),a0
        sf (a0)
        movea.l (sp)+,a0
        rts

; tex_class with st_plain set: a polygon of colour 7, 8 or 0 whose corners
; are track vertices gets the seats on its plane (tex_on bit 5): u along
; the plane and v = world z as the crowd (tex_crowd), 4 units (a seat)
; per texel, through the table of its colour, drawn by tspan in mesh mode
; 4 (mip levels of st_mips, flat from k ST_KMAX). tx_mode 5 when so.
; All registers kept.
tex_seats:
        movem.l d0-d7/a0-a6,-(sp)
        btst #5,tex_on(pc)
        beq .no
        moveq #15,d7
        and.b ctab(pc),d7
        moveq #ST_LUT,d6                ; the table: colour 7, 8, 0
        cmp.b #7,d7
        beq.s .col
        addq.w #1,d6
        cmp.b #8,d7
        beq.s .col
        addq.w #1,d6
        tst.b d7
        bne .no
.col:   lea pe_n(pc),a0
        cmpi.w #3,(a0)
        bcs .no
        tst.b pe_bad-pe_n(a0)
        bne .no
        tst.b pe_rel-pe_n(a0)
        bne .no
        move.w d6,-(sp)
        bsr tw_plane
        movem.w (sp)+,d6                ; (the flags kept)
        bne .no
        lea tx_psurf(pc),a3
        lea TS_UA(a3),a0                ; 1/4 texel per unit: D . u and
        moveq #5,d1                     ; D . v with their steps, and the
.sc:    move.l (a0),d0                  ; camera's u and v
        asr.l #2,d0
        move.l d0,(a0)+
        dbra d1,.sc
        move.l TS_CXP(a3),d0
        asr.l #2,d0
        move.l d0,TS_CXP(a3)
        move.l TS_CYP(a3),d0
        asr.l #2,d0
        move.l d0,TS_CYP(a3)
        move.w TS_P(a3),d0              ; footprint: k = mip level, 2 above
        addq.w #3,d0                    ; the crowd's (tex_crowd), with its
        movem.w tx_wnu(pc),d1-d2        ; steps for the slope
        muls.w d1,d1
        muls.w d2,d2
        add.l d2,d1
        cmp.l #$8000000,d1
        bcc.s .fp
        addq.w #1,d0
        cmp.l #$2000000,d1
        bcc.s .fp
        addq.w #1,d0
        cmp.l #$800000,d1
        bcc.s .fp
        addq.w #1,d0
.fp:    move.w d0,TS_FP(a3)
        lsl.w #8,d6
        movea.l tx_flut(pc),a0
        adda.w d6,a0
        move.l a0,TS_LUT(a3)
        move.b ST_MEAN(a0),TS_FLAT(a3)
        lea tx_fk(pc),a0
        move.w #ST_KMAX,(a0)
        move.l tx_fstex(pc),TS_TEX(a3)
        move.b #4,TS_MESH(a3)
        lea tx_mode(pc),a0
        move.b #5,(a0)
.no:    movem.l (sp)+,d0-d7/a0-a6
        rts

; The seat texture into R0 at A0 (its middle), 256 x 256 texels of a seat
; each (u along the stand, v up): bays of 16 x 16 with an aisle in columns
; 0-1, a walkway in rows 0-1 and the wall of the next tier in rows 2-3
; with a portal (2 x 2) in every second bay, else rows of benches and of
; the shade under them in turn, a bay 1 lighter or darker than the next
; by a hash. Rows are written in the order of the memory (the pattern
; repeats every 16).
st_paint:
        movem.l d0-d5/a0,-(sp)
        lea -32768(a0),a0
        moveq #0,d1                     ; v
.v:     moveq #0,d0                     ; u
.u:     moveq #15,d2
        and.w d1,d2
        moveq #15,d3
        and.w d0,d3
        moveq #ST_WALK,d4
        cmp.w #2,d2
        bcs.s .put
        cmp.w #4,d2
        bcc.s .seat
        moveq #ST_WALL,d4
        btst #4,d0                      ; a portal: columns 7 and 8
        beq.s .put
        move.w d3,d5
        subq.w #7,d5
        cmp.w #1,d5
        bhi.s .put
        moveq #ST_DARK,d4
        bra.s .put
.seat:  moveq #ST_STAIR,d4
        cmp.w #2,d3
        bcs.s .put
        moveq #ST_BENCH,d4
        btst #0,d1
        beq.s .tone
        moveq #ST_SHADE,d4
.tone:  move.w d0,d5                    ; bay and tier: 5 b + 3 t + (b & t),
        lsr.w #4,d5                     ; its bits 0-1 as -1, 0, 0, 1
        move.w d1,d2
        lsr.w #4,d2
        move.w d5,d3
        and.w d2,d3
        mulu.w #5,d5
        mulu.w #3,d2
        add.w d2,d5
        add.w d3,d5
        andi.w #3,d5
        addq.w #1,d5
        lsr.w #1,d5
        subq.w #1,d5
        add.w d5,d4
.put:   move.b d4,(a0)+
        addq.b #1,d0
        bne.s .u
        addq.b #1,d1
        bne.s .v
        movem.l (sp)+,d0-d5/a0
        rts

; R1-R3 of the seats at A0 (the middle of R0), $10000 apart. A stand is
; mostly seen along its length, where a pixel covers many seats but few
; rows: R1 is the rounded mean of each 2 x 2 texels (the bench rows even
; out), R2 and R3 that of each two blocks along u of the level before
; (4 x 2 and 8 x 2 texels), so the walkways and walls stay 2 texels high.
st_mips:
        movem.l d0-d2/d5-d7/a1-a3,-(sp)
        lea -32768(a0),a1
        movea.l a1,a2
        adda.l #$10000,a2
        moveq #127,d7
.r1:    moveq #127,d6
.c1:    moveq #0,d0
        move.b (a1),d0
        moveq #0,d1
        move.b 1(a1),d1
        add.w d1,d0
        move.b 256(a1),d1
        add.w d1,d0
        move.b 257(a1),d1
        add.w d1,d0
        addq.w #2,d0
        lsr.w #2,d0
        move.b d0,(a2)
        move.b d0,1(a2)
        move.b d0,256(a2)
        move.b d0,257(a2)
        addq.l #2,a1
        addq.l #2,a2
        dbra d6,.c1
        lea 256(a1),a1
        lea 256(a2),a2
        dbra d7,.r1
        moveq #2,d5                     ; block of the level before: A1,
.lv:    movea.l a2,a3                   ; A2 = the next level
.blk:   moveq #0,d0
        move.b (a1),d0
        moveq #0,d1
        move.b (a1,d5.w),d1
        add.w d1,d0
        addq.w #1,d0
        lsr.w #1,d0
        move.w d5,d2
        add.w d2,d2
        adda.w d2,a1
        subq.w #1,d2
.w:     move.b d0,(a2)+
        dbra d2,.w
        cmpa.l a3,a1
        bne.s .blk
        add.w d5,d5
        cmp.w #8,d5
        bne.s .lv
        movem.l (sp)+,d0-d2/d5-d7/a1-a3
        rts

        machine 68000
