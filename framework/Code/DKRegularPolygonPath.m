/**
 @author Graham Cox, Apptree.net
 @author Graham Miln, miln.eu
 @author Contributions from the community
 @date 2005-2014
 @copyright This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file.
 */

#import "DKRegularPolygonPath.h"
#import "DKDrawableShape.h"
#import "DKDrawing.h"
#import "DKStyle.h"
#import "DKKnob.h"
#import "DKObjectDrawingLayer.h"
#import "LogEvent.h"
#import "DKDrawkitMacros.h"
#include <tgmath.h>

@interface DKRegularPolygonPath (Private)

- (NSBezierPath*)calculatePath;
- (void)movePart:(NSInteger)pc toPoint:(NSPoint)mp constrainAngle:(BOOL)constrain;

/** @brief Returns the overall angle of the object
 @return the overall angle
 */
- (CGFloat)angleForVertexPartcode:(NSInteger)pc;
- (void)updateInfoForPartcode:(NSInteger)pc atPoint:(NSPoint)p;

@end

static CGFloat sAngleConstraint = 0.261799387799; // 15°

@implementation DKRegularPolygonPath

#pragma mark - as a DKRegularPolygonPath

- (void)setNumberOfSides:(NSInteger)sides
{
	if (sides != [self numberOfSides]) {
		[[[self undoManager] prepareWithInvocationTarget:self] setNumberOfSides:[self numberOfSides]];
		[self notifyVisualChange];
		mVertices = sides;
		[self setPath:[self calculatePath]];
		[[self undoManager] setActionName:NSLocalizedString(@"Change Polygon Sides", @"undo string for change poly sides")];
	}
}

- (CGFloat)numberOfSides
{
	return mVertices;
}

- (void)setRadius:(CGFloat)rad
{
	if (rad != [self radius]) {
		[[[self undoManager] prepareWithInvocationTarget:self] setRadius:[self radius]];
		[self notifyVisualChange];
		mOuterRadius = rad;
		[self setPath:[self calculatePath]];
		[[self undoManager] setActionName:NSLocalizedString(@"Change Polygon Radius", @"undo string for change poly radius")];
	}
}

- (CGFloat)radius
{
	return mOuterRadius;
}

- (void)setInnerRadius:(CGFloat)innerRad
{
	if (innerRad != [self innerRadius]) {
		[[[self undoManager] prepareWithInvocationTarget:self] setInnerRadius:[self innerRadius]];
		[self notifyVisualChange];
		mInnerRadius = innerRad;
		[self setPath:[self calculatePath]];
		[[self undoManager] setActionName:NSLocalizedString(@"Change Polygon Inset", @"undo string for change poly inner radius")];
	}
}

- (CGFloat)innerRadius
{
	return mInnerRadius;
}

- (void)setTipSpread:(CGFloat)spread
{
	if (spread != [self tipSpread]) {
		[[[self undoManager] prepareWithInvocationTarget:self] setTipSpread:[self tipSpread]];
		[self notifyVisualChange];
		mTipSpread = spread;
		[self setPath:[self calculatePath]];
		[[self undoManager] setActionName:NSLocalizedString(@"Change Polygon Outer Spread", @"undo string for change poly tip spread")];
	}
}

- (CGFloat)tipSpread
{
	return mTipSpread;
}

- (void)setValleySpread:(CGFloat)spread
{
	if (spread != [self valleySpread]) {
		[[[self undoManager] prepareWithInvocationTarget:self] setValleySpread:[self valleySpread]];
		[self notifyVisualChange];
		mValleySpread = spread;
		[self setPath:[self calculatePath]];
		[[self undoManager] setActionName:NSLocalizedString(@"Change Polygon Inner Spread", @"undo string for change poly valley spread")];
	}
}

- (CGFloat)valleySpread
{
	return mValleySpread;
}

- (void)setShowsSpreadControls:(BOOL)showControls
{
	if (showControls != [self showsSpreadControls]) {
		mShowSpreadControls = showControls;
		[self notifyVisualChange];
	}
}

- (BOOL)showsSpreadControls
{
	return mShowSpreadControls;
}

#pragma mark - private

