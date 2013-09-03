///**********************************************************************************************************************************
///  DKGuideLayer.m
///  DrawKit ¬¨¬©2005-2008 Apptree.net
///
///  Created by graham on 28/08/2006.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
///
///**********************************************************************************************************************************

#import "DKGuideLayer.h"
#import "DKDrawingView.h"
#import "DKDrawing.h"
#import "DKGridLayer.h"
#import "GCInfoFloater.h"
#import "NSColor+DKAdditions.h"
#import "DKUndoManager.h"


#define DK_DRAW_GUIDES_IN_CLIP_VIEW		0

@interface DKGuideLayer (Private)

- (void)		repositionGuide:(DKGuide*) guide atPoint:(NSPoint) p inView:(NSView*) aView;
- (NSRect)		guideRectOfGuide:(DKGuide*) guide forEnclosingClipViewOfView:(NSView*) aView;

@end

#pragma mark Static Vars
static CGFloat	sSnapTolerance = 6.0;

// tracks the cursor position whlie dragging modally

static BOOL		sWasInside = NO;

#pragma mark -
@implementation DKGuideLayer
#pragma mark As a DKGuideLayer

///*********************************************************************************************************************
///
/// method:			setSnapTolerance:
/// scope:			public class method
/// overrides:
/// description:	sets the distance a point needs to be before it is snapped to a guide
/// 
/// parameters:		<tol> the distance in points
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

+ (void)				setDefaultSnapTolerance:(CGFloat) tol
{
	sSnapTolerance = tol;
}


///*********************************************************************************************************************
///
/// method:			snapTolerance:
/// scope:			public class method
/// overrides:
/// description:	returns the distance a point needs to be before it is snapped to a guide
/// 
/// parameters:		none
/// result:			the distance in points
///
/// notes:			
///
///********************************************************************************************************************

+ (CGFloat)				defaultSnapTolerance
{
	return sSnapTolerance;
}


#pragma mark -


///*********************************************************************************************************************
///
/// method:			addGuide:
/// scope:			public instance method
/// overrides:
/// description:	adds a guide to the layer
/// 
/// parameters:		<guide> an existing guide object
/// result:			none
///
/// notes:			sets the guide's colour to the layer's guide colour initially - after adding the guide colour can
///					be set individually if desired.
///
///********************************************************************************************************************

- (void)				addGuide:(DKGuide*) guide
{
	NSAssert( guide != nil, @"attempt to add a nil guide to a guide layer");
	
	[[[self undoManager] prepareWithInvocationTarget:self] removeGuide:guide];
	
	if([guide isVerticalGuide])
		[m_vGuides addObject:guide];
	else
		[m_hGuides addObject:guide];
	
	[guide setGuideColour:[self guideColour]];
	[self refreshGuide:guide];
	
	if(! ([[self undoManager] isUndoing] || [[self undoManager] isRedoing]))
		[[self undoManager] setActionName:NSLocalizedString(@"Add Guide", @"undo action for Add Guide")];
}


///*********************************************************************************************************************
///
/// method:			removeGuide:
/// scope:			public instance method
/// overrides:
/// description:	removes a guide from the layer
/// 
/// parameters:		<guide> an existing guide object
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				removeGuide:(DKGuide*) guide
{
	NSAssert( guide != nil, @"attempt to remove a nil guide from a guide layer");
	
	[[[self undoManager] prepareWithInvocationTarget:self] addGuide:guide];

	[self refreshGuide:guide];
	
	if([guide isVerticalGuide])
		[m_vGuides removeObject:guide];
	else
		[m_hGuides removeObject:guide];

	if(! ([[self undoManager] isUndoing] || [[self undoManager] isRedoing]))
		[[self undoManager] setActionName:NSLocalizedString(@"Delete Guide", @"undo action for Remove Guide")];
}


///*********************************************************************************************************************
///
/// method:			removeAllGuides
/// scope:			public instance method
/// overrides:
/// description:	removes all guides permanently from the layer
/// 
/// parameters:		none
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				removeAllGuides
{
	if( ![self locked])
	{
		[[[self undoManager] prepareWithInvocationTarget:self] setGuides:[self guides]];
		
		[m_vGuides removeAllObjects];
		[m_hGuides removeAllObjects];
		[self setNeedsDisplay:YES];
	}
}


#pragma mark -


///*********************************************************************************************************************
///
/// method:			nearestVerticalGuideToPosition
/// scope:			public instance method
/// overrides:
/// description:	locates the nearest guide to the given position, if position is within the snap tolerance
/// 
/// parameters:		<pos> a verical coordinate value, in points
/// result:			the nearest guide to the given point that lies within the snap tolerance, or nil
///
/// notes:			
///
///********************************************************************************************************************

- (DKGuide*)			nearestVerticalGuideToPosition:(CGFloat) pos
{
	NSEnumerator*	iter = [[self verticalGuides] objectEnumerator];
	DKGuide*		guide;
	DKGuide*		nearestGuide = nil;
	CGFloat			nearestDistance = 10000, distance;
	
	while(( guide = [iter nextObject]))
	{
		distance = _CGFloatFabs(pos - [guide guidePosition]);
		
		if( distance < [self snapTolerance] && distance < nearestDistance )
		{
			nearestDistance = distance;
			nearestGuide = guide;
		}
	}
	
	return nearestGuide;
}


///*********************************************************************************************************************
///
/// method:			nearestHorizontalGuideToPosition
/// scope:			public instance method
/// overrides:
/// description:	locates the nearest guide to the given position, if position is within the snap tolerance
/// 
/// parameters:		<pos> a horizontal coordinate value, in points
/// result:			the nearest guide to the given point that lies within the snap tolerance, or nil
///
/// notes:			
///
///********************************************************************************************************************

- (DKGuide*)			nearestHorizontalGuideToPosition:(CGFloat) pos
{
	NSEnumerator*	iter = [[self horizontalGuides] objectEnumerator];
	DKGuide*		guide;
	DKGuide*		nearestGuide = nil;
	CGFloat			nearestDistance = 10000, distance;
	
	while(( guide = [iter nextObject]))
	{
		distance = _CGFloatFabs(pos - [guide guidePosition]);
		
		if( distance < [self snapTolerance] && distance < nearestDistance )
		{
			nearestDistance = distance;
			nearestGuide = guide;
		}
	}
	
	return nearestGuide;
}


