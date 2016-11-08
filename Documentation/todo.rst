Inherited To Do List
====================

The original to-do list inherited from DrawKit 1.0b7 (22 July 2007):

- Align Edges To Grid of group doesn't do the right thing if group is rotated
- Check poly create loop possible error (insert nil attempt)
- Moving first point of any subpath is either not correct or asserts when constraining to angle.
- Inspector base should send selection change notification when document closes and/or when new one opens to clear out any cached values for objects in the closed drawing. (Not sure on this, but get a crash at times).
- Text shapes in groups stretch instead of rewrap.
- Hitting a thin line is still quite difficult especially when the view is zoomed out. (Should the hit bitmap account for scaling??? hard to do). (Improved by making the hit bitmap at least 4 (not 2) wide)
- Text objects should show "double-click" message as a placeholder when created initially empty.
- Add bounds property to layers so they can be spatially arranged. (or at least think through the implications)
- Throughout Cocoa's documentation, whenever an NSNotification message is defined, it mentions at least two things: What the NSNotification "object" will be and, if the NSNotification has a "userInfo" dictionary, what keys it may contain. Similar documentation needs to be provided on NSNotification messages throughout DrawKit.
