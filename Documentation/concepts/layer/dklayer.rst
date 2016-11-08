DKLayer
-------

`DKLayer` is the semi-abstract base class for all layers. It provides some basic state variables common to all layers, and numerous useful methods for updating part of themselves (via the drawing, its controllers and views), handling basic mouse events, and other utility methods. The properties common to all layers are:

* its name (visible in a UI, perhaps, otherwise not used in DrawKit)
* whether it is visible or not
* whether it is locked or not
* what group it belongs to
* the "selection" colour value
* the `DKKnob` helper class that draws the selection handles for objects 
* arbitrary metadata attached by the user

Useful utility methods that can be used by all layers include:

* getting informed when the layer is made active or inactive
* displaying a small information window near the mouse point with some value of your choice
* updating itself or any part of itself
* supporting a general drag/drop functionality
* supporting contextual menus

One problem facing designers of applications that have multiple layers is making sure the user is clear about which layer is active. One way to help distinguish layers is by the use of colour, so the "selection" colour is provided by `DKLayer` to assist. Primarily intended for showing selection highlights in object layers, it is available to all layers. Classes such as `DKGuideLayer` use this as a default colour for its guides, for example. A simple mechanism is used to initially assign a different colour to each layer as it is initialized, but of course you can set it to whatever you like. The same colour is used as a background to the information window, again reinforcing which layer the information originates from. The DK demo application has a user interface for setting this colour directly, in its layers palette.

The information window is a handy feature that can be used to help supply direct feedback for some kinds of operations. For example when an object is resized the info window is used to display its current width and height. In general this tooltip-like window should be used for numeric information that takes up one, or at most two lines. As it is displayed in front of everything, it must not be so large as to obscure the content. Using the info window is easy - simply supply it with a string and a position in local coordinates, and `DKLayer` will do the rest. When you are finished with it, ask the layer to hide it.

`DKLayer` is able to respond to mouse events originating in a view and passed to it when it is the active layer. This passing on of events is performed by `DKViewController`. In general, layers should be designed to respond to their own mouse events only if their needs are simple and easily handled in a self-contained manner. So `DKGuideLayer` implements these methods for dragging guides, but the much more complex requirements of selecting and manipulating objects in a `DKObjectDrawingLayer` is handled by a variety of different tool objects instead.

Layers can be locked, which prevents their content being changed. Subclasses of `DKLayer` are responsible for checking and honouring this state to ensure that locking is consistent. Likewise, hidden layers should not be edited either, as the results cannot be seen and so the user should be gently prevented from giving themselves a nasty surprise. Hidden layers are automatically not drawn, but subclasses of `DKLayer` need to check for this state to prevent editing. The method -isLockedOrHidden usefully covers both states that should disallow editing.

Layers may or may not be required to appear in printed output. "Structural" layers such as `DKGuideLayer` probably shouldn't be, whereas of course layers with actual content should be. This can be easily set using the -setShouldDrawToPrinter: method. Subclasses usually set this to some appropriate default themselves.

A layer's name can be a useful way in a user interface to tell layers apart. `DKLayer` retains a name, and all layer subclasses set this to some useful default, but DrawKit itself does not use or interpret the name - it is entirely for the benefit of your user interface.
