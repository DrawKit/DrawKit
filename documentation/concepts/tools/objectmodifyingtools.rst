Object Modifying Tools
----------------------

DrawKit's tool protocol permits tools to do any kind of operation to an object if a special tool is needed. The only built-in one that is provided is the `DKPathInsertDeleteTool`, which as its name suggests, adds new points to an existing path or deletes existing points. It can only operate on `DKDrawablePath` objects, attempting to use it on any other type of object is a no-op.

An application can define other similar types of tools if necessary, by subclassing `DKDrawingTool` and following the protocol's rules. Tools can be made to modify any object's attributes, copy attributes from one object to another, add objects to layers, or just do things to the user interface.
