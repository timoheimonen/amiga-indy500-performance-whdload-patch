; Indianapolis 500 WHDLoad Slave V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; The track in the mirrors (mir_off clear). The game fills its mirror
; picture (4 planes of $78 bytes at $78514, rows of 10 bytes: columns 0-39
; go to the left mirror and 32-71 to the right one) with two rows of sky
; and nine of asphalt and draws the cars behind into it: a car at the depth
; d and x' to the right is centred on column 35 + 18 x' / d, and its image
; (as high as 530 / d rows) hangs from the horizon, the top of row 2.
; Here every pixel below the horizon is the ground point behind the camera
; that a car standing there would cover with its wheels: row r shows the
; depth 530 / (r - 1.5), column c the point d x (c - 35) / 18 to the right,
; and the point's place on the oval (the model of track_to_world: a core
; rectangle of 9900 x 1980 half sides and the lateral 0 line 4742 around
; it) gives its colour. A wall ends its column: it is white up to 0.3 of
; the height from the horizon to its foot, and its fence or the grandstand
; takes the rows above. No pitch, roll or banking: the game's mirror cars
; have none either.
;
; A row is not tested pixel by pixel: every test also gives the distance
; to the nearest edge of what it found, and the columns within that
; distance get the same colour.

        machine 68020

MIR_BUF equ $78514                      ; the game's mirror picture (chip)
MIR_PL  equ $78                         ; bytes per plane (12 rows of 10)
MIR_W   equ 72                          ; columns in use
MIR_X0  equ 35                          ; the column straight behind

MC_SKY   equ 11
MC_ROAD  equ 7
MC_APRON equ 14
MC_GRASS equ 10
MC_WALL  equ 15
MC_FENCE equ 13                         ; and the grandstand's concrete
MC_SEAT  equ 9
MC_ROOF  equ 8

MV_FX   equ 0                           ; forward and right, world x and y
MV_FY   equ 2                           ; (view matrix, 2.14)
MV_RX   equ 4
MV_RY   equ 6
MV_CX   equ 8                           ; camera (16.16)
MV_CY   equ 12
MV_TOP  equ 16                          ; a wall met in this row: the row
                                        ; of its top
MV_INV  equ 18                          ; this row: columns per unit x 65536
MV_S4X  equ 20                          ; this row: four columns to the right
MV_S4Y  equ 24
MV_ANY  equ 28                          ; a wall met in this picture
MV_BLK  equ 30                          ; per column: 0 or the wall met:
MV_PIX  equ MV_BLK+MIR_W                ; its top row, + $10 with a fence,
MV_SIZE equ MV_PIX+MIR_W                ; $20 with a grandstand; the row's
                                        ; colours

; fast_view_cars: A0 = the view matrix, A1 = the camera position (words),
; D0.w = not 0: the matrix is halved. No game address here: this module
; lies beyond the reach of the game_refs table. All registers kept.
mir_draw:
        tst.b mir_off(pc)
        bne .off
        movem.l d0-d7/a0-a6,-(sp)
        lea mir_v(pc),a5
        move.w (a0),d1
        move.w 6(a0),d2
        move.w 2(a0),d3
        move.w 8(a0),d4
        tst.w d0
        beq.s .full
        add.w d1,d1
        add.w d2,d2
        add.w d3,d3
        add.w d4,d4
.full:  move.w d1,MV_FX(a5)
        move.w d2,MV_FY(a5)
        move.w d3,MV_RX(a5)
        move.w d4,MV_RY(a5)
        move.w (a1),d0
        swap d0
        move.w #$8000,d0
        move.l d0,MV_CX(a5)
        move.w 2(a1),d0
        swap d0
        move.w #$8000,d0
        move.l d0,MV_CY(a5)
        sf MV_ANY(a5)
        lea MV_BLK(a5),a0
        moveq #MIR_W/4-1,d0
.clr:   clr.l (a0)+
        dbra d0,.clr
        lea mir_rows(pc),a4
        movea.l #MIR_BUF+10*10,a3
        moveq #10,d6                    ; from the bottom row up
