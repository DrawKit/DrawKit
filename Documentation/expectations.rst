DrawKit and You
===============

Cocoa programmers come in all shapes, sizes and levels of experience. If you're a beginner with Cocoa, using Drawkit effectively is likely to be a challenge; DrawKit is not a beginner's framework. However, DrawKit doesn't require knowledge of Bindings or Core Data, which are considered more advanced topics. DrawKit doesn't use Core Data, and it allows you to use Bindings or not as you wish, since it doesn't concern itself with how you implement your user interface.

To properly understand DrawKit, and this documentation, you will need to have some familiarity with Cocoa. Concepts such as memory management, how container classes and strings and many other parts of the Application Kit work is taken for granted, as is the model-view-controller paradigm, KVC, KVO and how views work. DrawKit is heavily based on Cocoa and Quartz graphics, and a good working knowledge of these technologies is highly advantageous. The beginner is directed to any of the many good books and online documentation available.

For the programmer already familiar with Cocoa, DrawKit should present no particular difficulties - it mostly works in the Cocoa domain, rather than Core Graphics or other framework, and employs no unusual techniques or tricky approaches. It makes use of Cocoa's classes for all of its storage, message passing and other needs. In one or two places it does extend Cocoa's classes for improved performance or efficiency (e.g. `NSUndoManager`) but by and large there should be no surprises. The lower level parts of the code make use of a number of categories on Cocoa classes, such as `NSBezierPath` and others.

While DrawKit is mostly "back end" or model, some programmers may prefer to approach it as a self-contained custom view, since that is probably how it
seems to the user, just as `NSTextView` is a view (but in fact consists mostly of non-view classes behind the scenes).