; Indianapolis 500 WHDLoad Slave V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; Game addresses, ExpMem offsets and constants of the CPU drawing.

F_POLY_FILL     equ G+$C1474E       ; move.w span_ymax,d6
G_SPAN_YMIN     equ G+$C1742C
G_SPAN_YMAX     equ G+$C1742E
G_SPAN_LEFT     equ G+$C17564       ; span_right at +$1FC
G_MASK_FIRST    equ G+$C17858       ; per x*2: mask of the first word
G_MASK_LAST     equ G+$C17AD8       ; per x*2: mask of the last word
G_WORD_OFFSET   equ G+$C17D58       ; per x*2: byte offset of the word
G_COLOUR        equ G+$C17430       ; four plane words from set_colour
G_DRAW_BACK     equ G+$C17418       ; back buffer
FILL_PLANE      equ $1F40
VIEW_TOP        equ $3C0            ; row 24, first row of the 3D view
VIEW_LONGS      equ 124*40/4        ; one plane of the 3D view
VIEW_W          equ 320             ; chunky view: one byte per pixel
VIEW_H          equ 124
CHUNKY_OFF      equ EXPMEM_SIZE+2*VIEW_W        ; after the stack, 2 spare rows
P2C_OFF         equ EXPMEM_SIZE+$A000           ; p2ctab, 256 x 8 bytes
        ifd INTERP
MB_OFF          equ EXPMEM_SIZE+$9E000          ; mask blit cache, after the
        else                                    ; textures (INTERP)
MB_OFF          equ EXPMEM_SIZE+$B000
        endif
        ifd INTERP
C2PT_OFF        equ EXPMEM_SIZE+$C9000          ; c2p table, 65536 x 2 longs
SKYP_OFF        equ EXPMEM_SIZE+$149000         ; sky pixel pairs, 2 x 1024 words
        endif
