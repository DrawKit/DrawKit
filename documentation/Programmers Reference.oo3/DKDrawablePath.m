//
//  DKDrawablePath.m
//  DrawingArchitecture
//
//  Created by graham on 10/09/2006.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "DKDrawablePath.h"

#import "DKDrawableShape.h"
#import "DKDrawing.h"
#import "DKStyle.h"
#import "DKKnob.h"
#import "DKObjectDrawingLayer.h"
#import "DKStroke.h"
#import "NSBezierPath+Editing.h"
#import "NSBezierPath+Geometry.h"
#import "GCInfoFloater.h"
#import "CurveFit.h"
#import "LogEvent.h"


#pragma mark Static Vars
static float			sAngleConstraint = 0.261799387799;	// 15¡
static NSPoint			sMouseForPathSnap = {0,0};
static NSBezierPath*	sPathForUndo = nil;
static NSColor*			sInfoWindowColour = nil;

#pragma mark -
@implementation DKDrawablePath
#pragma mark As a DKDrawablePath

///*********************************************************************************************************************
///
/// method:			drawablePathWithPath:
/// scope:			public class method
/// overrides:		
/// description:	creates a drawable path object for an existing NSBezierPath
/// 
/// parameters:		<path> the path to use
/// result:			a new drawable path object which has the path supplied
///
/// notes:			convenience method allows you to turn any path into a drawable that can be added to a drawing
///
///********************************************************************************************************************

+ (DKDrawablePath*)		drawablePathWithPath:(NSBezierPath*) path
{
	DKDrawablePath* dp = [(DKDrawablePath*)[DKDrawablePath alloc] initWithBezierPath:path];
	
	return [dp autorelease];
}


//*********************************************************************************************************************
///
/// method:			drawablePathWithPath:withStyle:
/// scope:			public class method
/// overrides:		
/// description:	creates a drawable path object for an existing NSBezierPath and style
/// 
/// parameters:		<path> the path to use
///					<aStyle> a style to apply to the path
/// result:			a new drawable path object which has the path supplied
///
/// notes:			convenience method allows you to turn any path into a drawable that can be added to a drawing
///
///********************************************************************************************************************

+ (DKDrawablePath*)		drawablePathWithPath:(NSBezierPath*) path withStyle:(DKStyle*) aStyle
{
	DKDrawablePath* dp = [self drawablePathWithPath:path];
	[dp setStyle:aStyle];
	
	return dp;
}


//*********************************************************************************************************************
///
/// method:			setInfoWindowBackgroundColour:
/// scope:			public class method
/// overrides:		
/// description:	set the background colour to use for the info window displayed when interacting with paths
/// 
/// parameters:		<colour> the colour to use
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

+ (void)				setInfoWindowBackgroundColour:(NSColor*) colour
{
	[colour retain];
	[sInfoWindowColour release];
	sInfoWindowColour = colour;
}


#pragma mark -
///*********************************************************************************************************************
///
/// method:			initWithPath:
/// scope:			public instance method
/// overrides:		
/// description:	initialises a drawable path object from an existing path
/// 
/// parameters:		<aPath> the path to use
/// result:			the drawable path object
///
/// notes:			the path is retained, not copied
///
///********************************************************************************************************************

- (id)				initWithBezierPath:(NSBezierPath*) aPath
{
	self = [self init];
	if (self != nil)
	{
		[self setPath:aPath];
	}
	
	return self;
}


#pragma mark -
///*********************************************************************************************************************
///
/// method:			setPath:
/// scope:			public instance method
/// overrides:		
/// description:	sets the object's path to the given NSBezierPath
/// 
/// parameters:		<path> a path
/// result:			none
///
/// notes:			path is edited in place, so pass in a copy if necessary. This method doesn't do the copy since
///					the creation of paths require this method to keep the same object during the operation.
///
///********************************************************************************************************************

- (void)			setPath:(NSBezierPath*) path
{
	if ( path != m_path )
	{
	//	LogEvent_(kStateEvent, @"setting path: %@", path );
		
		[self notifyVisualChange];
		[[self undoManager] registerUndoWithTarget:self selector:@selector(setPath:) object:m_path];
		
		[m_path release];
		m_path = [path retain];
		
		[self notifyVisualChange];
	}
}


///*********************************************************************************************************************
///
/// method:			path
/// scope:			public instance method
/// overrides:		
/// description:	returns the object's current path
/// 
/// parameters:		none
/// result:			the NSBezierPath
///
/// notes:			
///
///********************************************************************************************************************

- (NSBezierPath*)	path
{
	return m_path;
}


///*********************************************************************************************************************
///
/// method:			drawControlPointsOfPath:usingKnobs:
/// scope:			protected instance method
/// overrides:		
/// description:	returns the actual path drawn when the object is rendered
/// 
/// parameters:		<path> the path to draw
///					<knobs> the knobs object that draws the handles on the path
/// result:			none
///
/// notes:			called by -drawSelectedState
///
///********************************************************************************************************************

- (void)			drawControlPointsOfPath:(NSBezierPath*) path usingKnobs:(DKKnob*) knobs
{
	// draws the control points of the entire path using the knobs supplied.
	
	NSBezierPathElement et;
	NSPoint				ap[3];
	NSPoint				lp;
	DKKnobType			knobType;
	
	int i, ec = [path elementCount];
	lp = NSMakePoint( -1, -1 );
	
	for( i = 0; i < ec; ++i )
	{
		et = [path elementAtIndex:i associatedPoints:ap];
		
		if ( et == NSCurveToBezierPathElement )
		{
			// three points to draw, plus some bars
			
			if ( ! NSEqualPoints( lp, NSMakePoint( -1, -1 )))
			{
				knobType = kDKOnPathKnobType;
				
				if ([self locked])
					knobType |= kDKKnobIsDisabledFlag;
				
				[knobs drawControlBarFromPoint:ap[0] toPoint:lp];
				[knobs drawKnobAtPoint:lp ofType:knobType userInfo:nil];
			}

			knobType = kDKControlPointKnobType;
	
			if ([self locked])
				knobType |= kDKKnobIsDisabledFlag;
			
			[knobs drawControlBarFromPoint:ap[1] toPoint:ap[2]];
			[knobs drawKnobAtPoint:ap[0] ofType:knobType userInfo:nil];
			[knobs drawKnobAtPoint:ap[1] ofType:knobType userInfo:nil];
			lp = ap[2];
			
			// if this is the last element, draw the end point
			
			if ( i == ec - 1 )
			{
				knobType = kDKOnPathKnobType;
	
				if ([self locked])
					knobType |= kDKKnobIsDisabledFlag;
				[knobs drawKnobAtPoint:lp ofType:knobType userInfo:nil];
			}
			
#ifdef qIncludeGraphicDebugging
			if ( m_showPartcodes )
			{
				int			j, pc;
				
				for( j = 0; j < 3; ++j )
				{
					pc = [self hitPart:ap[j]];
					[knobs drawPartcode:pc atPoint:ap[j] fontSize:10];
				}
			}
#endif
		}
		else
		{
			// one point to draw. don't draw a moveto that is the last element
			
			BOOL drawit;
			
			drawit = !(( et == NSMoveToBezierPathElement ) && ( i == ( ec - 1 )));
			
			if ( drawit )
			{
				knobType = kDKOnPathKnobType;
				if ([self locked])
					knobType |= kDKKnobIsDisabledFlag;
				[knobs drawKnobAtPoint:lp ofType:knobType userInfo:nil];
				[knobs drawKnobAtPoint:ap[0] ofType:knobType userInfo:nil];
			}
			lp = ap[0];
		
#ifdef qIncludeGraphicDebugging
			if ( m_showPartcodes )
			{
				int			pc;
				
				pc = [self hitPart:ap[0]];
				[knobs drawPartcode:pc atPoint:ap[0] fontSize:10];	
			}
#endif
		}
	}
}


///*********************************************************************************************************************
///
/// method:			setNeedsDisplayForRects
/// scope:			private instance method
/// overrides:		
/// description:	given a set of rects as NSValue objects, this invalidates them
/// 
/// parameters:		<rects> a set of rects as NSValue objects
/// result:			none
///
/// notes:			used to optimize updates to an area that is much tighter to a complex path that the overall
///					bounds would be, thus minimizing drawing. Factors in the current style's extra space. The optimization
///					is not done if the style has a fill, because tearing can occur with some styles
///
///********************************************************************************************************************

- (void)				setNeedsDisplayForRects:(NSSet*) rects
{
	if ([[self style] hasFill] || [[self style] hasHatch])
	{
		[self setNeedsDisplayInRect:[self bounds]];
	}
	else
	{
		if( rects != nil )
		{
			NSSize			extra = [[self style] extraSpaceNeeded];
			
			// add in control knob sizes
			
			extra.width += 3;
			extra.height += 3;
			[[self layer] setNeedsDisplayInRects:rects withExtraPadding:extra];
		}
	}
}


#pragma mark -
///*********************************************************************************************************************
///
/// method:			combine:
/// scope:			public instance method
/// overrides:		
/// description:	merges two paths by simply appending them
/// 
/// parameters:		<anotherPath> another drawable path object like this one
/// result:			none
///
/// notes:			this simply appends the part of the other object to this one and recomputes the bounds, etc.
///					the result can act like a union, difference or XOR according to the relative placements of the
///					paths and the winding rules in use.
///
///********************************************************************************************************************

