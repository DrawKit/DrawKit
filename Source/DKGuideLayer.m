/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import "DKGuideLayer.h"
#import "DKDrawingView.h"
#import "DKDrawing.h"
#import "DKGridLayer.h"
#import "GCInfoFloater.h"
#import "NSColor+DKAdditions.h"
#import "DKUndoManager.h"

#define DK_DRAW_GUIDES_IN_CLIP_VIEW 0

@interface DKGuideLayer (Private)

/** @brief Moves a given guide to a new point

 Called by mouseDragged, allows undo of a move.
 @param guide the guide to move
 @param p where to move it to
 @param aView which view it's drawn in
 */
- (void)repositionGuide:(DKGuide*)guide atPoint:(NSPoint)p inView:(NSView*)aView;
- (NSRect)guideRectOfGuide:(DKGuide*)guide forEnclosingClipViewOfView:(NSView*)aView;

@end

#pragma mark Static Vars
static CGFloat sSnapTolerance = 6.0;

// tracks the cursor position whlie dragging modally

static BOOL sWasInside = NO;

#pragma mark -
@implementation DKGuideLayer
#pragma mark As a DKGuideLayer

/** @brief Sets the distance a point needs to be before it is snapped to a guide
 @param tol the distance in points
 */
+ (void)setDefaultSnapTolerance:(CGFloat)tol
{
	sSnapTolerance = tol;
}

/** @brief Returns the distance a point needs to be before it is snapped to a guide
 @return the distance in points
 */
+ (CGFloat)defaultSnapTolerance
{
	return sSnapTolerance;
}

#pragma mark -

/** @brief Adds a guide to the layer

 Sets the guide's colour to the layer's guide colour initially - after adding the guide colour can
 be set individually if desired.
 @param guide an existing guide object
 */
- (void)addGuide:(DKGuide*)guide
{
	NSAssert(guide != nil, @"attempt to add a nil guide to a guide layer");

	[[[self undoManager] prepareWithInvocationTarget:self] removeGuide:guide];

	if ([guide isVerticalGuide])
		[m_vGuides addObject:guide];
	else
		[m_hGuides addObject:guide];

	[guide setGuideColour:[self guideColour]];
	[self refreshGuide:guide];

	if (!([[self undoManager] isUndoing] || [[self undoManager] isRedoing]))
		[[self undoManager] setActionName:NSLocalizedString(@"Add Guide", @"undo action for Add Guide")];
}

/** @brief Removes a guide from the layer
 @param guide an existing guide object
 */
- (void)removeGuide:(DKGuide*)guide
{
	NSAssert(guide != nil, @"attempt to remove a nil guide from a guide layer");

	[[[self undoManager] prepareWithInvocationTarget:self] addGuide:guide];

	[self refreshGuide:guide];

	if ([guide isVerticalGuide])
		[m_vGuides removeObject:guide];
	else
		[m_hGuides removeObject:guide];

	if (!([[self undoManager] isUndoing] || [[self undoManager] isRedoing]))
		[[self undoManager] setActionName:NSLocalizedString(@"Delete Guide", @"undo action for Remove Guide")];
}

/** @brief Removes all guides permanently from the layer
 */
- (void)removeAllGuides
{
	if (![self locked]) {
		[[[self undoManager] prepareWithInvocationTarget:self] setGuides:[self guides]];

		[m_vGuides removeAllObjects];
		[m_hGuides removeAllObjects];
		[self setNeedsDisplay:YES];
	}
}

#pragma mark -

/** @brief Locates the nearest guide to the given position, if position is within the snap tolerance
 @param pos a verical coordinate value, in points
 @return the nearest guide to the given point that lies within the snap tolerance, or nil
 */
- (DKGuide*)nearestVerticalGuideToPosition:(CGFloat)pos
{
	DKGuide* nearestGuide = nil;
	CGFloat nearestDistance = 10000, distance;

	for (DKGuide* guide in [self verticalGuides]) {
		distance = _CGFloatFabs(pos - [guide guidePosition]);

		if (distance < [self snapTolerance] && distance < nearestDistance) {
			nearestDistance = distance;
			nearestGuide = guide;
		}
	}

	return nearestGuide;
}

/** @brief Locates the nearest guide to the given position, if position is within the snap tolerance
 @param pos a horizontal coordinate value, in points
 @return the nearest guide to the given point that lies within the snap tolerance, or nil
 */
