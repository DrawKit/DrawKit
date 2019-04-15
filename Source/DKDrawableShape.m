/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import "DKDrawableShape.h"
#import "DKDistortionTransform.h"
#import "DKDrawKitMacros.h"
#import "DKDrawablePath.h"
#import "DKDrawableShape+Hotspots.h"
#import "DKDrawing.h"
#import "DKGeometryUtilities.h"
#import "DKGridLayer.h"
#import "DKKnob.h"
#import "DKObjectDrawingLayer.h"
#import "DKPasteboardInfo.h"
#import "DKShapeGroup.h"
#import "DKStroke.h"
#import "DKStyle.h"
#import "GCInfoFloater.h"
#import "LogEvent.h"
#import "NSBezierPath+Editing.h"
#import "NSBezierPath+Geometry.h"
#import "NSDictionary+DeepCopy.h"
#include <tgmath.h>

#pragma mark Static Vars

static CGFloat sAspect = 1.0;
static CGFloat sAngleConstraint = 0.261799387799; // pi/12 or 15 degrees
static NSPoint sTempRotationPt;
static NSPoint sMouseForPathSnap;
static NSColor* sInfoWindowColour = nil;
static NSInteger sKnobMask = kDKDrawableShapeAllKnobs;
static NSSize sTempSavedOffset;

@interface DKDrawableShape ()
// private:

- (NSRect)knobBounds;
- (NSInteger)partcodeOppositeKnob:(NSInteger)knobPartCode;
- (CGFloat)knobAngleFromOrigin:(NSInteger)knobPartCode;
- (NSPoint)canonicalCornerPoint:(NSInteger)knobPartCode;
- (void)moveDistortionKnob:(NSInteger)partCode toPoint:(NSPoint)p;
- (void)drawDistortionEnvelope;
- (void)prepareRotation;
- (NSRect)knobRect:(NSInteger)knobPartCode;
- (void)updateInfoForOperation:(DKShapeEditOperation)op atPoint:(NSPoint)mp;

@end

#pragma mark -
@implementation DKDrawableShape
#pragma mark As a DKDrawableShape

/** @brief Return which particular knobs are used by instances of this class

 The default is to use all knobs, but subclasses may want to override this for particular uses
 @return bitmask indicating which knobs are used
 */
+ (NSInteger)knobMask
{
	return sKnobMask;
}

/** @brief Set which particular knobs are used by instances of this class

 The default is to use all knobs, but you can use this to set a different mask to use for all
 instances of this class.
 @param knobMask bitmask indicating which knobs are to be used
 */
+ (void)setKnobMask:(NSInteger)knobMask
{
	sKnobMask = knobMask;
}

/** @brief Sets the constraint angle for rotations

 When constraining a rotation (shift-drag), angles snap to multiples of this value. The default
 @param radians the constraint angle in radians
 */
+ (void)setAngularConstraintAngle:(CGFloat)radians
{
	sAngleConstraint = radians;
}

+ (CGFloat)angularConstraintAngle
{
	return sAngleConstraint;
}

/** @brief Return the unit rect centred at the origin

 This rect represents the bounds of all untransformed paths stored by a shape object
 @return the unit rect, centred at the origin
 */
+ (NSRect)unitRectAtOrigin
{
	return NSMakeRect(-0.5, -0.5, 1.0, 1.0);
}

/** @brief Set the background colour for info windows displayed by this class when dragging, etc

 The info window itself is implemented in the owning layer, but the class can supply a custom
 colour if you wish.
 @param colour the colour of the window
 */
+ (void)setInfoWindowBackgroundColour:(NSColor*)colour
{
	sInfoWindowColour = colour;
}

+ (NSColor*)infoWindowBackgroundColour
{
	return sInfoWindowColour;
}

+ (NSCursor*)cursorForShapePartcode:(NSInteger)pc
{
	static NSMutableDictionary* cursorCache = nil;

	NSCursor* curs = nil;
	NSString* pairKey;

	if (pc == kDKDrawingEntireObjectPart || pc == kDKDrawingNoPart)
		return [NSCursor arrowCursor];

	// cursors are used by opposite pairs of knobs for the sizing case, so if the partcode is part
	// of such a pair, generate the common key. The key name does not include the partcode itself
	// directly so resources are insulated from any changes made to the partcode numbering in future.

	if ((pc & kDKDrawableShapeNWSECorners) != 0)
		pairKey = @"NW-SE";
	else if ((pc & kDKDrawableShapeNESWCorners) != 0)
		pairKey = @"NE-SW";
	else if ((pc & kDKDrawableShapeEWHandles) != 0)
		pairKey = @"E-W";
	else if ((pc & kDKDrawableShapeNSHandles) != 0)
		pairKey = @"N-S";
	else if (pc == kDKDrawableShapeRotationHandle)
		pairKey = @"rotation";
	else
		pairKey = @"move";

	// the key is used both as the resource image name and the cache key

	NSString* key = [NSString stringWithFormat:@"shape_cursor_%@", pairKey];

	if (cursorCache == nil)
		cursorCache = [[NSMutableDictionary alloc] init];

	curs = [cursorCache objectForKey:key];

	if (curs == nil) {
		// not yet cached, so create the cursor from the image resource.
		// All shape cursors are 16x16 images with the hotspot at the centre

		LogEvent_(kInfoEvent, @"creating shape cursor: '%@'", key);

		NSImage* cursImage = [NSImage imageNamed:key];

		if (cursImage != nil) {
			curs = [[NSCursor alloc] initWithImage:cursImage
										   hotSpot:NSMakePoint(8, 8)];

			if (curs != nil) {
				[cursorCache setObject:curs
								forKey:key];
			}
		} else {
			// in the event of the image not being available, cache the arrow cursor
			// against this key so that it doesn't keep attempting to recreate it continually.

			[cursorCache setObject:[NSCursor arrowCursor]
							forKey:key];
		}
	}

	return curs;
}

#pragma mark -
#pragma mark Convenience methods

+ (DKDrawableShape*)drawableShapeWithRect:(NSRect)aRect
{
	return [[self alloc] initWithRect:aRect];
}

+ (DKDrawableShape*)drawableShapeWithOvalInRect:(NSRect)aRect
{
	return [[self alloc] initWithOvalInRect:aRect];
}

+ (DKDrawableShape*)drawableShapeWithCanonicalBezierPath:(NSBezierPath*)path
{
	NSAssert(NSEqualRects([path bounds], [self unitRectAtOrigin]), @"path bounds must be canonical!");

	DKDrawableShape* shape = [[self alloc] initWithCanonicalBezierPath:path];
	return shape;
}

+ (DKDrawableShape*)drawableShapeWithBezierPath:(NSBezierPath*)path
{
	return [self drawableShapeWithBezierPath:path
							  rotatedToAngle:0.0];
}

+ (DKDrawableShape*)drawableShapeWithBezierPath:(NSBezierPath*)path rotatedToAngle:(CGFloat)angle
{
	DKDrawableShape* shape = [[self alloc] initWithBezierPath:path
											   rotatedToAngle:angle];
	return shape;
}

+ (DKDrawableShape*)drawableShapeWithBezierPath:(NSBezierPath*)path withStyle:(DKStyle*)aStyle
{
	return [self drawableShapeWithBezierPath:path
							  rotatedToAngle:0.0
								   withStyle:aStyle];
}

+ (DKDrawableShape*)drawableShapeWithBezierPath:(NSBezierPath*)path rotatedToAngle:(CGFloat)angle withStyle:(DKStyle*)aStyle
{
	DKDrawableShape* shape = [[self alloc] initWithBezierPath:path
											   rotatedToAngle:angle
														style:aStyle];
	return shape;
}

#pragma mark -
#pragma mark - initialise a shape

- (instancetype)initWithRect:(NSRect)aRect
{
	return [self initWithRect:aRect
						style:[DKStyle defaultStyle]];
}

- (instancetype)initWithOvalInRect:(NSRect)aRect
{
	return [self initWithOvalInRect:aRect
							  style:[DKStyle defaultStyle]];
}

- (instancetype)initWithCanonicalBezierPath:(NSBezierPath*)path
{
	return [self initWithCanonicalBezierPath:path
									   style:[DKStyle defaultStyle]];
}

- (instancetype)initWithBezierPath:(NSBezierPath*)aPath
{
	return [self initWithBezierPath:aPath
					 rotatedToAngle:0.0];
}

- (instancetype)initWithBezierPath:(NSBezierPath*)aPath rotatedToAngle:(CGFloat)angle
{
	return [self initWithBezierPath:aPath
					 rotatedToAngle:angle
							  style:[DKStyle defaultStyle]];
}

- (instancetype)initWithRect:(NSRect)aRect style:(DKStyle*)aStyle
{
	self = [self initWithStyle:aStyle];
	if (self != nil) {
		NSPoint cp;
		cp.x = NSMidX(aRect);
		cp.y = NSMidY(aRect);

		[self setSize:aRect.size];
		[self setLocation:cp];
	}
	return self;
}

- (instancetype)initWithOvalInRect:(NSRect)aRect style:(DKStyle*)aStyle
{
	self = [self initWithStyle:aStyle];
	if (self != nil) {
		[[self path] removeAllPoints];
		[[self path] appendBezierPathWithOvalInRect:[[self class] unitRectAtOrigin]];

		NSPoint cp;
		cp.x = NSMidX(aRect);
		cp.y = NSMidY(aRect);

		[self setSize:aRect.size];
		[self setLocation:cp];
	}
	return self;
}

