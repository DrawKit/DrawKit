/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import "DKDrawablePath.h"
#import "DKShapeGroup.h"
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
#include <tgmath.h>

#pragma mark Global Vars
NSPoint gMouseForPathSnap = { 0, 0 };

NSString* kDKPathOnPathHitDetectionPriorityDefaultsKey = @"kDKPathOnPathHitDetectionPriority";

#pragma mark Static Vars
static CGFloat sAngleConstraint = 0.261799387799; // 15 degrees
static NSColor* sInfoWindowColour = nil;

@interface DKSecretSelectorsDrawablePath : NSObject
-(IBAction)convertToTrack:(id)sender;
@end

@interface DKDrawablePath ()

/**  */
- (void)showLengthInfo:(CGFloat)dist atPoint:(NSPoint)p;

@end

#pragma mark -
@implementation DKDrawablePath

+ (void)setAngularConstraintAngle:(CGFloat)radians
{
	sAngleConstraint = radians;
}

+ (CGFloat)angularConstraintAngle
{
	return sAngleConstraint;
}

- (BOOL)constrainWithEvent:(NSEvent*)anEvent
{
	return (([anEvent modifierFlags] & NSShiftKeyMask) != 0);
}

#pragma mark As a DKDrawablePath

/** @brief Creates a drawable path object for an existing NSBezierPath

 Convenience method allows you to turn any path into a drawable that can be added to a drawing
 @param path the path to use
 @return a new drawable path object which has the path supplied
 */
+ (DKDrawablePath*)drawablePathWithBezierPath:(NSBezierPath*)path
{
	DKDrawablePath* dp = [[self alloc] initWithBezierPath:path];

	return dp;
}

//*********************************************************************************************************************

/** @brief Creates a drawable path object for an existing NSBezierPath and style

 Convenience method allows you to turn any path into a drawable that can be added to a drawing
 @param path the path to use
 @param aStyle a style to apply to the path
 @return a new drawable path object which has the path supplied
 */
+ (DKDrawablePath*)drawablePathWithBezierPath:(NSBezierPath*)path withStyle:(DKStyle*)aStyle
{
	DKDrawablePath* dp = [[self alloc] initWithBezierPath:path
													style:aStyle];
	return dp;
}

//*********************************************************************************************************************

/** @brief Set the background colour to use for the info window displayed when interacting with paths
 @param colour the colour to use
 */
+ (void)setInfoWindowBackgroundColour:(NSColor*)colour
{
	sInfoWindowColour = colour;
}

//*********************************************************************************************************************

/** @brief Return the background colour to use for the info window displayed when interacting with paths
 @return the colour to use
 */
+ (NSColor*)infoWindowBackgroundColour
{
	return sInfoWindowColour;
}

//*********************************************************************************************************************

/** @brief Set whether the default hit-detection behaviour is to prioritise on-path points or off-path points

 Affects hit-detection when on-path and off-path points are coincident. Normally off-path points
 have priority, but an alternative approach is to have on-path points have priority, and the off-path
 points require the use of the command modifier key to be hit-detected. DK has previously always
 prioritised off-path points, but this setting allows you to change that for your app.
 @param priority if YES, on-path points have priority by default. 
 */
+ (void)setDefaultOnPathHitDetectionPriority:(BOOL)priority
{
	[[NSUserDefaults standardUserDefaults] setBool:priority
											forKey:kDKPathOnPathHitDetectionPriorityDefaultsKey];
}

//*********************************************************************************************************************

/** @brief Returns whether the default hit-detection behaviour is to prioritise on-path points or off-path points

 Affects hit-detection when on-path and off-path points are coincident. Normally off-path points
 have priority, but an alternative approach is to have on-path points have priority, and the off-path
 points require the use of the command modifier key to be hit-detected. DK has previously always
 prioritised off-path points, but this setting allows you to change that for your app.
 @return if YES, on-path points have priority by default
 */
+ (BOOL)defaultOnPathHitDetectionPriority
{
	return [[NSUserDefaults standardUserDefaults] boolForKey:kDKPathOnPathHitDetectionPriorityDefaultsKey];
}

#pragma mark -

/** @brief Initialises a drawable path object from an existing path

 The path is retained, not copied
 @param aPath the path to use
 @return the drawable path object
 */
- (instancetype)initWithBezierPath:(NSBezierPath*)aPath
{
	self = [self init];
	if (self != nil) {
		[self setPath:aPath];
	}

	return self;
}

/** @brief Initialises a drawable path object from an existing path with the given style

 The path is retained, not copied
 @param aPath the path to use
 @param aStyle the style to use
 @return the drawable path object
 */
- (instancetype)initWithBezierPath:(NSBezierPath*)aPath style:(DKStyle*)aStyle
{
	self = [self initWithStyle:aStyle];
	if (self) {
		[self setPath:aPath];
	}

	return self;
}

#pragma mark -

/** @brief Sets the object's path to the given NSBezierPath

 Path is edited in place, so pass in a copy if necessary. This method doesn't do the copy since
 the creation of paths require this method to keep the same object during the operation.
 @param path a path
 */
- (void)setPath:(NSBezierPath*)path
{
	if (path != m_path) {
		//	LogEvent_(kStateEvent, @"setting path: %@", path );

		NSRect oldBounds = [self bounds];

		[self notifyVisualChange];

		NSBezierPath* oldPath = [m_path copy];
		[[self undoManager] registerUndoWithTarget:self
										  selector:@selector(setPath:)
											object:oldPath];

		m_path = path;

		[self notifyVisualChange];
		[self notifyGeometryChange:oldBounds];
	}
}

/** @brief Returns the object's current path
 @return the NSBezierPath
 */
- (NSBezierPath*)path
{
	return m_path;
}

/** @brief Returns the actual path drawn when the object is rendered

 Called by -drawSelectedState
 @param path the path to draw
 @param knobs the knobs object that draws the handles on the path */
- (void)drawControlPointsOfPath:(NSBezierPath*)path usingKnobs:(DKKnob*)knobs
{
	// draws the control points of the entire path using the knobs supplied.

	NSBezierPathElement et;
	NSPoint ap[3];
	NSPoint lp;
	DKKnobType knobType;

	NSInteger i, ec = [path elementCount];
	lp = NSMakePoint(-1, -1);

	for (i = 0; i < ec; ++i) {
		et = [path elementAtIndex:i
				 associatedPoints:ap];

		if (et == NSCurveToBezierPathElement) {
			// three points to draw, plus some bars. If the on-path point priority is set, draw on-path points on top,
			// otherwise draw off-path points on top.

			// draw the bar - always behind the knobs whatever the priority

			if (![self locked])
				[knobs drawControlBarFromPoint:ap[1]
									   toPoint:ap[2]];

			// draw on-path point behind

			if (![[self class] defaultOnPathHitDetectionPriority]) {
				knobType = kDKOnPathKnobType;

				if (!NSEqualPoints(lp, NSMakePoint(-1, -1))) {
					if ([self locked])
						knobType |= kDKKnobIsDisabledFlag;
					else
						[knobs drawControlBarFromPoint:ap[0]
											   toPoint:lp];

					[knobs drawKnobAtPoint:lp
									ofType:knobType
								  userInfo:nil];

					if (i == ec - 1)
						[knobs drawKnobAtPoint:ap[2]
										ofType:knobType
									  userInfo:nil];
				}
			}

			// draw off-path points for unlocked paths

			knobType = kDKControlPointKnobType;

			if (![self locked]) {
				[knobs drawKnobAtPoint:ap[0]
								ofType:knobType
							  userInfo:nil];
				[knobs drawKnobAtPoint:ap[1]
								ofType:knobType
							  userInfo:nil];
			}

			knobType = kDKOnPathKnobType;
			if ([self locked])
				knobType |= kDKKnobIsDisabledFlag;

			// draw on-path point in front

			if ([[self class] defaultOnPathHitDetectionPriority]) {
				if (!NSEqualPoints(lp, NSMakePoint(-1, -1))) {
					if (![self locked])
						[knobs drawControlBarFromPoint:ap[0]
											   toPoint:lp];

					[knobs drawKnobAtPoint:lp
									ofType:knobType
								  userInfo:nil];
				}

				if (i == ec - 1)
					[knobs drawKnobAtPoint:ap[2]
									ofType:knobType
								  userInfo:nil];
			}

			lp = ap[2];

#ifdef qIncludeGraphicDebugging
			if (m_showPartcodes) {
				NSInteger j, pc;

				for (j = 0; j < 3; ++j) {
					pc = [self hitPart:ap[j]];
					[knobs drawPartcode:pc
								atPoint:ap[j]
							   fontSize:10];
				}
			}
#endif
		} else {
			// one point to draw. don't draw a moveto that is the last element

			BOOL drawit;

			drawit = !((et == NSMoveToBezierPathElement) && (i == (ec - 1)));

			if (drawit) {
				knobType = kDKOnPathKnobType;
				if ([self locked])
					knobType |= kDKKnobIsDisabledFlag;

				if (!NSEqualPoints(lp, NSMakePoint(-1, -1)))
					[knobs drawKnobAtPoint:lp
									ofType:knobType
								  userInfo:nil];

				[knobs drawKnobAtPoint:ap[0]
								ofType:knobType
							  userInfo:nil];
			}
			lp = ap[0];

#ifdef qIncludeGraphicDebugging
			if (m_showPartcodes) {
				NSInteger pc;

				pc = [self hitPart:ap[0]];
				[knobs drawPartcode:pc
							atPoint:ap[0]
						   fontSize:10];
			}
#endif
		}
	}
}

/** @brief Given a set of rects as NSValue objects, this invalidates them

 Used to optimize updates to an area that is much tighter to a complex path that the overall
 bounds would be, thus minimizing drawing. Factors in the current style's extra space. The optimization
 is not done if the style has a fill, because tearing can occur with some styles
 @param rects a set of rects as NSValue objects
 */
