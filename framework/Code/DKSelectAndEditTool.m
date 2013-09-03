///**********************************************************************************************************************************
///  DKSelectAndEditTool.m
///  DrawKit ©2005-2008 Apptree.net
///
///  Created by graham on 8/04/2008.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
///
///**********************************************************************************************************************************


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

@interface DKSelectAndEditTool (Private)

- (void)		setDraggedObjects:(NSArray*) objects;
- (NSArray*)	draggedObjects;
- (void)		proxyDragObjectsAsGroup:(NSArray*) objects inLayer:(DKObjectDrawingLayer*) layer toPoint:(NSPoint) p event:(NSEvent*) event dragPhase:(DKEditToolDragPhase) ph;
- (BOOL)		finishUsingToolInLayer:(DKObjectDrawingLayer*) odl delegate:(id) aDel event:(NSEvent*) event;

@end

#pragma mark constants

// notification names

NSString*		kDKSelectionToolWillStartSelectionDrag = @"kDKSelectionToolWillStartSelectionDrag";
NSString*		kDKSelectionToolDidFinishSelectionDrag = @"kDKSelectionToolDidFinishSelectionDrag";
NSString*		kDKSelectionToolWillStartMovingObjects = @"kDKSelectionToolWillStartMovingObjects";
NSString*		kDKSelectionToolDidFinishMovingObjects = @"kDKSelectionToolDidFinishMovingObjects";
NSString*		kDKSelectionToolWillStartEditingObject = @"kDKSelectionToolWillStartEditingObject";
NSString*		kDKSelectionToolDidFinishEditingObject = @"kDKSelectionToolDidFinishEditingObject";

// user info dict keys

NSString*		kDKSelectionToolTargetLayer = @"kDKSelectionToolTargetLayer";
NSString*		kDKSelectionToolTargetObject = @"kDKSelectionToolTargetObject";


@implementation DKSelectAndEditTool

#pragma mark - As a DKSelectAndEditTool

///*********************************************************************************************************************
///
/// method:			defaultMarqueeStyle:
/// scope:			public class method
/// description:	returns the default style to use for drawing the selection marquee
/// 
/// parameters:		none
/// result:			a style object
///
/// notes:			marquee styles should have a lot of transparency as they are drawn on top of all objects when
///					selecting them. The default style uses the system highlight colour as a starting point and
///					makes a low opacity version of it.
///
///********************************************************************************************************************

+ (DKStyle*)				defaultMarqueeStyle
{
	NSColor* fc = [[NSColor selectedTextBackgroundColor] colorWithAlphaComponent:0.25];
	NSColor* sc = [[NSColor whiteColor] colorWithAlphaComponent:0.75];
	
	DKStyle*	dms = [DKStyle styleWithFillColour:fc strokeColour:sc strokeWidth:0.0];
	
	return dms;
}



#pragma mark -
#pragma mark - modes of operation:

///*********************************************************************************************************************
///
/// method:			setOperationMode:
/// scope:			instance method
/// description:	sets the tool's operation mode
/// 
/// parameters:		<op> the mode to enter
/// result:			none
///
/// notes:			this is typically called automatically by the mouseDown method according to the context of the
///					initial click.
///
///********************************************************************************************************************

- (void)					setOperationMode:(DKEditToolOperation) op
{
	mOperationMode = op;
	
	LogEvent_( kInfoEvent, @"select tool set op mode = %d", op );
}



///*********************************************************************************************************************
///
/// method:			operationMode
/// scope:			instance method
/// description:	returns the tool's current operation mode
/// 
/// parameters:		none
/// result:			the current operation mode
///
/// notes:			
///
///********************************************************************************************************************

- (DKEditToolOperation)		operationMode
{
	return mOperationMode;
}



#pragma mark -
#pragma mark - drawing the marquee (selection rect):

///*********************************************************************************************************************
///
/// method:			drawMarqueeInView:
/// scope:			instance method
/// description:	draws the marquee (selection rect)
/// 
/// parameters:		<aView> the view being drawn in
/// result:			none
///
/// notes:			this is called only if the mode is kDKEditToolSelectionMode. The actual drawing is performed by
///					the style
///
///********************************************************************************************************************

- (void)					drawMarqueeInView:(DKDrawingView*) aView
{
	if([aView needsToDrawRect:[self marqueeRect]])
	{
		mViewScale = [aView scale];
		[[self marqueeStyle] render:self];
	}
}



///*********************************************************************************************************************
///
/// method:			marqueeRect
/// scope:			instance method
/// description:	returns the current marquee (selection rect)
/// 
/// parameters:		none
/// result:			a rect
///
/// notes:			
///
///********************************************************************************************************************

- (NSRect)					marqueeRect
{
	return mMarqueeRect;
}


///*********************************************************************************************************************
///
/// method:			setMarqueeRect:inLayer:
/// scope:			instance method
/// description:	sets the current marquee (selection rect)
/// 
/// parameters:		<marqueeRect> a rect
///					<alayer> the current layer (used to mark the update for the marquee rect)
/// result:			a rect
///
/// notes:			this updates the area that is different between the current marquee and the new one being set,
///					which results in much faster interactive selection of objects because far less drawing is going on.
///
///********************************************************************************************************************

- (void)					setMarqueeRect:(NSRect) marqueeRect inLayer:(DKLayer*) aLayer
{
	NSRect omr = [self marqueeRect];
	
	if( ! NSEqualRects( marqueeRect, omr))
	{
		NSSet* updateRegion = DifferenceOfTwoRects( omr, marqueeRect );
		
		// the extra padding here is OK for the default style - if you use something with a
		// bigger stroke this may need changing
		
		[aLayer setNeedsDisplayInRects:updateRegion withExtraPadding:NSMakeSize( 2.5, 2.5 )];
	
		mMarqueeRect = marqueeRect;
	}
}



///*********************************************************************************************************************
///
/// method:			setMarqueeStyle:
/// scope:			instance method
/// description:	set the drawing style for the marquee (selection rect)
/// 
/// parameters:		<aStyle> a style object
/// result:			none
///
/// notes:			if you replace the default style, take care that the style is generally fairly transparent,
///					otherwise it will be hard to see what you are selecting!
///
///********************************************************************************************************************

- (void)					setMarqueeStyle:(DKStyle*) aStyle
{
	NSAssert( aStyle != nil, @"attempt to set a nil style for the selection marquee");
	
	[aStyle retain];
	[mMarqueeStyle release];
	mMarqueeStyle = aStyle;
}


///*********************************************************************************************************************
///
/// method:			marqueeStyle
/// scope:			instance method
/// description:	set the drawing style for the marquee (selection rect)
/// 
/// parameters:		<aStyle> a style object
/// result:			none
///
/// notes:			if you replace the default style, take care that the style is generally fairly transparent,
///					otherwise it will be hard to see what you are selecting!
///
///********************************************************************************************************************