- (DKGuide*)nearestHorizontalGuideToPosition:(CGFloat)pos
{
	DKGuide* nearestGuide = nil;
	CGFloat nearestDistance = 10000, distance;

	for (DKGuide* guide in [self horizontalGuides]) {
		distance = _CGFloatFabs(pos - [guide guidePosition]);

		if (distance < [self snapTolerance] && distance < nearestDistance) {
			nearestDistance = distance;
			nearestGuide = guide;
		}
	}

	return nearestGuide;
}

/** @brief Returns the list of vertical guides

 The guides returns are not in any particular order
 @return an array of DKGuide objects
 */
- (NSArray*)verticalGuides
{
	return m_vGuides;
}

/** @brief Returns the list of horizontal guides

 The guides returns are not in any particular order
 @return an array of DKGuide objects
 */
- (NSArray*)horizontalGuides
{
	return m_hGuides;
}

#pragma mark -

@synthesize guidesSnapToGrid=m_snapToGrid;

#pragma mark -

/** @brief Snap a given point to any nearest guides within the snap tolerance

 X and y coordinates of the point are of course, individually snapped, so only one coordinate
 might be modified, as well as none or both.
 @param p a point in local drawing coordinates 
 @return a point, either the same point passed in, or a modified one that has been snapped to the guides
 */
- (NSPoint)snapPointToGuide:(NSPoint)p
{
	// if the point <p> is within the snap tolerance of any guide, the returned point is snapped to that guide. Otherwise the
	// returned point is the same as p.

	DKGuide* vg;
	DKGuide* hg;
	NSPoint ps;

	vg = [self nearestVerticalGuideToPosition:p.x];
	hg = [self nearestHorizontalGuideToPosition:p.y];

	if (vg)
		ps.x = [vg guidePosition];
	else
		ps.x = p.x;

	if (hg)
		ps.y = [hg guidePosition];
	else
		ps.y = p.y;

	return ps;
}

/** @brief Snaps any corner of the given rect to any nearest guides within the snap tolerance

 The rect size is never changed by this method, but its origin may be. Does not snap the centres.
 @param r a rect in local drawing coordinates 
 @return a rect, either the same rect passed in, or a modified one that has been snapped to the guides
 */
- (NSRect)snapRectToGuide:(NSRect)r
{
	return [self snapRectToGuide:r
				includingCentres:NO];
}

/** @brief Snaps any corner or centre point of the given rect to any nearest guides within the snap tolerance

 The rect size is never changed by this method, but its origin may be.
 @param r a rect in local drawing coordinates 
 @param centre YES to also snap mid points of all sides, NO to just snap the corners
 @return a rect, either the same rect passed in, or a modified one that has been snapped to the guides
 */
- (NSRect)snapRectToGuide:(NSRect)r includingCentres:(BOOL)centre
{
	NSRect sr;
	DKGuide* guide;

	sr = r;

	// look for vertical snaps first

	guide = [self nearestVerticalGuideToPosition:NSMinX(r)];
	if (guide)
		sr.origin.x = [guide guidePosition];
	else {
		guide = [self nearestVerticalGuideToPosition:NSMaxX(r)];
		if (guide)
			sr.origin.x = [guide guidePosition] - sr.size.width;
		else if (centre) {
			guide = [self nearestVerticalGuideToPosition:NSMidX(r)];
			if (guide)
				sr.origin.x = [guide guidePosition] - (sr.size.width / 2.0);
		}
	}

	// horizontal snaps

	guide = [self nearestHorizontalGuideToPosition:NSMinY(r)];
	if (guide)
		sr.origin.y = [guide guidePosition];
	else {
		guide = [self nearestHorizontalGuideToPosition:NSMaxY(r)];
		if (guide)
			sr.origin.y = [guide guidePosition] - sr.size.height;
		else if (centre) {
			guide = [self nearestHorizontalGuideToPosition:NSMidY(r)];
			if (guide)
				sr.origin.y = [guide guidePosition] - (sr.size.height / 2.0);
		}
	}

	return sr;
}

#pragma mark -

