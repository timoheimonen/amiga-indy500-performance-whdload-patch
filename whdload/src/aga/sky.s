; Indianapolis 500 WHDLoad Slave V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; Background with the AGA display: as c_background_tail, but the sky pixels
; (plane 2 clear) get the sky gradient: level = distance from the horizon
; line (sky_l0, sky_bpx and gnd_full from bg_line) in rows x SKY_K /
; 65536, with a 2 x 2 ordered dither between the levels, colour from
; skymap.

SKY_K   equ 17476                       ; 65536 x 16 levels / 60 rows

; Pixel \1 of a byte with sky and ground: ground (bit set) colour 7.
SKYMIX  macro
        add.b d5,d5
        bcc.s .s\@
        move.b #7,(a1)+
        bra.s .n\@
.s\@:  move.l d1,d0
        add.l \1*4(a2),d0
        swap d0
        move.b (a3,d0.w),(a1)+
.n\@:
        endm

        machine 68020
c_sky_tail:
        movem.l d0-d7/a0-a6,-(sp)
        move.l sky_bpx(pc),d3           ; B: levels per pixel (16.16)
        lea sky_offs(pc),a2             ; pixel offsets for even and odd rows
        lea sky_bias(pc),a3
        moveq #1,d6
.bp:    moveq #0,d0
        moveq #3,d5
.bi:    move.l d0,d1
        add.l (a3),d1
        move.l d1,(a2)+
        add.l d3,d0
        move.l d0,d1
        add.l 4(a3),d1
        move.l d1,(a2)+
        add.l d3,d0
        dbra d5,.bi
        addq.l #8,a3
        dbra d6,.bp
        lsl.l #3,d3                     ; 8 B: one byte of plane 2
        move.l sky_l0(pc),d2            ; level of row 0, x 0
        movea.l G_DRAW_BACK,a0
        lea VIEW_TOP+2*FILL_PLANE(a0),a0
        movea.l chunky_base(pc),a1
        lea skymap+128(pc),a3
        move.l #$07070707,d4            ; ground
        lea gnd_mark(pc),a4             ; textured later: markers
        sf (a4)
        btst #0,gnd_on(pc)
        beq.s .gm
        btst #0,tx_ok(pc)
        beq.s .gm
        move.l tx_gnd+TS_HS(pc),d0
        beq.s .gm
        st (a4)
        move.l #GND_MARK*$01010101,d4
.gm:    lea sky_gl(pc),a4
        move.l d4,(a4)
        suba.l a6,a6                    ; marker bytes above gnd_full
        moveq #0,d7                     ; row
.row:   cmp.w gnd_full(pc),d7
        bcc .grow
        lea sky_offs(pc),a2
        movea.l sky_pt(pc),a5
        btst #0,d7
        beq.s .even
        lea 32(a2),a2
        lea 2048(a5),a5
.even:  move.l d2,d1
        moveq #39,d6
        tst.l d3
        beq .frow
.byte:  move.b (a0)+,d5
.disp:  beq .sky8
        cmp.b #$ff,d5
        beq .gnd8
        SKYMIX 0
        SKYMIX 1
        SKYMIX 2
        SKYMIX 3
        SKYMIX 4
        SKYMIX 5
        SKYMIX 6
        SKYMIX 7
        bra .next
.gnd8:  move.l d4,(a1)+
        move.l d4,(a1)+
        addq.w #1,a6
.next:  add.l d3,d1
        dbra d6,.byte
.rend:  sub.l #SKY_K,d2
        addq.w #1,d7
        cmp.w #VIEW_H,d7
        bne .row
        bra.s .end
.grow:  moveq #VIEW_H,d6                ; the rows left are all ground
        sub.w d7,d6
        mulu.w #VIEW_W/32,d6
        subq.w #1,d6
.gr:    rept 8
        move.l d4,(a1)+
        endr
        dbra d6,.gr
.end:   lea gnd_cnt(pc),a0
        move.w a6,(a0)
        bsr tex_ground
        lea $dff000,a2                  ; blitter state as the original leaves it
        move.w #$1ff,$40(a2)
        clr.w $42(a2)
        clr.w $64(a2)
        clr.w $66(a2)
        movem.l (sp)+,d0-d7/a0-a6
        rts
; A run of bytes all sky: 2 pixels at a time from the pair table of the
; row's parity (A5, sky_pt_build), indexed by the quarter level of the
; even pixel, Q = 4 x level (D5 its integer, D0 its fraction), which
; steps by 8 B per pair (the high word in D4, the low word in A4). The
; odd pixel takes the level of the even one (one B less than the pixel
; code). D1 is rebuilt from Q at the end of the run.
.sky8:  move.l d1,d0
        asl.l #2,d0
        move.l d0,d5
        swap d5
        movea.w d3,a4
        move.l d3,d4
        swap d4