- (DKStyle*)				marqueeStyle
{
	return mMarqueeStyle;
}


#pragma mark -
#pragma mark - setting options for the tool

///*********************************************************************************************************************
///
/// method:			setSelectionShouldHideDuringDrag:
/// scope:			instance method
/// description:	set whether the selection highlight of objects should be supressed during a drag
/// 
/// parameters:		<hideSel> YES to hide selections during a drag, NO to leave them visible
/// result:			none
///
/// notes:			the default is YES. Hiding the selection can make positioning objects by eye more precise.
///
///********************************************************************************************************************

- (void)					setSelectionShouldHideDuringDrag:(BOOL) hideSel
{
	mHideSelectionOnDrag = hideSel;
}


///*********************************************************************************************************************
///
/// method:			selectionShouldHideDuringDrag:
/// scope:			instance method
/// description:	should the selection highlight of objects should be supressed during a drag?
/// 
/// parameters:		none 
/// result:			YES to hide selections during a drag, NO to leave them visible
///
/// notes:			the default is YES. Hiding the selection can make positioning objects by eye more precise.
///
///********************************************************************************************************************

- (BOOL)					selectionShouldHideDuringDrag
{
	return mHideSelectionOnDrag;
}


///*********************************************************************************************************************
///
/// method:			setDragsAllObjectsInSelection:
/// scope:			public instance method
///	overrides:
/// description:	sets whether dragging moves all objects in the selection as a group, or only the one under the mouse
/// 
/// parameters:		<multi> YES to drag all selected objects as a group, NO to drag just the one hit
/// result:			none
///
/// notes:			the default is YES.
///
///********************************************************************************************************************

- (void)				setDragsAllObjectsInSelection:(BOOL) multi
{
	mAllowMultiObjectDrag = multi;
}


///*********************************************************************************************************************
///
/// method:			dragsAllObjectsInSelection
/// scope:			public instance method
///	overrides:
/// description:	drags all objects as agroup?
/// 
/// parameters:		none
/// result:			YES if all selected objects are dragged as a group, NO if only one is
///
/// notes:			the default is YES
///
///********************************************************************************************************************

- (BOOL)				dragsAllObjectsInSelection
{
	return mAllowMultiObjectDrag;
}


///*********************************************************************************************************************
///
/// method:			setAllowsDirectDragCopying:
/// scope:			public instance method
///	overrides:
/// description:	sets whether option-drag copies the original object
/// 
/// parameters:		<dragCopy> YES to allow option-drag to copy the object
/// result:			none
///
/// notes:			the default is YES
///
///********************************************************************************************************************

- (void)				setAllowsDirectDragCopying:(BOOL) dragCopy
{
	mAllowDirectCopying = dragCopy;
}


///*********************************************************************************************************************
///
/// method:			allowsDirectDragCopying:
/// scope:			public instance method
///	overrides:
/// description:	whether option-drag copies the original object
/// 
/// parameters:		none
/// result:			YES if option-drag will copy the object
///
/// notes:			the default is YES
///
///********************************************************************************************************************

- (BOOL)				allowsDirectDragCopying
{
	return mAllowDirectCopying;
}


///*********************************************************************************************************************
///
/// method:			setDragsAllObjectsInSelectionWhenDraggingKnob:
/// scope:			public instance method
///	overrides:
/// description:	sets whether a hit on a knob in a multiple selection drags the objects or drags the knob
/// 
/// parameters:		<dragWithKnob> YES to drag the selection, NO to change the selection and drag the knob
/// result:			none
///
/// notes:			the default is NO
///
///********************************************************************************************************************

- (void)					setDragsAllObjectsInSelectionWhenDraggingKnob:(BOOL) dragWithKnob
{
	mAllowMultiObjectKnobDrag = dragWithKnob;
}

///*********************************************************************************************************************
///
/// method:			dragsAllObjectsInSelectionWhenDraggingKnob
/// scope:			public instance method
///	overrides:
/// description:	returns whether a hit on a knob in a multiple selection drags the objects or drags the knob
/// 
/// parameters:		none 
/// result:			YES to drag the selection, NO to change the selection and drag the knob
///
/// notes:			the default is NO
///
///********************************************************************************************************************

- (BOOL)					dragsAllObjectsInSelectionWhenDraggingKnob
{
	return mAllowMultiObjectKnobDrag;
}


///*********************************************************************************************************************
///
/// method:			setProxyDragThreshold:
/// scope:			public instance method
///	overrides:
/// description:	sets the number of selected objects at which a proxy drag is used rather than a live drag
/// 
/// parameters:		<numberOfObjects> the number above which a proxy drag is used 
/// result:			none
///
/// notes:			dragging large numbers of objects can be unacceptably slow due to the very high numbers of view updates
///					it entails. By setting a threshold, this tool can use a much faster (but less realistic) drag using
///					a temporary image of the objects being dragged. A value of 0 will disable proxy dragging. Note that
///					this gives a hugh performance gain for large numbers of objects - in fact it makes dragging of a lot
///					of objects actually feasible. The default threshold is 50 objects. Setting this to 1 effectively
///					makes proxy dragging operate at all times.
///
///********************************************************************************************************************

- (void)					setProxyDragThreshold:(NSUInteger) numberOfObjects
{
	mProxyDragThreshold = numberOfObjects;
}


///*********************************************************************************************************************
///
/// method:			proxyDragThreshold
/// scope:			public instance method
///	overrides:
/// description:	the number of selected objects at which a proxy drag is used rather than a live drag
/// 
/// parameters:		none  
/// result:			the number above which a proxy drag is used
///
/// notes:			dragging large numbers of objects can be unacceptably slow due to the very high numbers of view updates
///					it entails. By setting a threshold, this tool can use a much faster (but less realistic) drag using
///					a temporary image of the objects being dragged. A value of 0 will disable proxy dragging.
///
///********************************************************************************************************************

- (NSUInteger)				proxyDragThreshold
{
	return mProxyDragThreshold;
}



#pragma mark -
#pragma mark - changing the selection and dragging

///*********************************************************************************************************************
///
/// method:			changeSelectionWithTarget:inLayer:event:
/// scope:			public instance method
///	overrides:
/// description:	implement selection changes for the current event (mouse down, typically)
/// 
/// parameters:		<targ> the object that is being selected or deselected
///					<layer> the layer in which the object exists
///					<event> the event
/// result:			none
///
/// notes:			this method implements the 'standard' selection conventions for modifier keys as follows:
///					1. no modifiers - <targ> is selected if not already selected
///					2. + shift: <targ> is added to the existing selection
///					3. + command: the selected state of <targ> is flipped
///					This method also sets the undo action name to indicate what change occurred - if selection
///					changes are not considered undoable by the layer, these are simply ignored.
///
///********************************************************************************************************************

