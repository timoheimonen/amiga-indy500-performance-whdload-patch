; Indianapolis 500 WHDLoad Slave V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; Macros shared by the modules of geom/ and cars/.

HSUM    macro                           ; D4 = matrix words \1, \2, \3 . D1-D3
        move.w \1(a4),d4
        muls.w d1,d4
        move.w \2(a4),d0
        muls.w d2,d0
        add.l d0,d4
        move.w \3(a4),d0
        muls.w d3,d0
        add.l d0,d4
        endm
HSUPD   macro                           ; row \1, x \2 into the spans \3, \4
        cmp.w (\3,\1.w*2),\2
        bge.s .u\@
        move.w \2,(\3,\1.w*2)
.u\@:   cmp.w (\4,\1.w*2),\2
        ble.s .v\@
        move.w \2,(\4,\1.w*2)
.v\@:
        endm
