/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import "DKSelectAndEditTool.h"
#import "DKObjectDrawingLayer.h"
#import "DKGeometryUtilities.h"
#import "DKStyle.h"
#import "DKDrawing.h"
#import "DKDrawableObject.h"
#import "DKDrawingView.h"
#import "LogEvent.h"
#import "NSAffineTransform+DKAdditions.h"
#import "DKUndoManager.h"
#import "DKToolController.h"

#if __has_feature(objc_arc)
#define ARCRETAIN(__xArg) __xArg
#define ARCRELEASE(__xArg)
#else
#define ARCRETAIN(__xArg) [__xArg retain]
#define ARCRELEASE(__xArg) [__xArg release]
#endif

@interface DKSelectAndEditTool ()

@property (readwrite, copy) NSArray *draggedObjects;
- (void)proxyDragObjectsAsGroup:(NSArray*)objects inLayer:(DKObjectDrawingLayer*)layer toPoint:(NSPoint)p event:(NSEvent*)event dragPhase:(DKEditToolDragPhase)ph;
- (BOOL)finishUsingToolInLayer:(DKObjectDrawingLayer*)odl delegate:(id)aDel event:(NSEvent*)event;

@end

#pragma mark constants

// notification names

NSString* kDKSelectionToolWillStartSelectionDrag = @"kDKSelectionToolWillStartSelectionDrag";
NSString* kDKSelectionToolDidFinishSelectionDrag = @"kDKSelectionToolDidFinishSelectionDrag";
NSString* kDKSelectionToolWillStartMovingObjects = @"kDKSelectionToolWillStartMovingObjects";
NSString* kDKSelectionToolDidFinishMovingObjects = @"kDKSelectionToolDidFinishMovingObjects";
NSString* kDKSelectionToolWillStartEditingObject = @"kDKSelectionToolWillStartEditingObject";
NSString* kDKSelectionToolDidFinishEditingObject = @"kDKSelectionToolDidFinishEditingObject";

// user info dict keys

NSString* kDKSelectionToolTargetLayer = @"kDKSelectionToolTargetLayer";
NSString* kDKSelectionToolTargetObject = @"kDKSelectionToolTargetObject";

@implementation DKSelectAndEditTool

#pragma mark - As a DKSelectAndEditTool

/** @brief Returns the default style to use for drawing the selection marquee

 Marquee styles should have a lot of transparency as they are drawn on top of all objects when
 selecting them. The default style uses the system highlight colour as a starting point and
 makes a low opacity version of it.
 @return a style object
 */
+ (DKStyle*)defaultMarqueeStyle
{
	NSColor* fc = [[NSColor selectedTextBackgroundColor] colorWithAlphaComponent:0.25];
	NSColor* sc = [[NSColor whiteColor] colorWithAlphaComponent:0.75];

	DKStyle* dms = [DKStyle styleWithFillColour:fc
								   strokeColour:sc
									strokeWidth:0.0];

	return dms;
}

#pragma mark -
#pragma mark - modes of operation:

/** @brief Sets the tool's operation mode

 This is typically called automatically by the mouseDown method according to the context of the
 initial click.
 @param op the mode to enter */
- (void)setOperationMode:(DKEditToolOperation)op
{
	mOperationMode = op;

	LogEvent_(kInfoEvent, @"select tool set op mode = %ld", (long)op);
}

@synthesize operationMode=mOperationMode;

#pragma mark -
#pragma mark - drawing the marquee(selection rect):

/** @brief Draws the marquee (selection rect)

 This is called only if the mode is kDKEditToolSelectionMode. The actual drawing is performed by
 the style
 @param aView the view being drawn in */
- (void)drawMarqueeInView:(DKDrawingView*)aView
{
	if ([aView needsToDrawRect:[self marqueeRect]]) {
		mViewScale = [aView scale];
		[[self marqueeStyle] render:self];
	}
}

@synthesize marqueeRect=mMarqueeRect;

/** @brief Sets the current marquee (selection rect)

 This updates the area that is different between the current marquee and the new one being set,
 which results in much faster interactive selection of objects because far less drawing is going on.
 @param marqueeRect a rect
 @param alayer the current layer (used to mark the update for the marquee rect)
 @return a rect */
- (void)setMarqueeRect:(NSRect)marqueeRect inLayer:(DKLayer*)aLayer
{
	NSRect omr = [self marqueeRect];

	if (!NSEqualRects(marqueeRect, omr)) {
		NSSet* updateRegion = DifferenceOfTwoRects(omr, marqueeRect);

		// the extra padding here is OK for the default style - if you use something with a
		// bigger stroke this may need changing

		[aLayer setNeedsDisplayInRects:updateRegion
					  withExtraPadding:NSMakeSize(2.5, 2.5)];

		mMarqueeRect = marqueeRect;
	}
}

#if 0
/** @brief Set the drawing style for the marquee (selection rect)

 If you replace the default style, take care that the style is generally fairly transparent,
 otherwise it will be hard to see what you are selecting!
 @param aStyle a style object */
- (void)setMarqueeStyle:(DKStyle*)aStyle
{
	NSAssert(aStyle != nil, @"attempt to set a nil style for the selection marquee");

	[aStyle retain];
	[mMarqueeStyle release];
	mMarqueeStyle = aStyle;
}
#endif

@synthesize marqueeStyle=mMarqueeStyle;

#pragma mark -
#pragma mark - setting options for the tool

