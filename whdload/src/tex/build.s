; Indianapolis 500 WHDLoad Slave V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; tex_build: the textures and their tables in ExpMem, built once.

        machine 68020

; Once: the texture (value noise and grain) and the offset tables.
tex_build:
        movem.l d0-d7/a0-a6,-(sp)
        move.l expmem(pc),d0
        add.l #TEX_OFF,d0
        movea.l d0,a6                   ; texture
        add.l #32768,d0
        lea tx_tex(pc),a0
        move.l d0,(a0)                  ; middle: signed word index
        move.l expmem(pc),d0
        add.l #TLUT_OFF,d0
        lea tx_lut(pc),a0
        move.l d0,(a0)
        movea.l d0,a5                   ; lattices, then the tables
        move.l #$2545f491,d7            ; xorshift state
        movea.l a5,a0
        move.w #64+256+4096-1,d6
.lat:   bsr .rnd
        move.b d7,(a0)+
        dbra d6,.lat
        moveq #0,d1                     ; y
.ty:    moveq #0,d0                     ; x
.tx:    lea (a5),a0                     ; 8 x 8, period 32 texels
        moveq #5,d2
        moveq #5,d3
        bsr vnoise
        move.w d4,d5
        add.w d5,d5
        lea 64(a5),a0                   ; 16 x 16, period 16
        moveq #4,d2
        moveq #4,d3
        bsr vnoise
        add.w d4,d5
        sub.w #384,d5
        asr.w #5,d5
        addq.w #8,d5
        bpl.s .b0
        moveq #0,d5
.b0:    cmp.w #15,d5
        bls.s .b1
        moveq #15,d5
.b1:    lea 320(a5),a0                  ; 64 x 64, period 4
        moveq #2,d2
        moveq #2,d3
        bsr vnoise
        sub.w #64,d4
        asr.w #5,d4
        bpl.s .s0
        moveq #0,d4
.s0:    cmp.w #3,d4
        bls.s .s1
        moveq #3,d4
.s1:    lsl.w #4,d4
        or.w d4,d5
        bsr .rnd                        ; grain
        moveq #0,d4
        cmp.b #10,d7
        bcs.s .g3
        cmp.b #46,d7
        bcs.s .g1
        cmp.b #82,d7
        bcc.s .g0
        move.w #$80,d4                  ; +1
        bra.s .g0
.g1:    moveq #$40,d4                   ; -1
        bra.s .g0
.g3:    move.w #$c0,d4                  ; -2
.g0:    or.w d4,d5
        moveq #0,d4
        move.w d1,d4
        lsl.w #8,d4
        move.b d0,d4
        move.b d5,(a6,d4.l)
        addq.w #1,d0
        cmp.w #256,d0
        bne .tx
        addq.w #1,d1
        cmp.w #256,d1
        bne .ty
        move.l expmem(pc),d0            ; the wall: u along it, v = height
        add.l #TWALL_OFF,d0
        movea.l d0,a6
        add.l #32768,d0
        lea tx_wtex(pc),a0
        move.l d0,(a0)
        movea.l a5,a0
        move.w #64+256+512-1,d6
.wlat:  bsr .rnd
        move.b d7,(a0)+
        dbra d6,.wlat
        moveq #0,d1                     ; v
.wy:    moveq #0,d0                     ; u
.wx:    lea (a5),a0                     ; dirt: period 64 x 16
        moveq #6,d2
        moveq #4,d3
        bsr vnoise
        move.w d4,d5
        add.w d5,d5
        lea 64(a5),a0                   ; streaks: period 4 x 64
        moveq #2,d2
        moveq #6,d3
        bsr vnoise
        add.w d4,d5
        sub.w #384,d5
        asr.w #5,d5
        addq.w #8,d5
        bpl.s .w0
        moveq #0,d5
.w0:    cmp.w #15,d5
        bls.s .w1
        moveq #15,d5
.w1:    lea 320(a5),a0                  ; scuffs: period 32 x 4
        moveq #5,d2
        moveq #2,d3
        bsr vnoise
        moveq #0,d3
        cmp.w #60,d4
        bcs.s .w2
        moveq #$10,d3
        cmp.w #95,d4
        bcs.s .w2
        moveq #$20,d3
        cmp.w #210,d4
        bcs.s .w2
        moveq #$30,d3