- (void)					changeSelectionWithTarget:(DKDrawableObject*) targ inLayer:(DKObjectDrawingLayer*) layer event:(NSEvent*) event
{
	// given an object that we know was generally hit, this changes the selection. What happens can also depend on modifier keys, but the
	// result is that the layer's selection represents what a subsequent selection drag will consist of.
	
	BOOL extended = NO;//(([event modifierFlags] & NSShiftKeyMask) != 0 );
	BOOL invert = (([event modifierFlags] & NSCommandKeyMask) != 0 ) || (([event modifierFlags] & NSShiftKeyMask) != 0 );
	BOOL isSelected = [layer isSelectedObject:targ]; 
	
	// if already selected and we are not inverting, nothing to do if multi-drag is ON
	
	if ( isSelected && !invert && [self dragsAllObjectsInSelection])
		return;
	
	NSString* an = NSLocalizedString(@"Change Selection", @"undo string for change selecton");
	
	if ( extended )
	{
		[layer addObjectToSelection:targ];
		an = NSLocalizedString(@"Add To Selection", @"undo string for add selection");
	}
	else
	{
		if ( invert )
		{
			if ( isSelected )
			{
				[layer removeObjectFromSelection:targ];
				an = NSLocalizedString(@"Remove From Selection", @"undo string for remove selection");
			}
			else
			{
				[layer addObjectToSelection:targ];
				an = NSLocalizedString(@"Add To Selection", @"undo string for add selection");
			}
		}
		else
			[layer replaceSelectionWithObject:targ];
	}
	
	if([layer selectionChangesAreUndoable])
	{
		[self setUndoAction:an];
		mPerformedUndoableTask = YES;
	}
}


///*********************************************************************************************************************
///
/// method:			dragObjectsAsGroup:inLayer:toPoint:event:dragPhase:
/// scope:			public instance method
///	overrides:
/// description:	handle the drag of objects, either singly or multiply
/// 
/// parameters:		<objects> a list of objects to drag (may have only one item)
///					<layer> the layer in which the objects exist
///					<p> the current local point where the drag is
///					<event> the event
///					<ph> the drag phase - mouse down, dragged or up.
/// result:			none
///
/// notes:			this drags one or more objects to the point <p>. It also is where the current state of the options
///					for hiding the selection and allowing multiple drags is implemented. The method also deals with
///					snapping during the drag - what happens is slightly different when one object is dragged as opposed
///					to several objects - in the latter case the relative spatial positions of the objects is fixed
///					rather than allowing each one to snap individually to the grid which is poor from a usability POV.
///
///					This also tests the drag against the layer's current "exclusion rect". If the drag leaves this rect,
///					a Drag Manager drag is invoked to allow the objects to be dragged to another document, layer or
///					application.
///
///********************************************************************************************************************


// if this is set, CFArrayApplyFunction is used to update the objects rather than an enumerator

#define USE_CF_APPLIER_FOR_DRAGGING		1

typedef struct
{
	NSPoint		p;
	NSEvent*	event;
	BOOL		multiDrag;
}
_dragInfo;

static void		dragFunction_mouseDown( const void* obj, void* context )
{
	_dragInfo* dragInfo = (_dragInfo*)context;
	BOOL saveSnap = NO, saveShowsInfo = NO;
	
	if ( dragInfo->multiDrag )
	{
		saveSnap = [(DKDrawableObject*)obj mouseSnappingEnabled];
		[(DKDrawableObject*)obj setMouseSnappingEnabled:NO]; 
		
		saveShowsInfo = [[(DKDrawableObject*)obj class] displaysSizeInfoWhenDragging];
		[[(DKDrawableObject*)obj class] setDisplaysSizeInfoWhenDragging:NO];
	}
	
	[(DKDrawableObject*)obj mouseDownAtPoint:dragInfo->p inPart:kDKDrawingEntireObjectPart event:dragInfo->event];

	if ( dragInfo->multiDrag )
	{
		[(DKDrawableObject*)obj setMouseSnappingEnabled:saveSnap];
		[[(DKDrawableObject*)obj class] setDisplaysSizeInfoWhenDragging:saveShowsInfo];
	}
}


static void		dragFunction_mouseDrag( const void* obj, void* context )
{
	_dragInfo* dragInfo = (_dragInfo*)context;
	BOOL saveSnap = NO, saveShowsInfo = NO;
	
	if ( dragInfo->multiDrag )
	{
		saveSnap = [(DKDrawableObject*)obj mouseSnappingEnabled];
		[(DKDrawableObject*)obj setMouseSnappingEnabled:NO]; 
		
		saveShowsInfo = [[(DKDrawableObject*)obj class] displaysSizeInfoWhenDragging];
		[[(DKDrawableObject*)obj class] setDisplaysSizeInfoWhenDragging:NO];
	}
	
	[(DKDrawableObject*)obj mouseDraggedAtPoint:dragInfo->p inPart:kDKDrawingEntireObjectPart event:dragInfo->event];
	if ( dragInfo->multiDrag )
	{
		[(DKDrawableObject*)obj setMouseSnappingEnabled:saveSnap];
		[[(DKDrawableObject*)obj class] setDisplaysSizeInfoWhenDragging:saveShowsInfo];
	}
}


static void		dragFunction_mouseUp( const void* obj, void* context )
{
	_dragInfo* dragInfo = (_dragInfo*)context;
	
	BOOL saveSnap = NO, saveShowsInfo = NO;
	
	if ( dragInfo->multiDrag )
	{
		saveSnap = [(DKDrawableObject*)obj mouseSnappingEnabled];
		[(DKDrawableObject*)obj setMouseSnappingEnabled:NO]; 
		
		saveShowsInfo = [[(DKDrawableObject*)obj class] displaysSizeInfoWhenDragging];
		[[(DKDrawableObject*)obj class] setDisplaysSizeInfoWhenDragging:NO];
	}
	
	[(DKDrawableObject*)obj mouseUpAtPoint:dragInfo->p inPart:kDKDrawingEntireObjectPart event:dragInfo->event];
	[(DKDrawableObject*)obj notifyVisualChange];

	if ( dragInfo->multiDrag )
	{
		[(DKDrawableObject*)obj setMouseSnappingEnabled:saveSnap];
		[[(DKDrawableObject*)obj class] setDisplaysSizeInfoWhenDragging:saveShowsInfo];
	}
}


