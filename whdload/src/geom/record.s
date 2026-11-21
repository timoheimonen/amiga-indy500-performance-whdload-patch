; Indianapolis 500 WHDLoad Slave V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; Polygon corners: poly_edge records the corners of each polygon
; (vertex_buf records: depth, x', y' at +2, +4, +6). The fills rasterise
; them with sub-pixel precision (hspans), and c_poly_fill gets the plane
; of a solid colour 7, 8, 15 or 5 polygon from the first three
; (tex_class).

TX_YK           equ 15237           ; y' x 15237 / 32768 = y' / 2.1506
TX_KINV         equ 30475           ; y row x 30475 / 32768 = y row / k

; Replaces poly_begin: a new polygon. The camera relative polygons
; (shape_polys_rel: the clouds) get no plane (pe_rel), only their corners.
pe_begin_rel:
        move.l a0,-(sp)
        lea pe_n(pc),a0
        clr.w (a0)
        st pe_rel-pe_n(a0)
        bra.s pe_begin_span
pe_begin:
        move.l a0,-(sp)
        lea pe_n(pc),a0
        clr.w (a0)
        sf pe_rel-pe_n(a0)
pe_begin_span:
        movea.l (sp)+,a0
        move.w #$400,G_SPAN_YMIN
        move.w #$ffff,G_SPAN_YMAX
        rts

; Replaces the first two instructions of poly_edge (edge D7 to D6, records
; at A3; D0 is loaded by them). The top level calls are the polygon's edges
; in order, the last one back to the first corner: pe_vl gets the start of
; each and the end of the last (pe_bad when an edge does not start where
; the one before ended or there are more than PE_MAX). The near plane
; clipper calls poly_edge again from inside (pe_busy, not recorded).
pe_edge:
        move.l a0,-(sp)
        lea pe_busy(pc),a0
        tst.b (a0)
        bne.s .inner
        st (a0)
        lea pe_n(pc),a0
        move.w (a0),d0
        bne.s .more
        move.l a3,pe_base-pe_n(a0)
        sf pe_bad-pe_n(a0)
        move.w d7,pe_vl-pe_n(a0)
        bra.s .put
.more:  cmp.w #PE_MAX,d0
        bcc.s .bad
        cmpa.l pe_base-pe_n(a0),a3
        bne.s .bad
        add.w d0,d0
        cmp.w pe_vl-pe_n(a0,d0.w),d7
        bne.s .bad
.put:   addq.w #1,(a0)
        move.w (a0),d0
        add.w d0,d0
        move.w d6,pe_vl-pe_n(a0,d0.w)
        bra.s .rec
.bad:   st pe_bad-pe_n(a0)
.rec:   movea.l (sp)+,a0
        move.w 8(a3,d7.l),d0
        add.w d0,d0
        jsr F_POLY_EDGE+6
        move.l a0,-(sp)
        lea pe_busy(pc),a0
        sf (a0)
        movea.l (sp)+,a0
        rts
.inner: movea.l (sp)+,a0
        move.w 8(a3,d7.l),d0
        add.w d0,d0
        jmp F_POLY_EDGE+6

; Forget the recorded polygon.
pe_drop:
        move.l a0,-(sp)
        lea pe_n(pc),a0
        clr.w (a0)
        movea.l (sp)+,a0
        rts

; After ctable: tx_mode for the recorded polygon when its colour (ctab) is
; 7, 8, 15 or 5 (tex_on bit 3) and the textures are on, or 5 for a
; material of the scenery (colours 0, 7, 8, 11: tex_face). All registers
; kept.
tex_class:
        movem.l d1/a0,-(sp)
        lea tx_mode(pc),a0
        sf (a0)
        btst #0,tx_ok(pc)
        beq.s .drop
        moveq #15,d1
        and.b ctab(pc),d1
        btst #0,st_plain(pc)            ; a grandstand without its crowd:
        beq.s .cl                       ; seats
        bsr tex_seats
        tst.b (a0)
        bne.s .drop
.cl:    cmp.b #15,d1
        beq.s .go
        cmp.b #5,d1
        beq.s .grs
        cmp.b #11,d1                    ; colours 0, 7, 8, 11: a material
        beq.s .fc
        cmp.b #7,d1
        beq.s .fc
        cmp.b #8,d1
        beq.s .fc
        tst.b d1
        bne.s .drop