@synthesize selectionShouldHideDuringDrag=mHideSelectionOnDrag;
@synthesize dragsAllObjectsInSelection=mAllowMultiObjectDrag;
@synthesize allowsDirectDragCopying=mAllowDirectCopying;
@synthesize dragsAllObjectsInSelectionWhenDraggingKnob=mAllowMultiObjectKnobDrag;
@synthesize proxyDragThreshold=mProxyDragThreshold;

#pragma mark -
#pragma mark - changing the selection and dragging

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
- (void)changeSelectionWithTarget:(DKDrawableObject*)targ inLayer:(DKObjectDrawingLayer*)layer event:(NSEvent*)event
{
	// given an object that we know was generally hit, this changes the selection. What happens can also depend on modifier keys, but the
	// result is that the layer's selection represents what a subsequent selection drag will consist of.

	BOOL extended = NO; //(([event modifierFlags] & NSShiftKeyMask) != 0 );
	BOOL invert = (([event modifierFlags] & NSCommandKeyMask) != 0) || (([event modifierFlags] & NSShiftKeyMask) != 0);
	BOOL isSelected = [layer isSelectedObject:targ];

	// if already selected and we are not inverting, nothing to do if multi-drag is ON

	if (isSelected && !invert && [self dragsAllObjectsInSelection])
		return;

	NSString* an = NSLocalizedStringFromTableInBundle(@"Change Selection", @"DKTools", [NSBundle bundleForClass:[DKSelectAndEditTool class]], @"undo string for change selecton");

	if (extended) {
		[layer addObjectToSelection:targ];
		an = NSLocalizedStringFromTableInBundle(@"Add To Selection", @"DKTools", [NSBundle bundleForClass:[DKSelectAndEditTool class]], @"undo string for add selection");
	} else {
		if (invert) {
			if (isSelected) {
				[layer removeObjectFromSelection:targ];
				an = NSLocalizedStringFromTableInBundle(@"Remove From Selection", @"DKTools", [NSBundle bundleForClass:[DKSelectAndEditTool class]], @"undo string for remove selection");
			} else {
				[layer addObjectToSelection:targ];
				an = NSLocalizedStringFromTableInBundle(@"Add To Selection", @"DKTools", [NSBundle bundleForClass:[DKSelectAndEditTool class]], @"undo string for add selection");
			}
		} else
			[layer replaceSelectionWithObject:targ];
	}

	if ([layer selectionChangesAreUndoable]) {
		[self setUndoAction:an];
		mPerformedUndoableTask = YES;
	}
}

// if this is set, CFArrayApplyFunction is used to update the objects rather than an enumerator
#if __has_feature(objc_arc)
#define USE_CF_APPLIER_FOR_DRAGGING 0
#else
#define USE_CF_APPLIER_FOR_DRAGGING 1
#endif

#if defined(USE_CF_APPLIER_FOR_DRAGGING) && USE_CF_APPLIER_FOR_DRAGGING
typedef struct DKSelectAndEditDragInfo {
	NSPoint p;
	NSEvent* event;
	BOOL multiDrag;
} _dragInfo;

static void dragFunction_mouseDown(const void* obj, void* context)
{
	_dragInfo* dragInfo = (_dragInfo*)context;
	BOOL saveSnap = NO, saveShowsInfo = NO;

	if (dragInfo->multiDrag) {
		saveSnap = [(DKDrawableObject*)obj mouseSnappingEnabled];
		[(DKDrawableObject*)obj setMouseSnappingEnabled:NO];

		saveShowsInfo = [[(DKDrawableObject*)obj class] displaysSizeInfoWhenDragging];
		[[(DKDrawableObject*)obj class] setDisplaysSizeInfoWhenDragging:NO];
	}

	[(DKDrawableObject*)obj mouseDownAtPoint:dragInfo->p
									  inPart:kDKDrawingEntireObjectPart
									   event:dragInfo->event];

	if (dragInfo->multiDrag) {
		[(DKDrawableObject*)obj setMouseSnappingEnabled:saveSnap];
		[[(DKDrawableObject*)obj class] setDisplaysSizeInfoWhenDragging:saveShowsInfo];
	}
}

static void dragFunction_mouseDrag(const void* obj, void* context)
{
	_dragInfo* dragInfo = (_dragInfo*)context;
	BOOL saveSnap = NO, saveShowsInfo = NO;

	if (dragInfo->multiDrag) {
		saveSnap = [(DKDrawableObject*)obj mouseSnappingEnabled];
		[(DKDrawableObject*)obj setMouseSnappingEnabled:NO];

		saveShowsInfo = [[(DKDrawableObject*)obj class] displaysSizeInfoWhenDragging];
		[[(DKDrawableObject*)obj class] setDisplaysSizeInfoWhenDragging:NO];
	}

	[(DKDrawableObject*)obj mouseDraggedAtPoint:dragInfo->p
										 inPart:kDKDrawingEntireObjectPart
										  event:dragInfo->event];
	if (dragInfo->multiDrag) {
		[(DKDrawableObject*)obj setMouseSnappingEnabled:saveSnap];
		[[(DKDrawableObject*)obj class] setDisplaysSizeInfoWhenDragging:saveShowsInfo];
	}
}

