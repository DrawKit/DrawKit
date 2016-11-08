.. _layer:

The Drawing and Layers
----------------------

`DKDrawing` is the class at the heart of DrawKit, and is at the root of the model. The concept of DrawKit is based on that of the "drawing" as a draughtsman might think of it - a single large "sheet of paper" on which drawing can be done. The principal property of a drawing is its size - how big it is in its horizontal and vertical dimensions.

DrawKit internally uses Quartz coordinates throughout, and there are approximately 72 Quartz points per inch of drawing space, or 28.35 points per centimetre. Of course a drawing may be viewed on the screen at any scale so this does not necessarily mean one inch on the screen. However it should equal one inch in any printed output. Externally, DrawKit translates any coordinate values it displays to the current grid, which is set up entirely by you the programmer, who in turn may let the user set this. Thus from a user interface perspective, DrawKit works in "real world" values such as millimetres, inches, kilometres or what have you.

The drawing consists of any number of layers which are overlaid on top of each other. Each layer is transparent by default and exactly covers the full drawing area. Layers are where actual graphical content is generated - the drawing itself is merely a container for its layers. All drawings must have at least one layer to have any content (at least this is true as long as we are not discussing subclassing `DKDrawing`).

The drawing object represents a single drawing with all of its content. Typically an application might associate each document with a single drawing, though it is not required to do so - because `DKDrawing` is a separate object you could have more than one per document, or share a drawing among several though this would be unusual. A drawing can be viewed through as many views as you wish. A view can display the drawing content, or it might simply present a user interface to some aspect of the drawing - a list of its layers, for example. In any case, each view will be associated with a suitable controller, and the drawing maintains a list of all of the controllers that work with that particular drawing. The drawing owns the controllers while they exist, and each controller is associated with exactly one view.

.. toctree::
   :maxdepth: 2
   
   hierarchy
   dklayer
   dklayergroup
   dkdrawing
   active

Specialised Layers
------------------

.. toctree::
   :maxdepth: 2

   grid
   guides
   imageoverlay
   info