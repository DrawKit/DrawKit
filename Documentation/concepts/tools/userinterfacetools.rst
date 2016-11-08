User Interface Tools
--------------------

Often it is convenient for an application to have tools that do not modify the drawing itself but merely control aspects of the user interface. An obvious example is a zoom tool, which merely changes the scale (and possible the scroll position) of the view, it does not affect the content. DrawKit supports this type of tool as well - in fact `DKZoomTool` already supplies a tool for zooming the view. There is no compelling reason that a tool needs to work with target objects that are supplied by the tool controller - it is free to simply ignore that and do something else, which is how the zoom tool works.
