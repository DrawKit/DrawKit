Basic Shapes and Paths
======================

`DKDrawablePath`
----------------

`DKDrawablePath` is a concrete subclass of `DKDrawableObject` that draws a path. Its path is stored at the final size and position in the drawing that it occupies - there is no transformation done on the path at the time it is drawn. Paths are designed to be editable at the path control point level, so when selected these objects display draggable handles for every control point in the path.

Paths are best for objects that are long and thin, or have an irregular outline. Paths can be created in a number of "modes", which map to different kinds of typical creation tools - for example, bezier curves, straight lines, polygons, ars and wedges and freehand. Once created all these paths are edited in the same way, by dragging their control points. Thus an arc for example doesn't "know" its an arc once created, and will lose its shape if edited.

Path objects have no concept of overall rotation and always return an angle of zero.
Paths are drawn by their associated style objects exactly the same as for shapes.

`DKDrawableShape`
-----------------

`DKDrawableShape` is a concrete subclass of `DKDrawableObject` that draws a geometric shape defined by a bounding box. A selected shape features (as standard) eight "handles" or "knobs" arranged at the corners and mid-points of the box. Dragging the knobs changes the size of the box and the path of the shape is scaled to fit within.

Shapes also feature (as standard) a rotation knob which allows the object's angle to be simply dragged to a new value, and a centre position which sets the centre of rotation and origin for the object. This means that you are not required to have a separate "rotate" tool though DrawKit would certainly permit this approach if you prefer.

Shapes are best suited for objects that can be defined by simple scaling of a path to fit the bounding box - an irregular path can certainly be set and scaled to fit, but the detail of the path cannot be changed. However, `DKDrawablePath` and `DKDrawableShape` are freely interconvertible to each other with no loss of data (except rotation angle), so in fact you can simply convert to the other type and edit how you wish.

Shapes store their paths based on a unit square centred at the origin (i.e. a square 1.0 points wide and high, with its centre point at 0,0) and transform the path at that size to the final position, size and rotation angle when drawn. A shape's path is drawn by its associated style object.

`DKReshapableShape`
-------------------

`DKReshapableShape` is a simple subclass of `DKDrawableShape` that provides an opportunity for the path to be recomputed whenever the object's size changes. It is still best suited for geometric shapes but provides more flexibility - for example, a round-cornered rectangle will usually want to maintain a constant corner radius even as the overall shape is resized.

This object uses a helper object, an instance of `DKShapeFactory` to supply it with a new path on demand.