- (NSBezierPath*)calculatePath
{
	NSInteger i, pc;
	NSBezierPath* path = [NSBezierPath bezierPath];
	NSPoint p, fp, pp;
	BOOL hadFirstPoint = NO, isStar = NO;
	CGFloat pa, lpa, tip, valley, halfPi;

	halfPi = pi * 0.5f;
	p = fp = pp = NSZeroPoint;
	lpa = 0;

	// distance of control points from on-path point - may be zero.

	isStar = ([self innerRadius] >= 0.0);

	tip = [self radius] * [self tipSpread];
	valley = [self radius] * [self valleySpread];

	// iterate over the points

	for (i = 0; i <= [self numberOfSides]; ++i) {
		pc = i + kDKRegularPolyFirstVertexPart;
		p = [self pointForPartcode:pc];

		pa = [self angleForVertexPartcode:pc];

		if (hadFirstPoint) {
			// factor in spreads - if both zero, just use a line

			if (tip == 0.0 && valley == 0.0) {
				[path lineToPoint:p];
				pp = p;
				lpa = pa;
			} else {
				// segment is curved - calculate control points

				NSPoint cp1, cp2;

				if (isStar) {
					if ((i & 1) == 0) {
						cp1.x = pp.x + valley * cosf(lpa + halfPi);
						cp1.y = pp.y + valley * sinf(lpa + halfPi);

						cp2.x = p.x + tip * cosf(pa - halfPi);
						cp2.y = p.y + tip * sinf(pa - halfPi);
					} else {
						cp1.x = pp.x + tip * cosf(lpa + halfPi);
						cp1.y = pp.y + tip * sinf(lpa + halfPi);

						cp2.x = p.x + valley * cosf(pa - halfPi);
						cp2.y = p.y + valley * sinf(pa - halfPi);
					}
				} else {
					cp1.x = pp.x + tip * cosf(lpa + halfPi);
					cp1.y = pp.y + tip * sinf(lpa + halfPi);
					cp2.x = p.x + tip * cosf(pa - halfPi);
					cp2.y = p.y + tip * sinf(pa - halfPi);
				}

				[path curveToPoint:p
					 controlPoint1:cp1
					 controlPoint2:cp2];
				pp = p;
				lpa = pa;
			}
		} else {
			[path moveToPoint:p];
			hadFirstPoint = YES;
			fp = pp = p;
			lpa = pa;
		}
	}

	[path closePath];

	return path;
}

- (void)movePart:(NSInteger)pc toPoint:(NSPoint)mp constrainAngle:(BOOL)constrain
{
	CGFloat rad = hypotf(mp.x - mCentre.x, mp.y - mCentre.y);
	CGFloat angle = atan2f(mp.y - mCentre.y, mp.x - mCentre.x);

	if (constrain) {
		CGFloat rem = fmod(angle, sAngleConstraint);

		if (rem > sAngleConstraint / 2.0)
			angle += (sAngleConstraint - rem);
		else
			angle -= rem;
	}

	BOOL isValleyVertex = [self isStar] && (((pc - kDKRegularPolyFirstVertexPart) & 1) == 1);

	switch (pc) {
	case kDKRegularPolyTipSpreadPart: {
		CGFloat ts = ([self radius] * 0.6 - rad) / ([self radius] * -0.3);
		ts = LIMIT(ts, 0, 1.5);
		[self setTipSpread:ts];
	} break;

	case kDKRegularPolyValleySpreadPart: {
		CGFloat ts = ([self radius] * 0.2 - rad) / ([self radius] * -0.3);
		ts = LIMIT(ts, 0, 1.5);
		[self setValleySpread:ts];
	} break;

	case kDKRegularPolyRotationPart:
		[self setAngle:angle];
		break;

	default:
		if (isValleyVertex)
			[self setInnerRadius:rad / [self radius]];
		else
			[self setRadius:rad];
		break;
	}

	[self updateInfoForPartcode:pc
						atPoint:mp];
}

- (CGFloat)angleForVertexPartcode:(NSInteger)pc
{
	// return the instantaneous angle of the vertex for the given partcode

	NSPoint vp = [self pointForPartcode:pc];
	return atan2f(vp.y - [self location].y, vp.x - [self location].x);
}