- (instancetype)initWithCanonicalBezierPath:(NSBezierPath*)path style:(DKStyle*)aStyle
{
	NSAssert(path != nil, @"can't initialize with a nil path");

	// check the path is canonical:

	NSRect br = [path bounds];

	if (!NSEqualRects(br, [[self class] unitRectAtOrigin]))
		[NSException raise:NSInternalInconsistencyException
					format:@"attempt to initialise shape with a non-canonical path"];

	self = [self initWithStyle:aStyle];
	if (self != nil) {
		[self setPath:path];
	}
	return self;
}

- (instancetype)initWithBezierPath:(NSBezierPath*)aPath style:(DKStyle*)aStyle
{
	return [self initWithBezierPath:aPath
					 rotatedToAngle:0.0
							  style:aStyle];
}

- (instancetype)initWithBezierPath:(NSBezierPath*)aPath rotatedToAngle:(CGFloat)angle style:(DKStyle*)style
{
	NSAssert(aPath != nil, @"attempt to initialise shape with a nil path");

	NSRect br = [aPath bounds];

	if (angle != 0.0) {
		// if initially rotated, bounds must be compensated for the angle

		aPath = [aPath rotatedPath:-angle];
		br = [aPath bounds];
	}

	if (br.size.width <= 0.0 || br.size.height <= 0.0) {
		return nil;
	}

	self = [self initWithRect:br
						style:style];

	if (self != nil) {
		NSAffineTransform* xfm = [self inverseTransform];
		NSBezierPath* transformedPath = [xfm transformBezierPath:aPath];

		[self setPath:transformedPath];
		[self setAngle:angle];
	}

	return self;
}

#pragma mark -
#pragma mark - path operations

/** @brief Sets the shape's path to be the given path

 Path must be bounded by the unit rect, centred at the origin. If you have some other, arbitrary path,
 the method adoptPath: will probably be what you want.
 @param path the path, bounded by a unit rect centred at the origin
 */
- (void)setPath:(NSBezierPath*)path
{
	NSAssert(path != nil, @"can't set a nil path");
	NSAssert(![path isEmpty], @"can't set an empty path");

	NSRect oldBounds = [self bounds];
	mBoundsCache = NSZeroRect;

	// sanity check the path - if it's not canonical, throw. Note that testing for exact equality doesn't work - the
	// rect is sometimes a tiny amount off due to fp rounding errors in the transformation. This is intended to
	// catch gross abuses or misunderstanding of this method.

	if (!AreSimilarRects([path bounds], [[self class] unitRectAtOrigin], 0.01)) {
		NSLog(@"path bounds = %@", NSStringFromRect([path bounds]));
		[NSException raise:NSInternalInconsistencyException
					format:@"attempt to set non-canonical path in %@", self];
	}

	[[self undoManager] registerUndoWithTarget:self
									  selector:@selector(setPath:)
										object:m_path];

	m_path = path;
	[self notifyVisualChange];
	[self notifyGeometryChange:oldBounds];
}

/** @brief Returns the shape's original path
 @return the original path, transformed only by any active distortion transform, but not by the shape's
 overall scale, position or rotation.
 */
- (NSBezierPath*)path
{
	NSBezierPath* pth = m_path;

	if ([self distortionTransform] != nil)
		pth = [[self distortionTransform] transformBezierPath:pth];

	return pth;
}

@synthesize path = m_path;

- (void)reshapePath
{
}

- (void)adoptPath:(NSBezierPath*)path
{
	// if the current size is zero, a path cannot be adopted because the transform ends up performing a divide by zero,
	// and the canonical path cannot be calculated.

	if ([self size].width == 0.0 || [self size].height == 0.0)
		[NSException raise:NSInternalInconsistencyException
					format:@"cannot adopt the path because the object has an invalid height or width - divide by zero."];

	[self notifyVisualChange];

	NSRect br = [path bounds];
	CGFloat angl = [self angle];

	if (angl != 0.0) {
		// if initially rotated, bounds must be compensated for the angle

		NSPoint cp = [self location];

		path = [path rotatedPath:-angl
					  aboutPoint:cp];
		br = [path bounds];
		[self setAngle:0];
	}

	NSPoint loc = NSMakePoint(NSMidX(br), NSMidY(br));

	[self setDistortionTransform:nil];
	[self setSize:br.size];
	[self setOffset:NSZeroSize];
	[self setLocation:loc];

	// get the shape's transform and invert it

	NSAffineTransform* xfm = [self inverseTransform];

	// transform the path back to the shape's canonical bounds and origin

	NSBezierPath* transformedPath = [xfm transformBezierPath:path];

	// now set that path as the shape's path

	[self setPath:transformedPath];
	[self setAngle:angl];
	[self notifyVisualChange];
}

/** @brief Returns the shape's path after transforming using the shape's location, size and rotation angle
 @return the path transformed to its final form
 */
- (NSBezierPath*)transformedPath
{
	NSBezierPath* path = [self path];

	if (path != nil && ![path isEmpty])
		return [[self transformIncludingParent] transformBezierPath:path];
	else
		return nil;
}

#pragma mark -
#pragma mark - geometry

- (NSAffineTransform*)transformIncludingParent
{
	NSAffineTransform* xform = [self transform];
	NSAffineTransform* parentTransform = [self containerTransform];

	if (parentTransform)
		[xform appendTransform:parentTransform];

	return xform;
}

- (NSAffineTransform*)inverseTransform
{
	NSAffineTransform* tfm = [self transform];
	[tfm invert];

	return tfm;
}

- (NSPoint)locationIgnoringOffset
{
	return [[self transform] transformPoint:NSZeroPoint];
}

#pragma mark -

- (void)rotateUsingReferencePoint:(NSPoint)rp constrain:(BOOL)constrain
{
	NSPoint oo = [self knobPoint:kDKDrawableShapeOriginTarget];

	CGFloat rotationKnobAngle = [self knobAngleFromOrigin:kDKDrawableShapeRotationHandle];
	CGFloat angle = atan2(rp.y - oo.y, rp.x - oo.x) - rotationKnobAngle;

	CGFloat dist = hypot(rp.x - oo.x, rp.y - oo.y);

	if (constrain) {
		CGFloat rem = fmod(angle, sAngleConstraint);

		if (rem > sAngleConstraint / 2.0)
			angle += (sAngleConstraint - rem);
		else
			angle -= rem;
	}

	// post update prior to recalculating sTempRotationPt

	mBoundsCache = NSZeroRect;
	[self notifyVisualChange];

	CGFloat ta = angle + rotationKnobAngle;

	sTempRotationPt.x = oo.x + (dist * cos(ta));
	sTempRotationPt.y = oo.y + (dist * sin(ta));

	mBoundsCache = NSZeroRect;
	[self notifyVisualChange];
	[self setAngle:angle];
}

- (void)moveKnob:(NSInteger)knobPartCode toPoint:(NSPoint)p allowRotate:(BOOL)rotate constrain:(BOOL)constrain
{
	// if the knob isn't allowed by the class knobmask, ignore it

	if (([[self class] knobMask] & knobPartCode) == 0)
		return;

	if (knobPartCode == kDKDrawableShapeOriginTarget) {
		NSAffineTransform* ti = [self transform];
		[ti invert];

		NSPoint op = [ti transformPoint:p];

		NSSize offs;

		offs.width = op.x;
		offs.height = op.y;

		// limit offs to within the unit square

		if (offs.width > 0.5)
			offs.width = 0.5;

		if (offs.width < -0.5)
			offs.width = -0.5;

		if (offs.height > 0.5)
			offs.height = 0.5;

		if (offs.height < -0.5)
			offs.height = -0.5;

		[self setOffset:offs];
	} else {
		CGFloat dx, dy, ka;

		dx = p.x - [self location].x;
		dy = p.y - [self location].y;
		ka = [self knobAngleFromOrigin:knobPartCode];

		// rotation

		if (rotate)
			[self setAngle:atan2(dy, dx) - ka];

		// scaling

		// normalise the mouse point by cancelling out any overall rotation.

		CGFloat pa = atan2(dy, dx) - [self angle];
		CGFloat radius = hypot(dx, dy);
		CGFloat ndx, ndy;

		ndx = radius * cos(pa);
		ndy = radius * sin(pa);

		// whether we are adjusting the scale width, height or both depends on which knob we have hit

		NSSize oldSize = [self size];
		CGFloat scx, scy;
		NSUInteger kbMask;

		// allow for offset, which is where the anchor for the resize is currently set.

		NSSize offset = [self offset];

		kbMask = kDKDrawableShapeHorizontalSizingKnobs;

		if ((knobPartCode & kbMask) != 0) {
			if ((knobPartCode & kDKDrawableShapeAllLeftHandles) != 0)
				scx = ndx / -(offset.width + 0.5);
			else
				scx = ndx / (0.5 - offset.width);
		} else
			scx = oldSize.width;

		kbMask = kDKDrawableShapeVerticalSizingKnobs;

		if ((knobPartCode & kbMask) != 0) {
			if ((knobPartCode & kDKDrawableShapeAllTopHandles) != 0)
				scy = ndy / -(offset.height + 0.5);
			else
				scy = ndy / (0.5 - offset.height);
		} else
			scy = oldSize.height;

		// apply constraint. Which edge dictates the size depends on which knobs we are dragging

		if (constrain) {
			BOOL xNeg, yNeg;

			xNeg = scx < 0;
			yNeg = scy < 0;

			if ((knobPartCode & kbMask) != 0) {
				scx = scy / sAspect;

				if (xNeg != yNeg)
					scx = -scx;
			} else
				scy = sAspect * scx;
		}

		// protect against possible infinities if anchor point is placed at same edge as dragging point

		if (isinf(scx) || isinf(scy) || isnan(scx) || isnan(scy))
			return;

		[self setSize:NSMakeSize(scx, scy)];
	}
}

