Setting the Current Tool
------------------------

Since `DKToolController` is required to set one tool at a time, at some point your application will need to consider how this is achieved. Ultimately, it's a case of calling the -setDrawingTool: method of the tool controller. The tool controller will take into account the application's setting for whether the tool applies to just this view, the document, or globally for all documents. Your application will set the "scope" setting when it starts up, and is generally expected not to change it during the lifetime of the application (this is not harmful, just potentially confusing to a user). The default scope is per- document, which is likely to be the most typically used case.

`DKToolController` and `DKDrawingTool` together provide a multitude of ways in which a UI can easily interface to the tool selection mechanism. Which you decide to use is up to you - there's no "best" way - it will depend on your UI and application's needs.

`DKDrawingTool` has class methods to support a simple registry of tools. This allows you to associate a tool with a name, and retrieve that tool by name. By default, DK pre-registers a "standard" set of tools which you can use, replace, or simply ignore. They are there merely as a convenience. By default, the registered tools use the following names:

* Select
* Rectangle
* Oval
* Round Rectangle
* Round End Rectangle
* Text
* Ring
* Path
* Line
* Polygon
* Freehand
* Arc
* Wedge
* Speech Balloon
* Delete Path Point
* Insert Path Point
* Zoom

Most registered tools create the objects that their name suggests. "Select" is the default select and edit tool, "Zoom" is a view zooming tool, and the path insert/delete tools do what their names suggest.

You can replace any tool with another of the same name, or just register new tools with new names. `DKToolController` provides convenient methods for setting the current tool using its registered name. -setDrawingToolWithName: looks up the tool in the registry and sets it if it exists. Even more conveniently perhaps, there is also the -selectDrawingToolByName: action method. This can be targeted by any user interface object that supports the -title method (which includes `NSButtons`, `NSMenuItems` and `NSCells`). The title is set to the name of the registered tool, and simply by targeting that UI element on First Responder with this action, the UI will select the tool. Note - this approach is not ideal if the titles are visible to the user and you need to localise - in that case you need to register the tools using a localised name, or use a different method to select the tool.

Another approach is to set the tool as the representedObject of the UI object that pertains to it. You can then target First Responder with the action - selectToolByRepresentedObject: and the tool will be set to the sender's representedObject, if it is indeed a tool (if not an exception is raised). This approach has the advantage of not requiring the registry nor needing to use any part of the UI element as a special field, so cannot interfere with localisation.

If you have the `DKDrawingTool` object (representedObject or by any other means), a final way to set it is simply to call its -set method. This works by seeing if the current First Responder does indeed respond to the -setDrawingTool: method and passing itself. This can be extremely convenient for many kinds of applications. It's also a very easy way to programmatically set a tool without having to worry about the view, controller or anything else - just create the tool and set it. Of course this can fail if there is not a suitable First Responder.

Tools may also be assigned a keyboard equivalent, which can include any modifier flags you wish (except command, since those are detected by Cocoa as being menu shortcuts and are not passed through the usual key handling methods). `DKToolController` works with `DKDrawingTool` to look up tools if any of their keyboard equivalents are typed, and select them accordingly. Tools must be registered for the keyboard equivalents to operate.