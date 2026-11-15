; Indianapolis 500 WHDLoad Slave V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; Tables of the scenery materials (tex/face.s, tex/atlas.s).

; Materials of the scenery (FM_SIZE each): colour, tex_on bit, flags,
; table; box of corner A; S u, S v; origin in the atlas (u, v); world z
; of the v origin; flat texel and the mip level from which it is used.
fm_tab:
        dc.b 0,6,FMF_FLAT,0             ; grandstand roofs from below
        dc.w 300,14200,6000,7950,325,410
        dc.w 128,128,0,2,0
        dc.b 2,3
        dc.b 0,7,FMF_V,1                ; the scoring pylon
        dc.w 6530,6590,6940,6996,-10,445
        dc.w 128,128,0,2,0
        dc.b 1,4
        dc.b 11,7,FMF_V|FMF_ZMIN,2      ; the pagoda's glass
        dc.w 3880,4040,6050,6205,255,445
        dc.w 256,256,50,2,0
        dc.b 10,4
        dc.b 7,7,FMF_V,3                ; the pagoda's walls
        dc.w 3880,4040,6050,6205,165,445
        dc.w 256,128,50,50,170
        dc.b 8,3
        dc.b 8,7,FMF_V,4
        dc.w 3880,4040,6050,6205,165,445
        dc.w 256,128,50,50,170
        dc.b 8,3
        dc.b 8,7,0,5                    ; the suites on the back straight
        dc.w 9400,11600,-7550,-7300,20,190
        dc.w 128,128,0,146,30
        dc.b 7,3
        dc.b -1
        even
; Texels 1-15 of each table: colour, level.
fm_ramp:
        dc.b 0,9,0,12,0,15,1,1,1,3,1,5,1,7,1,9 ; roofs
        dc.b 1,11,8,9,8,12,13,6,13,9,3,9,15,9
        dc.b 0,9,0,15,8,3,8,6,8,9,13,6,13,9,7,8 ; pylon: greys between
        dc.b 14,3,14,6,15,3,15,6,14,8,14,10,15,10 ; black and the digits
        dc.b 1,6,1,8,1,10,13,8,11,0,11,2,11,4,11,6 ; glass
        dc.b 11,8,11,9,11,10,11,11,11,12,11,13,15,9
FMR     set 2
        rept 14                         ; walls, colour 7
        dc.b 7,FMR
FMR     set FMR+1
        endr
        dc.b 7,15
FMR     set 2
        rept 14                         ; colour 8
        dc.b 8,FMR
FMR     set FMR+1
        endr
        dc.b 8,15
        dc.b 0,12,0,15,8,5,8,7,1,7,1,8,1,9,1,10 ; suites
        dc.b 1,11,8,9,13,7,13,8,13,9,13,11,15,8
        even
; Rectangles of the atlases (FP_SIZE each), in order.
FPH     macro                           ; atlas H: texel, u0, v0, w, h, pu, tu, pv, tv
        dc.b 0,\1
        dc.w \2,\3,\4,\5,\6,\7,\8,\9
        endm
FPV     macro                           ; atlas V
        dc.b 1,\1
        dc.w \2,\3,\4,\5,\6,\7,\8,\9
        endm
fm_paint:
        FPH 2,0,0,256,144,1,1,1,1       ; roofs: sheet
        FPH 5,0,2,256,142,1,1,24,2      ; purlins
        FPH 7,0,0,256,144,16,2,1,1      ; beams
        FPH 10,0,0,256,4,1,1,1,1        ; front edge
        FPH 6,0,144,256,96,1,1,1,1      ; suites: glass
        FPH 9,0,161,256,3,1,1,1,1       ; reflections
        FPH 9,0,194,256,3,1,1,1,1
        FPH 9,0,218,256,4,1,1,1,1
        FPH 12,0,146,256,76,8,1,1,1     ; mullions
        FPH 13,0,146,256,1,1,1,1,1      ; sills
        FPH 13,0,167,256,1,1,1,1,1
        FPH 13,0,200,256,1,1,1,1,1
        FPH 1,0,164,256,3,1,1,1,1       ; floor slabs
        FPH 1,0,197,256,3,1,1,1,1
        FPH 12,0,221,256,3,1,1,1,1      ; top frame
        FPV 1,0,0,48,256,1,1,1,1        ; pylon: black
        FPV 2,0,204,20,8,1,1,1,1        ; header
        FPV 15,0,212,20,4,1,1,1,1       ; bar
        FPV 10,48,0,160,48,1,1,1,1      ; pagoda glass
        FPV 9,48,2,160,8,1,1,1,1
        FPV 12,48,30,160,8,1,1,1,1
        FPV 4,48,26,160,1,1,1,1,1       ; transom
        FPV 3,50,2,145,36,12,1,1,1      ; mullions
        FPV 3,50,2,145,1,1,1,1,1        ; frames
        FPV 3,50,37,145,1,1,1,1,1
        FPV 8,48,48,160,144,1,1,1,1     ; pagoda walls
        FPV 6,48,77,160,109,1,1,18,1    ; floor lines
        FPV 7,50,50,145,136,24,1,1,1    ; joints
        dc.b -1
        even
fm_cars:        dc.b 4,30,1,5,20,3,6,14,2,18,7,9 ; pylon: car numbers by
                dc.b 22,10,25,15,11,12,28,19,21,81 ; position (made up)
                dc.b 41,16,70,29,91,8,40,51,23,26,33
        even
fm_font:        dc.w $7B6F,$2C97,$73E7,$73CF,$5BC9 ; digits 0-9: 5 rows of 3 bits
                dc.w $79CF,$79EF,$7249,$7BEF,$7BCF ; from the top, bit 14 first
        even
