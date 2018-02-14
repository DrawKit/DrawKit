/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import "DKArcPath.h"
#import "DKDrawableShape.h"
#import "DKDrawing.h"
#import "DKStyle.h"
#import "DKKnob.h"
#import "DKObjectDrawingLayer.h"
#import "LogEvent.h"
#import "DKDrawKitMacros.h"
#import "DKShapeGroup.h"
#include <tgmath.h>

@interface DKArcPath ()

/** @brief Sets the path based on the current arc parameters

 Calls setPath: which is recorded by undo
 */
- (void)calculatePath;

/** @brief Adjusts the arc parameters based on the mouse location passed and the partcode, etc.

 Called from mouseDragged: to implement interactive editing
 @param pc the partcode being manipulated
 @param mp the current point (from the mouse)
 @param constrain YES to constrain angles to 15° increments
 */
- (void)movePart:(NSInteger)pc toPoint:(NSPoint)mp constrainAngle:(BOOL)constrain;

@end

#pragma mark -

@implementation DKArcPath

static CGFloat sAngleConstraint = 0.261799387799; // 15°

/** @brief Sets the radius of the arc
 @param rad the radius
 */
- (void)setRadius:(CGFloat)rad
{
	if (rad != [self radius]) {
		[[[self undoManager] prepareWithInvocationTarget:self] setRadius:[self radius]];
		[self notifyVisualChange];
		mRadius = rad;
		[self calculatePath];
		[[self undoManager] setActionName:NSLocalizedString(@"Change Arc Radius", @"undo string for change arc radius")];
	}
}

@synthesize radius=mRadius;

/** @brief Sets the starting angle, which is the more anti-clockwise point on the arc

 Angle is passed in DEGREES
 @param sa the angle in degrees anti-clockwise from the horizontal axis extending to the right
 */
- (void)setStartAngle:(CGFloat)sa
{
	if (sa != [self startAngle]) {
		[[[self undoManager] prepareWithInvocationTarget:self] setStartAngle:[self startAngle]];
		[self notifyVisualChange];
		mStartAngle = DEGREES_TO_RADIANS(sa);
		[self calculatePath];
		[[self undoManager] setActionName:NSLocalizedString(@"Change Arc Angle", @"undo string for change arc angle")];
	}
}

/** @brief Returns the starting angle, which is the more anti-clockwise point on the arc
 @return the angle in degrees anti-clockwise from the horizontal axis extending to the right
 */
- (CGFloat)startAngle
{
	return RADIANS_TO_DEGREES(mStartAngle);
}

/** @brief Sets the ending angle, which is the more clockwise point on the arc

 Angle is passed in DEGREES
 @param ea the angle in degrees anti-clockwise from the horizontal axis extending to the right
 */
- (void)setEndAngle:(CGFloat)ea
{
	if (ea != [self endAngle]) {
		[[[self undoManager] prepareWithInvocationTarget:self] setEndAngle:[self endAngle]];
		[self notifyVisualChange];
		mEndAngle = DEGREES_TO_RADIANS(ea);
		[self calculatePath];
		[[self undoManager] setActionName:NSLocalizedString(@"Change Arc Angle", @"undo string for change arc angle")];
	}
}

/** @brief Returns the ending angle, which is the more clockwise point on the arc
 @return the angle in degrees anti-clockwise from the horizontal axis extending to the right
 */
- (CGFloat)endAngle
{
	if (fabs(mEndAngle - mStartAngle) < 0.001)
		return RADIANS_TO_DEGREES(mStartAngle) + 360.0;
	else
		return RADIANS_TO_DEGREES(mEndAngle);
}

/** @brief Sets the arc type, which affects the path geometry
 @param arcType the required type
 */
- (void)setArcType:(DKArcPathType)arcType
{
	if (arcType != [self arcType]) {
		[[[self undoManager] prepareWithInvocationTarget:self] setArcType:[self arcType]];
		[self notifyVisualChange];
		mArcType = arcType;
		[self calculatePath];
		[[self undoManager] setActionName:NSLocalizedString(@"Change Arc Type", @"undo string for change arc type")];
	}
}

@synthesize arcType=mArcType;