- (void)				dragObjectsAsGroup:(NSArray*) objects inLayer:(DKObjectDrawingLayer*) layer toPoint:(NSPoint) p event:(NSEvent*) event dragPhase:(DKEditToolDragPhase) ph
{
	NSAssert( objects != nil, @"attempt to drag with nil array");
	NSAssert([objects count] > 0, @"attempt to drag with empty array");
	
	[layer setRulerMarkerUpdatesEnabled:NO];
	
	// if set to hide the selection highlight during a drag, test that here and set the highlight visible
	// as required on the initial mouse down
	
	if([self selectionShouldHideDuringDrag] && ph == kDKDragMouseDragged )
		[layer setSelectionVisible:NO];
		
	// if the mouse has left the layer's drag exclusion rect, this starts a drag of the objects as a "real" drag. Test for that here
	// and initiate the drag if needed. The drag will keep control until the items are dropped.
	
	if( ph == kDKDragMouseDragged )
	{
		NSRect der = [layer dragExclusionRect];
		if( ! NSPointInRect( p, der ))
		{
			[layer beginDragOfSelectedObjectsWithEvent:event inView:[layer currentView]];
			if([self selectionShouldHideDuringDrag])
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
			
			[window postEvent:fakeMouseUp atStart:YES];

			//NSLog(@"returning from drag source operation, phase = %d", ph);
			return;
		}
	}
	
	BOOL multipleObjects = [objects count] > 1;
	BOOL controlKey = ([event modifierFlags] & NSControlKeyMask) != 0;
	
	// when moved as a group, individual mouse snapping is supressed - instead we snap the input point to the grid and
	// apply it to all - as usual control key can disable (or enable) snapping temporarily
	
	if ( multipleObjects )
	{
		p = [[layer drawing] snapToGrid:p withControlFlag:controlKey];
		
		DKUndoManager* um = (DKUndoManager*)[layer undoManager];
		
		// set the undo manager to coalesce ABABABAB > AB instead of ABBBBBA > ABA
		
		if([um respondsToSelector:@selector(setCoalescingKind:)])
		{
			if( ph == kDKDragMouseDown )
				[um setCoalescingKind:kGCCoalesceAllMatchingTasks];
			else if ( ph == kDKDragMouseUp )
				[um setCoalescingKind:kGCCoalesceLastTask];
		}
	}
	
	// if we have exceeded a non-zero proxy threshold, handle things using the proxy drag method instead.
	
	if([self proxyDragThreshold] > 0 && [objects count] >= [self proxyDragThreshold])
	{
		[self proxyDragObjectsAsGroup:objects inLayer:layer toPoint:p event:event dragPhase:ph];
	}
	else
	{

#if USE_CF_APPLIER_FOR_DRAGGING
		_dragInfo	dragInfo;
		
		dragInfo.p = p;
		dragInfo.event = event;
		dragInfo.multiDrag = multipleObjects;
		
		switch( ph )
		{
			case kDKDragMouseDown:
				CFArrayApplyFunction((CFArrayRef) objects, CFRangeMake( 0, [objects count]), dragFunction_mouseDown, &dragInfo );
				break;
				
			case kDKDragMouseDragged:
				CFArrayApplyFunction((CFArrayRef) objects, CFRangeMake( 0, [objects count]), dragFunction_mouseDrag, &dragInfo );
				break;
				
			case kDKDragMouseUp:
				CFArrayApplyFunction((CFArrayRef) objects, CFRangeMake( 0, [objects count]), dragFunction_mouseUp, &dragInfo );
				break;
				
			default:
				break;
		}
		
		
	#else
		NSEnumerator*		iter = [objects objectEnumerator];
		DKDrawableObject*	o;
		BOOL				saveSnap = NO;
		BOOL				saveShowsInfo = NO;

		while(( o = [iter nextObject]))
		{
			if ( multipleObjects )
			{
				saveSnap = [o mouseSnappingEnabled];
				[o setMouseSnappingEnabled:NO]; 

				saveShowsInfo = [[o class] displaysSizeInfoWhenDragging];
				[[o class] setDisplaysSizeInfoWhenDragging:NO];
			}

			switch( ph )
			{
				case kDKDragMouseDown:
					[o mouseDownAtPoint:p inPart:kDKDrawingEntireObjectPart event:event];
					[o notifyVisualChange];
					break;
					
				case kDKDragMouseDragged:
					[o mouseDraggedAtPoint:p inPart:kDKDrawingEntireObjectPart event:event];
					break;
					
				case kDKDragMouseUp:
					[o mouseUpAtPoint:p inPart:kDKDrawingEntireObjectPart event:event];
					[o notifyVisualChange];
					break;
					
				default:
					break;
			}
			
			if ( multipleObjects )
			{
				[o setMouseSnappingEnabled:saveSnap];
				[[o class] setDisplaysSizeInfoWhenDragging:saveShowsInfo];
			}
		}
	#endif
	}
	
	// set the undo action to say what we just did for a drag:
	
	if( ph == kDKDragMouseDragged )
	{
		if( multipleObjects )
		{
			if( mDidCopyDragObjects )
				[self setUndoAction:NSLocalizedString(@"Copy And Move Objects", @"undo string for copy and move (plural)")];
			else
				[self setUndoAction:NSLocalizedString(@"Move Multiple Objects", @"undo string for move multiple objects")];
		}
		else
		{
			if( mDidCopyDragObjects )
				[self setUndoAction:NSLocalizedString(@"Copy And Move Object", @"undo string for copy and move (singular)")];
			else
				[self setUndoAction:NSLocalizedString(@"Move Object", @"undo string for move single object")];
		}
	}
	
	// if the mouse wasn't dragged, select the single object if shift or command isn't down - this avoids the need to deselect all
	// before selecting a single object in an already selected group. By also testing mouse moved, the tool is smart
	// enough not to do this if it was an object drag that was done. Result for the user - intuitively thought-free behaviour. ;-)
			
	if( !mMouseMoved && ph == kDKDragMouseUp )
	{
		BOOL shift = ([event modifierFlags] & NSShiftKeyMask) != 0;
		BOOL cmd = ([event modifierFlags] & NSCommandKeyMask) != 0;
		
		if ( !shift && !cmd)
		{
			DKDrawableObject* single = [layer hitTest:p];
	
			if( single != nil)
				[layer replaceSelectionWithObject:single];
		}
	}
	
	// on mouse up restore the selection visibility if required
	
	if([self selectionShouldHideDuringDrag] && ph == kDKDragMouseUp )
		[layer setSelectionVisible:YES];
	
	[layer setRulerMarkerUpdatesEnabled:YES];
	[layer updateRulerMarkersForRect:[layer selectionLogicalBounds]];
}


///*********************************************************************************************************************
///
/// method:			setUndoAction:
/// scope:			public instance method
///	overrides:
/// description:	store a string representing an undoable action
/// 
/// parameters:		<action> a string
/// result:			none
///
/// notes:			the string is simply stored until requested by the caller, it does not at this stage set the
///					undo manager's action name.
///
///********************************************************************************************************************