/** @brief Snaps any of a list of points to any nearest guides within the snap tolerance

 This is intended as one step in the snapping of a complex object to the guides, where points are
 arbitrarily distributed (e.g. not in a rect). Any of the points can snap to the guide - the first
 point in the list that actually snaps is used. The return value is intended to be used to offset
 a mouse point or similar so that the whole object is shifted by that amount to effect the snap.
 Note that h and v offsets are independent, and may not refer to the same actual input point.
 @param arrayOfPoints a list of NSValue object containing pointValues 
 @return a size, being the offset between whichever point was snapped and its snapped position
 */
- (NSSize)snapPointsToGuide:(NSArray*)arrayOfPoints
{
	return [self snapPointsToGuide:arrayOfPoints
					 verticalGuide:NULL
				   horizontalGuide:NULL];
}

/** @brief Snaps any of a list of points to any nearest guides within the snap tolerance

 This is intended as one step in the snapping of a complex object to the guides, where points are
 arbitrarily distributed (e.g. not in a rect). Any of the points can snap to the guide - the first
 point in the list that actually snaps is used. The return value is intended to be used to offset
 a mouse point or similar so that the whole object is shifted by that amount to effect the snap.
 Note that h and v offsets are independent, and may not refer to the same actual input point.
 @param arrayOfPoints a list of NSValue object containing pointValues 
 @param gv if not NULL, receives the actual vertical guide snapped to
 @param gh if not NULL, receives the actual horizontal guide snapped to
 @return a size, being the offset between whichever point was snapped and its snapped position
 */
- (NSSize)snapPointsToGuide:(NSArray*)arrayOfPoints verticalGuide:(DKGuide**)gv horizontalGuide:(DKGuide**)gh
{
	NSPoint p;
	NSSize result = NSZeroSize;
	DKGuide* guide;

	for (NSValue* v in arrayOfPoints) {
		p = [v pointValue];

		if (result.height == 0) {
			guide = [self nearestHorizontalGuideToPosition:p.y];

			if (guide) {
				result.height = [guide guidePosition] - p.y;

				if (gh)
					*gh = guide;
			}
		}

		if (result.width == 0) {
			guide = [self nearestVerticalGuideToPosition:p.x];

			if (guide) {
				result.width = [guide guidePosition] - p.x;

				if (gv)
					*gv = guide;
			}
		}

		if (result.width != 0 && result.height != 0)
			break;
	}

	return result;
}

#pragma mark -

@synthesize snapTolerance=m_snapTolerance;

#pragma mark -

/** @brief Marks a partiuclar guide as needing to be readrawn
 @param guide the guide to update
 */
- (void)refreshGuide:(DKGuide*)guide
{
	NSAssert(guide != nil, @"guide was nil in refreshGuide");

	[self setNeedsDisplayInRect:[self guideRect:guide]];
}

/** @brief Returns the rect occupied by a given guide

 This allows a small amount either side of the guide, and runs the full dimension of the drawing
 in the direction of the guide.
 @param guide the guide whose rect we are interested in
 @return a rect, in drawing coordinates
 */
- (NSRect)guideRect:(DKGuide*)guide
{
	NSAssert(guide != nil, @"guide was nil in guideRect:");

	NSRect r;
	NSSize ds = [[self drawing] drawingSize];

	if ([guide isVerticalGuide]) {
		r.origin.x = [guide guidePosition] - 1.0;
		r.origin.y = 0.0;
		r.size.width = 2.0;
		r.size.height = ds.height;
	} else {
		r.origin.y = [guide guidePosition] - 1.0;
		r.origin.x = 0.0;
		r.size.height = 2.0;
		r.size.width = ds.width;
	}

	return r;
}

/** @brief Creates a new vertical guide at the point p, adds it to the layer and returns it

 This is a convenient way to add a guide interactively, for example when dragging one "off" a
 ruler. See DKViewController for an example client of this method. If the layer is locked this
 does nothing and returns nil.
 @param p a point local to the drawing
 @return the guide created, or nil
 */
- (DKGuide*)createVerticalGuideAndBeginDraggingFromPoint:(NSPoint)p
{
	DKGuide* guide = nil;

	if (![self locked]) {
		guide = [[DKGuide alloc] init];

		[guide setGuidePosition:p.x];
		[guide setIsVerticalGuide:YES];
		[self addGuide:guide];

		// the layer is made active & visible so that the user gets the layer's cursor feedback and can reposition the guide if
		// it ends up not quite where they intended.

		[self setVisible:YES];
		[[self drawing] setActiveLayer:self];

		m_dragGuideRef = guide;
		sWasInside = NO;
	}

	return guide;
}

