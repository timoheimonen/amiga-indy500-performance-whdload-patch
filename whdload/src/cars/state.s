; Indianapolis 500 WHDLoad Slave V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; State of the 3D cars and the liveries.

c3_ok:          dc.b 0                  ; car_proj: a 3D car for the next image
c3_obj:         dc.b 0                  ; its car object (0-32), -1 none
c3_fcol:        dc.b 0                  ; c3_face: the colour byte
sp_ok:          dc.b 0                  ; car_proj: this car may have sparks
        even
c3_bank:        dc.w 0                  ; the bank of the road at the car
c3_head:        dc.w 0                  ; the car's heading
c3_rel:         ds.w 3                  ; its track point - the camera (world)
c3_org:         ds.l 3                  ; its ground point (as hcorner's)
c3_ax:          ds.w 9                  ; its axes (forward, right, up) in world
c3_m:           ds.w 9                  ; in camera space, per camera axis
c3_cm:          ds.w 3                  ; the camera in the car's axes (1/16)
c3_stamp:       dc.w 0                  ; per car: vertices done (c3_vert)
c3_mb:          dc.l 0                  ; level of detail: vertices,
c3_pt:          dc.l 0                  ; parts,
c3_np:          dc.w 0                  ; their number
c3_cols:        ds.b 8                  ; colour bytes per slot (car3d.i)
liv_cols:       dc.l 0                  ; liv_set: primary, secondary, accent,
liv_ok:         dc.b 0                  ; helmet; set for this car
sp_act:         dc.b 0                  ; sp_check: this car's burst (seed)
sp_st:          ds.b CARS               ; per car object: 0 outside the
                                        ; zones, 1 inside without sparks,
                                        ; else the seed of its burst
        even
sp_s:           dc.l 0                  ; its distance into the zone (1/256)
sp_p:           dc.l 0                  ; sp_pos: the car along the lap
sp_rnd:         dc.w $1989
sp_v:           dc.w 0                  ; sp_pos: the car's speed
        even
