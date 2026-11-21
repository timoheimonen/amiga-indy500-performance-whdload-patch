; Indianapolis 500 WHDLoad Slave V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; Asphalt, wall and grass textures: with the AGA display the ground (background
; colour 7), solid colour 7 polygons and the colour 7 and 8 panels as high
; as the camera get brightness offsets from a 256 x 256 texture laid on
; world x and y (2^TEX_SHIFT units per texel), the colour 15 walls from a
; second one laid along the wall and world z (1 unit per texel). Each pixel
; gets level 9 + offset (level 9: the colour itself, level_tab), the
; offsets fade with the pixel's footprint on the plane. The point seen in view pixel (x, y) is
; camera + t D, D = depth + xr x' + yr up (camera axes in world space,
; xr = (x - 159.5) / 160, yr = (61.5 - y) / 133.34), t = h / G with h the
; camera's height above the plane and G = -(n . D) (n: the plane's unit
; normal towards the camera). G and the world x and y of D are linear in
; x and y; u and v are exact every 16 pixels and linear in between.
; The grass (colour 5 polygons near flat) gets a fourth texture on world
; z = 0, laid on world x and y as the asphalt.
; Walls 10-20 units high get a see-through catch fence above them, a third
; texture (a mesh with holes) on the wall's plane, drawn after the 3D view
; (fence_flush). 68020 instructions (only reached on a 68040/060), 32 bit
; results only.

TEX_SHIFT       equ 1               ; 2 units per texel (walls: u, v doubled)
TEX_OFF         equ EXPMEM_SIZE+$B000       ; asphalt, 256 x 256 bytes
TLUT_OFF        equ TEX_OFF+$10000  ; per colour 7/8/15/5 and fade: 256 bytes
TWALL_OFF       equ TLUT_OFF+$2000  ; wall texture, 256 x 256 bytes
TMESH_OFF       equ TWALL_OFF+$10000 ; fence mesh, 256 x 256 bytes
TFLIST_OFF      equ TMESH_OFF+$10000 ; fences of the frame, FENCE_MAX x FL_SIZE
TGSH_OFF        equ TFLIST_OFF+$1000 ; the asphalt through the ground's offset
GND_FADES       equ 5               ; tables, fades 0-4: 256 x 256 bytes each
TGRASS_OFF      equ TGSH_OFF+GND_FADES*$10000 ; grass, 256 x 256 bytes
TTREE_OFF       equ EXPMEM_SIZE+$14A000 ; tree leaves: 32 KB of holes, 4 x 128 x 128
                                    ; in 256 x 256 bytes, 256 bytes of holes
TCROWD_OFF      equ EXPMEM_SIZE+$163000 ; crowd: 4 levels of 256 x 256 bytes, 3
                                    ; tables of 256 bytes
TFACE_OFF       equ EXPMEM_SIZE+$1A4000 ; scenery materials: atlases H and V and
                                    ; the seats, 4 levels of 256 x 256 bytes
                                    ; each, then FM_NLUT tables of 256 bytes