.w2:    or.w d3,d5
        moveq #31,d3                    ; seams every 32 units
        and.w d0,d3
        bne.s .w3
        or.w #$c0,d5
        bra.s .w4
.w3:    bsr .rnd                        ; grain
        cmp.b #8,d7
        bcc.s .w5
        or.w #$40,d5                    ; -1
        bra.s .w4
.w5:    cmp.b #16,d7
        bcc.s .w4
        or.w #$80,d5                    ; +1
.w4:    moveq #0,d4
        move.w d1,d4
        lsl.w #8,d4
        move.b d0,d4
        move.b d5,(a6,d4.l)
        addq.w #1,d0
        cmp.w #256,d0
        bne .wx
        addq.w #1,d1
        cmp.w #256,d1
        bne .wy
        move.l expmem(pc),d0            ; fence mesh: holes (bit 7),
        add.l #TMESH_OFF,d0             ; diagonal wires every 8 units,
        movea.l d0,a6                   ; posts every 64
        add.l #32768,d0
        lea tx_mtex(pc),a0
        move.l d0,(a0)
        add.l #TFLIST_OFF-TMESH_OFF-32768,d0
        lea tx_flist(pc),a0
        move.l d0,(a0)
        moveq #0,d1                     ; v
.my:    moveq #0,d0                     ; u
.mx:    move.w #$80,d5
        move.w d0,d2
        add.w d1,d2
        andi.w #7,d2
        beq.s .mw
        move.w d0,d2
        sub.w d1,d2
        andi.w #7,d2
        bne.s .mp
.mw:    moveq #FENCE_COL,d5
.mp:    moveq #63,d2
        and.w d0,d2
        cmp.w #2,d2
        bcc.s .ms
        moveq #FENCE_POST,d5
.ms:    moveq #0,d4
        move.w d1,d4
        lsl.w #8,d4
        move.b d0,d4
        move.b d5,(a6,d4.l)
        addq.w #1,d0
        cmp.w #256,d0
        bne.s .mx
        addq.w #1,d1
        cmp.w #256,d1
        bne.s .my
        movea.l tx_mtex(pc),a0          ; v 0-GR_H (world z): the turn
        lea gr_rows(pc),a1              ; guardrails, posts every 16 units
        moveq #0,d1
.gy:    move.b (a1)+,d5                 ; beam row or a hole
        moveq #0,d0
.gx:    move.b d5,d2
        moveq #15,d3
        and.w d0,d3
        cmp.w #2,d3
        bcc.s .gb
        tst.b d2                        ; posts behind the beams
        bpl.s .gb
        moveq #GR_POST,d2
.gb:    move.w d1,d4
        lsl.w #8,d4
        move.b d0,d4
        move.b d2,(a0,d4.w)
        addq.w #1,d0
        cmp.w #256,d0
        bne.s .gx
        addq.w #1,d1
        cmp.w #GR_H+1,d1
        bne.s .gy
        move.l expmem(pc),d0            ; grass: patches, clumps, blades
        add.l #TGRASS_OFF,d0
        movea.l d0,a6
        add.l #32768,d0
        lea tx_grtex(pc),a0
        move.l d0,(a0)
        movea.l a5,a0
        move.w #16+64+4096-1,d6
.rlat:  bsr .rnd
        move.b d7,(a0)+
        dbra d6,.rlat
        moveq #0,d1                     ; y
.ry:    moveq #0,d0                     ; x
.rx:    lea (a5),a0                     ; 4 x 4, period 64 texels
        moveq #6,d2
        moveq #6,d3
        bsr vnoise
        move.w d4,d5
        add.w d5,d5
        lea 16(a5),a0                   ; 8 x 8, period 32
        moveq #5,d2
        moveq #5,d3
        bsr vnoise
        add.w d4,d5
        sub.w #384,d5
        asr.w #5,d5
        addq.w #8,d5
        bpl.s .r0
        moveq #0,d5
