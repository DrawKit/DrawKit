///**********************************************************************************************************************************
///  DKSelectAndEditTool.m
///  DrawKit
///
///  Created by graham on 8/04/2008.
///  Released under the Creative Commons license 2007 Apptree.net.
///
/// 
///  This work is licensed under the Creative Commons Attribution-ShareAlike 2.5 License.
///  To view a copy of this license, visit http://creativecommons.org/licenses/by-sa/2.5/ or send a letter to
///  Creative Commons, 543 Howard Street, 5th Floor, San Francisco, California, 94105, USA.
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
	NSColor* sc = [[NSColor grayColor] colorWithAlphaComponent:0.75];
	
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
		NSAutoreleasePool* pool = [NSAutoreleasePool new];
		
		NSSet* updateRegion = DifferenceOfTwoRects( omr, marqueeRect );
		
		// the extra padding here is OK for the default style - if you use something with a
		// bigger stroke this may need changing
		
		[aLayer setNeedsDisplayInRects:updateRegion withExtraPadding:NSMakeSize( 2.5, 2.5 )];
	
		mMarqueeRect = marqueeRect;
		
		[pool drain];
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


- (void)				setAllowsDirectDragCopying:(BOOL) dragCopy
{
	mAllowDirectCopying = dragCopy;
}


- (BOOL)				allowsDirectDragCopying
{
	return mAllowDirectCopying;
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
	
	BOOL extended = (([event modifierFlags] & NSShiftKeyMask) != 0 );
	BOOL invert = (([event modifierFlags] & NSCommandKeyMask) != 0 );
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

- (void)				dragObjectsAsGroup:(NSArray*) objects inLayer:(DKObjectDrawingLayer*) layer toPoint:(NSPoint) p event:(NSEvent*) event dragPhase:(DKEditToolDragPhase) ph
{
	NSAssert( objects != nil, @"attempt to drag with nil array");
	NSAssert([objects count] > 0, @"attempt to drag with empty array");
	
	NSEnumerator*		iter = [objects objectEnumerator];
	DKDrawableObject*	o;
	BOOL				saveSnap = NO;
	BOOL				multipleObjects;
	BOOL				saveShowsInfo = NO;
	
	// if set to hide the selection highlight during a drag, test that here and set the highlight visible
	// as required on the initial mouse down
	
	if([self selectionShouldHideDuringDrag] && ph == kDKDragMouseDragged )
		[layer setSelectionVisible:NO];
		
	// if the mouse has left the layer's drag exclusion rect, this starts a drag of the objects as a "real" drag. Test for that here
	// and initiate the drag if needed. The drag will keep control until the items are dropped.
	
	NSRect der = [layer dragExclusionRect];
	if( ! NSPointInRect( p, der ))
	{
		[layer beginDragOfSelectedObjectsWithEvent:event inView:[layer currentView]];
		if([self selectionShouldHideDuringDrag])
			[layer setSelectionVisible:YES];
		return;
	}
	
	multipleObjects = [objects count] > 1;
	
	// when moved as a group, individual mouse snapping is supressed - instead we snap the input point to the grid and
	// apply it to all - as usual control key can disable (or enable) snapping temporarily
	
	if ( multipleObjects )
	{
		BOOL controlKey = ([event modifierFlags] & NSControlKeyMask) != 0;
		p = [[layer drawing] snapToGrid:p withControlFlag:controlKey];
	}
	
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
				[o mouseDownAtPoint:p inPart:kGCDrawingEntireObjectPart event:event];
				[o notifyVisualChange];
				break;
				
			case kDKDragMouseDragged:
				[o mouseDraggedAtPoint:p inPart:kGCDrawingEntireObjectPart event:event];
				break;
				
			case kDKDragMouseUp:
				[o mouseUpAtPoint:p inPart:kGCDrawingEntireObjectPart event:event];
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

- (int)				mouseDownAtPoint:(NSPoint) p targetObject:(DKDrawableObject*) obj layer:(DKLayer*) layer event:(NSEvent*) event delegate:(id) aDel
{
	#pragma unused(aDel)
	
	// first sanity check the layer kind - if it's not one that handles objects and selection, we can't operate.
	
	NSAssert( layer != nil, @"can't operate on a nil layer");
	
	int partCode = kGCDrawingNoPart;
	
	mPerformedUndoableTask = NO;
	mDidCopyDragObjects = NO;
	mMouseMoved = NO;
	
	if(![layer isKindOfClass:[DKObjectDrawingLayer class]])
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
			mAnchorPoint = p;
			mMarqueeRect = NSRectFromTwoPoints( p, p );
		}
		else
		{
			// a target object was supplied. The tool will either move it (and optionally other selected ones), or edit it by dragging its
			// knobs. 
		
			partCode = [obj hitPart:p];
			
			if ( partCode == kGCDrawingEntireObjectPart )
			{
				// select the object and move it (and optionally any others in the selection)
				
				[self setOperationMode:kDKEditToolMoveObjectsMode];
				[self changeSelectionWithTarget:obj inLayer:odl event:event];
				
				// get the objects that will be operated on:
				
				NSArray* selection = [odl selectedAvailableObjects];
				
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
						[odl addObjects:selection];
						[odl exchangeSelectionWithObjectsInArray:selection];
					}
					
					// start the drag with the mouse down if there are any objects to drag
				
					[self dragObjectsAsGroup:selection inLayer:odl toPoint:p event:event dragPhase:kDKDragMouseDown];
				}
			}
			else
			{
				// edit the object - select it singly and pass the initial mouse-down
				
				[self setOperationMode:kDKEditToolEditObjectMode];
				[odl replaceSelectionWithObject:obj];
			
				// setting nil here will cause the action name to be supplied by the object itself
			
				[self setUndoAction:nil];
				[obj mouseDownAtPoint:p inPart:partCode event:event];
			}
		}
	}
	
	return partCode;
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