- (void)				combine:(DKDrawablePath*) anotherPath
{
	NSBezierPath* path = [[self path] copy];

	[path appendBezierPath:[anotherPath path]];
	[self setPath:path];
	[path release];
}


///*********************************************************************************************************************
///
/// method:			join:tolerance:makeColinear:
/// scope:			public instance method
/// overrides:		
/// description:	joins open paths together at their ends
/// 
/// parameters:		<anotherPath> another drawable path object like this one
///					<tol> a value used to determine if the end points are placed sufficiently close to be joinable
///					<colin> if YES, and the joined segments are curves, this adjusts the control points of the curve
///					so that the join is colinear.
/// result:			YES if the paths were joined, NO otherwise
///
/// notes:			this attempts to join either or both ends of the two paths if they are placed sufficiently
///					closely. Usually the higher level join action at the layer level will be used.
///
///********************************************************************************************************************

- (BOOL)				join:(DKDrawablePath*) anotherPath tolerance:(float) tol makeColinear:(BOOL) colin
{
//	LogEvent_(kReactiveEvent, @"joining path, tolerance = %f", tol );
	
	NSBezierPath* ap = [anotherPath path];
	
	if ([ap isPathClosed] || [[self path] isPathClosed])
		return NO;
		
	// do the paths share an end point?
	
	float	dist;
	int		j, k;
	
	NSPoint p1[2];
	NSPoint p2[2];
	
	p1[0] = [[self path] firstPoint];	// head 1
	p1[1] = [[self path] lastPoint];	// tail 1
	p2[0] = [ap firstPoint];			// head 2
	p2[1] = [ap lastPoint];				// tail 2
	
//	LogEvent_(kInfoEvent,  @"end points of path A: %@, %@", NSStringFromPoint( p1[0]), NSStringFromPoint( p1[1]));
//	LogEvent_(kInfoEvent,  @"end points of path B: %@, %@", NSStringFromPoint( p2[0]), NSStringFromPoint( p2[1]));
	
	for( j = 0; j < 2; ++j )
	{
		for( k = 0; k < 2; ++k )
		{
			dist = hypotf( p2[j].x - p1[k].x, p2[j].y - p1[k].y );//LineLength( p1[k], p2[j] );
			
		//	LogEvent_(kInfoEvent, @"checking proximity %d with %d, dist = %f", k, j, dist );
			
			if ( dist <= tol )
			{
			//	LogEvent_(kInfoEvent, @"joining paths (k=%d,j=%d)", k, j );
				
				// found points close enough to join. One path may need reversing to accomplish it.
				// this would be when joining two heads or two tails.
				
				if ( k == j )
					ap = [ap bezierPathByReversingPath];
					
				// join to whichever path has the tail aligned
				
				NSBezierPath* newPath;
				int			  ec;
				
				if ( k == 0 )
				{
					newPath = [ap copy];
					ec = [newPath elementCount] - 1;
					[newPath appendBezierPathRemovingInitialMoveToPoint:[self path]];
				}
				else
				{
					// copy existing path rather than append directly - this ensures the operation is
					// undoable.
					
					newPath = [[self path] copy];
					ec = [newPath elementCount] - 1;
					[newPath appendBezierPathRemovingInitialMoveToPoint:ap];
				}
				
				if ( colin )
				{
					// colinearise the join if the segments joined are both curvetos
					
					NSPoint				elp[6];
					NSBezierPathElement el = [newPath elementAtIndex:ec associatedPoints:elp];
					NSBezierPathElement fl = [newPath elementAtIndex:ec + 1 associatedPoints:&elp[3]];
				
					if (( el == fl ) && ( el == NSCurveToBezierPathElement ))
					{
						[NSBezierPath colineariseVertex:&elp[1] cpA:&elp[1] cpB:&elp[3]];
					
						[newPath setAssociatedPoints:elp atIndex:ec];
						[newPath setAssociatedPoints:&elp[3] atIndex:ec+1];
					}
				}

				// if the other ends are also aligned, close the path
				
				k = ( k == 0 )? 1 : 0;
				j = ( j == 0 )? 1 : 0;
				
				dist = hypotf( p2[j].x - p1[k].x, p2[j].y - p1[k].y );//LineLength( p1[k], p2[j] );
				
				if ( dist <= tol )
				{
					[newPath closePath];
					
					if ( colin )
					{
						// colinearise the join if the segments joined are both curvetos
						
						ec = [newPath elementCount] - 3;
						
						NSPoint				elp[6];
						NSBezierPathElement el = [newPath elementAtIndex:ec associatedPoints:elp];
						NSBezierPathElement fl = [newPath elementAtIndex:1 associatedPoints:&elp[3]];
					
						if (( el == fl ) && ( el == NSCurveToBezierPathElement ))
						{
							[NSBezierPath colineariseVertex:&elp[1] cpA:&elp[1] cpB:&elp[3]];
						
							[newPath setAssociatedPoints:elp atIndex:ec];
							[newPath setAssociatedPoints:&elp[3] atIndex:1];
						}
					}
				}
					
				[self setPath:newPath];
				[newPath release];
				
				return YES;
			}
		}
	}

	return NO;
}


///*********************************************************************************************************************
///
/// method:			breakApart
/// scope:			public instance method
/// overrides:		
/// description:	converts each subpath in the current path to a separate object
/// 
/// parameters:		none
/// result:			an array of DKDrawablePath objects
///
/// notes:			A subpath is a path delineated by a moveTo opcode. Each one is made a separate new path. If there
///					is only one subpath (common) then the result will have just one entry.
///
///********************************************************************************************************************

- (NSArray*)			breakApart
{
	// returns a list of path objects each containing one subpath from this object's path. If this path only has one subpath, this
	// returns one object in the array which is equivalent to a copy.
	
	NSArray*		subpaths = [[self path] subPaths];
	NSEnumerator*	iter = [subpaths objectEnumerator];
	NSBezierPath*	pp;
	NSMutableArray*	newObjects;
	DKDrawablePath*	dp;
	
	newObjects = [[NSMutableArray alloc] init];
	
	while(( pp = [iter nextObject]))
	{
		if ( ![pp isEmpty])
		{
			dp = [DKDrawablePath drawablePathWithPath:pp];
			
			[dp setStyle:[self style]];
			[newObjects addObject:dp];
		}
	}
	
	return [newObjects autorelease];
}


#pragma mark -
///*********************************************************************************************************************
///
/// method:			setPathEditingMode:
/// scope:			public instance method
/// overrides:		
/// description:	sets the "mode" of operation for creating new path objects
/// 
/// parameters:		<editPathMode> a constant indicating how a new path should be constructed.
/// result:			none
///
/// notes:			paths are created by tools usually so this will be rarely needed. Pass 0 for the defalt mode which
///					is to edit an existing path (once created all paths are logically the same)
///
///********************************************************************************************************************

- (void)				setPathEditingMode:(int) editPathMode
{
	m_editPathMode = editPathMode;
}


///*********************************************************************************************************************
///
/// method:			pathEditingMode
/// scope:			public instance method
/// overrides:		
/// description:	gets the "mode" of operation for creating new path objects
/// 
/// parameters:		none
/// result:			the current editing/creation mode
///
/// notes:			
///
///********************************************************************************************************************

- (int)					pathEditingMode
{
	return m_editPathMode;
}


#pragma mark -
///*********************************************************************************************************************
///
/// method:			pathCreateLoop:
/// scope:			private instance method
/// overrides:		
/// description:	event loop for creating a curved path point by point
/// 
/// parameters:		<initialPoint> where to start
/// result:			none
///
/// notes:			keeps control until the ending criteria are met (double-click or click on first point).
///
///********************************************************************************************************************