.fc:    bsr tex_face
        tst.b (a0)
        bne.s .drop
        btst #0,tex_on(pc)              ; asphalt
        beq.s .drop
        cmp.b #7,d1
        beq.s .go
        cmp.b #8,d1
        beq.s .go
        bra.s .drop
.grs:   btst #3,tex_on(pc)              ; grass
        beq.s .drop
.go:    lea pl_col(pc),a0
        move.b d1,(a0)
        bsr.s poly_plane
.drop:  movem.l (sp)+,d1/a0
        rts

; Vertex \1 (offset word) at A1: \2 = depth, \3 = x', \4 = true y (longs).
VLOAD   macro
        move.w \1,d0
        move.w 2(a1,d0.w),\2
        ext.l \2
        move.w 4(a1,d0.w),\3
        ext.l \3
        move.w 6(a1,d0.w),\4
        muls.w #TX_YK,\4
        asr.l #8,\4
        asr.l #7,\4
        endm

; \1 = |\1| or'ed into D1 (uses D0).
ABSOR   macro
        move.l \1,d0
        bpl.s .p\@
        neg.l d0
.p\@:  or.l d0,d1
        endm

; The plane of the recorded polygon of colour pl_col (7, 8, 15 or 5) and
; its texture mode (tex_plane, tex_panel, tex_wall, grass); nothing for fewer than 3
; corners or a degenerate plane. The game paints the
; road with vertical panels across the track, as high as the camera
; (colour 8, colour 7 in places): their top edge is the horizon.
poly_plane:
        movem.l d0-d7/a0-a2,-(sp)
        lea pe_n(pc),a0
        cmpi.w #2,(a0)
        bcs .out
        tst.b pe_rel-pe_n(a0)
        bne .out
        movea.l pe_base(pc),a1
        lea pl_a(pc),a2
        VLOAD pe_vl(pc),d2,d3,d4        ; A
        move.w d2,(a2)+
        move.w d3,(a2)+
        move.w d4,(a2)
        VLOAD pe_vl+2(pc),d5,d6,d7      ; B
        lea pl_b(pc),a2
        move.w d5,(a2)+
        move.w d6,(a2)+
        move.w d7,(a2)
        sub.l d2,d5                     ; U = B - A
        sub.l d3,d6
        sub.l d4,d7
        VLOAD pe_vl+4(pc),d2,d3,d4      ; C
        lea pl_c(pc),a2
        move.w d2,(a2)+
        move.w d3,(a2)+
        move.w d4,(a2)
        lea pl_a(pc),a2
        move.w (a2)+,d1
        ext.l d1
        sub.l d1,d2                     ; V = C - A
        move.w (a2)+,d1
        ext.l d1
        sub.l d1,d3
        move.w (a2),d1
        ext.l d1
        sub.l d1,d4
        moveq #0,d1                     ; U and V to 15 bits
        ABSOR d2
        ABSOR d3
        ABSOR d4
        ABSOR d5
        ABSOR d6
        ABSOR d7
        moveq #0,d0
.sh:    cmp.l #$3fff,d1
        bls.s .shd
        lsr.l #1,d1
        addq.w #1,d0
        bra.s .sh
.shd:   asr.l d0,d2
        asr.l d0,d3
        asr.l d0,d4
        asr.l d0,d5
        asr.l d0,d6
        asr.l d0,d7
        lea pl_n(pc),a2                 ; N = U x V
        move.w d6,d0
        muls.w d4,d0
        move.w d7,d1
        muls.w d3,d1
        sub.l d1,d0
        move.l d0,(a2)+
        move.w d7,d0
        muls.w d2,d0
        move.w d5,d1
        muls.w d4,d1
        sub.l d1,d0
        move.l d0,(a2)+
        move.w d5,d0
        muls.w d3,d0
        move.w d6,d1
        muls.w d2,d1
        sub.l d1,d0
        move.l d0,(a2)
        movem.l pl_n(pc),d2-d4
        moveq #0,d1                     ; N to 15 bits
        ABSOR d2
        ABSOR d3
        ABSOR d4
        tst.l d1
        beq .out
        moveq #0,d0