- (void)			mouseDraggedToPoint:(NSPoint) p partCode:(int) pc layer:(DKLayer*) layer event:(NSEvent*) event delegate:(id) aDel
{
	BOOL					extended = (([event modifierFlags] & NSShiftKeyMask) != 0 );
	DKObjectDrawingLayer*	odl = (DKObjectDrawingLayer*) layer;
	NSArray*				sel;
	DKDrawableObject*		obj;
	
	// the mouse has actually been dragged, so flag that
	
	mMouseMoved = YES;
	
	// depending on the mode, carry out the operation for a mousedragged event
	
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
				[odl exchangeSelectionWithObjectsInArray:sel];
			
			break;
	
		case kDKEditToolMoveObjectsMode:
			sel = [odl selectedAvailableObjects];
			
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

- (BOOL)			mouseUpAtPoint:(NSPoint) p partCode:(int) pc layer:(DKLayer*) layer event:(NSEvent*) event delegate:(id) aDel
{
	#pragma unused(aDel)
	
	BOOL					extended = (([event modifierFlags] & NSShiftKeyMask) != 0 );
	DKObjectDrawingLayer*	odl = (DKObjectDrawingLayer*) layer;
	NSArray*				sel;
	DKDrawableObject*		obj;
	
	switch([self operationMode])
	{
		case kDKEditToolInvalidMode:
		default:
			break;
			
		case kDKEditToolSelectionMode:
			[self setMarqueeRect:NSRectFromTwoPoints( mAnchorPoint, p ) inLayer:odl];
			sel = [odl objectsInRect:[self marqueeRect]];
			
			NSString*	undoStr = nil;
			
			if ([sel count] == 0 && !extended)
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
			break;
	
		case kDKEditToolMoveObjectsMode:
			sel = [odl selectedAvailableObjects];
			
			if([sel count] > 0)
				[self dragObjectsAsGroup:sel inLayer:odl toPoint:p event:event dragPhase:kDKDragMouseUp];
			
			break;
			
		case kDKEditToolEditObjectMode:
			obj = [odl singleSelection];
			[obj mouseUpAtPoint:p inPart:pc event:event];
			break;
	}
	
	return mPerformedUndoableTask;
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

- (void)			drawRect:(NSRect) aRect inView:(NSView*) aView
{
	#pragma unused(aRect)
	
	if([self operationMode] == kDKEditToolSelectionMode)
		[self drawMarqueeInView:(DKDrawingView*)aView];
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


- (BOOL)			isValidTargetLayer:(DKLayer*) aLayer
{
	return [aLayer isKindOfClass:[DKObjectDrawingLayer class]];
}



///*********************************************************************************************************************
///
/// method:			setCursorForPoint:targetObject:inLayer:buttonDown:
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
		int pc = [obj hitPart:mp];
		curs = [obj cursorForPartcode:pc mouseButtonDown:NO];
	}
	
	[curs set];
}



#pragma mark -
#pragma mark As part of the NSObject (Rendering) protocol

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

- (float)			angle
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
	[super dealloc];
}

@end