- (void)calculatePath
{
	// computes the arc's path from the radius and angle params and sets it

	NSBezierPath* arcPath = [NSBezierPath bezierPath];
	NSPoint ep;

	if ([self arcType] == kDKArcPathCircle) {
		[arcPath appendBezierPathWithArcWithCenter:[self location]
											radius:[self radius]
										startAngle:0.0
										  endAngle:360.0];
		[arcPath closePath];
	} else {
		if ([self arcType] == kDKArcPathWedge) {
			[arcPath moveToPoint:[self location]];
			ep = [self pointForPartcode:kDKArcPathStartAnglePart];
			[arcPath lineToPoint:ep];
		}

		[arcPath appendBezierPathWithArcWithCenter:[self location]
											radius:[self radius]
										startAngle:[self startAngle]
										  endAngle:[self endAngle]];

		if ([self arcType] == kDKArcPathWedge) {
			[arcPath lineToPoint:[self location]];
			[arcPath closePath];
		}
	}
	[self setPath:arcPath];
}

- (void)movePart:(NSInteger)pc toPoint:(NSPoint)mp constrainAngle:(BOOL)constrain
{
	// move the given control point to the location. This establishes the angular and radial parameters, which in turn define the path.

	CGFloat rad = hypot(mp.x - mCentre.x, mp.y - mCentre.y);
	CGFloat angle = atan2(mp.y - mCentre.y, mp.x - mCentre.x);

	if (constrain) {
		CGFloat rem = fmod(angle, sAngleConstraint);

		if (rem > sAngleConstraint / 2.0)
			angle += (sAngleConstraint - rem);
		else
			angle -= rem;
	}

	switch (pc) {
	case kDKArcPathRadiusPart:
		[self setRadius:rad];
		break;

	case kDKArcPathStartAnglePart:
		[self setStartAngle:RADIANS_TO_DEGREES(angle)];
		break;

	case kDKArcPathEndAnglePart:
		[self setEndAngle:RADIANS_TO_DEGREES(angle)];
		break;

	case kDKArcPathRotationKnobPart:
		[self setAngle:angle];
		break;

	default:
		break;
	}

	[self clearUndoPath];
}

#pragma mark -

- (IBAction)convertToPath:(id)sender
{
#pragma unused(sender)

	// replaces itself in the owning layer with a shape object with the same path.

	DKObjectDrawingLayer* layer = (DKObjectDrawingLayer*)[self layer];
	NSInteger myIndex = [layer indexOfObject:self];

	Class pathClass = [DKDrawableObject classForConversionRequestFor:[DKDrawablePath class]];
	DKDrawablePath* so = [pathClass drawablePathWithBezierPath:[self path]];

	[so setStyle:[self style]];
	[so setUserInfo:[self userInfo]];

	[layer recordSelectionForUndo];
	[layer addObject:so
			 atIndex:myIndex];
	[layer replaceSelectionWithObject:so];
	[layer removeObject:self];
	[layer commitSelectionUndoWithActionName:NSLocalizedString(@"Convert To Path", @"undo string for convert to path")];
}

#pragma mark -
#pragma mark - as a DKDrawablePath

/** @brief Draws the selection knobs as required
 @param path not used
 @param knobs the knobs object to use for drawing
 */
- (void)drawControlPointsOfPath:(NSBezierPath*)path usingKnobs:(DKKnob*)knobs
{
#pragma unused(path)

	NSPoint kp, rp;
	DKKnobType kt = 0;

	if ([self locked])
		kt = kDKKnobIsDisabledFlag;

	rp = kp = [self pointForPartcode:kDKArcPathRadiusPart];

	if ([self isTrackingMouse]) {
		kp = [self pointForPartcode:kDKArcPathCentrePointPart];
		[knobs drawKnobAtPoint:kp
						ofType:kDKCentreTargetKnobType | kt
					  userInfo:nil];
		[knobs drawControlBarFromPoint:kp
							   toPoint:rp];
	}

	[knobs drawKnobAtPoint:rp
					ofType:kDKBoundingRectKnobType | kt
					 angle:[self angle]
				  userInfo:nil];

	if ([self arcType] != kDKArcPathCircle) {
		kp = [self pointForPartcode:kDKArcPathStartAnglePart];
		[knobs drawKnobAtPoint:kp
						ofType:kDKBoundingRectKnobType | kt
						 angle:mStartAngle
					  userInfo:nil];

		kp = [self pointForPartcode:kDKArcPathEndAnglePart];
		[knobs drawKnobAtPoint:kp
						ofType:kDKBoundingRectKnobType | kt
						 angle:mEndAngle
					  userInfo:nil];

		if (![self locked]) {
			kp = [self pointForPartcode:kDKArcPathRotationKnobPart];
			[knobs drawKnobAtPoint:kp
							ofType:kDKRotationKnobType
						  userInfo:nil];
		}
	}
}

