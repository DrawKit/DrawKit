.. _tools:

View and Tool Controllers
-------------------------

DrawKit's controllers sit between a drawing and its views. The controllers are owned by the drawing; the views are owned by their superviews and ultimately their windows. In DrawKit, there is one controller per view.

The basic controller, `DKViewController`, provides basic support for forwarding input events from the view to the active layer within the drawing, and for responding to requests from the drawing to update the view. `DKToolController`, a subclass of `DKViewController`, adds the concept of a settable tool, allowing the user to interactively create, select and edit objects.

.. toctree::
   :maxdepth: 2
   
   viewcontroller
   objectediting
   toolcontroller
   creatingnewobjects
   selectionandediting
   objectmodifyingtools
   userinterfacetools
   settingthecurrentool