.row:   move.w (a4)+,d0                 ; depth x 16
        move.w (a4)+,d1                 ; depth x 64 / 18
        move.w (a4)+,MV_TOP(a5)
        move.w (a4)+,MV_INV(a5)
        move.w MV_FX(a5),d2             ; the point straight behind
        muls.w d0,d2
        asr.l #2,d2
        move.l MV_CX(a5),d4
        sub.l d2,d4
        move.w MV_FY(a5),d2
        muls.w d0,d2
        asr.l #2,d2
        move.l MV_CY(a5),d5
        sub.l d2,d5
        move.w MV_RX(a5),d2             ; a column to the right
        muls.w d1,d2
        asr.l #4,d2
        movea.l d2,a1
        move.w MV_RY(a5),d3
        muls.w d1,d3
        asr.l #4,d3
        movea.l d3,a2
        move.l d2,d0
        asl.l #2,d0
        move.l d0,MV_S4X(a5)
        move.l d3,d0
        asl.l #2,d0
        move.l d0,MV_S4Y(a5)
        move.l d2,d0                    ; column 0: MIR_X0 columns to the
        asl.l #5,d0                     ; left
        add.l d2,d0
        add.l d2,d0
        add.l d2,d0
        sub.l d0,d4
        move.l d3,d0
        asl.l #5,d0
        add.l d3,d0
        add.l d3,d0
        add.l d3,d0
        sub.l d0,d5
        lea MV_BLK(a5),a6
        lea MV_PIX(a5),a0
        moveq #MIR_W-1,d7               ; D7 = columns after this one

; A column: behind a wall of a lower row, or its ground point -> D2 =
; colour and D1 = the distance (units) within which nothing else lies.
; D0 = dx = |x| - 9900, D1 = dy = |y| - 1980, D3 = y.
.px:    move.b (a6)+,d0
        bne .blk
        move.l d4,d0
        swap d0
        tst.w d0
        bpl.s .ax
        neg.w d0
.ax:    sub.w #9900,d0
        move.l d5,d1
        swap d1
        move.w d1,d3
        bpl.s .ay
        neg.w d1
.ay:    sub.w #1980,d1
        tst.w d0
        bgt .xo
        neg.w d0                        ; D0 = to the end of the straight
        tst.w d1
        bgt.s .long
        neg.w d1                        ; inside the core: the infield
        moveq #MC_GRASS,d2
        bra.s .min
.long:  sub.w #4742,d1                  ; a long straight: D1 = lateral
        bmi .inner                      ; the inner wall and its fence
        cmp.w #600,d1
        bgt .outer
        moveq #MC_ROAD,d2
        tst.w d3
        bmi.s .lr
        cmp.w #300,d1                   ; the main straight: the pit lane,
        bge.s .lt                       ; the pit wall (low: drawn flat) and
        cmp.w #265,d1                   ; the track
        bge.s .lp
        move.w #265,d3
        bra.s .band
.lp:    moveq #MC_WALL,d2
        sub.w #265,d1
        moveq #35,d3
        bra.s .band
.lt:    sub.w #300,d1
        move.w #300,d3
        bra.s .band
.lr:    move.w #600,d3
.band:  sub.w d1,d3                     ; D1 from the lower edge of a band
        cmp.w d1,d3                     ; D3 wide: the nearer edge
        bcc.s .min
        move.w d3,d1
.min:   cmp.w d0,d1
        bls.s .m1
        move.w d0,d1
.m1:    subq.w #2,d1                    ; (the coordinates are whole units)
        ble.s .one
        mulu.w MV_INV(a5),d1            ; the columns after this one that
        swap d1                         ; lie within the distance
        cmp.w d7,d1
        bls.s .m2
        move.w d7,d1
.m2:    sub.w d1,d7
        move.b d2,(a0)+
        add.l a1,d4
        add.l a2,d5
        subq.w #4,d1                    ; four columns at a time while none
        bcs.s .rt                       ; of them is behind a wall
        move.l (mir_rep,pc,d2.w*4),d3
.r4:    tst.l (a6)
        bne.s .rt
        move.l d3,(a0)+
        addq.l #4,a6
        add.l MV_S4X(a5),d4
        add.l MV_S4Y(a5),d5
        subq.w #4,d1
        bcc.s .r4
.rt:    addq.w #4,d1
        bra.s .rt1
.rl:    move.b (a6)+,d0
        bne.s .rstop
        move.b d2,(a0)+
        add.l a1,d4
        add.l a2,d5
.rt1:   dbra d1,.rl
        bra.s .next
.rstop: add.w d1,d7                     ; a column behind a wall ends the
                                        ; run
.blk:   moveq #15,d1                    ; the wall from its top row down
        and.b d0,d1
        moveq #MC_WALL,d2
        cmp.w d1,d6
        bcc.s .one
        move.w d7,d1
        add.w d6,d1
        bsr mir_above
.one:   move.b d2,(a0)+
        add.l a1,d4
        add.l a2,d5