///*********************************************************************************************************************
///
/// method:			verticalGuides
/// scope:			public instance method
/// overrides:
/// description:	returns the list of vertical guides
/// 
/// parameters:		none
/// result:			an array of DKGuide objects
///
/// notes:			the guides returns are not in any particular order
///
///********************************************************************************************************************

- (NSArray*)			verticalGuides
{
	return m_vGuides;
}


///*********************************************************************************************************************
///
/// method:			horizontalGuides
/// scope:			public instance method
/// overrides:
/// description:	returns the list of horizontal guides
/// 
/// parameters:		none
/// result:			an array of DKGuide objects
///
/// notes:			the guides returns are not in any particular order
///
///********************************************************************************************************************

- (NSArray*)			horizontalGuides
{
	return m_hGuides;
}


#pragma mark -
///*********************************************************************************************************************
///
/// method:			setGuidesSnapToGrid:
/// scope:			public instance method
/// overrides:
/// description:	set whether guids should snap to the grid by default or not
/// 
/// parameters:		<gridsnap> YES to always snap guides to the grid, NO otherwise
/// result:			none
///
/// notes:			the default is NO
///
///********************************************************************************************************************

- (void)				setGuidesSnapToGrid:(BOOL) gridsnap
{
	m_snapToGrid = gridsnap;
}


///*********************************************************************************************************************
///
/// method:			guidesSnapToGrid
/// scope:			public instance method
/// overrides:
/// description:	whether guids should snap to the grid by default or not
/// 
/// parameters:		none 
/// result:			YES to always snap guides to the grid, NO otherwise
///
/// notes:			the default is NO
///
///********************************************************************************************************************

- (BOOL)				guidesSnapToGrid
{
	return m_snapToGrid;
}


#pragma mark -
///*********************************************************************************************************************
///
/// method:			snapPointToGuide:
/// scope:			public instance method
/// overrides:
/// description:	snap a given point to any nearest guides within the snap tolerance
/// 
/// parameters:		<p> a point in local drawing coordinates 
/// result:			a point, either the same point passed in, or a modified one that has been snapped to the guides
///
/// notes:			x and y coordinates of the point are of course, individually snapped, so only one coordinate
///					might be modified, as well as none or both.
///
///********************************************************************************************************************

- (NSPoint)				snapPointToGuide:(NSPoint) p
{
	// if the point <p> is within the snap tolerance of any guide, the returned point is snapped to that guide. Otherwise the
	// returned point is the same as p.
	
	DKGuide*	vg;
	DKGuide*	hg;
	NSPoint		ps;
	
	vg = [self nearestVerticalGuideToPosition:p.x];
	hg = [self nearestHorizontalGuideToPosition:p.y];
	
	if ( vg )
		ps.x = [vg guidePosition];
	else
		ps.x = p.x;
		
	if ( hg )
		ps.y = [hg guidePosition];
	else
		ps.y = p.y;
		
	return ps;
}


///*********************************************************************************************************************
///
/// method:			snapRectToGuide:
/// scope:			public instance method
/// overrides:
/// description:	snaps any corner of the given rect to any nearest guides within the snap tolerance
/// 
/// parameters:		<r> a rect in local drawing coordinates 
/// result:			a rect, either the same rect passed in, or a modified one that has been snapped to the guides
///
/// notes:			the rect size is never changed by this method, but its origin may be. Does not snap the centres.
///
///********************************************************************************************************************

- (NSRect)				snapRectToGuide:(NSRect) r
{
	return [self snapRectToGuide:r includingCentres:NO];
}


///*********************************************************************************************************************
///
/// method:			snapRectToGuide:includingCentres:
/// scope:			public instance method
/// overrides:
/// description:	snaps any corner or centre point of the given rect to any nearest guides within the snap tolerance
/// 
/// parameters:		<r> a rect in local drawing coordinates 
///					<centre> YES to also snap mid points of all sides, NO to just snap the corners
/// result:			a rect, either the same rect passed in, or a modified one that has been snapped to the guides
///
/// notes:			the rect size is never changed by this method, but its origin may be.
///
///********************************************************************************************************************

- (NSRect)				snapRectToGuide:(NSRect) r includingCentres:(BOOL) centre
{
	NSRect		sr;
	DKGuide*	guide;
	
	sr = r;
	
	// look for vertical snaps first
	
	guide = [self nearestVerticalGuideToPosition:NSMinX( r )];
	if ( guide )
		sr.origin.x = [guide guidePosition];
	else
	{
		guide = [self nearestVerticalGuideToPosition:NSMaxX( r )];
		if ( guide )
			sr.origin.x = [guide guidePosition] - sr.size.width;
		else if ( centre )
		{
			guide = [self nearestVerticalGuideToPosition:NSMidX( r )];
			if ( guide )
				sr.origin.x = [guide guidePosition] - ( sr.size.width / 2.0 );
		}
	}
	
	// horizontal snaps
	
	guide = [self nearestHorizontalGuideToPosition:NSMinY( r )];
	if ( guide )
		sr.origin.y = [guide guidePosition];
	else
	{
		guide = [self nearestHorizontalGuideToPosition:NSMaxY( r )];
		if ( guide )
			sr.origin.y = [guide guidePosition] - sr.size.height;
		else if ( centre )
		{
			guide = [self nearestHorizontalGuideToPosition:NSMidY( r )];
			if ( guide )
				sr.origin.y = [guide guidePosition] - ( sr.size.height / 2.0 );
		}
	}
	
	return sr;
}


#pragma mark -
///*********************************************************************************************************************
///
/// method:			snapPointsToGuide:
/// scope:			public instance method
/// overrides:
/// description:	snaps any of a list of points to any nearest guides within the snap tolerance
/// 
/// parameters:		<arrayOfPoints> a list of NSValue object containing pointValues 
/// result:			a size, being the offset between whichever point was snapped and its snapped position
///
/// notes:			this is intended as one step in the snapping of a complex object to the guides, where points are
///					arbitrarily distributed (e.g. not in a rect). Any of the points can snap to the guide - the first
///					point in the list that actually snaps is used. The return value is intended to be used to offset
///					a mouse point or similar so that the whole object is shifted by that amount to effect the snap.
///					Note that h and v offsets are independent, and may not refer to the same actual input point.
///
///********************************************************************************************************************