/** @brief Creates the arc path initially
 @param initialPoint the starting point for the creation
 */
- (void)arcCreateLoop:(NSPoint)initialPoint
{
	// creates a circle segment. First click sets the centre, second the first radius, third the second radius.

	NSEvent* theEvent;
	NSInteger mask = NSLeftMouseDownMask | NSMouseMovedMask | NSPeriodicMask | NSScrollWheelMask;
	NSView* view = [[self layer] currentView];
	BOOL loop = YES, constrain = NO;
	NSInteger phase;
	NSPoint p, lp, nsp;
	NSString* abbrUnits = [[self drawing] abbreviatedDrawingUnits];

	p = mCentre = [self snappedMousePoint:initialPoint
						  withControlFlag:NO];
	phase = 0; // set radius
	lp = mCentre;

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
			// slope of line is forced to be on 15° intervals

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

				mRadius = hypot(p.x - mCentre.x, p.y - mCentre.y);
				mEndAngle = atan2(p.y - mCentre.y, p.x - mCentre.x);
				++phase; // now setting the arc

				if ([self arcType] == kDKArcPathCircle)
					loop = NO;
			} else
				loop = NO;
		} break;

		case NSMouseMoved:
			[self notifyVisualChange];
			[view autoscroll:theEvent];
			if (phase == 0) {
				mRadius = hypot(p.x - mCentre.x, p.y - mCentre.y);

				if ([self arcType] == kDKArcPathCircle)
					[self calculatePath];
				else
					[self setAngle:atan2(p.y - mCentre.y, p.x - mCentre.x)];

				if ([[self class] displaysSizeInfoWhenDragging]) {
					CGFloat rad = [[self drawing] convertLength:mRadius];
					CGFloat angle = RADIANS_TO_DEGREES([self angle]);

					if (angle < 0)
						angle += 360.0;

					[[self layer] showInfoWindowWithString:[NSString stringWithFormat:@"radius: %.2f%@\nangle: %.1f°", rad, abbrUnits, angle]
												   atPoint:nsp];
				}
			} else if (phase == 1) {
				mStartAngle = atan2(p.y - mCentre.y, p.x - mCentre.x);
				[self calculatePath];

				if ([[self class] displaysSizeInfoWhenDragging]) {
					CGFloat rad = [[self drawing] convertLength:mRadius];
					CGFloat angle = RADIANS_TO_DEGREES(mEndAngle - mStartAngle);

					if (angle < 0)
						angle = 360.0 + angle;

					[[self layer] showInfoWindowWithString:[NSString stringWithFormat:@"radius: %.2f%@\narc angle: %.1f°", rad, abbrUnits, angle]
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
	[self notifyVisualChange];
}

#pragma mark -
#pragma mark - as a DKDrawableObject

/** @brief Return the partcode that should be used by tools when initially creating a new object

 The client of this method is DKObjectCreationTool. An arc is created by dragging its radius to
 some initial value, so the inital partcode is the radius knob.
 @return a partcode value
 */
+ (NSInteger)initialPartcodeForObjectCreation
{
	return kDKArcPathRadiusPart;
}

/** @brief Hit test the point against the knobs
 @param pt the point to hit-test
 @param snap YES if the test is being done for snap-detecting purposes, NO for normal mouse hits
 @return the partcode hit by the point, if any
 */
- (NSInteger)hitSelectedPart:(NSPoint)pt forSnapDetection:(BOOL)snap
{
	CGFloat tol = [[[self layer] knobs] controlKnobSize].width;

	if (snap)
		tol *= 2;

	NSInteger pc;

	// test for a hit in any of our knobs

	NSRect kr;
	NSPoint kp;

	kr.size = NSMakeSize(tol, tol);

	for (pc = kDKArcPathRadiusPart; pc <= kDKArcPathCentrePointPart; ++pc) {
		kp = [self pointForPartcode:pc];
		kr.origin = kp;
		kr = NSOffsetRect(kr, tol * -0.5, tol * -0.5);

		if (NSPointInRect(pt, kr))
			return pc;
	}

	pc = kDKDrawingEntireObjectPart;

	if (snap) {
		// for snapping to the nearest point on the path, return a special partcode value and cache the mouse point -
		// when pointForPartcode is called with this special code, locate the nearest path point and return it.

		if ([self pointHitsPath:pt]) {
			gMouseForPathSnap = pt;
			pc = kDKSnapToNearestPathPointPartcode;
		}
	}

	return pc;
}

/** @brief Return the current point for a given partcode value
 @param pc the partcode
 @return the partcode hit by the point, if any
 */
- (NSPoint)pointForPartcode:(NSInteger)pc
{
	CGFloat angle, radius;

	radius = mRadius;

	switch (pc) {
	case kDKSnapToNearestPathPointPartcode:
		return [super pointForPartcode:pc];

	case kDKArcPathRotationKnobPart:
		radius *= 0.75;
	// fall through:
	case kDKArcPathRadiusPart:
		angle = [self angle];
		break;

	case kDKArcPathStartAnglePart:
		angle = mStartAngle;
		break;

	case kDKArcPathEndAnglePart:
		angle = mEndAngle;
		break;

	case kDKArcPathCentrePointPart:
		return mCentre;

	default:
		return NSZeroPoint;
	}

	NSPoint kp;

	kp.x = mCentre.x + (cos(angle) * radius);
	kp.y = mCentre.y + (sin(angle) * radius);

	return kp;
}

/** @brief Handles a mouse down in the object

 Starts edit or creation of object - the creation mode can be anything other then "edit existing"
 for arc creation. Use the "simple mode" to create arcs in a one-stage drag.
 @param mp the mouse point
 @param partcode the partcode returned earlier by hitPart:
 @param evt the event this came from */
- (void)mouseDownAtPoint:(NSPoint)mp inPart:(NSInteger)partcode event:(NSEvent*)evt
{
	[[self layer] setInfoWindowBackgroundColour:[[self class] infoWindowBackgroundColour]];

	[self setTrackingMouse:YES];
	DKDrawablePathCreationMode mode = [self pathCreationMode];

	switch (mode) {
	case kDKPathCreateModeEditExisting:
		[super mouseDownAtPoint:mp
						 inPart:partcode
						  event:evt];
		break;

	case kDKArcSimpleCreationMode:
		[self setStartAngle:-22.5];
		[self setEndAngle:22.5];
		[self setPathCreationMode:kDKPathCreateModeEditExisting];
		break;

	default:
		[self arcCreateLoop:mp];
		break;
	}
}

/** @brief Handles a mouse drag in the object

 Used when editing an existing path, but not creating one
 @param mp the mouse point
 @param partcode the partcode returned earlier by hitPart:
 @param evt the event this came from */
- (void)mouseDraggedAtPoint:(NSPoint)mp inPart:(NSInteger)partcode event:(NSEvent*)evt
{
	BOOL shift = (([evt modifierFlags] & NSShiftKeyMask) != 0);
	BOOL ctrl = (([evt modifierFlags] & NSControlKeyMask) != 0);

	// modifier keys change the editing of path control points thus:

	// +shift	- constrains curve control point angles to 15° intervals
	// +ctrl	- temporarily disables snap to grid

	NSPoint smp = [self snappedMousePoint:mp
						  withControlFlag:ctrl];

	if (partcode == kDKArcPathCentrePointPart)
		[self setLocation:smp];
	else if (partcode == kDKDrawingEntireObjectPart)
		[super mouseDraggedAtPoint:mp
							inPart:kDKDrawingEntireObjectPart
							 event:evt];
	else
		[self movePart:partcode
				   toPoint:smp
			constrainAngle:shift];

	if ([[self class] displaysSizeInfoWhenDragging]) {
		NSString* abbrUnits = [[self drawing] abbreviatedDrawingUnits];
		CGFloat rad = [[self drawing] convertLength:mRadius];
		CGFloat angle;
		NSString* infoStr;
		NSPoint gridPt;

		switch (partcode) {
		case kDKDrawingEntireObjectPart:
		case kDKArcPathCentrePointPart:
			gridPt = [self convertPointToDrawing:[self location]];
			infoStr = [NSString stringWithFormat:@"centre x: %.2f%@\ncentre y: %.2f%@", gridPt.x, abbrUnits, gridPt.y, abbrUnits];
			break;

		case kDKArcPathRotationKnobPart:
			angle = [self angleInDegrees];
			infoStr = [NSString stringWithFormat:@"radius: %.2f%@\nangle: %.1f°", rad, abbrUnits, angle];
			break;

		default:
			angle = RADIANS_TO_DEGREES(mEndAngle - mStartAngle);
			if (angle < 0)
				angle += 360.0;
			infoStr = [NSString stringWithFormat:@"radius: %.2f%@\narc angle: %.1f°", rad, abbrUnits, angle];
			break;
		}

		[[self layer] showInfoWindowWithString:infoStr
									   atPoint:mp];
	}

	[self setMouseHasMovedSinceStartOfTracking:YES];
}

/** @brief Sets the path's bounds to be updated
 */
- (void)notifyVisualChange
{
	[[self layer] drawable:self
		needsDisplayInRect:[self bounds]];
	[[self drawing] updateRulerMarkersForRect:[self logicalBounds]];
	[[NSNotificationCenter defaultCenter] postNotificationName:kDKDrawableDidChangeNotification
														object:self];
}

/** @brief Return the object's location within the drawing

 Arc objects consider their centre origin as the datum of the location
 @return the position of the object within the drawing
 */
- (NSPoint)location
{
	return mCentre;
}

@synthesize location=mCentre;

/** @brief Move the object to a given location within the drawing

 Arc objects consider their centre origin as the datum of the location
 @param p the point at which to place the object
 */
- (void)setLocation:(NSPoint)p
{
	if (!NSEqualPoints(p, mCentre) && ![self locked] && ![self locationLocked]) {
		[[[self undoManager] prepareWithInvocationTarget:self] setLocation:[self location]];
		[self notifyVisualChange];
		mCentre = p;
		[self calculatePath];
	}
}

/** @brief Return the total area the object is enclosed by

 Bounds includes the centre point, even if it's not visible
 @return the bounds rect
 */
- (NSRect)bounds
{
	NSRect pb = [[self path] bounds];
	NSRect kr;

	CGFloat tol = [[[self layer] knobs] controlKnobSize].width;
	NSPoint kp;
	NSInteger pc, pcm;

	kr.size = NSMakeSize(tol, tol);

	pcm = kDKArcPathCentrePointPart; //m_inMouseOp? kDKArcPathCentrePointPart : kDKArcPathRotationKnobPart;

	for (pc = kDKArcPathRadiusPart; pc <= pcm; ++pc) {
		kp = [self pointForPartcode:pc];
		kr.origin = kp;
		kr = NSOffsetRect(kr, tol * -0.5, tol * -0.5);
		pb = NSUnionRect(pb, kr);
	}

	NSSize ex = [super extraSpaceNeeded];
	return NSInsetRect(pb, -(ex.width + tol), -(ex.height + tol));
}

/** @brief Sets the overall angle of the object
 @param angle the overall angle in radians
 */
- (void)setAngle:(CGFloat)angle
{
	if ([self arcType] == kDKArcPathCircle)
		return;

	CGFloat da = angle - [self angle];

	if (da != 0.0) {
		[[[self undoManager] prepareWithInvocationTarget:self] setAngle:[self angle]];
		[self notifyVisualChange];
		mStartAngle += da;
		mEndAngle += da;
		[self calculatePath];
		[[self undoManager] setActionName:NSLocalizedString(@"Rotate Arc", @"undo string for rotate arc")];
	}
}

/** @brief Returns the overall angle of the object

 The overall angle is considered to be halfway between the start and end points around the arc
 @return the overall angle
 */
- (CGFloat)angle
{
	if ([self arcType] == kDKArcPathCircle)
		return 0.0;
	else {
		CGFloat angle = (mStartAngle + mEndAngle) * 0.5;

		if (fabs(mEndAngle - mStartAngle) < 0.001)
			angle -= M_PI;

		if (mEndAngle < mStartAngle)
			angle += M_PI;

		return angle;
	}
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
	// note - arc paths can become very distorted if groups are scaled unequally. Should the path be preserved
	// in the distorted way? Or should the arc be recovered with the most useful radius? Something's got to give... at
	// the moment this does the latter.

	NSPoint loc = [self location];
	loc = [aTransform transformPoint:loc];

	NSSize radSize = NSMakeSize([self radius], [self radius]);
	radSize = [aTransform transformSize:radSize];

	[self setLocation:loc];
	[self setRadius:hypot(radSize.width, radSize.height) / M_SQRT2];
	[self setAngle:[self angle] + [aGroup angle]];
}

/** @brief Returns a list of potential snapping points used when the path is snapped to the grid or guides

 Part of the snapping protocol
 @param offset add this offset to the points
 @return an array of points as NSValue objects
 */
- (NSArray*)snappingPointsWithOffset:(NSSize)offset
{
	NSInteger i;
	NSPoint p;
	NSMutableArray* result = [NSMutableArray array];

	for (i = kDKArcPathRadiusPart; i <= kDKArcPathCentrePointPart; ++i) {
		if (i != kDKArcPathRotationKnobPart) {
			p = [self pointForPartcode:i];

			p.x += offset.width;
			p.y += offset.height;

			[result addObject:[NSValue valueWithPoint:p]];
		}
	}
	return result;
}

- (BOOL)populateContextualMenu:(NSMenu*)theMenu
{
	[[theMenu addItemWithTitle:NSLocalizedString(@"Convert To Path", @"menu item for convert to path")
						action:@selector(convertToPath:)
				 keyEquivalent:@""] setTarget:self];
	return [super populateContextualMenu:theMenu];
}

- (void)applyTransform:(NSAffineTransform*)transform
{
	[super applyTransform:transform];
	mCentre = [transform transformPoint:mCentre];
}

#pragma mark -
#pragma mark - as a NSObject

/** @brief Designated initialiser
 @return the object
 */
- (instancetype)init
{
	self = [super init];
	if (self != nil) {
		[self setPathCreationMode:kDKPathCreateModeWedgeSegment];
		[self setArcType:kDKArcPathWedge];
		[self setStyle:[DKStyle defaultStyle]];
	}

	return self;
}

/** @brief Copies the object

 Implements <NSCopying>
 @param zone the zone
 @return the copy
 */
- (id)copyWithZone:(NSZone*)zone
{
	DKArcPath* copy = [super copyWithZone:zone];
	if (copy != nil) {
		copy->mStartAngle = mStartAngle;
		copy->mEndAngle = mEndAngle;
		copy->mRadius = mRadius;
		copy->mCentre = mCentre;
		copy->mArcType = mArcType;
	}

	return copy;
}

/** @brief Encodes the object for archiving
 @param coder the coder
 */
- (void)encodeWithCoder:(NSCoder*)coder
{
	[super encodeWithCoder:coder];
	[coder encodeDouble:mStartAngle
				 forKey:@"DKArcPath_startAngle"];
	[coder encodeDouble:mEndAngle
				 forKey:@"DKArcPath_endAngle"];
	[coder encodeDouble:mRadius
				 forKey:@"DKArcPath_radius"];
	[coder encodeInteger:[self arcType]
				  forKey:@"DKArcPath_arcType"];
	[coder encodePoint:[self location]
				forKey:@"DKArcPath_location"];
}

/** @brief Decodes the object for archiving
 @param coder the coder
 @return the object
 */
- (instancetype)initWithCoder:(NSCoder*)coder
{
	if (self = [super initWithCoder:coder]) {
	mStartAngle = [coder decodeDoubleForKey:@"DKArcPath_startAngle"];
	mEndAngle = [coder decodeDoubleForKey:@"DKArcPath_endAngle"];
	mRadius = [coder decodeDoubleForKey:@"DKArcPath_radius"];
	[self setArcType:[coder decodeIntegerForKey:@"DKArcPath_arcType"]];
	[self setLocation:[coder decodePointForKey:@"DKArcPath_location"]];
	}

	return self;
}

#pragma mark -
#pragma mark As part of NSMenuValidation Protocol

- (BOOL)validateMenuItem:(NSMenuItem*)item
{
	SEL action = [item action];

	if (action == @selector(convertToPath:))
		return ![self locked];

	return [super validateMenuItem:item];
}

@end