.next:  dbra d7,.px
        move.l #MC_ROAD*$01010101,d3
        bsr mir_c2p
        lea -10(a3),a3
        subq.w #1,d6
        cmp.w #2,d6
        bcc .row
        tst.b MV_ANY(a5)                ; the two rows above the horizon:
        beq.s .done                     ; sky without a wall
        move.l #(MC_SKY<<24)|(MC_FENCE<<16)|(MC_SKY<<8)|MC_FENCE,d4
        move.l #MC_SEAT*$01010101,d5
.top:   lea MV_BLK(a5),a6               ; four columns at a time: no wall, a
        lea MV_PIX(a5),a0               ; fence (D4) or a grandstand (D5)
        moveq #MIR_W-1,d3               ; D3 = columns after this one
        moveq #MIR_W/4-1,d7
.tp:    move.l (a6)+,d0
        and.l #$f0f0f0f0,d0
        bne.s .tp1
        move.l #MC_SKY*$01010101,(a0)+
        bra.s .tpn
.tp1:   cmp.l #$10101010,d0
        bne.s .tp2
        move.l d4,(a0)+
        bra.s .tpn
.tp2:   cmp.l #$20202020,d0
        bne.s .tp3
        move.l d5,(a0)+
        bra.s .tpn
.tp3:   subq.l #4,a6
        bsr.s .tone
        bsr.s .tone
        bsr.s .tone
        bsr.s .tone
        addq.w #4,d3
.tpn:   subq.w #4,d3
        dbra d7,.tp
        move.l #MC_SKY*$01010101,d3
        bsr mir_c2p
        lea -10(a3),a3
        rol.l #8,d4
        move.l #MC_ROOF*$01010101,d5
        dbra d6,.top
.done:  movem.l (sp)+,d0-d7/a0-a6
.off:   rts
.tone:  moveq #MC_SKY,d2
        move.b (a6)+,d0
        beq.s .tput
        move.w d3,d1
        add.w d6,d1
        bsr mir_above
.tput:  move.b d2,(a0)+
        subq.w #1,d3
        rts

; A wall: D2 = its type, D1 = how far the point is behind it, D0 = to the
; end of the straight or the turn. The columns within that distance meet it
; as well.
.inner: move.w d1,d3                    ; (and the core on the other side)
        add.w #4742,d3
        neg.w d1
        cmp.w d3,d1
        bls.s .hit1
        move.w d3,d1
        bra.s .hit1
.outer: sub.w #600,d1
        tst.w d3                        ; grandstands along the main straight
        bmi.s .hit1
        moveq #$20,d2
        bra.s .hit
.chit:  sub.w #660,d1
.hit1:  moveq #$10,d2                   ; a wall with a fence
.hit:   add.b MV_TOP+1(a5),d2
        st MV_ANY(a5)
        cmp.w d0,d1
        bls.s .h0
        move.w d0,d1
.h0:    subq.w #2,d1
        bgt.s .h1
        moveq #0,d1
        bra.s .h2
.h1:    mulu.w MV_INV(a5),d1
        swap d1
        cmp.w d7,d1
        bls.s .h2
        move.w d7,d1
.h2:    sub.w d1,d7
        bra.s .h4
.h3:    move.b (a6)+,d0
        bne .rstop
.h4:    move.b d2,-1(a6)
        move.b #MC_WALL,(a0)+
        add.l a1,d4
        add.l a2,d5
        dbra d1,.h3
        bra .next

.xo:    tst.w d1
        bgt.s .turn
        neg.w d1                        ; a short chute: D0 = to its end,
        exg d0,d1                       ; D1 = lateral
        sub.w #4742,d1
        cmp.w #660,d1
        bgt.s .chit
        moveq #MC_ROAD,d2
        move.w #660,d3
        tst.w d1
        bpl .band
        moveq #MC_APRON,d2
        add.w #80,d1
        moveq #80,d3
        tst.w d1
        bpl .band
        neg.w d1
        moveq #MC_GRASS,d2
        bra .min

.turn:  move.w d0,d3                    ; a turn: D3 = to its nearer end.
        cmp.w d1,d3                     ; The squared distance from the
        bls.s .t0                       ; corner of the core against the
        move.w d1,d3                    ; squared radii. The outer wall is
