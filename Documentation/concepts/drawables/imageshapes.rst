Image Shapes
------------

`DKImageShape` is a subclass of `DKDrawableShape` that displays an image in addition to any stylistic properties it has. The image is displayed within the bounding rectangle of the shape, oriented to its angle. This class provides basic image support within DrawKit, though for another way to use images, you can also add a `DKImageAdornment` to any object''s style.

If you drag an image file into a `DKObjectDrawingLayer`, it will create a `DKImageShape` to display it by default.

A `DKImageShape` has a style as normal, which can be shown in front of or behind the image. For example you could set up a style with a stroke to act as a frame or border for the image, or add text, etc.