- (void)				pathCreateLoop:(NSPoint) initialPoint
{
	// when we create a path, we capture the mouse on the first mouse down and don't return until the path is complete. This is necessary because
	// the layer isn't designed to handle this type of multi-click behaviour by itself.
	
	// on entry, the path shouldn't yet exist.

	NSEvent*	theEvent;
	int			mask = NSLeftMouseDownMask | NSLeftMouseUpMask | NSLeftMouseDraggedMask | NSMouseMovedMask | NSPeriodicMask | NSScrollWheelMask;
	NSView*		view = [[self layer] currentView];
	BOOL		loop = YES;
	BOOL		first = YES;
	int			element, partcode;
	NSPoint		p, ip, centre, opp;
	
	p = ip = [self snappedMousePoint:initialPoint withControlFlag:NO];
	
	LogEvent_(kReactiveEvent, @"entering path create loop");
	
	NSBezierPath* path = [NSBezierPath bezierPath];
	
	[path moveToPoint:p];
	[path curveToPoint:p controlPoint1:p controlPoint2:p];
	[self setPath:path];
	
	element = 1;
	partcode = partcodeForElementControlPoint( element, 1 );

	while( loop )
	{
		theEvent = [NSApp nextEventMatchingMask:mask untilDate:[NSDate distantFuture] inMode:NSEventTrackingRunLoopMode dequeue:YES];
		
		p = [view convertPoint:[theEvent locationInWindow] fromView:nil];
		p = [self snappedMousePoint:p withControlFlag:NO];
		
		if ([self shouldEndPathCreationWithEvent:theEvent])
		{
			loop = NO;
			goto finish;
		}
		
		switch ([theEvent type])
		{
			case NSLeftMouseDown:
			{
				// when the mouse goes down we start a new segment unless we hit the first point in which case we
				// terminate the loop
				
				NSRect tr = NSMakeRect( ip.x - 3.0, ip.y - 3.0, 6.0, 6.0 );
				
				if ( NSPointInRect( p, tr ))
				{
					loop = NO;
					[path setControlPoint:p forPartcode:partcode];
					
					// set cp2 to the colinear opposite of cp1 of element 1
					
					centre = [path controlPointForPartcode:partcodeForElement( 0 )];
					
					opp = [NSBezierPath colinearPointForPoint:[path controlPointForPartcode:partcodeForElementControlPoint( 1, 0)] centrePoint:centre]; 
					[path setControlPoint:opp forPartcode:partcodeForElementControlPoint( element, 1 )];
					//[path closePath];
				}
				else
				{
					[path curveToPoint:p controlPoint1:p controlPoint2:p];
					++element;
					partcode = partcodeForElementControlPoint( element, 2 );
					first = NO;
				}
			}
			break;
			
			case NSLeftMouseDragged:
				// a mouse drag pulls out a curve segment with all three points set to <p>. The partcode and element are
				// already set
				[self notifyVisualChange];
				[view autoscroll:theEvent];
				[path setControlPoint:p forPartcode:partcode];
				[path setControlPoint:p forPartcode:partcodeForElementControlPoint( element, 1 )];
				[path setControlPoint:p forPartcode:partcodeForElementControlPoint( element, 0 )];
				
				if ( ! first )
				{
					// also affects the previous cp2 colinearly
					
					centre = [path controlPointForPartcode:partcodeForElementControlPoint( element - 1, 2 )];
					opp = [NSBezierPath colinearPointForPoint:p centrePoint:centre]; 
					
					[path setControlPoint:opp forPartcode:partcodeForElementControlPoint( element - 1, 1 )];
				}
				break;
			
			case NSLeftMouseUp:
				partcode = partcodeForElementControlPoint( element, 2 );
				break;
				
			case NSMouseMoved:
				[self notifyVisualChange];
				[view autoscroll:theEvent];
				[path setControlPoint:p forPartcode:partcode];
				[path setControlPoint:p forPartcode:partcodeForElementControlPoint( element, 1 )];
				break;
				
			case NSScrollWheel:
				[view scrollWheel:theEvent];
				break;
			
			default:
				break;
		}
		
		[self notifyVisualChange];
	}

finish:	
	LogEvent_(kReactiveEvent, @"ending path create loop");
	
	[self setPath:[path bezierPathByStrippingRedundantElements]];
	[self setPathEditingMode:kGCPathCreateModeEditExisting];
	[self notifyVisualChange];
}


///*********************************************************************************************************************
///
/// method:			lineCreateLoop:
/// scope:			private instance method
/// overrides:		
/// description:	event loop for creating a single straight line
/// 
/// parameters:		<initialPoint> where to start
/// result:			none
///
/// notes:			keeps control until the ending criteria are met (second click).
///
///********************************************************************************************************************

- (void)				lineCreateLoop:(NSPoint) initialPoint
{
	// creates a single straight line path, with only one segment. There are two ways a user can make a line - click and release,
	// drag, then click. Or click-drag-release.
	
	NSEvent*	theEvent;
	int			mask = NSLeftMouseDownMask | NSLeftMouseUpMask | NSLeftMouseDraggedMask | NSMouseMovedMask | NSPeriodicMask | NSScrollWheelMask;
	NSView*		view = [[self layer] currentView];
	BOOL		loop = YES, constrain = NO, forceMouseUp = NO;
	int			element, partcode;
	NSPoint		p, ip;
	
	p = ip = [self snappedMousePoint:initialPoint withControlFlag:NO];
	
	LogEvent_(kReactiveEvent, @"entering line create loop");
	
	NSBezierPath* path = [NSBezierPath bezierPath];
	
	[path moveToPoint:p];
	[path lineToPoint:p];
	[self setPath:path];
	
	element = 1;
	partcode = partcodeForElement( element );

	while( loop )
	{
		theEvent = [NSApp nextEventMatchingMask:mask untilDate:[NSDate distantFuture] inMode:NSEventTrackingRunLoopMode dequeue:YES];
		
		p = [view convertPoint:[theEvent locationInWindow] fromView:nil];
		p = [self snappedMousePoint:p withControlFlag:NO];
		
		constrain = (([theEvent modifierFlags] & NSShiftKeyMask) != 0 );
		
		if ( constrain )
		{
			// slope of line is forced to be on 15Â° intervals
			
			float	angle = atan2f( p.y - ip.y, p.x - ip.x );
			float	rem = fmodf( angle, sAngleConstraint );
			float	radius = hypotf( p.x - ip.x, p.y - ip.y );
		
			if ( rem > sAngleConstraint / 2.0 )
				angle += ( sAngleConstraint - rem );
			else
				angle -= rem;
				
			p.x = ip.x + ( radius * cosf( angle ));
			p.y = ip.y + ( radius * sinf( angle ));
		}
		
		switch ([theEvent type])
		{
			case NSLeftMouseDown:
				loop = NO;
				break;
			
			case NSLeftMouseDragged:
				[self notifyVisualChange];
				[view autoscroll:theEvent];
				[path setControlPoint:p forPartcode:partcode];
				break;
			
			case NSLeftMouseUp:
				// if the final point is in the same place as the first point, do a click-drag-click creation. Otherwise
				// we've already dragged so finish.
				
				if ( ! NSEqualPoints( p, ip ))
				{
					loop = NO;
					forceMouseUp = YES;
				}
				break;
				
			case NSMouseMoved:
				[self notifyVisualChange];
				[view autoscroll:theEvent];
				[path setControlPoint:p forPartcode:partcode];
				break;
				
			case NSScrollWheel:
				[view scrollWheel:theEvent];
				break;
			
			default:
				break;
		}
		
		[self notifyVisualChange];
	}

	LogEvent_(kReactiveEvent, @"ending line create loop");
	
	[self setPathEditingMode:kGCPathCreateModeEditExisting];
	[self notifyVisualChange];
	
	if ( forceMouseUp )
		[view mouseUp:theEvent];
}


///*********************************************************************************************************************
///
/// method:			polyCreateLoop:
/// scope:			private instance method
/// overrides:		
/// description:	event loop for creating a polygon consisting of straight line sections
/// 
/// parameters:		<initialPoint> where to start
/// result:			none
///
/// notes:			keeps control until the ending criteria are met (double-click or click on start point).
///
///********************************************************************************************************************

- (void)				polyCreateLoop:(NSPoint) initialPoint
{
	// creates a polygon or multi-segment line. Each click makes a new node, double-click or click in first point to finish.
	
	NSEvent*	theEvent;
	int			mask = NSLeftMouseDownMask | NSMouseMovedMask | NSPeriodicMask | NSScrollWheelMask;
	NSView*		view = [[self layer] currentView];
	BOOL		loop = YES, constrain = NO;
	int			element, partcode;
	NSPoint		p, ip, lp;
	
	p = ip = [self snappedMousePoint:initialPoint withControlFlag:NO];
	
	LogEvent_(kReactiveEvent, @"entering poly create loop");
	
	NSBezierPath* path = [NSBezierPath bezierPath];
	
	[path moveToPoint:p];
	[path lineToPoint:p];
	[self setPath:path];
	
	element = 1;
	partcode = partcodeForElement( element );
	lp = ip;
	
	//[NSEvent startPeriodicEventsAfterDelay:0.5 withPeriod:0.1];
	
	while( loop )
	{
		theEvent = [NSApp nextEventMatchingMask:mask untilDate:[NSDate distantFuture] inMode:NSEventTrackingRunLoopMode dequeue:YES];
		
		if ([self shouldEndPathCreationWithEvent:theEvent])
		{
			loop = NO;
			path = [path bezierPathByRemovingTrailingElements:1];
			goto finish;
		}

		p = [view convertPoint:[theEvent locationInWindow] fromView:nil];
		p = [self snappedMousePoint:p withControlFlag:NO];
		
		constrain = (([theEvent modifierFlags] & NSShiftKeyMask) != 0 );
		
		if ( constrain )
		{
			// slope of line is forced to be on 15¡ intervals
			
			float	angle = atan2f( p.y - lp.y, p.x - lp.x );
			float	rem = fmodf( angle, sAngleConstraint );
			float	radius = hypotf( p.x - lp.x, p.y - lp.y );
		
			if ( rem > sAngleConstraint / 2.0 )
				angle += ( sAngleConstraint - rem );
			else
				angle -= rem;
				
			p.x = lp.x + ( radius * cosf( angle ));
			p.y = lp.y + ( radius * sinf( angle ));
		}

		switch ([theEvent type])
		{
			case NSLeftMouseDown:
			{
				NSRect tr = NSMakeRect( ip.x - 3.0, ip.y - 3.0, 6.0, 6.0 );
				
				if ( NSPointInRect( p, tr ))
				{
					loop = NO;
					path = [path bezierPathByRemovingTrailingElements:1];
					[path closePath];
				}
				else
				{
					lp = p;
					
					[path lineToPoint:p];
					partcode = partcodeForElement( ++element );
				}
			}
			break;
			
			case NSMouseMoved:
				[view autoscroll:theEvent];
				[self notifyVisualChange];
				[path setControlPoint:p forPartcode:partcode];
				break;
				
			case NSScrollWheel:
				[view scrollWheel:theEvent];
				break;
			
			default:
				break;
		}
		
		[self notifyVisualChange];
	}

finish:	
	LogEvent_(kReactiveEvent, @"ending poly create loop");
	
	//[NSEvent stopPeriodicEvents];
	
	[self setPath:path];
	
	[self setPathEditingMode:kGCPathCreateModeEditExisting];
	[self notifyVisualChange];
}