- (void)			setUndoAction:(NSString*) action
{
	[action retain];
	[mUndoAction release];
	mUndoAction = action;
}


///*********************************************************************************************************************
///
/// method:			prepareDragImage:inLayer:
/// scope:			public instance method
///	overrides:
/// description:	prepare the proxy drag image for the given objects
/// 
/// parameters:		<objectsToDrag> the list of objects that will be dragged
///					<layer> the layer they are owned by
/// result:			an image, representing the dragged objects.
///
/// notes:			the default method creates the image by asking the layer to make one using its standard imaging
///					methods. You can override this for different approaches. Typically the drag image has the bounds of
///					the selected objects - the caller will position the image based on that assumption. This is only
///					invoked if the proxy drag threshold was exceeded and not zero.
///
///********************************************************************************************************************


#define SHOW_DRAG_PROXY_BOUNDARY		0


- (NSImage*)				prepareDragImage:(NSArray*) objectsToDrag inLayer:(DKObjectDrawingLayer*) layer
{
#pragma unused(objectsToDrag)
	
	NSImage* img = [layer imageOfSelectedObjects];
	
	// draw a dotted line around the boundary.
	
#if SHOW_DRAG_PROXY_BOUNDARY
	NSRect br = NSZeroRect;
	br.size = [img size];
	br = NSInsetRect( br, 1, 1 );
	NSBezierPath* bp = [NSBezierPath bezierPathWithRect:br];
	CGFloat pattern[] = { 4, 4 };
	
	[bp setLineWidth:1.0];
	[bp setLineDash:pattern count:2 phase:0];
	
	[img lockFocus];
	[[NSColor grayColor] set];
	[bp stroke];
	[img unlockFocus];
#endif
	
	return img;
}



///*********************************************************************************************************************
///
/// method:			proxyDragObjectsAsGroup:inLayer:toPoint:event:dragPhase:
/// scope:			private instance method
///	overrides:
/// description:	perform the proxy drag image for the given objects
/// 
/// parameters:		see dragObjectsAsGroup: etc.
/// result:			none
///
/// notes:			called internally when a proxy drag is detected. This will create the drag image on mouse down,
///					drag the image on a drag and clean up on mouse up. The point <p> is already pre-snapped for
///					a multi-object drag and the caller will take care of other normal housekeeping.
///
///********************************************************************************************************************

- (void)					proxyDragObjectsAsGroup:(NSArray*) objects inLayer:(DKObjectDrawingLayer*) layer toPoint:(NSPoint) p event:(NSEvent*) event dragPhase:(DKEditToolDragPhase) ph;
{
#pragma unused(event)
	
	static NSSize	offset;
	static NSPoint	anchor;
	
	switch( ph )
	{
		case kDKDragMouseDown:
		{
			if( mProxyDragImage == nil )
			{
				mProxyDragImage = [[self prepareDragImage:objects inLayer:layer] retain];
			
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

				NSEnumerator*		iter = [objects objectEnumerator];
				DKDrawableObject*	obj;
				
				while(( obj = [iter nextObject]))
					[obj setVisible:NO];

				[[layer undoManager] enableUndoRegistration];
			}
			mInProxyDrag = YES;
		}	
		break;
			
		case kDKDragMouseDragged:
		{
			[layer setNeedsDisplayInRect:mProxyDragDestRect];

			mProxyDragDestRect.size = [mProxyDragImage size];
			mProxyDragDestRect.origin.x = p.x - offset.width;
			mProxyDragDestRect.origin.y = p.y - offset.height;
			
			[layer setNeedsDisplayInRect:mProxyDragDestRect];
		}
		break;
			
		case kDKDragMouseUp:
		{
			[mProxyDragImage release];
			mProxyDragImage = nil;
			[layer setNeedsDisplayInRect:mProxyDragDestRect];
			
			// move the objects by the total drag distance
			
			CGFloat dx, dy;
			
			dx = p.x - anchor.x;
			dy = p.y - anchor.y;
			
			NSEnumerator* iter = [objects objectEnumerator];
			DKDrawableObject* obj;
			
			while(( obj = [iter nextObject]))
			{
				[obj offsetLocationByX:dx byY:dy];
				
				[[layer undoManager] disableUndoRegistration];
				[obj setVisible:YES];
				[[layer undoManager] enableUndoRegistration];
			}
			mInProxyDrag = NO;
		}	
		break;
			
		default:
			break;
	}
}


- (void)		setDraggedObjects:(NSArray*) objects
{
	[objects retain];
	[mDraggedObjects release];
	mDraggedObjects = objects;
}


- (NSArray*)	draggedObjects
{
	return mDraggedObjects;
}


- (BOOL)		finishUsingToolInLayer:(DKObjectDrawingLayer*) odl delegate:(id) aDel event:(NSEvent*) event
{
	NSArray*				sel = nil;
	DKDrawableObject*		obj;
	NSDictionary*			userInfoDict = [NSDictionary dictionaryWithObjectsAndKeys:odl, kDKSelectionToolTargetLayer, [odl singleSelection], kDKSelectionToolTargetObject, nil];
	BOOL					extended = (([event modifierFlags] & NSShiftKeyMask) != 0 );
	
	switch([self operationMode])
	{
		case kDKEditToolInvalidMode:
		default:
			break;
			
		case kDKEditToolSelectionMode:
			[self setMarqueeRect:NSRectFromTwoPoints( mAnchorPoint, mLastPoint ) inLayer:odl];
			
			if( NSIsEmptyRect([self marqueeRect]) && mWasInLockedObject )
			{
				obj = [odl hitTest:mLastPoint];
				[odl replaceSelectionWithObject:obj];
			}
			else
				sel = [odl objectsInRect:[self marqueeRect]];
			
			NSString*	undoStr = nil;
			
			if ([sel count] == 0 && !extended && !mWasInLockedObject)
			{
				// the marquee hit nothing, so deselect everything
				
				[odl deselectAll];
				undoStr = NSLocalizedString(@"Deselect All", @"undo string for deselect all");
			}
			else
				undoStr = NSLocalizedString(@"Change Selection", @"undo string for change selecton");
			
			if([odl selectionChangesAreUndoable])
			{
				[self setUndoAction:undoStr];
				
				// did we do anything undoable? compare the before and after selection state - if the same, the
				// answer is no.
				
				mPerformedUndoableTask = [odl selectionHasChangedFromRecorded];
			}
			[self setMarqueeRect:NSZeroRect inLayer:odl];
			
			// notify the delegate that an undo group will be needed for the selection change
			
			if( mPerformedUndoableTask )
				[aDel toolWillPerformUndoableAction:self];
			
			[[NSNotificationCenter defaultCenter] postNotificationName:kDKSelectionToolDidFinishSelectionDrag object:self userInfo:userInfoDict];
			break;
			
		case kDKEditToolMoveObjectsMode:
			sel = [self draggedObjects];
			
			if([sel count] > 0)
			{
				[self dragObjectsAsGroup:sel inLayer:odl toPoint:mLastPoint event:event dragPhase:kDKDragMouseUp];
				
				// directly inform the layer that the drag finished and how far the objects were moved
				
				if([odl respondsToSelector:@selector(objects:wereDraggedFromPoint:toPoint:)])
					[odl objects:sel wereDraggedFromPoint:mAnchorPoint toPoint:mLastPoint];
			}
			
			[[NSNotificationCenter defaultCenter] postNotificationName:kDKSelectionToolDidFinishMovingObjects object:self userInfo:userInfoDict];
			break;
			
		case kDKEditToolEditObjectMode:
			obj = [odl singleSelection];
			[obj mouseUpAtPoint:mLastPoint inPart:mPartcode event:event];
			[[NSNotificationCenter defaultCenter] postNotificationName:kDKSelectionToolDidFinishEditingObject object:self userInfo:userInfoDict];
			break;
	}
	[self setDraggedObjects:nil];
	return mPerformedUndoableTask;
}