#pragma mark -

- (void)flipHorizontally
{
	NSSize ss = [self size];
	ss.width *= -1.0;
	[self setSize:ss];

	CGFloat angle = [self angle];
	[self setAngle:-angle];
}

- (void)flipVertically
{
	NSSize ss = [self size];
	ss.height *= -1.0;
	[self setSize:ss];

	CGFloat angle = [self angle];
	[self setAngle:-angle];
}

#pragma mark -

- (void)resetBoundingBox
{
	CGFloat angl = [self angle];

	NSBezierPath* path = [[self transformedPath] rotatedPath:-angl];

	[self setAngle:0.0];
	[self adoptPath:path];
	[self setAngle:angl];
}

- (void)resetBoundingBoxAndRotation
{
	// resets the bounding box and rotation angle. The shape's appearance and apparent position etc are not changed.

	NSBezierPath* path = [[self transformedPath] copy];

	[self setAngle:0.0];
	[self adoptPath:path];
}

- (void)adjustToFitGrid:(DKGridLayer*)grid
{
	NSInteger k, knob[4] = { kDKDrawableShapeTopLeftHandle, kDKDrawableShapeTopRightHandle, kDKDrawableShapeBottomLeftHandle, kDKDrawableShapeBottomRightHandle };

	for (k = 3; k >= 0; --k) {
		NSPoint corner = [grid nearestGridIntersectionToPoint:[self knobPoint:knob[k]]];

		[self setDragAnchorToPart:[self partcodeOppositeKnob:knob[k]]];
		[self moveKnob:knob[k]
				toPoint:corner
			allowRotate:NO
			  constrain:NO];
		[self setOffset:sTempSavedOffset];
	}
}

#pragma mark -

- (BOOL)allowSizeKnobsToRotateShape
{
	return NO;
}

/** @brief Given a partcode for one of the control knobs, this returns a rect surrounding its current position

 The DKKnob class is used to compute the actual rect size, and it should also be called to perform
 the final hit-testing because it takes into account the actual path shape of the knob.
 @param knobPartCode the partcode for the knob, which is private to the shape class
 @return a rect, centred on the knob's current point
 */
- (NSRect)knobRect:(NSInteger)knobPartCode
{
	DKKnobType knobType = [self knobTypeForPartCode:knobPartCode];
	NSPoint p = [self knobPoint:knobPartCode];

	NSRect kr;

	if ([[self layer] knobs]) {
		kr = [[[self layer] knobs] controlKnobRectAtPoint:p
												   ofType:knobType];

		if (kr.size.width < 1 || kr.size.height < 1)
			kr = NSInsetRect(kr, -3, -3);
	} else {
		// if no owner, still pass back a valid rect - this is to ensure that the bounds can be determined correctly even
		// when no owner is set.

		kr = NSMakeRect(p.x, p.y, 0, 0);
		kr = NSInsetRect(kr, -3, -3);
	}

	return kr;
}

- (NSPoint)convertPointFromRelativeLocation:(NSPoint)rloc
{
	if ([self distortionTransform] != nil)
		rloc = [[self distortionTransform] transformPoint:rloc
												 fromRect:[[self class] unitRectAtOrigin]];

	NSAffineTransform* tx = [self transformIncludingParent];
	return [tx transformPoint:rloc];
}

#pragma mark -
#pragma mark - private

/** @brief Return the rectangle that bounds the current control knobs
 @return a rect, the union of all active knob rectangles
 */
- (NSRect)knobBounds
{
	NSRect br = NSZeroRect;

	if ([self operationMode] == kDKShapeTransformStandard) {
		br = NSUnionRect(br, [self knobRect:kDKDrawableShapeTopLeftHandle]);
		br = NSUnionRect(br, [self knobRect:kDKDrawableShapeBottomRightHandle]);
		br = NSUnionRect(br, [self knobRect:kDKDrawableShapeOriginTarget]);

		if ([self angle] != 0.0) {
			br = NSUnionRect(br, [self knobRect:kDKDrawableShapeTopRightHandle]);
			br = NSUnionRect(br, [self knobRect:kDKDrawableShapeBottomLeftHandle]);
		}

		if (m_inRotateOp) {
			NSRect rk = [[[self layer] knobs] controlKnobRectAtPoint:sTempRotationPt
															  ofType:kDKRotationKnobType];
			br = NSUnionRect(br, rk);
		}
	} else {
		br = NSUnionRect(br, [self knobRect:kDKDrawableShapeTopLeftDistort]);
		br = NSUnionRect(br, [self knobRect:kDKDrawableShapeTopRightDistort]);
		br = NSUnionRect(br, [self knobRect:kDKDrawableShapeBottomLeftDistort]);
		br = NSUnionRect(br, [self knobRect:kDKDrawableShapeBottomRightDistort]);
	}

	return br;
}

/** @brief Returns the partcode of the knob that is "opposite" the one passed
 @param knobPartCode a knob part code
 @return another knob part code
 */
- (NSInteger)partcodeOppositeKnob:(NSInteger)knobPartCode
{
	static NSInteger pc[] = { kDKDrawableShapeRightHandle, kDKDrawableShapeBottomHandle, kDKDrawableShapeLeftHandle, kDKDrawableShapeTopHandle,
		kDKDrawableShapeBottomRightHandle, kDKDrawableShapeBottomLeftHandle,
		kDKDrawableShapeTopRightHandle, kDKDrawableShapeTopLeftHandle };

	if (knobPartCode > kDKDrawableShapeBottomRightHandle)
		return knobPartCode;
	else {
		NSInteger indx = 0;
		NSUInteger mask = 1;

		while ((mask & knobPartCode) == 0 && indx < 8) {
			++indx;
			mask <<= 1;
		}

		return pc[indx];
	}
}

- (void)setDragAnchorToPart:(NSInteger)part
{
	// saves the offset, then sets the current offset to the location of the given part. This sets the drag origin to the given point.
	// usually this will be the knob opposite the one being dragged.

	sTempSavedOffset = m_offset;

	NSPoint p = [self canonicalCornerPoint:part];

	NSSize offs;

	offs.width = p.x;
	offs.height = p.y;

	[self setOffset:offs];
}

/** @brief Returns the angle of a given knob relative to the shape's offset

 Part of the process of setting up an interactive drag of a knob
 @param knobPartCode a knob part code
 @return the knob's angle relative to the origin
 */
- (CGFloat)knobAngleFromOrigin:(NSInteger)knobPartCode
{
	NSPoint p;
	CGFloat dy, dx;

	if (knobPartCode == kDKDrawableShapeRotationHandle)
		p = [self rotationKnobPoint];
	else
		p = [self knobPoint:knobPartCode];

	dy = p.y - [self location].y;
	dx = p.x - [self location].x;

	return atan2(dy, dx) - [self angle];
}

- (void)drawKnob:(NSInteger)knobPartCode
{
	// if knob disallowed by mask, ignore it

	if ([[self class] knobMask] & knobPartCode) {
		NSPoint kp = [self knobPoint:knobPartCode];
		DKKnob* knobs = [[self layer] knobs];
		DKKnobType knobType = [self knobTypeForPartCode:knobPartCode];
		NSColor* selColour = (knobType == kDKRotationKnobType || knobType == kDKCentreTargetKnobType) ? nil : [[self layer] selectionColour];

		[knobs drawKnobAtPoint:kp
						ofType:knobType
						 angle:[self angle]
			   highlightColour:selColour];

#ifdef qIncludeGraphicDebugging
		if (m_showPartcodes) {
			kp.x += 2;
			kp.y += 2;
			[knobs drawPartcode:knobPartCode
						atPoint:kp
					   fontSize:10];
		}

		if (m_showTargets) {
			NSRect kr = [self knobRect:knobPartCode];

			[[NSColor magentaColor] set];
			NSFrameRectWithWidth(kr, 0.0);
		}
#endif
	}
}

/** @brief Given the partcode of a knob, this returns its corner of the canonical unit rect

 The result needs to be transformed to the final position
 @param knobPartCode the partcode for the knob, which is private to the shape class
 @return the associated knob's corner on the unit rect
 */
