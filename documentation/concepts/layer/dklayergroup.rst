DKLayerGroup
------------

`DKLayerGroup` is a layer subclass that can contain other layers, including other groups. It has no function other than as a container for layers, but is responsible for handling the drawing of the layers it contains in the correct order, and for implementing the Z-order altering commands and methods. `DKDrawing` inherits from this class, being the root of the layer tree.

Layers are stored in an ordered array such that index #0 is the top layer, and index #(count -1) is the bottom layer. While accessing layers by index is occasionally necessary, your application should avoid depending on layer stacking order where possible. To help in this respect, there are convenient methods such as -topToBottomEnumerator which will return an enumerator for iterating over the layers in the specified order.

One reason that layers are stored in the order stated above (and in this respect they happen to differ from the order that drawable objects are stacked within a layer), is to permit a user-interface such as one based on `NSTableView` to display layers naturally, that is, with the topmost layer at the top of the list, with no special effort. Earlier versions of DrawKit (prior to beta3) would cause such tables to appear upside-down unless they were coded to compensate. `DKLayerGroup` is able to detect and automatically reverse layer stacks in archives saved prior to this change.

Layer groups, being layers, are able to be locked and hidden, and when locked, changing the Z-order of layers, or adding and deleting layers is disabled. If a drawing as a whole is locked, the active layer can't be changed either.