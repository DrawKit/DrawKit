Text Shapes
-----------

`DKTextShape` is a `DKDrawableShape` subclass that is able to display a block of text. The text can have attributes applied to it as a single block either directly or through the attached style. Text can be editied by double-clicking it which creates a temporary editor. Text shapes respond to the font panel and other commands in the Text/Format menu directly (as long as they are not linked to a locked style).

Another (often more flexible) way to display text in a DrawKit drawing is to use a `DKTextAdornment` as part of an object's style.

If you drag text into a `DKObjectDrawingLayer`, it will create a `DKTextShape` to display it by default.