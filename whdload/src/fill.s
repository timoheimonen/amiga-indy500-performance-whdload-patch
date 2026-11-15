; Indianapolis 500 WHDLoad Slave V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; CPU drawing (assembled with CPUFILL defined, build.py --cpufill): the root
; of its modules. fill_install (fill/install.s) chooses by CPU type:
;
;   fill/    The game's blits replaced with CPU code that writes the planes:
;            the background tail on every CPU, the fills, lines, car images
;            and the background on a 68040/060. The other CPUs keep the
;            blits; in the 3D view line_draw_to leaves its last blit running
;            (fill/defer.s).
;   chunky/  68040/060: the 3D view drawn as bytes in fast memory and
;            converted to the planes.
;   aga/     With INTERP: the 8 plane AGA view, its fills, sky and horizon.
;   geom/    With INTERP: recorded polygons, sub-pixel edges, clipping,
;            lines, posts and transforms that round to nearest.
;   tex/     With INTERP: textures of the ground, walls, fences, trees,
;            crowd and scenery.
;   cars/    With INTERP: exact car positions, 3D cars, liveries, sparks and
;            the track in the mirrors (car3d.i and livery.i are generated
;            data).
;
; 68000 instructions only, except the modules that switch to machine 68020:
; those are reached on a 68040/060 only.
;
; The modules are included in the order of the code in the slave. PC relative
; code reaches 32 KiB, so the order is part of the layout: keep it (bgtab and
; c2ptab of chunky/c2p.s before aga/, the 3D car buffers last).
;
; The CPU reads chip memory written by the blitter. This relies on chip memory
; not being data cached: with the MMU (default on a 68040/060) WHDLoad marks
; BaseMem non cacheable and the Slave and ExpMem copyback, without it the
; data cache is off. On a 68020/030 the slave makes BaseMem cacheable for the
; instruction cache only, with the data cache off (slave.s, cache_setup).

        include "fill/defs.i"
        include "fill/install.s"
        include "fill/defer.s"
        include "fill/poly.s"
        include "fill/sprite.s"
        include "fill/background.s"
        include "chunky/hooks.s"
        include "fill/bgtail.s"
        include "fill/line.s"
        include "chunky/view.s"
        ifd INTERP
        include "aga/fill.s"
        else
        include "chunky/fill.s"
        endif
        include "chunky/sprite.s"
        include "chunky/c2p.s"

        ifd INTERP
        include "aga/display.s"
        include "aga/c2p8.s"
        include "aga/sky.s"
        include "geom/macros.i"
        include "geom/record.s"
        include "aga/levels.s"
        include "tex/defs.i"
        include "tex/frame.s"
        include "tex/span.s"
        include "tex/ground.s"
        include "tex/wall.s"
        include "tex/tree.s"
        include "tex/crowd.s"
        include "tex/face.s"
        include "tex/fence.s"
        include "geom/clip.s"
        include "geom/spans.s"
        include "cars/proj.s"
        include "cars/car3d.s"
        include "geom/xline.s"
        include "geom/post.s"
        include "geom/xform.s"
        include "aga/horizon.s"
        include "geom/xform_world.s"
        include "geom/scan.s"
        include "tex/math.s"
        include "tex/poly.s"
        include "tex/build.s"
        include "tex/atlas.s"
        include "tex/noise.s"

        ; Data, in this order.
        include "aga/switches.s"
        include "cars/state.s"
        include "cars/livery.i"
        even
        include "cars/car3d.i"
        even
        include "tex/state.s"
        include "tex/materials.s"
        include "tex/surfaces.s"
        include "tex/offsets.s"
        include "cars/buffers.s"
        include "cars/spark.s"          ; code after the data: the 32 KiB reach
        include "cars/mirror.s"
        endif
