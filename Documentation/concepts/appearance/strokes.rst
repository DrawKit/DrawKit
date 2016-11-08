Strokes
=======

`DKStroke`
----------

`DKStroke` is a concrete subclass of `DKRasterizer` that provides for a straightforward stroke of a path. Its properties include:

* its width
* its colour
* its shadow, if any
* its dash, if any (set using a `DKLineDash` object)
* line cap and join styles

`DKArrowStroke`
---------------

`DKArrowStroke` subclasses `DKStroke` to add arrow heads to a stroked path. A variety of arrow head styles are supported, and this class also supports "smart" arrow heads that can be used on curving paths to good effect.

`DKRoughStroke`
---------------

`DKRoughStroke` subclasses `DKStroke` to add random variation to the stroke width along the rendered path. This gives a much more naturalistic and "hand drawn" look to a stroke, which can be invaluable in some kinds of illustration work.

`DKZigZagStroke`
----------------

`DKZigZagStroke` subclasses `DKStroke` to provide a path that zig-zags about the nominal path. The wavelength, amplitude and "spread" (roundness of the peaks) can all be adjusted.

Dashes
------

Dashes are handled by a small helper class called `DKLineDash`. This simply stores a dash's properties and applies them to a path on demand.
The use of an object to store a dash makes life a lot easier when it comes to handling dashes in a user interface, for example.