- (void)updateInfoForPartcode:(NSInteger)pc atPoint:(NSPoint)p
{
	// updates the floating info window depending on what's being moved

	if ([[self class] displaysSizeInfoWhenDragging]) {
		NSString* abbrUnits = [[self drawing] abbreviatedDrawingUnits];
		CGFloat val;
		NSString* infoStr;
		NSPoint gridPt;

		switch (pc) {
		case kDKDrawingEntireObjectPart:
		case kDKRegularPolyCentrePart:
			gridPt = [self convertPointToDrawing:[self location]];
#warning 64BIT: Check formatting arguments
			infoStr = [NSString stringWithFormat:@"centre x: %.2f%@\ncentre y: %.2f%@", gridPt.x, abbrUnits, gridPt.y, abbrUnits];
			break;

		case kDKRegularPolyRotationPart:
			val = [self angleInDegrees];
#warning 64BIT: Check formatting arguments
			infoStr = [NSString stringWithFormat:@"%.1f%C", val, 0xB0];
			break;

		case kDKRegularPolyTipSpreadPart:
			val = [self tipSpread] * 100.0;
#warning 64BIT: Check formatting arguments
			infoStr = [NSString stringWithFormat:@"tip: %.0f%%", val];
			break;

		case kDKRegularPolyValleySpreadPart:
			val = [self valleySpread] * 100.0;
#warning 64BIT: Check formatting arguments
			infoStr = [NSString stringWithFormat:@"valley: %.0f%%", val];
			break;

		default:
			if (((pc - kDKRegularPolyFirstVertexPart) & 1) == 1) {
				val = [self innerRadius] * 100.0;
#warning 64BIT: Check formatting arguments
				infoStr = [NSString stringWithFormat:@"radial ratio: %.0f%%", val];
			} else {
				val = [[self drawing] convertLength:[self radius]];
#warning 64BIT: Check formatting arguments
				infoStr = [NSString stringWithFormat:@"radius: %.2f%@", val, abbrUnits];
			}
			break;
		}

		[[self layer] showInfoWindowWithString:infoStr
									   atPoint:p];
	}
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

- (IBAction)setNumberOfSidesWithTag:(id)sender
{
	// sender's tag sets the number of sides. If innerRadius +ve, the tag is doubled

	NSInteger sides = [sender tag];
	if ([self innerRadius] >= 0.0)
		sides *= 2;

	[self setNumberOfSides:sides];
}

- (BOOL)isStar
{
	return [self innerRadius] >= 0;
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

	if ([self isTrackingMouse]) {
		rp = [self pointForPartcode:kDKRegularPolyRotationPart];
		kp = [self pointForPartcode:kDKRegularPolyCentrePart];
		[knobs drawKnobAtPoint:kp
						ofType:kDKCentreTargetKnobType | kt
					  userInfo:nil];
		[knobs drawControlBarFromPoint:kp
							   toPoint:rp];
	}

	NSInteger pc;
	CGFloat pa;

	for (pc = kDKRegularPolyFirstVertexPart; pc < (kDKRegularPolyFirstVertexPart + [self numberOfSides]); ++pc) {
		rp = [self pointForPartcode:pc];
		pa = [self angleForVertexPartcode:pc];
		[knobs drawKnobAtPoint:rp
						ofType:kDKBoundingRectKnobType | kt
						 angle:pa
					  userInfo:nil];
	}

	if (![self locked]) {
		kp = [self pointForPartcode:kDKRegularPolyRotationPart];
		[knobs drawKnobAtPoint:kp
						ofType:kDKRotationKnobType
					  userInfo:nil];

		if ([self showsSpreadControls]) {
			NSDictionary* options = [NSDictionary dictionaryWithObjectsAndKeys:[NSColor yellowColor], kDKKnobPreferredHighlightColour, nil];

			kp = [self pointForPartcode:kDKRegularPolyTipSpreadPart];
			[knobs drawKnobAtPoint:kp
							ofType:kDKBoundingRectKnobType
							 angle:[self angle]
						  userInfo:options];

			if ([self isStar]) {
				kp = [self pointForPartcode:kDKRegularPolyValleySpreadPart];
				[knobs drawKnobAtPoint:kp
								ofType:kDKBoundingRectKnobType
								 angle:[self angle]
							  userInfo:options];
			}
		}
	}
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
	return kDKRegularPolyFirstVertexPart;
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

	for (pc = kDKRegularPolyCentrePart; pc < (kDKRegularPolyFirstVertexPart + [self numberOfSides]); ++pc) {
		if (![self showsSpreadControls] && (pc == kDKRegularPolyTipSpreadPart || pc == kDKRegularPolyValleySpreadPart))
			continue;

		kp = [self pointForPartcode:pc];
		kr.origin = kp;
		kr = NSOffsetRect(kr, tol * -0.5f, tol * -0.5f);

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

	radius = [self radius];
	angle = [self angle];

	switch (pc) {
	case kDKSnapToNearestPathPointPartcode:
		return [super pointForPartcode:pc];

	case kDKRegularPolyTipSpreadPart:
		radius *= (0.6 + (0.3 * [self tipSpread]));
		break;

	case kDKRegularPolyValleySpreadPart:
		radius *= (0.2 + (0.3 * [self valleySpread]));
		break;

	case kDKRegularPolyRotationPart:
		radius *= 0.75;
		angle = [self angle];
		break;

	case kDKRegularPolyCentrePart:
		return mCentre;

	default: {
		NSInteger i = pc - kDKRegularPolyFirstVertexPart;
		angle = ((2 * pi * i) / [self numberOfSides]) + [self angle];

		if ((mInnerRadius >= 0.0) && (i & 1) == 1)
			radius *= [self innerRadius];
	} break;
	}

	NSPoint kp;

	kp.x = mCentre.x + (cosf(angle) * radius);
	kp.y = mCentre.y + (sinf(angle) * radius);

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

	case kDKRegularPolyCreationMode:
		[self setPathCreationMode:kDKPathCreateModeEditExisting];
		break;

	default:
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

	if (partcode == kDKRegularPolyCentrePart) {
		if (![self locationLocked]) {
			[self setLocation:smp];
			[self updateInfoForPartcode:partcode
								atPoint:mp];
		}
	} else if (partcode == kDKDrawingEntireObjectPart) {
		[super mouseDraggedAtPoint:mp
							inPart:kDKDrawingEntireObjectPart
							 event:evt];
		[self updateInfoForPartcode:partcode
							atPoint:mp];
	} else
		[self movePart:partcode
				   toPoint:smp
			constrainAngle:shift];

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

/** @brief Move the object to a given location within the drawing

 Arc objects consider their centre origin as the datum of the location
 @param p the point at which to place the object
 */
- (void)setLocation:(NSPoint)p
{
	if (!NSEqualPoints(p, [self location]) && ![self locked] && ![self locationLocked]) {
		[[[self undoManager] prepareWithInvocationTarget:self] setLocation:[self location]];
		[self notifyVisualChange];
		mCentre = p;
		[self setPath:[self calculatePath]];
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

	CGFloat tol = [[[self layer] knobs] controlKnobSize].width * 0.71f;
	kr.size = NSMakeSize(tol, tol);

	NSSize ex = [super extraSpaceNeeded];
	return NSInsetRect(pb, -(ex.width + tol), -(ex.height + tol));
}

/** @brief Sets the overall angle of the object

 The angle is in radians
 @param angle the overall angle in radians
 */
- (void)setAngle:(CGFloat)angle
{
	if (angle != [self angle]) {
		[[[self undoManager] prepareWithInvocationTarget:self] setAngle:[self angle]];
		[self notifyVisualChange];
		mAngle = angle;
		[self setPath:[self calculatePath]];
		[[self undoManager] setActionName:NSLocalizedString(@"Rotate Polygon", @"undo string for rotate regular poly")];
	}
}

- (CGFloat)angle
{
	return mAngle;
}

/** @brief Sets the object's size

 The larger of the width or height passed is used to set the size by adjusting the radius to half the value.
 @param aSize the object's size
 */
- (void)setSize:(NSSize)aSize
{
	[self setRadius:MAX(aSize.width, aSize.height) * 0.5];
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
	NSPoint loc = [self location];
	loc = [aTransform transformPoint:loc];

	NSSize radSize = NSMakeSize([self radius], [self radius]);
	radSize = [aTransform transformSize:radSize];

	[self setLocation:loc];
	[self setRadius:hypotf(radSize.width, radSize.height) / _CGFloatSqrt(2.0f)];
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

	for (i = kDKRegularPolyCentrePart; i < (kDKRegularPolyFirstVertexPart + [self numberOfSides]); ++i) {
		if (i != kDKRegularPolyRotationPart) {
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
	NSMenu* sidesMenu = [[NSMenu alloc] initWithTitle:@"Sides"];
	NSUInteger i;
	NSMenuItem* item;

	for (i = 3; i < 9; ++i) {
#warning 64BIT: Inspect use of long
		item = [sidesMenu addItemWithTitle:[NSString stringWithFormat:@"%ld", (long)i]
									action:@selector(setNumberOfSidesWithTag:)
							 keyEquivalent:@""];
		[item setTag:i];
		[item setTarget:self];
	}

	item = [theMenu addItemWithTitle:NSLocalizedString(@"Sides", @"menu item for # of sides")
							  action:NULL
					   keyEquivalent:@""];
	[item setSubmenu:sidesMenu];
	[sidesMenu release];

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
- (id)init
{
	self = [super init];
	if (self != nil) {
		mTipSpread = 0;
		mValleySpread = 0;
		mVertices = 6;
		mInnerRadius = -1.0; // -ve value means ordinary regular poly
		mShowSpreadControls = NO;

		[self setPathCreationMode:kDKRegularPolyCreationMode];
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
	DKRegularPolygonPath* copy = [super copyWithZone:zone];
	if (copy != nil) {
		copy->mVertices = mVertices;
		copy->mOuterRadius = mOuterRadius;
		copy->mInnerRadius = mInnerRadius;
		copy->mCentre = mCentre;
		copy->mTipSpread = mTipSpread;
		copy->mValleySpread = mValleySpread;
		copy->mAngle = mAngle;
		copy->mShowSpreadControls = mShowSpreadControls;
	}

	return copy;
}

/** @brief Encodes the object for archiving
 @param coder the coder
 */
- (void)encodeWithCoder:(NSCoder*)coder
{
	[super encodeWithCoder:coder];
	[coder encodeDouble:[self radius]
				 forKey:@"DKRegularPoly_outerRadius"];
	[coder encodeDouble:[self innerRadius]
				 forKey:@"DKRegularPoly_innerRadius"];
	[coder encodeDouble:[self tipSpread]
				 forKey:@"DKRegularPoly_tipSpread"];
	[coder encodeDouble:[self valleySpread]
				 forKey:@"DKRegularPoly_valleySpread"];
	[coder encodeDouble:[self angle]
				 forKey:@"DKRegularPoly_angle"];
	[coder encodeInteger:[self numberOfSides]
				  forKey:@"DKRegularPoly_numberOfSides"];
	[coder encodePoint:[self location]
				forKey:@"DKRegularPoly_location"];
	[coder encodeBool:[self showsSpreadControls]
			   forKey:@"DKRegularPoly_showSpreadControls"];
}

/** @brief Decodes the object for archiving
 @param coder the coder
 @return the object
 */
- (id)initWithCoder:(NSCoder*)coder
{
	[super initWithCoder:coder];
	[self setRadius:[coder decodeDoubleForKey:@"DKRegularPoly_outerRadius"]];
	[self setInnerRadius:[coder decodeDoubleForKey:@"DKRegularPoly_innerRadius"]];
	[self setTipSpread:[coder decodeDoubleForKey:@"DKRegularPoly_tipSpread"]];
	[self setValleySpread:[coder decodeDoubleForKey:@"DKRegularPoly_valleySpread"]];
	[self setAngle:[coder decodeDoubleForKey:@"DKRegularPoly_angle"]];
	[self setNumberOfSides:[coder decodeIntegerForKey:@"DKRegularPoly_numberOfSides"]];
	[self setLocation:[coder decodePointForKey:@"DKRegularPoly_location"]];
	[self setShowsSpreadControls:[coder decodeBoolForKey:@"DKRegularPoly_showSpreadControls"]];

	return self;
}

#pragma mark -
#pragma mark As part of NSMenuValidation Protocol

- (BOOL)validateMenuItem:(NSMenuItem*)item
{
	SEL action = [item action];

	if (action == @selector(convertToPath:))
		return ![self locked];
	else if (action == @selector(setNumberOfSidesWithTag:)) {
		NSInteger sides = [self numberOfSides];
		if ([self innerRadius] > 0.0)
			sides /= 2;

		[item setState:([item tag] == sides) ? NSOnState : NSOffState];

		return ![self locked];
	}

	return [super validateMenuItem:item];
}

@end