#pragma mark -
#pragma mark - As part of DKDrawingTool Protocol


///*********************************************************************************************************************
///
/// method:			toolPerformsUndoableAction
/// scope:			public class method
///	overrides:		DKDrawingTool
/// description:	does the tool ever implement undoable actions?
/// 
/// parameters:		none
/// result:			always returns YES
///
/// notes:			returning YES means that the tool can POTENTIALLY do undoable things, not that it always will.
///
///********************************************************************************************************************

+ (BOOL)			toolPerformsUndoableAction
{
	return YES;	// in general, tasks performed by this tool create undo tasks
}


///*********************************************************************************************************************
///
/// method:			actionName
/// scope:			public instance method
///	overrides:		DKDrawingTool
/// description:	rerurn the current action name
/// 
/// parameters:		none
/// result:			a string, whatever was stored by setUndoAction:
///
/// notes:			
///
///********************************************************************************************************************

- (NSString*)		actionName
{
	return mUndoAction;
}


///*********************************************************************************************************************
///
/// method:			cursor
/// scope:			public instance method
///	overrides:		DKDrawingTool
/// description:	return the tool's cursor
/// 
/// parameters:		none
/// result:			the arrow cursor
///
/// notes:			
///
///********************************************************************************************************************

- (NSCursor*)		cursor
{
	return [NSCursor arrowCursor];
}


///*********************************************************************************************************************
///
/// method:			mouseDownAtPoint:targetObject:layer:event:delegate:
/// scope:			public instance method
///	overrides:		DKDrawingTool
/// description:	handle the initial mouse down
/// 
/// parameters:		<p> the local point where the mouse went down
///					<obj> the target object, if there is one
///					<layer> the layer in which the tool is being applied
///					<event> the original event
///					<aDel> an optional delegate
/// result:			the partcode of the target that was hit, or 0 (no object)
///
/// notes:			this method determines the context of the tool based on whether the tool hit an object or not,
///					whether a partcode (knob) was hit, the layer kind, etc. The operation mode of the tool is set
///					by this and applies for the subsequent drag/up methods.
///
///********************************************************************************************************************