FM_COL          equ 0               ; fm_tab: byte: the game's colour
FM_BIT          equ 1               ; byte: its tex_on bit
FM_FLG          equ 2               ; byte: FMF_*
FM_LUT          equ 3               ; byte: its table (fm_ramp)
FM_BOX          equ 4               ; 6 words: x, y, z min and max of corner A
FM_SU           equ 16              ; word: texels per unit x 256 along u
FM_SV           equ 18              ; along v
FM_UO           equ 20              ; word: u of the origin in the atlas
FM_VO           equ 22              ; v
FM_Z0           equ 24              ; word: world z of the v origin (vertical)
FM_FLAT         equ 26              ; byte: texel drawn flat (far)
FM_KMAX         equ 27              ; byte: mip level from which it is flat
FM_SIZE         equ 28
FMF_FLAT        equ 1               ; flat (a roof), else vertical
FMF_ZMIN        equ 2               ; v origin at the polygon's lowest z
FMF_V           equ 4               ; atlas V, else H
FM_NLUT         equ 9
ST_LUT          equ 6               ; seats: the tables of colours 7, 8 and 0
ST_MEAN         equ 9               ; texel of the far, flat seats
ST_KMAX         equ 6               ; flat from this k on (256 units a pixel, or far)
ST_DARK         equ 1               ; seat texels: portal
ST_WALK         equ 4               ; walkway
ST_STAIR        equ 5               ; aisle
ST_SHADE        equ 8               ; row under a bench (tone -1 to +1)
ST_BENCH        equ 12              ; bench row
ST_WALL         equ 14              ; wall above a walkway
FM_PNUM         equ 12              ; pylon: texel of the positions
FM_CNUM         equ 14              ; and of the car numbers
FP_ATL          equ 0               ; fm_paint: byte: atlas (0 H, 1 V; -1 end)
FP_IDX          equ 1               ; byte: texel
FP_U0           equ 2               ; words: corner, size
FP_V0           equ 4
FP_W            equ 6
FP_H            equ 8
FP_PU           equ 10              ; words: period and width along u
FP_TU           equ 12
FP_PV           equ 14              ; and along v
FP_TV           equ 16
FP_SIZE         equ 18
FENCE_MAX       equ 32
FL_KEY          equ 0               ; long: camera depth of the top edge's middle
FL_FQ           equ 4               ; 6 words: the top edge (tx_fq)
FL_SURF         equ 16              ; the wall's surface (TS_SIZE bytes)
FL_H            equ FL_SURF+64      ; word: height above the edge
FL_SIZE         equ FL_SURF+68
FENCE_H         equ 57              ; fence height above the wall (game posts)
FENCE_ZN        equ 4               ; near plane of the fence clipping
FENCE_COL       equ 13              ; mesh colour: mid grey, seen on the sky, the road grey and the dark grandstands
FENCE_POST      equ 0               ; post colour
GR_Z            equ 7               ; turn guardrail: z of the game's lower rail
GR_H            equ 14              ; its height from the ground
GR_KFAR         equ 3               ; posts below this k, beams to k 6
TX_GMIN         equ 1024            ; G x 65536 below this: flat (far)
G_CAM_POS       equ G+$C13A26       ; view_cam_pos: x, y, z
G_SHAPE_BASE    equ G+$C1CA78       ; shape_base (A4 of the scene code)
G_RACE_MODE     equ G+$C093E0       ; race_mode: 0 practice, 1 qualifying, 2 race
F_POLYS_TRACK   equ G+$C1D188       ; shape_polys_track: moveq #0,d0; moveq #0,d2
F_PAT_A         equ G+$C1D2F0       ; shape_polys_pattern: cmpi.w #0,race_mode
F_PAT_B         equ G+$C1D2FE       ; its second entry: cmpi.w #2,race_mode
F_PAT_BODY      equ G+$C1D30A       ; the pattern polygons: moveq #0,d0; moveq #0,d2
G_COORD_POOL    equ G+$C0471A       ; coord_pool (A5)
TRACK_VTX_REL   equ $C230CA-$C1CA78 ; track_vertices from shape_base
TRACK_VTX_N     equ 2282

TS_GA   equ 0                       ; G at view pixel (0, 0), x 2^24
TS_GX   equ 4                       ; per pixel
TS_GY   equ 8                       ; per row
TS_UA   equ 12                      ; D . u axis, as G
TS_UX   equ 16
TS_UY   equ 20
TS_VA   equ 24                      ; D . v axis
TS_VX   equ 28
TS_VY   equ 32
TS_HS   equ 36                      ; h x 2^p, 4096-8191 (0: no texture)
TS_CXP  equ 40                      ; camera u x 2^p
TS_CYP  equ 44                      ; camera v x 2^p
TS_LUT  equ 48                      ; offset table of fade 0
TS_TEX  equ 52                      ; texture + 32768
TS_P    equ 56                      ; word: p
TS_GY12 equ 58                      ; word: (|GX| + |GY|) / 4096
TS_FP   equ 60                      ; word: footprint shift (p, walls p - 1)
TS_FLAT equ 62                      ; byte: colour without texture
TS_MESH equ 63                      ; byte: mesh mode (tspan), 0 none
TS_SIZE equ 64