static void dragFunction_mouseUp(const void* obj, void* context)
{
	_dragInfo* dragInfo = (_dragInfo*)context;

	BOOL saveSnap = NO, saveShowsInfo = NO;

	if (dragInfo->multiDrag) {
		saveSnap = [(DKDrawableObject*)obj mouseSnappingEnabled];
		[(DKDrawableObject*)obj setMouseSnappingEnabled:NO];

		saveShowsInfo = [[(DKDrawableObject*)obj class] displaysSizeInfoWhenDragging];
		[[(DKDrawableObject*)obj class] setDisplaysSizeInfoWhenDragging:NO];
	}

	[(DKDrawableObject*)obj mouseUpAtPoint:dragInfo->p
									inPart:kDKDrawingEntireObjectPart
									 event:dragInfo->event];
	[(DKDrawableObject*)obj notifyVisualChange];

	if (dragInfo->multiDrag) {
		[(DKDrawableObject*)obj setMouseSnappingEnabled:saveSnap];
		[[(DKDrawableObject*)obj class] setDisplaysSizeInfoWhenDragging:saveShowsInfo];
	}
}
#endif

- (void)dragObjectsAsGroup:(NSArray<DKDrawableObject*>*)objects inLayer:(DKObjectDrawingLayer*)layer toPoint:(NSPoint)p event:(NSEvent*)event dragPhase:(DKEditToolDragPhase)ph
{
	NSAssert(objects != nil, @"attempt to drag with nil array");
	NSAssert([objects count] > 0, @"attempt to drag with empty array");

	[layer setRulerMarkerUpdatesEnabled:NO];

	// if set to hide the selection highlight during a drag, test that here and set the highlight visible
	// as required on the initial mouse down

	if ([self selectionShouldHideDuringDrag] && ph == kDKDragMouseDragged)
		[layer setSelectionVisible:NO];

	// if the mouse has left the layer's drag exclusion rect, this starts a drag of the objects as a "real" drag. Test for that here
	// and initiate the drag if needed. The drag will keep control until the items are dropped.

	if (ph == kDKDragMouseDragged) {
		NSRect der = [layer dragExclusionRect];
		if (!NSPointInRect(p, der)) {
			[layer beginDragOfSelectedObjectsWithEvent:event
												inView:[layer currentView]];
			if ([self selectionShouldHideDuringDrag])
				[layer setSelectionVisible:YES];

			// the drag will have clobbered the mouse up, but we need to post one to ensure that the sequence is correctly terminated.
			// this is particularly important for managing undo groups, which are exceedingly finicky.

			NSWindow* window = [event window];

			NSEvent* fakeMouseUp = [NSEvent mouseEventWithType:NSLeftMouseUp
													  location:[event locationInWindow]
												 modifierFlags:0
													 timestamp:[NSDate timeIntervalSinceReferenceDate]
												  windowNumber:[window windowNumber]
													   context:[NSGraphicsContext currentContext]
												   eventNumber:0
													clickCount:1
													  pressure:0.0];

			[window postEvent:fakeMouseUp
					  atStart:YES];

			//NSLog(@"returning from drag source operation, phase = %d", ph);
			return;
		}
	}

	BOOL multipleObjects = [objects count] > 1;
	BOOL controlKey = ([event modifierFlags] & NSControlKeyMask) != 0;

	// when moved as a group, individual mouse snapping is supressed - instead we snap the input point to the grid and
	// apply it to all - as usual control key can disable (or enable) snapping temporarily

	if (multipleObjects) {
		p = [[layer drawing] snapToGrid:p
						withControlFlag:controlKey];

		DKUndoManager* um = (DKUndoManager*)[layer undoManager];

		// set the undo manager to coalesce ABABABAB > AB instead of ABBBBBA > ABA

		if ([um respondsToSelector:@selector(setCoalescingKind:)]) {
			if (ph == kDKDragMouseDown)
				[um setCoalescingKind:kGCCoalesceAllMatchingTasks];
			else if (ph == kDKDragMouseUp)
				[um setCoalescingKind:kGCCoalesceLastTask];
		}
	}

	// if we have exceeded a non-zero proxy threshold, handle things using the proxy drag method instead.

	if ([self proxyDragThreshold] > 0 && [objects count] >= [self proxyDragThreshold]) {
		[self proxyDragObjectsAsGroup:objects
							  inLayer:layer
							  toPoint:p
								event:event
							dragPhase:ph];
	} else {

#if defined(USE_CF_APPLIER_FOR_DRAGGING) && USE_CF_APPLIER_FOR_DRAGGING
		_dragInfo dragInfo;

		dragInfo.p = p;
		dragInfo.event = event;
		dragInfo.multiDrag = multipleObjects;

		switch (ph) {
		case kDKDragMouseDown:
			CFArrayApplyFunction((CFArrayRef)objects, CFRangeMake(0, [objects count]), dragFunction_mouseDown, &dragInfo);
			break;

		case kDKDragMouseDragged:
			CFArrayApplyFunction((CFArrayRef)objects, CFRangeMake(0, [objects count]), dragFunction_mouseDrag, &dragInfo);
			break;

		case kDKDragMouseUp:
			CFArrayApplyFunction((CFArrayRef)objects, CFRangeMake(0, [objects count]), dragFunction_mouseUp, &dragInfo);
			break;

		default:
			break;
		}

#else
		switch (ph) {
		case kDKDragMouseDown:
			for (DKDrawableObject *obj in objects) {
				BOOL saveSnap = NO, saveShowsInfo = NO;
				
				if (multipleObjects) {
					saveSnap = [obj mouseSnappingEnabled];
					obj.mouseSnappingEnabled = NO;

					saveShowsInfo = [[obj class] displaysSizeInfoWhenDragging];
					[[obj class] setDisplaysSizeInfoWhenDragging:NO];
				}

				[obj mouseDownAtPoint:p
							   inPart:kDKDrawingEntireObjectPart
								event:event];
				
				if (multipleObjects) {
					obj.mouseSnappingEnabled = saveSnap;
					[[obj class] setDisplaysSizeInfoWhenDragging:saveShowsInfo];
				}
			}
			break;

		case kDKDragMouseDragged:
			for (DKDrawableObject *obj in objects) {
				BOOL saveSnap = NO, saveShowsInfo = NO;
				
				if (multipleObjects) {
					saveSnap = [obj mouseSnappingEnabled];
					obj.mouseSnappingEnabled = NO;

					saveShowsInfo = [[obj class] displaysSizeInfoWhenDragging];
					[[obj class] setDisplaysSizeInfoWhenDragging:NO];
				}
				
				[obj mouseDraggedAtPoint:p
								  inPart:kDKDrawingEntireObjectPart
								   event:event];
				if (multipleObjects) {
					obj.mouseSnappingEnabled = saveSnap;
					[[obj class] setDisplaysSizeInfoWhenDragging:saveShowsInfo];
				}
			}
			break;

		case kDKDragMouseUp:
			for (DKDrawableObject *obj in objects) {
				BOOL saveSnap = NO, saveShowsInfo = NO;

				if (multipleObjects) {
					saveSnap = [obj mouseSnappingEnabled];
					obj.mouseSnappingEnabled = NO;
					
					saveShowsInfo = [[obj class] displaysSizeInfoWhenDragging];
					[[obj class] setDisplaysSizeInfoWhenDragging:NO];
				}

				[obj mouseUpAtPoint:p
							 inPart:kDKDrawingEntireObjectPart
							  event:event];
				[obj notifyVisualChange];

				if (multipleObjects) {
					obj.mouseSnappingEnabled = saveSnap;
					[[obj class] setDisplaysSizeInfoWhenDragging:saveShowsInfo];
				}
			}
			break;

			default:
				break;
		}
#endif
	}

	// set the undo action to say what we just did for a drag:

	if (ph == kDKDragMouseDragged) {
		if (multipleObjects) {
			if (mDidCopyDragObjects)
				[self setUndoAction:NSLocalizedStringFromTableInBundle(@"Copy And Move Objects", @"DKTools", [NSBundle bundleForClass:[DKSelectAndEditTool class]], @"undo string for copy and move (plural)")];
			else
				[self setUndoAction:NSLocalizedStringFromTableInBundle(@"Move Multiple Objects", @"DKTools", [NSBundle bundleForClass:[DKSelectAndEditTool class]], @"undo string for move multiple objects")];
		} else {
			if (mDidCopyDragObjects)
				[self setUndoAction:NSLocalizedStringFromTableInBundle(@"Copy And Move Object", @"DKTools", [NSBundle bundleForClass:[DKSelectAndEditTool class]], @"undo string for copy and move (singular)")];
			else
				[self setUndoAction:NSLocalizedStringFromTableInBundle(@"Move Object", @"DKTools", [NSBundle bundleForClass:[DKSelectAndEditTool class]], @"undo string for move single object")];
		}
	}

	// if the mouse wasn't dragged, select the single object if shift or command isn't down - this avoids the need to deselect all
	// before selecting a single object in an already selected group. By also testing mouse moved, the tool is smart
	// enough not to do this if it was an object drag that was done. Result for the user - intuitively thought-free behaviour. ;-)

	if (!mMouseMoved && ph == kDKDragMouseUp) {
		BOOL shift = ([event modifierFlags] & NSShiftKeyMask) != 0;
		BOOL cmd = ([event modifierFlags] & NSCommandKeyMask) != 0;

		if (!shift && !cmd) {
			DKDrawableObject* single = [layer hitTest:p];

			if (single != nil)
				[layer replaceSelectionWithObject:single];
		}
	}

	// on mouse up restore the selection visibility if required

	if ([self selectionShouldHideDuringDrag] && ph == kDKDragMouseUp)
		[layer setSelectionVisible:YES];

	[layer setRulerMarkerUpdatesEnabled:YES];
	[layer updateRulerMarkersForRect:[layer selectionLogicalBounds]];
}