/** @brief Creates a new horizontal guide at the point p, adds it to the layer and returns it

 This is a convenient way to add a guide interactively, for example when dragging one "off" a
 ruler. See DKViewController for an example client of this method. If the layer is locked this
 does nothing and returns nil.
 @param p a point local to the drawing
 @return the guide created, or nil
 */
- (DKGuide*)createHorizontalGuideAndBeginDraggingFromPoint:(NSPoint)p
{
	DKGuide* guide = nil;

	if (![self locked]) {
		guide = [[DKGuide alloc] init];

		[guide setGuidePosition:p.y];
		[guide setIsVerticalGuide:NO];
		[self addGuide:guide];

		// the layer is made active and visible so that the user gets the layer's cursor feedback and can reposition the guide if
		// it ends up not quite where they intended.

		[self setVisible:YES];
		[[self drawing] setActiveLayer:self];

		m_dragGuideRef = guide;
		sWasInside = NO;
	}

	return guide;
}

/** @brief Get all current guides
 @return an array of guide objects
 */
- (NSArray*)guides
{
	NSMutableArray* ga = [[self horizontalGuides] mutableCopy];
	[ga addObjectsFromArray:[self verticalGuides]];
	return ga;
}

/** @brief Adds a set of guides to th elayer
 @param guides an array of guide objects
 */
- (void)setGuides:(NSArray*)guides
{
	NSAssert(guides != nil, @"can't set guides from nil array");

	for (DKGuide* guide in guides) {
		if ([guide isKindOfClass:[DKGuide class]])
			[self addGuide:guide];
	}
}

- (void)repositionGuide:(DKGuide*)guide atPoint:(NSPoint)p inView:(NSView*)aView
{
	NSPoint oldPoint = p;
	CGFloat newPos;

	if ([guide isVerticalGuide]) {
		oldPoint.x = [guide guidePosition];
		newPos = p.x;
	} else {
		oldPoint.y = [guide guidePosition];
		newPos = p.y;
	}

	if (!NSEqualPoints(oldPoint, p)) {
		[[[self undoManager] prepareWithInvocationTarget:self] repositionGuide:guide
																	   atPoint:oldPoint
																		inView:aView];

#if DK_DRAW_GUIDES_IN_CLIP_VIEW
		NSRect gr = [self guideRectOfGuide:guide
				forEnclosingClipViewOfView:aView];
		NSClipView* clipView = [[aView enclosingScrollView] contentView];

		if (clipView)
			[clipView setNeedsDisplayInRect:gr];
		else
#endif
			[self refreshGuide:guide];
		[guide setGuidePosition:newPos];
#if DK_DRAW_GUIDES_IN_CLIP_VIEW
		gr = [self guideRectOfGuide:guide
			forEnclosingClipViewOfView:aView];
		if (clipView)
			[clipView setNeedsDisplayInRect:gr];
		else
#endif
			[self refreshGuide:guide];
	}
}

- (NSRect)guideRectOfGuide:(DKGuide*)guide forEnclosingClipViewOfView:(NSView*)aView
{
	NSClipView* clipView = [[aView enclosingScrollView] contentView];

	if (clipView) {
		NSRect br = [clipView bounds];
		NSRect gr = [self guideRect:guide];
		NSRect rr;

		NSPoint topLeft = [clipView convertPoint:gr.origin
										fromView:aView];

		if ([guide isVerticalGuide]) {
			rr.origin.x = topLeft.x;
			rr.origin.y = NSMinY(br);
			rr.size.height = NSHeight(br);
			rr.size.width = NSWidth(gr);
		} else {
			rr.origin.x = NSMinX(br);
			rr.origin.y = topLeft.y;
			rr.size.width = NSWidth(br);
			rr.size.height = NSHeight(gr);
		}

		return rr;
	} else
		return NSZeroRect; // no clip view
}

#pragma mark -

@synthesize showsDragInfoWindow=m_showDragInfo;
@synthesize guideDeletionRect=mGuideDeletionZone;

- (void)setGuidesDrawnInEnclosingScrollview:(BOOL)drawOutside
{
	mDrawGuidesInClipView = drawOutside;
	[self setNeedsDisplay:YES];
}

@synthesize guidesDrawnInEnclosingScrollview=mDrawGuidesInClipView;

#pragma mark -