///*********************************************************************************************************************
///
/// method:			freehandCreateLoop:
/// scope:			private instance method
/// overrides:		
/// description:	event loop for creating a curved path by fitting it to a series of sampled points
/// 
/// parameters:		<initialPoint> where to start
/// result:			none
///
/// notes:			keeps control until the ending criteria are met (mouse up).
///
///********************************************************************************************************************

- (void)				freehandCreateLoop:(NSPoint) initialPoint
{
	// this works by building a freehand vector path (line segments) then smoothing it using curve fitting at the end.
	
	NSEvent*	theEvent;
	int			mask = NSLeftMouseDownMask | NSLeftMouseUpMask | NSLeftMouseDraggedMask | NSPeriodicMask | NSScrollWheelMask;
	NSView*		view = [[self layer] currentView];
	BOOL		loop = YES;
	NSPoint		p, lastPoint;
	
	p = lastPoint = initialPoint;
	
	LogEvent_(kReactiveEvent, @"entering freehand create loop");
	
	NSBezierPath* path = [NSBezierPath bezierPath];
	
	[path moveToPoint:p];
	[self setPath:path];
	
	while( loop )
	{
		theEvent = [NSApp nextEventMatchingMask:mask untilDate:[NSDate distantFuture] inMode:NSEventTrackingRunLoopMode dequeue:YES];
		
		p = [view convertPoint:[theEvent locationInWindow] fromView:nil];
		
		BOOL shiftKey = ([theEvent modifierFlags] & NSShiftKeyMask ) != 0;
		
		p = [self snappedMousePoint:p withControlFlag:shiftKey];
		
		switch ([theEvent type])
		{
			case NSLeftMouseDown:
				loop = NO;
				break;
			
			case NSLeftMouseDragged:
				if ( ! NSEqualPoints( p, lastPoint ))
				{
					[path lineToPoint:p];
				#ifdef qUseCurveFit
					[self setPath:curveFitPath( path, m_freehandEpsilon )];
				#else
					[self invalidateCache];				
					[self notifyVisualChange];
				#endif
					lastPoint = p;
				}
				[view autoscroll:theEvent];
				break;
			
			case NSLeftMouseUp:
				loop = NO;
				break;
				
			case NSScrollWheel:
				[view scrollWheel:theEvent];
				break;
			
			default:
				break;
		}
		
		[self notifyVisualChange];
	}

	LogEvent_(kReactiveEvent, @"ending freehand create loop");
	
	[self setPathEditingMode:kGCPathCreateModeEditExisting];
	[self notifyVisualChange];
	
	[view mouseUp:theEvent];
}



///*********************************************************************************************************************
///
/// method:			arcCreateLoop:
/// scope:			private instance method
/// overrides:		
/// description:	event loop for creating an arc or a wedge
/// 
/// parameters:		<initialPoint> where to start
/// result:			none
///
/// notes:			keeps control until the ending criteria are met (second click).
///
///********************************************************************************************************************

- (void)				arcCreateLoop:(NSPoint) initialPoint
{
	// creates a circle segment. First click sets the centre, second the first radius, third the second radius.
	
	NSEvent*		theEvent;
	int				mask = NSLeftMouseDownMask | NSMouseMovedMask | NSPeriodicMask | NSScrollWheelMask;
	NSView*			view = [[self layer] currentView];
	BOOL			loop = YES, constrain = NO;
	int				element, partcode, phase;
	NSPoint			p, centre, lp, nsp;
	float			radius = 0.0;
	float			startAngle = 0.0;
	float			endAngle;
	DKStyle*		savedStyle = nil;
	NSString*		abbrUnits = [[self drawing] abbreviatedDrawingUnits];
	
	savedStyle = [[self style] retain];
	[self setStyle:[DKStyle styleWithFillColour:nil strokeColour:[NSColor redColor] strokeWidth:2.0]];
	
	p = centre = [self snappedMousePoint:initialPoint withControlFlag:NO];
	phase = 0;	// set radius
	
	LogEvent_(kReactiveEvent, @"entering arc create loop");
	
	NSBezierPath* path = [NSBezierPath bezierPath];
	
	[path moveToPoint:p];
	[path lineToPoint:p];	// begin rubber band of first line segment
	[self setPath:path];
	
	element = 1;
	partcode = partcodeForElement( element );
	lp = centre;
	
	while( loop )
	{
		theEvent = [NSApp nextEventMatchingMask:mask untilDate:[NSDate distantFuture] inMode:NSEventTrackingRunLoopMode dequeue:YES];
		
		nsp = [view convertPoint:[theEvent locationInWindow] fromView:nil];
		p = [self snappedMousePoint:nsp withControlFlag:NO];
		
		constrain = (([theEvent modifierFlags] & NSShiftKeyMask) != 0 );
		
		if ( constrain )
		{
			// slope of line is forced to be on 15¡ intervals
			
			float	angle = atan2f( p.y - lp.y, p.x - lp.x );
			float	rem = fmodf( angle, sAngleConstraint );
			float	rad = hypotf( p.x - lp.x, p.y - lp.y );
		
			if ( rem > sAngleConstraint / 2.0 )
				angle += ( sAngleConstraint - rem );
			else
				angle -= rem;
				
			p.x = lp.x + ( rad * cosf( angle ));
			p.y = lp.y + ( rad * sinf( angle ));
		}

		switch ([theEvent type])
		{
			case NSLeftMouseDown:
			{
				if ( phase == 0 )
				{
					// set radius as the distance from this click to the centre, and the
					// start angle based on the slope of this line
					
					radius = hypotf( p.x - centre.x, p.y - centre.y );
					startAngle = ( atan2f( p.y - centre.y, p.x - centre.x ) * 180.0 ) / pi;
					++phase;	// now setting the arc
				}
				else
					loop = NO;
			}
			break;
			
			case NSMouseMoved:
				[self notifyVisualChange];
				[view autoscroll:theEvent];
				if ( phase == 0 )
				{
					[path setControlPoint:p forPartcode:partcode];
					radius = hypotf( p.x - centre.x, p.y - centre.y );
					
					if([[self class] displaysSizeInfoWhenDragging])
					{			
						float rad = [[self drawing] convertLength:radius];
						p.x += 4;
						p.y -= 12;
						
						[[self layer] showInfoWindowWithString:[NSString stringWithFormat:@"radius: %.2f%@", rad, abbrUnits] atPoint:nsp];
					}
				}
				else if ( phase == 1 )
				{
					endAngle = ( atan2f( p.y - centre.y, p.x - centre.x ) * 180.0 ) / pi;
					
					[self setStyle:savedStyle];
					[path removeAllPoints];
					if ([self pathEditingMode] == kGCPathCreateModeWedgeSegment)
						[path moveToPoint:centre];
						
					[path appendBezierPathWithArcWithCenter:centre radius:radius startAngle:startAngle endAngle:endAngle];
					
					if ([self pathEditingMode] == kGCPathCreateModeWedgeSegment)
						[path closePath];
					[self setPath:path];

					if([[self class] displaysSizeInfoWhenDragging])
					{			
						float rad = [[self drawing] convertLength:radius];
						float angle = endAngle - startAngle;
						
						if ( angle < 0 )
							angle = 360.0 + angle;
							
						p.x += 4;
						p.y -= 12;
						
						[[self layer] showInfoWindowWithString:[NSString stringWithFormat:@"radius: %.2f%@\nangle: %.1f%C", rad, abbrUnits, angle, 0xB0] atPoint:nsp];
					}
				}
				break;
				
			case NSScrollWheel:
				[view scrollWheel:theEvent];
				break;
			
			default:
				break;
		}
		
		[self notifyVisualChange];
	}

	LogEvent_(kReactiveEvent, @"ending arc create loop");
	
	[self setPathEditingMode:kGCPathCreateModeEditExisting];
	[self setStyle:savedStyle];
	[savedStyle release];
	[self notifyVisualChange];

	[view mouseUp:theEvent];
}


#pragma mark -
///*********************************************************************************************************************
///
/// method:			shouldEndPathCreationWithEvent:
/// scope:			private instance method
/// overrides:		
/// description:	test for the ending criterion of a path loop
/// 
/// parameters:		<event> an event
/// result:			YES to end the loop, NO to continue
///
/// notes:			currently only checks for a double-click
///
///********************************************************************************************************************

- (BOOL)				shouldEndPathCreationWithEvent:(NSEvent*) event
{
	// determine if path creation loop should be terminated - can be overridden to terminate differently.
	
	if ([event type] == NSLeftMouseDown)
		return ([event clickCount] >= 2 );
	else
		return NO;
}