.sr:
        rept 4
        move.w (a5,d5.w*2),(a1)+
        add.w a4,d0
        addx.w d4,d5
        endr
        subq.w #1,d6
        bmi.s .srx                      ; the row is done
        tst.b (a0)+
        beq.s .sr
        swap d5                         ; level of this byte
        move.w d0,d5
        asr.l #2,d5
        move.l d5,d1
        move.l sky_gl(pc),d4
        move.b -1(a0),d5                ; not 0
        bra .disp
.srx:   move.l sky_gl(pc),d4
        bra .rend
; A level horizon (B = 0, so b = 0): the rows above gnd_full are all sky,
; every byte with the same 8 pixels, built once into A4 and A5.
.frow:
pix     set 0
        rept 4
        move.l d1,d0
        add.l pix*4(a2),d0
        swap d0
        lsl.l #8,d5
        move.b (a3,d0.w),d5
pix     set pix+1
        endr
        movea.l d5,a4
        rept 4
        move.l d1,d0
        add.l pix*4(a2),d0
        swap d0
        lsl.l #8,d5
        move.b (a3,d0.w),d5
pix     set pix+1
        endr
        movea.l d5,a5
        moveq #9,d6
.fs:    rept 4
        move.l a4,(a1)+
        move.l a5,(a1)+
        endr
        dbra d6,.fs
        bra .rend

        machine 68000

; Sky pixel pairs (68000 code, run once): for each row parity and quarter
; level q (-512 to 511) a word with the colours of the even and the odd
; pixel, skymap levels q >> 2 and (q + 2) >> 2 for even rows, (q + 3) >> 2
; and (q + 1) >> 2 for odd rows (the dither offsets of sky_bias), clamped
; to -128..127. sky_pt is the word of q = 0 of the even rows; the odd rows
; follow 2048 bytes later.
SKYQ    macro                           ; D2 = colour of level (D0 + \1) >> 2
        move.w d0,d2
        add.w #\1,d2
        asr.w #2,d2
        cmp.w #127,d2
        ble.s .a\@
        moveq #127,d2
.a\@:   cmp.w #-128,d2
        bge.s .b\@
        move.w #-128,d2
.b\@:   move.b (a2,d2.w),d2
        endm
sky_pt_build:
        movem.l d0-d3/a0-a2,-(sp)
        movea.l expmem(pc),a0
        adda.l #SKYP_OFF,a0
        lea 1024(a0),a1
        lea sky_pt(pc),a2
        move.l a1,(a2)
        lea skymap+128(pc),a2
        move.w #-512,d0                 ; q
        move.w #1023,d3
.q:     SKYQ 0
        move.b d2,(a0)
        SKYQ 2
        move.b d2,1(a0)
        SKYQ 3
        move.b d2,2048(a0)
        SKYQ 1
        move.b d2,2049(a0)
        addq.l #2,a0
        addq.w #1,d0
        dbra d3,.q
        movem.l (sp)+,d0-d3/a0-a2
        rts

sky_pt:         dc.l 0                  ; sky pairs of q = 0, even rows
sky_gl:         dc.l 0                  ; ground long of the frame
sky_l0:         dc.l 0                  ; sky level of row 0, x 0 (16.16)
sky_bpx:        dc.l 0                  ; its step per pixel
aga_dirty:      dc.b 0                  ; colours 16-255 to be written
gnd_on:         dc.b 1                  ; ground textured after the 3D view
gnd_mark:       dc.b 0                  ; this frame's ground bytes are markers
        even
gnd_full:       dc.w 0                  ; first row with plane 2 all ones
gnd_cnt:        dc.w 0                  ; marker bytes of plane 2 above it
gnd_n:          dc.w 0                  ; spans in gnd_list
gnd_list:       ds.w 3*VIEW_H           ; x, pixels, view row
aga_pal:        ds.w 16                 ; palette they were written from
sky_high:       ds.w 16                 ; per r: high nibbles of 16 r + 11
sky_low:        ds.w 16                 ; and the low nibbles
sky_rgb:        ds.b 3*16               ; R, G, B of levels 0-15
sky_bias:       dc.l 0,$8000,$c000,$4000        ; dither: rows even, odd
sky_offs:       ds.l 16                 ; per row parity and pixel of a byte
; Level (-128 to 127) to colour: below 0 the horizon colour, above 15 the
; top colour; level 4 is colour 11, the others 16 r + 11.
skymap: dcb.b 128,11+16*1
        dc.b 11+16*1,11+16*2,11+16*3,11+16*4,11,11+16*5,11+16*6,11+16*7
        dc.b 11+16*8,11+16*9,11+16*10,11+16*11,11+16*12,11+16*13,11+16*14
        dc.b 11+16*15
        dcb.b 112,11+16*15
        even