/** @brief Store a string representing an undoable action

 The string is simply stored until requested by the caller, it does not at this stage set the
 undo manager's action name.
 @param action a string
 */
- (void)setUndoAction:(NSString*)action
{
#if __has_feature(objc_arc)
	mUndoAction = [action copy];
#else
	[action retain];
	[mUndoAction release];
	mUndoAction = [action copy];
	[action release];
#endif
}

#define SHOW_DRAG_PROXY_BOUNDARY 0

/** @brief Prepare the proxy drag image for the given objects

 The default method creates the image by asking the layer to make one using its standard imaging
 methods. You can override this for different approaches. Typically the drag image has the bounds of
 the selected objects - the caller will position the image based on that assumption. This is only
 invoked if the proxy drag threshold was exceeded and not zero.
 @param objectsToDrag the list of objects that will be dragged
 @param layer the layer they are owned by
 @return an image, representing the dragged objects.
 */
- (NSImage*)prepareDragImage:(NSArray*)objectsToDrag inLayer:(DKObjectDrawingLayer*)layer
{
#pragma unused(objectsToDrag)

	NSImage* img = [layer imageOfSelectedObjects];

// draw a dotted line around the boundary.

#if SHOW_DRAG_PROXY_BOUNDARY
	NSRect br = NSZeroRect;
	br.size = [img size];
	br = NSInsetRect(br, 1, 1);
	NSBezierPath* bp = [NSBezierPath bezierPathWithRect:br];
	CGFloat pattern[] = { 4, 4 };

	[bp setLineWidth:1.0];
	[bp setLineDash:pattern
			  count:2
			  phase:0];

	[img lockFocus];
	[[NSColor grayColor] set];
	[bp stroke];
	[img unlockFocus];
#endif

	return img;
}

