Fills
=====

`DKFill`
--------

`DKFill` provides for a basic colour fill using a solid colour, an image-based pattern or a gradient. Its properties include:

* its colour (including image-based pattern colours)
* its shadow, if any
* its gradient, if any

Note that image-based patterns are entirely handled by Cocoa's default implementation. They are useful for emulating the patterns used in older graphics software (e.g. MacDraw) but they are not hugely flexible. Their main advantage is good performance. DrawKit also has `DKFillPattern` for a different approach to patterns, where a "motif" image is placed at regular intervals with many parameters being adjustable.

`DKGradient`
------------

`DKGradient` is an object that implements Quartz's gradient shading with a higher-level API. Here it is used as a property of a `DKFill`, where it takes priority over any solid colour fill value. `DKGradient` is compatible with GCGardient as used in the Gradient Panel framework, so you can freely interchange one for the other if you want to use the GP user interface in your application.

`DKHatching`
------------

`DKHatching` is a `DKRasterizer` subclass that fills a path with a series of straight lines. This class is invaluable for CAD-type drawing applications and is surprisingly versatlie, especially when used in pairs or groups. Properties include:

* the line width
* the line colour
* the line dash (set using a `DKLineDash` object)
* the line spacing
* the line angle
* line cap and join styles
* the line phase or lead-in offset

`DKFillPattern`
---------------

`DKFillPattern` is a subclass of `DKPathDecorator` since it leverages the same image caching techniques for performance reasons. However its disposition is rather different. The problem with Quartz's basic pattern support via `NSImage` and `NSColor` is that it's hard to control very precisely and alignment is always to the base coordinates not to the object being filled. `DKFillPattern` works differently - it takes an image (called the "motif") and repeats it at intervals within the path's interior. The image's PDF representation is used wherever possible so a vector image remains a vector image even when used as a pattern motif. The scaling, spacing and angle of the motif is controllable, as is the angle of the pattern as a whole and the alternate row and column offset values. Because this object can do a lot of intensive drawing work at times, it is able to use a low-quality image of the motif during live updates for better performance, then switch to the PDF motif for better quality when the rapid redrawing ceases.

The motif is always positioned based on the path's centre point so it remains stable as the path is resized and moved in the drawing.

`DKZigZagFill`
--------------

`DKZigZagFill` subclasses `DKFill` to provide a zig-zag outline to the filled region. As with `DKZigZagStroke`, wavelength, amplitude and spread can be
controlled.