.r0:    cmp.w #15,d5
        bls.s .r1
        moveq #15,d5
.r1:    lea 80(a5),a0                   ; 64 x 64, period 4: clumps
        moveq #2,d2
        moveq #2,d3
        bsr vnoise
        lsr.w #6,d4
        lsl.w #4,d4
        or.w d4,d5
        bsr .rnd                        ; blades
        moveq #0,d4
        cmp.b #10,d7
        bcs.s .rb3
        cmp.b #72,d7
        bcs.s .rb1
        cmp.b #139,d7
        bcc.s .rb0
        move.w #$80,d4                  ; +1
        bra.s .rb0
.rb1:   moveq #$40,d4                   ; -1
        bra.s .rb0
.rb3:   move.w #$c0,d4                  ; -2
.rb0:   or.w d4,d5
        moveq #0,d4
        move.w d1,d4
        lsl.w #8,d4
        move.b d0,d4
        move.b d5,(a6,d4.l)
        addq.w #1,d0
        cmp.w #256,d0
        bne .rx
        addq.w #1,d1
        cmp.w #256,d1
        bne .ry
        movea.l a5,a0                   ; tables: colours 7, 8, 15, 5 x fade
        moveq #7,d6
        lea tx_off(pc),a2
        bsr .tab
        moveq #8,d6
        lea tx_off(pc),a2
        bsr .tab
        moveq #15,d6
        lea tx_woff(pc),a2
        bsr .tab
        moveq #5,d6
        lea tx_goff(pc),a2
        bsr .tab
        move.l expmem(pc),d0            ; the ground (colour 7, r 0) per
        add.l #TGSH_OFF,d0              ; fade: each texel's colour
        movea.l d0,a1
        add.l #32768,d0
        lea tx_gsh(pc),a0
        move.l d0,(a0)
        movea.l tx_lut(pc),a2
        moveq #GND_FADES-1,d2
.gf:    movea.l tx_tex(pc),a0
        suba.l #32768,a0
        moveq #0,d0
        move.w #$ffff,d1
.gp:    move.b (a0)+,d0
        move.b (a2,d0.w),(a1)+
        dbra d1,.gp
        lea 256(a2),a2
        dbra d2,.gf
        move.l expmem(pc),d0            ; tree leaves: clusters with holes,
        add.l #TTREE_OFF+32768,d0       ; 128 x 128 texels (v up) at the
        movea.l d0,a6                   ; middle (R0), three mip levels
        add.l #32768,d0                 ; beside it (tr_reg); R2 and R3
        lea tx_trtex(pc),a0             ; hold the cluster values and the
        move.l d0,(a0)                  ; leaf noise until R0 is done
        lea -32768(a6),a0               ; holes around it: what a v out of
        move.w #65536/4-1,d0            ; 0-127 reads
.tc:    clr.l (a0)+
        dbra d0,.tc
        adda.l #32768,a0
        moveq #256/4-1,d0
.td:    clr.l (a0)+
        dbra d0,.td
        lea 128(a6),a0                  ; leaf noise (R3): 0-153 per block
        moveq #0,d1                     ; of 4 x 4 texels
.nb:    moveq #0,d0
.nc:    bsr .rnd
        moveq #0,d5
        move.b d7,d5
        mulu.w #154,d5
        lsr.w #8,d5
        move.w d1,d3
        moveq #10,d6
        lsl.w d6,d3
        move.w d0,d6
        lsl.w #2,d6
        add.w d6,d3
        moveq #3,d6
.nr:    move.b d5,(a0,d3.w)
        move.b d5,1(a0,d3.w)
        move.b d5,2(a0,d3.w)
        move.b d5,3(a0,d3.w)
        add.w #256,d3
        dbra d6,.nr
        addq.w #1,d0
        cmp.w #32,d0
        bne.s .nc
        addq.w #1,d1
        cmp.w #32,d1
        bne.s .nb
        moveq #0,d1                     ; + 0-101 per texel