- (NSInteger)				mouseDownAtPoint:(NSPoint) p targetObject:(DKDrawableObject*) obj layer:(DKLayer*) layer event:(NSEvent*) event delegate:(id) aDel
{
	#pragma unused(aDel)
	
	// first sanity check the layer kind - if it's not one that handles objects and selection, we can't operate.
	
	NSAssert( layer != nil, @"can't operate on a nil layer");
	
	mPartcode = kDKDrawingNoPart;
	
	mPerformedUndoableTask = NO;
	mDidCopyDragObjects = NO;
	mMouseMoved = NO;
	mWasInLockedObject = NO;
	mLastPoint = p;
	
	LogEvent_( kUserEvent, @"S/E tool mouse down, target = %@, layer = %@, pt = %@", obj, layer, NSStringFromPoint( p ));
	
	NSDictionary*	userInfoDict = [NSDictionary dictionaryWithObjectsAndKeys:layer, kDKSelectionToolTargetLayer, obj, kDKSelectionToolTargetObject, nil];
	
	if(![self isValidTargetLayer:layer])
	{
		// if the layer kind is not an object layer, the tool cannot be applied so set its mode to invalid
		
		[self setOperationMode:kDKEditToolInvalidMode];
	}
	else
	{
		// layer type is OK. Whether we will move, select or edit depends on what was initially hit and the current selection state.
		
		DKObjectDrawingLayer* odl = (DKObjectDrawingLayer*)layer;
	
		if( obj == nil )
		{
			// no initial target object, so the tool simply implements a drag selection
			
			[self setOperationMode:kDKEditToolSelectionMode];
			mAnchorPoint = mLastPoint = p;
			mMarqueeRect = NSRectFromTwoPoints( p, p );
			
			[[NSNotificationCenter defaultCenter] postNotificationName:kDKSelectionToolWillStartSelectionDrag object:self userInfo:userInfoDict];
		}
		else
		{
			// a target object was supplied. The tool will either move it (and optionally other selected ones), or edit it by dragging its
			// knobs. If the object is locked it can still be selected but not moved or resized, so it makes more sense to switch to a marquee drag in this case.
			
			if([obj locked] || [obj locationLocked])
			{
				[self setOperationMode:kDKEditToolSelectionMode];
				mAnchorPoint = mLastPoint = p;
				mMarqueeRect = NSRectFromTwoPoints( p, p );
				
				[[NSNotificationCenter defaultCenter] postNotificationName:kDKSelectionToolWillStartSelectionDrag object:self userInfo:userInfoDict];
				[self changeSelectionWithTarget:obj inLayer:odl event:event];
				mWasInLockedObject = YES;
				return kDKDrawingEntireObjectPart;
			}
		
			mPartcode = [obj hitPart:p];
			
			// detect a double-click and call the target object's method for fielding it
			
			if([event clickCount] > 1)
			{
				[obj mouseDoubleClickedAtPoint:p inPart:mPartcode event:event];
				return mPartcode;
			}

			NSUInteger sc = [odl countOfSelection];
			
			if ( mPartcode == kDKDrawingEntireObjectPart || (( sc > 1 ) && [self dragsAllObjectsInSelectionWhenDraggingKnob]))
			{
				// select the object and move it (and optionally any others in the selection)
				
				[self setOperationMode:kDKEditToolMoveObjectsMode];
				[self changeSelectionWithTarget:obj inLayer:odl event:event];
				
				// get the objects that will be operated on:
				// these are then cached locally so that we can perform fiendish operations on the objects without upsetting the layer.
				// This also should yield small performance improvements.
				
				NSArray* selection = [odl selectedAvailableObjects];
				[self setDraggedObjects:selection];
				
				if ([selection count] > 0 )
				{
					// if drag-copying is allowed, and the option key is down, make a copy of the selection and drag that
					
					if([self allowsDirectDragCopying] && ([event modifierFlags] & NSAlternateKeyMask) != 0 )
					{
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
					
					[[NSNotificationCenter defaultCenter] postNotificationName:kDKSelectionToolWillStartMovingObjects object:self userInfo:userInfoDict];
					
					// start the drag with the mouse down if there are any objects to drag
				
					[self dragObjectsAsGroup:selection inLayer:odl toPoint:p event:event dragPhase:kDKDragMouseDown];
				}
			}
			else
			{
				// edit the object - select it singly and pass the initial mouse-down
				
				[self setOperationMode:kDKEditToolEditObjectMode];
				[odl replaceSelectionWithObject:obj];
				
				// notify we are about to start:
				
				[[NSNotificationCenter defaultCenter] postNotificationName:kDKSelectionToolWillStartEditingObject object:self userInfo:userInfoDict];

				// setting nil here will cause the action name to be supplied by the object itself
			
				[self setUndoAction:nil];
				[obj mouseDownAtPoint:p inPart:mPartcode event:event];
			}
		}
	}
	
	return mPartcode;
}


///*********************************************************************************************************************
///
/// method:			mouseDraggedToPoint:partCode:layer:event:delegate:
/// scope:			public instance method
///	overrides:		DKDrawingTool
/// description:	handle the mouse dragged event
/// 
/// parameters:		<p> the local point where the mouse has been dragged to
///					<partCode> the partcode returned by the mouseDown method
///					<layer> the layer in which the tool is being applied
///					<event> the original event
///					<aDel> an optional delegate
/// result:			none
///
/// notes:			the delegate may be called to signal that an undoable task is about to be created at certain times.
///
///********************************************************************************************************************

- (void)			mouseDraggedToPoint:(NSPoint) p partCode:(NSInteger) pc layer:(DKLayer*) layer event:(NSEvent*) event delegate:(id) aDel
{
	BOOL					extended = (([event modifierFlags] & NSShiftKeyMask) != 0 );
	DKObjectDrawingLayer*	odl = (DKObjectDrawingLayer*) layer;
	NSArray*				sel;
	DKDrawableObject*		obj;
	NSAutoreleasePool*		pool = [NSAutoreleasePool new];
	
	// the mouse has actually been dragged, so flag that
	
	mMouseMoved = YES;
	mLastPoint = p;
	
	// depending on the mode, carry out the operation for a mousedragged event
	@try
	{
		switch([self operationMode])
		{
			case kDKEditToolInvalidMode:
			default:
				break;
				
			case kDKEditToolSelectionMode:
				[self setMarqueeRect:NSRectFromTwoPoints( mAnchorPoint, p ) inLayer:odl];

				sel = [odl objectsInRect:[self marqueeRect]];
				
				if ( extended )
					[odl addObjectsToSelectionFromArray:sel];
				else
					[odl exchangeSelectionWithObjectsFromArray:sel];
				
				break;
		
			case kDKEditToolMoveObjectsMode:
				sel = [self draggedObjects];
				
				if ([sel count] > 0 )
				{
					[aDel toolWillPerformUndoableAction:self];
					[self dragObjectsAsGroup:sel inLayer:odl toPoint:p event:event dragPhase:kDKDragMouseDragged];
					mPerformedUndoableTask = YES;
				}
				break;
				
			case kDKEditToolEditObjectMode:
				obj = [odl singleSelection];
				if ( obj != nil )
				{
					[aDel toolWillPerformUndoableAction:self];
					[obj mouseDraggedAtPoint:p inPart:pc event:event];
					mPerformedUndoableTask = YES;
				}
				break;
		}
	}
	@catch( NSException* exception )
	{
		NSLog(@"#### exception while dragging with selection tool: mode = %ld, exc = (%@) - ignored ####", (long)[self operationMode], exception );
	}
	
	[pool drain];
}


///*********************************************************************************************************************
///
/// method:			mouseUpAtPoint:partCode:layer:event:delegate:
/// scope:			public instance method
///	overrides:		DKDrawingTool
/// description:	handle the mouse up event
/// 
/// parameters:		<p> the local point where the mouse went up
///					<partCode> the partcode returned by the mouseDown method
///					<layer> the layer in which the tool is being applied
///					<event> the original event
///					<aDel> an optional delegate
/// result:			YES if the tool did something undoable, NO otherwise
///
/// notes:			the delegate may be called to signal that an undoable task is about to be created at certain times.
///
///********************************************************************************************************************

- (BOOL)			mouseUpAtPoint:(NSPoint) p partCode:(NSInteger) pc layer:(DKLayer*) layer event:(NSEvent*) event delegate:(id) aDel
{
	#pragma unused(pc)
	
	DKObjectDrawingLayer*	odl = (DKObjectDrawingLayer*) layer;
	mLastPoint = p;
	
	return [self finishUsingToolInLayer:odl delegate:aDel event:event];
}


///*********************************************************************************************************************
///
/// method:			drawRect:InView:
/// scope:			public instance method
///	overrides:		DKDrawingTool
/// description:	handle the initial mouse down
/// 
/// parameters:		<aRect> the rect being redrawn (not used)
///					<aView> the view that is doing the drawing
/// result:			none
///
/// notes:			draws the marquee (selection rect) in selection mode
///
///********************************************************************************************************************

#define		PROXY_DRAG_IMAGE_OPACITY		0.8


- (void)			drawRect:(NSRect) aRect inView:(NSView*) aView
{
	#pragma unused(aRect)
	
	if([self operationMode] == kDKEditToolSelectionMode)
		[self drawMarqueeInView:(DKDrawingView*)aView];
	else if ( mInProxyDrag && mProxyDragImage != nil )
	{
		// need to flip the image if needed
		
		SAVE_GRAPHICS_CONTEXT		//[NSGraphicsContext saveGraphicsState];
		
		if([aView isFlipped])
		{
			NSAffineTransform* unflipper = [NSAffineTransform transform];
			[unflipper translateXBy:mProxyDragDestRect.origin.x yBy:mProxyDragDestRect.origin.y + mProxyDragDestRect.size.height];
			[unflipper scaleXBy:1.0 yBy:-1.0];
			[unflipper concat];
		}
		
		// for slightly higher performance but less visual fidelity, comment this out:
		
		[[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
		
		// the drag image is drawn at 80% opacity to help with the "interleaving" issue. In practice this works pretty well.
		
		[mProxyDragImage drawAtPoint:NSZeroPoint fromRect:NSZeroRect operation:NSCompositeSourceAtop fraction:PROXY_DRAG_IMAGE_OPACITY];
		
		RESTORE_GRAPHICS_CONTEXT	//[NSGraphicsContext restoreGraphicsState];
	}
}


///*********************************************************************************************************************
///
/// method:			flagsChanged:inLayer:
/// scope:			public instance method
///	overrides:		DKDrawingTool
/// description:	the state of the modifier keys changed
/// 
/// parameters:		<event> the event
///					<layer> the current layer that the tool is being applied to
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)			flagsChanged:(NSEvent*) event inLayer:(DKLayer*) layer
{
	#pragma unused(event)
	#pragma unused(layer)
}


///*********************************************************************************************************************
///
/// method:			isValidTargetLayer:
/// scope:			public instance method
///	overrides:		DKDrawingTool
/// description:	verifies that the target layer can be used with the tool
/// 
/// parameters:		<aLayer> the current layer that the tool is being applied to
/// result:			YES if target layer can be operated on, NO otherwise
///
/// notes:			
///
///********************************************************************************************************************

- (BOOL)			isValidTargetLayer:(DKLayer*) aLayer
{
	if([aLayer respondsToSelector:@selector(canBeUsedWithSelectionTool)])
		return [aLayer canBeUsedWithSelectionTool];
	else
		return [aLayer isKindOfClass:[DKObjectDrawingLayer class]];
}


///*********************************************************************************************************************
///
/// method:			isSelectionTool
/// scope:			public instance method
///	overrides:		
/// description:	return whether the tool is some sort of object selection tool
/// 
/// parameters:		none
/// result:			YES
///
/// notes:			this method is used to assist the tool controller in making sensible decisions about certain
///					automatic operations.
///
///********************************************************************************************************************

- (BOOL)				isSelectionTool
{
	return YES;
}


///*********************************************************************************************************************
///
/// method:			setCursorForPoint:targetObject:inLayer:event:
/// scope:			public instance method
///	overrides:		DKDrawingTool
/// description:	set a cursor if the given point is over something interesting
/// 
/// parameters:		<mp> the local mouse point
///					<obj> the target object under the mouse, if any
///					<alayer> the active layer
///					<event> the original event
/// result:			none
///
/// notes:			called by the tool controller when the mouse moves, this should determine whether a special cursor
///					needs to be set right now and set it. If no special cursor needs to be set, it should set the
///					current one for the tool.
///
///********************************************************************************************************************

- (void)			setCursorForPoint:(NSPoint) mp targetObject:(DKDrawableObject*) obj inLayer:(DKLayer*) aLayer event:(NSEvent*) event
{
	#pragma unused(aLayer)
	#pragma unused(event)
	
	NSCursor* curs = [self cursor];
	
	if( obj != nil )
	{
		NSInteger pc = [obj hitPart:mp];
		curs = [obj cursorForPartcode:pc mouseButtonDown:NO];
	}
	
	[curs set];
}


///*********************************************************************************************************************
///
/// method:			toolControllerWillUnsetTool:
/// scope:			public instance method
///	overrides:		
/// description:	called when this tool is about to be unset by a tool controller
/// 
/// parameters:		<aController> the controller that set this tool
/// result:			none
///
/// notes:			subclasses can make use of this message to prepare themselves when they are unset if necessary, for
///					example by finishing the work they were doing and cleaning up.
///
///********************************************************************************************************************

- (void)				toolControllerWillUnsetTool:(DKToolController*) aController
{
	if([self isValidTargetLayer:[aController activeLayer]])
		[self finishUsingToolInLayer:(DKObjectDrawingLayer*)[aController activeLayer] delegate:aController event:[NSApp currentEvent]];
}




#pragma mark -
#pragma mark As part of the DKRenderable protocol

///*********************************************************************************************************************
///
/// method:			renderingPath:
/// scope:			public instance method
///	overrides:		NSObject (Rendering)
/// description:	return the marquee (selection rect) path to be rendered by the style
/// 
/// parameters:		none
/// result:			a bezier path - the current selection rect
///
/// notes:			
///
///********************************************************************************************************************

- (NSBezierPath*)	renderingPath
{
	return [NSBezierPath bezierPathWithRect:[self marqueeRect]];
}


///*********************************************************************************************************************
///
/// method:			angle:
/// scope:			public instance method
///	overrides:		NSObject (Rendering)
/// description:	required for the complete protocol
/// 
/// parameters:		none
/// result:			zero - the selection doesn't have an angle
///
/// notes:			
///
///********************************************************************************************************************

- (CGFloat)			angle
{
	return 0.0;
}


///*********************************************************************************************************************
///
/// method:			useLowQualityDrawing
/// scope:			public instance method
///	overrides:		NSObject (Rendering)
/// description:	required for the complete protocol
/// 
/// parameters:		none
/// result:			NO - selections never use low quality drawing
///
/// notes:			
///
///********************************************************************************************************************

- (BOOL)			useLowQualityDrawing
{
	return NO;
}


// these methods are here to comply with the formal protocol - they will not be called under nromal circumstances

- (NSSize)				size
{
	return [self marqueeRect].size;
}


- (NSPoint)				location
{
	return [self marqueeRect].origin;
}


- (NSAffineTransform*)	containerTransform
{
	return [NSAffineTransform transform];
}


- (NSSize)				extraSpaceNeeded
{
	return NSZeroSize;
}


- (NSRect)				bounds
{
	return [self marqueeRect];
}


- (NSUInteger)			geometryChecksum
{
	return 0;
}


#pragma mark -
#pragma mark As an NSObject

///*********************************************************************************************************************
///
/// method:			init
/// scope:			public instance method
///	overrides:		NSObject
/// description:	initialize the tool (designated initializer)
/// 
/// parameters:		none
/// result:			the tool object
///
/// notes:			
///
///********************************************************************************************************************

- (id)				init
{
	self = [super init];
	if( self != nil )
	{
		[self setMarqueeStyle:[[self class] defaultMarqueeStyle]];
		mHideSelectionOnDrag = YES;
		mAllowMultiObjectDrag = YES;
		mAllowDirectCopying = YES;
		mProxyDragThreshold = kDKSelectToolDefaultProxyDragThreshold;
	}
	
	return self;
}


///*********************************************************************************************************************
///
/// method:			dealloc
/// scope:			public instance method
///	overrides:		NSObject
/// description:	deallocate the tool
/// 
/// parameters:		none
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)			dealloc
{
	[mMarqueeStyle release];
	[mProxyDragImage release];
	[mDraggedObjects release];
	[super dealloc];
}

@end