MB_N            equ 16                  ; mask blit cache entries
MB_MAXW         equ 256                 ; words x rows of a cached blit
MB_KEY          equ 0                   ; long: mask address (0: free)
MB_STRIDE       equ 4                   ; long: distance of the planes
MB_WORDS        equ 8                   ; word: words per row
MB_ROWS         equ 10                  ; word: rows converted
MB_PL           equ 16                  ; copy: mask, planes 0-3 (2 x MB_MAXW each)
MB_C            equ MB_PL+5*2*MB_MAXW   ; per pixel: colour, 0 where the mask is clear
MB_NM           equ MB_C+16*MB_MAXW     ; per pixel: $ff where the mask is clear
MB_SIZE         equ MB_NM+16*MB_MAXW
F_BG_TAIL       equ G+$C14E12       ; background: wait, then the plane 3 blit
F_LINE_DRAW     equ G+$C144D6       ; move.l d2,-(sp); move.w d0,$C17428.l
F_LINE_TAIL     equ G+$C146E4       ; the end point becomes the start; rts
G_LINE_X0       equ G+$C17424       ; start point (line_move_to)
G_LINE_Y0       equ G+$C17426
G_LINE_X1       equ G+$C17428       ; end point
G_LINE_Y1       equ G+$C1742A
G_LINE_CON0     equ G+$C1743C       ; BLTCON0 of the start point
F_FILL_PATTERN  equ G+$C1485C       ; move.w span_ymax,d6
F_FILL_DITHER   equ G+$C14982       ; move.w span_ymax,d6 (after the $AAAA5555 entry)
G_PATTERN_BASE  equ G+$C1AF86       ; long: pattern image (4 planes, $438 apart)
G_PATTERN_X     equ G+$C1AF8C       ; word added to the pattern offset
G_SETPAT_MID    equ G+$C14488       ; set_pattern: the pattern of colour 8
G_SETPAT_LIGHT  equ G+$C14494       ; and of the others (7)
G_DITHER        equ G+$C1D442       ; two dither words
G_DITHER_ROW    equ G+$C17440       ; dither word of the current row
PATTERN_PLANE   equ $438
F_CAR_SPRITE    equ G+$C14FE2       ; movem.l a2-a6,-(sp)
F_SET_COLOUR    equ G+$C1443C
G_SPR_COLOURS   equ G+$C1AF74       ; the car's two body colours (for 12 and 9)
G_SPR_Y         equ G+$C1AF76
G_SPR_COUNT     equ G+$C1AF78       ; byte: source rows until one is dropped
G_SPR_RELOAD    equ G+$C1AF79
G_SPR_FIRST     equ G+$C188D8       ; per x*2: mask of the first word
G_SPR_LAST      equ G+$C19058       ; per x*2: mask of the last word
G_SPR_OFFSET    equ G+$C197D8       ; per x*2: byte offset of the word
F_BACKGROUND    equ G+$C14CC6       ; add.w d0,d0; add.w d1,d1; bmi.w
G_BG_HORIZON    equ G+$C14C50       ; per d0: horizon row of the view
G_BG_BAND       equ G+$C14C8E       ; per |d1|: half height of the band
F_VIEW_CALL     equ G+$C08EB0       ; frame_loop: jsr view_setup
F_VIEW_SETUP    equ G+$C1334C
F_CARS_CALL     equ G+$C0914E       ; frame_loop (cockpit view): jsr draw_cars
F_DRAW_CARS     equ G+$C2906A
G_VIEW_FLAGS    equ G+$C093E3       ; bit 0: cockpit view with instruments
F_DEBRIS_CALL   equ G+$C0915A       ; frame_loop (cockpit view): jsr $C35104
F_DEBRIS_CALL2  equ G+$C091BC       ; frame_loop (outside views): jsr $C35104
F_DEBRIS        equ G+$C35104       ; wall hit debris (shape_polys_world)
F_WHEELS_CALL   equ G+$C0919C       ; frame_loop (cockpit view): jsr $C15AC2
F_WHEELS        equ G+$C15AC2       ; front wheels, steering wheel top, lines
F_MASK_BLIT     equ G+$C15BE2       ; move.w #$fca,BLTCON0: masked 4 plane blit
F_VIEW_DONE     equ G+$C09144       ; frame_loop after the 3D view: btst.b #0,$C093E3.l
F_LINE_REGS     equ G+$C1453C       ; line_draw_to: move.w d1,BLTBMOD (first register)
F_LINE_WAIT     equ G+$C14726       ; line_draw_to: the wait after the last plane
F_FILL_REGS     equ G+$C1479A       ; poly_fill: move.w #$5ac,BLTCON0(a0)
F_PATTERN_REGS  equ G+$C148A2       ; poly_fill_pattern: move.w #$7ac,BLTCON0(a0)
F_DITHER_REGS   equ G+$C149F0       ; poly_fill_dither: move.w #$5ac,BLTCON0(a0)
F_POLY_EDGE     equ G+$C1B0F6       ; move.w 8(a3,d7.l),d0; add.w d0,d0
F_POLY_BEGIN    equ G+$C1473C       ; move.w #$400,span_ymin
F_REL_BEGIN     equ G+$C1D288       ; shape_polys_rel (clouds): jsr poly_begin
G_VIEW_MATRIX   equ G+$C13A36       ; per world axis: depth, x', y' (2.14)
F_XT_X          equ G+$C13542       ; xform_track_vertex: products of an x value
F_XT_Y          equ G+$C13598       ; of a y value
F_XT_Z          equ G+$C135EE       ; of a z value
F_XW_SUM        equ G+$C136F4       ; xform_vertex_world/rel: the three sums
G_MATRIX_HALVED equ G+$C13A24       ; -1: view_matrix halved
F_SINCOS        equ G+$C0D2B0       ; D0 angle -> D2 cos, D1 sin (1024 steps)
G_COS_TABLE     equ G+$C0D2CA       ; 1024 words, 2.14
F_VS_YAW        equ G+$C13362       ; view_setup: jsr sincos of the yaw
F_VS_ROLL       equ G+$C13376       ; of the roll
F_VS_PITCH      equ G+$C13390       ; of the pitch
F_BG_CHOICE     equ G+$C08EB6       ; frame_loop: background from the tables or streams
G_LINE_PREV     equ G+$C1D446       ; line primitives: record of the vertex before
F_XFORM_TRACK   equ G+$C13514       ; D7 vertex -> D6 record, D0 outcode (flags)
F_XFORM_REL     equ G+$C1368A       ; camera relative vertex
F_XFORM_WORLD   equ G+$C136BA       ; world vertex
F_LINES_TRACK   equ G+$C1CAA6       ; line primitives (lines_ranged enters at +$E)
F_LINES_WORLD   equ G+$C1CBD4
F_LINES_REL     equ G+$C1CD02
F_LINE_PAIRS    equ G+$C1CE96       ; draw_line_pairs
F_XFORM_SKY     equ G+$C137B2       ; xform_sky_point: the point of track_to_world
F_TRACK_TO_WORLD equ G+$C2B17E      ; D0 track position, D1 lateral x 16
G_T2W           equ G+$C2B358       ; its world x, y, z and track heading
F_DRAW_CAR      equ G+$C2951E       ; draw_car: A2 = draw list entry + 2
F_CAR_PROJ      equ F_DRAW_CAR+$2C  ; its jsr xform_sky_point
G_CAR_HEAD      equ G+$C2B360       ; draw_car: the car's heading (track + own)
G_BANK_TAB      equ G+$C11E7A       ; track_shape_at: bank factor at the turn ends
F_SHAPE_TAB     equ G+$C0CB92       ; track_shape_at: movea.l #G_BANK_TAB,a1
C3_FAR          equ 400             ; 3D cars nearer than this depth (units)
SP_FAR          equ 2000            ; sparks nearer than this
C3_LOD          equ 150             ; the near model (car3d.i level 0) below
F_CAR_COLS      equ F_DRAW_CAR+$14  ; move.w $1a(a0),G_CAR_COLS
F_AERIAL_COLS   equ G+$C296F4       ; draw_car_aerial: the same
G_CAR_COLS      equ G+$C2B362       ; the car's two body colours (12, 9)
LSJSR   macro                       ; jsr \2 at \1
        CHECKW \1,$4eb9
        CHECKL \1+2,\2
        endm