- (NSSize)				snapPointsToGuide:(NSArray*) arrayOfPoints
{
	return [self snapPointsToGuide:arrayOfPoints verticalGuide:NULL horizontalGuide:NULL];
}


///*********************************************************************************************************************
///
/// method:			snapPointsToGuide:verticalGuide:horizontalGuide:
/// scope:			public instance method
/// overrides:
/// description:	snaps any of a list of points to any nearest guides within the snap tolerance
/// 
/// parameters:		<arrayOfPoints> a list of NSValue object containing pointValues 
///					<gv> if not NULL, receives the actual vertical guide snapped to
///					<gh> if not NULL, receives the actual horizontal guide snapped to
/// result:			a size, being the offset between whichever point was snapped and its snapped position
///
/// notes:			this is intended as one step in the snapping of a complex object to the guides, where points are
///					arbitrarily distributed (e.g. not in a rect). Any of the points can snap to the guide - the first
///					point in the list that actually snaps is used. The return value is intended to be used to offset
///					a mouse point or similar so that the whole object is shifted by that amount to effect the snap.
///					Note that h and v offsets are independent, and may not refer to the same actual input point.
///
///********************************************************************************************************************

- (NSSize)				snapPointsToGuide:(NSArray*) arrayOfPoints verticalGuide:(DKGuide**) gv horizontalGuide:(DKGuide**) gh
{
	NSEnumerator*	iter = [arrayOfPoints objectEnumerator];
	NSValue*		v;
	NSPoint			p;
	NSSize			result = NSZeroSize;
	DKGuide*		guide;
	
	while(( v = [iter nextObject]))
	{
		p = [v pointValue];
		
		if ( result.height == 0 )
		{
			guide = [self nearestHorizontalGuideToPosition:p.y];
		
			if ( guide )
			{
				result.height = [guide guidePosition] - p.y;
				
				if ( gh )
					*gh = guide;
			}
		}
		
		if ( result.width == 0 )
		{
			guide = [self nearestVerticalGuideToPosition:p.x];
		
			if ( guide )
			{
				result.width = [guide guidePosition] - p.x;
				
				if ( gv )
					*gv = guide;
			}
		}
	
		if ( result.width != 0 && result.height != 0 )
			break;
	}
	
	return result;
}


#pragma mark -
///*********************************************************************************************************************
///
/// method:			setSnapTolerance:
/// scope:			public instance method
/// overrides:
/// description:	sets the distance a point needs to be before it is snapped to a guide
/// 
/// parameters:		<tol> the distance in points
/// result:			none
///
/// notes:			the default value is determind by the class method of the same name
///
///********************************************************************************************************************

- (void)				setSnapTolerance:(CGFloat) tol
{
	m_snapTolerance = tol;
}


///*********************************************************************************************************************
///
/// method:			snapTolerance
/// scope:			public instance method
/// overrides:
/// description:	resturns the distance a point needs to be before it is snapped to a guide
/// 
/// parameters:		none
/// result:			the distance in points
///
/// notes:			the default value is determind by the class method of the same name
///
///********************************************************************************************************************

- (CGFloat)				snapTolerance
{
	return m_snapTolerance;
}


#pragma mark -

///*********************************************************************************************************************
///
/// method:			refreshGuide:
/// scope:			public instance method
/// overrides:
/// description:	marks a partiuclar guide as needing to be readrawn
/// 
/// parameters:		<guide> the guide to update
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				refreshGuide:(DKGuide*) guide
{
	NSAssert( guide != nil, @"guide was nil in refreshGuide");

	[self setNeedsDisplayInRect:[self guideRect:guide]];
}


///*********************************************************************************************************************
///
/// method:			guideRect:
/// scope:			public instance method
/// overrides:
/// description:	returns the rect occupied by a given guide
/// 
/// parameters:		<guide> the guide whose rect we are interested in
/// result:			a rect, in drawing coordinates
///
/// notes:			this allows a small amount either side of the guide, and runs the full dimension of the drawing
///					in the direction of the guide.
///
///********************************************************************************************************************

- (NSRect)				guideRect:(DKGuide*) guide
{
	NSAssert( guide != nil, @"guide was nil in guideRect:");
	
	NSRect	r;
	NSSize	ds = [[self drawing] drawingSize];
	
	if ([guide isVerticalGuide])
	{
		r.origin.x = [guide guidePosition] - 1.0;
		r.origin.y = 0.0;
		r.size.width = 2.0;
		r.size.height = ds.height;
	}
	else
	{
		r.origin.y = [guide guidePosition] - 1.0;
		r.origin.x = 0.0;
		r.size.height = 2.0;
		r.size.width = ds.width;
	}
	
	return r;
}


///*********************************************************************************************************************
///
/// method:			createVerticalGuideAndBeginDraggingFromPoint:
/// scope:			public instance method
/// overrides:
/// description:	creates a new vertical guide at the point p, adds it to the layer and returns it
/// 
/// parameters:		<p> a point local to the drawing
/// result:			the guide created, or nil
///
/// notes:			this is a convenient way to add a guide interactively, for example when dragging one "off" a
///					ruler. See DKViewController for an example client of this method. If the layer is locked this
///					does nothing and returns nil.
///
///********************************************************************************************************************

- (DKGuide*)			createVerticalGuideAndBeginDraggingFromPoint:(NSPoint) p
{
	DKGuide* guide = nil;
	
	if( ![self locked])
	{
		guide = [[DKGuide alloc] init];
		
		[guide setGuidePosition:p.x];
		[guide setIsVerticalGuide:YES];
		[self addGuide:guide];
		[guide release];
		
		// the layer is made active & visible so that the user gets the layer's cursor feedback and can reposition the guide if
		// it ends up not quite where they intended.
		
		[self setVisible:YES];
		[[self drawing] setActiveLayer:self];
		
		m_dragGuideRef = guide;
		sWasInside = NO;
	}
	
	return guide;
}


