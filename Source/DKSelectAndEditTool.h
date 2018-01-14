/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>
#import "DKDrawingTool.h"
#import "DKRasterizerProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@class DKDrawingView, DKStyle, DKObjectDrawingLayer;

//! modes of operation determined by what was hit and what is in the selection
typedef NS_ENUM(NSInteger, DKEditToolOperation) {
	kDKEditToolInvalidMode = 0,
	kDKEditToolSelectionMode = 1,
	kDKEditToolEditObjectMode = 2,
	kDKEditToolMoveObjectsMode = 3
};

//! drag phases passed to \c dragObjectAsGroup:...
typedef NS_ENUM(NSInteger, DKEditToolDragPhase) {
	kDKDragMouseDown = 1,
	kDKDragMouseDragged = 2,
	kDKDragMouseUp = 3
};

// tool class

/**
 This tool implements the standard selection and edit tool behaviour (multi-purpose tool) which allows objects to be selected,
 moved by dragging and to be edited by having their knobs dragged. For editing, objects mostly handle this themselves, but this
 provides the initial translation of mouse events into edit operations.

 Note that the tool can only be used in layers which are DKObjectDrawingLayers - if the layer is not of this kind then the
 tool mode is set to invalid and nothing is done.

 The 'marquee' (selection rect) is drawn using a style, giving great flexibility as to its appearance. In general a style that
 has a very low opacity should be used - the default style takes the system's highlight colour and makes a low opacity version of it.
*/
@interface DKSelectAndEditTool : DKDrawingTool <DKRenderable> {
@private
	DKEditToolOperation mOperationMode; // what the tool is doing (selecting, editing or moving)
	NSPoint mAnchorPoint; // the point of the initial mouse down
	NSPoint mLastPoint; // last point seen
	NSRect mMarqueeRect; // the selection rect, while selecting
	DKStyle* mMarqueeStyle; // the appearance style of the marquee
	NSInteger mPartcode; // current partcode
	NSString* mUndoAction; // the most recently performed action name
	BOOL mHideSelectionOnDrag; // YES to hide knobs and jhandles while dragging an object
	BOOL mAllowMultiObjectDrag; // YES to allow all objects in the selection to be moved at once
	BOOL mAllowMultiObjectKnobDrag; // YES to allow movement of all selected objects, even when dragging on a control point
	BOOL mPerformedUndoableTask; // YES if the tool did anything undoable
	BOOL mAllowDirectCopying; // YES if option-drag copies the objects directly
	BOOL mDidCopyDragObjects; // YES if objects were copied when dragged
	BOOL mMouseMoved; // YES if mouse was actually dragged, not just clicked
	CGFloat mViewScale; // the view's current scale, valid for the renderingPath callback
	NSUInteger mProxyDragThreshold; // number of objects in the selection where a proxy drag is used; 0 = never do a proxy drag
	BOOL mInProxyDrag; // YES during a proxy drag
	NSImage* mProxyDragImage; // the proxy image being dragged
	NSRect mProxyDragDestRect; // where it is drawn
	NSArray* mDraggedObjects; // cache of objects being dragged
	BOOL mWasInLockedObject; // YES if initial mouse down was in a locked object
}

/** @brief Returns the default style to use for drawing the selection marquee

 Marquee styles should have a lot of transparency as they are drawn on top of all objects when
 selecting them. The default style uses the system highlight colour as a starting point and
 makes a low opacity version of it.
 @return a style object
 */
+ (DKStyle*)defaultMarqueeStyle;

// modes of operation:

/** @brief The tool's operation mode.

 This is typically called automatically by the mouseDown method according to the context of the
 initial click.
 */
@property (nonatomic) DKEditToolOperation operationMode;

// drawing the marquee (selection rect):

/** @brief Draws the marquee (selection rect)

 This is called only if the mode is kDKEditToolSelectionMode. The actual drawing is performed by
 the style
 @param aView the view being drawn in */
- (void)drawMarqueeInView:(DKDrawingView*)aView;

/** @brief Returns the current marquee (selection rect)
 @return a rect */
@property (readonly) NSRect marqueeRect;

/** @brief Sets the current marquee (selection rect)

 This updates the area that is different between the current marquee and the new one being set,
 which results in much faster interactive selection of objects because far less drawing is going on.
 @param marqueeRect a rect
 @param aLayer the current layer (used to mark the update for the marquee rect)
 */
- (void)setMarqueeRect:(NSRect)marqueeRect inLayer:(DKLayer*)aLayer;

/** @brief The drawing style for the marquee (selection rect)
 
 If you replace the default style, take care that the style is generally fairly transparent,
 otherwise it will be hard to see what you are selecting!
 */
@property (nonatomic, retain, nonnull) DKStyle *marqueeStyle;

// setting up optional behaviours:

