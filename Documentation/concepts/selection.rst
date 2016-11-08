The Selection
=============

`DKObjectDrawingLayer` is a subclass of `DKObjectOwnerLayer` that supports a selection. The selection is simply a set (literally an `NSSet`) of objects that are "selected", that is they are a member of the set. When drawables are drawn, their membership of this set is passed along as a boolean parameter so that the object is able to draw itself in a way that gives the user appropriate feedback that the object is indeed selected. For example shapes have "handles" (also known as "knobs") arranged around their bounding rectangles, and paths have draggable control points.

The selection permits objects to be more finely targeted for input. Some commands for example are able to operate on all of the objects in the selection. Some commands need to target one single unambiguous object*. `DKObjectDrawingLayer` provides support for doing both of these things - in the first case by implementing numerous "selection targeted" commands of its own, and in the second case by automatically forwarding messages it cannot handle itself to a single selected object which is able to respond. Once again this permits individual drawable objects to implement actions and methods as if it were an `NSResponder` in the responder chain.

*Note*: some specialised commands may operate on specific numbers of objects, typically two - for example joining paths.

Because `DKObjectDrawingLayer` is able to provide so many "selection targeted" actions, for ease of maintenance and understanding they have been split across several categories:

* `DKObjectDrawingLayer+Alignment` - handles a host of alignment actions
* `DKObjectDrawingLayer+BooleanOps` - handles high-level boolean (set) operations between multiple objects (using the optional third-party GPC library)
* `DKObjectDrawingLayer+Duplication` - handles a number of duplication actions

The main class implements high-level actions for cut, copy, paste, delete, move (by keyboard), Z-ordering, grouping and ungrouping, show, hide lock and unlock among others. Your app is free to ignore them if it doesn't need them or use them to get many useful features for next to no effort. All actions are undoable.

To support drag and drop, `DKObjectDrawingLayer` allows the object under the mouse location to be selected dynamically during a drag, if the object is able to receive whatever it is that is being dragged. The coordination of this is fairly complex but the upshot is that objects can be dragged into the layer, or in many cases into a drawable object within the layer. A drawable that receives the drag is itself responsible for accepting and ultimately handling the data that is dropped.

`DKObjectDrawingLayer` can be set either to treat selection changes as undoable actions in their own right, or not (and so selection changes are only undone as part of some other operation). Different applications will take different views on this.

DKKnob
------

`DKKnob` is a small helper class that is responsible for drawing the knobs or "handles" shown on selected paths and shapes. This helper object can be owned by a layer, or (by default, and because it subclasses `DKLayer`) the drawing. Showing the selected state of an object involves several steps - first, the object is added to the selection set in `DKObjectDrawingLayer`. Note that being "selected" means membership of this set, and nothing else - the state of the object itself does not change. However, an object is able to get notified when its selected "state" changes, and can also query this at any time.

When the owning layer draws the object, the selected state is passed as a boolean flag. The object responds by making additional drawing calls to display this state. This will usually involve making use of a `DKKnob` instance to perform the actual knob drawing. The basic highlight colour for the selection is also supplied by the layer. The involvement of the layer and `DKKnob` is to provide a consistent appearance for selections, but is also a place that is considered an early target for customisation.

`DKKnob` is asked to draw a knob of a given type at a certain point, does so, and returns. The knob "type" is a purely logical classification that `DKKnob` can use to choose one of several appearances for the knob. It is not in itself a specific appearance - a `DKKnob` subclass may decide to render all knob types the same for example. Knob types are defined in `DKCommonTypes`.h As a convenience, you can also pass some extra flags along with the knob type to indicate a locked object, or a disabled object for example. `DKKnob` is responsible for the interpretation of these flags and turning them into distinct visual renderings.

Note that clients of `DKKnob` (drawable objects) should not try to force `DKKnob` to draw one way or another. The point is to allow `DKKnob` to provide a consistent selection appearance when given any and all objects. Since `DKKnob` is drawing UI-related information (it is not part of the data model), it needs to take into account two aspects of the application's UI - the view's zoom scale and the view's window's active state. It does this by querying these via a simple formal protocol implemented by its owner - typically a `DKLayer`. The view's scale is used to compensate the knob's size for the zoom. By default, `DKKnob` does not cancel the zoom exactly - it allows a small amount of growth in proportion to the zoom (it grows about a third as fast) which gives better usability - the knobs grow, but not so large as to obliterate the content at large scales.
