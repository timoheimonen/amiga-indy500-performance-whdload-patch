; Indianapolis 500 WHDLoad Slave V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; 3D car buffers, last to keep the other data in reach of (pc).

        even
c3_ord:         ds.l 2*C3_NPMAX         ; parts far to near: depth, address
c3_v:           ds.l 6*C3_NVMAX         ; vertices (c3_vert)
