Bug Fixes list, 22/6/07
=======================

List from DrawKit 1.0b7.

1.  ~~Undo String for Layer Reordering not present.~~
2.  ~~Creating a new shape selects the guide layer if the initial hit is on a guide, preventing the object from being created.~~
3.  ~~Combine needs to work on any number of objects, not just 2.~~
4.  ~~All path creation loops do not autoscroll~~
5.  ~~Boolean ops do not save selection for Undo.~~
6.  ~~Groups do not unarchive correctly.~~
7.  ~~Ungroup doesn't save the selection for Undo.~~
8.  ~~Duplication offset isn't recorded by dragging a duplicated shape.~~
9.  ~~Path decorator image isn't properly updated from its previous one.~~
10.  ~~Selection should be a set, not an array.~~
11.  ~~Images not drawn to hit bitmap, so are not selected by marquee.~~
12.  ~~Groups should not allow distort/shear transforms as they don't operate in the right way for groups.~~
13.  ~~Renderers in subgroups are not observed correctly after loading in from file, and subsequently crash when removed from being observed by the style.~~
14.  ~~Menu items for alignment ops should be validated~~
15.  ~~Need a better way to dynamically synchronize the rulers to any grid we set~~
16.  ~~Initial click for creating shapes not aligned to grid~~
17.  ~~BBox seems excessively large for text objects with no stroke~~
18.  ~~Inspectors fail to pick up selection on app resume.~~
19.  ~~Shared styles problem after reload of saved drawing~~
20.  ~~Reset drag exclusion rect when drawing size/margins change~~
21.  ~~Revert doesn't work~~
22.  ~~Creating objects at very high zooms prefers rotation knob over drag corner.~~
23.  ~~Delete command doesn't check for eligible objects~~
24.  ~~Changing layer lock state doesn't update inspectors (needs to notify as if selection changes even though it doesn't)~~
25.  ~~Need Arc as well as Wedge drawing~~
26.  ~~Need a way to connect paths whose end points coincide~~
27.  ~~Need Path add point tool to specify type~~
28.  ~~Converting formatted text to path/shape loses formatting (bold, italic, etc)~~
29.  ~~Option-drag of curve control point should constrain colinearity; option-shift-drag for independent movement.~~
30.  ~~Can't insert points on single orthogonal line path (bbox is empty)~~
31.  ~~Path decorator doesn't decorate closePath segments (also affects arrowed lines on closed paths)~~
32.  ~~Text attributes don't affect text shapes correctly if detached from the style attributes.~~
33.  ~~Shapes should not be selectable by interior click if they have no fill (as per paths).~~
34.  ~~Need a way to see/select shapes without a style~~
35.  ~~Text hit testing is broken due to offscreen image being flipped.~~
36.  ~~Text hit test bitmap not invalidated when text attributes are changed.~~
37.  ~~Improve behaviour when creating a shape with a path and a non-zero rotation angle. (BBox is not accurately aligned).~~
38.  ~~Shift-select with marquee does not work.~~
39.  ~~Need notification from style library for styles added/removed and demo needs to update lib menu on this.~~
40.  ~~Reset Bounding Box on group doesn't work correctly (ok to simply disable this op for groups)~~
41.  Align Edges To Grid of group doesn't do the right thing if group is rotated
42.  ~~Convert To Path for group should be disallowed~~
43.  ~~Add/Delete layers should be undoable (??)~~
44.  ~~Text Shape ignores style set by tool if ignore is YES - should probably set itself from style initially then ignore from then on.~~
45.  ~~Hide selection should only occur when the drag actually starts, not on mouse down~~
46.  ~~Locked state of style ignored for changes to text attributes~~
47.  ~~Text Label Renderer incorrectly offsets labels when shapes are resized (not factoring offset)~~
48.  ~~Location target needs to scale down when view is highly zoomed~~
49.  ~~15° angular constraint on path control points would be useful~~
50.  Check poly create loop possible error (insert nil attempt)
51.  ~~Zero-length paths should not be added to drawing/create undo task~~
52.  ~~Can't pull control point of first point on path if it's on top of initial point (or indeed any cp1 that lies on top of the previous segment's end point).~~
53.  ~~Selecting very thin paths is still too difficult (thicken offscreen lines)~~
54.  ~~Join paths too fussy about alignment of points~~
55.  ~~"Snap to other object" would be damn handy, if not too hard. (In fact it was hard, but did it anyway).~~
56.  ~~Optionally auto-calculate polar dupe so that exact fit in circle is achieved.~~
57.  ~~Join paths needs colinearise option, and to work on any number of paths~~
58.  ~~Hit testing of groups not working (can't reproduce at the moment, maybe PPC issue)~~
59.  ~~Closing doc crashes app if quality timer is still to complete.~~
60.  ~~Really need to implement flip V and H as distinct operations.~~
61.  ~~Still getting bad partcodes for some paths.~~
62.  ~~Pagebreaks should be a view behaviour and not draw to printer~~
63.  ~~Pagebreaks should update if visible and page setup is changed~~
64.  ~~Do not draw location target during resize operation on shape~~
65.  ~~Double-click on text shape broken by recent double-click handler change~~
66.  ~~Duplicating a text shape leaves text attributes behind if style locked. (In fact this bug is due to changing text attributes in edit mode, then ignoring locked state of style when ending the edit).~~
67.  ~~Image shapes do not draw the hit bitmap and hence can't be selected. (Can't reproduce on Intel - seems to be PPC only bug)~~
68.  ~~Can't unlock locked object (menu command dimmed).~~
69.  ~~End point of single line has incorrect partcode (-1)~~
70.  ~~Horizontal distribution of paths misaligns the intermediate objects incorrectly in vertical direction (may be other similar bugs).~~
71.  ~~Ungroup should maintain its Z-position within the layer of the group (?)~~
72.  ~~Auto-hit to select layer needs to be a lot smarter - only if active layer doesn't want to use click should it operate. (Solution adopted is to make the current tool a class member instead of instance data member, and to only allow autoactivation if selection tool is set - this much improves the usability as desired but is a minimal change to the code. Tool access is still via instance methods should a subclass wish to do it differently).~~
73.  ~~Snap to guide is a bit too strong - overwhelms snap to grid for the adjacent grid line making it hard to position edges near, but not touching, a guide. (Solved by using smarter logic when applying all snap types, so that the smallest snap of several possible is preferred).~~
74.  ~~Snap to other objects needs to consider edges, not just knobs, to be more useful.~~
75.  ~~Undo state still goes bad sometimes (unclear which action triggers this).~~
76.  ~~Combine (and poss. other boolean-type ops) should maintain Z-order of item in layer if non-ambiguous.~~
77.  ~~Constrain of line segment edits to 15° angles on shift key would be useful.~~
78.  ~~Snap to Grid is not disabled by control key when dragging objects(s).~~
79.  ~~Snap to object path ignores closePath segments.~~
80.  ~~Irregular polygon adds unwanted extra point when path closes.~~
81.  ~~Bezier path doesn't auto-close properly (new bug).~~
82.  ~~Hit-target area for location cross is way too big, making it awkward at high zooms.~~
83.  ~~Need "Show All Hidden Objects" command, rather than rely on selection.~~
84.  Moving first point of any subpath is either not correct or asserts when constraining to angle.
85.  Inspector base should send selection change notification when document closes and/or when new one opens to clear out any cached values for objects in the closed drawing. (Not sure on this, but get a crash at times).
86.  ~~Multiple object drag should snap to guides (This is too hard under the current architecture, which is troubling).~~
87.  Text shapes in groups stretch instead of rewrap.
88.  ~~Hidden layers need to act locked.~~
89.  ~~Flip commands do not actually flip the shape, only the canonical path.~~
90.  ~~Undo action name for transform operations not correctly set.~~
91.  ~~Adding or Removing renderers from a style should be undoable. (Further bug: undoing this needs to carefully preserve renderer order - partial solution as long as there are no nested groups - DKRastGroup is not undo aware at present).~~
92.  ~~Converting to/from paths and shapes loses metadata.~~
93.  ~~Changing styles on a shape doesn't immediately update the hit bitmap.~~
94.  Hitting a thin line is still quite difficult especially when the view is zoomed out. (Should the hit bitmap account for scaling??? hard to do). (Improved by making the hit bitmap at least 4 (not 2) wide)
95.  ~~Group bounds should be calculated from logical bounds (not apparent) for accuracy of measurement of group sizes. (This change also requires that group's apparent and bbox be calculated by accumulating the bounds of the components, not just assuming from calculated logical bounds.~~
96.  ~~Style swatch cache is not invalidated by changes to renderers wihin it, so the swatch becomes out of synch.~~
97.  ~~Constraining aspect ratio of shapes doesn't allow mouse to go to the left of (or if above, right of) the anchor point.~~
98.  ~~Convert to Outline no longer works on Leopard (bad context - null).~~
99.  ~~Dragging a marquee in a blank document (or in any doc where selection doesn't change) dirties the document unnecessarily.~~
100.  ~~Resizing shapes on top of others when "snap to other objects" is on doesn't work smoothly - snapping interferes grossly with drag.~~
101.  ~~Image Vectorisation broken on Leopard (bad bitmap creation params).~~
102.  ~~Allow DKKnob to operate at the layer level rather than the drawing level (optionally).~~
103.  Text objects should show "double-click" message as a placeholder when created initially empty.
104.  Add bounds property to layers so they can be spatially arranged. (or at least think through the implications)
105.  ~~Reimplement flipping of groups - no longer works correctly with changes to the way flipping works for normal shapes~~
106.  Throughout Cocoa's documentation, whenever an NSNotification message is defined, it mentions at least two things: What the NSNotification "object" will be and, if the NSNotification has a "userInfo" dictionary, what keys it may contain. Similar documentation needs to be provided on NSNotification messages throughout DrawKit.
107.  Rework copyright notice headers and add svn repo keywords to all files
108. 