/** @brief Set whether the selection highlight of objects should be supressed during a drag

 The default is <code>YES</code>. Hiding the selection can make positioning objects by eye more precise.
 Is \c YES to hide selections during a drag, \c NO to leave them visible */
@property BOOL selectionShouldHideDuringDrag;

/** @brief Drags all objects as agroup?
 
 The default is <code>YES</code>.
 Is \c YES if all selected objects are dragged as a group, \c NO if only one is
 */
@property BOOL dragsAllObjectsInSelection;

/** @brief Whether option-drag copies the original object
 
 The default is <code>YES</code>.
 @return \c YES if option-drag will copy the object.
 */
@property BOOL allowsDirectDragCopying;

/** @brief Whether a hit on a knob in a multiple selection drags the objects or drags the knob.

 The default is \c <code>NO</code>
 Is \c YES to drag the selection, \c NO to change the selection and drag the knob.
 */
@property BOOL dragsAllObjectsInSelectionWhenDraggingKnob;

/** @brief Sets the number of selected objects at which a proxy drag is used rather than a live drag

 Dragging large numbers of objects can be unacceptably slow due to the very high numbers of view updates
 it entails. By setting a threshold, this tool can use a much faster (but less realistic) drag using
 a temporary image of the objects being dragged. A value of 0 will disable proxy dragging. Note that
 this gives a hugh performance gain for large numbers of objects - in fact it makes dragging of a lot
 of objects actually feasible. The default threshold is 50 objects. Setting this to 1 effectively
 makes proxy dragging operate at all times.
 */
@property NSUInteger proxyDragThreshold;

// handling the selection

/** @brief Implement selection changes for the current event (mouse down, typically)

 This method implements the 'standard' selection conventions for modifier keys as follows:
 1. no modifiers - \c targ is selected if not already selected
 2. + shift: \c targ is added to the existing selection
 3. + command: the selected state of \c targ is flipped
 This method also sets the undo action name to indicate what change occurred - if selection
 changes are not considered undoable by the layer, these are simply ignored.
 @param targ the object that is being selected or deselected
 @param layer the layer in which the object exists
 @param event the event
 */
- (void)changeSelectionWithTarget:(DKDrawableObject*)targ inLayer:(DKObjectDrawingLayer*)layer event:(NSEvent*)event;

// dragging objects

/** @brief Handle the drag of objects, either singly or multiply
 
 This drags one or more objects to the point <code>p</code>. It also is where the current state of the options
 for hiding the selection and allowing multiple drags is implemented. The method also deals with
 snapping during the drag - what happens is slightly different when one object is dragged as opposed
 to several objects - in the latter case the relative spatial positions of the objects is fixed
 rather than allowing each one to snap individually to the grid which is poor from a usability POV.
 This also tests the drag against the layer's current "exclusion rect". If the drag leaves this rect,
 a Drag Manager drag is invoked to allow the objects to be dragged to another document, layer or
 application.
 @param objects a list of objects to drag (may have only one item)
 @param layer the layer in which the objects exist
 @param p the current local point where the drag is
 @param event the event
 @param ph the drag phase - mouse down, dragged or up.
 */
- (void)dragObjectsAsGroup:(NSArray<DKDrawableObject*>*)objects inLayer:(DKObjectDrawingLayer*)layer toPoint:(NSPoint)p event:(NSEvent*)event dragPhase:(DKEditToolDragPhase)ph;

/** @brief Prepare the proxy drag image for the given objects

 The default method creates the image by asking the layer to make one using its standard imaging
 methods. You can override this for different approaches. Typically the drag image has the bounds of
 the selected objects - the caller will position the image based on that assumption. This is only
 invoked if the proxy drag threshold was exceeded and not zero.
 @param objectsToDrag the list of objects that will be dragged
 @param layer the layer they are owned by
 @return an image, representing the dragged objects.
 */
- (NSImage*)prepareDragImage:(NSArray*)objectsToDrag inLayer:(DKObjectDrawingLayer*)layer;

// setting the undo action name

- (void)setUndoAction:(nullable NSString*)action;

@end

/** informal protocol used to verify use of tool with target layer
 */
@interface NSObject (SelectionToolDelegate)

- (BOOL)canBeUsedWithSelectionTool;

@end

#define kDKSelectToolDefaultProxyDragThreshold 50

// notifications:

extern NSNotificationName const kDKSelectionToolWillStartSelectionDrag;
extern NSNotificationName const kDKSelectionToolDidFinishSelectionDrag;
extern NSNotificationName const kDKSelectionToolWillStartMovingObjects;
extern NSNotificationName const kDKSelectionToolDidFinishMovingObjects;
extern NSNotificationName const kDKSelectionToolWillStartEditingObject;
extern NSNotificationName const kDKSelectionToolDidFinishEditingObject;

// keys for user info dictionary:

extern NSString* const kDKSelectionToolTargetLayer;
extern NSString* const kDKSelectionToolTargetObject;

NS_ASSUME_NONNULL_END
