/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2015
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>

@class DKDrawableObject, DKLayer;

@protocol DKDrawingTool

- (NSString*)actionName;
- (NSCursor*)cursor;
- (NSInteger)mouseDownAtPoint:(NSPoint)p targetObject:(DKDrawableObject*)obj layer:(DKLayer*)layer event:(NSEvent*)event delegate:(id)aDel;
- (void)mouseDraggedToPoint:(NSPoint)p partCode:(NSInteger)pc layer:(DKLayer*)layer event:(NSEvent*)event delegate:(id)aDel;
- (BOOL)mouseUpAtPoint:(NSPoint)p partCode:(NSInteger)pc layer:(DKLayer*)layer event:(NSEvent*)event delegate:(id)aDel;

@end

// informally, a tool can also implement this, which will be called from DKToolController if the object does respond to it.

//- (void)			drawRect:(NSRect) inView:(NSView*) aView;

//==== NOTE ABOUT UNDO ====

// when a tool performs undoable actions, it doesn't mean it necessarily WILL perform an undoable action. Since complex tasks are usually
// grouped, there needs to be a way to start a group at the right time, if and only if there WILL be something undoable. Unfortunately this
// is required because NSUndoManager has a bug where opening and closing a group but doing nothing in between records a bogus undo task.

// Thus a tool can signal to its delegate that the operation it is about to perform will create an undo task, and so the delegate can
// open an undo group if it needs to. Note that tools can also turn off undo registration temporarily if they see fit.

/** @brief The drawing tool protocol must be implemented by all tools that can be used to operate on a drawing.

The drawing tool protocol must be implemented by all tools that can be used to operate on a drawing. Getting tools right is tricky, 
because of all the different cases that need to be considered, undo tasks, and so forth. Thus the following rules must be followed:

1. On mouseDown, a tool needs to decide what it is going to do, and return the partcode of the hit part for the object under consideration. At
this point however, it should NOT perform the actual action of the tool.

2. The partcode returned in 1, if non-zero, will be passed back during a mouse drag.

3. On mouse UP, the tool must carry out its actual action, returning YES if the action was carried out, NO if not. The correct return values
from mouse down and mouse up are essential to allow the correct management of undo tasks that arise during the tool's operation.

4. Tools that do not affect the data content of a drawing (e.g. a zoom tool, which affects only the view) should return 0 and NO respectively.

5. Tools that perform an action that can be considered undoable must implement +toolPerformsUndoableAction returning YES and also supply an
action name when requested.

6. Tools must supply a cursor which is displayed during the mouse down/drag/up sequence and whenever the tool is set.
*/
@interface NSObject (DKToolDelegate)

- (void)toolWillPerformUndoableAction:(id<DKDrawingTool>)aTool;
- (void)toolDidPerformUndoableAction:(id<DKDrawingTool>)aTool;

@end
