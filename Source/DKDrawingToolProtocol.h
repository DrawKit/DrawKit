/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class DKDrawableObject, DKLayer;
@protocol DKToolDelegate;

NS_SWIFT_NAME(DKDrawingToolProtocol)
@protocol DKDrawingTool <NSObject>

/** @brief Returns the undo action name for the tool.

 Override to return something useful.
 */
@property (readonly, copy, nullable) NSString *actionName;

/** @brief Return the tool's cursor.

 Override to return a cursor appropriate to the tool.
 */
- (NSCursor*)cursor;

/** @brief Handle the initial mouse down.

 Override to do something useful.
 @param p The local point where the mouse went down.
 @param obj The target object, if there is one.
 @param layer The layer in which the tool is being applied.
 @param event The original event.
 @param aDel An optional delegate.
 @return the partcode of the target that was hit, or \c 0 (no object).
 */
- (NSInteger)mouseDownAtPoint:(NSPoint)p targetObject:(nullable DKDrawableObject*)obj layer:(DKLayer*)layer event:(NSEvent*)event delegate:(nullable id<DKToolDelegate>)aDel;

/** @brief Handle the mouse dragged event.

 Override to do something useful.
 @param p The local point where the mouse has been dragged to.
 @param pc The partcode returned by the mouseDown method.
 @param layer The layer in which the tool is being applied.
 @param event The original event.
 @param aDel An optional delegate.
 */
- (void)mouseDraggedToPoint:(NSPoint)p partCode:(NSInteger)pc layer:(DKLayer*)layer event:(NSEvent*)event delegate:(nullable id<DKToolDelegate>)aDel;

/** @brief Handle the mouse up event.

 Override to do something useful
 tools usually return <code>YES</code>, tools that operate the user interface such as a zoom tool typically return <code>NO</code>.
 @param p The local point where the mouse went up.
 @param pc The partcode returned by the \c mouseDown method.
 @param layer The layer in which the tool is being applied.
 @param event The original event.
 @param aDel An optional delegate.
 @return \c YES if the tool did something undoable, \c NO otherwise.
 */
- (BOOL)mouseUpAtPoint:(NSPoint)p partCode:(NSInteger)pc layer:(DKLayer*)layer event:(NSEvent*)event delegate:(nullable id<DKToolDelegate>)aDel;

@optional

/** @brief Draw the tool's graphic.

 Informally, a tool can also implement this, which will be called from \c DKToolController if the object does respond to it.
 @param rect The rect being redrawn.
 @param aView The view that is doing the drawing.
 */
- (void)drawRect:(NSRect)rect inView:(NSView*)aView;

@end


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
@protocol DKToolDelegate <NSObject>
@optional

/** @brief Opens an undo group to receive subsequent undo tasks

 This is needed to work around an NSUndoManager bug where empty groups create a bogus task on the stack.
 A group is only opened when a real task is coming. This isn't really very elegant right now - a
 better solution is sought, perhaps subclassing NSUndoManager itself.
 @param aTool the tool making the request */
- (void)toolWillPerformUndoableAction:(id<DKDrawingTool>)aTool;
- (void)toolDidPerformUndoableAction:(id<DKDrawingTool>)aTool;

@end

NS_ASSUME_NONNULL_END