///*********************************************************************************************************************
///
/// method:			createHorizontalGuideAndBeginDraggingFromPoint:
/// scope:			public instance method
/// overrides:
/// description:	creates a new horizontal guide at the point p, adds it to the layer and returns it
/// 
/// parameters:		<p> a point local to the drawing
/// result:			the guide created, or nil
///
/// notes:			this is a convenient way to add a guide interactively, for example when dragging one "off" a
///					ruler. See DKViewController for an example client of this method. If the layer is locked this
///					does nothing and returns nil.
///
///********************************************************************************************************************

- (DKGuide*)			createHorizontalGuideAndBeginDraggingFromPoint:(NSPoint) p
{
	DKGuide* guide = nil;
	
	if ( ![self locked])
	{
		guide = [[DKGuide alloc] init];
		
		[guide setGuidePosition:p.y];
		[guide setIsVerticalGuide:NO];
		[self addGuide:guide];
		[guide release];
		
		// the layer is made active and visible so that the user gets the layer's cursor feedback and can reposition the guide if
		// it ends up not quite where they intended.
		
		[self setVisible:YES];
		[[self drawing] setActiveLayer:self];

		m_dragGuideRef = guide;
		sWasInside = NO;
	}
	
	return guide;
}



///*********************************************************************************************************************
///
/// method:			guides
/// scope:			public instance method
/// overrides:
/// description:	get all current guides
/// 
/// parameters:		none
/// result:			an array of guide objects
///
/// notes:			
///
///********************************************************************************************************************

- (NSArray*)			guides
{
	NSMutableArray* ga = [[self horizontalGuides] mutableCopy];
	[ga addObjectsFromArray:[self verticalGuides]];
	return [ga autorelease];
}


///*********************************************************************************************************************
///
/// method:			setGuides:
/// scope:			public instance method
/// overrides:
/// description:	adds a set of guides to th elayer
/// 
/// parameters:		<guides> an array of guide objects
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				setGuides:(NSArray*) guides
{
	NSAssert( guides != nil, @"can't set guides from nil array");
	
	NSEnumerator*	iter = [guides objectEnumerator];
	DKGuide*		guide;
	
	while(( guide = [iter nextObject]))
	{
		if([guide isKindOfClass:[DKGuide class]])
			[self addGuide:guide];
	}
}


///*********************************************************************************************************************
///
/// method:			repositionGuide:atPoint:
/// scope:			private instance method
/// overrides:
/// description:	moves a given guide to a new point
/// 
/// parameters:		<guide> the guide to move
///					<p> where to move it to
///					<aView> which view it's drawn in
/// result:			none
///
/// notes:			called by mouseDragged, allows undo of a move.
///
///********************************************************************************************************************

- (void)		repositionGuide:(DKGuide*) guide atPoint:(NSPoint) p inView:(NSView*) aView
{
	NSPoint oldPoint = p;
	CGFloat	newPos;
	
	if([guide isVerticalGuide])
	{
		oldPoint.x = [guide guidePosition];
		newPos = p.x;
	}
	else
	{
		oldPoint.y = [guide guidePosition];
		newPos = p.y;
	}
	
	if( !NSEqualPoints( oldPoint, p ))
	{
		[[[self undoManager] prepareWithInvocationTarget:self] repositionGuide:guide atPoint:oldPoint inView:aView];
		
#if DK_DRAW_GUIDES_IN_CLIP_VIEW
		NSRect gr = [self guideRectOfGuide:guide forEnclosingClipViewOfView:aView];
		NSClipView* clipView = [[aView enclosingScrollView] contentView];
		
		if( clipView )
			[clipView setNeedsDisplayInRect:gr];
		else
#endif
			[self refreshGuide:guide];
		[guide setGuidePosition:newPos];
#if DK_DRAW_GUIDES_IN_CLIP_VIEW
		gr = [self guideRectOfGuide:guide forEnclosingClipViewOfView:aView];
		if( clipView )
			[clipView setNeedsDisplayInRect:gr];
		else
#endif
			[self refreshGuide:guide];
	}
}


- (NSRect)		guideRectOfGuide:(DKGuide*) guide forEnclosingClipViewOfView:(NSView*) aView
{
	NSClipView* clipView = [[aView enclosingScrollView] contentView];
	
	if( clipView )
	{
		NSRect br = [clipView bounds];
		NSRect gr = [self guideRect:guide];
		NSRect rr;
		
		NSPoint topLeft = [clipView convertPoint:gr.origin fromView:aView];
		
		if([guide isVerticalGuide])
		{
			rr.origin.x = topLeft.x;
			rr.origin.y = NSMinY( br );
			rr.size.height = NSHeight( br );
			rr.size.width = NSWidth( gr );
		}
		else
		{
			rr.origin.x = NSMinX( br );
			rr.origin.y = topLeft.y;
			rr.size.width = NSWidth( br );
			rr.size.height = NSHeight( gr );
		}
		
		return rr;
	}
	else
		return NSZeroRect;	// no clip view
}


#pragma mark -
///*********************************************************************************************************************
///
/// method:			setShowsDragInfoWindow:
/// scope:			public instance method
/// overrides:
/// description:	set whether the info window should be displayed when dragging a guide
/// 
/// parameters:		<showsIt> YES to display the window, NO otherwise
/// result:			none
///
/// notes:			default is YES, display the window
///
///********************************************************************************************************************

- (void)				setShowsDragInfoWindow:(BOOL) showsIt
{
	m_showDragInfo = showsIt;
}


///*********************************************************************************************************************
///
/// method:			showsDragInfoWindow
/// scope:			public instance method
/// overrides:
/// description:	return whether the info window should be displayed when dragging a guide
/// 
/// parameters:		none
/// result:			YES to display the window, NO otherwise
///
/// notes:			default is YES, display the window
///
///********************************************************************************************************************

- (BOOL)				showsDragInfoWindow
{
	return m_showDragInfo;
}


///*********************************************************************************************************************
///
/// method:			setGuideDeletionRect:
/// scope:			public instance method
/// overrides:
/// description:	sets a rect for which guides will be deleted if they are dragged outside of it
/// 
/// parameters:		<rect> the rect
/// result:			none
///
/// notes:			default is the same as the drawing's interior
///
///********************************************************************************************************************