- (NSPoint)canonicalCornerPoint:(NSInteger)knobPartCode
{
	NSRect r = [[self class] unitRectAtOrigin];
	NSPoint kp;

	switch (knobPartCode) {
	default:
		return NSZeroPoint;

	case kDKDrawableShapeTopLeftHandle:
		kp.x = NSMinX(r);
		kp.y = NSMinY(r);
		break;

	case kDKDrawableShapeTopHandle:
		kp.x = NSMidX(r);
		kp.y = NSMinY(r);
		break;

	case kDKDrawableShapeTopRightHandle:
		kp.x = NSMaxX(r);
		kp.y = NSMinY(r);
		break;

	case kDKDrawableShapeRightHandle:
		kp.x = NSMaxX(r);
		kp.y = NSMidY(r);
		break;

	case kDKDrawableShapeBottomRightHandle:
		kp.x = NSMaxX(r);
		kp.y = NSMaxY(r);
		break;

	case kDKDrawableShapeBottomHandle:
		kp.x = NSMidX(r);
		kp.y = NSMaxY(r);
		break;

	case kDKDrawableShapeBottomLeftHandle:
		kp.x = NSMinX(r);
		kp.y = NSMaxY(r);
		break;

	case kDKDrawableShapeLeftHandle:
		kp.x = NSMinX(r);
		kp.y = NSMidY(r);
		break;

	case kDKDrawableShapeObjectCentre:
		kp.x = NSMidX(r);
		kp.y = NSMidY(r);
		break;

	case kDKDrawableShapeOriginTarget:
		kp.x = [self offset].width;
		kp.y = [self offset].height;
		break;

	case kDKDrawableShapeRotationHandle:
		kp.y = NSMidY(r);
		kp.x = (NSMaxX(r) + NSMidX(r)) * 0.75;
		break;
	}

	return kp;
}

- (NSPoint)knobPoint:(NSInteger)knobPartCode
{
	NSPoint kp;
	NSRect r = [[self class] unitRectAtOrigin];
	NSPoint qp[4];

	switch (knobPartCode) {
	default:
		kp = [self canonicalCornerPoint:knobPartCode];
		break;

	case kDKDrawableShapeTopLeftDistort:
		[[self distortionTransform] getEnvelopePoints:qp];
		kp = qp[0];
		break;

	case kDKDrawableShapeTopRightDistort:
		[[self distortionTransform] getEnvelopePoints:qp];
		kp = qp[1];
		break;

	case kDKDrawableShapeBottomRightDistort:
		[[self distortionTransform] getEnvelopePoints:qp];
		kp = qp[2];
		break;

	case kDKDrawableShapeBottomLeftDistort:
		[[self distortionTransform] getEnvelopePoints:qp];
		kp = qp[3];
		break;
	}

	// if it's not a distortion handle, apply the distortion transform

	if (knobPartCode < kDKDrawableShapeTopLeftDistort && [self distortionTransform] != nil)
		kp = [[self distortionTransform] transformPoint:kp
											   fromRect:r];

	NSAffineTransform* tx = [self transformIncludingParent];
	return [tx transformPoint:kp];
}

/** @brief Given a partcode, this returns the knob type for it

 The knob type is used to tell DKKnob the function of a knob in broad terms, which in turn it
 maps to a specific kind of knob appearance. For convenience the locked flag is also passed as
 part of the knob type.
 @param pc a knob part code
 @return a knob type, as defined by DKKnob (see DKCommonTypes.h)
 */
- (DKKnobType)knobTypeForPartCode:(NSInteger)pc
{
	DKKnobType knobType;

	if (pc == kDKDrawableShapeRotationHandle)
		knobType = kDKRotationKnobType;
	else if (pc == kDKDrawableShapeOriginTarget)
		knobType = kDKCentreTargetKnobType;
	else
		knobType = kDKBoundingRectKnobType;

	if ([self locked])
		knobType |= kDKKnobIsDisabledFlag;

	return knobType;
}

#pragma mark -

- (NSString*)undoActionNameForPartCode:(NSInteger)pc
{
	NSString* s = nil;

	switch (pc) {
	case kDKDrawingNoPart:
		s = @"????"; // this shouldn't happen
		break;

	case kDKDrawingEntireObjectPart:
		s = NSLocalizedString(@"Move", @"undo string for move object");
		break;

	case kDKDrawableShapeRotationHandle:
		s = NSLocalizedString(@"Rotate", @"undo string for rotate object");
		break;

	case kDKDrawableShapeOriginTarget:
		s = NSLocalizedString(@"Move Origin", @"undo string for object offset");
		break;

	case kDKDrawableShapeTopLeftDistort:
	case kDKDrawableShapeTopRightDistort:
	case kDKDrawableShapeBottomRightDistort:
	case kDKDrawableShapeBottomLeftDistort: {
		switch ([self operationMode]) {
		default:
			s = NSLocalizedString(@"Distortion Transform", @"undo string for object distortion");
			break;

		case kDKShapeTransformHorizontalShear:
			s = NSLocalizedString(@"Horizontal Shear", @"undo string for h shear");
			break;

		case kDKShapeTransformVerticalShear:
			s = NSLocalizedString(@"Vertical Shear", @"undo string for v shear");
			break;

		case kDKShapeTransformPerspective:
			s = NSLocalizedString(@"Perspective Transform", @"undo string for perspective");
			break;
		}
	} break;

	default:
		s = NSLocalizedString(@"Resize", @"undo string for resize object");
		break;
	}

	return s;
}

/** @brief Allows the distortion transform to be adjusted interactively
 @param partCode a knob partcode for the distortion envelope private to the class
 @param p the point where the knob should be moved to.
 */
- (void)moveDistortionKnob:(NSInteger)partCode toPoint:(NSPoint)p
{
	NSInteger qi = 0;

	switch (partCode) {
	case kDKDrawableShapeTopLeftDistort:
		qi = 0;
		break;

	case kDKDrawableShapeTopRightDistort:
		qi = 1;
		break;

	case kDKDrawableShapeBottomRightDistort:
		qi = 2;
		break;

	case kDKDrawableShapeBottomLeftDistort:
		qi = 3;
		break;

	default:
		return; // ignore all others
	}

	//	LogEvent_(kStateEvent, @"adjusting transform part %d", qi );

	NSPoint old = [self knobPoint:partCode];

	[[[self undoManager] prepareWithInvocationTarget:self] moveDistortionKnob:partCode
																	  toPoint:old];

	[self notifyVisualChange];

	NSAffineTransform* tfm = [self transform];
	[tfm invert];

	p = [tfm transformPoint:p];

	DKDistortionTransform* t = [self distortionTransform];
	NSPoint q[4];
	[t getEnvelopePoints:q];

	switch ([self operationMode]) {
	default:
	case kDKShapeTransformFreeDistort:
		q[qi] = p;
		[t setEnvelopePoints:q];
		break;

	case kDKShapeTransformHorizontalShear:
		if (qi == 2 || qi == 3)
			[t shearHorizontallyBy:-(p.x - q[qi].x)];
		else
			[t shearHorizontallyBy:p.x - q[qi].x];
		break;

	case kDKShapeTransformVerticalShear:
		if (qi == 0 || qi == 3)
			[t shearVerticallyBy:-(p.y - q[qi].y)];
		else
			[t shearVerticallyBy:p.y - q[qi].y];
		break;

	case kDKShapeTransformPerspective:
		if (qi == 1 || qi == 3)
			[t differentialPerspectiveBy:-(p.y - q[qi].y)];
		else
			[t differentialPerspectiveBy:p.y - q[qi].y];
		break;
	}

	[self notifyVisualChange];
}

/** @brief In distortion mode, draws the envelope and knobs of the current distortion transform around the shape
 */
- (void)drawDistortionEnvelope
{
	NSPoint q[4];
	NSBezierPath* ep;

	ep = [NSBezierPath bezierPath];

	q[0] = [self knobPoint:kDKDrawableShapeTopLeftDistort];
	q[1] = [self knobPoint:kDKDrawableShapeTopRightDistort];
	q[2] = [self knobPoint:kDKDrawableShapeBottomRightDistort];
	q[3] = [self knobPoint:kDKDrawableShapeBottomLeftDistort];

	[ep moveToPoint:q[0]];
	[ep lineToPoint:q[1]];
	[ep lineToPoint:q[2]];
	[ep lineToPoint:q[3]];
	[ep closePath];

	[[NSColor purpleColor] setStroke];
	[ep setLineWidth:1.0];
	[ep stroke];

	[self drawKnob:kDKDrawableShapeTopLeftDistort];
	[self drawKnob:kDKDrawableShapeTopRightDistort];
	[self drawKnob:kDKDrawableShapeBottomRightDistort];
	[self drawKnob:kDKDrawableShapeBottomLeftDistort];

	[self drawKnob:kDKDrawableShapeOriginTarget];
}

#pragma mark -

/** @brief Prepares for a rotation operation by setting up the info window and rotation state info

 Called internally from a mouse down event
 */
- (void)prepareRotation
{
	NSPoint rkp = [self rotationKnobPoint];

	[self updateInfoForOperation:kDKShapeOperationRotate
						 atPoint:rkp];
	m_inRotateOp = YES;
	sTempRotationPt = rkp;

	[self notifyVisualChange];
}

- (NSPoint)rotationKnobPoint
{
	return [self knobPoint:kDKDrawableShapeRotationHandle];
}

/** @brief Display the appropriate information in the info window when dragging during various operations

 The window is owned by the layer, this supplies its content. If turned off this is a no-op
 @param op what info to display
 @param mp where the mouse is currently
 */
- (void)updateInfoForOperation:(DKShapeEditOperation)op atPoint:(NSPoint)mp
{
	if ([[self class] displaysSizeInfoWhenDragging]) {
		NSString* infoStr;
		NSString *fmt1, *fmt2;
		NSArray* fmt3;

		switch (op) {
		default:
		case kDKShapeOperationResize:
			fmt1 = [[self drawing] formattedConvertedLength:[self size].width];
			fmt2 = [[self drawing] formattedConvertedLength:[self size].height];
			infoStr = [NSString stringWithFormat:@"w: %@\nh: %@", fmt1, fmt2];
			break;

		case kDKShapeOperationMove:
			fmt3 = [[self drawing] formattedConvertedPoint:[self location]];
			infoStr = [NSString stringWithFormat:@"x: %@\ny: %@", [fmt3 objectAtIndex:0], [fmt3 objectAtIndex:1]];
			break;

		case kDKShapeOperationRotate:
			infoStr = [NSString stringWithFormat:@"%.1f°", [self angleInDegrees]]; // UTF-8 for degree symbol is 0xB0
			break;
		}

		if (sInfoWindowColour != nil)
			[[self layer] setInfoWindowBackgroundColour:sInfoWindowColour];

		[[self layer] showInfoWindowWithString:infoStr
									   atPoint:mp];
	}
}