/** @brief Perform the proxy drag image for the given objects

 Called internally when a proxy drag is detected. This will create the drag image on mouse down,
 drag the image on a drag and clean up on mouse up. The point <p> is already pre-snapped for
 a multi-object drag and the caller will take care of other normal housekeeping.
 */
- (void)proxyDragObjectsAsGroup:(NSArray*)objects inLayer:(DKObjectDrawingLayer*)layer toPoint:(NSPoint)p event:(NSEvent*)event dragPhase:(DKEditToolDragPhase)ph
{
#pragma unused(event)

	static NSSize offset;
	static NSPoint anchor;

	switch (ph) {
	case kDKDragMouseDown: {
		if (mProxyDragImage == nil) {
			mProxyDragImage = ARCRETAIN([self prepareDragImage:objects
													   inLayer:layer]);

			offset.width = p.x - NSMinX([layer selectionBounds]);
			offset.height = p.y - NSMinY([layer selectionBounds]);
			anchor = p;

			mProxyDragDestRect.size = [mProxyDragImage size];
			mProxyDragDestRect.origin.x = p.x - offset.width;
			mProxyDragDestRect.origin.y = p.y - offset.height;

			[layer setNeedsDisplayInRect:mProxyDragDestRect];

			// need to hide the real objects being dragged. Since we cache the dragged list
			// locally we can do this without getting bad results from [layer selectedAvailableObjects]

			// we also want to keep the undo manager out of this:

			[[layer undoManager] disableUndoRegistration];

			for (DKDrawableObject* obj in objects)
				[obj setVisible:NO];

			[[layer undoManager] enableUndoRegistration];
		}
		mInProxyDrag = YES;
	} break;

	case kDKDragMouseDragged: {
		[layer setNeedsDisplayInRect:mProxyDragDestRect];

		mProxyDragDestRect.size = [mProxyDragImage size];
		mProxyDragDestRect.origin.x = p.x - offset.width;
		mProxyDragDestRect.origin.y = p.y - offset.height;

		[layer setNeedsDisplayInRect:mProxyDragDestRect];
	} break;

	case kDKDragMouseUp: {
		ARCRELEASE(mProxyDragImage);
		mProxyDragImage = nil;
		[layer setNeedsDisplayInRect:mProxyDragDestRect];

		// move the objects by the total drag distance

		CGFloat dx, dy;

		dx = p.x - anchor.x;
		dy = p.y - anchor.y;

		for (DKDrawableObject* obj in objects) {
			[obj offsetLocationByX:dx
							   byY:dy];

			[[layer undoManager] disableUndoRegistration];
			[obj setVisible:YES];
			[[layer undoManager] enableUndoRegistration];
		}
		mInProxyDrag = NO;
	} break;

	default:
		break;
	}
}

@synthesize draggedObjects=mDraggedObjects;

- (BOOL)finishUsingToolInLayer:(DKObjectDrawingLayer*)odl delegate:(id)aDel event:(NSEvent*)event
{
	NSArray* sel = nil;
	DKDrawableObject* obj;
	NSDictionary* userInfoDict = [NSDictionary dictionaryWithObjectsAndKeys:odl, kDKSelectionToolTargetLayer, [odl singleSelection], kDKSelectionToolTargetObject, nil];
	BOOL extended = (([event modifierFlags] & NSShiftKeyMask) != 0);

	switch ([self operationMode]) {
	case kDKEditToolInvalidMode:
	default:
		break;

	case kDKEditToolSelectionMode: {
		[self setMarqueeRect:NSRectFromTwoPoints(mAnchorPoint, mLastPoint)
					 inLayer:odl];

		if (NSIsEmptyRect([self marqueeRect]) && mWasInLockedObject) {
			obj = [odl hitTest:mLastPoint];
			[odl replaceSelectionWithObject:obj];
		} else
			sel = [odl objectsInRect:[self marqueeRect]];

		NSString* undoStr = nil;

		if ([sel count] == 0 && !extended && !mWasInLockedObject) {
			// the marquee hit nothing, so deselect everything

			[odl deselectAll];
			undoStr = NSLocalizedStringFromTableInBundle(@"Deselect All", @"DKTools", [NSBundle bundleForClass:[DKSelectAndEditTool class]], @"undo string for deselect all");
		} else
			undoStr = NSLocalizedStringFromTableInBundle(@"Change Selection", @"DKTools", [NSBundle bundleForClass:[DKSelectAndEditTool class]], @"undo string for change selecton");

		if ([odl selectionChangesAreUndoable]) {
			[self setUndoAction:undoStr];

			// did we do anything undoable? compare the before and after selection state - if the same, the
			// answer is no.

			mPerformedUndoableTask = [odl selectionHasChangedFromRecorded];
		}
		[self setMarqueeRect:NSZeroRect
					 inLayer:odl];

		// notify the delegate that an undo group will be needed for the selection change

		if (mPerformedUndoableTask)
			[aDel toolWillPerformUndoableAction:self];

		[[NSNotificationCenter defaultCenter] postNotificationName:kDKSelectionToolDidFinishSelectionDrag
															object:self
														  userInfo:userInfoDict];
	}
		break;

	case kDKEditToolMoveObjectsMode:
		sel = [self draggedObjects];

		if ([sel count] > 0) {
			[self dragObjectsAsGroup:sel
							 inLayer:odl
							 toPoint:mLastPoint
							   event:event
						   dragPhase:kDKDragMouseUp];

			// directly inform the layer that the drag finished and how far the objects were moved

			if ([odl respondsToSelector:@selector(objects:
											wereDraggedFromPoint:
														 toPoint:)])
				[odl objects:sel
					wereDraggedFromPoint:mAnchorPoint
								 toPoint:mLastPoint];
		}

		[[NSNotificationCenter defaultCenter] postNotificationName:kDKSelectionToolDidFinishMovingObjects
															object:self
														  userInfo:userInfoDict];
		break;

	case kDKEditToolEditObjectMode:
		obj = [odl singleSelection];
		[obj mouseUpAtPoint:mLastPoint
					 inPart:mPartcode
					  event:event];
		[[NSNotificationCenter defaultCenter] postNotificationName:kDKSelectionToolDidFinishEditingObject
															object:self
														  userInfo:userInfoDict];
		break;
	}
	[self setDraggedObjects:nil];
	return mPerformedUndoableTask;
}