- (void)setNeedsDisplayForRects:(NSSet*)rects
{
	if ([[self style] hasFill] || [[self style] hasHatch]) {
		[self setNeedsDisplayInRect:[self bounds]];
	} else {
		if (rects != nil) {
			NSSize extra = [[self style] extraSpaceNeeded];

			// add in control knob sizes

			extra.width += 3;
			extra.height += 3;
			[[self layer] setNeedsDisplayInRects:rects
								withExtraPadding:extra];
		}
	}
}

/** @brief Return the length of the path

 Length is accurately computed by summing the segment distances.
 @return the path's length
 */
- (CGFloat)length
{
	return [[self path] length];
}

/** @brief Return the length along the path for a given point

 Points too far from the path return a value of -1. To be within range, the point needs to be within
 4 x the widest stroke drawn by the style, or 4 points, whichever is larger.
 @param mp a point somewhere close to the path
 @return a distance along the path nearest to the point
 */
- (CGFloat)lengthForPoint:(NSPoint)mp
{
	return [self lengthForPoint:mp
					  tolerance:MAX(1, [[self style] maxStrokeWidth]) * 4];
}

/** @brief Return the length along the path for a given point

 Points too far from the path return a value of -1. The point needs to be <tol> or less from the path.
 @param mp a point somewhere close to the path
 @param tol the tolerance value
 @return a distance along the path nearest to the point
 */
- (CGFloat)lengthForPoint:(NSPoint)mp tolerance:(CGFloat)tol
{
	return [[self path] distanceFromStartOfPathAtPoint:mp
											 tolerance:tol];
}

- (CGFloat)infoLengthForPath:(NSBezierPath*)path
{
	NSParameterAssert(path);
	return [path length];
}

- (void)recordPathForUndo
{
	m_undoPath = [[self path] copy];
}

- (NSBezierPath*)undoPath
{
	return m_undoPath;
}

- (void)clearUndoPath
{
	m_undoPath = nil;
}

#pragma mark -

/** @brief Merges two paths by simply appending them

 This simply appends the part of the other object to this one and recomputes the bounds, etc.
 the result can act like a union, difference or XOR according to the relative placements of the
 paths and the winding rules in use.
 @param anotherPath another drawable path object like this one
 */
- (void)combine:(DKDrawablePath*)anotherPath
{
	NSBezierPath* path = [[self path] copy];

	[path appendBezierPath:[anotherPath path]];
	[self setPath:path];
}

/** @brief Preflights a potential join to determine if the join would be made

 Allows a join operation to be preflighted without actually performing the join.
 @param anotherPath another drawable path object like this one
 @param tol a value used to determine if the end points are placed sufficiently close to be joinable
 @return a join result value, indicating which end(s) would be joined, if any
 */
- (DKDrawablePathJoinResult)wouldJoin:(DKDrawablePath*)anotherPath tolerance:(CGFloat)tol
{
	NSBezierPath* ap = [anotherPath path];
	DKDrawablePathJoinResult result = kDKPathNoJoin;

	if (anotherPath == nil || [ap isPathClosed] || [[self path] isPathClosed])
		return kDKPathNoJoin;

	// do the paths share an end point?

	CGFloat dist;
	NSInteger j, k;

	NSPoint p1[2];
	NSPoint p2[2];

	p1[0] = [[self path] firstPoint]; // head 1
	p1[1] = [[self path] lastPoint]; // tail 1
	p2[0] = [ap firstPoint]; // head 2
	p2[1] = [ap lastPoint]; // tail 2

	for (j = 0; j < 2; ++j) {
		for (k = 0; k < 2; ++k) {
			dist = hypot(p2[j].x - p1[k].x, p2[j].y - p1[k].y);

			if (dist <= tol) {
				// found points close enough to join. One path may need reversing to accomplish it.
				// this would be when joining two heads or two tails.

				if (k == 0)
					result = kDKPathOtherPathWasPrepended;
				else
					result = kDKPathOtherPathWasAppended;

				// test if both ends would be joined

				k = (k == 0) ? 1 : 0;
				j = (j == 0) ? 1 : 0;

				dist = hypot(p2[j].x - p1[k].x, p2[j].y - p1[k].y);

				if (dist <= tol)
					result = kDKPathBothEndsJoined;

				return result;
			}
		}
	}

	return result;
}

/** @brief Joins open paths together at their ends

 This attempts to join either or both ends of the two paths if they are placed sufficiently
 closely. Usually the higher level join action at the layer level will be used.
 @param anotherPath another drawable path object like this one
 @param tol a value used to determine if the end points are placed sufficiently close to be joinable
 @param colin if YES, and the joined segments are curves, this adjusts the control points of the curve
 @return a join result value, indicating which end(s) were joined, if any
 */
- (DKDrawablePathJoinResult)join:(DKDrawablePath*)anotherPath tolerance:(CGFloat)tol makeColinear:(BOOL)colin
{
	//	LogEvent_(kReactiveEvent, @"joining path, tolerance = %f", tol );

	NSBezierPath* ap = [anotherPath path];
	DKDrawablePathJoinResult result = kDKPathNoJoin;

	if ([ap isPathClosed] || [[self path] isPathClosed])
		return kDKPathNoJoin;

	// do the paths share an end point?

	CGFloat dist;
	NSInteger j, k;

	NSPoint p1[2];
	NSPoint p2[2];

	p1[0] = [[self path] firstPoint]; // head 1
	p1[1] = [[self path] lastPoint]; // tail 1
	p2[0] = [ap firstPoint]; // head 2
	p2[1] = [ap lastPoint]; // tail 2

	for (j = 0; j < 2; ++j) {
		for (k = 0; k < 2; ++k) {
			dist = hypot(p2[j].x - p1[k].x, p2[j].y - p1[k].y);

			if (dist <= tol) {
				// found points close enough to join. One path may need reversing to accomplish it.
				// this would be when joining two heads or two tails.

				if (k == j)
					ap = [ap bezierPathByReversingPath];

				// join to whichever path has the tail aligned

				NSBezierPath* newPath;
				NSInteger ec;

				if (k == 0) {
					newPath = [ap copy];
					ec = [newPath elementCount] - 1;
					[newPath appendBezierPathRemovingInitialMoveToPoint:[self path]];

					result = kDKPathOtherPathWasPrepended;
				} else {
					// copy existing path rather than append directly - this ensures the operation is
					// undoable.

					newPath = [[self path] copy];
					ec = [newPath elementCount] - 1;
					[newPath appendBezierPathRemovingInitialMoveToPoint:ap];

					result = kDKPathOtherPathWasAppended;
				}

				if (colin) {
					// colinearise the join if the segments joined are both curvetos

					NSPoint elp[6];
					NSBezierPathElement el = [newPath elementAtIndex:ec
													associatedPoints:elp];
					NSBezierPathElement fl = [newPath elementAtIndex:ec + 1
													associatedPoints:&elp[3]];

					if ((el == fl) && (el == NSCurveToBezierPathElement)) {
						[NSBezierPath colineariseVertex:&elp[1]
													cpA:&elp[1]
													cpB:&elp[3]];

						[newPath setAssociatedPoints:elp
											 atIndex:ec];
						[newPath setAssociatedPoints:&elp[3]
											 atIndex:ec + 1];
					}
				}

				// if the other ends are also aligned, close the path

				k = (k == 0) ? 1 : 0;
				j = (j == 0) ? 1 : 0;

				dist = hypot(p2[j].x - p1[k].x, p2[j].y - p1[k].y);

				if (dist <= tol) {
					[newPath closePath];

					result = kDKPathBothEndsJoined;

					if (colin) {
						// colinearise the join if the segments joined are both curvetos

						ec = [newPath elementCount] - 3;

						NSPoint elp[6];
						NSBezierPathElement el = [newPath elementAtIndex:ec
														associatedPoints:elp];
						NSBezierPathElement fl = [newPath elementAtIndex:1
														associatedPoints:&elp[3]];

						if ((el == fl) && (el == NSCurveToBezierPathElement)) {
							[NSBezierPath colineariseVertex:&elp[1]
														cpA:&elp[1]
														cpB:&elp[3]];

							[newPath setAssociatedPoints:elp
												 atIndex:ec];
							[newPath setAssociatedPoints:&elp[3]
												 atIndex:1];
						}
					}
				}

				[self setPath:newPath];

				return result;
			}
		}
	}

	return kDKPathNoJoin;
}

/** @brief Converts each subpath in the current path to a separate object

 A subpath is a path delineated by a moveTo opcode. Each one is made a separate new path. If there
 is only one subpath (common) then the result will have just one entry.
 @return an array of DKDrawablePath objects
 */
- (NSArray*)breakApart
{
	// returns a list of path objects each containing one subpath from this object's path. If this path only has one subpath, this
	// returns one object in the array which is equivalent to a copy.

	NSArray* subpaths = [[self path] subPaths];
	NSMutableArray* newObjects;
	DKDrawablePath* dp;

	newObjects = [[NSMutableArray alloc] init];

	for (NSBezierPath* pp in subpaths) {
		if (![pp isEmpty]) {
			dp = [[self class] drawablePathWithBezierPath:pp];

			[dp setStyle:[self style]];
			[dp setUserInfo:[self userInfo]];
			[newObjects addObject:dp];
		}
	}

	return newObjects;
}

/** @brief Splits a path into two paths at a specific point

 The new path has the same style and user info as the original, but is not added to the layer
 by this method. If <distance> is <= 0 or >= length, nil is returned.
 @param distance the position from the start of the path to make the split
 @return a new path, being the section of the original path from <distance> to the end.
 */