- (void)				setGuideDeletionRect:(NSRect) rect
{
	mGuideDeletionZone = rect;
}


///*********************************************************************************************************************
///
/// method:			guideDeletionRect
/// scope:			public instance method
/// overrides:
/// description:	the rect for which guides will be deleted if they are dragged outside of it
/// 
/// parameters:		none
/// result:			the rect
///
/// notes:			default is the same as the drawing's interior
///
///********************************************************************************************************************

- (NSRect)				guideDeletionRect
{
	return mGuideDeletionZone;
}


- (void)				setGuidesDrawnInEnclosingScrollview:(BOOL) drawOutside
{
	mDrawGuidesInClipView = drawOutside;
	[self setNeedsDisplay:YES];
}


- (BOOL)				guidesDrawnInEnclosingScrollview
{
	return mDrawGuidesInClipView;
}


#pragma mark -
///*********************************************************************************************************************
///
/// method:			clearGuides:
/// scope:			public action method
/// overrides:
/// description:	high level action to remove all guides from the layer
/// 
/// parameters:		<sender> the action's sender
/// result:			none
///
/// notes:			can be hooked directly to a menu item for clearing the guides - will be available when the guide
///					layer is active. Does nothing if the layer is locked.
///
///********************************************************************************************************************

- (IBAction)			clearGuides:(id) sender
{
	#pragma unused(sender)
	
	if ( ![self locked])
	{
		[self removeAllGuides];
		[[self undoManager] setActionName:NSLocalizedString(@"Clear Guides", @"undo string for clear guides")];
	}
}


#pragma mark -

///*********************************************************************************************************************
///
/// method:			setGuideColour:
/// scope:			public instance method
/// overrides:
/// description:	set the colour of all guides in this layer to a given colour
/// 
/// parameters:		<colour> the colour to set
/// result:			none
///
/// notes:			the guide colour is actually synonymous with the "selection" colour inherited from DKLayer, but
///					also each guide is able to have its own colour. This sets the colour for each guide to be the same
///					so you may prefer to obtain a particular guide and set it individually.
///
///********************************************************************************************************************

- (void)				setGuideColour:(NSColor*) colour
{
	if ( ![self locked] && colour != [self guideColour])
	{
		[[[self undoManager] prepareWithInvocationTarget:self] setGuideColour:[self guideColour]];
		
		[[self verticalGuides] makeObjectsPerformSelector:@selector(setGuideColour:) withObject:colour];
		[[self horizontalGuides] makeObjectsPerformSelector:@selector(setGuideColour:) withObject:colour];
		[super setSelectionColour:colour];

		if(! ([[self undoManager] isUndoing] || [[self undoManager] isRedoing]))
			[[self undoManager] setActionName:NSLocalizedString(@"Change Guide Colour", @"undo action for Guide colour")];
	}
}


///*********************************************************************************************************************
///
/// method:			guideColour
/// scope:			public instance method
/// overrides:
/// description:	return the layer's guide colour
/// 
/// parameters:		none
/// result:			a colour
///
/// notes:			the guide colour is actually synonymous with the "selection" colour inherited from DKLayer, but
///					also each guide is able to have its own colour. This returns the selection colour, but if guides
///					have their own colours this says nothing about them.
///
///********************************************************************************************************************

- (NSColor*)			guideColour
{
	return [self selectionColour];
}


#pragma mark -
#pragma mark As a DKLayer
///*********************************************************************************************************************
///
/// method:			drawRect:inView:
/// scope:			public instance method
/// overrides:		DKLayer
/// description:	draws the guide layer
/// 
/// parameters:		<rect> the overall rect needing update
///					<aView> the view that's doing it
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				drawRect:(NSRect) rect inView:(DKDrawingView*) aView
{
	NSEnumerator*	iter; 
	DKGuide*		guide;
	CGFloat			savedLineWidth, lineWidth = ([aView scale] < 1.0)? 1.0 : (2.0 / [aView scale]);
	
	savedLineWidth = [NSBezierPath defaultLineWidth];
	iter = [[self guides] objectEnumerator];

#if DK_DRAW_GUIDES_IN_CLIP_VIEW
	NSClipView* clipView = [[aView enclosingScrollView] contentView];

	if( clipView && aView )
	{
		[NSBezierPath setDefaultLineWidth:1.0];
		
		SAVE_GRAPHICS_CONTEXT
		
		[clipView lockFocus];
		
		NSRect br = [clipView bounds];
		[NSBezierPath clipRect:br];

		while(( guide = [iter nextObject]))
		{
			NSRect gr = [self guideRectOfGuide:guide forEnclosingClipViewOfView:aView];
			
			if([clipView needsToDrawRect:gr])
			{
				float	pos = [guide guidePosition];
				BOOL	vert = [guide isVerticalGuide];
				NSPoint a, b;
				
				if( vert )
					a.x = b.x = pos;
				else
					a.y = b.y = pos;
				
				a = [clipView convertPoint:a fromView:aView];
				b = [clipView convertPoint:b fromView:aView];
				
				if( vert )
				{
					a.y = NSMinX(br);
					b.y = NSMaxY(br);
				}
				else
				{
					a.x = NSMinX(br);
					b.x = NSMaxX(br);
				}
				
				[[guide guideColour] set];
				[NSBezierPath strokeLineFromPoint:a toPoint:b];
			}
		}
		
		[clipView unlockFocus];
		
		RESTORE_GRAPHICS_CONTEXT
	}
	else
#endif
	{
		[NSBezierPath setDefaultLineWidth:lineWidth];
		
		while(( guide = [iter nextObject]))
		{
			if ( aView == nil || [aView needsToDrawRect:[self guideRect:guide]])
				[guide drawInRect:rect lineWidth:lineWidth];
		}
	}
	
	[NSBezierPath setDefaultLineWidth:savedLineWidth];
}


///*********************************************************************************************************************
///
/// method:			hitLayer:
/// scope:			public instance method
/// overrides:		DKLayer
/// description:	test whether the point "hits" the layer
/// 
/// parameters:		<p> a point in local (drawing) coordinates
/// result:			YES if any guide was hit, NO otherwise
///
/// notes:			to be considered a "hit", the point needs to be within the snap tolerance of a guide.
///
///********************************************************************************************************************