#pragma mark -
#pragma mark - operation modes

/** @brief Sets what kind of operation is performed by dragging the shape's control knobs

 Switches between normal location, scaling and rotation operations, and those involving the
 distortion transform (shearing, free distort, perpective).
 */
- (void)setOperationMode:(DKShapeTransformOperation)mode
{
	if (mode != m_opMode) {
		[[[self undoManager] prepareWithInvocationTarget:self] setOperationMode:m_opMode];

		m_opMode = mode;

		if (mode != kDKShapeTransformStandard && ([self distortionTransform] == nil)) {
			[self setDistortionTransform:[DKDistortionTransform transformWithInitialRect:[[self class] unitRectAtOrigin]]];
			[self notifyVisualChange];
		}

		if (mode == kDKShapeTransformStandard) {
			//[self setDistortionTransform:nil];
			[self resetBoundingBox];
		}
	}
}

@synthesize operationMode = m_opMode;

/** @brief Returns the current operation mode
 @return ops mode
 */
- (DKShapeTransformOperation)operationMode
{
	return m_opMode;
}

#pragma mark -
#pragma mark - distortion ops

/** @brief Sets the current distortion transform to the one passed.

 This can be used in two ways. Either pre-prepare a transform and set it, which will immediately have
 its effect on the shape. This is the hard way. The easy way is to set the distort mode which creates
 a transform as needed and allows it to be changed interactively.
 @param dt a distortion transform
 */
- (void)setDistortionTransform:(DKDistortionTransform*)dt
{
	if (dt != m_distortTransform) {
		m_distortTransform = dt;

		[self notifyVisualChange];

		if (m_distortTransform == nil)
			[self setOperationMode:kDKShapeTransformStandard];
	}
}

@synthesize distortionTransform = m_distortTransform;

#pragma mark -
#pragma mark - convert to editable path

- (DKDrawablePath*)makePath
{
	NSBezierPath* path = [[self transformedPath] copy];

	Class pathClass = [DKDrawableObject classForConversionRequestFor:[DKDrawablePath class]];
	DKDrawablePath* dp = [pathClass drawablePathWithBezierPath:path
													 withStyle:[self style]];

	[dp setUserInfo:[self userInfo]];

	return dp;
}

- (NSArray*)breakApart
{
	// returns a list of path objects each containing one subpath from this object's path. If this path only has one subpath, this
	// returns one object in the array which is equivalent to a copy.

	NSArray* subpaths = [[self renderingPath] subPaths];
	NSMutableArray* newObjects;

	newObjects = [[NSMutableArray alloc] init];

	for (NSBezierPath* pp in subpaths) {
		if (![pp isEmpty]) {
			DKDrawableShape* dp = [[self class] drawableShapeWithBezierPath:pp
															 rotatedToAngle:[self angle]];

			[dp setStyle:[self style]];
			[dp setUserInfo:[self userInfo]];
			[newObjects addObject:dp];
		}
	}

	return newObjects;
}

#pragma mark -
#pragma mark - user actions

- (IBAction)convertToPath:(id)sender
{
#pragma unused(sender)

	// converts the shape to a path object and replaces itself in the owning layer with the new shape.

	DKObjectDrawingLayer* layer = (DKObjectDrawingLayer*)[self layer];
	NSInteger myIndex = [layer indexOfObject:self];

	DKDrawablePath* po = [self makePath];

	[po willBeAddedAsSubstituteFor:self
						   toLayer:layer];

	[layer recordSelectionForUndo];
	[layer addObject:po
			 atIndex:myIndex];
	[layer replaceSelectionWithObject:po];
	[layer removeObject:self];
	[layer commitSelectionUndoWithActionName:NSLocalizedString(@"Convert To Path", @"undo string for convert to path")];
}

- (IBAction)unrotate:(id)sender
{
#pragma unused(sender)

	[self setAngle:0.0];
	[[self undoManager] setActionName:NSLocalizedString(@"Unrotate", @"undo string for shape unrotate")];
}

- (IBAction)rotate:(id)sender
{
	// sets the current rotation angle to the sender's floatValue in degrees.

	CGFloat angle = DEGREES_TO_RADIANS([sender doubleValue]);

	[self setAngle:angle];
	[[self undoManager] setActionName:NSLocalizedString(@"Rotation", @"undo string for shape rotate")];
}

- (IBAction)setDistortMode:(id)sender
{
	NSInteger m = [sender tag];
	[self setOperationMode:m];
	[self notifyVisualChange];
	[[self undoManager] setActionName:NSLocalizedString(@"Change Transform Mode", @"undo string for change transform mode")];
}

- (IBAction)resetBoundingBox:(id)sender
{
#pragma unused(sender)

	[self resetBoundingBoxAndRotation];
	[[self undoManager] setActionName:NSLocalizedString(@"Reset Bounding Box", @"undo string for reset bbox")];
}

- (IBAction)toggleHorizontalFlip:(id)sender
{
#pragma unused(sender)

	[self flipHorizontally];
	[[self undoManager] setActionName:NSLocalizedString(@"Flip Horizontally", @"h flip")];
}

- (IBAction)toggleVerticalFlip:(id)sender
{
#pragma unused(sender)

	[self flipVertically];
	[[self undoManager] setActionName:NSLocalizedString(@"Flip Vertically", @"v flip")];
}

- (IBAction)pastePath:(id)sender
{
#pragma unused(sender)

	// if there is a native shape or path on the pb, use its path for this shape. This conveniently allows you to draw a fancy
	// path and apply it to an existing shape - especially useful for image and text shapes.

	NSPasteboard* pb = [NSPasteboard generalPasteboard];
	NSArray* objects = [DKDrawableObject nativeObjectsFromPasteboard:pb];

	// this only works if there is just one object on the pb - otherwise it's ambiguous which path to use

	if (objects != nil && [objects count] == 1) {
		DKDrawableObject* od = [objects lastObject];

		NSBezierPath* path = [od renderingPath];
		NSRect br = [path bounds];

		if (path != nil && ![path isEmpty] && br.size.width > 0.0 && br.size.height > 0.0) {
			// set this path, but we don't want to use adoptPath: here because it changes our location, etc. Instead
			// we need to transform the path back to its canonical form and set it directly.

			NSAffineTransform* tfm;

			if ([od isKindOfClass:[DKDrawablePath class]]) {
				// for paths coming from path objects, just translate and scale them directly back
				// to the unit rect at the origin.

				CGFloat x, y;

				x = NSMidX(br);
				y = NSMidY(br);

				tfm = [NSAffineTransform transform];

				[tfm scaleXBy:1.0 / NSWidth(br)
						  yBy:1.0 / NSHeight(br)];
				[tfm translateXBy:-x
							  yBy:-y];
			} else {
				// for paths originating from shapes, the shape can do the work and this allows for any rotation
				// offset, etc.

				tfm = [od transform];
				[tfm invert];
			}
			path = [tfm transformBezierPath:path];

			[self setPath:path];
			[[self undoManager] setActionName:NSLocalizedString(@"Paste Path", @"undo string for paste path")];
		}
	}
}

- (BOOL)canPastePathWithPasteboard:(NSPasteboard*)pb
{
	NSString* type = [pb availableTypeFromArray:@[kDKDrawableObjectInfoPasteboardType]];
	if (type) {
		DKPasteboardInfo* info = [DKPasteboardInfo pasteboardInfoWithPasteboard:pb];
		return [info count] == 1;
	}

	return NO;
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
		[odl recordSelectionForUndo];
		[odl addObjectsFromArray:broken];
		[odl removeObject:self];
		[odl exchangeSelectionWithObjectsFromArray:broken];
		[odl commitSelectionUndoWithActionName:NSLocalizedString(@"Break Apart", @"undo string for break apart")];
	}
}

#pragma mark -
#pragma mark As a DKDrawableObject

/** @brief Return the partcode that should be used by tools when initially creating a new object

 The client of this method is DKObjectCreationTool.
 */
+ (NSInteger)initialPartcodeForObjectCreation
{
	if (([self knobMask] & kDKDrawableShapeBottomRightHandle) == kDKDrawableShapeBottomRightHandle)
		return kDKDrawableShapeBottomRightHandle;
	else {
		// bottom/right not available, so return one that is

		NSInteger i;

		for (i = kDKDrawableShapeBottomLeftHandle; i >= kDKDrawableShapeLeftHandle; --i) {
			if (([self knobMask] & i) == i)
				return i;
		}

		return kDKDrawingNoPart;
	}
}

/** @brief Return the pasteboard types that instances of this class are able to receive
 @param op an operation contsnat (ignored)
 @return a list of pasteboard types that can be dropped or pasted on objects of this type
 */