.t0:    move.w d0,d2                    ; 640 out at the ends of the turn and
        mulu.w d1,d2                    ; 770 in its middle:
        mulu.w d0,d0                    ; r2 - 3/32 dx dy against 5382^2.
        mulu.w d1,d1                    ; A difference of squares / 16384 is
        add.l d1,d0                     ; less than the distance
        cmp.l #4662*4662,d0
        bcs.s .tgr
        cmp.l #4742*4742,d0
        bcs.s .tap
        move.l d2,d1
        add.l d2,d2
        add.l d1,d2
        lsr.l #5,d2
        sub.l d2,d0
        move.l #5382*5382,d1
        sub.l d0,d1
        bls.s .thit
        add.l d2,d0
        sub.l #4742*4742,d0
        moveq #MC_ROAD,d2
.t1:    cmp.l d0,d1
        bls.s .t2
        move.l d0,d1
.t2:    moveq #14,d0
        lsr.l d0,d1
        move.w d3,d0
        bra .min
.tap:   move.l #4742*4742,d1
        sub.l d0,d1
        sub.l #4662*4662,d0
        moveq #MC_APRON,d2
        bra.s .t1
.tgr:   move.l #4662*4662,d1
        sub.l d0,d1
        moveq #MC_GRASS,d2
        bra.s .t2
.thit:  neg.l d1                        ; behind the outer wall: / 16384
        moveq #14,d2                    ; within 5800 of the corner, / 32768
        cmp.l #5800*5800,d0             ; within 8192, else / 131072
        bcs.s .th1
        moveq #15,d2
        cmp.l #$4000000,d0
        bcs.s .th1
        moveq #17,d2
.th1:   lsr.l d2,d1
        move.w d3,d0
        bra .hit1

; D0 = the wall of the column, D6 = row, D1 = row + columns after this
; one -> D2 = the colour above the wall: its fence (every other pixel, the
; grass or the sky behind) or the grandstand (concrete, seats, roof).
mir_above:
        btst #5,d0
        bne.s .stand
        moveq #MC_FENCE,d2
        btst #0,d1
        bne.s .x
        moveq #MC_GRASS,d2
        cmp.w #2,d6
        bcc.s .x
        moveq #MC_SKY,d2
.x:     rts
.stand: moveq #MC_FENCE,d2
        cmp.w #2,d6
        bcc.s .x
        moveq #MC_SEAT,d2
        tst.w d6
        bne.s .x
        moveq #MC_ROOF,d2
        rts

; The MIR_W bytes at MV_PIX into the four planes of the row at A3, except
; the groups of 8 in the colour the game has filled the row with (D3 = its
; byte four times). D0, D2, D7, A0-A1 changed.
mir_c2p:
        lea MV_PIX(a5),a0
        lea mir_ctab(pc),a1
        moveq #0,d2
        moveq #MIR_W/8-1,d7
.byte:  cmp.l (a0),d3
        bne.s .conv
        cmp.l 4(a0),d3
        bne.s .conv
        addq.l #8,a0
        addq.l #1,a3
        dbra d7,.byte
        bra.s .end
.conv:  moveq #0,d0
        rept 8
        move.b (a0)+,d2
        add.l d0,d0
        or.l (a1,d2.w*4),d0
        endr
        move.b d0,3*MIR_PL(a3)
        lsr.l #8,d0
        move.b d0,2*MIR_PL(a3)
        lsr.l #8,d0
        move.b d0,MIR_PL(a3)
        lsr.l #8,d0
        move.b d0,(a3)+
        dbra d7,.byte
.end:   lea -MIR_W/8(a3),a3
        rts

mir_rep:                                ; a colour in four bytes
        dc.l 0,$01010101,$02020202,$03030303,$04040404,$05050505,$06060606,$07070707
        dc.l $08080808,$09090909,$0a0a0a0a,$0b0b0b0b,$0c0c0c0c,$0d0d0d0d,$0e0e0e0e,$0f0f0f0f
mir_ctab:                               ; a colour as a bit of each plane
        dc.l $00000000,$01000000,$00010000,$01010000,$00000100,$01000100,$00010100,$01010100
        dc.l $00000001,$01000001,$00010001,$01010001,$00000101,$01000101,$00010101,$01010101
mir_rows:                               ; rows 10 to 2: depth x 16, depth
        dc.w 998,222,4,18730            ; x 64 / 18, the top row of a wall
        dc.w 1131,251,4,16526           ; met there, columns per unit x
        dc.w 1305,290,4,14322           ; 65536 (1 percent less)
        dc.w 1542,343,3,12120
        dc.w 1884,419,3,9916
        dc.w 2423,538,3,7712
        dc.w 3392,754,2,5508
        dc.w 5653,1256,2,3306
        dc.w 16960,3769,2,1102
mir_v:  ds.b MV_SIZE
        even

        machine 68000
