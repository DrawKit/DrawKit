Object Layers
=============

Object layers are layers that contain graphical objects that can be operated on individually, as distinct from layers that present some fixed type of content such as the grid. Most of the "interesting" content (user created) in a DrawKit application is likely to live in an object layer.

Object Owning Layers and Drawables
----------------------------------

Object layers are functionally split into two classes - `DKObjectOwnerLayer` and `DKObjectDrawingLayer`, which subclasses it.

The names may be slightly misleading, as a `DKObjectOwnerLayer` is perfectly able to draw the objects it owns. The name is meant to reflect the main functional purpose of the class - that is, to own objects. In DrawKit, the term 'object' is rather ambiguous and open to misinterpretation, so a graphical object that has its own distinct identity is called a "drawable". Every single shape, path or other distinct selectable item in DrawKit is a subclass of the semi-abstract drawable base class, `DKDrawableObject`.

`DKObjectOwnerLayer` provides the basic ownership of drawables, and is responsible for maintaining them as a related set. It also deals with the front- to-back (Z) ordering of the drawables it owns, and provides methods for changing these. Like `DKLayerGroup`, it provides user-action methods that can be simply hooked to menus to provide commands such as Move To Front, Move Backwards, etc.

`DKObjectDrawingLayer` is a subclass of `DKObjectOwnerLayer` that brings the concept of a selection into the picture. The reason for the functional split is twofold: first, one of convenience in that even with the split, both are quite large classes in terms of number of methods, so this keeps it manageable. Second, it permits a DrawKit developer to subclass at either level if they wish, giving a more fine-grained opportunity to do this.
`DKObjectOwnerLayer` undoably supports the adding and removing of objects to the layer, changing their Z-order and other basic operations that do not require the concept of a "selection". It also handles the essential requirements of handling drags of external data into the layer.