+ (NSArray*)pasteboardTypesForOperation:(DKPasteboardOperationType)op
{
#pragma unused(op)
	return @[NSPasteboardTypeColor, NSPasteboardTypePDF, NSPasteboardTypeTIFF, (NSString*)kUTTypeFileURL,
		NSPasteboardTypeString, kDKStyleKeyPasteboardType, kDKStylePasteboardType];
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
	if (self != nil) {
		m_path = [NSBezierPath bezierPathWithRect:[[self class] unitRectAtOrigin]];

		if (m_path == nil) {
			return nil;
		}
	}
	return self;
}

/** @brief Return the shape's current rotation angle
 @return the shape's angle in radians
 */
- (CGFloat)angle
{
	return m_rotationAngle;
}

/** @brief Return the visual bounds of the object
 @return a rect, the apparent bounds of the shape
 */
- (NSRect)apparentBounds
{
	NSRect r = [[self transformedPath] bounds];

	if ([self style]) {
		NSSize as = [[self style] extraSpaceNeeded];

		r = NSInsetRect(r, -as.width, -as.height);

		// also make a small allowance for the rotation of the shape - this allows for the
		// hypoteneuse of corners

		CGFloat f = ABS(sin([self angle] * 2)) * ([[self style] maxStrokeWidth] * 0.36);

		r = NSInsetRect(r, -f, -f);
	}

	return r;
}

/** @brief Return the total bounds of the shape

 WARNING: bounds can be affected by the zoom factor of the current view, since knobs resize with
 zoom. Thus don't rely on bounds remaining unchanged when the zoom factor changes.
 @return a rect, the overall bounds of the shape
 */
- (NSRect)bounds
{
	if (NSEqualRects(mBoundsCache, NSZeroRect)) {
		NSRect r = NSZeroRect;

		if (![[self path] isEmpty]) {
			r = [self knobBounds];

			// add allowance for the style and angle

			NSSize as = [self extraSpaceNeeded];
			// also make a small allowance for the rotation of the shape - this allows for the
			// hypoteneuse of corners

			CGFloat f = ABS(sin([self angle] * 1.0)) * (MAX([[self style] maxStrokeWidth] * 0.5, 1.0) * 0.25);
			mBoundsCache = NSInsetRect(r, -(as.width + f), -(as.height + f));
		}
	}

	return mBoundsCache;
}

/**
 For hit testing, uses thickened stroke if necessary to make hitting easier
 */
- (void)drawContent
{
	if ([self isBeingHitTested]) {
		// for easier hit-testing of very thin or offset paths, the path is stroked using a
		// centre-aligned 2pt or greater stroke. This is substituted on the fly here and never visible to the user.

		BOOL hasStroke = [[self style] hasStroke];
		BOOL hasFill = !hasStroke || [[self style] hasFill] || [[self style] hasHatch];

		CGFloat strokeWidth = hasStroke ? MAX(2, [[self style] maxStrokeWidth]) : 0;

		DKStyle* temp = [DKStyle styleWithFillColour:hasFill ? [NSColor blackColor] : nil
										strokeColour:hasStroke ? [NSColor blackColor] : nil
										 strokeWidth:strokeWidth];
		[temp render:self];
	} else
		[super drawContent];
}

/**
 Return if knobs should be drawn. Default is true, override to change
 */
-(BOOL) shouldDrawKnobs {
       return YES;
}

/**
 Takes account of its internal state to draw the appropriate control knobs, etc
 */
- (void)drawSelectedState
{
	@autoreleasepool {

		if (m_inRotateOp) {
			[[[self layer] knobs] drawRotationBarWithKnobsFromCentre:[self knobPoint:kDKDrawableShapeOriginTarget]
															 toPoint:sTempRotationPt];

		} else {
			if ([self operationMode] != kDKShapeTransformStandard)
				[self drawDistortionEnvelope];
			else {
				// draw the bounding box:

				NSBezierPath* pp = [NSBezierPath bezierPathWithRect:[[self class] unitRectAtOrigin]];

				if ([self distortionTransform] != nil)
					pp = [[self distortionTransform] transformBezierPath:pp];

				[pp transformUsingAffineTransform:[self transformIncludingParent]];
				[self drawSelectionPath:pp];

				// draw the knobs:
				// n.b. drawKnob is a no-op for knobs not included by +knobMask

				if ([self shouldDrawKnobs]) {
					[self drawKnob:kDKDrawableShapeLeftHandle];
					[self drawKnob:kDKDrawableShapeTopHandle];
					[self drawKnob:kDKDrawableShapeRightHandle];
					[self drawKnob:kDKDrawableShapeBottomHandle];
					[self drawKnob:kDKDrawableShapeTopLeftHandle];
					[self drawKnob:kDKDrawableShapeTopRightHandle];
					[self drawKnob:kDKDrawableShapeBottomLeftHandle];
					[self drawKnob:kDKDrawableShapeBottomRightHandle];
				}

				// the other knobs and any hotspots are not drawn when in a locked state

				if (![self locked]) {
					[self drawKnob:kDKDrawableShapeRotationHandle];

					// draw the shape's origin target

					if (!m_hideOriginTarget)
						[self drawKnob:kDKDrawableShapeOriginTarget];

					// draw the hotspots

					[self drawHotspotsInState:kDKHotspotStateOn];
				}
			}
		}
	}
}

/** @brief Hit test the point against the object
 @param pt the point to test
 @return the partcode hit
 */
- (NSInteger)hitPart:(NSPoint)pt
{
	NSInteger pc = [super hitPart:pt];

	if (pc == kDKDrawingEntireObjectPart) {
		// here we need to carefully check if the hit is in the shape or not. It is in the bounds, but
		// the path might not contain it. However, the hit could be on the stroke or shadow so we need to test against
		// the cached bitmap copy of the shape.

		if (([[self style] hasFill] || [[self style] hasHatch]) && [[self transformedPath] containsPoint:pt])
			return kDKDrawingEntireObjectPart;

		if ([self pointHitsPath:pt])
			return kDKDrawingEntireObjectPart;

		pc = kDKDrawingNoPart;
	}

	return pc;
}

/** @brief Hit test the point against the object's selection knobs

 Only called if object is selected and unlocked
 @param pt the point to test
 @param snap YES if this is for detecting snaps, NO otherwise
 @return the partcode hit */
- (NSInteger)hitSelectedPart:(NSPoint)pt forSnapDetection:(BOOL)snap
{
	// it's helpful that parts are tested in the order which allows them to work even if the shape has zero size.

	DKKnob* knobs = [[self layer] knobs]; // performs the basic hit test based on the functional type of the knob
	NSPoint kp;
	DKKnobType knobType;
	NSRect kr;
	NSInteger knob;

	if ([self operationMode] == kDKShapeTransformStandard) {
		knobType = [self knobTypeForPartCode:kDKDrawableShapeOriginTarget];

		if (([[self class] knobMask] & kDKDrawableShapeOriginTarget) == kDKDrawableShapeOriginTarget) {
			if ([knobs hitTestPoint:pt
					  inKnobAtPoint:[self knobPoint:kDKDrawableShapeOriginTarget]
							 ofType:knobType
						   userInfo:nil])
				return kDKDrawableShapeOriginTarget;
		}

		knob = kDKDrawableShapeBottomRightHandle;
		knobType = [self knobTypeForPartCode:knob];

		while (knob > 0) {
			if (([[self class] knobMask] & knob) == knob) {
				if (snap) {
					kr = ScaleRect([self knobRect:knob], 2.0);

					if (NSMouseInRect(pt, kr, [[self drawing] isFlipped]))
						return knob;
				} else {
					kp = [self knobPoint:knob];

					if ([knobs hitTestPoint:pt
							  inKnobAtPoint:kp
									 ofType:knobType
								   userInfo:nil])
						return knob;
				}
			}

			knob >>= 1;
		}

		knobType = [self knobTypeForPartCode:kDKDrawableShapeRotationHandle];

		if (([[self class] knobMask] & kDKDrawableShapeRotationHandle) == kDKDrawableShapeRotationHandle) {
			if ([knobs hitTestPoint:pt
					  inKnobAtPoint:[self knobPoint:kDKDrawableShapeRotationHandle]
							 ofType:knobType
						   userInfo:nil])
				return kDKDrawableShapeRotationHandle;
		}
		// check for hits in hotspots

		DKHotspot* hs = [self hotspotUnderMouse:pt];

		if (hs)
			return [hs partcode];
	} else {
		knob = kDKDrawableShapeTopLeftDistort;

		while (knob <= kDKDrawableShapeBottomLeftDistort) {
			kr = [self knobRect:knob];

			if (snap)
				kr = ScaleRect(kr, 2.0);

			if (NSMouseInRect(pt, kr, [[self drawing] isFlipped]))
				return knob;

			knob <<= 1;
		}
	}

	// to allow snap to work with any part of the path, check if we are close to the path and if so return a special
	// partcode that pointForPartcode knows about. Need to record mouse point as it's not passed along in the next call.

	if (snap && NSMouseInRect(pt, [self bounds], YES) && [self pointHitsPath:pt]) {
		// need to now check that the point is close to the actual path, not just somewhere in the shape

		sMouseForPathSnap = pt;
		return kDKDrawableShapeSnapToPathEdge;
	}

	return kDKDrawingEntireObjectPart;
}

/** @brief Return the bounds of the shape, ignoring stylistic effects
 @return a rect, the pure path bounds
 */
- (NSRect)logicalBounds
{
	return [[self transformedPath] bounds];
}

/** @brief Sets the shape's location to the given point
 @param location the new location of the object
 */