#pragma mark -
///*********************************************************************************************************************
///
/// method:			pathDeletePointWithPartCode:
/// scope:			protected instance method
/// overrides:		
/// description:	delete the point from the path with the given part code
/// 
/// parameters:		<pc> the partcode to delete
/// result:			YES if the point could be deleted, NO if not
///
/// notes:			only on-path points of a curve are allowed to be deleted, not control points. The partcodes will
///					be renumbered by this, so do not cache the partcode beyond this point.
///
///********************************************************************************************************************

- (BOOL)				pathDeletePointWithPartCode:(int) pc
{
	// delete the point with the given partcode
	
	if ( pc > kGCDrawingNoPart )
	{
		NSBezierPath* np = [[self path] deleteControlPointForPartcode:pc];
		
		if (np != [self path])
		{
			[self setPath:np];
			return YES;
		}
	}
	
	return NO;
}


///*********************************************************************************************************************
///
/// method:			pathInsertPointAt:ofType:
/// scope:			protected instance method
/// overrides:		
/// description:	insert a new point into the path
/// 
/// parameters:		<loc> the point at which to insert a point
///					<pathPointType> the type of point (curve or vertex) to insert
/// result:			the inserted point's new partcode, or 0 if the location was too far off the path.
///
/// notes:			the inserted point must be "close" to the path - within its drawn stroke in fact.
///
///********************************************************************************************************************

- (int)					pathInsertPointAt:(NSPoint) loc ofType:(int) pathPointType
{
	// insert a new point at the given location, returning the new point's partcode
	
	float tol = MAX( 4.0, [[self style] maxStrokeWidth]);
	
	NSBezierPath* np = [[self path] insertControlPointAtPoint:loc tolerance:tol type:pathPointType];
	
	if ( np != nil )
	{
		[self setPath:np];
		return [np partcodeHitByPoint:loc tolerance:tol];
	}

	return kGCDrawingNoPart;
}


#pragma mark -
///*********************************************************************************************************************
///
/// method:			setFreehandSmoothing:
/// scope:			public instance method
/// overrides:		
/// description:	set the smoothness of paths created in freehand mode
/// 
/// parameters:		<fs> a smoothness value
/// result:			none
///
/// notes:			the bigger the number, the smoother but less accurate the path. The value is the distance in
///					base units that a point has to be to the path to be considered a fit. Typical values are between 1 and 20
///
///********************************************************************************************************************

- (void)				setFreehandSmoothing:(float) fs
{
	m_freehandEpsilon = fs;
}


///*********************************************************************************************************************
///
/// method:			freehandSmoothing
/// scope:			public instance method
/// overrides:		
/// description:	get the smoothness valueof paths created in freehand mode
/// 
/// parameters:		none
/// result:			the smoothness value
///
/// notes:			
///
///********************************************************************************************************************

- (float)				freehandSmoothing
{
	return m_freehandEpsilon;
}


#pragma mark -
///*********************************************************************************************************************
///
/// method:			makeShape
/// scope:			public instance method
/// overrides:		
/// description:	make a copy of the path into a shape object
/// 
/// parameters:		none
/// result:			a DKDrawableShape object, identical to this
///
/// notes:			called by -convertToShape, a higher level operation
///
///********************************************************************************************************************

- (DKDrawableShape*)	makeShape
{
	// creates a new drawable shape objects using the path's path, location, etc. This should be performed on a closed path for best results. The
	// new shape appears identical but has different features, such as the ability to be scaled and rotated.

	NSBezierPath* mp = [[[self path] copy] autorelease];
	
	return [DKDrawableShape drawableShapeWithPath:mp];
}


#pragma mark -
#pragma mark - user level commands this object can respond to
///*********************************************************************************************************************
///
/// method:			convertToShape:
/// scope:			public action method
/// overrides:		
/// description:	converts this object to he equivalent shape
/// 
/// parameters:		<sender> the action's sender
/// result:			none
///
/// notes:			undoably replaces itself in its current layer by the equivalent shape object
///
///********************************************************************************************************************

- (IBAction)			convertToShape:(id) sender
{
	#pragma unused(sender)
	
	// replaces itself in the owning layer with a shape object with the same path.
	
	DKObjectDrawingLayer*	layer = (DKObjectDrawingLayer*)[self layer];
	int						myIndex = [layer indexOfObject:self];
	
	DKDrawableShape*		so = [self makeShape];
	
	[so setStyle:[self style]];
	[so setUserInfo:[self userInfo]];
	
	[layer recordSelectionForUndo];
	[layer addObject:so atIndex:myIndex];
	[layer replaceSelectionWithObject:so];
	[layer removeObject:self];
	[layer commitSelectionUndoWithActionName:NSLocalizedString(@"Convert To Shape", @"undo string for convert to shape")];
}


///*********************************************************************************************************************
///
/// method:			addRandomNoise:
/// scope:			public action method
/// overrides:		
/// description:	adds some random offset to every point on the path
/// 
/// parameters:		<sender> the action's sender
/// result:			none
///
/// notes:			just a fun effect
///
///********************************************************************************************************************

- (IBAction)			addRandomNoise:(id) sender
{
	#pragma unused(sender)
	
	// just for fun,this adds a little random offset to every control point on the path. For some paths (such as text) this produces
	// a fairly interesting effect.
	
	[self setPath: [[self path] bezierPathByRandomisingPoints:0.0f]];
	[[self undoManager] setActionName:NSLocalizedString(@"Add Randomness", @"undo string for path add random")];
}


///*********************************************************************************************************************
///
/// method:			convertToOutline:
/// scope:			public action method
/// overrides:		
/// description:	replaces the path with an outline of the path
/// 
/// parameters:		<sender> the action's sender
/// result:			none
///
/// notes:			the result depends on the style - specifically the maximum stroke width. The path is replaced by
///					a path whose edges are where the edge of the stroke of the original path lie. The topmost stroke
///					is used to set the fill of the resulting object's style. The result is similar but not always
///					identical to the original. For complex styles you will lose a lot of information.
///
///********************************************************************************************************************

- (IBAction)			convertToOutline:(id) sender
{
	#pragma unused(sender)
	
	NSBezierPath* path = [self path];
	
	float sw = [[self style] maxStrokeWidthDifference] / 2.0;
	[[self style] applyStrokeAttributesToPath:path];
	
	if ( sw > 0.0 )
		[path setLineWidth:[path lineWidth] - sw];
	
	path = [path strokedPath];
	[self setPath:path];
	
	// try to keep the appearance similar by creating a fill style with the same colour as the original's stroke
	
	NSArray* rs = [[self style] renderersOfClass:[DKStroke class]];
	if ([rs count] > 0 )
	{
		DKStroke*	stroke = [rs lastObject];
		DKStroke*	firstStroke = [rs objectAtIndex:0];
		NSColor*	strokeColour = nil;
		
		if ( firstStroke != stroke )
			strokeColour = [firstStroke colour];
		
		DKStyle* newStyle = [DKStyle styleWithFillColour:[stroke colour] strokeColour:strokeColour];
		
		stroke = [[newStyle renderersOfClass:[DKStroke class]] lastObject];
		
		if ( stroke )
			[stroke setWidth:sw];

		[self setStyle:newStyle];
	}
	
	[[self undoManager] setActionName:NSLocalizedString(@"Convert To Outline", @"undo string for convert to outline")];
}


///*********************************************************************************************************************
///
/// method:			breakApart:
/// scope:			public action method
/// overrides:		
/// description:	replaces the object with new objects, one for each subpath in the original
/// 
/// parameters:		<sender> the action's sender
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (IBAction)			breakApart:(id) sender
{
	#pragma unused(sender)
	
	NSArray* broken = [self breakApart];
	
	DKObjectDrawingLayer* odl = (DKObjectDrawingLayer*)[self layer];
	
	if ( odl && [broken count] > 1 )
	{
		[odl recordSelectionForUndo];
		[odl addObjects:broken];
		[odl removeObject:self];
		[odl exchangeSelectionWithObjectsInArray:broken];
		[odl commitSelectionUndoWithActionName:NSLocalizedString(@"Break Apart", @"undo string for break apart")];
	}
}


- (IBAction)			roughenPath:(id) sender
{
	#pragma unused(sender)
	
	NSBezierPath* path = [self path];
	
	float sw = [[self style] maxStrokeWidthDifference] / 2.0;
	[[self style] applyStrokeAttributesToPath:path];
	
	if ( sw > 0.0 )
		[path setLineWidth:[path lineWidth] - sw];
		
	float roughness = [[self style] maxStrokeWidth] / 4.0;
	
	path = [path bezierPathWithRoughenedStrokeOutline:roughness];
	[self setPath:path];
	
	// try to keep the appearance similar by creating a fill style with the same colour as the original's stroke
	
	NSArray* rs = [[self style] renderersOfClass:[DKStroke class]];
	if ([rs count] > 0 )
	{
		DKStroke*	stroke = [rs lastObject];
		DKStroke*	firstStroke = [rs objectAtIndex:0];
		NSColor*	strokeColour = nil;
		
		if ( firstStroke != stroke )
			strokeColour = [firstStroke colour];
		
		DKStyle* newStyle = [DKStyle styleWithFillColour:[stroke colour] strokeColour:strokeColour];
		
		stroke = [[newStyle renderersOfClass:[DKStroke class]] lastObject];
		
		if ( stroke )
			[stroke setWidth:sw];

		[self setStyle:newStyle];
	}
	
	[[self undoManager] setActionName:NSLocalizedString(@"Roughen Path", @"undo string for roughen path")];
}