#pragma mark -
#pragma mark - As part of DKDrawingTool Protocol

/** @brief Does the tool ever implement undoable actions?

 Returning YES means that the tool can POTENTIALLY do undoable things, not that it always will.
 @return always returns YES
 */
+ (BOOL)toolPerformsUndoableAction
{
	return YES; // in general, tasks performed by this tool create undo tasks
}

/** @brief Rerurn the current action name
 @return a string, whatever was stored by setUndoAction:
 */
- (NSString*)actionName
{
	return mUndoAction;
}

/** @brief Return the tool's cursor
 @return the arrow cursor
 */
- (NSCursor*)cursor
{
	return [NSCursor arrowCursor];
}

/** @brief Handle the initial mouse down

 This method determines the context of the tool based on whether the tool hit an object or not,
 whether a partcode (knob) was hit, the layer kind, etc. The operation mode of the tool is set
 @param p the local point where the mouse went down
 @param obj the target object, if there is one
 @param layer the layer in which the tool is being applied
 @param event the original event
 @param aDel an optional delegate
 @return the partcode of the target that was hit, or 0 (no object)
 */
- (NSInteger)mouseDownAtPoint:(NSPoint)p targetObject:(DKDrawableObject*)obj layer:(DKLayer*)layer event:(NSEvent*)event delegate:(id)aDel
{
#pragma unused(aDel)

	// first sanity check the layer kind - if it's not one that handles objects and selection, we can't operate.

	NSAssert(layer != nil, @"can't operate on a nil layer");

	mPartcode = kDKDrawingNoPart;

	mPerformedUndoableTask = NO;
	mDidCopyDragObjects = NO;
	mMouseMoved = NO;
	mWasInLockedObject = NO;
	mLastPoint = p;

	LogEvent_(kUserEvent, @"S/E tool mouse down, target = %@, layer = %@, pt = %@", obj, layer, NSStringFromPoint(p));

	NSDictionary* userInfoDict = [NSDictionary dictionaryWithObjectsAndKeys:layer, kDKSelectionToolTargetLayer, obj, kDKSelectionToolTargetObject, nil];


	if (![self isValidTargetLayer:layer]) {
		// if the layer kind is not an object layer, the tool cannot be applied so set its mode to invalid

		[self setOperationMode:kDKEditToolInvalidMode];
	} else {
		// layer type is OK. Whether we will move, select or edit depends on what was initially hit and the current selection state.

		DKObjectDrawingLayer* odl = (DKObjectDrawingLayer*)layer;

		if (obj == nil) {
			// no initial target object, so the tool simply implements a drag selection

			[self setOperationMode:kDKEditToolSelectionMode];
			mAnchorPoint = mLastPoint = p;
			mMarqueeRect = NSRectFromTwoPoints(p, p);

			[[NSNotificationCenter defaultCenter] postNotificationName:kDKSelectionToolWillStartSelectionDrag
																object:self
															  userInfo:userInfoDict];
		} else {
			// a target object was supplied. The tool will either move it (and optionally other selected ones), or edit it by dragging its
			// knobs. If the object is locked it can still be selected but not moved or resized, so it makes more sense to switch to a marquee drag in this case.

			if ([obj locked] || [obj locationLocked]) {
				[self setOperationMode:kDKEditToolSelectionMode];
				mAnchorPoint = mLastPoint = p;
				mMarqueeRect = NSRectFromTwoPoints(p, p);

				[[NSNotificationCenter defaultCenter] postNotificationName:kDKSelectionToolWillStartSelectionDrag
																	object:self
																  userInfo:userInfoDict];
				[self changeSelectionWithTarget:obj
										inLayer:odl
										  event:event];
				mWasInLockedObject = YES;
				return kDKDrawingEntireObjectPart;
			}

			mPartcode = [obj hitPart:p];

			// detect a double-click and call the target object's method for fielding it

			if ([event clickCount] > 1) {
				[obj mouseDoubleClickedAtPoint:p
										inPart:mPartcode
										 event:event];
				return mPartcode;
			}

			NSUInteger sc = [odl countOfSelection];

			if (mPartcode == kDKDrawingEntireObjectPart || ((sc > 1) && [self dragsAllObjectsInSelectionWhenDraggingKnob])) {
				// select the object and move it (and optionally any others in the selection)

				[self setOperationMode:kDKEditToolMoveObjectsMode];
				[self changeSelectionWithTarget:obj
										inLayer:odl
										  event:event];

				// get the objects that will be operated on:
				// these are then cached locally so that we can perform fiendish operations on the objects without upsetting the layer.
				// This also should yield small performance improvements.

				NSArray* selection = [odl selectedAvailableObjects];
				[self setDraggedObjects:selection];

				if ([selection count] > 0) {
					// if drag-copying is allowed, and the option key is down, make a copy of the selection and drag that

					if ([self allowsDirectDragCopying] && ([event modifierFlags] & NSAlternateKeyMask) != 0) {
						// this task must be grouped with the overall undo for the event, so flag that now

						[aDel toolWillPerformUndoableAction:self];
						mPerformedUndoableTask = YES;
						mDidCopyDragObjects = YES;

						// copy the selection and add it to the layer and select it

						selection = [odl duplicatedSelection];
						[odl addObjectsFromArray:selection];
						[odl exchangeSelectionWithObjectsFromArray:selection];
					}

					// send notification:

					[[NSNotificationCenter defaultCenter] postNotificationName:kDKSelectionToolWillStartMovingObjects
																		object:self
																	  userInfo:userInfoDict];

					// start the drag with the mouse down if there are any objects to drag

					[self dragObjectsAsGroup:selection
									 inLayer:odl
									 toPoint:p
									   event:event
								   dragPhase:kDKDragMouseDown];
				}
			} else {
				// edit the object - select it singly and pass the initial mouse-down

				[self setOperationMode:kDKEditToolEditObjectMode];
				[odl replaceSelectionWithObject:obj];

				// notify we are about to start:

				[[NSNotificationCenter defaultCenter] postNotificationName:kDKSelectionToolWillStartEditingObject
																	object:self
																  userInfo:userInfoDict];

				// setting nil here will cause the action name to be supplied by the object itself

				[self setUndoAction:nil];
				[obj mouseDownAtPoint:p
							   inPart:mPartcode
								event:event];
			}
		}
	}

	return mPartcode;
}