- (void)setLocation:(NSPoint)location
{
	if (!NSEqualPoints(location, [self location]) && ![self locationLocked]) {
		NSRect oldBounds = [self bounds];
		[[[self undoManager] prepareWithInvocationTarget:self] setLocation:[self location]];

		[self notifyVisualChange];
		m_location = location;
		mBoundsCache = NSZeroRect;
		[self notifyVisualChange];
		[self notifyGeometryChange:oldBounds];
	}
}

- (NSPoint)location
{
	return m_location;
}

/** @brief Handle mouse down event in this object
 @param mp mouse point
 @param partcode the partcode hit, as returned by an earlier call to hitPart:
 @param evt the original event
 */
- (void)mouseDownAtPoint:(NSPoint)mp inPart:(NSInteger)partcode event:(NSEvent*)evt
{
	[super mouseDownAtPoint:mp
					 inPart:partcode
					  event:evt];

	// save the current aspect ratio in case we wish to constrain a resize:
	// if the size is zero assume square

	if (NSEqualSizes([self size], NSZeroSize))
		sAspect = 1.0;
	else
		sAspect = fabs([self size].height / [self size].width);

	// for rotation, set up a small info window to track the angle

	if (partcode == kDKDrawableShapeRotationHandle) {
		[self prepareRotation];
	} else if (partcode >= kDKHotspotBasePartcode) {
		[[self hotspotForPartCode:partcode] startMouseTracking:evt
														inView:[self currentView]];
	} else
		[self updateInfoForOperation:kDKShapeOperationResize
							 atPoint:mp];
}

/** @brief Handle a mouse drag in this object

 Calls necessary methods to interactively drag the hit part
 @param mp the mouse point
 @param partcode partcode being dragged
 @param evt the original event
 */
- (void)mouseDraggedAtPoint:(NSPoint)mp inPart:(NSInteger)partcode event:(NSEvent*)evt
{
	// modifier keys constrain shape sizing and rotation thus:

	// +shift	- constrain rotation to 15 degree intervals when rotating
	// +shift	- constrain aspect ratio of the shape to whatever it was at the time the mouse first went down
	// +option	- resize the shape from the centre
	// +option	- for rotation, snap mouse to the grid (normally not snapped for rotation operations)

	NSPoint omp = mp;

	if (![self mouseHasMovedSinceStartOfTracking]) {
		if (partcode >= kDKDrawableShapeLeftHandle && partcode <= kDKDrawableShapeBottomRightHandle) {
			m_hideOriginTarget = YES;

			if (([evt modifierFlags] & NSAlternateKeyMask) != 0)
				[self setDragAnchorToPart:kDKDrawableShapeObjectCentre];
			else if (([evt modifierFlags] & NSCommandKeyMask) != 0)
				[self setDragAnchorToPart:kDKDrawableShapeOriginTarget];
			else
				[self setDragAnchorToPart:[self partcodeOppositeKnob:partcode]];
		}
	}

	BOOL constrain = (([evt modifierFlags] & NSShiftKeyMask) != 0);
	BOOL controlKey = (([evt modifierFlags] & NSControlKeyMask) != 0);

	if (partcode == kDKDrawingEntireObjectPart) {
		if (![self locationLocked]) {
			mp.x -= [self mouseDragOffset].width;
			mp.y -= [self mouseDragOffset].height;

			mp = [self snappedMousePoint:mp
				forSnappingPointsWithControlFlag:controlKey];

			[self setLocation:mp];
			[self updateInfoForOperation:kDKShapeOperationMove
								 atPoint:omp];
		}
	} else if (partcode == kDKDrawableShapeRotationHandle) {
		m_hideOriginTarget = YES;

		mp = [self snappedMousePoint:mp
					 withControlFlag:controlKey];

		[self rotateUsingReferencePoint:mp
							  constrain:constrain];
		[self updateInfoForOperation:kDKShapeOperationRotate
							 atPoint:omp];
	} else {
		if ([self operationMode] != kDKShapeTransformStandard)
			[self moveDistortionKnob:partcode
							 toPoint:mp];
		else {
			// if partcode is for a hotspot, track the hotspot

			if (partcode >= kDKHotspotBasePartcode) {
				[[self hotspotForPartCode:partcode] continueMouseTracking:evt
																   inView:[self currentView]];
			} else {
				mp = [self snappedMousePoint:mp
							 withControlFlag:controlKey];
				[self moveKnob:partcode
						toPoint:mp
					allowRotate:[self allowSizeKnobsToRotateShape]
					  constrain:constrain];

				// update the info window with size or position according to partcode

				if (partcode == kDKDrawableShapeOriginTarget)
					[self updateInfoForOperation:kDKShapeOperationMove
										 atPoint:omp];
				else
					[self updateInfoForOperation:kDKShapeOperationResize
										 atPoint:omp];
			}
		}
	}
	[self setMouseHasMovedSinceStartOfTracking:YES];
}

/** @brief Complete a drag operation

 Cleans up after a drag operation completes
 @param mp the mouse point
 @param partcode the part that was hit
 @param evt the original event
 */
- (void)mouseUpAtPoint:(NSPoint)mp inPart:(NSInteger)partcode event:(NSEvent*)evt
{
#pragma unused(mp)

	[self setTrackingMouse:NO];
	m_hideOriginTarget = NO;

	if (m_inRotateOp) {
		[self notifyVisualChange];
		sTempRotationPt = [self knobPoint:kDKDrawableShapeRotationHandle];
		m_inRotateOp = NO;
	}

	if (partcode >= kDKHotspotBasePartcode)
		[[self hotspotForPartCode:partcode] endMouseTracking:evt
													  inView:[self currentView]];

	if ([self mouseHasMovedSinceStartOfTracking]) {
		if (partcode >= kDKDrawableShapeLeftHandle && partcode <= kDKDrawableShapeBottomRightHandle)
			[self setOffset:sTempSavedOffset];

		[[self undoManager] setActionName:[self undoActionNameForPartCode:partcode]];
		[self setMouseHasMovedSinceStartOfTracking:NO];
	}

	[[self layer] hideInfoWindow];
}

/** @brief Turn off distortion mode whenever the shape loses selection focus.
 */
- (void)objectIsNoLongerSelected
{
	[super objectIsNoLongerSelected];
	[self setOperationMode:kDKShapeTransformStandard];
}

/** @brief Return the point currently associated with the given partcode
 @param pc a partcode
 @return the point where the partcode is located
 */
- (NSPoint)pointForPartcode:(NSInteger)pc
{
	if (pc == kDKDrawingEntireObjectPart)
		return [self location];
	else if (pc == kDKDrawableShapeSnapToPathEdge)
		return [[self transformedPath] nearestPointToPoint:sMouseForPathSnap
												 tolerance:4];
	else
		return [self knobPoint:pc];
}

/** @brief Build a contextual menu pertaining to shapes
 @param theMenu add items to this menu
 @return YES if at least one item added, NO otherwise
 */
- (BOOL)populateContextualMenu:(NSMenu*)theMenu
{
	// put the conversion item into the submenu if it exists

	NSMenu* convertMenu = [[theMenu itemWithTag:kDKConvertToSubmenuTag] submenu];

	if (convertMenu == nil)
		[[theMenu addItemWithTitle:NSLocalizedString(@"Convert To Path", @"menu item for convert to path")
							action:@selector(convertToPath:)
					 keyEquivalent:@""] setTarget:self];
	else
		[[convertMenu addItemWithTitle:NSLocalizedString(@"Path", @"submenu item for convert to path")
								action:@selector(convertToPath:)
						 keyEquivalent:@""] setTarget:self];

	if ([self canPastePathWithPasteboard:[NSPasteboard generalPasteboard]])
		[[theMenu addItemWithTitle:NSLocalizedString(@"Paste Path Into Shape", @"menu item for paste path")
							action:@selector(pastePath:)
					 keyEquivalent:@""] setTarget:self];

	[theMenu addItem:[NSMenuItem separatorItem]];

	[super populateContextualMenu:theMenu];
	return YES;
}

/** @brief Return the path that will be actually drawn

 When drawing in LQ mode, the path is less smooth
 @return a path
 */
- (NSBezierPath*)renderingPath
{
	NSBezierPath* rPath = [self transformedPath];

	// if drawing is in low quality mode, set a coarse flatness value:

	if ([[self drawing] lowRenderingQuality])
		[rPath setFlatness:2.0];
	else
		[rPath setFlatness:0.5];

	return rPath;
}

/** @brief Rotates the shape to he given angle
 @param angle the desired new angle, in radians
 */
- (void)setAngle:(CGFloat)angle
{
	if (angle != m_rotationAngle) {
		NSRect oldBounds = [self bounds];

		[[[self undoManager] prepareWithInvocationTarget:self] setAngle:m_rotationAngle];

		[self notifyVisualChange];
		m_rotationAngle = angle;
		mBoundsCache = NSZeroRect;
		[self notifyVisualChange];

		[self notifyGeometryChange:oldBounds];
	}
}

/** @brief Set the shape's size to the width and height given
 @param newSize the shape's new size
 */