#ifdef qUseCurveFit
///*********************************************************************************************************************
///
/// method:			smoothPath:
/// scope:			public action method
/// overrides:		
/// description:	tries to smooth a path by curve fitting. If the path is already made up from bezier elements,
///					this will have no effect. vector paths can benefit however.
/// 
/// parameters:		<sender> the action's sender
/// result:			none
///
/// notes:			the current set smoothness value is used
///
///********************************************************************************************************************

- (IBAction)			smoothPath:(id) sender
{
	#pragma unused(sender)
	
	//NSBezierPath* temp = [[self path] bezierPathByFlatteningPath];
	
	[self setPath:smartCurveFitPath( [self path], [self freehandSmoothing], 1.0 )];
	[[self undoManager] setActionName:NSLocalizedString(@"Smooth Path", @"smooth path action name")];
}


///*********************************************************************************************************************
///
/// method:			smoothPathMore:
/// scope:			public action method
/// overrides:		
/// description:	tries to smooth a path by curve fitting. If the path is already made up from bezier elements,
///					this will have no effect. vector paths can benefit however.
/// 
/// parameters:		<sender> the action's sender
/// result:			none
///
/// notes:			the current set smoothness value x4 is used
///
///********************************************************************************************************************

- (IBAction)			smoothPathMore:(id) sender
{
	#pragma unused(sender)
	
	[self setPath:smartCurveFitPath( [self path], [self freehandSmoothing] * 4.0, 1.2 )];
	[[self undoManager] setActionName:NSLocalizedString(@"Smooth More", @"smooth more action name")];
}
#endif /* defined(qUseCurveFit) */


///*********************************************************************************************************************
///
/// method:			parallelCopy:
/// scope:			public action method
/// overrides:		
/// description:	adds a copy of the receiver to the drawing with a parallel offset path
/// 
/// parameters:		<sender> the action's sender
/// result:			none
///
/// notes:			this is really just a test of the algorithm
///
///********************************************************************************************************************

- (IBAction)			parallelCopy:(id) sender
{
	#pragma unused(sender)
	
	DKDrawablePath*		newPath = [self copy];
	
	float delta = 30.0; //[[[self drawing] gridLayer] nearestGridIntegralToSize:NSMakeSize( 30, 30 )];
	
	[newPath setPath:[[self path] paralleloidPathWithOffset2:delta]];
	
	DKObjectDrawingLayer* odl = (DKObjectDrawingLayer*)[self layer];
	
	if ( odl )
	{
		[odl recordSelectionForUndo];
		[odl addObject:newPath];
		[odl exchangeSelectionWithObjectsInArray:[NSArray arrayWithObject:newPath]];
		[odl commitSelectionUndoWithActionName:NSLocalizedString(@"Parallel Copy", @"undo string for parallel copy")];
	}
	
	[newPath release];
}


///*********************************************************************************************************************
///
/// method:			toggleHorizontalFlip:
/// scope:			public action method
/// overrides:		
/// description:	flips the path horizontally
/// 
/// parameters:		<sender> the action's sender
/// result:			none
///
/// notes:			the path is flipped directly
///
///********************************************************************************************************************

- (IBAction)			toggleHorizontalFlip:(id) sender
{
	#pragma unused(sender)
	
	NSPoint cp;
	
	cp.x = NSMidX([self bounds]);
	cp.y = NSMidY([self bounds]);
	
	NSBezierPath* np = [[self path] horizontallyFlippedPathAboutPoint:cp];
	
	NSAssert( np != nil, @"bad path when flipping");
	
	[self setPath:np];
	[[self undoManager] setActionName:NSLocalizedString(@"Flip Horizontally", @"h flip")];
}


///*********************************************************************************************************************
///
/// method:			toggleVerticalFlip:
/// scope:			public action method
/// overrides:		
/// description:	flips the path vertically
/// 
/// parameters:		<sender> the action's sender
/// result:			none
///
/// notes:			the path is flipped directly
///
///********************************************************************************************************************

- (IBAction)			toggleVerticalFlip:(id) sender
{
	#pragma unused(sender)

	NSPoint cp;
	
	cp.x = NSMidX([self bounds]);
	cp.y = NSMidY([self bounds]);
	
	NSBezierPath* np = [[self path] verticallyFlippedPathAboutPoint:cp];
	
	NSAssert( np != nil, @"bad path when flipping");

	[self setPath:np];
	[[self undoManager] setActionName:NSLocalizedString(@"Flip Vertically", @"v flip")];
}


#pragma mark -
#pragma mark As a DKDrawableObject

///*********************************************************************************************************************
///
/// method:			initialPartcodeForObjectCreation
/// scope:			public class method
/// overrides:
/// description:	return the partcode that should be used by tools when initially creating a new object
/// 
/// parameters:		none
/// result:			a partcode value - since paths start empty the 'no part' partcode is returned
///
/// notes:			The client of this method is DKObjectCreationTool.
///
///********************************************************************************************************************

+ (int)					initialPartcodeForObjectCreation
{
	return kGCDrawingNoPart;
}



+ (NSArray*)			pasteboardTypesForOperation:(DKPasteboardOperationType) op
{
	#pragma unused(op)
	return [NSArray arrayWithObjects:NSColorPboardType, NSStringPboardType, NSPDFPboardType, NSTIFFPboardType, NSFilenamesPboardType, nil];
}


///*********************************************************************************************************************
///
/// method:			apparentBounds
/// scope:			public instance method
/// overrides:		DKDrawableObject
/// description:	returns the apparent (visual) bounds of the object
/// 
/// parameters:		none
/// result:			a rectangle bounding the object
///
/// notes:			bounds is derived from the path directly
///
///********************************************************************************************************************

- (NSRect)			apparentBounds
{
	NSRect r = [[self renderingPath] bounds];
	
	if([self style])
	{
		NSSize allow = [[self style] extraSpaceNeeded];
		r = NSInsetRect( r, -allow.width, -allow.height );
	}
	return r;
}


///*********************************************************************************************************************
///
/// method:			bounds
/// scope:			public instance method
/// overrides:		DKDrawableObject
/// description:	returns the bounds of the object
/// 
/// parameters:		none
/// result:			a rectangle bounding the object
///
/// notes:			bounds is derived from the path directly
///
///********************************************************************************************************************

- (NSRect)			bounds
{
	NSRect	r = NSInsetRect( [[self renderingPath] controlPointBounds], -3, -3 );
	
	// factor in style allowance
	
	NSSize allow = [self extraSpaceNeeded];
	r = NSInsetRect( r, -allow.width, -allow.height );

	return r;
}


///*********************************************************************************************************************
///
/// method:			drawSelectedState
/// scope:			public instance method
/// overrides:		DKDrawableObject
/// description:	draws the seleciton highlight on the object when requested
/// 
/// parameters:		none
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)			drawSelectedState
{
	// stroke the path using the standard selection
	
	NSBezierPath* path = [self renderingPath];
	
	[self drawSelectionPath:path];
	[self drawControlPointsOfPath:path usingKnobs:[[self layer] knobs]];
	
#ifdef qIncludeGraphicDebugging
	if ( m_showBBox )
		[[self path] drawElementsBoundingBoxes];

#endif
}


///*********************************************************************************************************************
///
/// method:			hitPart:
/// scope:			public instance method
/// overrides:		DKDrawableObject
/// description:	determines the partcode hit by a given point
/// 
/// parameters:		<pt> a point
/// result:			an integer value, the partcode hit.
///
/// notes:			partcodes apart from 0 and -1 are private to this object
///
///********************************************************************************************************************

- (int)				hitPart:(NSPoint) pt
{
	int pc = [super hitPart:pt];
	
	if ( pc == kGCDrawingEntireObjectPart )
	{
		// hit in bounds, refine by testing against controls/bitmap
		// if we have a fill, test for path contains as well:

		if([[self style] hasFill])
		{
			if ([[self path] containsPoint:pt])
				return kGCDrawingEntireObjectPart;
		}

		if ([self pointHitsPath:pt])
			return kGCDrawingEntireObjectPart;
		
		// nothing was hit:
				
		pc = kGCDrawingNoPart;
	}
	return pc;
}


///*********************************************************************************************************************
///
/// method:			hitSelectedPart:forSnapDetection:
/// scope:			protected instance method
/// overrides:		DKDrawableObject
/// description:	determines the partcode hit by a given point
/// 
/// parameters:		<pt> a point
///					<snap> YES if being called to determine snapping to the object, NO for normal mouse click
/// result:			an integer value, the partcode hit.
///
/// notes:			partcodes apart from 0 and -1 are private to this object
///
///********************************************************************************************************************

- (int)				hitSelectedPart:(NSPoint) pt forSnapDetection:(BOOL) snap
{
	float	tol = [[[self layer] knobs] controlKnobSize].width;
	
	if( snap )
		tol *= 2;
		
	int		pc;
	
	pc = [[self path] partcodeHitByPoint:pt tolerance:tol];
	
	if ( pc == 0 )
	{
		pc = kGCDrawingEntireObjectPart;
	
		if ( snap )
		{
			// for snapping to the nearest point on the path, return a special partcode value and cache the mouse point -
			// when pointForPartcode is called with this special code, locate the nearest path point and return it.
			
			if ([self pointHitsPath:pt])
			{
				sMouseForPathSnap = pt;
				pc = kGCSnapToNearestPathPointPartcode;
			}
		}
	}
	return pc;
}


