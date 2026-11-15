; Indianapolis 500 WHDLoad Slave V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; Surfaces (TS_SIZE) and the working storage of tspan.

tx_crlut:       dc.l 0                  ; texel -> pixel byte, 3 x 256 bytes
tx_wv:          ds.l 6                  ; U, V
tx_wn:          ds.l 3                  ; normal
tx_wnc:         ds.l 3                  ; normal in camera space
tx_up:          ds.w 3                  ; world up in camera space (depth, x', true y)
tx_n:           ds.w 3                  ; polygon: unit normal
tx_h8:          dc.l 0                  ; and the camera's height above it x 256
tx_gnd:         ds.b TS_SIZE            ; the ground (world z = 0)
tx_grs:         ds.b TS_SIZE            ; the grass (world z = 0)
tx_psurf:       ds.b TS_SIZE            ; the polygon being filled
tx_loc:         dcb.b TL_SIZE,0
        even
        cnop 2,4
        dc.w 0                          ; class of the chunk before the first
tx_bnd:         ds.b 21*TB_SIZE             ; tspan: per chunk end (TB_SIZE)
