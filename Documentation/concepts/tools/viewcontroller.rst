View Controller and the Flow of Events
--------------------------------------

Initially a user's inputs are all directed to the key view, which is the first responder in the responder chain. These user inputs can be mouse clicks and drags, selecting commands from menus, typing on the keyboard, or dragging data items into the view. `DKDrawingView` forwards all messages it cannot respond to to its controller, including forwarding all mouse and flagsChanged events.

`DKViewController` basically forwards everything on again, this time to the active layer as determined by querying the `DKDrawing` instance that the controller belongs to. However it does intercept the Layer Z-ordering action messages and invokes the relevant methods on `DKDrawing` to handle them, as well as providing an optional "click to activate" methodology for setting the active layer. `DKViewController` also implements autoscrolling of a mouse dragged event using a timer.

Depending on the class of the current active layer, the forwarded messages and mouse events may be handled or forwarded again to "the selection" or a single selected object.

When a `DKToolController` is used in place of a `DKViewController` (which is usually the case), the currently set tool acts as a filter for mouse events such that the basic events are translated into meaningful operations that can be applied to the active layer or objects within it. What happens depends on the class of tool set, and `DKToolController` merely coordinates the calling of the various methods that the tool protocol provides. The tool itself performs its operations on the active layer according to its design.

Typically a tool will target a specific object and pass events or messages to it to get its job done. Tools are generally quite lightweight in that they don't do
a lot of heavy lifting on behalf of objects - they identify the target object and then mostly simply pass on events to it in the proper sequence.