- (BOOL)				hitLayer:(NSPoint) p
{
	DKGuide* dg;
	
	dg = [self nearestHorizontalGuideToPosition:p.y];
	
	if ( dg )
		return YES;
	else
	{
		dg = [self nearestVerticalGuideToPosition:p.x];
	
		if ( dg )
			return YES;
	}
	
	return NO;
}


///*********************************************************************************************************************
///
/// method:			mouseDown:inView:
/// scope:			public instance method
/// overrides:		DKLayer
/// description:	respond to a mouseDown event
/// 
/// parameters:		<event> the mouseDown event
///					<view> where it came from
/// result:			none
///
/// notes:			begins the drag of a guide, if the layer isn't locked. Determines which guide will be dragged
///					and sets m_dragGuideRef to it.
///
///********************************************************************************************************************

- (void)				mouseDown:(NSEvent*) event inView:(NSView*) view
{
	if( ![self locked])
	{
		NSPoint p = [view convertPoint:[event locationInWindow] fromView:nil];
		BOOL isNewGuide = NO;
		
		if( m_dragGuideRef == nil )
		{
			DKGuide* dg = [self nearestHorizontalGuideToPosition:p.y];
			if ( dg )
				m_dragGuideRef = dg;
			else
			{
				dg = [self nearestVerticalGuideToPosition:p.x];
				
				if ( dg )
					m_dragGuideRef = dg;
			}
		}
		else
			isNewGuide = YES;
		
		if ( m_dragGuideRef && [self showsDragInfoWindow])
		{
			[[self undoManager] beginUndoGrouping];
			
			if( !isNewGuide )
				[[self undoManager] setActionName:NSLocalizedString(@"Move Guide", @"undo action for move guide")];
			[[self drawing] invalidateCursors];
			
			NSPoint	gg = p;
			
			if ([m_dragGuideRef isVerticalGuide])
				gg.x = [m_dragGuideRef guidePosition];
			else
				gg.y = [m_dragGuideRef guidePosition];
			
			NSPoint gp = [[[self drawing] gridLayer] gridLocationForPoint:gg];

			if ([m_dragGuideRef isVerticalGuide])
				[self showInfoWindowWithString:[NSString stringWithFormat:@"%.2f", gp.x] atPoint:p];
			else
				[self showInfoWindowWithString:[NSString stringWithFormat:@"%.2f", gp.y] atPoint:p];
		}
	}
}


///*********************************************************************************************************************
///
/// method:			mouseDragged:inView:
/// scope:			public instance method
/// overrides:		DKLayer
/// description:	respond to a mouseDragged event
/// 
/// parameters:		<event> the mouseDragged event
///					<view> where it came from
/// result:			none
///
/// notes:			continues the drag of a guide, if the layer isn't locked.
///
///********************************************************************************************************************

- (void)				mouseDragged:(NSEvent*) event inView:(NSView*) view
{
	if ( ![self locked] && m_dragGuideRef != nil )
	{
		NSPoint p = [view convertPoint:[event locationInWindow] fromView:nil];
		BOOL	shift = (([event modifierFlags] & NSShiftKeyMask) != 0);
				
		if ([self guidesSnapToGrid] || shift)
			p = [[self drawing] snapToGrid:p ignoringUserSetting:YES];
		
		// change cursor if crossed from the interior to the margin or vice versa
		
		NSRect	ir = [self guideDeletionRect];
		NSRect	gr = [self guideRect:m_dragGuideRef];
		BOOL	isIn = NSIntersectsRect( gr, ir );
		
		if( isIn != sWasInside )
		{
			sWasInside = isIn;
			
			if( !isIn )
				[[NSCursor disappearingItemCursor] set];
			else
				[[self cursor] set];
		}
			
		// get the grid conversion for the guide's location:
		
		NSPoint gp = [[[self drawing] gridLayer] gridLocationForPoint:p];
		[self repositionGuide:m_dragGuideRef atPoint:p inView:view];
		
		if ([m_dragGuideRef isVerticalGuide])
		{
			if([self showsDragInfoWindow])
				[self showInfoWindowWithString:[NSString stringWithFormat:@"%.2f", gp.x] atPoint:p];		}
		else
		{
			if([self showsDragInfoWindow])
				[self showInfoWindowWithString:[NSString stringWithFormat:@"%.2f", gp.y] atPoint:p];
		}
	}
}


///*********************************************************************************************************************
///
/// method:			mouseUp:inView:
/// scope:			public instance method
/// overrides:		DKLayer
/// description:	respond to a mouseUp event
/// 
/// parameters:		<event> the mouseUp event
///					<view> where it came from
/// result:			none
///
/// notes:			completes a guide drag. If the guide was dragged out of the interior of the drawing, it is deleted.
///
///********************************************************************************************************************

- (void)				mouseUp:(NSEvent*) event inView:(NSView*) view
{
	#pragma unused(event)
	#pragma unused(view)
	// if the guide has been dragged outside of the interior area of the drawing, delete it.
	
	if( m_dragGuideRef != nil )
	{
		[[self drawing] invalidateCursors];
		
		NSRect	ir = [self guideDeletionRect];
		NSRect	gr = [self guideRect:m_dragGuideRef];
		
		if ( ! NSIntersectsRect( gr, ir ))
		{
			[self removeGuide:m_dragGuideRef];
			
			NSPoint animLoc = [[event window] convertBaseToScreen:[event locationInWindow]];
			NSShowAnimationEffect(NSAnimationEffectDisappearingItemDefault, animLoc, NSZeroSize, nil, nil, NULL );
		}
		
		m_dragGuideRef = nil;
		[self hideInfoWindow];
		[[self undoManager] endUndoGrouping];
	}
}


///*********************************************************************************************************************
///
/// method:			shouldAutoActivateWithEvent:
/// scope:			public instance method
/// overrides:		DKLayer
/// description:	query whether the layer can be automatically activated by the given event
/// 
/// parameters:		<event> the event (typically a mouseDown event)
/// result:			NO - guide layers never auto-activate by default
///
/// notes:			
///
///********************************************************************************************************************

