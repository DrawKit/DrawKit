.. _drawables:

Drawables
=========

All drawn objects inherit from `DKDrawableObject`. This is a semi-abstract base class that provides an informal protocol that all drawables are expected to comply with. Drawables are responsible for drawing themselves on demand as well as implementing the lowest level of mouse event handling required to edit themselves interactively in a sensible fashion.
In general, applications can extend the features of `DKDrawableObjects` in two ways - at compile time or at runtime. Compile time extension is a classic case of subclassing `DKDrawableObject` or one of its existing subclasses. You would do this if you have particular needs that the standard objects do not cover. Runtime customisation is easier but of course more limited. This involves creating the styles and geometry of the paths and shapes you want using combinations of DrawKit's existing objects.
Essential properties shared by all drawables are:

* Its bounds rect. This is a rectangular area that by definition contains all of the drawing done by the object. It will occasionally extend well beyond the obvious visible edge of the object, but for efficiency should not be made excessively large. Drawables are responsible for calculating this bounds rect and not drawing outside it.
* Its position. A drawable has a definite location within the overall drawing, specified in drawing (Quartz) coordinates. The location can be defined by the object to be anywhere relative to its bounds - for example paths use their top, left point whereas shapes use their centre point, plus some variable offset.
* Its angle - some types don't have an angle so must always return 0. For types that do, this represents the rotation of the object about some point (typically its location).
* Its size - a width and height oriented in the direction of the angle.
* Whether the object is visible (drawn) or not, and whether the object is locked or not (editable).
* Its geometry - usually specified in terms of an owned `NSBezierPath` object.
* Its style - an object's style is responsible for its actual appearance (strokes, fills and other rasterizations).
* Its metadata - an attached optional dictionary of values. DrawKit is able to use and set some metadata itself but generally this is for application use.

`DKDrawableObject` supports two built-in user actions - copy and paste of the attached style.

`DKDrawableObject` provides many methods that are of general utility to all concrete subclasses, as well as a number of informal protocols (and stub methods that are part of these). A drawable is always required to draw wholly within the area defined by its -bounds method. It should calculate and return this region taking into account all possible graphical adornment that can be applied to the object. Thus the object's style contributes significantly to this calculation. Note that DrawKit doesn't enforce this region by clipping to it when drawing. This is done for performance reasons, since the need to save and restore the graphics context and text the clipping path can slow things down. As a result, if you do draw outside the bounds, trails of unerased pixels might be left when the object is moved or changed.

For best performance, the bounds should be kept as tight to the object as possible. When an object needs to be redrawn for any reason, its - notifyVisualChange method is called. This invalidates the object's bounds in all views that are currently displaying it. The resulting areas are repainted on the next event cycle (Cocoa coalesces all such update requests into a single update, and strictly limits drawing to these ares when repainting). For most typical operations on a drawable, -notifyVisualChange is called as necessary - you only need to call it if you need to force an update outside of changes made through the usual methods.

DrawKit's built-in concrete subclasses of `DKDrawableObject` fall roughly into two kinds - paths (`DKDrawablePath`) and shapes (`DKDrawableShape`).

.. toctree::
   :maxdepth: 2
   
   shapesandpaths
   imageshapes
   textshapes
   groups
   metadata