- (DKDrawablePath*)dividePathAtLength:(CGFloat)distance
{
	if (distance > 0) {
		CGFloat length = [self length];

		if (distance < length) {
			NSBezierPath* remainingPath = [[self path] bezierPathByTrimmingFromLength:distance];
			NSBezierPath* newPath = [[self path] bezierPathByTrimmingToLength:distance];

			[self setPath:newPath];

			// create a new path object for the remainder path

			DKDrawablePath* path = [[[self class] alloc] initWithBezierPath:remainingPath];

			// copy over all the various gubbins we neeed to:

			[path setStyle:[self style]];
			[path addUserInfo:[self userInfo]];
			[path setGhosted:[self isGhosted]];

			return path;
		}
	}

	return nil;
}

#pragma mark -

@synthesize pathCreationMode = m_editPathMode;

#pragma mark -

/** @brief Event loop for creating a curved path point by point

 Keeps control until the ending criteria are met (double-click or click on first point).
 @param initialPoint where to start
 */
- (void)pathCreateLoop:(NSPoint)initialPoint
{
	// when we create a path, we capture the mouse on the first mouse down and don't return until the path is complete. This is necessary because
	// the layer isn't designed to handle this type of multi-click behaviour by itself.

	// on entry, the path shouldn't yet exist.

	NSEvent* theEvent;
	NSInteger mask = NSLeftMouseDownMask | NSLeftMouseUpMask | NSLeftMouseDraggedMask | NSMouseMovedMask | NSPeriodicMask | NSScrollWheelMask | NSKeyDownMask;
	NSView* view = [[self layer] currentView];
	BOOL loop = YES;
	BOOL first = YES;
	NSInteger element, partcode;
	NSPoint p, ip, centre, opp, nsp;

	p = ip = [self snappedMousePoint:initialPoint
					 withControlFlag:NO];

	LogEvent_(kReactiveEvent, @"entering path create loop");

	NSBezierPath* path = [NSBezierPath bezierPath];

	[path moveToPoint:p];
	[path curveToPoint:p
		 controlPoint1:p
		 controlPoint2:p];
	[self setPath:path];

	element = 1;
	partcode = partcodeForElementControlPoint(element, 1);

	while (loop) {
		theEvent = [NSApp nextEventMatchingMask:mask
									  untilDate:[NSDate distantFuture]
										 inMode:NSEventTrackingRunLoopMode
										dequeue:YES];

		// look for any special key codes that we want to detect

		if ([theEvent type] == NSKeyDown) {
			unsigned short code = [theEvent keyCode];

			if (code == 0x33) // delete key
			{
				if (element > 1) {
					// back up to the previously placed point.

					path = [path bezierPathByRemovingTrailingElements:1];
					partcode = partcodeForElementControlPoint(--element, 2);
					[path setControlPoint:p
							  forPartcode:partcode];
					[self setPath:path];
				}
				continue;
			}
		}

		p = nsp = [view convertPoint:[theEvent locationInWindow]
							fromView:nil];
		p = [self snappedMousePoint:p
					withControlFlag:NO];

		if ([self shouldEndPathCreationWithEvent:theEvent]) {
			// if the event isn't a mouse event, post a mouse up which the creation tool needs to complete the object creation

			if ([theEvent type] == NSKeyDown)
				theEvent = [self postMouseUpAtPoint:p];

			NSRect tr = NSMakeRect(ip.x - 3.0, ip.y - 3.0, 6.0, 6.0);

			if (NSPointInRect(p, tr)) {
				loop = NO;
				[path setControlPoint:p
						  forPartcode:partcode];

				// set cp2 to the colinear opposite of cp1 of element 1

				centre = [path controlPointForPartcode:partcodeForElement(0)];

				opp = [NSBezierPath colinearPointForPoint:[path controlPointForPartcode:partcodeForElementControlPoint(1, 0)]
											  centrePoint:centre];
				[path setControlPoint:opp
						  forPartcode:partcodeForElementControlPoint(element, 1)];
			}

			goto finish;
		}

		switch ([theEvent type]) {
		case NSLeftMouseDown: {
			// when the mouse goes down we start a new segment unless we hit the first point in which case we
			// terminate the loop

			NSRect tr = NSMakeRect(ip.x - 3.0, ip.y - 3.0, 6.0, 6.0);

			if (NSPointInRect(p, tr)) {
				loop = NO;
				[path setControlPoint:p
						  forPartcode:partcode];

				// set cp2 to the colinear opposite of cp1 of element 1

				centre = [path controlPointForPartcode:partcodeForElement(0)];

				opp = [NSBezierPath colinearPointForPoint:[path controlPointForPartcode:partcodeForElementControlPoint(1, 0)]
											  centrePoint:centre];
				[path setControlPoint:opp
						  forPartcode:partcodeForElementControlPoint(element, 1)];
			} else {
				[path curveToPoint:p
					 controlPoint1:p
					 controlPoint2:p];
				++element;
				partcode = partcodeForElementControlPoint(element, 2);
				first = NO;
			}
		} break;

		case NSLeftMouseDragged:
			// a mouse drag pulls out a curve segment with all three points set to <p>. The partcode and element are
			// already set
			[self notifyVisualChange];
			[view autoscroll:theEvent];
			[path setControlPoint:p
					  forPartcode:partcode];
			[path setControlPoint:p
					  forPartcode:partcodeForElementControlPoint(element, 1)];
			[path setControlPoint:p
					  forPartcode:partcodeForElementControlPoint(element, 0)];

			if (!first) {
				// also affects the previous cp2 colinearly

				centre = [path controlPointForPartcode:partcodeForElementControlPoint(element - 1, 2)];
				opp = [NSBezierPath colinearPointForPoint:p
											  centrePoint:centre];

				[path setControlPoint:opp
						  forPartcode:partcodeForElementControlPoint(element - 1, 1)];
			}

			[self showLengthInfo:[self infoLengthForPath:path]
						 atPoint:nsp];
			break;

		case NSLeftMouseUp:
			partcode = partcodeForElementControlPoint(element, 2);
			break;

		case NSMouseMoved:
			[self notifyVisualChange];
			[view autoscroll:theEvent];
			[path setControlPoint:p
					  forPartcode:partcode];
			[path setControlPoint:p
					  forPartcode:partcodeForElementControlPoint(element, 1)];
			[self showLengthInfo:[self infoLengthForPath:path]
						 atPoint:nsp];
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

	[NSApp discardEventsMatchingMask:NSAnyEventMask
						 beforeEvent:theEvent];

	[self setPath:[path bezierPathByStrippingRedundantElements]];
	[self setPathCreationMode:kDKPathCreateModeEditExisting];
}

/** @brief Event loop for creating a single straight line

 Keeps control until the ending criteria are met (second click).
 @param initialPoint where to start
 */
- (void)lineCreateLoop:(NSPoint)initialPoint
{
	// creates a single straight line path, with only one segment. There are two ways a user can make a line - click and release,
	// move, then click. Or click-drag-release.

	NSEvent* theEvent;
	NSInteger mask = NSLeftMouseDownMask | NSLeftMouseUpMask | NSLeftMouseDraggedMask | NSMouseMovedMask | NSPeriodicMask | NSScrollWheelMask;
	NSView* view = [[self layer] currentView];
	BOOL loop = YES, constrain = NO;
	NSInteger element, partcode;
	NSPoint p, ip, nsp;
	CGFloat angleConstraint = [self.class angularConstraintAngle];

	p = ip = [self snappedMousePoint:initialPoint
					 withControlFlag:NO];

	LogEvent_(kReactiveEvent, @"entering line create loop");

	NSBezierPath* path = [NSBezierPath bezierPath];

	[path moveToPoint:p];
	[path lineToPoint:p];
	[self setPath:path];

	element = 1;
	partcode = partcodeForElement(element);

	while (loop) {
		theEvent = [NSApp nextEventMatchingMask:mask
									  untilDate:[NSDate distantFuture]
										 inMode:NSEventTrackingRunLoopMode
										dequeue:YES];

		p = nsp = [view convertPoint:[theEvent locationInWindow]
							fromView:nil];
		p = [self snappedMousePoint:p
					withControlFlag:NO];

		constrain = [self constrainWithEvent:theEvent];

		if (constrain) {
			// slope of line is forced to be on 15 degree intervals

			CGFloat angle = atan2(p.y - ip.y, p.x - ip.x);
			CGFloat rem = fmod(angle, angleConstraint);
			CGFloat radius = hypot(p.x - ip.x, p.y - ip.y);

			if (rem > angleConstraint / 2.0)
				angle += (angleConstraint - rem);
			else
				angle -= rem;

			p.x = ip.x + (radius * cos(angle));
			p.y = ip.y + (radius * sin(angle));
		}

		switch ([theEvent type]) {
		case NSLeftMouseDown:
			loop = NO;
			break;

		case NSLeftMouseDragged:
			[self notifyVisualChange];
			[view autoscroll:theEvent];
			[path setControlPoint:p
					  forPartcode:partcode];
			[self showLengthInfo:[self infoLengthForPath:path]
						 atPoint:nsp];
			break;

		case NSLeftMouseUp:
			// if the final point is in the same place as the first point, do a click-drag-click creation. Otherwise
			// we've already dragged so finish.

			if (!NSEqualPoints(p, ip)) {
				loop = NO;
			}
			break;

		case NSMouseMoved:
			[self notifyVisualChange];
			[view autoscroll:theEvent];
			[path setControlPoint:p
					  forPartcode:partcode];
			[self showLengthInfo:[self infoLengthForPath:path]
						 atPoint:nsp];
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

	[NSApp discardEventsMatchingMask:NSAnyEventMask
						 beforeEvent:theEvent];

	[self setPathCreationMode:kDKPathCreateModeEditExisting];
	[self notifyVisualChange];
	[self postMouseUpAtPoint:p];
}

/** @brief Event loop for creating a polygon consisting of straight line sections

 Keeps control until the ending criteria are met (double-click or click on start point).
 @param initialPoint where to start
 */
- (void)polyCreateLoop:(NSPoint)initialPoint
{
	// creates a polygon or multi-segment line. Each click makes a new node, double-click or click in first point to finish.

	NSEvent* theEvent;
	NSInteger mask = NSLeftMouseDownMask | NSMouseMovedMask | NSPeriodicMask | NSScrollWheelMask | NSKeyDownMask;
	NSView* view = [[self layer] currentView];
	BOOL loop = YES, constrain = NO;
	NSInteger element, partcode;
	NSPoint p, ip, lp, nsp;

	p = ip = [self snappedMousePoint:initialPoint
					 withControlFlag:NO];

	LogEvent_(kReactiveEvent, @"entering poly create loop");

	// if we are extending an existing path, start with that path and its open endpoint. Otherwise start from scratch

	NSBezierPath* path;

	if (m_extending && ![self isPathClosed]) {
		path = [self path];
		element = [path elementCount];
	} else {
		path = [NSBezierPath bezierPath];

		[path moveToPoint:p];
		[path lineToPoint:p];
		[self setPath:path];

		element = 1;
	}

	partcode = partcodeForElement(element);
	lp = ip;

	//[NSEvent startPeriodicEventsAfterDelay:0.5 withPeriod:0.1];

	while (loop) {
		theEvent = [NSApp nextEventMatchingMask:mask
									  untilDate:[NSDate distantFuture]
										 inMode:NSEventTrackingRunLoopMode
										dequeue:YES];

		// look for any special key codes that we want to detect

		if ([theEvent type] == NSKeyDown) {
			unsigned short code = [theEvent keyCode];

			if (code == 0x33) // delete key
			{
				if (element > 1) {
					// back up to the previously placed point.

					path = [path bezierPathByRemovingTrailingElements:1];
					partcode = partcodeForElement(--element);
					lp = [path controlPointForPartcode:partcodeForElement(element - 1)];
					[path setControlPoint:p
							  forPartcode:partcode];
					[self setPath:path];
				}
				continue;
			}
		}

		if ([self shouldEndPathCreationWithEvent:theEvent]) {
			if ([theEvent type] == NSKeyDown)
				theEvent = [self postMouseUpAtPoint:p];
			else
				path = [path bezierPathByRemovingTrailingElements:1];

			NSRect tr = NSMakeRect(ip.x - 3.0, ip.y - 3.0, 6.0, 6.0);

			if (NSPointInRect(p, tr)) {
				path = [path bezierPathByRemovingTrailingElements:1];
				[path closePath];
			}
			goto finish;
		}

		p = nsp = [view convertPoint:[theEvent locationInWindow]
							fromView:nil];
		p = [self snappedMousePoint:p
					withControlFlag:NO];

		constrain = (([theEvent modifierFlags] & NSShiftKeyMask) != 0);

		if (constrain) {
			// slope of line is forced to be on 15 degree intervals

			CGFloat angle = atan2(p.y - lp.y, p.x - lp.x);
			CGFloat rem = fmod(angle, sAngleConstraint);
			CGFloat radius = hypot(p.x - lp.x, p.y - lp.y);

			if (rem > sAngleConstraint / 2.0)
				angle += (sAngleConstraint - rem);
			else
				angle -= rem;

			p.x = lp.x + (radius * cos(angle));
			p.y = lp.y + (radius * sin(angle));
		}

		switch ([theEvent type]) {
		case NSLeftMouseDown: {
			NSRect tr = NSMakeRect(ip.x - 3.0, ip.y - 3.0, 6.0, 6.0);

			if (NSPointInRect(p, tr)) {
				loop = NO;
				path = [path bezierPathByRemovingTrailingElements:1];
				[path closePath];
			} else {
				lp = p;

				[path lineToPoint:p];
				partcode = partcodeForElement(++element);
			}
		} break;

		case NSMouseMoved:
			[view autoscroll:theEvent];
			[self notifyVisualChange];
			[path setControlPoint:p
					  forPartcode:partcode];
			[self showLengthInfo:[self infoLengthForPath:path]
						 atPoint:nsp];
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

	[NSApp discardEventsMatchingMask:NSAnyEventMask
						 beforeEvent:theEvent];

	[self setPath:path];

	[self setPathCreationMode:kDKPathCreateModeEditExisting];
	[self notifyVisualChange];
}

/** @brief Event loop for creating a curved path by fitting it to a series of sampled points

 Keeps control until the ending criteria are met (mouse up).
 @param initialPoint where to start
 */
- (void)freehandCreateLoop:(NSPoint)initialPoint
{
	// this works by building a freehand vector path (line segments) then smoothing it using curve fitting at the end.

	NSEvent* theEvent;
	NSInteger mask = NSLeftMouseDownMask | NSLeftMouseUpMask | NSLeftMouseDraggedMask | NSPeriodicMask | NSScrollWheelMask;
	NSView* view = [[self layer] currentView];
	BOOL loop = YES;
	NSPoint p, lastPoint;

	p = lastPoint = initialPoint;

	LogEvent_(kReactiveEvent, @"entering freehand create loop");

	NSBezierPath* path = [NSBezierPath bezierPath];

	[path moveToPoint:p];
	[self setPath:path];

	while (loop) {
		theEvent = [NSApp nextEventMatchingMask:mask
									  untilDate:[NSDate distantFuture]
										 inMode:NSEventTrackingRunLoopMode
										dequeue:YES];

		p = [view convertPoint:[theEvent locationInWindow]
					  fromView:nil];

		BOOL shiftKey = ([theEvent modifierFlags] & NSShiftKeyMask) != 0;

		p = [self snappedMousePoint:p
					withControlFlag:shiftKey];

		switch ([theEvent type]) {
		case NSLeftMouseDown:
			loop = NO;
			break;

		case NSLeftMouseDragged:
			if (!NSEqualPoints(p, lastPoint)) {
				[path lineToPoint:p];
#ifdef qUseCurveFit
				[self setPath:DKCurveFitPath(path, m_freehandEpsilon)];
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

	[NSApp discardEventsMatchingMask:NSAnyEventMask
						 beforeEvent:theEvent];

	[self setPathCreationMode:kDKPathCreateModeEditExisting];
	[self notifyVisualChange];

	[view mouseUp:theEvent];
}

/** @brief Event loop for creating an arc or a wedge

 Keeps control until the ending criteria are met (second click).
 @param initialPoint where to start
 */
- (void)arcCreateLoop:(NSPoint)initialPoint
{
	// creates a circle segment. First click sets the centre, second the first radius, third the second radius.

	NSEvent* theEvent;
	NSInteger mask = NSLeftMouseDownMask | NSMouseMovedMask | NSPeriodicMask | NSScrollWheelMask;
	NSView* view = [[self layer] currentView];
	BOOL loop = YES, constrain = NO;
	NSInteger element, partcode, phase;
	NSPoint p, centre, lp, nsp;
	CGFloat radius = 0.0;
	CGFloat startAngle = 0.0;
	CGFloat endAngle;
	DKStyle* savedStyle = nil;
	NSString* abbrUnits = [[self drawing] abbreviatedDrawingUnits];

	savedStyle = [self style];
	[self setStyle:[DKStyle styleWithFillColour:nil
								   strokeColour:[NSColor redColor]
									strokeWidth:2.0]];

	p = centre = [self snappedMousePoint:initialPoint
						 withControlFlag:NO];
	phase = 0; // set radius

	LogEvent_(kReactiveEvent, @"entering arc create loop");

	NSBezierPath* path = [NSBezierPath bezierPath];

	[path moveToPoint:p];
	[path lineToPoint:p]; // begin rubber band of first line segment
	[self setPath:path];

	element = 1;
	partcode = partcodeForElement(element);
	lp = centre;

	while (loop) {
		theEvent = [NSApp nextEventMatchingMask:mask
									  untilDate:[NSDate distantFuture]
										 inMode:NSEventTrackingRunLoopMode
										dequeue:YES];

		nsp = [view convertPoint:[theEvent locationInWindow]
						fromView:nil];
		p = [self snappedMousePoint:nsp
					withControlFlag:NO];

		constrain = (([theEvent modifierFlags] & NSShiftKeyMask) != 0);

		if (constrain) {
			// slope of line is forced to be on 15¬¨¬®‚Äö√†√ª intervals

			CGFloat angle = atan2(p.y - lp.y, p.x - lp.x);
			CGFloat rem = fmod(angle, sAngleConstraint);
			CGFloat rad = hypot(p.x - lp.x, p.y - lp.y);

			if (rem > sAngleConstraint / 2.0)
				angle += (sAngleConstraint - rem);
			else
				angle -= rem;

			p.x = lp.x + (rad * cos(angle));
			p.y = lp.y + (rad * sin(angle));
		}

		switch ([theEvent type]) {
		case NSLeftMouseDown: {
			if (phase == 0) {
				// set radius as the distance from this click to the centre, and the
				// start angle based on the slope of this line

				radius = hypot(p.x - centre.x, p.y - centre.y);
				startAngle = (atan2(p.y - centre.y, p.x - centre.x) * 180.0) / M_PI;
				++phase; // now setting the arc
			} else
				loop = NO;
		} break;

		case NSMouseMoved:
			[self notifyVisualChange];
			[view autoscroll:theEvent];
			if (phase == 0) {
				[path setControlPoint:p
						  forPartcode:partcode];
				radius = hypot(p.x - centre.x, p.y - centre.y);

				if ([[self class] displaysSizeInfoWhenDragging]) {
					CGFloat rad = [[self drawing] convertLength:radius];
					p.x += 4;
					p.y -= 12;

					[[self layer] showInfoWindowWithString:[NSString stringWithFormat:@"radius: %.2f%@", rad, abbrUnits]
												   atPoint:nsp];
				}
			} else if (phase == 1) {
				endAngle = (atan2(p.y - centre.y, p.x - centre.x) * 180.0) / M_PI;

				[self setStyle:savedStyle];
				[path removeAllPoints];
				if ([self pathCreationMode] == kDKPathCreateModeWedgeSegment)
					[path moveToPoint:centre];

				[path appendBezierPathWithArcWithCenter:centre
												 radius:radius
											 startAngle:startAngle
											   endAngle:endAngle];

				if ([self pathCreationMode] == kDKPathCreateModeWedgeSegment)
					[path closePath];
				[self setPath:path];

				if ([[self class] displaysSizeInfoWhenDragging]) {
					CGFloat rad = [[self drawing] convertLength:radius];
					CGFloat angle = endAngle - startAngle;

					if (angle < 0)
						angle = 360.0 + angle;

					p.x += 4;
					p.y -= 12;

					[[self layer] showInfoWindowWithString:[NSString stringWithFormat:@"radius: %.2f%@\nangle: %.1f°", rad, abbrUnits, angle]
												   atPoint:nsp];
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

	[NSApp discardEventsMatchingMask:NSAnyEventMask
						 beforeEvent:theEvent];

	[self setPathCreationMode:kDKPathCreateModeEditExisting];
	[self setStyle:savedStyle];
	[self notifyVisualChange];

	[view mouseUp:theEvent];
}

/** @brief Overrideable hook at the end of path creation
 */
- (void)pathCreationLoopDidEnd
{
	// override when you need to hook into the end of path creation
}

#pragma mark -

/** @brief Test for the ending criterion of a path loop

 Currently only checks for a double-click
 @param event an event
 @return YES to end the loop, NO to continue
 */
- (BOOL)shouldEndPathCreationWithEvent:(NSEvent*)event
{
	// determine if path creation loop should be terminated - can be overridden to terminate differently.

	if ([event type] == NSLeftMouseDown)
		return ([event clickCount] >= 2);
	else if ([event type] == NSKeyDown)
		return YES;
	else
		return NO;
}

- (NSEvent*)postMouseUpAtPoint:(NSPoint)p
{
	NSView* view = [[self layer] currentView];
	p = [view convertPoint:p
					toView:nil];

	NSEvent* mouseUp = [NSEvent mouseEventWithType:NSLeftMouseUp
										  location:p
									 modifierFlags:0
										 timestamp:[NSDate timeIntervalSinceReferenceDate]
									  windowNumber:[[view window] windowNumber]
										   context:[NSGraphicsContext currentContext]
									   eventNumber:0
										clickCount:0
										  pressure:0.0];

	[NSApp postEvent:mouseUp
			 atStart:NO];
	return mouseUp;
}

/** @brief Discover whether the path is open or closed

 A path is closed if it has a closePath element or its first and last points are coincident.
 @return YES if the path is closed, NO if open
 */
- (BOOL)isPathClosed
{
	return [[self path] isPathClosed];
}

/** @brief Discover whether the given partcode is an open end point of the path

 A closed path always returns NO, as it has no open end points. An open path will return YES for
 only the first and last points.
 @param partcode a partcode to test
 @return YES if the partcode is one of the endpoints, NO otherwise
 */
- (BOOL)isOpenEndPoint:(NSInteger)partcode
{
	if (![self isPathClosed]) {
		if (partcode == partcodeForElement(0))
			return YES;

		if (partcode == [[self path] partcodeForLastPoint])
			return YES;
	}

	return NO;
}

@synthesize shouldExtendExistingPath=m_extending;

/** @brief Conditionally display the length info feedback window

 Distance is converted to drawing's current units, and point is converted to global. If the feedback
 display is disabled, does nothing.
 @param dist the distance to display
 @param p where to put the window
 */
- (void)showLengthInfo:(CGFloat)dist atPoint:(NSPoint)p
{
	if ([[self class] displaysSizeInfoWhenDragging]) {
		NSString* fmt = [[self drawing] formattedConvertedLength:dist];
		[[self layer] showInfoWindowWithString:fmt
									   atPoint:p];
	}
}

#pragma mark -

/** @brief Delete the point from the path with the given part code

 Only on-path points of a curve are allowed to be deleted, not control points. The partcodes will
 be renumbered by this, so do not cache the partcode beyond this point.
 @param pc the partcode to delete
 @return YES if the point could be deleted, NO if not */
- (BOOL)pathDeletePointWithPartCode:(NSInteger)pc
{
	// delete the point with the given partcode

	if (pc > kDKDrawingNoPart && [[self path] elementCount] > 2) {
		NSBezierPath* np = [[self path] deleteControlPointForPartcode:pc];

		if (np != [self path]) {
			[self setPath:np];
			return YES;
		}
	}

	return NO;
}

/** @brief Delete a segment from the path at the given index

 If the element id removed from the middle, the path is split into two subpaths. If removed at
 either end, the path is shortened. Partcodes will change.
 @param indx the index of the element to delete
 @return YES if the element was deleted, NO if not
 */
- (BOOL)pathDeleteElementAtIndex:(NSInteger)indx
{
	NSBezierPath* np = [[self path] bezierPathByRemovingElementAtIndex:indx];

	if (np != [self path]) {
		[self setPath:np];
		return YES;
	}

	return NO;
}

/** @brief Delete a segment from the path at the given point

 Finds the element hit by the point and calls -pathDeleteElementAtIndex:
 @param loc a point
 @return YES if the element was deleted, NO if not
 */
- (BOOL)pathDeleteElementAtPoint:(NSPoint)loc
{
	CGFloat tol = MAX(4.0, [[self style] maxStrokeWidth]);
	NSInteger indx = [[self path] elementHitByPoint:loc
										  tolerance:tol
											 tValue:NULL];

	if (indx != -1)
		return [self pathDeleteElementAtIndex:indx];

	return NO;
}

/** @brief Insert a new point into the path

 The inserted point must be "close" to the path - within its drawn stroke in fact.
 @param loc the point at which to insert a point
 @param pathPointType the type of point (curve or vertex) to insert
 @return the inserted point's new partcode, or 0 if the location was too far off the path. */
- (NSInteger)pathInsertPointAt:(NSPoint)loc ofType:(DKDrawablePathInsertType)pathPointType
{
	// insert a new point at the given location, returning the new point's partcode

	CGFloat tol = MAX(4.0, [[self style] maxStrokeWidth]);

	NSBezierPath* np = [[self path] insertControlPointAtPoint:loc
													tolerance:tol
														 type:pathPointType];

	if (np != nil) {
		[self setPath:np];
		return [np partcodeHitByPoint:loc
							tolerance:tol];
	}

	return kDKDrawingNoPart;
}

/** @brief Move a single control point to a new position

 Essential interactive editing method
 @param pc the partcode for the point to be moved
 @param mp the point to move it to
 @param evt the event (used to grab modifier flags) */
- (void)movePathPartcode:(NSInteger)pc toPoint:(NSPoint)mp event:(NSEvent*)evt
{
	if (pc < 4)
		return;

	BOOL option = (([evt modifierFlags] & NSAlternateKeyMask) != 0);
	BOOL cmd = (([evt modifierFlags] & NSCommandKeyMask) != 0);

	// modifier keys change the editing of path control points thus:

	// +shift	- constrains curve control point angles to 15 degree intervals
	// +option	- forces the control points either side of an on-path point to maintain the same radial distance
	// +cmd		- allows control points to be moved fully independently
	// +ctrl	- temporarily disables snap to grid

	NSRect oldBounds = [self bounds];

	// if cmd + option is down, cmd takes priority of +defaultOnPathHitDetectionPriority is NO, option takes priority if
	// it returns YES

	if (cmd && option) {
		if ([[self class] defaultOnPathHitDetectionPriority])
			cmd = NO;
	}

	[self notifyVisualChange];
	[[self path] moveControlPointPartcode:pc
								  toPoint:mp
								 colinear:!cmd
								 coradial:option
						   constrainAngle:[self constrainWithEvent:evt]];
	[self notifyGeometryChange:oldBounds];
	[self notifyVisualChange];
}

#pragma mark -

@synthesize freehandSmoothing=m_freehandEpsilon;

#pragma mark -

/** @brief Make a copy of the path into a shape object

 Called by -convertToShape, a higher level operation. Note that the actual class of object returned
 can be modified by customising the interconversion table.
 @return a DKDrawableShape object, identical to this
 */
- (DKDrawableShape*)makeShape
{
	NSBezierPath* mp = [[self path] copy];

	Class shapeClass = [DKDrawableObject classForConversionRequestFor:[DKDrawableShape class]];

	DKDrawableShape* so = [shapeClass drawableShapeWithBezierPath:mp
														withStyle:[self style]];
	[so setUserInfo:[self userInfo]];

	return so;
}

- (BOOL)canConvertToTrack
{
	return NO;
}

/** @brief Make a copy of the path but with a parallel offset
 @param distance the distance from the original that the path is offset (negative forupward displacement)
 @param smooth if YES, also smooths the resulting path
 @return a DKDrawablePath object
 */
- (DKDrawablePath*)makeParallelWithOffset:(CGFloat)distance smooth:(BOOL)smooth
{
	DKDrawablePath* newPath = [self copy];

	if (distance != 0.0) {
		NSBezierPath* np = [[self path] paralleloidPathWithOffset2:distance];

		if (smooth)
			np = [np bezierPathByInterpolatingPath:1.0];

		[newPath setPath:np];
	}

	return newPath;
}

#pragma mark -
#pragma mark - user level commands this object can respond to

/** @brief Converts this object to he equivalent shape

 Undoably replaces itself in its current layer by the equivalent shape object
 @param sender the action's sender
 */
- (IBAction)convertToShape:(id)sender
{
#pragma unused(sender)

	// replaces itself in the owning layer with a shape object with the same path.

	DKObjectDrawingLayer* layer = (DKObjectDrawingLayer*)[self layer];
	NSInteger myIndex = [layer indexOfObject:self];

	DKDrawableShape* so = [self makeShape];

	if (so) {
		[so willBeAddedAsSubstituteFor:self
							   toLayer:layer];

		[layer recordSelectionForUndo];
		[layer addObject:so
				 atIndex:myIndex];
		[layer replaceSelectionWithObject:so];
		[layer removeObject:self];
		[layer commitSelectionUndoWithActionName:NSLocalizedString(@"Convert To Shape", @"undo string for convert to shape")];
	} else
		NSBeep();
}

/** @brief Adds some random offset to every point on the path

 Just a fun effect
 @param sender the action's sender
 */
- (IBAction)addRandomNoise:(id)sender
{
#pragma unused(sender)

	// just for fun,this adds a little random offset to every control point on the path. For some paths (such as text) this produces
	// a fairly interesting effect.

	[self setPath:[[self path] bezierPathByRandomisingPoints:0.0]];
	[[self undoManager] setActionName:NSLocalizedString(@"Add Randomness", @"undo string for path add random")];
}

/** @brief Replaces the path with an outline of the path

 The result depends on the style - specifically the maximum stroke width. The path is replaced by
 a path whose edges are where the edge of the stroke of the original path lie. The topmost stroke
 is used to set the fill of the resulting object's style. The result is similar but not always
 identical to the original. For complex styles you will lose a lot of information.
 @param sender the action's sender
 */
- (IBAction)convertToOutline:(id)sender
{
#pragma unused(sender)

	NSBezierPath* path = [self path];

	CGFloat sw = [[self style] maxStrokeWidthDifference] / 2.0;
	[[self style] applyStrokeAttributesToPath:path];

	if (sw > 0.0)
		[path setLineWidth:[path lineWidth] - sw];

	path = [path strokedPath];
	[self setPath:path];

	// try to keep the appearance similar by creating a fill style with the same colour as the original's stroke

	NSArray* rs = [[self style] renderersOfClass:[DKStroke class]];
	if ([rs count] > 0) {
		DKStroke* stroke = [rs lastObject];
		DKStroke* firstStroke = [rs objectAtIndex:0];
		NSColor* strokeColour = nil;

		if (firstStroke != stroke)
			strokeColour = [firstStroke colour];

		DKStyle* newStyle = [DKStyle styleWithFillColour:[stroke colour]
											strokeColour:strokeColour];

		stroke = (DKStroke*)[[newStyle renderersOfClass:[DKStroke class]] lastObject];

		if (stroke)
			[stroke setWidth:sw];

		[self setStyle:newStyle];
	}

	[[self undoManager] setActionName:NSLocalizedString(@"Convert To Outline", @"undo string for convert to outline")];
}

/** @brief Replaces the object with new objects, one for each subpath in the original
 @param sender the action's sender
 */
- (IBAction)breakApart:(id)sender
{
#pragma unused(sender)

	NSArray* broken = [self breakApart];

	DKObjectDrawingLayer* odl = (DKObjectDrawingLayer*)[self layer];

	if (odl && [broken count] > 1) {
		for (DKDrawableObject* obj in broken) {
			[obj willBeAddedAsSubstituteFor:self
									toLayer:odl];
		}

		[odl recordSelectionForUndo];
		[odl addObjectsFromArray:broken];
		[odl removeObject:self];
		[odl exchangeSelectionWithObjectsFromArray:broken];
		[odl commitSelectionUndoWithActionName:NSLocalizedString(@"Break Apart", @"undo string for break apart")];
	}
}

- (IBAction)roughenPath:(id)sender
{
#pragma unused(sender)

	NSBezierPath* path = [self path];

	CGFloat sw = [[self style] maxStrokeWidthDifference] / 2.0;
	[[self style] applyStrokeAttributesToPath:path];

	if (sw > 0.0)
		[path setLineWidth:[path lineWidth] - sw];

	CGFloat roughness = [[self style] maxStrokeWidth] / 4.0;

	path = [path bezierPathWithRoughenedStrokeOutline:roughness];
	[self setPath:path];

	// try to keep the appearance similar by creating a fill style with the same colour as the original's stroke

	NSArray* rs = [[self style] renderersOfClass:[DKStroke class]];
	if ([rs count] > 0) {
		DKStroke* stroke = [rs lastObject];
		DKStroke* firstStroke = [rs objectAtIndex:0];
		NSColor* strokeColour = nil;

		if (firstStroke != stroke)
			strokeColour = [firstStroke colour];

		DKStyle* newStyle = [DKStyle styleWithFillColour:[stroke colour]
											strokeColour:strokeColour];

		stroke = (DKStroke*)[[newStyle renderersOfClass:[DKStroke class]] lastObject];

		if (stroke)
			[stroke setWidth:sw];

		[self setStyle:newStyle];
	}

	[[self undoManager] setActionName:NSLocalizedString(@"Roughen Path", @"undo string for roughen path")];
}

#ifdef qUseCurveFit

/** @brief Tries to smooth a path by curve fitting. If the path is already made up from bezier elements,
 this will have no effect. vector paths can benefit however.

 The current set smoothness value is used
 @param sender the action's sender
 */
- (IBAction)smoothPath:(id)sender
{
#pragma unused(sender)

	[self setPath:[[self path] bezierPathByInterpolatingPath:1.0]];
	[[self undoManager] setActionName:NSLocalizedString(@"Smooth Path", @"smooth path action name")];
}

/** @brief Tries to smooth a path by curve fitting. If the path is already made up from bezier elements,
 this will have no effect. vector paths can benefit however.

 The current set smoothness value x4 is used
 @param sender the action's sender
 */
- (IBAction)smoothPathMore:(id)sender
{
#pragma unused(sender)

	[self setPath:DKSmartCurveFitPath([self path], [self freehandSmoothing] * 4.0, 1.2)];
	[[self undoManager] setActionName:NSLocalizedString(@"Smooth More", @"smooth more action name")];
}
#endif /* defined(qUseCurveFit) */

/** @brief Adds a copy of the receiver to the drawing with a parallel offset path

 This is really just a test of the algorithm
 @param sender the action's sender
 */
- (IBAction)parallelCopy:(id)sender
{
#pragma unused(sender)

	DKDrawablePath* newPath = [self makeParallelWithOffset:30.0
													smooth:YES];

	DKObjectDrawingLayer* odl = (DKObjectDrawingLayer*)[self layer];

	if (odl) {
		[odl recordSelectionForUndo];
		[odl addObject:newPath];
		[odl exchangeSelectionWithObjectsFromArray:@[newPath]];
		[odl commitSelectionUndoWithActionName:NSLocalizedString(@"Parallel Copy", @"undo string for parallel copy")];
	}
}

/** @brief Attempts to curve-fit the object's path

 The path might not change, depending on how it is made up
 @param sender the action's sender
 */
- (IBAction)curveFit:(id) __unused sender
{
	if (![self locked]) {
		
		// Extracted from NSBezierPath+GPC in 1.5b of DrawKit
		NSBezierPath* originalPath = [self path];
		if ([originalPath isEmpty])
			return;
		NSSize ps = [originalPath bounds].size;
		CGFloat epsilon = MIN( ps.width, ps.height ) / 1000.0;
		NSBezierPath* newPath = DKSmartCurveFitPath( originalPath, epsilon, kDKDefaultCornerThreshold );
		if (newPath != nil) {
			[self setPath:newPath];
			[[self undoManager] setActionName:NSLocalizedString(@"Curve Fit", @"undo action for Curve Fit")];
		}
	}
}

/** @brief Reverses the direction of the object's path

 Does not change the path's appearance directly, but may depending on the current style, e.g. arrows
 will flip to the other end.
 @param sender the action's sender
 */
- (IBAction)reversePath:(id)sender
{
#pragma unused(sender)

	if (![self locked]) {
		NSBezierPath* newPath = [[self path] bezierPathByReversingPath];
		[self setPath:newPath];
		[[self undoManager] setActionName:NSLocalizedString(@"Reverse Path", @"undo action for Reverse Path")];
	}
}

/** @brief Flips the path horizontally

 The path is flipped directly
 @param sender the action's sender
 */
- (IBAction)toggleHorizontalFlip:(id)sender
{
#pragma unused(sender)

	NSPoint cp;

	cp.x = NSMidX([self bounds]);
	cp.y = NSMidY([self bounds]);

	NSBezierPath* np = [[self path] horizontallyFlippedPathAboutPoint:cp];

	NSAssert(np != nil, @"bad path when flipping");

	[self setPath:np];
	[[self undoManager] setActionName:NSLocalizedString(@"Flip Horizontally", @"h flip")];
}

/** @brief Flips the path vertically

 The path is flipped directly
 @param sender the action's sender
 */
- (IBAction)toggleVerticalFlip:(id)sender
{
#pragma unused(sender)

	NSPoint cp;

	cp.x = NSMidX([self bounds]);
	cp.y = NSMidY([self bounds]);

	NSBezierPath* np = [[self path] verticallyFlippedPathAboutPoint:cp];

	NSAssert(np != nil, @"bad path when flipping");

	[self setPath:np];
	[[self undoManager] setActionName:NSLocalizedString(@"Flip Vertically", @"v flip")];
}

/** @brief Closes the path if not already closed

 Paths created using the bezier tool are always left open by default
 @param sender the action's sender
 */
- (IBAction)closePath:(id)sender
{
#pragma unused(sender)

	if (![self isPathClosed] && ![self locked]) {
		NSBezierPath* path = [[self path] copy];
		[path closePath];
		[self setPath:path];
		[[self undoManager] setActionName:NSLocalizedString(@"Close Path", nil)];
	}
}

#pragma mark -
#pragma mark As a DKDrawableObject

/** @brief Return the partcode that should be used by tools when initially creating a new object

 The client of this method is DKObjectCreationTool.
 @return a partcode value - since paths start empty the 'no part' partcode is returned
 */
+ (NSInteger)initialPartcodeForObjectCreation
{
	return kDKDrawingNoPart;
}

+ (NSArray*)pasteboardTypesForOperation:(DKPasteboardOperationType)op
{
#pragma unused(op)
	return @[NSColorPboardType, NSStringPboardType, NSPDFPboardType, NSTIFFPboardType,
									 NSFilenamesPboardType, kDKStylePasteboardType, kDKStyleKeyPasteboardType];
}

/** @brief Initializes the drawable to have the style given

 You can use -init to initialize using the default style. Note that if creating many objects at
 once, supplying the style when initializing is more efficient.
 @param aStyle the initial style for the object
 @return the object
 */
- (instancetype)initWithStyle:(DKStyle*)aStyle
{
	self = [super initWithStyle:aStyle];
	if (self) {
		m_freehandEpsilon = 2.0;
		m_editPathMode = kDKPathCreateModeEditExisting;
	}

	return self;
}

/** @brief Returns the apparent (visual) bounds of the object

 Bounds is derived from the path directly
 @return a rectangle bounding the object
 */
- (NSRect)apparentBounds
{
	NSRect r = [[self renderingPath] bounds];

	if ([self style]) {
		NSSize allow = [[self style] extraSpaceNeeded];
		r = NSInsetRect(r, -allow.width, -allow.height);
	}
	return r;
}

/** @brief Returns the bounds of the object

 Bounds is derived from the path directly
 @return a rectangle bounding the object
 */
- (NSRect)bounds
{
	NSRect r;

	// get the true knob size so we can factor that in accurately

	NSRect kr = [[[self layer] knobs] controlKnobRectAtPoint:NSZeroPoint
													  ofType:kDKOnPathKnobType];

	CGFloat kbs = kr.size.width * 0.5;
	r = NSInsetRect([[self renderingPath] controlPointBounds], -kbs, -kbs);

	// factor in style allowance

	NSSize allow = [self extraSpaceNeeded];
	r = NSInsetRect(r, -allow.width, -allow.height);

	if (r.size.width < 1) {
		r.size.width = 1;
		r.origin.x = [self location].x - 0.5;
	}

	if (r.size.height < 1) {
		r.size.height = 1;
		r.origin.y = [self location].y - 0.5;
	}

	return r;
}

/** @brief Draws the object

 When hit-testing, substitutes a style that is easier to hit
 */
- (void)drawContent
{
	if ([self isBeingHitTested]) {
		// for easier hit-testing of very thin or offset paths, the path is stroked using a
		// centre-aligned 4pt or greater stroke. This is substituted on the fly here and never visible to the user.

		CGFloat strokeWidth = MAX(4, [[self style] maxStrokeWidth]);

		BOOL hasFill = [[self style] hasFill] || [[self style] hasHatch];

		DKStyle* temp = [DKStyle styleWithFillColour:hasFill ? [NSColor blackColor] : nil
										strokeColour:[NSColor blackColor]
										 strokeWidth:strokeWidth];
		[temp render:self];
	} else
		[super drawContent];
}

/** @brief Draws the seleciton highlight on the object when requested
 */
- (void)drawSelectedState
{
	// stroke the path using the standard selection

	@autoreleasepool {

		NSBezierPath* path = [self renderingPath];

		[self drawSelectionPath:path];
		[self drawControlPointsOfPath:path
						   usingKnobs:[[self layer] knobs]];

#ifdef qIncludeGraphicDebugging
		if (m_showBBox)
			[[self path] drawElementsBoundingBoxes];

#endif

	}
}

/** @brief Draw the ghosted content of the object

 The default simply strokes the rendering path at minimum width using the ghosting colour. Can be
 overridden for more complex appearances. Note that ghosting should deliberately keep the object
 unobtrusive and simple.
 */
- (void)drawGhostedContent
{
	[[[self class] ghostColour] set];
	NSBezierPath* rp = [self renderingPath];

	// if the path is usually drawn wider than 2, outline it

	if ([[self style] maxStrokeWidth] > 2)
		rp = [rp strokedPathWithStrokeWidth:[[self style] maxStrokeWidth]];

	[rp setLineWidth:0];
	[rp stroke];
}

/** @brief Determines the partcode hit by a given point

 Partcodes apart from 0 and -1 are private to this object
 @param pt a point
 @return an integer value, the partcode hit.
 */
- (NSInteger)hitPart:(NSPoint)pt
{
	NSInteger pc = [super hitPart:pt];

	if (pc == kDKDrawingEntireObjectPart) {
		// hit in bounds, refine by testing against controls/bitmap
		// if we have a fill, test for path contains as well:

		if ([[self style] hasFill] || [[self style] hasHatch]) {
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

/** @brief Determines the partcode hit by a given point

 Partcodes apart from 0 and -1 are private to this object
 @param pt a point
 @param snap YES if being called to determine snapping to the object, NO for normal mouse click
 @return an integer value, the partcode hit. */
- (NSInteger)hitSelectedPart:(NSPoint)pt forSnapDetection:(BOOL)snap
{
	CGFloat tol = [[[self layer] knobs] controlKnobSize].width;

	if (snap)
		tol *= 2;

	NSInteger pc;
	BOOL commandKey = ([[NSApp currentEvent] modifierFlags] & NSCommandKeyMask) != 0;
	;

	if ([[self class] defaultOnPathHitDetectionPriority])
		commandKey = !commandKey;

	pc = [[self path] partcodeHitByPoint:pt
							   tolerance:tol
				  prioritiseOnPathPoints:commandKey];

	// if snapping, ignore off-path points

	if (snap && ![[self path] isOnPathPartcode:pc])
		pc = 0;

	if (pc == 0) {
		pc = kDKDrawingEntireObjectPart;

		if (snap) {
			// for snapping to the nearest point on the path, return a special partcode value and cache the mouse point -
			// when pointForPartcode is called with this special code, locate the nearest path point and return it.

			if ([self pointHitsPath:pt]) {
				gMouseForPathSnap = pt;
				pc = kDKSnapToNearestPathPointPartcode;
			}
		}
	}
	return pc;
}

/** @brief Returns the logical bounds of the object

 Bounds is derived from the path directly
 @return a rectangle bounding the object ignoring any style attributes
 */
- (NSRect)logicalBounds
{
	return [[self renderingPath] bounds];
}

/** @brief Handles a mouse down in the object

 This is used mainly to grab the mousedown and start our internal creation loops according to
 which edit mode is set for the object.
 @param mp the mouse point
 @param partcode the partcode returned earlier by hitPart:
 @param evt the event this came from */
- (void)mouseDownAtPoint:(NSPoint)mp inPart:(NSInteger)partcode event:(NSEvent*)evt
{
	[[self layer] setInfoWindowBackgroundColour:[[self class] infoWindowBackgroundColour]];

	[self setTrackingMouse:YES];
	NSInteger mode = [self pathCreationMode];

	if ((partcode == kDKDrawingNoPart) && (mode != kDKPathCreateModeEditExisting)) {
		// these loops keep control until their logic dictates otherwise, so the other
		// mouse event handler methods won't be called

		switch (mode) {
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
		case kDKPathCreateModeFreehandCreate: {
			CGFloat savedFHE = [self freehandSmoothing];

			BOOL option = ([evt modifierFlags] & NSAlternateKeyMask) != 0;

			if (option)
				[self setFreehandSmoothing:10 * savedFHE];

			[self freehandCreateLoop:mp];
			[self setFreehandSmoothing:savedFHE];
		} break;
#endif
		case kDKPathCreateModeWedgeSegment:
		case kDKPathCreateModeArcSegment:
			[self arcCreateLoop:mp];
			break;

		default:
			break;
		}

		[self pathCreationLoopDidEnd];
	} else {
		if (partcode == kDKDrawingEntireObjectPart)
			[super mouseDownAtPoint:mp
							 inPart:partcode
							  event:evt];
		else {
			[self recordPathForUndo];
			[self setMouseHasMovedSinceStartOfTracking:NO];
		}
	}
}

/** @brief Handles a mouse drag in the object

 Used when editing an existing path, but not creating one
 @param mp the mouse point
 @param partcode the partcode returned earlier by hitPart:
 @param evt the event this came from */
- (void)mouseDraggedAtPoint:(NSPoint)mp inPart:(NSInteger)partcode event:(NSEvent*)evt
{
	if (partcode == kDKDrawingEntireObjectPart) {
		[super mouseDraggedAtPoint:mp
							inPart:partcode
							 event:evt];
	} else {
		BOOL ctrl = (([evt modifierFlags] & NSControlKeyMask) != 0);
		mp = [self snappedMousePoint:mp
					 withControlFlag:ctrl];
		[self movePathPartcode:partcode
					   toPoint:mp
						 event:evt];

		// if the class is set to show size info when resizing, set up an info window now to do that.

		if ([[self class] displaysSizeInfoWhenDragging]) {
			NSPoint gridPt = [self convertPointToDrawing:mp];
			NSString* abbrUnits = [[self drawing] abbreviatedDrawingUnits];

			[[self layer] showInfoWindowWithString:[NSString stringWithFormat:@"x: %.2f%@\ny: %.2f%@", gridPt.x, abbrUnits, gridPt.y, abbrUnits]
										   atPoint:mp];
		}

		[self setMouseHasMovedSinceStartOfTracking:YES];
	}
}

/** @brief Handles a mouseup in the object

 Used when editing an existing path, but not creating one
 @param mp the mouse point
 @param partcode the partcode returned earlier by hitPart:
 @param evt the event this came from */
- (void)mouseUpAtPoint:(NSPoint)mp inPart:(NSInteger)partcode event:(NSEvent*)evt
{
	if (partcode == kDKDrawingEntireObjectPart)
		[super mouseUpAtPoint:mp
					   inPart:partcode
						event:evt];
	else {
		if ([self mouseHasMovedSinceStartOfTracking] && [self undoPath]) {
			[[self undoManager] registerUndoWithTarget:self
											  selector:@selector(setPath:)
												object:[self undoPath]];
			[[self undoManager] setActionName:NSLocalizedString(@"Change Path", @"undo string for change path")];
			[self clearUndoPath];
		}
	}
	[[self layer] hideInfoWindow];
	[self notifyVisualChange];
	[self setTrackingMouse:NO];
}

/** @brief Moves the object to a new location
 @param p the new location
 */
- (void)setLocation:(NSPoint)p
{
	if (![self locationLocked]) {
		CGFloat dx, dy;

		dx = p.x - [self location].x;
		dy = p.y - [self location].y;

		if (dx != 0.0 || dy != 0.0) {
			NSRect oldBounds = [self bounds];

			[self notifyVisualChange];
			[[[self undoManager] prepareWithInvocationTarget:self] setLocation:[self location]];

			NSAffineTransform* tfm = [NSAffineTransform transform];
			[tfm translateXBy:dx
						  yBy:dy];

			[[self path] transformUsingAffineTransform:tfm];
			[self notifyVisualChange];
			[self notifyGeometryChange:oldBounds];
		}
	}
}

/** @brief Given a partcode, this returns the current value of the associated point

 Partcodes apart from 0 and -1 are private to this object
 @param pc an integer - the private partcode
 @return a point - the location of the partcode. */
- (NSPoint)pointForPartcode:(NSInteger)pc
{
	if (pc != kDKDrawingNoPart && pc != kDKDrawingEntireObjectPart) {
		if (pc == kDKSnapToNearestPathPointPartcode) {
			// snapping to the nearest path point

			return [[self path] nearestPointToPoint:gMouseForPathSnap
										  tolerance:4];
		} else
			return [[self path] controlPointForPartcode:pc];
	} else
		return [super pointForPartcode:pc];
}

/** @brief Populate the menu with commands pertaining to this object
 @param theMenu the menu to populate
 @return YES
 */
- (BOOL)populateContextualMenu:(NSMenu*)theMenu
{
	// if the object supports any contextual menu commands, it should add them to the menu and return YES. If subclassing,
	// you should call the inherited method first so that the menu is the union of all the ancestor's added methods.

	NSMenu* convertMenu = [[theMenu itemWithTag:kDKConvertToSubmenuTag] submenu];

	if (convertMenu)
		[[convertMenu addItemWithTitle:NSLocalizedString(@"Shape", @"submenu item for convert to shape")
								action:@selector(convertToShape:)
						 keyEquivalent:@""] setTarget:self];
	else
		[[theMenu addItemWithTitle:NSLocalizedString(@"Convert To Shape", @"menu item for convert to shape")
							action:@selector(convertToShape:)
					 keyEquivalent:@""] setTarget:self];

	[theMenu addItem:[NSMenuItem separatorItem]];

	[super populateContextualMenu:theMenu];
	return YES;
}

/** @brief Returns the actual path drawn when the object is rendered

 This is part of the style rendering protocol. Note that the path returned is always a copy of the
 object's stored path and may be freely modified
 @return a NSBezierPath object, transformed according to its parents (groups for example)
 */
- (NSBezierPath*)renderingPath
{
	NSBezierPath* rPath = [[self path] copy];
	NSAffineTransform* parentTransform = [self containerTransform];

	if (parentTransform)
		rPath = [parentTransform transformBezierPath:rPath];

	// if drawing is in low quality mode, set a coarse flatness value:

	if ([[self drawing] lowRenderingQuality])
		[rPath setFlatness:2.0];
	else
		[rPath setFlatness:0.5];

	return rPath;
}

/** @brief Rotates the path to the given angle

 Paths are not rotatable like shapes, but in special circumstances you may want to rotate the path
 in place. This will do that. The bounds remains aligned orthogonally. Note that asking for the path's
 angle will always return 0.
 @param angle the angle in radians
 */
- (void)setAngle:(CGFloat)angle
{
	[self setPath:[[self path] rotatedPath:angle
								aboutPoint:[self location]]];
}

/** @brief Returns a list of potential snapping points used when the path is snapped to the grid or guides

 Part of the snapping protocol
 @param offset add this offset to the points
 @return an array of points as NSValue objects
 */
- (NSArray*)snappingPointsWithOffset:(NSSize)offset
{
	// utility method mainly for the purpose of snapping to guides - returns an array of the on-path points as values
	// with the offset added to them. This can subsequently be tested for guide snaps and used to return a mouse offset.

	NSMutableArray* pts;
	NSPoint a[3];
	NSInteger i, el = [[self path] elementCount];
	NSBezierPathElement elem;

	pts = [[NSMutableArray alloc] init];

	for (i = 0; i < el; ++i) {
		elem = [[self path] elementAtIndex:i
						  associatedPoints:a];

		if (elem == NSCurveToBezierPathElement) {
			a[2].x += offset.width;
			a[2].y += offset.height;
			[pts addObject:[NSValue valueWithPoint:a[2]]];
		} else {
			a[0].x += offset.width;
			a[0].y += offset.height;
			[pts addObject:[NSValue valueWithPoint:a[0]]];
		}
	}

	return pts;
}

/** @brief Sets the path's bounds to be updated

 This optimizes the update to the individual element bounding rects rather than the entire bounding
 rect which can help a lot when there are many other objects close to the path (within its bounds
 but outside the element bounds).
 */
/*
- (void)			notifyVisualChange
{
	[self setNeedsDisplayForRects:[[self renderingPath] allBoundingBoxes]];
	[[self drawing] updateRulerMarkersForRect:[self logicalBounds]];
	[[NSNotificationCenter defaultCenter] postNotificationName:kDKDrawableDidChangeNotification object:self];
}
*/

/** @brief Return whether the object was valid following creation

 See DKDrawableObject
 @return YES if usable and valid
 */
- (BOOL)objectIsValid
{
	// paths are invalid if their length is zero or there is no path or the path is empty.

	BOOL valid;

	valid = ([self path] != nil && ![[self path] isEmpty] && [[self path] length] > 0.0);

	return valid;
}

/** @brief Return the object's size
 @return the size of the object (the size of the path bounds)
 */
- (NSSize)size
{
	return [[self path] bounds].size;
}

/** @brief This object is being ungrouped from a group

 When ungrouping, an object must help the group to the right thing by resizing, rotating and repositioning
 itself appropriately. At the time this is called, the object has already has its container set to
 the layer it will be added to but has not actually been added.
 @param aGroup the group containing the object
 @param aTransform the transform that the group is applying to the object to scale rotate and translate it.
 */
- (void)group:(DKShapeGroup*)aGroup willUngroupObjectWithTransform:(NSAffineTransform*)aTransform
{
#pragma unused(aGroup)

	NSAssert(aTransform != nil, @"expected valid transform");

	NSBezierPath* path = [[self path] copy];
	[path transformUsingAffineTransform:aTransform];
	[self setPath:path];
}

/** @brief Apply the transform to the object
 @param transform a transform
 */
- (void)applyTransform:(NSAffineTransform*)transform
{
	[self notifyVisualChange];
	[[self path] transformUsingAffineTransform:transform];
	[self notifyVisualChange];
}

#pragma mark -
#pragma mark As an NSObject
- (instancetype)init
{
	return [self initWithStyle:[DKStyle styleWithFillColour:nil
											   strokeColour:[NSColor blackColor]
												strokeWidth:1.0]];
}

#pragma mark -
#pragma mark As part of NSCoding Protocol
- (void)encodeWithCoder:(NSCoder*)coder
{
	[super encodeWithCoder:coder];

	[coder encodeObject:[self path]
				 forKey:@"path"];
	[coder encodeDouble:m_freehandEpsilon
				 forKey:@"freehand_smoothing"];
}

- (instancetype)initWithCoder:(NSCoder*)coder
{
	self = [super initWithCoder:coder];
	if (self != nil) {
		[self setPath:[coder decodeObjectForKey:@"path"]];
		m_freehandEpsilon = [coder decodeDoubleForKey:@"freehand_smoothing"];
	}
	return self;
}

#pragma mark -
#pragma mark As part of NSCopying Protocol
- (id)copyWithZone:(NSZone*)zone
{
	DKDrawablePath* copy = [super copyWithZone:zone];
	NSBezierPath* pc = [[self path] copyWithZone:zone];

	[copy setPath:pc];

	[copy setPathCreationMode:[self pathCreationMode]];

	return copy;
}

#pragma mark -
#pragma mark As part of NSDraggingDestination protocol

- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender
{
	// this is called when the owning layer permits it, and the drag pasteboard contains a type that matches the class's
	// pasteboardTypesForOperation result. Generally at this point the object should simply handle the drop.

	// default behaviour is to derive a style from the current style.

	DKStyle* newStyle = nil;

	// first see if we have dropped a complete style

	newStyle = [DKStyle styleFromPasteboard:[sender draggingPasteboard]];

	if (newStyle == nil)
		newStyle = [[self style] derivedStyleWithPasteboard:[sender draggingPasteboard]
												withOptions:kDKDerivedStyleForPathHint];

	if (newStyle != nil && newStyle != [self style]) {
		[self setStyle:newStyle];
		[[self undoManager] setActionName:NSLocalizedString(@"Drop Property", @"undo string for drop colour onto shape")];

		return YES;
	}

	return NO;
}

#pragma mark -
#pragma mark As part of NSMenuValidation Protocol
- (BOOL)validateMenuItem:(NSMenuItem*)item
{
	SEL action = [item action];

	if (action == @selector(convertToOutline:) || action == @selector(roughenPath:))
		return ![self locked] && [[self style] hasStroke];

	if (action == @selector(breakApart:))
		return ![self locked] && [[self path] countSubPaths] > 1;

	if (action == @selector(convertToShape:) || action == @selector(addRandomNoise:) || action == @selector(smoothPath:) || action == @selector(parallelCopy:) || action == @selector(smoothPathMore:) || action == @selector(toggleHorizontalFlip:) || action == @selector(toggleVerticalFlip:) || action == @selector(curveFit:) || action == @selector(reversePath:))
		return ![self locked];

	if (action == @selector(convertToTrack:))
		return ![self locked] && [self canConvertToTrack] && [self respondsToSelector:action];

	if (action == @selector(closePath:))
		return ![self locked] && ![self isPathClosed];

	return [super validateMenuItem:item];
}

@end