.sn:    cmp.l #$3fff,d1
        bls.s .snd
        lsr.l #1,d1
        addq.w #1,d0
        bra.s .sn
.snd:   asr.l d0,d2
        asr.l d0,d3
        asr.l d0,d4
        lea pl_a(pc),a2                 ; N towards the camera: N.A < 0
        move.w (a2)+,d0
        muls.w d2,d0
        move.w (a2)+,d1
        muls.w d3,d1
        add.l d1,d0
        move.w (a2),d1
        muls.w d4,d1
        add.l d1,d0
        ble.s .front
        neg.w d2
        neg.w d3
        neg.w d4
.front: lea .front(pc),a2               ; N for the texture plane (tx_n is
        adda.l #tx_n-.front,a2          ; beyond the reach of a word)
        move.w d2,(a2)+
        move.w d3,(a2)+
        move.w d4,(a2)
        lea tx_up-tx_n-4(a2),a2         ; D6 = N.up
        move.w (a2)+,d6
        muls.w d2,d6
        move.w (a2)+,d0
        muls.w d3,d0
        add.l d0,d6
        move.w (a2),d0
        muls.w d4,d0
        add.l d0,d6
        muls.w d2,d2                    ; |N|
        muls.w d3,d3
        muls.w d4,d4
        add.l d3,d2
        add.l d4,d2
        moveq #0,d1                     ; D1 = sqrt(D2)
        move.l #$40000000,d3
.i1:    cmp.l d2,d3
        bls.s .i2
        lsr.l #2,d3
        bne.s .i1
.i2:    move.l d1,d0
        add.l d3,d0
        lsr.l #1,d1
        cmp.l d0,d2
        bcs.s .i3
        sub.l d0,d2
        add.l d3,d1
.i3:    lsr.l #2,d3
        bne.s .i2
        cmp.w #64,d1
        bcs .out                        ; too small for a direction
        move.b pl_col(pc),d0
        cmp.b #15,d0
        bne.s .road
        move.l d6,d0                    ; wall: within 0.2 of vertical
        divs.w d1,d0
        bpl.s .wp
        neg.w d0
.wp:    cmp.w #3277,d0
        bcc.s .out
        bsr tex_wall
        bra.s .out
.road:  cmp.b #5,d0
        beq.s .grass
        bsr tex_plane
        divs.w d1,d6                    ; cos with world up
        move.w d6,d0
        bpl.s .up
        neg.w d6
.up:    cmp.w #3277,d6
        bcc.s .slope
        bsr tex_panel                   ; vertical (below 0.2)
        bra.s .out
.slope: lea tx_mode(pc),a0
        cmp.w #14746,d6                 ; within 26 degrees of flat: the road
        bcs.s .own                      ; plane (the banked turns are fans
        move.b #2,(a0)                  ; that are not plane)
        bra.s .out
.own:   tst.w d0                        ; steeper, facing up: its own plane
        bmi.s .out
        move.b #1,(a0)
        bra.s .out
.grass: divs.w d1,d6                    ; within 26 degrees of flat: the
        bpl.s .gu                       ; grass plane (world z = 0)
        neg.w d6
.gu:    cmp.w #14746,d6
        bcs.s .out
        lea tx_mode(pc),a0
        move.b #4,(a0)
.out:   movem.l (sp)+,d0-d7/a0-a2
        rts

PE_MAX          equ 16                  ; corners of a polygon recorded
pe_n:           dc.w 0                  ; edges recorded
pe_base:        dc.l 0                  ; vertex_buf (A3)
pe_vl:          ds.w PE_MAX+1           ; record offsets of the corners
pe_busy:        dc.b 0                  ; inside poly_edge
pe_rel:         dc.b 0                  ; camera relative: no plane
pe_bad:         dc.b 0                  ; the edges do not form one polygon
pl_col:         dc.b 0                  ; colour of the polygon
        even
pl_a:           ds.w 3                  ; corner A
pl_b:           ds.w 3                  ; corner B
pl_c:           ds.w 3                  ; corner C
pl_n:           ds.l 3                  ; plane normal