TCH     equ 16                      ; tspan: pixels per chunk (dG/dx not 0); 32
TCHS    equ 4                       ; was 1-6 % faster but coarsened the fence
TL_ROW  equ 0                       ; tspan, word: view row of TL_RG-TL_RV
TL_LEFT equ 2                       ; word: pixels left
TL_KT   equ 4                       ; word: k from which u and v are unused
TL_HZ   equ 6                       ; word: haze: first pixel of each chunk
TL_N    equ 8                       ; word: pixels of a last, shorter chunk
TL_MASK equ 10                      ; byte: set: only where the ground markers are
TL_U16  equ 14                      ; long: u step per 16 pixels (row path)
TL_V16  equ 18                      ; long: v step
TL_RG   equ 22                      ; longs: G, D . u and D . v at x = 0 of
TL_RU   equ 26                      ; row TL_ROW of the surface TL_RS
TL_RV   equ 30
TL_RS   equ 34                      ; long: that surface
TL_X    equ 38                      ; word: x of TL_XG-TL_XV
TL_XG   equ 40                      ; longs: x times TS_GX, TS_UX and TS_VX
TL_XU   equ 44                      ; of the surface TL_RS (set whenever
TL_XV   equ 48                      ; the row terms are multiplied)
TL_SIZE equ 52
TROW_NONE equ $8000                 ; TL_ROW: no row (TROW0)
TB_SIZE equ 12                      ; tx_bnd entry: u, v (longs), k, class (words)
GND_MARK equ $11                    ; colour 16 + 1: the drawing never writes it

; Before the first tspan of a surface, and after any change to one: the
; row terms tspan kept are not of this surface. \1 = an address register,
; lost.
TROW0   macro
        lea tx_loc+TL_ROW(pc),\1
        move.w #TROW_NONE,(\1)
        endm
; Pass 2 of tspan: u, v, their steps and the jump into the pixel code for
; a chunk of D7 pixels from its two tx_bnd entries at A5. Leaves D0 =
; (16 - n) x 16, D2 = 16 - n. The pixel code keeps the u integer byte in
; D1 and its step in D7; D3 holds the u fraction in bits 24-31 and v (8.8)
; in the low word, D5 their steps the same way, so one add steps both and
; leaves the carry of the u fraction for the addx. Bits 16-23 take the
; carries out of v: both registers have them clear at the start of a chunk
; and a chunk has at most 16 pixels.
TUV     macro
        move.w TS_P(a3),d1
        move.l TB_SIZE(a5),d5           ; per pixel, 8.8 texels: the low
        sub.l (a5),d5                   ; word of the difference / D7,
        asr.l d1,d5                     ; truncated
        move.l TB_SIZE+4(a5),d6
        sub.l 4(a5),d6
        asr.l d1,d6
        cmp.w #TCH,d7
        bne.s .s\@
        tst.l d5                        ; a whole chunk: shifts
        bpl.s .u\@
        moveq #TCH-1,d0
        add.l d0,d5
.u\@:   asr.l #TCHS,d5
        tst.l d6
        bpl.s .v\@
        moveq #TCH-1,d0
        add.l d0,d6
.v\@:   asr.l #TCHS,d6
        bra.s .d\@
.s\@:   divs.w d7,d5                    ; shorter: a word quotient; when it
        bvc.s .w\@                      ; does not fit (D5 is kept) the long
        divs.l d7,d5                    ; divide
.w\@:   divs.w d7,d6
        bvc.s .d\@
        divs.l d7,d6
.d\@:   move.l (a5),d3                  ; start, 8.8 texels (low word)
        lsr.l d1,d3
        move.l 4(a5),d4
        lsr.l d1,d4
        moveq #TCH,d0                    ; copies of the pixel code to skip
        sub.w d7,d0
        move.w d0,d2
        lsl.w #4,d0
        move.w d3,d1                    ; u: integer byte in D1, its step
        lsr.w #8,d1                     ; in D7
        move.w d5,d7
        lsr.w #8,d7
        lsl.w #8,d3                     ; fraction and v
        swap d3
        move.w d4,d3
        lsl.w #8,d5                     ; their steps
        swap d5
        move.w d6,d5
        endm
TPX     macro                           ; one pixel, 16 bytes
        move.w d3,d0
        move.b d1,d0                    ; v, u
        move.b (a1,d0.w),d2
        move.b (a2,d2.w),(a0)+
        add.l d5,d3
        addx.b d7,d1
        endm
; Pass 1 of tspan: the chunk end at A5 from G, D . u and D . v (D5-D7):
; k, and u and v when k is below TL_KT. D0-D3 lost.
BEND    macro
        move.l d5,d0
        asr.l #8,d0
        cmp.l #TX_GMIN,d0
        bge.s .n\@
        moveq #7,d3                     ; far: flat
        bra.s .k\@