- (void)setSize:(NSSize)newSize
{
	if (!NSEqualSizes(newSize, m_scale)) {
		NSRect oldBounds = [self bounds];

		[[[self undoManager] prepareWithInvocationTarget:self] setSize:m_scale];

		[self notifyVisualChange];
		m_scale = newSize;
		mBoundsCache = NSZeroRect;

		// give the shape the opportunity to reshape the path to account for the new size, if necessary
		// this is implemented by subclasses. Not called if size is zero in either dimension.

		if ([self size].width != 0.0 && [self size].height != 0.0)
			[self reshapePath];

		[self notifyVisualChange];
		[self notifyGeometryChange:oldBounds];
	}
}

@synthesize size = m_scale;

- (NSAffineTransform*)transform
{
	// returns a transform which will transform a path at the origin to the correct location, scale and angle of this object.

	NSAffineTransform* xform = [NSAffineTransform transform];

	[xform translateXBy:[self location].x
					yBy:[self location].y];
	[xform rotateByRadians:[self angle]];

	CGFloat sx = [self size].width;
	CGFloat sy = [self size].height;

	[xform scaleXBy:sx
				yBy:sy];
	[xform translateXBy:-[self offset].width
					yBy:-[self offset].height];

	return xform;
}

/** @brief Return the cursor displayed when a given partcode is hit or entered

 The cursor may be displayed when the mouse hovers over or is clicked in the area indicated by the
 partcode. This should not try to anticipate the action of the mouse if there is any ambiguity-
 that's the tool's job. The tool may modify the results of this method, so you can just go ahead
 and return a cursor.
 @param partcode the partcode
 @param button YES if the mouse left button is pressed, NO otherwise
 @return a cursor object
 */
- (NSCursor*)cursorForPartcode:(NSInteger)partcode mouseButtonDown:(BOOL)button
{
#pragma unused(button)

	return [[self class] cursorForShapePartcode:partcode];
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
	NSAssert(aGroup != nil, @"expected valid group");
	NSAssert(aTransform != nil, @"expected valid transform");

	NSPoint loc = [self location];
	NSBezierPath* path = [[self transformedPath] copy];

	[path transformUsingAffineTransform:aTransform];
	loc = [aTransform transformPoint:loc];

	NSRect pathBounds = [path bounds];

	if (pathBounds.size.height > 0 && pathBounds.size.width > 0) {
		[self setLocation:loc];
		[self rotateByAngle:[aGroup angle]]; // preserves rotated bounds
		[self adoptPath:path];
	} else
		[self setSize:NSZeroSize];
}

- (void)setStyle:(DKStyle*)aStyle
{
	mBoundsCache = NSZeroRect;
	[super setStyle:aStyle];
	mBoundsCache = NSZeroRect;
	[self notifyVisualChange];
}

- (void)styleWillChange:(NSNotification*)note
{
	[super styleWillChange:note];
	mBoundsCache = NSZeroRect;
}

- (void)setContainer:(id<DKDrawableContainer>)container
{
	[super setContainer:container];
	mBoundsCache = NSZeroRect;
}

#pragma mark -

/** @brief Set the offset bewteen the shape's origin and its location point

 The offset is the distance between the origin and the rotation centre of the shape. When setting it,
 we don't want the shape to change position, so we must compensate the location for the offset.
 The offset is relative to the original unit path bounds, not to the rendered object. (In other words,
 the offset doesn't need to change with a shape's size. So to set e.g. the top, left corner as the origin
 call [shape setOrigin:NSMakeSize(-0.5,-0.5)]; )
 @param offs the desired offset width and height
 */
- (void)setOffset:(NSSize)offs
{
	if (!NSEqualSizes(offs, [self offset])) {
		[self notifyVisualChange];
		[[[self undoManager] prepareWithInvocationTarget:self] setOffset:m_offset];

		NSPoint p;

		p.x = offs.width;
		p.y = offs.height;

		p = [[self transform] transformPoint:p];

		// set location ivar directly to avoid undo

		m_location = p;
		m_offset = offs;
		mBoundsCache = NSZeroRect;
		[self notifyVisualChange];

		LogEvent_(kReactiveEvent, @"set offset = %@; location = %@", NSStringFromSize(m_offset), NSStringFromPoint(p));
	}
}

/** @brief Return the current offset

 The default offset is zero
 @return the offset bewteen the shape's position and its origin
 */
- (NSSize)offset
{
	return m_offset;
}

/** @brief Force the offset back to zero
 */
- (void)resetOffset
{
	[self setOffset:NSZeroSize];
}

/** @brief Obtain a list of snapping points

 Snapping points are locations within an object that will snap to a guide. For a shape, this is
 the handle locations arounds its boundary.
 @param offset an offset value that is added to each point
 @return a list of points (NSValues)
 */
- (NSArray*)snappingPointsWithOffset:(NSSize)offset
{
	NSMutableArray* pts = [[NSMutableArray alloc] init];
	NSPoint p;
	NSInteger j[] = { kDKDrawableShapeLeftHandle, kDKDrawableShapeTopHandle, kDKDrawableShapeRightHandle,
		kDKDrawableShapeBottomHandle, kDKDrawableShapeTopLeftHandle, kDKDrawableShapeTopRightHandle,
		kDKDrawableShapeBottomLeftHandle, kDKDrawableShapeBottomRightHandle, kDKDrawableShapeOriginTarget };
	NSInteger i;

	for (i = 0; i < 9; ++i) {
		if ((i & [[self class] knobMask]) != 0) {
			p = [self knobPoint:j[i]];
			p.x += offset.width;
			p.y += offset.height;
			[pts addObject:[NSValue valueWithPoint:p]];
		}
	}

	return pts;
}

/** @brief Return whether the object was valid following creation

 See DKDrawableObject
 @return YES if usable and valid
 */
- (BOOL)objectIsValid
{
	// shapes are invalid if their size is zero in either dimension or there is no path or the path is empty.

	BOOL valid;
	NSSize sz = [self size];

	valid = ([self path] != nil && ![[self path] isEmpty] && sz.width != 0.0 && sz.height != 0.0);

	return valid;
}

#pragma mark -
#pragma mark As an NSObject

#pragma mark -
#pragma mark As part of NSCoding Protocol
- (void)encodeWithCoder:(NSCoder*)coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	[super encodeWithCoder:coder];

	[coder encodeObject:m_path
				 forKey:@"path"];
	[coder encodeObject:[self hotspots]
				 forKey:@"hot_spots"];
	[coder encodeDouble:[self angle]
				 forKey:@"angle"];
	[coder encodePoint:[self location]
				forKey:@"location"];
	[coder encodeSize:[self size]
			   forKey:@"size"];
	[coder encodeSize:[self offset]
			   forKey:@"offset"];

	[coder encodeObject:[self distortionTransform]
				 forKey:@"dt"];
}

- (instancetype)initWithCoder:(NSCoder*)coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	//	LogEvent_(kFileEvent, @"decoding drawable shape %@", self);

	self = [super initWithCoder:coder];
	if (self != nil) {
		[self setPath:[coder decodeObjectForKey:@"path"]];
		[self setHotspots:[coder decodeObjectForKey:@"hot_spots"]];
		[self setAngle:[coder decodeDoubleForKey:@"angle"]];

		// init order is critical here: offset must be set before location as the location factors in the offset

		[self setOffset:[coder decodeSizeForKey:@"offset"]];
		[self setLocation:[coder decodePointForKey:@"location"]];

		[self setSize:[coder decodeSizeForKey:@"size"]];
		[self setDistortionTransform:[coder decodeObjectForKey:@"dt"]];
	}
	return self;
}

#pragma mark -
#pragma mark As part of NSCopying Protocol
- (id)copyWithZone:(NSZone*)zone
{
	DKDrawableShape* copy = [super copyWithZone:zone];

	[copy setPath:m_path];

	DKDistortionTransform* dfm = [[self distortionTransform] copy];
	[copy setDistortionTransform:dfm];

	[copy setAngle:[self angle]];
	[copy setSize:[self size]];
	[copy setOffset:[self offset]];
	[copy setLocation:[self location]];

	NSArray* hots = [[self hotspots] deepCopy];
	[copy setHotspots:hots];

	return copy;
}

#pragma mark -
#pragma mark As part of NSDraggingDestination protocol

- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender
{
	// this is called when the owning layer permits it, and the drag pasteboard contains a type that matches the class's
	// pasteboardTypesForOperation result. Generally at this point the object should simply handle the drop.

	// default behaviour is to derive a style from the current style.

	DKStyle* newStyle;

	// first see if we have dropped a complete style

	newStyle = [DKStyle styleFromPasteboard:[sender draggingPasteboard]];

	if (newStyle == nil) {
		// no, so perhaps we can derive a style for other data such as text, images or colours:

		newStyle = [[self style] derivedStyleWithPasteboard:[sender draggingPasteboard]
												withOptions:kDKDerivedStyleForShapeHint];
	}

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

	if (action == @selector(unrotate:))
		return ![self locked] && [self angle] != 0.0;

	if (action == @selector(setDistortMode:)) {
		[item setState:[item tag] == [self operationMode] ? NSOnState : NSOffState];
		return ![self locked];
	}

	if (action == @selector(resetBoundingBox:))
		return ![self locked] && [self angle] != 0.0;

	if (action == @selector(convertToPath:) || action == @selector(toggleHorizontalFlip:) || action == @selector(toggleVerticalFlip:))
		return ![self locked];

	if (action == @selector(pastePath:))
		return ![self locked] && [self canPastePathWithPasteboard:[NSPasteboard generalPasteboard]];

	if (action == @selector(breakApart:))
		return ![self locked] && [[self path] countSubPaths] > 1;

	return [super validateMenuItem:item];
}

@end
