; Indianapolis 500 WHDLoad Slave V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; Crowd on the pattern polygons of the grandstands (tex_crowd).

        machine 68020

; c_pattern_fill: a pattern polygon (the grandstands' crowd in a race or
; qualifying; practice draws them plain) whose corners are track vertices
; gets the crowd on its plane instead (tex_on bit 5): u along the plane,
; v = world z, 1 unit per texel as the walls, the brightness of the
; game's pattern (colour 7 light, 8 medium, 0 shade) through cr_lut,
; drawn by tspan in mesh mode 3. cr_on set when so.
tex_crowd:
        movem.l d0-d7/a0-a6,-(sp)
        lea cr_on(pc),a0
        sf (a0)
        btst #5,tex_on(pc)
        beq .no
        btst #0,tx_ok(pc)
        beq .no
        lea pe_n(pc),a0
        cmpi.w #3,(a0)
        bcs .no
        tst.b pe_bad-pe_n(a0)
        bne .no
        tst.b pe_rel-pe_n(a0)
        bne .no
        bsr tw_plane
        bne .no
        movea.l tx_crlut(pc),a2         ; brightness by the pattern
        move.l G_PATTERN_BASE,d0
        cmp.l G_SETPAT_LIGHT,d0
        beq.s .b
        lea 256(a2),a2
        cmp.l G_SETPAT_MID,d0
        beq.s .b
        lea 256(a2),a2
.b:     move.l a2,TS_LUT(a3)
        move.w TS_P(a3),d0              ; footprint: k = mip level, 2 above
        addq.w #1,d0                    ; walls (p - 1); a v texel (world z)
        movem.w tx_wnu(pc),d1-d2        ; is 1 / sin(slope) units along the
        muls.w d1,d1                    ; slope, where f is largest: k one
        muls.w d2,d2                    ; lower per halving of sin (rounded),
        add.l d2,d1                     ; sin^2 x 2^28 = N x^2 + N y^2
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
        move.l tx_crtex(pc),TS_TEX(a3)
        move.b #3,TS_MESH(a3)
        lea cr_on(pc),a0
        st (a0)
.no:    movem.l (sp)+,d0-d7/a0-a6
        rts

        machine 68000
