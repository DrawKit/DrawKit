Basics of Object Editing
------------------------

By and large, drawable objects are able to edit themselves. This is sensible as it avoids the need to have lots of different controller classes with overlapping responsibilities just to deal with the object variations. Instead, objects are given fairly low-level events such as mouse dragged, and given the context of where the mouse is within the object, do the expected thing.

Drawables typically have numerous places or clickable regions within them that are sensitive to the mouse and have specific behaviours when clicked or dragged. For example a path's every control point is draggable, and each one will have a slightly different effect on the path. A shape's handles or knobs each resize the shape in a slightly different way. In order for a drawable object to tell what the user clicked, it assigns a "partcode" to every single separately sensitive place. A partcode is just a number (int) which identifies the point clicked - it is entirely private to the object and is only interpreted by it.

Two partcodes are reserved and are interpreted outside of an individual drawable instance - that of 0 meaning "no part was hit" and -1 meaning "the entire object was hit" or "no special partcode was hit".

When the mouse goes down initially in an object, the partcode of the hit is determined by the target object itself, and returned to the caller (the tool or tool controller, for example). If the partcode is anything other than 0 or -1, it is known to be private to the object so all that will happen is that the same value is passed back in subsequent mouse-dragged and mouse-up handlers. 0 or -1 values might be interpreted. For example -1 might trigger a move operation, and 0 might trigger the start of a drag selection operation.

If the target object is passed back the partcode in a mouse drag call, it alone knows what to do with it. For example, a shape might identify the partcode as meaning the rotation knob was hit, so it carries out a rotation operation based on the current mouse point.