/** @brief Handle the mouse dragged event

 The delegate may be called to signal that an undoable task is about to be created at certain times.
 @param p the local point where the mouse has been dragged to
 @param pc the partcode returned by the mouseDown method
 @param layer the layer in which the tool is being applied
 @param event the original event
 @param aDel an optional delegate
 */
- (void)mouseDraggedToPoint:(NSPoint)p partCode:(NSInteger)pc layer:(DKLayer*)layer event:(NSEvent*)event delegate:(id<DKToolDelegate>)aDel
{
	BOOL extended = (([event modifierFlags] & NSShiftKeyMask) != 0);
	DKObjectDrawingLayer* odl = (DKObjectDrawingLayer*)layer;
	NSArray* sel;
	DKDrawableObject* obj;
	@autoreleasepool {

		// the mouse has actually been dragged, so flag that

		mMouseMoved = YES;
		mLastPoint = p;

		// depending on the mode, carry out the operation for a mousedragged event
		@try
		{
			switch ([self operationMode]) {
			case kDKEditToolInvalidMode:
			default:
				break;

			case kDKEditToolSelectionMode:
				[self setMarqueeRect:NSRectFromTwoPoints(mAnchorPoint, p)
							 inLayer:odl];

				sel = [odl objectsInRect:[self marqueeRect]];

				if (extended)
					[odl addObjectsToSelectionFromArray:sel];
				else
					[odl exchangeSelectionWithObjectsFromArray:sel];

				break;

			case kDKEditToolMoveObjectsMode:
				sel = [self draggedObjects];

				if ([sel count] > 0) {
					[aDel toolWillPerformUndoableAction:self];
					[self dragObjectsAsGroup:sel
									 inLayer:odl
									 toPoint:p
									   event:event
								   dragPhase:kDKDragMouseDragged];
					mPerformedUndoableTask = YES;
				}
				break;

			case kDKEditToolEditObjectMode:
				obj = [odl singleSelection];
				if (obj != nil) {
					[aDel toolWillPerformUndoableAction:self];
					[obj mouseDraggedAtPoint:p
									  inPart:pc
									   event:event];
					mPerformedUndoableTask = YES;
				}
				break;
			}
		}
		@catch (NSException* exception)
		{
			NSLog(@"#### exception while dragging with selection tool: mode = %ld, exc = (%@) - ignored ####", (long)[self operationMode], exception);
		}

	}
}

/** @brief Handle the mouse up event

 The delegate may be called to signal that an undoable task is about to be created at certain times.
 @param p the local point where the mouse went up
 @param pc the partcode returned by the mouseDown method
 @param layer the layer in which the tool is being applied
 @param event the original event
 @param aDel an optional delegate
 @return YES if the tool did something undoable, NO otherwise
 */
- (BOOL)mouseUpAtPoint:(NSPoint)p partCode:(NSInteger)pc layer:(DKLayer*)layer event:(NSEvent*)event delegate:(id)aDel
{
#pragma unused(pc)

	DKObjectDrawingLayer* odl = (DKObjectDrawingLayer*)layer;
	mLastPoint = p;

	return [self finishUsingToolInLayer:odl
							   delegate:aDel
								  event:event];
}

#define PROXY_DRAG_IMAGE_OPACITY 0.8

/** @brief Handle the initial mouse down

 Draws the marquee (selection rect) in selection mode
 @param aRect the rect being redrawn (not used)
 @param aView the view that is doing the drawing
 */