.ny:    moveq #0,d0
.nx:    bsr .rnd
        moveq #0,d5
        move.b d7,d5
        mulu.w #102,d5
        lsr.w #8,d5
        move.w d1,d3
        lsl.w #8,d3
        add.w d0,d3
        add.b d5,(a0,d3.w)
        addq.w #1,d0
        cmp.w #128,d0
        bne.s .nx
        addq.w #1,d1
        cmp.w #128,d1
        bne.s .ny
        lea tr_sq(pc),a2                ; 16 sqrt(i), i below 170
        moveq #0,d5
.sq:    move.l d5,d2
        lsl.l #8,d2
        bsr tx_sqrt
        move.w d1,(a2)+
        addq.w #1,d5
        cmp.w #170,d5
        bne.s .sq
        lea tr_sq(pc),a2                ; 55 clusters (R2): cones of
        lea tr_cl(pc),a3                ; radius 6-13 texels centred
        moveq #54,d6                    ; within 59 texels of the middle,
.cl:    bsr .rnd                        ; each texel the highest cone
        moveq #127,d0
        and.w d7,d0                     ; x
        move.w d7,d1
        lsr.w #8,d1
        andi.w #127,d1                  ; y
        move.w d0,d2
        sub.w #64,d2
        muls.w d2,d2
        move.w d1,d3
        sub.w #64,d3
        muls.w d3,d3
        add.l d3,d2
        cmp.l #3482,d2
        bcc.s .cl
        move.l d7,d3
        swap d3
        andi.w #7,d3
        addq.w #6,d3                    ; r
        movem.w d0-d1/d3,(a3)
        move.w d3,d4
        mulu.w d3,d4
        move.w d4,6(a3)                 ; r^2
        lsl.w #4,d3
        move.w d3,8(a3)                 ; 16 r
        move.w 2(a3),d5                 ; rows
        sub.w 4(a3),d5
        bpl.s .v0
        moveq #0,d5
.v0:    move.w 2(a3),d0
        add.w 4(a3),d0
        cmp.w #127,d0
        ble.s .v1
        move.w #127,d0
.v1:    move.w d0,10(a3)
.vl:    move.w (a3),d4                  ; columns
        sub.w 4(a3),d4
        bpl.s .u0
        moveq #0,d4
.u0:    move.w (a3),d0
        add.w 4(a3),d0
        cmp.w #127,d0
        ble.s .u1
        move.w #127,d0
.u1:    move.w d0,12(a3)
.ul:    move.w d4,d1
        sub.w (a3),d1
        muls.w d1,d1
        move.w d5,d2
        sub.w 2(a3),d2
        muls.w d2,d2
        add.w d2,d1                     ; d^2
        cmp.w 6(a3),d1
        bcc.s .ue
        move.w (a2,d1.w*2),d1           ; 255 (1 - d / r)
        mulu.w #255,d1
        divu.w 8(a3),d1
        move.w #255,d0
        sub.w d1,d0
        move.w d5,d2
        lsl.w #8,d2
        add.w d4,d2
        cmp.b (a6,d2.w),d0
        bls.s .ue
        move.b d0,(a6,d2.w)
.ue:    addq.w #1,d4
        cmp.w 12(a3),d4
        ble.s .ul
        addq.w #1,d5
        cmp.w 10(a3),d5
        ble.s .vl
        dbra d6,.cl
        movea.l tx_trtex(pc),a0         ; R0: a leaf where the cluster
        moveq #0,d1                     ; value c is above 30 and either
.fy:    moveq #0,d0                     ; c above 140 or the noise n above
.fx:    move.w d1,d2                    ; 100; level 1 + (9 c + 6 n) / 255
        lsl.w #8,d2                     ; (up to 15), else 0 (a hole)
        add.w d0,d2
        moveq #0,d3
        move.b (a6,d2.w),d3
        moveq #0,d4
        move.b 128(a6,d2.w),d4
        moveq #0,d5
        cmp.w #30,d3
        bls.s .fh
        cmp.w #140,d3
        bhi.s .fo
        cmp.w #100,d4
        bls.s .fh
.fo:    move.w d3,d5
        mulu.w #9,d5
        move.w d4,d6
        mulu.w #6,d6
        add.l d6,d5
        divu.w #255,d5
        addq.w #1,d5
        cmp.w #15,d5
        bls.s .fh
        moveq #15,d5
