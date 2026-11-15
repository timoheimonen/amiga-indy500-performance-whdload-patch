; Indianapolis 500 WHDLoad Slave V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; Switches of the extras of the AGA view (tex_on, tex_on2) and the texture
; state of the frame and the polygon (tx_ok, tx_mode).

tex_on:         dc.b 255                ; bit 0: asphalt, 1: walls, 2: fences, 3: grass, 4: trees, 5: crowd,
                                        ; 6: grandstand roofs, 7: buildings
tx_ok:          dc.b 0                  ; frame values valid
tx_mode:        dc.b 0                  ; polygon: 1 own plane, 2 ground, 3 wall, 4 grass,
                                        ; 5 material (tex_face)
tex_on2:        dc.b 15                 ; bit 0: turn guardrails (gr_seg),
                                        ; 1: posts with a width (pst_chk),
                                        ; 2: 3D cars (c3_car),
                                        ; 3: team liveries (liv_set)
opt_cur:        dc.w 0                  ; opt_off as applied (opt_apply)
sky_flat:       dc.b 0                  ; set: every sky level is colour 11
sp_off:         dc.b 0                  ; set: no sparks under the cars
sp_prob:        dc.b 20                 ; chance of a burst per pass (/256)
mir_off:        dc.b 0                  ; set: no track in the mirrors
        even