/** @brief High level action to remove all guides from the layer

 Can be hooked directly to a menu item for clearing the guides - will be available when the guide
 layer is active. Does nothing if the layer is locked.
 @param sender the action's sender
 */
- (IBAction)clearGuides:(id)sender
{
#pragma unused(sender)

	if (![self locked]) {
		[self removeAllGuides];
		[[self undoManager] setActionName:NSLocalizedString(@"Clear Guides", @"undo string for clear guides")];
	}
}

#pragma mark -

/** @brief Set the colour of all guides in this layer to a given colour

 The guide colour is actually synonymous with the "selection" colour inherited from DKLayer, but
 also each guide is able to have its own colour. This sets the colour for each guide to be the same
 so you may prefer to obtain a particular guide and set it individually.
 @param colour the colour to set
 */

/** @brief Sets the guide's colour

 Note that this doesn't mark the guide for update - DKGuideLayer has a method for doing that.
 @param colour a colour 
 */
- (void)setGuideColour:(NSColor*)colour
{
	if (![self locked] && colour != [self guideColour]) {
		[[[self undoManager] prepareWithInvocationTarget:self] setGuideColour:[self guideColour]];

		[[self verticalGuides] makeObjectsPerformSelector:@selector(setGuideColour:)
											   withObject:colour];
		[[self horizontalGuides] makeObjectsPerformSelector:@selector(setGuideColour:)
												 withObject:colour];
		[super setSelectionColour:colour];

		if (!([[self undoManager] isUndoing] || [[self undoManager] isRedoing]))
			[[self undoManager] setActionName:NSLocalizedString(@"Change Guide Colour", @"undo action for Guide colour")];
	}
}

/** @brief Return the layer's guide colour

 The guide colour is actually synonymous with the "selection" colour inherited from DKLayer, but
 also each guide is able to have its own colour. This returns the selection colour, but if guides
 have their own colours this says nothing about them.
 @return a colour
 */

/** @brief Returns the guide's colour
 @return a colour
 */
- (NSColor*)guideColour
{
	return [self selectionColour];
}

#pragma mark -
#pragma mark As a DKLayer

/** @brief Draws the guide layer
 @param rect the overall rect needing update
 @param aView the view that's doing it
 */
- (void)drawRect:(NSRect)rect inView:(DKDrawingView*)aView
{
	CGFloat savedLineWidth, lineWidth = ([aView scale] < 1.0) ? 1.0 : (2.0 / [aView scale]);

	savedLineWidth = [NSBezierPath defaultLineWidth];

#if DK_DRAW_GUIDES_IN_CLIP_VIEW
	NSClipView* clipView = [[aView enclosingScrollView] contentView];

	if (clipView && aView) {
		[NSBezierPath setDefaultLineWidth:1.0];

		SAVE_GRAPHICS_CONTEXT

		[clipView lockFocus];

		NSRect br = [clipView bounds];
		[NSBezierPath clipRect:br];

		for (DKGuide* guide in self.guides) {
			NSRect gr = [self guideRectOfGuide:guide
					forEnclosingClipViewOfView:aView];

			if ([clipView needsToDrawRect:gr]) {
				CGFloat pos = [guide guidePosition];
				BOOL vert = [guide isVerticalGuide];
				NSPoint a, b;

				if (vert)
					a.x = b.x = pos;
				else
					a.y = b.y = pos;

				a = [clipView convertPoint:a
								  fromView:aView];
				b = [clipView convertPoint:b
								  fromView:aView];

				if (vert) {
					a.y = NSMinX(br);
					b.y = NSMaxY(br);
				} else {
					a.x = NSMinX(br);
					b.x = NSMaxX(br);
				}

				[[guide guideColour] set];
				[NSBezierPath strokeLineFromPoint:a
										  toPoint:b];
			}
		}

		[clipView unlockFocus];

		RESTORE_GRAPHICS_CONTEXT
	} else
#endif
	{
		[NSBezierPath setDefaultLineWidth:lineWidth];

		for (DKGuide* guide in self.guides) {
			if (aView == nil || [aView needsToDrawRect:[self guideRect:guide]])
				[guide drawInRect:rect
						lineWidth:lineWidth];
		}
	}

	[NSBezierPath setDefaultLineWidth:savedLineWidth];
}

/** @brief Test whether the point "hits" the layer

 To be considered a "hit", the point needs to be within the snap tolerance of a guide.
 @param p a point in local (drawing) coordinates
 @return YES if any guide was hit, NO otherwise
 */