.fh:    move.b d5,(a0,d2.w)
        addq.w #1,d0
        cmp.w #128,d0
        bne.s .fx
        addq.w #1,d1
        cmp.w #128,d1
        bne.s .fy
        lea tr_reg+4(pc),a3             ; mip levels: blocks of 2, 4 and 8
        moveq #2,d6                     ; texels, a hole when less than
.tm:    movea.l tx_trtex(pc),a0         ; half is leaves, else their mean
        movea.l a0,a1                   ; level
        adda.l (a3)+,a1
        moveq #0,d1
.qy:    moveq #0,d0
.qx:    move.w d1,d2
        lsl.w #8,d2
        add.w d0,d2
        lea (a0,d2.w),a2
        lea (a1,d2.w),a4
        moveq #0,d3
        moveq #0,d4
        move.w d6,d7
        subq.w #1,d7
.mr:    swap d7
        move.w d6,d7
        subq.w #1,d7
.mc:    moveq #0,d2
        move.b (a2)+,d2
        beq.s .m0
        addq.w #1,d3
        add.w d2,d4
.m0:    dbra d7,.mc
        suba.w d6,a2
        lea 256(a2),a2
        swap d7
        dbra d7,.mr
        move.w d6,d2
        mulu.w d6,d2
        move.w d3,d7
        add.w d7,d7
        cmp.w d2,d7
        bcs.s .mz
        move.w d3,d2
        lsr.w #1,d2
        add.w d2,d4
        divu.w d3,d4
        bra.s .tw
.mz:    moveq #0,d4
.tw:    move.w d6,d7
        subq.w #1,d7
.wr:    swap d7
        move.w d6,d7
        subq.w #1,d7
.wc:    move.b d4,(a4)+
        dbra d7,.wc
        suba.w d6,a4
        lea 256(a4),a4
        swap d7
        dbra d7,.wr
        add.w d6,d0
        cmp.w #128,d0
        bcs .qx
        add.w d6,d1
        cmp.w #128,d1
        bcs .qy
        add.w d6,d6
        cmp.w #16,d6
        bcs .tm
        move.l expmem(pc),d0            ; crowd: 64 x 64 cells of 4 x 4
        add.l #TCROWD_OFF,d0            ; texels (u x v, v up) in R0, a
        movea.l d0,a6                   ; person each: rows 0-2 the shirt,
        add.l #32768,d0                 ; row 3 the head on texels 1-2
        lea tx_crtex(pc),a0             ; between shadows; 15 % empty
        move.l d0,(a0)                  ; seats;
        moveq #0,d1                     ;
.kr:    moveq #0,d0                     ; stairs every 64 texels
.ks:    moveq #0,d3
        move.w d1,d3
        moveq #10,d4
        lsl.l d4,d3
        move.w d0,d4
        lsl.w #2,d4
        add.w d4,d3
        lea (a6,d3.l),a0                ; the cell's lowest left texel
        moveq #15,d4
        and.w d0,d4
        bne.s .kp
        moveq #CM_EDGE,d5               ; stairs
        move.b d5,(a0)
        move.b d5,1(a0)
        move.b d5,2(a0)
        move.b d5,3(a0)
        moveq #CM_STAIR,d5
        moveq #2,d4
.ka:    lea 256(a0),a0
        move.b d5,(a0)
        move.b d5,1(a0)
        move.b d5,2(a0)
        move.b d5,3(a0)
        dbra d4,.ka
        bra .kc
.kp:    moveq #CM_EDGE,d5               ; shadows beside the head
        move.b d5,768(a0)
        move.b d5,768+3(a0)
        bsr .rnd
        cmp.b #218,d7
        bcs.s .ko
        moveq #CM_SEAT,d5               ; empty
        moveq #2,d4
.ke:    move.b d5,(a0)
        move.b d5,1(a0)
        move.b d5,2(a0)
        move.b d5,3(a0)
        lea 256(a0),a0
        dbra d4,.ke
        move.b d5,1(a0)
        move.b d5,2(a0)
        bra.s .kc
