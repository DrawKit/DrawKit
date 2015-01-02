/**
 @author Graham Cox, Apptree.net
 @author Graham Miln, miln.eu
 @author Contributions from the community
 @date 2005-2014
 @copyright This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file.
 */

#import "DKDrawingView+Drop.h"
#import "DKObjectOwnerLayer.h"

extern DKDrawingView* sCurDView;

@implementation DKDrawingView (DropHandling)
#pragma mark As a DKDrawingView

/** @brief Returns the current active layer, by asking the controller for it

 DKDrawing maintains the active layer - look there for a method to set it
 @return a layer, the one that is currently active
 */
- (DKLayer*)activeLayer
{
	return [[self controller] activeLayer];
}

#pragma mark -
#pragma mark As part of NSDraggingDestination Protocol

/** @brief A drag entered the view
 @param sender the drag sender
 @return a drag operation constant */
- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender
{
	NSDragOperation result = NSDragOperationNone;

	if (![[self activeLayer] lockedOrHidden] && [[self activeLayer] respondsToSelector:@selector(draggingEntered:)]) {
		[[self window] performSelector:@selector(makeKeyAndOrderFront:)
							withObject:[self window]
							afterDelay:0.0];

		[self set];
		result = [[self activeLayer] draggingEntered:sender];
		[[self class] pop];
	}

	return result;
}

/** @brief A drag moved in the view
 @param sender the drag sender
 @return a drag operation constant */
- (NSDragOperation)draggingUpdated:(id<NSDraggingInfo>)sender
{
	NSDragOperation result = NSDragOperationNone;

	if (![[self activeLayer] lockedOrHidden] && [[self activeLayer] respondsToSelector:@selector(draggingUpdated:)]) {
		[self set];
		result = [[self activeLayer] draggingUpdated:sender];
		[[self class] pop];
	}

	return result;
}

/** @brief A drag left the view
 @param sender the drag sender
 @return a drag operation constant */
- (void)draggingExited:(id<NSDraggingInfo>)sender
{
	if (![[self activeLayer] lockedOrHidden] && [[self activeLayer] respondsToSelector:@selector(draggingExited:)]) {
		[self set];
		[[self activeLayer] draggingExited:sender];
		[[self class] pop];
	}
}

#pragma mark -

/** @brief Queries whether the active layer wantes periodic drag updates

 A layer implementing the NSDraggingDestination protocol should return the desired flag
 @return YES if perodic update are wanted, NO otherwise */
- (BOOL)wantsPeriodicDraggingUpdates
{
	BOOL result = NO;

	if (![[self activeLayer] lockedOrHidden] && [[self activeLayer] respondsToSelector:@selector(wantsPeriodicDraggingUpdates)]) {
		[self set];
		result = [[self activeLayer] wantsPeriodicDraggingUpdates];
		[[self class] pop];
	}

	return result;
}

#pragma mark -

/** @brief Perform the drop at the end of a drag
 @param sender the sender of the drag
 @return YES if the drop was handled, NO otherwise */
- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender
{
	BOOL result = NO;

	if (![[self activeLayer] lockedOrHidden] && [[self activeLayer] respondsToSelector:@selector(performDragOperation:)]) {
		[self set];
		result = [[self activeLayer] performDragOperation:sender];
		[[self class] pop];
	}

	return result;
}

/** @brief A drop is about to be performed, so get ready
 @param sender the sender of the drag
 @return YES if the drop will be handled, NO otherwise */
- (BOOL)prepareForDragOperation:(id<NSDraggingInfo>)sender
{
	BOOL result = NO;

	if (![[self activeLayer] lockedOrHidden] && [[self activeLayer] respondsToSelector:@selector(prepareForDragOperation:)]) {
		[self set];
		result = [[self activeLayer] prepareForDragOperation:sender];
		[[self class] pop];
	}

	return result;
}

/** @brief A drop was performed, so perform any final clean-up
 @param sender the sender of the drag */
- (void)concludeDragOperation:(id<NSDraggingInfo>)sender
{
	if (![[self activeLayer] lockedOrHidden] && [[self activeLayer] respondsToSelector:@selector(concludeDragOperation:)]) {
		[self set];
		[[self activeLayer] concludeDragOperation:sender];
		[[self class] pop];
	}
}

@end