- (BOOL)				shouldAutoActivateWithEvent:(NSEvent*) event
{
	#pragma unused(event)
	
	return NO;
}


///*********************************************************************************************************************
///
/// method:			setSelectionColour:
/// scope:			public instance method
/// overrides:		DKLayer
/// description:	sets the "selection" colour of the layer
/// 
/// parameters:		<aColour> the colour to set
/// result:			none
///
/// notes:			this sets the guide colour, which is the same as the selection colour. This override allows a
///					common colour-setting UI to be easily used for all layer types.
///
///********************************************************************************************************************

- (void)				setSelectionColour:(NSColor*) aColour
{
	[self setGuideColour:aColour];
}


///*********************************************************************************************************************
///
/// method:			cursor
/// scope:			public instance method
/// overrides:		DKLayer
/// description:	returns the curor in use when this layer is active
/// 
/// parameters:		none
/// result:			none
///
/// notes:			closed hand when dragging a guide, open hand otherwise.
///
///********************************************************************************************************************

- (NSCursor*)			cursor
{
	if([self locked])
		return [NSCursor arrowCursor];
	else
	{
		if(m_dragGuideRef)
		{
			if([m_dragGuideRef isVerticalGuide])
				return [NSCursor resizeLeftRightCursor];
			else
				return [NSCursor resizeUpDownCursor];
		}
		else
			return [NSCursor openHandCursor];
	}
}


///*********************************************************************************************************************
///
/// method:			activeCursorRect
/// scope:			public instance method
/// description:	return a rect where the layer's cursor is shown when the mouse is within it
/// 
/// parameters:		none
/// result:			the cursor rect
///
/// notes:			guide layer's cursor rect is the deletion rect.
///
///********************************************************************************************************************

- (NSRect)			activeCursorRect
{
	return [self guideDeletionRect];
}


///*********************************************************************************************************************
///
/// method:			wasAddedToDrawing:
/// scope:			public instance method
/// description:	notifies the layer that it or a group containing it was added to a drawing.
/// 
/// parameters:		<aDrawing> the drawing that added the layer
/// result:			none
///
/// notes:			sets the default deletion zone to equal the drawing's interior if it hasn't been set already
///
///********************************************************************************************************************

- (void)			wasAddedToDrawing:(DKDrawing*) aDrawing
{
	if( NSIsEmptyRect( mGuideDeletionZone ))
		[self setGuideDeletionRect:[aDrawing interior]];
}


///*********************************************************************************************************************
///
/// method:			layerMayBeDeleted
/// scope:			public instance method
/// description:	return whether the layer can be deleted
/// 
/// parameters:		none
/// result:			NO - typically guide layers shouldn't be deleted
///
/// notes:			This setting is intended to be checked by UI-level code to prevent deletion of layers within the UI.
///					It does not prevent code from directly removing the layer.
///
///********************************************************************************************************************

- (BOOL)			layerMayBeDeleted
{
	return NO;
}


///*********************************************************************************************************************
///
/// method:			menuForEvent:inView:
/// scope:			public instance method
/// description:	allows a contextual menu to be built for the layer or its contents
/// 
/// parameters:		<theEvent> the original event (a right-click mouse event)
///					<view> the view that received the original event
/// result:			a menu that will be displayed as a contextual menu
///
/// notes:			
///
///********************************************************************************************************************

- (NSMenu *)		menuForEvent:(NSEvent *)theEvent inView:(NSView*) view
{
	NSMenu* menu = [super menuForEvent:theEvent inView:view];
	
	if(![self locked])
	{
		if( menu == nil )
			menu = [[[NSMenu alloc] initWithTitle:@"DK_GuideLayerContextualMenu"] autorelease]; // title never seen
	
		NSMenuItem* item = [menu addItemWithTitle:NSLocalizedString(@"Clear Guides", nil) action:@selector(clearGuides:) keyEquivalent:@""];
		[item setTarget:self];
	}
	
	return menu;
}


- (BOOL)			supportsMetadata
{
	return NO;
}




#pragma mark -
#pragma mark As an NSObject

///*********************************************************************************************************************
///
/// method:			dealloc
/// scope:			public instance method
/// overrides:		NSObject
/// description:	deallocates the guide layer
/// 
/// parameters:		none
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				dealloc
{
	[m_hGuides release];
	[m_vGuides release];
	
	[super dealloc];
}


///*********************************************************************************************************************
///
/// method:			init
/// scope:			public instance method - designated initializer
/// overrides:		NSObject
/// description:	initializes the guide layer
/// 
/// parameters:		none
/// result:			the guide layer
///
/// notes:			initially the layer has no guides
///
///********************************************************************************************************************

- (id)					init
{
	self = [super init];
	if (self != nil)
	{
		m_hGuides = [[NSMutableArray alloc] init];
		m_vGuides = [[NSMutableArray alloc] init];
		m_showDragInfo = YES;
		m_snapTolerance = [[self class] defaultSnapTolerance];
		[self setShouldDrawToPrinter:NO];
		[self setSelectionColour:[NSColor orangeColor]];
		
		if (m_hGuides == nil || m_vGuides == nil)
		{
			[self autorelease];
			self = nil;
		}
	}
	if (self != nil)
	{
		[self setLayerName:NSLocalizedString(@"Guides", @"default name for guide layer")];
	}
	return self;
}


#pragma mark -
#pragma mark As part of NSCoding Protocol
- (void)				encodeWithCoder:(NSCoder*) coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	[super encodeWithCoder:coder];
	
	[coder encodeObject:m_hGuides forKey:@"horizontalguides"];
	[coder encodeObject:m_vGuides forKey:@"verticalguides"];
	
	[coder encodeBool:m_snapToGrid forKey:@"snapstogrid"];
	[coder encodeBool:m_showDragInfo forKey:@"showdraginfo"];
	[coder encodeDouble:m_snapTolerance forKey:@"snaptolerance"];
	[coder encodeRect:[self guideDeletionRect] forKey:@"DKGuideLayer_deletionRect"];
}


