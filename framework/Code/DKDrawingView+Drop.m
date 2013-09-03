///**********************************************************************************************************************************
///  DKDrawingView+Drop.m
///  DrawKit ©2005-2008 Apptree.net
///
///  Created by jason on 1/11/2007.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
///
///**********************************************************************************************************************************

#import "DKDrawingView+Drop.h"
#import "DKObjectOwnerLayer.h"

extern DKDrawingView*	sCurDView;



@implementation DKDrawingView (DropHandling)
#pragma mark As a DKDrawingView


///*********************************************************************************************************************
///
/// method:			activeLayer
/// scope:			public instance method
/// overrides:		
/// description:	returns the current active layer, by asking the controller for it
/// 
/// parameters:		none
/// result:			a layer, the one that is currently active
///
/// notes:			DKDrawing maintains the active layer - look there for a method to set it
///
///********************************************************************************************************************

- (DKLayer*)			activeLayer
{
	return [[self controller] activeLayer];
}


#pragma mark -
#pragma mark As part of NSDraggingDestination Protocol


///*********************************************************************************************************************
///
/// method:			draggingEntered
/// scope:			protocol method
/// overrides:		NSDraggingDestination
/// description:	a drag entered the view
/// 
/// parameters:		<sender> the drag sender
/// result:			a drag operation constant
///
/// notes:			
///
///********************************************************************************************************************

- (NSDragOperation)		draggingEntered:(id <NSDraggingInfo>)sender
{
	NSDragOperation result = NSDragOperationNone;
	
	if (![[self activeLayer] lockedOrHidden] && [[self activeLayer] respondsToSelector:@selector(draggingEntered:)])
	{
		[[self window] performSelector:@selector(makeKeyAndOrderFront:) withObject:[self window] afterDelay:0.0];
		
		[self set];
		result = [[self activeLayer] draggingEntered:sender];
		[[self class] pop];
	}

	return result;
}


///*********************************************************************************************************************
///
/// method:			draggingUpdated
/// scope:			protocol method
/// overrides:		NSDraggingDestination
/// description:	a drag moved in the view
/// 
/// parameters:		<sender> the drag sender
/// result:			a drag operation constant
///
/// notes:			
///
///********************************************************************************************************************

- (NSDragOperation)		draggingUpdated:(id <NSDraggingInfo>)sender
{
	NSDragOperation result = NSDragOperationNone;
	
	if (![[self activeLayer] lockedOrHidden] && [[self activeLayer] respondsToSelector:@selector(draggingUpdated:)])
	{
		[self set];
		result = [[self activeLayer] draggingUpdated:sender];
		[[self class] pop];
	}

	return result;
}


///*********************************************************************************************************************
///
/// method:			draggingExited
/// scope:			protocol method
/// overrides:		NSDraggingDestination
/// description:	a drag left the view
/// 
/// parameters:		<sender> the drag sender
/// result:			a drag operation constant
///
/// notes:			
///
///********************************************************************************************************************

- (void)				draggingExited:(id <NSDraggingInfo>) sender
{
	if (![[self activeLayer] lockedOrHidden] && [[self activeLayer] respondsToSelector:@selector(draggingExited:)])
	{
		[self set];
		[[self activeLayer] draggingExited:sender];
		[[self class] pop];
	}
}


#pragma mark -


///*********************************************************************************************************************
///
/// method:			wantsPeriodicDraggingUpdates
/// scope:			protocol method
/// overrides:		NSDraggingDestination
/// description:	queries whether the active layer wantes periodic drag updates
/// 
/// parameters:		none
/// result:			YES if perodic update are wanted, NO otherwise
///
/// notes:			a layer implementing the NSDraggingDestination protocol should return the desired flag
///
///********************************************************************************************************************

- (BOOL)				wantsPeriodicDraggingUpdates
{
	BOOL result = NO;
	
	if (![[self activeLayer] lockedOrHidden] && [[self activeLayer] respondsToSelector:@selector(wantsPeriodicDraggingUpdates)])
	{
		[self set];
		result = [[self activeLayer] wantsPeriodicDraggingUpdates];
		[[self class] pop];
	}

	return result;
}


#pragma mark -

///*********************************************************************************************************************
///
/// method:			performDragOperation
/// scope:			protocol method
/// overrides:		NSDraggingDestination
/// description:	perform the drop at the end of a drag
/// 
/// parameters:		<sender> the sender of the drag
/// result:			YES if the drop was handled, NO otherwise
///
/// notes:			
///
///********************************************************************************************************************

- (BOOL)				performDragOperation:(id <NSDraggingInfo>) sender
{
	BOOL result = NO;
	
	if (![[self activeLayer] lockedOrHidden] && [[self activeLayer] respondsToSelector:@selector(performDragOperation:)])
	{
		[self set];
		result = [[self activeLayer] performDragOperation:sender];
		[[self class] pop];
	}

	return result;
}


///*********************************************************************************************************************
///
/// method:			prepareForDragOperation
/// scope:			protocol method
/// overrides:		NSDraggingDestination
/// description:	a drop is about to be performed, so get ready
/// 
/// parameters:		<sender> the sender of the drag
/// result:			YES if the drop will be handled, NO otherwise
///
/// notes:			
///
///********************************************************************************************************************

- (BOOL)				prepareForDragOperation:(id <NSDraggingInfo>) sender
{
	BOOL result = NO;
	
	if (![[self activeLayer] lockedOrHidden] && [[self activeLayer] respondsToSelector:@selector(prepareForDragOperation:)])
	{
		[self set];
		result = [[self activeLayer] prepareForDragOperation:sender];
		[[self class] pop];
	}

	return result;
}


///*********************************************************************************************************************
///
/// method:			concludeDragOperation
/// scope:			protocol method
/// overrides:		NSDraggingDestination
/// description:	a drop was performed, so perform any final clean-up
/// 
/// parameters:		<sender> the sender of the drag
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				concludeDragOperation:(id <NSDraggingInfo>) sender
{
	if (![[self activeLayer] lockedOrHidden] && [[self activeLayer] respondsToSelector:@selector(concludeDragOperation:)])
	{
		[self set];
		[[self activeLayer] concludeDragOperation:sender];
		[[self class] pop];
	}
}


@end