- (BOOL)hitLayer:(NSPoint)p
{
	DKGuide* dg;

	dg = [self nearestHorizontalGuideToPosition:p.y];

	if (dg)
		return YES;
	else {
		dg = [self nearestVerticalGuideToPosition:p.x];

		if (dg)
			return YES;
	}

	return NO;
}

/** @brief Respond to a mouseDown event

 Begins the drag of a guide, if the layer isn't locked. Determines which guide will be dragged
 and sets m_dragGuideRef to it.
 @param event the mouseDown event
 @param view where it came from
 */
- (void)mouseDown:(NSEvent*)event inView:(NSView*)view
{
	if (![self locked]) {
		NSPoint p = [view convertPoint:[event locationInWindow]
							  fromView:nil];
		BOOL isNewGuide = NO;

		if (m_dragGuideRef == nil) {
			DKGuide* dg = [self nearestHorizontalGuideToPosition:p.y];
			if (dg)
				m_dragGuideRef = dg;
			else {
				dg = [self nearestVerticalGuideToPosition:p.x];

				if (dg)
					m_dragGuideRef = dg;
			}
		} else
			isNewGuide = YES;

		if (m_dragGuideRef && [self showsDragInfoWindow]) {
			[[self undoManager] beginUndoGrouping];

			if (!isNewGuide)
				[[self undoManager] setActionName:NSLocalizedString(@"Move Guide", @"undo action for move guide")];
			[[self drawing] invalidateCursors];

			NSPoint gg = p;

			if ([m_dragGuideRef isVerticalGuide])
				gg.x = [m_dragGuideRef guidePosition];
			else
				gg.y = [m_dragGuideRef guidePosition];

			NSPoint gp = [[[self drawing] gridLayer] gridLocationForPoint:gg];

			if ([m_dragGuideRef isVerticalGuide])
				[self showInfoWindowWithString:[NSString stringWithFormat:@"%.2f", gp.x]
									   atPoint:p];
			else
				[self showInfoWindowWithString:[NSString stringWithFormat:@"%.2f", gp.y]
									   atPoint:p];
		}
	}
}

/** @brief Respond to a mouseDragged event

 Continues the drag of a guide, if the layer isn't locked.
 @param event the mouseDragged event
 @param view where it came from
 */
- (void)mouseDragged:(NSEvent*)event inView:(NSView*)view
{
	if (![self locked] && m_dragGuideRef != nil) {
		NSPoint p = [view convertPoint:[event locationInWindow]
							  fromView:nil];
		BOOL shift = (([event modifierFlags] & NSShiftKeyMask) != 0);

		if ([self guidesSnapToGrid] || shift)
			p = [[self drawing] snapToGrid:p
					   ignoringUserSetting:YES];

		// change cursor if crossed from the interior to the margin or vice versa

		NSRect ir = [self guideDeletionRect];
		NSRect gr = [self guideRect:m_dragGuideRef];
		BOOL isIn = NSIntersectsRect(gr, ir);

		if (isIn != sWasInside) {
			sWasInside = isIn;

			if (!isIn)
				[[NSCursor disappearingItemCursor] set];
			else
				[[self cursor] set];
		}

		// get the grid conversion for the guide's location:

		NSPoint gp = [[[self drawing] gridLayer] gridLocationForPoint:p];
		[self repositionGuide:m_dragGuideRef
					  atPoint:p
					   inView:view];

		if ([m_dragGuideRef isVerticalGuide]) {
			if ([self showsDragInfoWindow])
				[self showInfoWindowWithString:[NSString stringWithFormat:@"%.2f", gp.x]
									   atPoint:p];
		} else {
			if ([self showsDragInfoWindow])
				[self showInfoWindowWithString:[NSString stringWithFormat:@"%.2f", gp.y]
									   atPoint:p];
		}
	}
}

/** @brief Respond to a mouseUp event

 Completes a guide drag. If the guide was dragged out of the interior of the drawing, it is deleted.
 @param event the mouseUp event
 @param view where it came from
 */
