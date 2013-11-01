The layer containment hierarchy
-------------------------------

Layers, based on the `DKLayer` semi-abstract base class, are organised into hierarchical groups. `DKLayer` is an object that provides support for drawing content on demand, and possibly providing some basic mouse event handling. In DrawKit, everything you see in a drawing is drawn in a layer, including any grid or guides. Layers have a front-to-back (Z) ordering that you can change at will. This means that whether a grid is placed in front of or behind other content is your simple choice - just put the layers in the order you require.

Layers are hierarchical. They can be, but are not required to be, organised into related groups. `DKLayerGroup` is a `DKLayer` subclass that can contain any number of other layers. Layers that are grouped together can be hidden or shown as a group for example. However, even grouped layers share the root drawing's overall size. `DKLayerGroup` provides methods for (undoably) changing the order of the layers that it immediately contains.
`DKDrawing` is itself a subclass of `DKLayerGroup`, because it is at the root of the layer containment hierarchy.

Principal properties of `DKLayer` include whether it is visible or not, locked (locked layers cannot have their content edited), whether the layer is included in printed output, its name and some properties that affect the appearance of selected objects in that layer.
In some respects layers can be though of a little like views - they draw stuff when requested and mouse events are directed to them.