- (id)					initWithCoder:(NSCoder*) coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	self = [super initWithCoder:coder];
	if (self != nil)
	{
		m_hGuides = [[coder decodeObjectForKey:@"horizontalguides"] mutableCopy];
		m_vGuides = [[coder decodeObjectForKey:@"verticalguides"] mutableCopy];
		
		m_snapToGrid = [coder decodeBoolForKey:@"snapstogrid"];
		m_showDragInfo = [coder decodeBoolForKey:@"showdraginfo"];
		NSAssert(m_dragGuideRef == nil, @"Expected init to zero");
		m_snapTolerance = [coder decodeDoubleForKey:@"snaptolerance"];
		
		NSRect dr = [coder decodeRectForKey:@"DKGuideLayer_deletionRect"];
		[self setGuideDeletionRect:dr];
		
		if (m_hGuides == nil || m_vGuides == nil )
		{
			[self autorelease];
			self = nil;
		}
	}
	return self;
}


#pragma mark -
#pragma mark As part of NSMenuValidation Protocol
///*********************************************************************************************************************
///
/// method:			validateMenuItem:
/// scope:			public instance method
/// overrides:		NSObject
/// description:	enables the menu item if targeted at clearGuides
/// 
/// parameters:		<item> a menu item
/// result:			YES if the item is enabled, NO otherwise
///
/// notes:			layer must be unlocked and have at least one guide to enable the menu.
///
///********************************************************************************************************************

- (BOOL)				validateMenuItem:(NSMenuItem*) item
{
	if ([item action] == @selector( clearGuides: ))
		return ![self locked] && ([[self verticalGuides] count] > 0 || [[self horizontalGuides] count] > 0);
		
	return [super validateMenuItem:item];
}


@end


#pragma mark -
@implementation DKGuide
#pragma mark As a DKGuide


///*********************************************************************************************************************
///
/// method:			setPosition:
/// scope:			public instance method
/// overrides:		
/// description:	sets the position of the guide
/// 
/// parameters:		<pos> a position value in drawing coordinates
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				setGuidePosition:(CGFloat) pos
{
	m_position = pos;
}


///*********************************************************************************************************************
///
/// method:			position
/// scope:			public instance method
/// overrides:		
/// description:	returns the position of the guide
/// 
/// parameters:		none
/// result:			position value in drawing coordinates
///
/// notes:			
///
///********************************************************************************************************************

- (CGFloat)				guidePosition
{
	return m_position;
}


///*********************************************************************************************************************
///
/// method:			setIsVerticalGuide:
/// scope:			public instance method
/// overrides:		
/// description:	sets whether the guide is vertically oriented or horizontal
/// 
/// parameters:		<vert> YES for a vertical guide, NO for a horizontal guide
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				setIsVerticalGuide:(BOOL) vert
{
	m_isVertical = vert;
}


///*********************************************************************************************************************
///
/// method:			isVerticalGuide
/// scope:			public instance method
/// overrides:		
/// description:	returns whether the guide is vertically oriented or horizontal
/// 
/// parameters:		none 
/// result:			YES for a vertical guide, NO for a horizontal guide
///
/// notes:			
///
///********************************************************************************************************************

- (BOOL)				isVerticalGuide
{
	return m_isVertical;
}


///*********************************************************************************************************************
///
/// method:			setGuideColour:
/// scope:			public instance method
/// overrides:		
/// description:	sets the guide's colour
/// 
/// parameters:		<colour> a colour 
/// result:			none
///
/// notes:			note that this doesn't mark the guide for update - DKGuideLayer has a method for doing that.
///
///********************************************************************************************************************

- (void)				setGuideColour:(NSColor*) colour
{
	[colour retain];
	[m_colour release];
	m_colour = colour;
}


///*********************************************************************************************************************
///
/// method:			guideColour
/// scope:			public instance method
/// overrides:		
/// description:	returns the guide's colour
/// 
/// parameters:		none 
/// result:			a colour
///
/// notes:			
///
///********************************************************************************************************************

- (NSColor*)			guideColour
{
	return m_colour;
}


///*********************************************************************************************************************
///
/// method:			drawInRect:inView:
/// scope:			public instance method
/// overrides:		
/// description:	draws the guide
/// 
/// parameters:		<rect> the update rect 
///					<lw> the line width to draw
/// result:			none
///
/// notes:			is called by the guide layer only if the guide needs to be drawn
///
///********************************************************************************************************************

- (void)				drawInRect:(NSRect) rect lineWidth:(CGFloat) lw
{
	NSPoint a, b;
	
	if([self isVerticalGuide])
	{
		a.y = NSMinY( rect );
		b.y = NSMaxY( rect );
		a.x = b.x = [self guidePosition];
	}
	else
	{
		a.x = NSMinX( rect );
		b.x = NSMaxX( rect );
		a.y = b.y = [self guidePosition];
	}
		
	[[self guideColour] set];
	[NSBezierPath setDefaultLineWidth:lw];
	[NSBezierPath strokeLineFromPoint:a toPoint:b];
}


#pragma mark -
#pragma mark As an NSObject
///*********************************************************************************************************************
///
/// method:			init
/// scope:			public instance method - designated initializer
/// overrides:		NSObject
/// description:	initializes the guide
/// 
/// parameters:		none
/// result:			the guide
///
/// notes:			
///
///********************************************************************************************************************

- (id)					init
{
	if ((self = [super init]) != nil )
	{
		m_position = 0.0;
		m_isVertical = NO;
		[self setGuideColour:[NSColor cyanColor]];
		if (m_colour == nil)
		{
			[self autorelease];
			self = nil;
		}
	}
	return self;
}


#pragma mark -
#pragma mark As part of NSCoding Protocol
- (void)				encodeWithCoder:(NSCoder*) coder
{
	[coder encodeDouble:[self guidePosition] forKey:@"position"];
	[coder encodeBool:[self isVerticalGuide] forKey:@"vertical"];
	[coder encodeObject:[self guideColour] forKey:@"guide_colour"];
}


- (id)					initWithCoder:(NSCoder*) coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	if ((self = [super init]) != nil )
	{
		m_position = [coder decodeDoubleForKey:@"position"];
		m_isVertical = [coder decodeBoolForKey:@"vertical"];
		
		// guard against older files that didn't save this ivar
		
		NSColor* clr = [coder decodeObjectForKey:@"guide_colour"];
		
		if ( clr )
			[self setGuideColour:clr];
	}
	return self;
}


@end

