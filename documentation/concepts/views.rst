Views
=====

The architecture of DrawKit is designed to support any number of views "into" a drawing. These views might actually display the drawing itself, or just present some aspect of it to the user in some fashion - an example could be a table view showing the arrangement of the layers. By using `DKViewController` as a basis for your views' controllers, you can easily make any sort of view or user interface for the DrawKit drawing.

For views such as the layer UI mentioned, it is worth using a `DKViewController` because it's much easier to get informed about events and so forth that involve objects deep within the drawing without having to dig down through the drawing structure yourself. For example when any layer or drawable object changes state the view controller is informed directly, so any interface attached to it is able to quickly get the update triggers it needs.

Of course there are numerous notifications that you can also make use of, if that makes more sense. For example a global "inspector" type interface may prefer to rely on notifications since it can get them from all documents/drawings at once. The `DKDrawKitInspectorBase` works this way, for example. For a complete list of available notifications, see xxxx [missing - ed].

General Views
-------------

For the case of actually viewing and interacting with the drawing, DrawKit provides the `DKDrawingView` class. This provides some useful features that most drawing programs are likely to want to take advantage of, such as rulers, zooming in and out of the drawing, and of course acting as an initial first responder for all actions and events that ultimately end up targeted at the active layer and any objects it contains. `DKDrawingView` interfaces to `DKViewController` for handling all the usual mouse events, and provides a few other conveniences, such as drawing page breaks for the current printer setup. In general for actually viewing the drawing, you should use `DKDrawingView`, or possibly a subclass of it, though there's relatively little functionality that should be part of the view itself - mostly subclassing the controller is likely to be the better bet for customising interactivity with `DKDrawing` and its layers.

`DKDrawing` owns its controllers but it does not own or keep a reference to any view. Views are, as normal, owned by their superviews and ultimately their windows. There is also no limit on the number of view/controller pairs that a `DKDrawing` can support - you can easily set up a split view of the same drawing, or have views in different windows viewing the same drawing. All that is required is that each view has an associated `DKViewController` added to the drawing. Each view that views the same drawing will be automatically updated when necessary - if you are working with objects in one view, any others will display changes live as you work.

`DKDrawingView` is generally used in a "flipped" state, meaning that the Y coordinate increases in a downward direction. This is common to many drawing programs and is familiar. However you can use DrawKit in an "unflipped" state where Y coordinates increase in an upward direction. Because this needs to be consistent across all views associated with a drawing, this is actually set in `DKDrawing` - `DKDrawingView` queries this value and returns it in the - isFlipped method.

Specialised views
-----------------

Because DrawKit provides no user interface of its own except the interactivity with objects, it is designed to make as few assumptions about how your user interface might work as possible. However because many typical drawing-type applications often have quite similar user interfaces, DK does provide some support, particularly for inspector-type views.

`DKDrawkitInspectorBase` is a simple class that subclasses `NSWindowController`, and can be used by your own inspector controllers if you wish. All it does it to provide some standard hooks for most of the useful state change notifications coming out of drawkit, such as the active document changing, the active layer changing, and the selection changing. It leaves the handling and display of the information entirely up to your application.