- (void)mouseUp:(NSEvent*)event inView:(NSView*)view
{
#pragma unused(event)
#pragma unused(view)
	// if the guide has been dragged outside of the interior area of the drawing, delete it.

	if (m_dragGuideRef != nil) {
		[[self drawing] invalidateCursors];

		NSRect ir = [self guideDeletionRect];
		NSRect gr = [self guideRect:m_dragGuideRef];

		if (!NSIntersectsRect(gr, ir)) {
			[self removeGuide:m_dragGuideRef];

			NSPoint animLoc = [[event window] convertBaseToScreen:[event locationInWindow]];
			NSShowAnimationEffect(NSAnimationEffectDisappearingItemDefault, animLoc, NSZeroSize, nil, nil, NULL);
		}

		m_dragGuideRef = nil;
		[self hideInfoWindow];
		[[self undoManager] endUndoGrouping];
	}
}

/** @brief Query whether the layer can be automatically activated by the given event
 @param event the event (typically a mouseDown event)
 @return NO - guide layers never auto-activate by default
 */
- (BOOL)shouldAutoActivateWithEvent:(NSEvent*)event
{
#pragma unused(event)

	return NO;
}

/** @brief Sets the "selection" colour of the layer

 This sets the guide colour, which is the same as the selection colour. This override allows a
 common colour-setting UI to be easily used for all layer types.
 @param aColour the colour to set
 */
- (void)setSelectionColour:(NSColor*)aColour
{
	[self setGuideColour:aColour];
}

/** @brief Returns the curor in use when this layer is active

 Closed hand when dragging a guide, open hand otherwise.
 */
- (NSCursor*)cursor
{
	if ([self locked])
		return [NSCursor arrowCursor];
	else {
		if (m_dragGuideRef) {
			if ([m_dragGuideRef isVerticalGuide])
				return [NSCursor resizeLeftRightCursor];
			else
				return [NSCursor resizeUpDownCursor];
		} else
			return [NSCursor openHandCursor];
	}
}

/** @brief Return a rect where the layer's cursor is shown when the mouse is within it

 Guide layer's cursor rect is the deletion rect.
 @return the cursor rect
 */
- (NSRect)activeCursorRect
{
	return [self guideDeletionRect];
}

/** @brief Notifies the layer that it or a group containing it was added to a drawing.

 Sets the default deletion zone to equal the drawing's interior if it hasn't been set already
 @param aDrawing the drawing that added the layer
 */
- (void)wasAddedToDrawing:(DKDrawing*)aDrawing
{
	if (NSIsEmptyRect(mGuideDeletionZone))
		[self setGuideDeletionRect:[aDrawing interior]];
}

/** @brief Return whether the layer can be deleted

 This setting is intended to be checked by UI-level code to prevent deletion of layers within the UI.
 It does not prevent code from directly removing the layer.
 @return NO - typically guide layers shouldn't be deleted
 */
- (BOOL)layerMayBeDeleted
{
	return NO;
}

/** @brief Allows a contextual menu to be built for the layer or its contents
 @param theEvent the original event (a right-click mouse event)
 @param view the view that received the original event
 @return a menu that will be displayed as a contextual menu
 */
- (NSMenu*)menuForEvent:(NSEvent*)theEvent inView:(NSView*)view
{
	NSMenu* menu = [super menuForEvent:theEvent
								inView:view];

	if (![self locked]) {
		if (menu == nil)
			menu = [[NSMenu alloc] initWithTitle:@"DK_GuideLayerContextualMenu"]; // title never seen

		NSMenuItem* item = [menu addItemWithTitle:NSLocalizedString(@"Clear Guides", nil)
										   action:@selector(clearGuides:)
									keyEquivalent:@""];
		[item setTarget:self];
	}

	return menu;
}

- (BOOL)supportsMetadata
{
	return NO;
}

#pragma mark -
#pragma mark As an NSObject

/** @brief Deallocates the guide layer
 */

/** @brief Initializes the guide layer

 Initially the layer has no guides
 @return the guide layer
 */

/** @brief Initializes the guide
 @return the guide
 */
- (instancetype)init
{
	self = [super init];
	if (self != nil) {
		m_hGuides = [[NSMutableArray alloc] init];
		m_vGuides = [[NSMutableArray alloc] init];
		m_showDragInfo = YES;
		m_snapTolerance = [[self class] defaultSnapTolerance];
		[self setShouldDrawToPrinter:NO];
		[self setSelectionColour:[NSColor orangeColor]];

		if (m_hGuides == nil || m_vGuides == nil) {
			return nil;
		}

		[self setLayerName:NSLocalizedString(@"Guides", @"default name for guide layer")];
	}
	return self;
}

