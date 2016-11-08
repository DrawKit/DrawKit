Model, View and Controller
--------------------------

In common with most object-oriented designs, DrawKit is divided into three major functional areas - the model layer, the controller layer and the view layer. The majority of DrawKit's classes reside in the model layer, with some overlap between this and the controller layer when it comes to handling direct interaction with objects. Distinct "tools" for creating and manipulating objects reside in the controller layer, and the view(s) through which the graphics are displayed are of course part of the view layer.

The user of a DrawKit application interacts with DrawKit through one or more views. In common with any Cocoa-based application, if the view is key, then keyboard, mouse and menu events are targeted at the view. From there they are processed by the controllers and affect the state of the model. Changes in the model's state, if they affect the visible appearance of an object, are in turn used to mark areas of the view for update.

In DrawKit, objects that are part of the model are responsible for both drawing themselves and to a large extent, handling their own editing via the mouse. The controller layers coordinate both of these processes. In turn the appearance of an object (how it is actually painted) is handled by its style, and this is separate from the geometry of the object (its path or shape). Each functional area is handled by a distinct class of object. This makes DrawKit both powerful and flexible as well as easier to manage from a maintenance or customisation standpoint.

At the centre of the DrawKit architecture stands `DKDrawing`, the "drawing" object. Understanding DrawKit begins here.