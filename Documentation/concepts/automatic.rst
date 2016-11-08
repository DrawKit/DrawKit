Automatic Drawing Construction
------------------------------

DrawKit suppports a special mode of operation that is implemented by `DKDrawingView`. This convenient feature constructs all of the necessary drawing "back-end" for a view if you don't bother to make one yourself. This is meant to be analogous to Cocoa's `NSTextView` class - if you do not set up the text "back-end" yourself it does it for you, so you can go right ahead and start editing text immediately. DrawKit provides the same approach to drawings - drop a `DKDrawingView` into a nib and you will get a complete working drawing editor with no set up at all. The drawing size is set to the view's bounds. In this case the `DKDrawing` is owned by the view, which is fine because the weak references within `DKViewController` ensure that there is no retain cycle created.

This mechanism works when `DKDrawingView`'s drawRect: method is called - if at that point there is no drawing, `DKDrawingView` creates one, adds layers to it and then carries on as normal. The upshot is a very simple and easy way to drop a drawing editor into your application.

The drawback of this approach is the same as the one for `NSTextView` - it might not be what you want. While it's a very typical setup, possible drawing editors are likely to be even more varied than possible text editors, so chances are you'll want something else. For ultimate control you'll want to set up the "back-end" by hand, just as you would for `NSTextView` - for other cases you can let the automatic setup be done and then modify it, or override methods in `DKDrawingView` that make the automatic `DKDrawing` and supply the set-up you want.

Functionally, there is no difference in terms of what DK can do when it's set up this way, though because you are not using `DKDrawingDocument` you
would have to handle file opening and saving yourself.