#pragma mark -
#pragma mark As part of NSCoding Protocol
- (void)encodeWithCoder:(NSCoder*)coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	[super encodeWithCoder:coder];

	[coder encodeObject:m_hGuides
				 forKey:@"horizontalguides"];
	[coder encodeObject:m_vGuides
				 forKey:@"verticalguides"];

	[coder encodeBool:m_snapToGrid
			   forKey:@"snapstogrid"];
	[coder encodeBool:m_showDragInfo
			   forKey:@"showdraginfo"];
	[coder encodeDouble:m_snapTolerance
				 forKey:@"snaptolerance"];
	[coder encodeRect:[self guideDeletionRect]
			   forKey:@"DKGuideLayer_deletionRect"];
}

- (instancetype)initWithCoder:(NSCoder*)coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	self = [super initWithCoder:coder];
	if (self != nil) {
		m_hGuides = [[coder decodeObjectForKey:@"horizontalguides"] mutableCopy];
		m_vGuides = [[coder decodeObjectForKey:@"verticalguides"] mutableCopy];

		m_snapToGrid = [coder decodeBoolForKey:@"snapstogrid"];
		m_showDragInfo = [coder decodeBoolForKey:@"showdraginfo"];
		NSAssert(m_dragGuideRef == nil, @"Expected init to zero");
		m_snapTolerance = [coder decodeDoubleForKey:@"snaptolerance"];

		NSRect dr = [coder decodeRectForKey:@"DKGuideLayer_deletionRect"];
		[self setGuideDeletionRect:dr];

		if (m_hGuides == nil || m_vGuides == nil) {
			return nil;
		}
	}
	return self;
}

#pragma mark -
#pragma mark As part of NSMenuValidation Protocol

/** @brief Enables the menu item if targeted at clearGuides

 Layer must be unlocked and have at least one guide to enable the menu.
 @param item a menu item
 @return YES if the item is enabled, NO otherwise
 */
- (BOOL)validateMenuItem:(NSMenuItem*)item
{
	if ([item action] == @selector(clearGuides:))
		return ![self locked] && ([[self verticalGuides] count] > 0 || [[self horizontalGuides] count] > 0);

	return [super validateMenuItem:item];
}

@end

#pragma mark -
@implementation DKGuide
#pragma mark As a DKGuide

@synthesize guidePosition=m_position;
@synthesize isVerticalGuide=m_isVertical;
@synthesize guideColour=m_colour;

/** @brief Draws the guide

 Is called by the guide layer only if the guide needs to be drawn
 @param rect the update rect 
 @param lw the line width to draw
 */
- (void)drawInRect:(NSRect)rect lineWidth:(CGFloat)lw
{
	NSPoint a, b;

	if ([self isVerticalGuide]) {
		a.y = NSMinY(rect);
		b.y = NSMaxY(rect);
		a.x = b.x = [self guidePosition];
	} else {
		a.x = NSMinX(rect);
		b.x = NSMaxX(rect);
		a.y = b.y = [self guidePosition];
	}

	[[self guideColour] set];
	[NSBezierPath setDefaultLineWidth:lw];
	[NSBezierPath strokeLineFromPoint:a
							  toPoint:b];
}

#pragma mark -
#pragma mark As an NSObject

- (instancetype)init
{
	if ((self = [super init]) != nil) {
		m_position = 0.0;
		m_isVertical = NO;
		[self setGuideColour:[NSColor cyanColor]];
		if (m_colour == nil) {
			return nil;
		}
	}
	return self;
}

#pragma mark -
#pragma mark As part of NSCoding Protocol
- (void)encodeWithCoder:(NSCoder*)coder
{
	[coder encodeDouble:[self guidePosition]
				 forKey:@"position"];
	[coder encodeBool:[self isVerticalGuide]
			   forKey:@"vertical"];
	[coder encodeObject:[self guideColour]
				 forKey:@"guide_colour"];
}

- (instancetype)initWithCoder:(NSCoder*)coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	if ((self = [super init]) != nil) {
		m_position = [coder decodeDoubleForKey:@"position"];
		m_isVertical = [coder decodeBoolForKey:@"vertical"];

		// guard against older files that didn't save this ivar

		NSColor* clr = [coder decodeObjectForKey:@"guide_colour"];

		if (clr)
			[self setGuideColour:clr];
	}
	return self;
}


@end