.ko:    move.w d7,d4                    ; shirt
        lsr.w #8,d4
        andi.w #15,d4
        add.w #CM_SHIRT,d4
        moveq #2,d5
.kh:    move.b d4,(a0)
        move.b d4,1(a0)
        move.b d4,2(a0)
        move.b d4,3(a0)
        lea 256(a0),a0
        dbra d5,.kh
        move.w d7,d4                    ; head
        moveq #12,d2
        lsr.w d2,d4
        andi.w #7,d4
        lea cr_head(pc),a1
        move.b (a1,d4.w),d4
        move.b d4,1(a0)
        move.b d4,2(a0)
.kc:    addq.w #1,d0
        cmp.w #64,d0
        bne .ks
        addq.w #1,d1
        cmp.w #64,d1
        bne .kr
        lea cr_reg+4(pc),a3             ; mip levels: one random texel of
        moveq #2,d6                     ; each block of 2, 4 and 8 over the
.km:    movea.l a6,a4                   ; whole block
        adda.l (a3)+,a4
        moveq #0,d1
.kmy:   moveq #0,d0
.kmx:   bsr .rnd
        move.w d6,d5
        subq.w #1,d5
        move.w d7,d3
        and.w d5,d3
        add.w d0,d3
        move.w d7,d4
        lsr.w #8,d4
        and.w d5,d4
        add.w d1,d4
        moveq #0,d2
        move.w d4,d2
        lsl.l #8,d2
        add.w d3,d2
        move.b (a6,d2.l),d3             ; the texel
        moveq #0,d2
        move.w d1,d2
        lsl.l #8,d2
        add.w d0,d2
        lea (a4,d2.l),a0
        move.w d5,d4
.kfr:   move.w d5,d2
.kfc:   move.b d3,(a0)+
        dbra d2,.kfc
        suba.w d6,a0
        lea 256(a0),a0
        dbra d4,.kfr
        add.w d6,d0
        cmp.w #256,d0
        bcs .kmx
        add.w d6,d1
        cmp.w #256,d1
        bcs .kmy
        add.w d6,d6
        cmp.w #16,d6
        bcs .km
        move.l a6,d0                    ; the three brightness tables
        add.l #$40000,d0                ; after R3: colour c at level L +
        lea tx_crlut(pc),a0             ; shift, clamped to 0-15
        move.l d0,(a0)
        movea.l d0,a0
        lea cr_sh(pc),a2
        moveq #2,d6
.kl:    move.b (a2)+,d5
        ext.w d5
        lea cr_mat(pc),a1
        moveq #CM_N-1,d4
        movea.l a0,a4
.kl2:   moveq #0,d0
        move.b (a1)+,d0
        moveq #0,d1
        move.b (a1)+,d1
        add.w d5,d1
        bpl.s .kl3
        moveq #0,d1
.kl3:   cmp.w #15,d1
        ble.s .kl4
        moveq #15,d1
.kl4:   sub.w #9,d1
        andi.w #15,d1
        lsl.w #4,d1
        or.w d0,d1
        move.b d1,(a4)+
        dbra d4,.kl2
        lea 256(a0),a0
        dbra d6,.kl
        bsr fc_build
        movem.l (sp)+,d0-d7/a0-a6
        rts
; The 8 fades x 256 texels of colour D6 from the offsets at A2 to A0.
.tab:   move.w #8*256-1,d3
.te:    move.b (a2)+,d0
        ext.w d0
        add.w #9,d0                     ; level 9 + offset
        bpl.s .t0
        moveq #0,d0
.t0:    cmp.w #15,d0
        bls.s .t1
        moveq #15,d0
.t1:    sub.w #9,d0
        andi.w #15,d0
        lsl.w #4,d0
        or.b d6,d0
        move.b d0,(a0)+
        dbra d3,.te
        rts
.rnd:   move.l d7,d4
        lsl.l #8,d4
        lsl.l #5,d4
        eor.l d4,d7
        move.l d7,d4
        moveq #17,d2
        lsr.l d2,d4
        eor.l d4,d7
        move.l d7,d4
        lsl.l #5,d4
        eor.l d4,d7
        rts

        machine 68000