///*********************************************************************************************************************
///
/// method:			logicalBounds
/// scope:			public instance method
/// overrides:		DKDrawableObject
/// description:	returns the logical bounds of the object
/// 
/// parameters:		none
/// result:			a rectangle bounding the object ignoring any style attributes
///
/// notes:			bounds is derived from the path directly
///
///********************************************************************************************************************

- (NSRect)			logicalBounds
{
	return [[self path] bounds];
}


///*********************************************************************************************************************
///
/// method:			mouseDoubleClickedAtPoint:inPart:event:
/// scope:			public instance method
/// overrides:		DKDrawableObject
/// description:	double-click in path
/// 
/// parameters:		<mp> the mouse point
///					<partcode> the part that was hit
///					<evt> the original event
/// result:			none
///
/// notes:			this is a shortcut for convert to shape, making quickly switching between the two representations
///					more than easy. Maybe too easy - might remove for public release.
///
///********************************************************************************************************************

- (void)				mouseDoubleClickedAtPoint:(NSPoint) mp inPart:(int) partcode event:(NSEvent*) evt
{
	#pragma unused(mp)
	#pragma unused(partcode)
	#pragma unused(evt)
	
	//[self convertToShape:self];
}


///*********************************************************************************************************************
///
/// method:			mouseDownAtPoint:inPart:event:
/// scope:			protected instance method
/// overrides:		DKDrawableObject
/// description:	handles a mouse down in the object
/// 
/// parameters:		<mp> the mouse point
///					<partcode> the partcode returned earlier by hitPart:
///					<evt> the event this came from
/// result:			none
///
/// notes:			this is used mainly to grab the mousedown and start our internal creation loops according to
///					which edit mode is set for the object.
///
///********************************************************************************************************************

- (void)				mouseDownAtPoint:(NSPoint) mp inPart:(int) partcode event:(NSEvent*) evt
{
	m_inMouseOp = YES;
	int mode = [self pathEditingMode];
	
	if (( partcode == kGCDrawingNoPart ) && ( mode != kGCPathCreateModeEditExisting ))
	{
		// these loops keep control until their logic dictates otherwise, so the other
		// mouse event handler methods won't be called
		
		switch( mode )
		{
			case kGCPathCreateModeLineCreate:
				[self lineCreateLoop:mp];
				break;
				
			case kGCPathCreateModeBezierCreate:
				[self pathCreateLoop:mp];
				break;
				
			case kGCPathCreateModePolygonCreate:
				[self polyCreateLoop:mp];
				break;
#ifdef qUseCurveFit
			case kGCPathCreateModeFreehandCreate:
			{
				float savedFHE = [self freehandSmoothing];
				
				BOOL option = ([evt modifierFlags] & NSAlternateKeyMask) != 0;
				
				if ( option )
					[self setFreehandSmoothing:10 * savedFHE];
					
				[self freehandCreateLoop:mp];
				[self setFreehandSmoothing:savedFHE];
			}
			break;
#endif
			case kGCPathCreateModeWedgeSegment:
			case kGCPathCreateModeArcSegment:
				[self arcCreateLoop:mp];
				break;
				
			default:
				break;
		}
	}
	else
	{
		if ( partcode == kGCDrawingEntireObjectPart )
			[super mouseDownAtPoint:mp inPart:partcode event:evt];
		else
		{
			sPathForUndo = [[self path] copy];
			m_mouseEverMoved = NO;
		}
	}
	
	[[self layer] setInfoWindowBackgroundColour:sInfoWindowColour];
}


///*********************************************************************************************************************
///
/// method:			mouseDraggedAtPoint:inPart:event:
/// scope:			protected instance method
/// overrides:		DKDrawableObject
/// description:	handles a mouse drag in the object
/// 
/// parameters:		<mp> the mouse point
///					<partcode> the partcode returned earlier by hitPart:
///					<evt> the event this came from
/// result:			none
///
/// notes:			used when editing an existing path, but not creating one
///
///********************************************************************************************************************

- (void)				mouseDraggedAtPoint:(NSPoint) mp inPart:(int) partcode event:(NSEvent*) evt
{
	if (partcode == kGCDrawingEntireObjectPart )
	{
		[super mouseDraggedAtPoint:mp inPart:partcode event:evt];
	}
	else
	{
		BOOL option = (([evt modifierFlags] & NSAlternateKeyMask ) != 0 );
		BOOL cmd	= (([evt modifierFlags] & NSCommandKeyMask ) != 0 );
		BOOL shift	= (([evt modifierFlags] & NSShiftKeyMask ) != 0 );
		BOOL ctrl	= (([evt modifierFlags] & NSControlKeyMask ) != 0 );
		
		// modifier keys change the editing of path control points thus:
		
		// +shift	- constrains curve control point angles to 15¡ intervals
		// +option	- forces the control points either side of an on-path point to maintain the same radial distance
		// +cmd		- allows control points to be moved fully independently
		// +ctrl	- temporarily disables snap to grid
		
		mp = [self snappedMousePoint:mp withControlFlag:ctrl];
		
		// optimization - instead of invalidating entire bounds, just invalidate the elements affected
		
		//[self notifyVisualChange];
		[self setNeedsDisplayForRects:[[self path] boundingBoxesForPartcode:partcode]];
		
		[[self path] moveControlPointPartcode:partcode toPoint:mp colinear:!cmd coradial:option constrainAngle:shift];
		
		//[self notifyVisualChange];
		[self setNeedsDisplayForRects:[[self path] boundingBoxesForPartcode:partcode]];
		
		// if the class is set to show size info when resizing, set up an info window now to do that.
			
		if([[self class] displaysSizeInfoWhenDragging])
		{			
			NSPoint		gridPt = [self convertPointToDrawing:mp];
			NSString*	abbrUnits = [[self drawing] abbreviatedDrawingUnits];
			
			[[self layer] showInfoWindowWithString:[NSString stringWithFormat:@"x: %.2f%@\ny: %.2f%@", gridPt.x, abbrUnits, gridPt.y, abbrUnits] atPoint:mp];
		}
		
		m_mouseEverMoved = YES;
	}
}


///*********************************************************************************************************************
///
/// method:			mouseUpAtPoint:inPart:event:
/// scope:			protected instance method
/// overrides:		DKDrawableObject
/// description:	handles a mouseup in the object
/// 
/// parameters:		<mp> the mouse point
///					<partcode> the partcode returned earlier by hitPart:
///					<evt> the event this came from
/// result:			none
///
/// notes:			used when editing an existing path, but not creating one
///
///********************************************************************************************************************

- (void)				mouseUpAtPoint:(NSPoint) mp inPart:(int) partcode event:(NSEvent*) evt
{
	if ( partcode == kGCDrawingEntireObjectPart )
		[super mouseUpAtPoint:mp inPart:partcode event:evt];
	else
	{
		if ( sPathForUndo != nil )
		{
			if ( m_mouseEverMoved)
			{
				[[self undoManager] registerUndoWithTarget:self selector:@selector(setPath:) object:sPathForUndo];
				[[self undoManager] setActionName:NSLocalizedString( @"Change Path", @"undo string for change path")];
			}
			[sPathForUndo release];
			sPathForUndo = nil;
		}
	}
	[[self layer] hideInfoWindow];
	m_inMouseOp = NO;
}


///*********************************************************************************************************************
///
/// method:			moveByX:byY:
/// scope:			public instance method
/// overrides:		DKDrawableObject
/// description:	offsets the object to a new location
/// 
/// parameters:		<dx, dy> offset values in x and y direction from current location
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)			moveByX:(float) dx byY:(float) dy
{
	if ( dx != 0.0 || dy != 0.0 )
	{
		[self notifyVisualChange];
		[[[self undoManager] prepareWithInvocationTarget:self] moveToPoint:[self location]];
		
		NSAffineTransform* tfm = [NSAffineTransform transform];
		[tfm translateXBy:dx yBy:dy];
		
		[[self path] transformUsingAffineTransform:tfm];
		[self notifyVisualChange];
	}
}


///*********************************************************************************************************************
///
/// method:			moveToPoint:
/// scope:			public instance method
/// overrides:		DKDrawableObject
/// description:	moves the object to a new locaiton
/// 
/// parameters:		<p> the new location
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)			moveToPoint:(NSPoint) p
{
	float	dx, dy;

	dx = p.x - [self location].x;
	dy = p.y - [self location].y;
	
	[self moveByX:dx byY:dy];
}


///*********************************************************************************************************************
///
/// method:			pointForPartcode:
/// scope:			protected instance method
/// overrides:		DKDrawableObject
/// description:	given a partcode, this returns the current value of the associated point
/// 
/// parameters:		<pc> an integer - the private partcode
/// result:			a point - the location of the partcode.
///
/// notes:			partcodes apart from 0 and -1 are private to this object
///
///********************************************************************************************************************

- (NSPoint)			pointForPartcode:(int) pc
{
	if ( pc != kGCDrawingNoPart && pc != kGCDrawingEntireObjectPart )
	{
		if ( pc == kGCSnapToNearestPathPointPartcode )
		{
			// snapping to the nearest path point
			
			return [[self path] nearestPointToPoint:sMouseForPathSnap tolerance:4];
		}
		else
			return [[self path] controlPointForPartcode:pc];
	}
	else
		return [super pointForPartcode:pc];
}