.n\@:   move.l d0,d2
        asr.l #4,d2                     ; G x 4096 (64 or more)
        move.l d2,d1
        mulu.w #410,d1
        clr.w d1
        swap d1                         ; / 160
        add.w TS_GY12(a3),d1
        muls.l TS_HS(a3),d1
        mulu.w d2,d2
        lsr.l #8,d2
        lsr.l #4,d2
        bfffo d2{0:32},d3               ; k: bits of f x 2^p >> TS_FP, f x
        lsl.l d3,d2                     ; 2^p = D1 / D2 (D2 not 0). The bits
        move.w d3,8(a5)                 ; of the quotient without the divide:
        bfffo d1{0:32},d3               ; both shifted up to bit 31, the
        lsl.l d3,d1                     ; difference of the shifts, one more
        sub.w 8(a5),d3                  ; when the shifted D1 is not below
        neg.w d3                        ; the shifted D2
        sub.l d2,d1
        moveq #0,d2
        subx.w d2,d3
        addq.w #1,d3
        bpl.s .q\@
        moveq #0,d3                     ; a quotient of 0
.q\@:   sub.w TS_FP(a3),d3
        cmp.w #7,d3
        bls.s .k\@
        spl d3                          ; below 0: 0, above 7: 7
        andi.w #7,d3
.k\@:   move.w d3,8(a5)
        cmp.w TL_KT(a4),d3
        bcc.s .e\@                      ; u and v unused
        move.l d6,d1
        asr.l #8,d1
        muls.l TS_HS(a3),d1
        divs.l d0,d1
        add.l TS_CXP(a3),d1
        lsl.l #8-TEX_SHIFT,d1
        move.l d1,(a5)                  ; u, 8.8 texels x 2^p
        move.l d7,d1
        asr.l #8,d1
        muls.l TS_HS(a3),d1
        divs.l d0,d1
        add.l TS_CYP(a3),d1
        lsl.l #8-TEX_SHIFT,d1
        move.l d1,4(a5)                 ; v
.e\@:
        endm
; Ground markers in the D2 (1-16) bytes at A0: to \1 when all are
; markers, to \2 when some are, on when none. D1 and D3 lost.
MCLASS  macro
        move.l #GND_MARK*$01010101,d3
        cmp.l (a0),d3
        bne.s .c\@
        cmp.l 4(a0),d3
        bne.s .c\@
        cmp.w #8,d2
        bls \1
        cmp.l 8(a0),d3
        bne.s .c\@
        cmp.l 12(a0),d3
        beq \1
.c\@:   move.w d2,d1
        subq.w #1,d1
.s\@:   cmp.b (a0,d1.w),d3
        dbeq d1,.s\@
        beq \2
        endm
; Row path of tspan: the chunk's start from the anchors A5 (u) and A6 (v)
; (x 2^(p + 8 - TEX_SHIFT), modulo 2^32: the bits RANCH takes are the same
; as from the unshifted sums) into D1 (u integer byte) and D3 (fraction
; and v as in TUV), anchors on by 16 pixels (D6 = p, A3 = the u step per
; 16 pixels). D4 lost.
RANCH   macro
        move.l a5,d3
        lsr.l d6,d3
        move.w d3,d1
        lsr.w #8,d1
        move.l a6,d4
        lsr.l d6,d4
        lsl.w #8,d3
        swap d3
        move.w d4,d3
        adda.l a3,a5
        adda.l TL_V16(a4),a6
        endm
TPXG    macro                           ; TPX with the ground colours, 12 bytes
        move.w d3,d0
        move.b d1,d0
        move.b (a1,d0.w),(a0)+
        add.l d5,d3
        addx.b d7,d1
        endm
GPXG    macro                           ; on a ground marker (D2), 18 bytes
        cmp.b (a0)+,d2
        bne.s *+12
        move.w d3,d0
        move.b d1,d0
        move.b (a1,d0.w),-1(a0)
        add.l d5,d3
        addx.b d7,d1
        endm
; MCLASS with the marker long in A2. D1 and D3 lost.
MCLASS2 macro
        cmpa.l (a0),a2
        bne.s .c\@
        cmpa.l 4(a0),a2
        bne.s .c\@
        cmp.w #8,d2
        bls \1
        cmpa.l 8(a0),a2
        bne.s .c\@
        cmpa.l 12(a0),a2
        beq \1
.c\@:   move.l a2,d3
        move.w d2,d1
        subq.w #1,d1
.s\@:   cmp.b (a0,d1.w),d3
        dbeq d1,.s\@
        beq \2
        endm
