; Indianapolis 500 WHDLoad Slave V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; State of the interpolation and the triple buffering.

tb_vars:    ds.l 6
valid:      dc.b 0
            even
tb_gauges3: ds.b GAUGE_SIZE
prev_cam:   ds.b CAM_BYTES
cur_cam:    ds.b CAM_BYTES
cam_fr:     ds.w 3              ; snapshot x, y, height: fractions (1/256)
cam_fi:     ds.w 3              ; and the whole values
prev_cars:  ds.w CARS*3
cur_cars:   ds.w CARS*3
saved_cars: ds.w CARS*3
car_fr:     ds.b CARS+1         ; blended track positions: fractions (1/256)
