//
//  DKDrawablePath.m
///  DrawKit ¬¨¬®¬¨¬©2005-2008 Apptree.net
//
//  Created by graham on 10/09/2006.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
//

#import "DKDrawablePath.h"
#import "DKShapeGroup.h"
#import "DKDrawing.h"
#import "DKStyle.h"
#import "DKKnob.h"
#import "DKObjectDrawingLayer.h"
#import "DKStroke.h"
#import "NSBezierPath+Editing.h"
#import "NSBezierPath+Geometry.h"
#import "NSBezierPath+GPC.h"
#import "GCInfoFloater.h"
#import "CurveFit.h"
#import "LogEvent.h"


#pragma mark Global Vars
NSPoint			gMouseForPathSnap = {0,0};

NSString*		kDKPathOnPathHitDetectionPriorityDefaultsKey = @"kDKPathOnPathHitDetectionPriority";


#pragma mark Static Vars
static CGFloat			sAngleConstraint = 0.261799387799;	// 15 degrees
static NSColor*			sInfoWindowColour = nil;


@interface DKDrawablePath (Private)

- (void)		showLengthInfo:(CGFloat) dist atPoint:(NSPoint) p;

@end

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

+ (DKDrawablePath*)		drawablePathWithBezierPath:(NSBezierPath*) path
{
	DKDrawablePath* dp = [[self alloc] initWithBezierPath:path];
	
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

+ (DKDrawablePath*)		drawablePathWithBezierPath:(NSBezierPath*) path withStyle:(DKStyle*) aStyle
{
	DKDrawablePath* dp = [[self alloc] initWithBezierPath:path style:aStyle];
	return [dp autorelease];
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


//*********************************************************************************************************************
///
/// method:			infoWindowBackgroundColour:
/// scope:			public class method
/// overrides:		
/// description:	return the background colour to use for the info window displayed when interacting with paths
/// 
/// parameters:		none 
/// result:			the colour to use
///
/// notes:			
///
///********************************************************************************************************************

+ (NSColor*)			infoWindowBackgroundColour
{
	return sInfoWindowColour;
}


//*********************************************************************************************************************
///
/// method:			setDefaultOnPathHitDetectionPriority:
/// scope:			public class method
/// overrides:		
/// description:	set whether the default hit-detection behaviour is to prioritise on-path points or off-path points
/// 
/// parameters:		<priority> if YES, on-path points have priority by default. 
/// result:			none
///
/// notes:			Affects hit-detection when on-path and off-path points are coincident. Normally off-path points
///					have priority, but an alternative approach is to have on-path points have priority, and the off-path
///					points require the use of the command modifier key to be hit-detected. DK has previously always
///					prioritised off-path points, but this setting allows you to change that for your app.
///
///********************************************************************************************************************

+ (void)				setDefaultOnPathHitDetectionPriority:(BOOL) priority
{
	[[NSUserDefaults standardUserDefaults] setBool:priority forKey:kDKPathOnPathHitDetectionPriorityDefaultsKey];
}


//*********************************************************************************************************************
///
/// method:			defaultOnPathHitDetectionPriority:
/// scope:			public class method
/// overrides:		
/// description:	returns whether the default hit-detection behaviour is to prioritise on-path points or off-path points
/// 
/// parameters:		none
/// result:			if YES, on-path points have priority by default
///
/// notes:			Affects hit-detection when on-path and off-path points are coincident. Normally off-path points
///					have priority, but an alternative approach is to have on-path points have priority, and the off-path
///					points require the use of the command modifier key to be hit-detected. DK has previously always
///					prioritised off-path points, but this setting allows you to change that for your app.
///
///********************************************************************************************************************

+ (BOOL)				defaultOnPathHitDetectionPriority
{
	return [[NSUserDefaults standardUserDefaults] boolForKey:kDKPathOnPathHitDetectionPriorityDefaultsKey];
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


///*********************************************************************************************************************
///
/// method:			initWithPath:style:
/// scope:			public instance method
/// overrides:		
/// description:	initialises a drawable path object from an existing path with the given style
/// 
/// parameters:		<aPath> the path to use
///					<aStyle> the style to use
/// result:			the drawable path object
///
/// notes:			the path is retained, not copied
///
///********************************************************************************************************************

- (id)					initWithBezierPath:(NSBezierPath*) aPath style:(DKStyle*) aStyle
{
	self = [self initWithStyle:aStyle];
	if( self )
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
		
		NSRect oldBounds = [self bounds];
		
		[self notifyVisualChange];
		
		NSBezierPath* oldPath = [m_path copy];
		[[self undoManager] registerUndoWithTarget:self selector:@selector(setPath:) object:oldPath];
		[oldPath release];
		
		[m_path release];
		m_path = [path retain];
		
		[self notifyVisualChange];
		[self notifyGeometryChange:oldBounds];
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
	
	NSInteger i, ec = [path elementCount];
	lp = NSMakePoint( -1, -1 );
	
	for( i = 0; i < ec; ++i )
	{
		et = [path elementAtIndex:i associatedPoints:ap];
		
		if ( et == NSCurveToBezierPathElement )
		{
			// three points to draw, plus some bars. If the on-path point priority is set, draw on-path points on top,
			// otherwise draw off-path points on top.
			
			// draw the bar - always behind the knobs whatever the priority
			
			if( ![self locked])
				[knobs drawControlBarFromPoint:ap[1] toPoint:ap[2]];
			
			// draw on-path point behind
			
			if(![[self class] defaultOnPathHitDetectionPriority])
			{
				knobType = kDKOnPathKnobType;
				
				if( !NSEqualPoints( lp, NSMakePoint( -1, -1 )))
				{
					if ([self locked])
						knobType |= kDKKnobIsDisabledFlag;
					else
						[knobs drawControlBarFromPoint:ap[0] toPoint:lp];
					
					[knobs drawKnobAtPoint:lp ofType:knobType userInfo:nil];

					if( i == ec - 1 )
						[knobs drawKnobAtPoint:ap[2] ofType:knobType userInfo:nil];
				}
			}
			
			// draw off-path points for unlocked paths
			
			knobType = kDKControlPointKnobType;
	
			if (![self locked])
			{
				[knobs drawKnobAtPoint:ap[0] ofType:knobType userInfo:nil];
				[knobs drawKnobAtPoint:ap[1] ofType:knobType userInfo:nil];
			}
			
			knobType = kDKOnPathKnobType;
			if ([self locked])
				knobType |= kDKKnobIsDisabledFlag;

			// draw on-path point in front
			
			if ([[self class] defaultOnPathHitDetectionPriority])
			{
				if( !NSEqualPoints( lp, NSMakePoint( -1, -1 )))
				{
					if (![self locked])
						[knobs drawControlBarFromPoint:ap[0] toPoint:lp];
					
					[knobs drawKnobAtPoint:lp ofType:knobType userInfo:nil];
				}
				
				if( i == ec - 1 )
					[knobs drawKnobAtPoint:ap[2] ofType:knobType userInfo:nil];
			}
			
			lp = ap[2];
			
#ifdef qIncludeGraphicDebugging
			if ( m_showPartcodes )
			{
				NSInteger			j, pc;
				
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
				
				if ( !NSEqualPoints( lp, NSMakePoint(-1, -1)))
					[knobs drawKnobAtPoint:lp ofType:knobType userInfo:nil];
				
				[knobs drawKnobAtPoint:ap[0] ofType:knobType userInfo:nil];
			}
			lp = ap[0];
		
#ifdef qIncludeGraphicDebugging
			if ( m_showPartcodes )
			{
				NSInteger			pc;
				
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


///*********************************************************************************************************************
///
/// method:			length
/// scope:			public instance method
/// overrides:		
/// description:	return the length of the path
/// 
/// parameters:		none
/// result:			the path's length
///
/// notes:			length is accurately computed by summing the segment distances.
///
///********************************************************************************************************************

- (CGFloat)				length
{
	return [[self path] length];
}


///*********************************************************************************************************************
///
/// method:			lengthForPoint:
/// scope:			public instance method
/// overrides:		
/// description:	return the length along the path for a given point
/// 
/// parameters:		<mp> a point somewhere close to the path
/// result:			a distance along the path nearest to the point
///
/// notes:			points too far from the path return a value of -1. To be within range, the point needs to be within
///					4 x the widest stroke drawn by the style, or 4 points, whichever is larger.
///
///********************************************************************************************************************

- (CGFloat)			lengthForPoint:(NSPoint) mp
{
	return [self lengthForPoint:mp tolerance:MAX( 1, [[self style] maxStrokeWidth]) * 4];
}


///*********************************************************************************************************************
///
/// method:			lengthForPoint:tolerance:
/// scope:			public instance method
/// overrides:		
/// description:	return the length along the path for a given point
/// 
/// parameters:		<mp> a point somewhere close to the path
///					<tol> the tolerance value
/// result:			a distance along the path nearest to the point
///
/// notes:			points too far from the path return a value of -1. The point needs to be <tol> or less from the path.
///
///********************************************************************************************************************

- (CGFloat)			lengthForPoint:(NSPoint) mp tolerance:(CGFloat) tol
{
	return [[self path] distanceFromStartOfPathAtPoint:mp tolerance:tol];
}



- (void)				recordPathForUndo
{
	[m_undoPath release];
	m_undoPath = [[self path] copy];
}


- (NSBezierPath*)		undoPath
{
	return m_undoPath;
}


- (void)				clearUndoPath
{
	[m_undoPath release];
	m_undoPath = nil;
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
/// method:			wouldJoin:tolerance:
/// scope:			public instance method
/// overrides:		
/// description:	preflights a potential join to determine if the join would be made
/// 
/// parameters:		<anotherPath> another drawable path object like this one
///					<tol> a value used to determine if the end points are placed sufficiently close to be joinable
/// result:			a join result value, indicating which end(s) would be joined, if any
///
/// notes:			allows a join operation to be preflighted without actually performing the join.
///
///********************************************************************************************************************

- (DKDrawablePathJoinResult)	wouldJoin:(DKDrawablePath*) anotherPath tolerance:(CGFloat) tol
{
	NSBezierPath* ap = [anotherPath path];
	DKDrawablePathJoinResult result = kDKPathNoJoin;
	
	if ( anotherPath == nil || [ap isPathClosed] || [[self path] isPathClosed])
		return kDKPathNoJoin;
	
	// do the paths share an end point?
	
	CGFloat	dist;
	NSInteger		j, k;
	
	NSPoint p1[2];
	NSPoint p2[2];
	
	p1[0] = [[self path] firstPoint];	// head 1
	p1[1] = [[self path] lastPoint];	// tail 1
	p2[0] = [ap firstPoint];			// head 2
	p2[1] = [ap lastPoint];				// tail 2
	
	for( j = 0; j < 2; ++j )
	{
		for( k = 0; k < 2; ++k )
		{
			dist = hypotf( p2[j].x - p1[k].x, p2[j].y - p1[k].y );
			
			if ( dist <= tol )
			{
				// found points close enough to join. One path may need reversing to accomplish it.
				// this would be when joining two heads or two tails.
				
				if ( k == 0 )
					result = kDKPathOtherPathWasPrepended;
				else
					result = kDKPathOtherPathWasAppended;
				
				// test if both ends would be joined
				
				k = ( k == 0 )? 1 : 0;
				j = ( j == 0 )? 1 : 0;
				
				dist = hypotf( p2[j].x - p1[k].x, p2[j].y - p1[k].y );
				
				if ( dist <= tol )
					result = kDKPathBothEndsJoined;
				
				return result;
			}
		}
	}
	
	return result;
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
/// result:			a join result value, indicating which end(s) were joined, if any
///
/// notes:			this attempts to join either or both ends of the two paths if they are placed sufficiently
///					closely. Usually the higher level join action at the layer level will be used.
///
///********************************************************************************************************************

- (DKDrawablePathJoinResult) join:(DKDrawablePath*) anotherPath tolerance:(CGFloat) tol makeColinear:(BOOL) colin
{
//	LogEvent_(kReactiveEvent, @"joining path, tolerance = %f", tol );
	
	NSBezierPath* ap = [anotherPath path];
	DKDrawablePathJoinResult result = kDKPathNoJoin;
	
	if ([ap isPathClosed] || [[self path] isPathClosed])
		return kDKPathNoJoin;
		
	// do the paths share an end point?
	
	CGFloat	dist;
	NSInteger		j, k;
	
	NSPoint p1[2];
	NSPoint p2[2];
	
	p1[0] = [[self path] firstPoint];	// head 1
	p1[1] = [[self path] lastPoint];	// tail 1
	p2[0] = [ap firstPoint];			// head 2
	p2[1] = [ap lastPoint];				// tail 2
	
	for( j = 0; j < 2; ++j )
	{
		for( k = 0; k < 2; ++k )
		{
			dist = hypotf( p2[j].x - p1[k].x, p2[j].y - p1[k].y );
			
			if ( dist <= tol )
			{
				// found points close enough to join. One path may need reversing to accomplish it.
				// this would be when joining two heads or two tails.
				
				if ( k == j )
					ap = [ap bezierPathByReversingPath];
					
				// join to whichever path has the tail aligned
				
				NSBezierPath* newPath;
				NSInteger			  ec;
				
				if ( k == 0 )
				{
					newPath = [ap copy];
					ec = [newPath elementCount] - 1;
					[newPath appendBezierPathRemovingInitialMoveToPoint:[self path]];
					
					result = kDKPathOtherPathWasPrepended;
				}
				else
				{
					// copy existing path rather than append directly - this ensures the operation is
					// undoable.
					
					newPath = [[self path] copy];
					ec = [newPath elementCount] - 1;
					[newPath appendBezierPathRemovingInitialMoveToPoint:ap];
					
					result = kDKPathOtherPathWasAppended;
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
				
				dist = hypotf( p2[j].x - p1[k].x, p2[j].y - p1[k].y );
				
				if ( dist <= tol )
				{
					[newPath closePath];
					
					result = kDKPathBothEndsJoined;
					
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
				
				return result;
			}
		}
	}

	return kDKPathNoJoin;
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
			dp = [[self class] drawablePathWithBezierPath:pp];
			
			[dp setStyle:[self style]];
			[dp setUserInfo:[self userInfo]];
			[newObjects addObject:dp];
		}
	}
	
	return [newObjects autorelease];
}


///*********************************************************************************************************************
///
/// method:			dividePathAtLength:
/// scope:			public instance method
/// overrides:		
/// description:	splits a path into two paths at a specific point
/// 
/// parameters:		<distance> the position from the start of the path to make the split
/// result:			a new path, being the section of the original path from <distance> to the end.
///
/// notes:			The new path has the same style and user info as the original, but is not added to the layer
///					by this method. If <distance> is <= 0 or >= length, nil is returned.
///
///********************************************************************************************************************

- (DKDrawablePath*)		dividePathAtLength:(CGFloat) distance
{
	if( distance > 0 )
	{
		CGFloat length = [self length];
		
		if( distance < length )
		{
			NSBezierPath* remainingPath = [[self path] bezierPathByTrimmingFromLength:distance];
			NSBezierPath* newPath = [[self path] bezierPathByTrimmingToLength:distance];

			[self setPath:newPath];
			
			// create a new path object for the remainder path
			
			DKDrawablePath* path = [[[self class] alloc] initWithBezierPath:remainingPath];
			
			// copy over all the various gubbins we neeed to:
			
			[path setStyle:[self style]];
			[path addUserInfo:[self userInfo]];
			[path setGhosted:[self isGhosted]];
			
			return [path autorelease];
		}
	}
	
	return nil;
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

- (void)				setPathCreationMode:(DKDrawablePathCreationMode) editPathMode
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

- (DKDrawablePathCreationMode)	pathCreationMode
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
	NSInteger			mask = NSLeftMouseDownMask | NSLeftMouseUpMask | NSLeftMouseDraggedMask | NSMouseMovedMask | NSPeriodicMask | NSScrollWheelMask | NSKeyDownMask;
	NSView*		view = [[self layer] currentView];
	BOOL		loop = YES;
	BOOL		first = YES;
	NSInteger			element, partcode;
	NSPoint		p, ip, centre, opp, nsp;
	
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
		
		// look for any special key codes that we want to detect

		if([theEvent type] == NSKeyDown )
		{
			unsigned short code = [theEvent keyCode];
			
			if( code == 0x33 )		// delete key
			{
				if( element > 1 )
				{
					// back up to the previously placed point.
					
					path = [path bezierPathByRemovingTrailingElements:1];
					partcode = partcodeForElementControlPoint( --element, 2 );
					[path setControlPoint:p forPartcode:partcode];
					[self setPath:path];
				}
				continue;
			}
		}

		p = nsp = [view convertPoint:[theEvent locationInWindow] fromView:nil];
		p = [self snappedMousePoint:p withControlFlag:NO];

		if ([self shouldEndPathCreationWithEvent:theEvent])
		{
			// if the event isn't a mouse event, post a mouse up which the creation tool needs to complete the object creation
			
			if([theEvent type] == NSKeyDown )
				theEvent = [self postMouseUpAtPoint:p];
			
			NSRect tr = NSMakeRect( ip.x - 3.0, ip.y - 3.0, 6.0, 6.0 );
			
			if ( NSPointInRect( p, tr ))
			{
				loop = NO;
				[path setControlPoint:p forPartcode:partcode];
				
				// set cp2 to the colinear opposite of cp1 of element 1
				
				centre = [path controlPointForPartcode:partcodeForElement( 0 )];
				
				opp = [NSBezierPath colinearPointForPoint:[path controlPointForPartcode:partcodeForElementControlPoint( 1, 0)] centrePoint:centre]; 
				[path setControlPoint:opp forPartcode:partcodeForElementControlPoint( element, 1 )];
			}
			
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
				
				[self showLengthInfo:[path length] atPoint:nsp];
				break;
			
			case NSLeftMouseUp:
				partcode = partcodeForElementControlPoint( element, 2 );
				break;
				
			case NSMouseMoved:
				[self notifyVisualChange];
				[view autoscroll:theEvent];
				[path setControlPoint:p forPartcode:partcode];
				[path setControlPoint:p forPartcode:partcodeForElementControlPoint( element, 1 )];
				[self showLengthInfo:[path length] atPoint:nsp];
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
	
	[NSApp discardEventsMatchingMask:NSAnyEventMask beforeEvent:theEvent];
	
	[self setPath:[path bezierPathByStrippingRedundantElements]];
	[self setPathCreationMode:kDKPathCreateModeEditExisting];
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
	// move, then click. Or click-drag-release.
	
	NSEvent*	theEvent;
	NSInteger			mask = NSLeftMouseDownMask | NSLeftMouseUpMask | NSLeftMouseDraggedMask | NSMouseMovedMask | NSPeriodicMask | NSScrollWheelMask;
	NSView*		view = [[self layer] currentView];
	BOOL		loop = YES, constrain = NO;
	NSInteger			element, partcode;
	NSPoint		p, ip, nsp;
	
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
		
		p = nsp = [view convertPoint:[theEvent locationInWindow] fromView:nil];
		p = [self snappedMousePoint:p withControlFlag:NO];
		
		constrain = (([theEvent modifierFlags] & NSShiftKeyMask) != 0 );
		
		if ( constrain )
		{
			// slope of line is forced to be on 15 degree intervals
			
			CGFloat	angle = atan2f( p.y - ip.y, p.x - ip.x );
			CGFloat	rem = fmodf( angle, sAngleConstraint );
			CGFloat	radius = hypotf( p.x - ip.x, p.y - ip.y );
		
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
				[self showLengthInfo:[path length] atPoint:nsp];
				break;
			
			case NSLeftMouseUp:
				// if the final point is in the same place as the first point, do a click-drag-click creation. Otherwise
				// we've already dragged so finish.
				
				if ( ! NSEqualPoints( p, ip ))
				{
					loop = NO;
				}
				break;
				
			case NSMouseMoved:
				[self notifyVisualChange];
				[view autoscroll:theEvent];
				[path setControlPoint:p forPartcode:partcode];
				[self showLengthInfo:[path length] atPoint:nsp];
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
	
	[NSApp discardEventsMatchingMask:NSAnyEventMask beforeEvent:theEvent];

	[self setPathCreationMode:kDKPathCreateModeEditExisting];
	[self notifyVisualChange];
	[self postMouseUpAtPoint:p];
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
	NSInteger	mask = NSLeftMouseDownMask | NSMouseMovedMask | NSPeriodicMask | NSScrollWheelMask | NSKeyDownMask;
	NSView*		view = [[self layer] currentView];
	BOOL		loop = YES, constrain = NO;
	NSInteger	element, partcode;
	NSPoint		p, ip, lp, nsp;
	
	p = ip = [self snappedMousePoint:initialPoint withControlFlag:NO];
	
	LogEvent_(kReactiveEvent, @"entering poly create loop");
	
	// if we are extending an existing path, start with that path and its open endpoint. Otherwise start from scratch
	
	NSBezierPath* path;
	
	if( m_extending && ![self isPathClosed])
	{
		path = [self path];
		element = [path elementCount];
	}
	else
	{
		path = [NSBezierPath bezierPath];
		
		[path moveToPoint:p];
		[path lineToPoint:p];
		[self setPath:path];
	
		element = 1;
	}
	
	partcode = partcodeForElement( element );
	lp = ip;
	
	//[NSEvent startPeriodicEventsAfterDelay:0.5 withPeriod:0.1];
	
	while( loop )
	{
		theEvent = [NSApp nextEventMatchingMask:mask untilDate:[NSDate distantFuture] inMode:NSEventTrackingRunLoopMode dequeue:YES];
		
		// look for any special key codes that we want to detect
		
		if([theEvent type] == NSKeyDown )
		{
			unsigned short code = [theEvent keyCode];
			
			if( code == 0x33 )		// delete key
			{
				if( element > 1 )
				{
					// back up to the previously placed point.
				
					path = [path bezierPathByRemovingTrailingElements:1];
					partcode = partcodeForElement( --element );
					lp = [path controlPointForPartcode:partcodeForElement( element - 1 )];
					[path setControlPoint:p forPartcode:partcode];
					[self setPath:path];
				}
				continue;
			}
		}
		
		if ([self shouldEndPathCreationWithEvent:theEvent])
		{
			if([theEvent type] == NSKeyDown )
				theEvent = [self postMouseUpAtPoint:p];
			else
				path = [path bezierPathByRemovingTrailingElements:1];

			NSRect tr = NSMakeRect( ip.x - 3.0, ip.y - 3.0, 6.0, 6.0 );
			
			if ( NSPointInRect( p, tr ))
			{
				path = [path bezierPathByRemovingTrailingElements:1];
				[path closePath];
			}	
			goto finish;
		}

		p = nsp = [view convertPoint:[theEvent locationInWindow] fromView:nil];
		p = [self snappedMousePoint:p withControlFlag:NO];
		
		constrain = (([theEvent modifierFlags] & NSShiftKeyMask) != 0 );
		
		if ( constrain )
		{
			// slope of line is forced to be on 15 degree intervals
			
			CGFloat	angle = atan2f( p.y - lp.y, p.x - lp.x );
			CGFloat	rem = fmodf( angle, sAngleConstraint );
			CGFloat	radius = hypotf( p.x - lp.x, p.y - lp.y );
		
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
				[self showLengthInfo:[path length] atPoint:nsp];
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
	
	[NSApp discardEventsMatchingMask:NSAnyEventMask beforeEvent:theEvent];

	[self setPath:path];
	
	[self setPathCreationMode:kDKPathCreateModeEditExisting];
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
	NSInteger			mask = NSLeftMouseDownMask | NSLeftMouseUpMask | NSLeftMouseDraggedMask | NSPeriodicMask | NSScrollWheelMask;
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
	
	[NSApp discardEventsMatchingMask:NSAnyEventMask beforeEvent:theEvent];

	[self setPathCreationMode:kDKPathCreateModeEditExisting];
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
	NSInteger				mask = NSLeftMouseDownMask | NSMouseMovedMask | NSPeriodicMask | NSScrollWheelMask;
	NSView*			view = [[self layer] currentView];
	BOOL			loop = YES, constrain = NO;
	NSInteger				element, partcode, phase;
	NSPoint			p, centre, lp, nsp;
	CGFloat			radius = 0.0;
	CGFloat			startAngle = 0.0;
	CGFloat			endAngle;
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
			// slope of line is forced to be on 15¬¨¬®‚Äö√†√ª intervals
			
			CGFloat	angle = atan2f( p.y - lp.y, p.x - lp.x );
			CGFloat	rem = fmodf( angle, sAngleConstraint );
			CGFloat	rad = hypotf( p.x - lp.x, p.y - lp.y );
		
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
						CGFloat rad = [[self drawing] convertLength:radius];
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
					if ([self pathCreationMode] == kDKPathCreateModeWedgeSegment)
						[path moveToPoint:centre];
						
					[path appendBezierPathWithArcWithCenter:centre radius:radius startAngle:startAngle endAngle:endAngle];
					
					if ([self pathCreationMode] == kDKPathCreateModeWedgeSegment)
						[path closePath];
					[self setPath:path];

					if([[self class] displaysSizeInfoWhenDragging])
					{			
						CGFloat rad = [[self drawing] convertLength:radius];
						CGFloat angle = endAngle - startAngle;
						
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
	
	[NSApp discardEventsMatchingMask:NSAnyEventMask beforeEvent:theEvent];

	[self setPathCreationMode:kDKPathCreateModeEditExisting];
	[self setStyle:savedStyle];
	[savedStyle release];
	[self notifyVisualChange];
	

	[view mouseUp:theEvent];
}


///*********************************************************************************************************************
///
/// method:			pathCreationLoopDidEnd
/// scope:			private instance method
/// overrides:		
/// description:	overrideable hook at the end of path creation
/// 
/// parameters:		none
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************
- (void)				pathCreationLoopDidEnd
{
	// override when you need to hook into the end of path creation
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
	else if ([event type] == NSKeyDown )
		return YES;
	else
		return NO;
}


- (NSEvent*)	postMouseUpAtPoint:(NSPoint) p
{
	NSView* view = [[self layer] currentView];
	p = [view convertPoint:p toView:nil];
	
	NSEvent* mouseUp = [NSEvent mouseEventWithType:NSLeftMouseUp
								location:p
								modifierFlags:0
								timestamp:[NSDate timeIntervalSinceReferenceDate]
								windowNumber:[[view window] windowNumber]
								context:[NSGraphicsContext currentContext]
								eventNumber:0
								clickCount:0
								pressure:0.0];
	
	[NSApp postEvent:mouseUp atStart:NO];
	return mouseUp;
}


///*********************************************************************************************************************
///
/// method:			isPathClosed
/// scope:			public instance method
/// overrides:		
/// description:	discover whether the path is open or closed
/// 
/// parameters:		none
/// result:			YES if the path is closed, NO if open
///
/// notes:			A path is closed if it has a closePath element or its first and last points are coincident.
///
///********************************************************************************************************************

- (BOOL)				isPathClosed
{
	return [[self path] isPathClosed];
}


///*********************************************************************************************************************
///
/// method:			isOpenEndPoint:
/// scope:			public instance method
/// overrides:		
/// description:	discover whether the given partcode is an open end point of the path
/// 
/// parameters:		<partcode> a partcode to test
/// result:			YES if the partcode is one of the endpoints, NO otherwise
///
/// notes:			A closed path always returns NO, as it has no open end points. An open path will return YES for
///					only the first and last points.
///
///********************************************************************************************************************

- (BOOL)				isOpenEndPoint:(NSInteger) partcode
{
	if(![self isPathClosed])
	{
		if( partcode == partcodeForElement( 0 ))
			return YES;
		
		if( partcode == [[self path] partcodeForLastPoint])
			return YES;
	}
	
	return NO;
}


///*********************************************************************************************************************
///
/// method:			shouldExtendExistingPath:
/// scope:			public instance method
/// overrides:		
/// description:	set whether the object should extend its path or start from scratch
/// 
/// parameters:		<xtend> YES to extend the path, NO for normal creation
/// result:			none
///
/// notes:			When YES, this affects the starting partcode for the creation process. Normally paths are started
///					from scratch, but if YES, this extends the existing path from its end if the path is open. The
///					tool that coordinates the creation of new objects is reposnsible for managing this appropriately.
///
///********************************************************************************************************************

- (void)				setShouldExtendExistingPath:(BOOL) xtend
{
	m_extending = xtend;
}


///*********************************************************************************************************************
///
/// method:			showLengthInfo:atPoint:
/// scope:			public instance method
/// overrides:		
/// description:	conditionally display the length info feedback window
/// 
/// parameters:		<dist> the distance to display
///					<p> where to put the window
/// result:			none
///
/// notes:			distance is converted to drawing's current units, and point is converted to global. If the feedback
///					display is disabled, does nothing.
///
///********************************************************************************************************************

- (void)				showLengthInfo:(CGFloat) dist atPoint:(NSPoint) p
{
	if([[self class] displaysSizeInfoWhenDragging])
	{
		NSString* fmt = [[self drawing] formattedConvertedLength:dist];
		[[self layer] showInfoWindowWithString:fmt atPoint:p];
	}
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

- (BOOL)				pathDeletePointWithPartCode:(NSInteger) pc
{
	// delete the point with the given partcode
	
	if ( pc > kDKDrawingNoPart && [[self path] elementCount] > 2 )
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
/// method:			pathDeleteElementAtIndex:
/// scope:			public instance method
/// overrides:		
/// description:	delete a segment from the path at the given index
/// 
/// parameters:		<indx> the index of the element to delete
/// result:			YES if the element was deleted, NO if not
///
/// notes:			If the element id removed from the middle, the path is split into two subpaths. If removed at
///					either end, the path is shortened. Partcodes will change.
///
///********************************************************************************************************************

- (BOOL)				pathDeleteElementAtIndex:(NSInteger) indx
{
	NSBezierPath* np = [[self path] bezierPathByRemovingElementAtIndex:indx];
	
	if( np != [self path])
	{
		[self setPath:np];
		return YES;
	}
	
	return NO;
}


///*********************************************************************************************************************
///
/// method:			pathDeleteElementAtPoint:
/// scope:			public instance method
/// overrides:		
/// description:	delete a segment from the path at the given point
/// 
/// parameters:		<loc> a point
/// result:			YES if the element was deleted, NO if not
///
/// notes:			Finds the element hit by the point and calls -pathDeleteElementAtIndex:
///
///********************************************************************************************************************

- (BOOL)				pathDeleteElementAtPoint:(NSPoint) loc
{
	CGFloat tol = MAX( 4.0, [[self style] maxStrokeWidth]);
	NSInteger indx = [[self path] elementHitByPoint:loc tolerance:tol tValue:NULL];
	
	if( indx != -1 )
		return [self pathDeleteElementAtIndex:indx];
	
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

- (NSInteger)					pathInsertPointAt:(NSPoint) loc ofType:(DKDrawablePathInsertType) pathPointType
{
	// insert a new point at the given location, returning the new point's partcode
	
	CGFloat tol = MAX( 4.0, [[self style] maxStrokeWidth]);
	
	NSBezierPath* np = [[self path] insertControlPointAtPoint:loc tolerance:tol type:pathPointType];
	
	if ( np != nil )
	{
		[self setPath:np];
		return [np partcodeHitByPoint:loc tolerance:tol];
	}

	return kDKDrawingNoPart;
}


///*********************************************************************************************************************
///
/// method:			movePathPartcode:toPoint:event:
/// scope:			protected instance method
/// overrides:		
/// description:	move a single control point to a new position
/// 
/// parameters:		<pc> the partcode for the point to be moved
///					<mp> the point to move it to
///					<evt> the event (used to grab modifier flags)
/// result:			none
///
/// notes:			essential interactive editing method
///
///********************************************************************************************************************

- (void)				movePathPartcode:(NSInteger) pc toPoint:(NSPoint) mp event:(NSEvent*) evt
{
	if( pc < 4 )
		return;
	
	BOOL option = (([evt modifierFlags] & NSAlternateKeyMask ) != 0 );
	BOOL cmd	= (([evt modifierFlags] & NSCommandKeyMask ) != 0 );
	BOOL shift	= (([evt modifierFlags] & NSShiftKeyMask ) != 0 );
	
	// modifier keys change the editing of path control points thus:
	
	// +shift	- constrains curve control point angles to 15 degree intervals
	// +option	- forces the control points either side of an on-path point to maintain the same radial distance
	// +cmd		- allows control points to be moved fully independently
	// +ctrl	- temporarily disables snap to grid
	
	NSRect oldBounds = [self bounds];
	
	// if cmd + option is down, cmd takes priority of +defaultOnPathHitDetectionPriority is NO, option takes priority if
	// it returns YES
	
	if( cmd && option )
	{
		if([[self class] defaultOnPathHitDetectionPriority])
			cmd = NO;
	}
	
	[self notifyVisualChange];
	[[self path] moveControlPointPartcode:pc toPoint:mp colinear:!cmd coradial:option constrainAngle:shift];
	[self notifyGeometryChange:oldBounds];
	[self notifyVisualChange];
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

- (void)				setFreehandSmoothing:(CGFloat) fs
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

- (CGFloat)				freehandSmoothing
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
/// notes:			called by -convertToShape, a higher level operation. Note that the actual class of object returned
///					can be modified by customising the interconversion table.
///
///********************************************************************************************************************

- (DKDrawableShape*)	makeShape
{
	NSBezierPath* mp = [[[self path] copy] autorelease];
	
	Class shapeClass = [DKDrawableObject classForConversionRequestFor:[DKDrawableShape class]];
	
	DKDrawableShape* so = [shapeClass drawableShapeWithBezierPath:mp withStyle:[self style]];
	[so setUserInfo:[self userInfo]];
	
	return so;
}


- (BOOL)				canConvertToTrack
{
	return NO;
}


///*********************************************************************************************************************
///
/// method:			makeParallelWithOffset:
/// scope:			public instance method
/// overrides:		
/// description:	make a copy of the path but with a parallel offset
/// 
/// parameters:		<distance> the distance from the original that the path is offset (negative forupward displacement)
///					<smooth> if YES, also smooths the resulting path
/// result:			a DKDrawablePath object
///
/// notes:			
///
///********************************************************************************************************************

- (DKDrawablePath*)		makeParallelWithOffset:(CGFloat) distance smooth:(BOOL) smooth
{
	DKDrawablePath*		newPath = [self copy];
	
	if( distance != 0.0 )
	{
		NSBezierPath* np = [[self path] paralleloidPathWithOffset2:distance];
		
		if( smooth )
			np = [np bezierPathByInterpolatingPath:1.0];

		[newPath setPath:np];
	}
	
	return [newPath autorelease];
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
	NSInteger				myIndex = [layer indexOfObject:self];
	
	DKDrawableShape*		so = [self makeShape];
	
	if( so )
	{
		[so willBeAddedAsSubstituteFor:self toLayer:layer];
		
		[layer recordSelectionForUndo];
		[layer addObject:so atIndex:myIndex];
		[layer replaceSelectionWithObject:so];
		[layer removeObject:self];
		[layer commitSelectionUndoWithActionName:NSLocalizedString(@"Convert To Shape", @"undo string for convert to shape")];
	}
	else
		NSBeep();
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
	
	CGFloat sw = [[self style] maxStrokeWidthDifference] / 2.0;
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
		NSEnumerator* iter = [broken objectEnumerator];
		DKDrawableObject* obj;
		
		while(( obj = [iter nextObject]))
			[obj willBeAddedAsSubstituteFor:self toLayer:odl];
		
		[odl recordSelectionForUndo];
		[odl addObjectsFromArray:broken];
		[odl removeObject:self];
		[odl exchangeSelectionWithObjectsFromArray:broken];
		[odl commitSelectionUndoWithActionName:NSLocalizedString(@"Break Apart", @"undo string for break apart")];
	}
}


- (IBAction)			roughenPath:(id) sender
{
	#pragma unused(sender)
	
	NSBezierPath* path = [self path];
	
	CGFloat sw = [[self style] maxStrokeWidthDifference] / 2.0;
	[[self style] applyStrokeAttributesToPath:path];
	
	if ( sw > 0.0 )
		[path setLineWidth:[path lineWidth] - sw];
		
	CGFloat roughness = [[self style] maxStrokeWidth] / 4.0;
	
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
	
	[self setPath:[[self path] bezierPathByInterpolatingPath:1.0]];
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
	
	DKDrawablePath*		newPath = [self makeParallelWithOffset:30.0 smooth:YES];
	
	DKObjectDrawingLayer* odl = (DKObjectDrawingLayer*)[self layer];
	
	if ( odl )
	{
		[odl recordSelectionForUndo];
		[odl addObject:newPath];
		[odl exchangeSelectionWithObjectsFromArray:[NSArray arrayWithObject:newPath]];
		[odl commitSelectionUndoWithActionName:NSLocalizedString(@"Parallel Copy", @"undo string for parallel copy")];
	}
}


///*********************************************************************************************************************
///
/// method:			curveFit:
/// scope:			public action method
/// overrides:		
/// description:	attempts to curve-fit the object's path
/// 
/// parameters:		<sender> the action's sender
/// result:			none
///
/// notes:			The path might not change, depending on how it is made up
///
///********************************************************************************************************************

- (IBAction)			curveFit:(id) sender
{
#pragma unused(sender)
	
	if(![self locked])
	{
		NSBezierPath* newPath = [[self path] bezierPathByUnflatteningPath];
		[self setPath:newPath];
		[[self undoManager] setActionName:NSLocalizedString(@"Curve Fit", @"undo action for Curve Fit")];
	}
}


///*********************************************************************************************************************
///
/// method:			reversePath:
/// scope:			public action method
/// overrides:		
/// description:	reverses the direction of the object's path
/// 
/// parameters:		<sender> the action's sender
/// result:			none
///
/// notes:			Does not change the path's appearance directly, but may depending on the current style, e.g. arrows
///					will flip to the other end.
///
///********************************************************************************************************************

- (IBAction)			reversePath:(id) sender
{
#pragma unused(sender)
	
	if(![self locked])
	{
		NSBezierPath* newPath = [[self path] bezierPathByReversingPath];
		[self setPath:newPath];
		[[self undoManager] setActionName:NSLocalizedString(@"Reverse Path", @"undo action for Reverse Path")];
	}
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


///*********************************************************************************************************************
///
/// method:			closePath:
/// scope:			public action method
/// overrides:		
/// description:	closes the path if not already closed
/// 
/// parameters:		<sender> the action's sender
/// result:			none
///
/// notes:			paths created using the bezier tool are always left open by default
///
///********************************************************************************************************************

- (IBAction)			closePath:(id) sender
{
#pragma unused(sender)
	
	if(![self isPathClosed] && ![self locked])
	{
		NSBezierPath* path = [[self path] copy];
		[path closePath];
		[self setPath:path];
		[path release];
		[[self undoManager] setActionName:NSLocalizedString(@"Close Path", nil)];
	}
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

+ (NSInteger)					initialPartcodeForObjectCreation
{
	return kDKDrawingNoPart;
}



+ (NSArray*)			pasteboardTypesForOperation:(DKPasteboardOperationType) op
{
	#pragma unused(op)
	return [NSArray arrayWithObjects:NSColorPboardType, NSStringPboardType, NSPDFPboardType, NSTIFFPboardType,
										NSFilenamesPboardType, kDKStylePasteboardType, kDKStyleKeyPasteboardType, nil];
}


///*********************************************************************************************************************
///
/// method:			initWithStyle:
/// scope:			public instance method
/// overrides:
/// description:	initializes the drawable to have the style given
/// 
/// parameters:		<aStyle> the initial style for the object
/// result:			the object
///
/// notes:			you can use -init to initialize using the default style. Note that if creating many objects at
///					once, supplying the style when initializing is more efficient.
///
///********************************************************************************************************************

- (id)					initWithStyle:(DKStyle*) aStyle
{
	self = [super initWithStyle:aStyle];
	if( self )
	{
		m_freehandEpsilon = 2.0;
		m_editPathMode = kDKPathCreateModeEditExisting;
	}
	
	return self;
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
	NSRect	r;
	
	// get the true knob size so we can factor that in accurately
		
	NSRect kr = [[[self layer] knobs] controlKnobRectAtPoint:NSZeroPoint ofType:kDKOnPathKnobType];
		
	CGFloat kbs = kr.size.width * 0.5f;
	r = NSInsetRect( [[self renderingPath] controlPointBounds], -kbs, -kbs );

	// factor in style allowance
	
	NSSize allow = [self extraSpaceNeeded];
	r = NSInsetRect( r, -allow.width, -allow.height );
	
	if( r.size.width < 1 )
	{
		r.size.width = 1;
		r.origin.x = [self location].x - 0.5;
	}
	
	if( r.size.height < 1 )
	{
		r.size.height = 1;
		r.origin.y = [self location].y - 0.5;
	}
	
	return r;
}


///*********************************************************************************************************************
///
/// method:			drawContent
/// scope:			public instance method
/// overrides:		DKDrawableObject
/// description:	draws the object
/// 
/// parameters:		none
/// result:			none
///
/// notes:			when hit-testing, substitutes a style that is easier to hit
///
///********************************************************************************************************************

- (void)			drawContent
{
	if([self isBeingHitTested])
	{
		// for easier hit-testing of very thin or offset paths, the path is stroked using a
		// centre-aligned 4pt or greater stroke. This is substituted on the fly here and never visible to the user.
		
		CGFloat strokeWidth = MAX( 4, [[self style] maxStrokeWidth]);
		
		BOOL hasFill = [[self style] hasFill] || [[self style] hasHatch];
		
		DKStyle* temp = [DKStyle styleWithFillColour:hasFill? [NSColor blackColor] : nil strokeColour:[NSColor blackColor] strokeWidth:strokeWidth];
		[temp render:self];
	}
	else
		[super drawContent];	
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
	
	NSAutoreleasePool* pool = [NSAutoreleasePool new];
	
	NSBezierPath* path = [self renderingPath];
	
	[self drawSelectionPath:path];
	[self drawControlPointsOfPath:path usingKnobs:[[self layer] knobs]];
	
#ifdef qIncludeGraphicDebugging
	if ( m_showBBox )
		[[self path] drawElementsBoundingBoxes];

#endif
	
	[pool drain];
}


///*********************************************************************************************************************
///
/// method:			drawGhostedContent
/// scope:			public instance method
/// overrides:
/// description:	draw the ghosted content of the object
/// 
/// parameters:		none
/// result:			none
///
/// notes:			The default simply strokes the rendering path at minimum width using the ghosting colour. Can be
///					overridden for more complex appearances. Note that ghosting should deliberately keep the object
///					unobtrusive and simple.
///
///********************************************************************************************************************

- (void)			drawGhostedContent
{
	[[[self class] ghostColour] set];
	NSBezierPath* rp = [self renderingPath];
	
	// if the path is usually drawn wider than 2, outline it
	
	if([[self style] maxStrokeWidth] > 2 )
		rp = [rp strokedPathWithStrokeWidth:[[self style] maxStrokeWidth]];
	
	[rp setLineWidth:0];
	[rp stroke];
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

- (NSInteger)				hitPart:(NSPoint) pt
{
	NSInteger pc = [super hitPart:pt];
	
	if ( pc == kDKDrawingEntireObjectPart )
	{
		// hit in bounds, refine by testing against controls/bitmap
		// if we have a fill, test for path contains as well:

		if([[self style] hasFill] || [[self style] hasHatch])
		{
			if ([[self path] containsPoint:pt])
				return kDKDrawingEntireObjectPart;
		}

		if ([self pointHitsPath:pt])
			pc = kDKDrawingEntireObjectPart;
		else
			pc = kDKDrawingNoPart;
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

- (NSInteger)				hitSelectedPart:(NSPoint) pt forSnapDetection:(BOOL) snap
{
	CGFloat	tol = [[[self layer] knobs] controlKnobSize].width;
	
	if( snap )
		tol *= 2;
		
	NSInteger		pc;
	BOOL			commandKey = ([[NSApp currentEvent] modifierFlags] & NSCommandKeyMask ) != 0;;
	
	if([[self class] defaultOnPathHitDetectionPriority])
		commandKey = !commandKey;
	
	pc = [[self path] partcodeHitByPoint:pt tolerance:tol prioritiseOnPathPoints:commandKey];
	
	// if snapping, ignore off-path points
	
	if( snap && ![[self path] isOnPathPartcode:pc])
		pc = 0;
	
	if ( pc == 0 )
	{
		pc = kDKDrawingEntireObjectPart;
	
		if ( snap )
		{
			// for snapping to the nearest point on the path, return a special partcode value and cache the mouse point -
			// when pointForPartcode is called with this special code, locate the nearest path point and return it.
			
			if ([self pointHitsPath:pt])
			{
				gMouseForPathSnap = pt;
				pc = kDKSnapToNearestPathPointPartcode;
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
	return [[self renderingPath] bounds];
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

- (void)				mouseDownAtPoint:(NSPoint) mp inPart:(NSInteger) partcode event:(NSEvent*) evt
{
	[[self layer] setInfoWindowBackgroundColour:[[self class] infoWindowBackgroundColour]];

	[self setTrackingMouse:YES];
	NSInteger mode = [self pathCreationMode];
	
	if (( partcode == kDKDrawingNoPart ) && ( mode != kDKPathCreateModeEditExisting ))
	{
		// these loops keep control until their logic dictates otherwise, so the other
		// mouse event handler methods won't be called
		
		switch( mode )
		{
			case kDKPathCreateModeLineCreate:
				[self lineCreateLoop:mp];
				break;
				
			case kDKPathCreateModeBezierCreate:
				[self pathCreateLoop:mp];
				break;
				
			case kDKPathCreateModePolygonCreate:
				[self polyCreateLoop:mp];
				break;
#ifdef qUseCurveFit
			case kDKPathCreateModeFreehandCreate:
			{
				CGFloat savedFHE = [self freehandSmoothing];
				
				BOOL option = ([evt modifierFlags] & NSAlternateKeyMask) != 0;
				
				if ( option )
					[self setFreehandSmoothing:10 * savedFHE];
					
				[self freehandCreateLoop:mp];
				[self setFreehandSmoothing:savedFHE];
			}
			break;
#endif
			case kDKPathCreateModeWedgeSegment:
			case kDKPathCreateModeArcSegment:
				[self arcCreateLoop:mp];
				break;
				
			default:
				break;
		}
		
		[self pathCreationLoopDidEnd];
	}
	else
	{
		if ( partcode == kDKDrawingEntireObjectPart )
			[super mouseDownAtPoint:mp inPart:partcode event:evt];
		else
		{
			[self recordPathForUndo];
			[self setMouseHasMovedSinceStartOfTracking:NO];
		}
	}
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

- (void)				mouseDraggedAtPoint:(NSPoint) mp inPart:(NSInteger) partcode event:(NSEvent*) evt
{
	if (partcode == kDKDrawingEntireObjectPart )
	{
		[super mouseDraggedAtPoint:mp inPart:partcode event:evt];
	}
	else
	{
		BOOL ctrl	= (([evt modifierFlags] & NSControlKeyMask ) != 0 );
		mp = [self snappedMousePoint:mp withControlFlag:ctrl];
		[self movePathPartcode:partcode toPoint:mp event:evt];
		
		// if the class is set to show size info when resizing, set up an info window now to do that.
			
		if([[self class] displaysSizeInfoWhenDragging])
		{			
			NSPoint		gridPt = [self convertPointToDrawing:mp];
			NSString*	abbrUnits = [[self drawing] abbreviatedDrawingUnits];
			
			[[self layer] showInfoWindowWithString:[NSString stringWithFormat:@"x: %.2f%@\ny: %.2f%@", gridPt.x, abbrUnits, gridPt.y, abbrUnits] atPoint:mp];
		}
		
		[self setMouseHasMovedSinceStartOfTracking:YES];
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

- (void)				mouseUpAtPoint:(NSPoint) mp inPart:(NSInteger) partcode event:(NSEvent*) evt
{
	if ( partcode == kDKDrawingEntireObjectPart )
		[super mouseUpAtPoint:mp inPart:partcode event:evt];
	else
	{
		if ([self mouseHasMovedSinceStartOfTracking] && [self undoPath])
		{
			[[self undoManager] registerUndoWithTarget:self selector:@selector(setPath:) object:[self undoPath]];
			[[self undoManager] setActionName:NSLocalizedString( @"Change Path", @"undo string for change path")];
			[self clearUndoPath];
		}
	}
	[[self layer] hideInfoWindow];
	[self notifyVisualChange];
	[self setTrackingMouse:NO];
}


///*********************************************************************************************************************
///
/// method:			setLocation:
/// scope:			public instance method
/// overrides:		DKDrawableObject
/// description:	moves the object to a new location
/// 
/// parameters:		<p> the new location
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)			setLocation:(NSPoint) p
{
	if(![self locationLocked])
	{
		CGFloat	dx, dy;

		dx = p.x - [self location].x;
		dy = p.y - [self location].y;
		
		if ( dx != 0.0 || dy != 0.0 )
		{
			NSRect oldBounds = [self bounds];
			
			[self notifyVisualChange];
			[[[self undoManager] prepareWithInvocationTarget:self] setLocation:[self location]];
			
			NSAffineTransform* tfm = [NSAffineTransform transform];
			[tfm translateXBy:dx yBy:dy];
			
			[[self path] transformUsingAffineTransform:tfm];
			[self notifyVisualChange];
			[self notifyGeometryChange:oldBounds];
		}
	}
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

- (NSPoint)			pointForPartcode:(NSInteger) pc
{
	if ( pc != kDKDrawingNoPart && pc != kDKDrawingEntireObjectPart )
	{
		if ( pc == kDKSnapToNearestPathPointPartcode )
		{
			// snapping to the nearest path point
			
			return [[self path] nearestPointToPoint:gMouseForPathSnap tolerance:4];
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
	
	NSMenu* convertMenu = [[theMenu itemWithTag:kDKConvertToSubmenuTag] submenu];
	
	if( convertMenu )
		[[convertMenu addItemWithTitle:NSLocalizedString(@"Shape", @"submenu item for convert to shape") action:@selector( convertToShape: ) keyEquivalent:@""] setTarget:self];
	else
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
/// notes:			this is part of the style rendering protocol. Note that the path returned is always a copy of the
///					object's stored path and may be freely modified
///
///********************************************************************************************************************

- (NSBezierPath*)	renderingPath
{
	NSBezierPath* rPath = [[[self path] copy] autorelease];
	NSAffineTransform* parentTransform = [self containerTransform];
	
	if ( parentTransform )
		rPath = [parentTransform transformBezierPath:rPath];
		
	// if drawing is in low quality mode, set a coarse flatness value:
	
	if([[self drawing] lowRenderingQuality])
		[rPath setFlatness:2.0];
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

- (void)			setAngle:(CGFloat) angle
{
	[self setPath:[[self path] rotatedPath:angle aboutPoint:[self location]]];
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
	NSInteger						i, el = [[self path] elementCount];
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
/*
- (void)			notifyVisualChange
{
	[self setNeedsDisplayForRects:[[self renderingPath] allBoundingBoxes]];
	[[self drawing] updateRulerMarkersForRect:[self logicalBounds]];
	[[NSNotificationCenter defaultCenter] postNotificationName:kDKDrawableDidChangeNotification object:self];
}
*/

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


///*********************************************************************************************************************
///
/// method:			size
/// scope:			public instance method
/// overrides:		DKDrawableObject
/// description:	return the object's size
/// 
/// parameters:		none
/// result:			the size of the object (the size of the path bounds)
///
/// notes:			
///
///********************************************************************************************************************

- (NSSize)				size
{
	return [[self path] bounds].size;
}


///*********************************************************************************************************************
///
/// method:			group:willUngroupObjectWithTransform:
/// scope:			public instance method
/// overrides:
/// description:	this object is being ungrouped from a group
/// 
/// parameters:		<aGroup> the group containing the object
///					<aTransform> the transform that the group is applying to the object to scale rotate and translate it.
/// result:			none
///
/// notes:			when ungrouping, an object must help the group to the right thing by resizing, rotating and repositioning
///					itself appropriately. At the time this is called, the object has already has its container set to
///					the layer it will be added to but has not actually been added.
///
///********************************************************************************************************************

- (void)				group:(DKShapeGroup*) aGroup willUngroupObjectWithTransform:(NSAffineTransform*) aTransform
{
	#pragma unused(aGroup)
	
	NSAssert( aTransform != nil, @"expected valid transform");

	NSBezierPath* path = [[self path] copy];
	[path transformUsingAffineTransform:aTransform];
	[self setPath:path];
	[path release];
}


///*********************************************************************************************************************
///
/// method:			applyTransform:
/// scope:			public instance method
/// overrides:		DKDrawableObject
/// description:	apply the transform to the object
/// 
/// parameters:		<transform> a transform
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				applyTransform:(NSAffineTransform*) transform
{
	[self notifyVisualChange];
	[[self path] transformUsingAffineTransform:transform];
	[self notifyVisualChange];
}




#pragma mark -
#pragma mark As an NSObject
- (void)			dealloc
{
	[m_path release];
	[m_undoPath release];
	[super dealloc];
}


- (id)				init
{
	return [self initWithStyle:[DKStyle styleWithFillColour:nil strokeColour:[NSColor blackColor] strokeWidth:1.0]];
}


#pragma mark -
#pragma mark As part of NSCoding Protocol
- (void)			encodeWithCoder:(NSCoder*) coder
{
	[super encodeWithCoder:coder];
	
	[coder encodeObject:[self path] forKey:@"path"];
	[coder encodeDouble:m_freehandEpsilon forKey:@"freehand_smoothing"];
}


- (id)				initWithCoder:(NSCoder*) coder
{
	self = [super initWithCoder:coder];
	if (self != nil)
	{
		[self setPath:[coder decodeObjectForKey:@"path"]];
		m_freehandEpsilon = [coder decodeDoubleForKey:@"freehand_smoothing"];
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

	[copy setPathCreationMode:[self pathCreationMode]];
	
	return copy;
}


#pragma mark -
#pragma mark As part of NSDraggingDestination protocol

- (BOOL)				performDragOperation:(id <NSDraggingInfo>) sender
{
	// this is called when the owning layer permits it, and the drag pasteboard contains a type that matches the class's
	// pasteboardTypesForOperation result. Generally at this point the object should simply handle the drop.
	
	// default behaviour is to derive a style from the current style.
		
	DKStyle* newStyle = nil;
	
	// first see if we have dropped a complete style
	
	newStyle = [DKStyle styleFromPasteboard:[sender draggingPasteboard]];
	
	if( newStyle == nil )
		newStyle = [[self style] derivedStyleWithPasteboard:[sender draggingPasteboard] withOptions:kDKDerivedStyleForPathHint];
	
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
	SEL	action = [item action];
	
	if ( action == @selector( convertToOutline: ) ||
		 action == @selector( roughenPath: ))
		return ![self locked] && [[self style] hasStroke];
	
	if ( action == @selector( breakApart: ))
		return ![self locked] && [[self path] countSubPaths] > 1;
	
	if ( action == @selector( convertToShape: ) ||
				action == @selector( addRandomNoise: ) ||
				action == @selector( smoothPath: ) ||
				action == @selector( parallelCopy: ) ||
				action == @selector( smoothPathMore: ) ||
				action == @selector( toggleHorizontalFlip: ) ||
				action == @selector( toggleVerticalFlip: ) ||
				action == @selector(curveFit:) ||
				action == @selector(reversePath:))
		return ![self locked];
	
	if( action == @selector( convertToTrack: ))
		return ![self locked] && [self canConvertToTrack] && [self respondsToSelector:action];
	
	if( action == @selector(closePath:))
		return ![self locked] && ![self isPathClosed];

	return [super validateMenuItem:item];
}


@end
