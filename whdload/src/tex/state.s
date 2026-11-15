; Indianapolis 500 WHDLoad Slave V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; State of the textures. Also here, to stay in reach of the PC relative code:
; the span, clipping and projection buffers of geom/ and cars/proj.s and the
; tables of the trees, the crowd and the guardrails.

tx_tex:         dc.l 0                  ; asphalt + 32768
tx_wtex:        dc.l 0                  ; wall texture + 32768
tx_gsh:         dc.l 0                  ; ground colours, fade 0 + 32768
tx_mtex:        dc.l 0                  ; fence mesh + 32768
tx_grtex:       dc.l 0                  ; grass + 32768
tx_flist:       dc.l 0                  ; fences of the frame (TFLIST_OFF)
tx_fn:          dc.w 0                  ; their number
tx_lut:         dc.l 0                  ; offset tables (colour 7, fade 0)
tx_m:           ds.w 9                  ; view_matrix, halving undone
cam_f:          ds.w 3                  ; cam_view: camera x, y, z fraction (1/256)
cam_c:          ds.w 3                  ; in camera space (depth, x', true y) x 256
cam_m:          ds.l 3                  ; . view_matrix / 256 (transform sums)
cam_mt:         ds.l 3                  ; . tx_m / 256
cam_z0:         dc.l 0,0,0              ; hcorner: no fraction
tx_da:          ds.l 9                  ; D x, y, z at (0, 0); per pixel; per row
tx_wc:          ds.w 12                 ; wall: corners A, B, C, D (world)
tx_fq:          ds.w 6                  ; fence: top edge (world)
tx_fc:          ds.l 3                  ; its height (camera space)
fd_h:           dc.w FENCE_H            ; fence_draw: height above the edge
tx_fa:          ds.l 3*10               ; clipping
tx_fbb:         ds.l 3*10
tx_fp:          ds.w 2*10               ; projected corners
fc_zn:          dc.l FENCE_ZN*16        ; fclip: near plane (1/16 unit)
hs_y0:          dc.w 0                  ; hscan: first and last row
hs_y1:          dc.w 0
hs_l:           ds.w VIEW_H             ; first and last x per row
hs_r:           ds.w VIEW_H
hp_a:           ds.l 3*(PE_MAX+5)       ; clipping
hp_b:           ds.l 3*(PE_MAX+5)
hp_p:           ds.l 2*(PE_MAX+5)       ; projected corners: x x 16, y x 256
hl_c:           ds.l 6                  ; xline: the two ends (depth, x', y')
cp_c:           ds.l 3                  ; car_proj: the car (depth, x', y')
cp_w:           ds.w 4                  ; the game's point (x, y, z, heading)
cp_d:           ds.w 3                  ; the step to the next one x fraction
tx_fl:          ds.w VIEW_H             ; left and right x per row
tx_fr:          ds.w VIEW_H
tx_weu:         ds.w 2                  ; its u axis (world x, y, 2.14)
tx_wnu:         ds.w 3                  ; its unit normal (2.14)
tx_trtex:       dc.l 0                  ; tree leaves (R0) + 32768
tr_ext:         ds.l 4                  ; tex_tree: u min, max (x 2^14), z min, max
tr_reg:         dc.l 0,128,-32768,-32640 ; leaves by k: R0-R3 from R0
tr_cl:          ds.w 8                  ; tex_build: a cluster
tr_sq:          ds.w 170                ; tex_build: 16 sqrt(i)
tr_lut5:                                ; tree levels: colour 5, colour 10
TRL     set 0
        rept 16
        dc.b ((TRL-9)&15)*16+5
TRL     set TRL+1
        endr
tr_lut10:
TRL     set 0
        rept 16
        dc.b ((TRL-9)&15)*16+10
TRL     set TRL+1
        endr
tr_on:          dc.b 0                  ; the dither polygon gets leaves
cr_on:          dc.b 0                  ; the pattern polygon gets the crowd
        even
tx_crtex:       dc.l 0                  ; crowd (R0) + 32768
cr_reg:         dc.l 0,$10000,$20000,$30000 ; crowd by k: R0-R3 from R0
GR_POST         equ $08                 ; guardrail post: colour 8, level 9
gr_rows:        dc.b $80,$80,$80,$80,$80 ; z 0-4: holes (posts)
                dc.b $08,$2D,$0D,$2D    ; z 5-8: lower beam (colour 13 levels
                dc.b $80,$80            ; 11 and 9, its lower edge colour 8)
                dc.b $08,$2D,$0D,$2D    ; z 11-14: upper beam
CM_EDGE         equ 1                   ; crowd texels: cr_mat entries
CM_SEAT         equ 2
CM_STAIR        equ 3
CM_HEAD         equ 4                   ; 5 heads
CM_SHIRT        equ 9                   ; 16 shirts
CM_N            equ 25
cr_mat:         dc.b 13,9               ; 0: unused (a hole); colour, level
                dc.b 1,9                ; shadow
                dc.b 13,9               ; seat
                dc.b 3,10               ; stairs
                dc.b 6,4,7,12,6,6,1,8,14,5 ; heads: dark, light, tan, dark hair, blond
                dc.b 4,10,12,10,9,11,11,10 ; shirts
                dc.b 14,10,6,10,15,11,10,10
                dc.b 5,12,15,9,13,12,2,11
                dc.b 14,8,12,8,15,10,11,8
cr_sh:          dc.b 0,-1,-3            ; brightness: colour 7, 8, 0 patterns
cr_head:        dc.b CM_HEAD,CM_HEAD+1,CM_HEAD+2,CM_HEAD+3 ; heads by 3 random bits
                dc.b CM_HEAD+4,CM_HEAD+1,CM_HEAD+2,CM_HEAD+1
tw_hor:         dc.b 0                  ; tw_plane: flat axes (tex_face)
tw_given:       dc.b 0                  ; tw_plane: corners in tx_wc (gr_seg)
        even
tx_wev:         ds.w 2                  ; flat: v axis (world x, y, 2.14)
tx_fhtex:       dc.l 0                  ; materials: atlas H (R0) + 32768
tx_fvtex:       dc.l 0                  ; atlas V (R0) + 32768
tx_flut:        dc.l 0                  ; their tables, FM_NLUT x 256 bytes
tx_fk:          dc.w 7                  ; tspan: the material's FM_KMAX
fm_ext:         ds.l 2                  ; tex_face: u min, max (x 2^14)
                ds.w 1                  ; z min