///*********************************************************************************************************************
///
/// method:			populateContextualMenu
/// scope:			public instance method
/// overrides:		DKDrawableObject
/// description:	populate the menu with commands pertaining to this object
/// 
/// parameters:		<theMenu> the menu to populate
/// result:			YES
///
/// notes:			
///
///********************************************************************************************************************

- (BOOL)				populateContextualMenu:(NSMenu*) theMenu
{
	// if the object supports any contextual menu commands, it should add them to the menu and return YES. If subclassing,
	// you should call the inherited method first so that the menu is the union of all the ancestor's added methods.
	
	[[theMenu addItemWithTitle:NSLocalizedString(@"Convert To Shape", @"menu item for convert to shape") action:@selector( convertToShape: ) keyEquivalent:@""] setTarget:self];
	[theMenu addItem:[NSMenuItem separatorItem]];
	
	[super populateContextualMenu:theMenu];
	return YES;
}


///*********************************************************************************************************************
///
/// method:			renderingPath
/// scope:			public instance method
/// overrides:		DKDrawableObject
/// description:	returns the actual path drawn when the object is rendered
/// 
/// parameters:		none
/// result:			a NSBezierPath object, transformed according to its parents (groups for example)
///
/// notes:			this is part of the style rendering protocol
///
///********************************************************************************************************************

- (NSBezierPath*)	renderingPath
{
	NSBezierPath* rPath = [self path];
	NSAffineTransform* parentTransform = [self containerTransform];
	
	if ( parentTransform )
		rPath = [parentTransform transformBezierPath:[self path]];
		
	// if drawing is in low quality mode, set a coarse flatness value:
	
	if([[self drawing] lowRenderingQuality])
		[rPath setFlatness:5.0];
	else
		[rPath setFlatness:0.5];
		
	return rPath;
}


///*********************************************************************************************************************
///
/// method:			rotateToAngle:
/// scope:			public instance method
/// overrides:		DKDrawableObject
/// description:	rotates the path to the given angle
/// 
/// parameters:		<angle> the angle in radians
/// result:			none
///
/// notes:			paths are not rotatable like shapes, but in special circumstances you may want to rotate the path
///					in place. This will do that. The bounds remains aligned orthogonally. Note that asking for the path's
///					angle will always return 0.
///
///********************************************************************************************************************

- (void)			rotateToAngle:(float) angle
{
	NSAffineTransform*	tfm = [NSAffineTransform transform];
	NSPoint				loc = [self location];
	
	[tfm translateXBy:-loc.x yBy:-loc.y];

	NSAffineTransform*	t2 = [NSAffineTransform transform];
	[t2 rotateByRadians:angle];
	[tfm appendTransform:t2];
	
	NSAffineTransform*	t3 = [NSAffineTransform transform];
	[t3 translateXBy:loc.x yBy:loc.y];
	[tfm appendTransform:t3];
	
	NSBezierPath* temp = [tfm transformBezierPath:[self path]];
	[self setPath:temp];
}


///*********************************************************************************************************************
///
/// method:			snappingPointsWithOffset:
/// scope:			public action method
/// overrides:		DKDrawableObject
/// description:	returns a list of potential snapping points used when the path is snapped to the grid or guides
/// 
/// parameters:		<offset> add this offset to the points
/// result:			an array of points as NSValue objects
///
/// notes:			part of the snapping protocol
///
///********************************************************************************************************************

- (NSArray*)			snappingPointsWithOffset:(NSSize) offset
{
	// utility method mainly for the purpose of snapping to guides - returns an array of the on-path points as values
	// with the offset added to them. This can subsequently be tested for guide snaps and used to return a mouse offset.

	NSMutableArray*			pts;
	NSPoint					a[3];
	int						i, el = [[self path] elementCount];
	NSBezierPathElement		elem;
	
	pts = [[NSMutableArray alloc] init];
	
	for( i = 0; i < el; ++i )
	{
		elem = [[self path] elementAtIndex:i associatedPoints:a];
		
		if ( elem == NSCurveToBezierPathElement )
		{
			a[2].x += offset.width;
			a[2].y += offset.height;
			[pts addObject:[NSValue valueWithPoint:a[2]]];
		}
		else
		{
			a[0].x += offset.width;
			a[0].y += offset.height;
			[pts addObject:[NSValue valueWithPoint:a[0]]];
		}
	}
	
	return [pts autorelease];
}


///*********************************************************************************************************************
///
/// method:			notifyVisualChange
/// scope:			public instance method
/// overrides:		DKDrawableObject
/// description:	sets the path's bounds to be updated
/// 
/// parameters:		none
/// result:			none
///
/// notes:			this optimizes the update to the individual element bounding rects rather than the entire bounding
///					rect which can help a lot when there are many other objects close to the path (within its bounds
///					but outside the element bounds).
///
///********************************************************************************************************************

- (void)			notifyVisualChange
{
	[self setNeedsDisplayForRects:[[self renderingPath] allBoundingBoxes]];
}


///*********************************************************************************************************************
///
/// method:			objectIsValid
/// scope:			public instance method
/// overrides:		DKDrawableObject
/// description:	return whether the object was valid following creation
/// 
/// parameters:		none
/// result:			YES if usable and valid
///
/// notes:			see DKDrawableObject
///
///********************************************************************************************************************

- (BOOL)				objectIsValid
{
	// paths are invalid if their length is zero or there is no path or the path is empty.
	
	BOOL valid;
	
	valid = ([self path] != nil && ![[self path] isEmpty] && [[self path] length] > 0.0);
	
	return valid;
}


- (NSSize)				size
{
	return [[self path] bounds].size;
}



#pragma mark -
#pragma mark As an NSObject
- (void)			dealloc
{
	[m_path release];
	[super dealloc];
}


- (id)				init
{
	self = [super init];
	if (self != nil)
	{
		NSAssert(m_path == nil, @"Expected init to zero");
		NSAssert(m_editPathMode == kGCPathCreateModeEditExisting, @"Expected init to zero");
		m_freehandEpsilon = 2.0;
	}
	if (self != nil)
	{
		// the default style is set to the default track style
		
		//[self setStyle:[DKStyle defaultStyle]];
		[self setStyle:[DKStyle defaultTrackStyle]];
	}
	
	return self;
}


#pragma mark -
#pragma mark As part of NSCoding Protocol
- (void)			encodeWithCoder:(NSCoder*) coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	[super encodeWithCoder:coder];
	
	[coder encodeObject:[self path] forKey:@"path"];
	[coder encodeFloat:m_freehandEpsilon forKey:@"freehand_smoothing"];
}


- (id)				initWithCoder:(NSCoder*) coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	self = [super initWithCoder:coder];
	if (self != nil)
	{
		[self setPath:[coder decodeObjectForKey:@"path"]];
		NSAssert(m_editPathMode == kGCPathCreateModeEditExisting, @"Expected init to zero");
		m_freehandEpsilon = [coder decodeFloatForKey:@"freehand_smoothing"];
	}
	return self;
}


#pragma mark -
#pragma mark As part of NSCopying Protocol
- (id)				copyWithZone:(NSZone*) zone
{
	DKDrawablePath* copy = [super copyWithZone:zone];
	NSBezierPath*	pc = [[self path] copyWithZone:zone];
	
	[copy setPath:pc];
	[pc release];

	[copy setPathEditingMode:[self pathEditingMode]];
	
	return copy;
}


#pragma mark -
#pragma mark As part of NSDraggingDestination protocol

- (BOOL)				performDragOperation:(id <NSDraggingInfo>) sender
{
	// this is called when the owning layer permits it, and the drag pasteboard contains a type that matches the class's
	// pasteboardTypesForOperation result. Generally at this point the object should simply handle the drop.
	
	// default behaviour is to derive a style from the current style.
		
	DKStyle* newStyle = [[self style] derivedStyleWithPasteboard:[sender draggingPasteboard] withOptions:kDKDerivedStyleForPathHint];
	
	if ( newStyle != nil && newStyle != [self style])
	{
		[self setStyle:newStyle];
		[[self undoManager] setActionName:NSLocalizedString(@"Drop Property", @"undo string for drop colour onto shape")];
		
		return YES;
	}
	
	return NO;
}


#pragma mark -
#pragma mark As part of NSMenuValidation Protocol
- (BOOL)				validateMenuItem:(NSMenuItem*) item
{
	BOOL enable = NO;
	SEL	action = [item action];
	
	if ( action == @selector( convertToOutline: ) ||
		 action == @selector( roughenPath: ))
		enable = ![self locked] && [[self style] hasStroke];
	else if ( action == @selector( breakApart: ))
		enable = ![self locked] && [[self path] countSubPaths] > 1;
	else if ( action == @selector( convertToShape: ) ||
				action == @selector( addRandomNoise: ) ||
				action == @selector( smoothPath: ) ||
				action == @selector( parallelCopy: ) ||
				action == @selector( smoothPathMore: ) ||
				action == @selector( toggleHorizontalFlip: ) ||
				action == @selector( toggleVerticalFlip: ))
		enable = ![self locked];
	
	enable |= [super validateMenuItem:item];
	
	return enable;
}


@end