- (void)drawRect:(NSRect)aRect inView:(NSView*)aView
{
#pragma unused(aRect)

	if ([self operationMode] == kDKEditToolSelectionMode)
		[self drawMarqueeInView:(DKDrawingView*)aView];
	else if (mInProxyDrag && mProxyDragImage != nil) {
		// need to flip the image if needed

		SAVE_GRAPHICS_CONTEXT //[NSGraphicsContext saveGraphicsState];
			if ([aView isFlipped])
		{
			NSAffineTransform* unflipper = [NSAffineTransform transform];
			[unflipper translateXBy:mProxyDragDestRect.origin.x
								yBy:mProxyDragDestRect.origin.y + mProxyDragDestRect.size.height];
			[unflipper scaleXBy:1.0
							yBy:-1.0];
			[unflipper concat];
		}

		// for slightly higher performance but less visual fidelity, comment this out:

		[[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];

		// the drag image is drawn at 80% opacity to help with the "interleaving" issue. In practice this works pretty well.

		[mProxyDragImage drawAtPoint:NSZeroPoint
							fromRect:NSZeroRect
						   operation:NSCompositeSourceAtop
							fraction:PROXY_DRAG_IMAGE_OPACITY];

		RESTORE_GRAPHICS_CONTEXT //[NSGraphicsContext restoreGraphicsState];
	}
}

/** @brief The state of the modifier keys changed
 @param event the event
 @param layer the current layer that the tool is being applied to
 */
- (void)flagsChanged:(NSEvent*)event inLayer:(DKLayer*)layer
{
#pragma unused(event)
#pragma unused(layer)
}

/** @brief Verifies that the target layer can be used with the tool
 @param aLayer the current layer that the tool is being applied to
 @return YES if target layer can be operated on, NO otherwise
 */
- (BOOL)isValidTargetLayer:(DKLayer*)aLayer
{
	if ([aLayer respondsToSelector:@selector(canBeUsedWithSelectionTool)])
		return [aLayer canBeUsedWithSelectionTool];
	else
		return [aLayer isKindOfClass:[DKObjectDrawingLayer class]];
}

/** @brief Return whether the tool is some sort of object selection tool

 This method is used to assist the tool controller in making sensible decisions about certain
 automatic operations.
 @return YES
 */
- (BOOL)isSelectionTool
{
	return YES;
}

/** @brief Set a cursor if the given point is over something interesting

 Called by the tool controller when the mouse moves, this should determine whether a special cursor
 needs to be set right now and set it. If no special cursor needs to be set, it should set the
 current one for the tool.
 @param mp the local mouse point
 @param obj the target object under the mouse, if any
 @param aLayer the active layer
 @param event the original event
 */
- (void)setCursorForPoint:(NSPoint)mp targetObject:(DKDrawableObject*)obj inLayer:(DKLayer*)aLayer event:(NSEvent*)event
{
#pragma unused(aLayer)
#pragma unused(event)

	NSCursor* curs = [self cursor];

	if (obj != nil) {
		NSInteger pc = [obj hitPart:mp];
		curs = [obj cursorForPartcode:pc
					  mouseButtonDown:NO];
	}

	[curs set];
}

/** @brief Called when this tool is about to be unset by a tool controller

 Subclasses can make use of this message to prepare themselves when they are unset if necessary, for
 example by finishing the work they were doing and cleaning up.
 @param aController the controller that set this tool
 */
- (void)toolControllerWillUnsetTool:(DKToolController*)aController
{
	if ([self isValidTargetLayer:[aController activeLayer]])
		[self finishUsingToolInLayer:(DKObjectDrawingLayer*)[aController activeLayer]
							delegate:aController
							   event:[NSApp currentEvent]];
}

#pragma mark -
#pragma mark As part of the DKRenderable protocol

/** @brief Return the marquee (selection rect) path to be rendered by the style
 @return a bezier path - the current selection rect
 */
- (NSBezierPath*)renderingPath
{
	return [NSBezierPath bezierPathWithRect:[self marqueeRect]];
}

/** @brief Required for the complete protocol
 @return zero - the selection doesn't have an angle
 */
- (CGFloat)angle
{
	return 0.0;
}

/** @brief Required for the complete protocol
 @return NO - selections never use low quality drawing
 */
- (BOOL)useLowQualityDrawing
{
	return NO;
}

// these methods are here to comply with the formal protocol - they will not be called under nromal circumstances

- (NSSize)size
{
	return [self marqueeRect].size;
}

- (NSPoint)location
{
	return [self marqueeRect].origin;
}

- (NSAffineTransform*)containerTransform
{
	return [NSAffineTransform transform];
}

- (NSSize)extraSpaceNeeded
{
	return NSZeroSize;
}

- (NSRect)bounds
{
	return [self marqueeRect];
}

- (NSUInteger)geometryChecksum
{
	return 0;
}

#pragma mark -
#pragma mark As an NSObject

/** @brief Initialize the tool (designated initializer)
 @return the tool object
 */
- (instancetype)init
{
	self = [super init];
	if (self != nil) {
		[self setMarqueeStyle:[[self class] defaultMarqueeStyle]];
		mHideSelectionOnDrag = YES;
		mAllowMultiObjectDrag = YES;
		mAllowDirectCopying = YES;
		mProxyDragThreshold = kDKSelectToolDefaultProxyDragThreshold;
	}

	return self;
}

#if !__has_feature(objc_arc)
/** @brief Deallocate the tool
 */
- (void)dealloc
{
	[mMarqueeStyle release];
	[mProxyDragImage release];
	[mDraggedObjects release];
	[super dealloc];
}
#endif

@end
