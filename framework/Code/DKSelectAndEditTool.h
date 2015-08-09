/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2015
 @copyright MPL2; see LICENSE.txt
*/

#import "DKDrawingTool.h"
#import "DKRasterizerProtocol.h"

@class DKDrawingView, DKStyle, DKObjectDrawingLayer;

// modes of operation determined by what was hit and what is in the selection

typedef enum {
	kDKEditToolInvalidMode = 0,
	kDKEditToolSelectionMode = 1,
	kDKEditToolEditObjectMode = 2,
	kDKEditToolMoveObjectsMode = 3
} DKEditToolOperation;

// drag phases passed to dragObjectAsGroup:...

typedef enum {
	kDKDragMouseDown = 1,
	kDKDragMouseDragged = 2,
	kDKDragMouseUp = 3
} DKEditToolDragPhase;

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

/** @brief Sets the tool's operation mode

 This is typically called automatically by the mouseDown method according to the context of the
 initial click.
 @param op the mode to enter */
- (void)setOperationMode:(DKEditToolOperation)op;

/** @brief Returns the tool's current operation mode
 @return the current operation mode */
- (DKEditToolOperation)operationMode;

// drawing the marquee (selection rect):

/** @brief Draws the marquee (selection rect)

 This is called only if the mode is kDKEditToolSelectionMode. The actual drawing is performed by
 the style
 @param aView the view being drawn in */
- (void)drawMarqueeInView:(DKDrawingView*)aView;

/** @brief Returns the current marquee (selection rect)
 @return a rect */
- (NSRect)marqueeRect;

/** @brief Sets the current marquee (selection rect)

 This updates the area that is different between the current marquee and the new one being set,
 which results in much faster interactive selection of objects because far less drawing is going on.
 @param marqueeRect a rect
 @param alayer the current layer (used to mark the update for the marquee rect)
 @return a rect */
- (void)setMarqueeRect:(NSRect)marqueeRect inLayer:(DKLayer*)aLayer;

/** @brief Set the drawing style for the marquee (selection rect)

 If you replace the default style, take care that the style is generally fairly transparent,
 otherwise it will be hard to see what you are selecting!
 @param aStyle a style object */
- (void)setMarqueeStyle:(DKStyle*)aStyle;

/** @brief Set the drawing style for the marquee (selection rect)

 If you replace the default style, take care that the style is generally fairly transparent,
 otherwise it will be hard to see what you are selecting!
 @param aStyle a style object */
- (DKStyle*)marqueeStyle;

// setting up optional behaviours:

/** @brief Set whether the selection highlight of objects should be supressed during a drag

 The default is YES. Hiding the selection can make positioning objects by eye more precise.
 @param hideSel YES to hide selections during a drag, NO to leave them visible */
- (void)setSelectionShouldHideDuringDrag:(BOOL)hideSel;

/** @brief Should the selection highlight of objects should be supressed during a drag?

 The default is YES. Hiding the selection can make positioning objects by eye more precise.
 @return YES to hide selections during a drag, NO to leave them visible */
- (BOOL)selectionShouldHideDuringDrag;
- (void)setDragsAllObjectsInSelection:(BOOL)multi;
- (BOOL)dragsAllObjectsInSelection;
- (void)setAllowsDirectDragCopying:(BOOL)dragCopy;
- (BOOL)allowsDirectDragCopying;

/** @brief Sets whether a hit on a knob in a multiple selection drags the objects or drags the knob

 The default is NO
 @param dragWithKnob YES to drag the selection, NO to change the selection and drag the knob
 */
- (void)setDragsAllObjectsInSelectionWhenDraggingKnob:(BOOL)dragWithKnob;

/** @brief Returns whether a hit on a knob in a multiple selection drags the objects or drags the knob

 The default is NO
 @return YES to drag the selection, NO to change the selection and drag the knob
 */
- (BOOL)dragsAllObjectsInSelectionWhenDraggingKnob;

/** @brief Sets the number of selected objects at which a proxy drag is used rather than a live drag

 Dragging large numbers of objects can be unacceptably slow due to the very high numbers of view updates
 it entails. By setting a threshold, this tool can use a much faster (but less realistic) drag using
 a temporary image of the objects being dragged. A value of 0 will disable proxy dragging. Note that
 this gives a hugh performance gain for large numbers of objects - in fact it makes dragging of a lot
 of objects actually feasible. The default threshold is 50 objects. Setting this to 1 effectively
 makes proxy dragging operate at all times.
 @param numberOfObjects the number above which a proxy drag is used 
 */
- (void)setProxyDragThreshold:(NSUInteger)numberOfObjects;

/** @brief The number of selected objects at which a proxy drag is used rather than a live drag

 Dragging large numbers of objects can be unacceptably slow due to the very high numbers of view updates
 it entails. By setting a threshold, this tool can use a much faster (but less realistic) drag using
 a temporary image of the objects being dragged. A value of 0 will disable proxy dragging.
 @return the number above which a proxy drag is used
 */
- (NSUInteger)proxyDragThreshold;

// handling the selection

/** @brief Implement selection changes for the current event (mouse down, typically)

 This method implements the 'standard' selection conventions for modifier keys as follows:
 1. no modifiers - <targ> is selected if not already selected
 2. + shift: <targ> is added to the existing selection
 3. + command: the selected state of <targ> is flipped
 This method also sets the undo action name to indicate what change occurred - if selection
 changes are not considered undoable by the layer, these are simply ignored.
 @param targ the object that is being selected or deselected
 @param layer the layer in which the object exists
 @param event the event
 */
- (void)changeSelectionWithTarget:(DKDrawableObject*)targ inLayer:(DKObjectDrawingLayer*)layer event:(NSEvent*)event;

// dragging objects

- (void)dragObjectsAsGroup:(NSArray*)objects inLayer:(DKObjectDrawingLayer*)layer toPoint:(NSPoint)p event:(NSEvent*)event dragPhase:(DKEditToolDragPhase)ph;

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

- (void)setUndoAction:(NSString*)action;

@end

// informal protocol ised to verify use of tool with target layer

@interface NSObject (SelectionToolDelegate)

- (BOOL)canBeUsedWithSelectionTool;

@end

#define kDKSelectToolDefaultProxyDragThreshold 50

// notifications:

extern NSString* kDKSelectionToolWillStartSelectionDrag;
extern NSString* kDKSelectionToolDidFinishSelectionDrag;
extern NSString* kDKSelectionToolWillStartMovingObjects;
extern NSString* kDKSelectionToolDidFinishMovingObjects;
extern NSString* kDKSelectionToolWillStartEditingObject;
extern NSString* kDKSelectionToolDidFinishEditingObject;

// keys for user info dictionary:

extern NSString* kDKSelectionToolTargetLayer;
extern NSString* kDKSelectionToolTargetObject;
