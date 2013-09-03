///**********************************************************************************************************************************
///  DKDrawableShape.m
///  DrawKit
///
///  Created by graham on 13/08/2006.
///  Released under the Creative Commons license 2006 Apptree.net.
///
/// 
///  This work is licensed under the Creative Commons Attribution-ShareAlike 2.5 License.
///  To view a copy of this license, visit http://creativecommons.org/licenses/by-sa/2.5/ or send a letter to
///  Creative Commons, 543 Howard Street, 5th Floor, San Francisco, California, 94105, USA.
///
///**********************************************************************************************************************************

#import "DKDrawableShape.h"
#import "DKDrawablePath.h"
#import "DKDrawableShape+Hotspots.h"
#import "DKDrawing.h"
#import "DKStyle.h"
#import "DKStroke.h"
#import "DKDistortionTransform.h"
#import "DKKnob.h"
#import "DKObjectDrawingLayer.h"
#import "GCInfoFloater.h"
#import "DKGeometryUtilities.h"
#import "LogEvent.h"
#import "NSBezierPath+Geometry.h"
#import "NSBezierPath+Editing.h"
#import "NSDictionary+DeepCopy.h"
#import "DKGridLayer.h"

#pragma mark Static Vars

static float			sAspect = 1.0;
static float			sAngleConstraint = 0.261799387799; // pi/12 or 15 degrees
static NSPoint			sTempRotationPt;
static NSPoint			sMouseForPathSnap;
static NSColor*			sInfoWindowColour = nil;

#pragma mark -
@implementation DKDrawableShape
#pragma mark As a DKDrawableShape
///*********************************************************************************************************************
///
/// method:			knobMask
/// scope:			private class method
/// overrides:		
/// description:	return which particular knobs are used by instances of this class
/// 
/// parameters:		none
/// result:			bitmask indicating which knobs are used
///
/// notes:			the default is to use all knobs, but subclasses may want to override this for particular uses
///
///********************************************************************************************************************

+ (int)					knobMask
{
	return kGCDrawableShapeAllKnobs;
}


///*********************************************************************************************************************
///
/// method:			setAngularConstraintAngle:
/// scope:			private class method
/// overrides:		
/// description:	sets the constraint angle for rotations
/// 
/// parameters:		<radians> the constraint angle in radians
/// result:			none
///
/// notes:			when constraining a rotation (shift-drag), angles snap to multiples of this value. The default
///					is 15 degrees or pi / 12
///
///********************************************************************************************************************

+ (void)				setAngularConstraintAngle:(float) radians
{
	sAngleConstraint = radians;
}


///*********************************************************************************************************************
///
/// method:			unitRectAtOrigin
/// scope:			private class method
/// overrides:		
/// description:	return the unit rect centred at the origin
/// 
/// parameters:		none
/// result:			the unit rect, centred at the origin
///
/// notes:			this rect represents the bounds of all untransformed paths stored by a shape object
///
///********************************************************************************************************************

+ (NSRect)				unitRectAtOrigin
{
	return NSMakeRect( -0.5, -0.5, 1.0, 1.0 );
}


///*********************************************************************************************************************
///
/// method:			setInfoWindowBackgroundColour
/// scope:			public class method
/// overrides:		
/// description:	set the background colour for info windows displayed by this class when dragging, etc
/// 
/// parameters:		<colour> the colour of the window
/// result:			none
///
/// notes:			the info window itself is implemented in the owning layer, but the class can supply a custom
///					colour if you wish.
///
///********************************************************************************************************************

+ (void)				setInfoWindowBackgroundColour:(NSColor*) colour
{
	[colour retain];
	[sInfoWindowColour release];
	sInfoWindowColour = colour;
}


///*********************************************************************************************************************
///
/// method:			cursorForShapePartcode:
/// scope:			public class method
/// overrides:		
/// description:	return a cursor for the given partcode
/// 
/// parameters:		<pc> a partcode
/// result:			a cursor
///
/// notes:			shapes have a fixed set of partcodes so the cursors can be set up by the class and cached for all
///					instances. Called by the cursorForPartcode:mouseButtonDown: method
///
///********************************************************************************************************************

+ (NSCursor*)			cursorForShapePartcode:(int) pc
{
	static NSMutableDictionary*		cursorCache = nil;
	
	NSCursor*	curs = nil;
	NSString*	pairKey;
	
	if ( pc == kGCDrawingEntireObjectPart || pc == kGCDrawingNoPart )
		return [NSCursor arrowCursor];
		
	// cursors are used by opposite pairs of knobs for the sizing case, so if the partcode is part
	// of such a pair, generate the common key. The key name does not include the partcode itself
	// directly so resources are insulated from any changes made to the partcode numbering in future.
	
	if (( pc & kGCDrawableShapeNWSECorners) != 0 )
		pairKey = @"NW-SE";
	else if (( pc & kGCDrawableShapeNESWCorners) != 0 )
		pairKey = @"NE-SW";
	else if (( pc & kGCDrawableShapeEWHandles) != 0 )
		pairKey = @"E-W";
	else if (( pc & kGCDrawableShapeNSHandles) != 0 )
		pairKey = @"N-S";
	else if ( pc == kGCDrawableShapeRotationHandle )
		pairKey = @"rotation";
	else
		pairKey = @"move";
	
	// the key is used both as the resource image name and the cache key
	
	NSString*	key = [NSString stringWithFormat:@"shape_cursor_%@", pairKey];
	
	if ( cursorCache == nil )
		cursorCache = [[NSMutableDictionary alloc] init];
		
	curs = [cursorCache objectForKey:key];
	
	if( curs == nil )
	{
		// not yet cached, so create the cursor from the image resource.
		// All shape cursors are 16x16 images with the hotspot at the centre
		
		LogEvent_( kInfoEvent, @"creating shape cursor: '%@'", key);

		NSImage* cursImage = [NSImage imageNamed:key];
		
		if( cursImage != nil )
		{
			curs = [[NSCursor alloc] initWithImage:cursImage hotSpot:NSMakePoint( 8, 8 )];
			
			if ( curs != nil )
			{
				[cursorCache setObject:curs forKey:key];
				[curs release];
			}
		}
		else
		{
			// in the event of the image not being available, cache the arrow cursor
			// against this key so that it doesn't keep attempting to recreate it continually.
		
			[cursorCache setObject:[NSCursor arrowCursor] forKey:key];
		}
	}
	
	return curs;
}

#pragma mark -
#pragma mark Convenience methods

///*********************************************************************************************************************
///
/// method:			drawableShapeWithRect:
/// scope:			public class method
/// overrides:		
/// description:	create a shape object with the rect given
/// 
/// parameters:		<aRect> a rectangle
/// result:			a new shape object, autoreleased
///
/// notes:			the shape's location and size is set to the rect, angle is 0 and it has the default style.
///
///********************************************************************************************************************

+ (DKDrawableShape*)	drawableShapeWithRect:(NSRect) aRect
{
	return [[[self alloc] initWithRect:aRect] autorelease];
}


///*********************************************************************************************************************
///
/// method:			drawableShapeWithOvalInRect:
/// scope:			public class method
/// overrides:		
/// description:	create an oval shape object with the rect given
/// 
/// parameters:		<aRect> a rectangle
/// result:			a new shape object, autoreleased
///
/// notes:			the shape's location and size is set to the rect, angle is 0 and it has the default style. Its path
///					is an oval inscribed within the rect.
///
///********************************************************************************************************************

+ (DKDrawableShape*)	drawableShapeWithOvalInRect:(NSRect) aRect
{
	return [[[self alloc] initWithOvalInRect:aRect] autorelease];
}

///*********************************************************************************************************************
///
/// method:			drawableShapeWithCanonicalPath:
/// scope:			public class method
/// overrides:		
/// description:	create a shape object with the canonical path given
/// 
/// parameters:		<path> the path for the shape
/// result:			a new shape object, autoreleased
///
/// notes:			the path must be canonical, that is, having a bounds of {-0.5,-0.5},{1,1}. If it isn't, this
///					asserts. The resulting shape must be moved, sized and rotated as required before use
///
///********************************************************************************************************************

+ (DKDrawableShape*)	drawableShapeWithCanonicalPath:(NSBezierPath*) path
{
	NSAssert( NSEqualRects([path bounds], [self unitRectAtOrigin]), @"path bounds must be canonical!");
	
	DKDrawableShape* shape = [[self alloc] initWithCanonicalBezierPath:path];
	return [shape autorelease];
}


///*********************************************************************************************************************
///
/// method:			drawableShapeWithPath
/// scope:			public class method
/// overrides:		
/// description:	create a shape object with the path given
/// 
/// parameters:		<path> the path for the shape
/// result:			a new shape object, autoreleased
///
/// notes:			the path sets the size and location of the shape. Rotation angle is set to zero.
///
///********************************************************************************************************************

+ (DKDrawableShape*)	drawableShapeWithPath:(NSBezierPath*) path
{
	return [self drawableShapeWithPath:path rotatedToAngle:0.0];
}


///*********************************************************************************************************************
///
/// method:			drawableShapeWithPath:initialRotation:
/// scope:			public class method
/// overrides:		
/// description:	create a shape object with the given path and initial angle
/// 
/// parameters:		<path> the path
///					<angle> initial rotation angle
/// result:			a new shape object, autoreleased
///
/// notes:			the path sets the size and location of the shape
///
///********************************************************************************************************************

+ (DKDrawableShape*)	drawableShapeWithPath:(NSBezierPath*) path rotatedToAngle:(float) angle
{
	DKDrawableShape*	shape = [[self alloc] initWithBezierPath:path rotatedToAngle:angle];
	return [shape autorelease];
}


///*********************************************************************************************************************
///
/// method:			drawableShapeWithPath:withStyle:
/// scope:			public class method
/// overrides:		
/// description:	create a shape object with the given path and style
/// 
/// parameters:		<path> the path
///					<aStyle> the shape's style
/// result:			a new shape object, autoreleased
///
/// notes:			the path sets the size and location of the shape, the style sets its appearance
///
///********************************************************************************************************************

+ (DKDrawableShape*)	drawableShapeWithPath:(NSBezierPath*) path withStyle:(DKStyle*) aStyle
{
	return [self drawableShapeWithPath:path rotatedToAngle:0.0 withStyle:aStyle];
}


///*********************************************************************************************************************
///
/// method:			drawableShapeWithPath:initialRotation:withStyle:
/// scope:			public class method
/// overrides:		
/// description:	create a shape object with the given path and initial angle and style
/// 
/// parameters:		<path> the path
///					<angle> initial rotation angle
///					<aStyle> the shape's style
/// result:			a new shape object, autoreleased
///
/// notes:			the path sets the size and location of the shape, the style sets its appearance
///
///********************************************************************************************************************

+ (DKDrawableShape*)	drawableShapeWithPath:(NSBezierPath*) path rotatedToAngle:(float) angle withStyle:(DKStyle*) aStyle
{
	DKDrawableShape* shape = [self drawableShapeWithPath:path rotatedToAngle:angle];
	[shape setStyle:aStyle];
	
	return shape;
}



#pragma mark -
#pragma mark - initialise a shape
///*********************************************************************************************************************
///
/// method:			initWithRect:
/// scope:			public instance method
/// overrides:		
/// description:	initializes the shape to be the given rectangle
/// 
/// parameters:		<aRect> a rectangle
/// result:			the initialized object
///
/// notes:			the rect establishes the shape, size and location of the shape object
///
///********************************************************************************************************************

- (id)					initWithRect:(NSRect) aRect
{
	self = [self init];
	if (self != nil)
	{
		[[self path] appendBezierPathWithRect:[[self class] unitRectAtOrigin]];

		NSPoint cp;
		cp.x = NSMidX( aRect );
		cp.y = NSMidY( aRect );
		
		[self setSize:aRect.size];
		[self moveToPoint:cp];
	}
	return self;
}


///*********************************************************************************************************************
///
/// method:			initWithOvalInRect:
/// scope:			public instance method
/// overrides:		
/// description:	initializes the shape to be an oval inscribed within the given rect
/// 
/// parameters:		<aRect> the bounding rect for an oval
/// result:			the initialized object
///
/// notes:			the rect establishes the size and location of the shape
///
///********************************************************************************************************************

- (id)					initWithOvalInRect:(NSRect) aRect;
{
	self = [self init];
	if (self != nil)
	{
		[[self path] appendBezierPathWithOvalInRect:[[self class] unitRectAtOrigin]];
		
		NSPoint cp;
		cp.x = NSMidX( aRect );
		cp.y = NSMidY( aRect );
		
		[self setSize:aRect.size];
		[self moveToPoint:cp];
	}
	return self;
}


///*********************************************************************************************************************
///
/// method:			initWithCanonicalPath:
/// scope:			public instance method
/// overrides:		
/// description:	initializes the shape to have the given canonical path
/// 
/// parameters:		<path> the canonical path, that is, one having a bounds rect of size 1.0 centred at the origin
/// result:			the initialized object
///
/// notes:			the resulting shape must be sized, moved and rotated as required before use. If the path passed
///					is not canonical, an exception is thrown and no object is created.
///
///********************************************************************************************************************

- (id)					initWithCanonicalBezierPath:(NSBezierPath*) path
{
	NSAssert( path != nil, @"can't initialize with a nil path");
	
	// check the path is canonical:
	
	NSRect br = [path bounds];
	
	if( ! NSEqualRects( br, [[self class] unitRectAtOrigin]))
		[NSException raise:NSInternalInconsistencyException format:@"attempt to initialise shape with a non-canonical path"];
	
	self = [self init];
	if (self != nil)
	{
		[self setPath:path];
	}
	return self;
}


///*********************************************************************************************************************
///
/// method:			initWithBezierPath:
/// scope:			public instance method
/// overrides:		
/// description:	initializes the shape to have the given path
/// 
/// parameters:		<path> a path
/// result:			the initialized object
///
/// notes:			the resulting shape is located at the centre of the path and the size is set to the width and height
///					of the path's bounds. The angle is zero.
///
///********************************************************************************************************************

- (id)					initWithBezierPath:(NSBezierPath*) aPath
{
	return [self initWithBezierPath:aPath rotatedToAngle:0.0];
}


///*********************************************************************************************************************
///
/// method:			initWithBezierPath:rotatedToAngle:
/// scope:			public instance method
/// overrides:		
/// description:	initializes the shape to have the given path
/// 
/// parameters:		<aPath> a path
///					<angle> the intial rotation angle of the shape, in radians.
/// result:			the initialized object
///
/// notes:			the resulting shape is located at the centre of the path and the size is set to the width and height
///					of the path's bounds. 
///
///********************************************************************************************************************

- (id)					initWithBezierPath:(NSBezierPath*) aPath rotatedToAngle:(float) angle
{
	NSAssert( aPath != nil, @"attempt to initialise shape with a nil path");
	
	NSRect	br = [aPath bounds];
	
	if ( angle != 0.0 )
	{
		// if initially rotated, bounds must be compensated for the angle
		
		aPath = [aPath rotatedPath:-angle];
		br = [aPath bounds];
	}
	
	if ( br.size.width <= 0.0 || br.size.height <= 0.0 )
		return nil;

	self = [self initWithRect:br];
	
	if( self != nil )
	{
		NSAffineTransform*	xfm = [self inverseTransform];
		NSBezierPath* transformedPath = [xfm transformBezierPath:aPath];
		
		[self setPath:transformedPath];
		[self rotateToAngle:angle];
	}
	
	return self;
}



#pragma mark -
#pragma mark - path operations
///*********************************************************************************************************************
///
/// method:			setPath:
/// scope:			public instance method
/// overrides:		
/// description:	sets the shape's path to be the given path
/// 
/// parameters:		<path> the path, bounded by a unit rect centred at the origin
/// result:			none
///
/// notes:			path must be bounded by the unit rect, centred at the origin. If you have some other, arbitrary path,
///					the method adoptPath: will work much better.
///
///********************************************************************************************************************

- (void)				setPath:(NSBezierPath*) path
{
	[[self undoManager] registerUndoWithTarget:self selector:@selector(setPath:) object:m_path];
	
	[path retain];
	[m_path release];
	m_path = path;
	[self notifyVisualChange];
}


///*********************************************************************************************************************
///
/// method:			path
/// scope:			public instance method
/// overrides:		
/// description:	returns the shape's original path
/// 
/// parameters:		none
/// result:			the original path, transformed only by any active distortion transform, but not by the shape's
///					overall scale, position or rotation.
///
/// notes:			
///
///********************************************************************************************************************

- (NSBezierPath*)		path
{
	NSBezierPath* pth = m_path;

	if ([self distortionTransform] != nil)
		pth = [[self distortionTransform] transformBezierPath:pth];

	return pth;
}


///*********************************************************************************************************************
///
/// method:			reshapePath
/// scope:			public instance method
/// overrides:		
/// description:	fetch a new path definition following a resize of the shape
/// 
/// parameters:		none
/// result:			none
///
// Notes:
// some shapes will need to be reshaped when their size changes. An example would be a round-cornered rect where the corners
// are expected to remain at a fixed radius whatever the shape's overall size. This means that the path needs to be reshaped
// so that the final size of the shape is used to compute the path, which is then transformed back to the internally stored
// form. This method gives a shape the opportunity to do this - it is called by the setSize method. The default method does
// nothing but subclasses can override this to implement the desired reshaping.
// note that after reshaping, the object is refreshed automatically so you don't need to refresh it as part of this.
///
///********************************************************************************************************************

- (void)				reshapePath
{
}


///*********************************************************************************************************************
///
/// method:			adoptPath:
/// scope:			public instance method
/// overrides:		
/// description:	sets the shape's path given any path
/// 
/// parameters:		<path> the path to adopt
/// result:			none
///
/// notes:			this computes the original unit path by using the inverse transform, and sets that. Important:
///					the shape's overall location should be set before calling this, as it has an impact on the
///					accurate transformation of the path to the origin in the rotated case. Typically this is the
///					centre point of the path, but may not be in every case, text glyphs being a prime example.
///					The shape must have some non-zero size otherwise an exception is thrown.
///
///********************************************************************************************************************

- (void)				adoptPath:(NSBezierPath*) path
{
	// if the current size is zero, a path cannot be adopted because the transform ends up performing a divide by zero,
	// and the canonical path cannot be calculated.
	
	if([self size].width == 0.0 || [self size].height == 0.0 )
		[NSException raise:NSInternalInconsistencyException format:@"cannot adopt the path because the object has an invalid height or width - divide by zero."];
	
	[self notifyVisualChange];
	
	NSRect	br = [path bounds];
	float angl = [self angle];

	if (angl != 0.0 )
	{
		// if initially rotated, bounds must be compensated for the angle
		
		NSPoint cp = [self location];
		
		path = [path rotatedPath:-angl aboutPoint:cp];
		br = [path bounds];
		[self rotateToAngle:0];
	}

	NSPoint loc = NSMakePoint( NSMidX( br ), NSMidY( br ));

	[self setDistortionTransform:nil];
	[self setSize:br.size];
	[self setOffset:NSZeroSize];
	[self moveToPoint:loc];

	// get the shape's transform and invert it
	
	NSAffineTransform* xfm = [self inverseTransform];
	
	// transform the path back to the shape's canonical bounds and origin
	
	NSBezierPath* transformedPath = [xfm transformBezierPath:path];
	
	// now set that path as the shape's path
	
	[self setPath:transformedPath];
	[self rotateToAngle:angl];
	[self notifyVisualChange];
}


///*********************************************************************************************************************
///
/// method:			transformedPath
/// scope:			public instance method
/// overrides:		
/// description:	returns the shape's path after transforming using the shape's location, size and rotation angle
/// 
/// parameters:		none
/// result:			the path transformed to its final form
///
/// notes:			
///
///********************************************************************************************************************

- (NSBezierPath*)		transformedPath
{
	NSBezierPath* path = [self path];
	
	if ( path != nil && ![path isEmpty])
		return [[self transformIncludingParent] transformBezierPath:path];
	else
		return nil;
}


#pragma mark -
#pragma mark - geometry


///*********************************************************************************************************************
///
/// method:			transformIncludingParent
/// scope:			public instance method
/// overrides:		
/// description:	returns the transform representing the shape's parameters
/// 
/// parameters:		none
/// result:			an autoreleased affine transform, which will convert the unit path to the final form
///
/// notes:			this transform is global - i.e. it factors in the parent's transform and all parents above it
///
///********************************************************************************************************************

- (NSAffineTransform*)	transformIncludingParent
{
	NSAffineTransform* xform = [self transform];
	NSAffineTransform* parentTransform = [self containerTransform];
	
	if ( parentTransform )
		[xform appendTransform:parentTransform];

	return xform;
}


///*********************************************************************************************************************
///
/// method:			inverseTransform
/// scope:			public instance method
/// overrides:		
/// description:	returns the inverse transform representing the shape's parameters
/// 
/// parameters:		none
/// result:			an autoreleased affine transform, which will convert the final path to unit form
///
/// notes:			by using this method instead of inverting the transform yourself, you are insulated from optimisations
///					that might be employed. Note that if the shape has no size or width, this will throw an exception
///					because there is no valid inverse transform.
///
///********************************************************************************************************************

- (NSAffineTransform*)	inverseTransform
{
	NSAffineTransform* tfm = [self transform];
	[tfm invert];
	
	return tfm;
}


///*********************************************************************************************************************
///
/// method:			locationIgnoringOffset
/// scope:			instance method
/// overrides:		
/// description:	returns the location of the shape's centre in the drawing, regardless of what the current origin/offset
///					is set to. This provides a point that doesn't change when the drag anchor is set. This can be used
///					by some renderers to avoid the "shifting image" effect as a shape is resized.
/// 
/// parameters:		none
/// result:			a point
///
/// notes:			
///
///********************************************************************************************************************

- (NSPoint)				locationIgnoringOffset
{
	return [[self transform] transformPoint:NSZeroPoint];
}


#pragma mark -
///*********************************************************************************************************************
///
/// method:			rotateByAngle:
/// scope:			public instance method
/// overrides:		
/// description:	rotate the shape by adding a delta angle to the current angle
/// 
/// parameters:		<da> add this much to the current angle
/// result:			none
///
/// notes:			da is a value in radians
///
///********************************************************************************************************************

- (void)				rotateByAngle:(float) da
{
	if ( da != 0 )
	{
		[[[self undoManager] prepareWithInvocationTarget:self] rotateToAngle:m_rotationAngle ];

		[self notifyVisualChange];
		m_rotationAngle += da;
		[self notifyVisualChange];
	}
}


///*********************************************************************************************************************
///
/// method:			rotateUsingReferencePoint:constrain:
/// scope:			public instance method
/// overrides:		
/// description:	interactively rotate the shape based on dragging a point.
/// 
/// parameters:		<rp> the coordinates of a point relative to the current origin, taken to represent the rotation knob
///					<constrain> YES to constrain to multiples of the constraint angle, NO for free rotation
/// result:			none
///
/// notes:			the angle of the shape is computed from the line drawn between rp and the shape's origin, allowing for
///					the position of the rotation knob, and setting the shape's angle to it. <rp> is likely to be the mouse
///					position while dragging the rotation knob, and the functioning of this method is based on that.
///
///********************************************************************************************************************

- (void)				rotateUsingReferencePoint:(NSPoint) rp constrain:(BOOL) constrain
{
	NSPoint oo = [self knobPoint:kGCDrawableShapeOriginTarget];
	
	float rotationKnobAngle = [self knobAngleFromOrigin:kGCDrawableShapeRotationHandle];
	float angle = atan2f( rp.y - oo.y, rp.x - oo.x ) - rotationKnobAngle;
	
	float dist = hypotf( rp.x - oo.x, rp.y - oo.y );
	
	if ( constrain )
	{
		float rem = fmodf( angle, sAngleConstraint );
		
		if ( rem > sAngleConstraint / 2.0 )
			angle += ( sAngleConstraint - rem );
		else
			angle -= rem;
	}
	
	[self notifyVisualChange];
	
	float ta = angle + rotationKnobAngle;
	
	sTempRotationPt.x = oo.x + ( dist * cosf( ta ));
	sTempRotationPt.y = oo.y + ( dist * sinf( ta ));

	[self rotateToAngle:angle];
}


///*********************************************************************************************************************
///
/// method:			moveKnob:toPoint:allowRotate:constrain:
/// scope:			private instance method
/// overrides:		
/// description:	interactively change the shape's size and/or rotation angle
/// 
/// parameters:		<knobPartCode> the partcode of the knob being moved
///					<p> the point that the knob should be moved to
///					<rotate> YES to allow any knob to rotate the shape, NO if only the rotate knob has this privilege
///					<constrain> YES to constrain appropriately, NO for free movement
/// result:			none
///
/// notes:			this allows any of the main knobs (not distortion knobs) to be operated. The shape's size and/or
///					angle may be affected. If the knob is a sizing knob, a constrain of YES maintains the current aspect
///					ratio. If a rotate, the angle is constrained to that set by the angular constraint value. The shape's
///					offset also affects this - operation are performed relative to it, so it's necessary to set the offset
///					to an appropriate location prior to calling this.
///
///********************************************************************************************************************

- (void)				moveKnob:(int) knobPartCode toPoint:(NSPoint) p allowRotate:(BOOL) rotate constrain:(BOOL) constrain
{
	// if the knob isn't allowed by the class knobmask, ignore it
	
	if (([[self class] knobMask] & knobPartCode ) == 0 )
		return;
	
	if ( knobPartCode == kGCDrawableShapeOriginTarget )
	{
		NSAffineTransform* ti = [self transform];
		[ti invert];
		
		NSPoint op = [ti transformPoint:p];
		
		NSSize	offs;
		
		offs.width = op.x;
		offs.height = op.y;
		
		// limit offs to within the unit square
		
		if ( offs.width > 0.5 )
			offs.width = 0.5;
			
		if ( offs.width < -0.5 )
			offs.width = -0.5;
			
		if ( offs.height > 0.5 )
			offs.height = 0.5;
			
		if ( offs.height < -0.5 )
			offs.height = -0.5;
	
		[self setOffset:offs];
	}
	else
	{
		float		dx, dy, ka;
		
		dx = p.x - [self location].x;
		dy = p.y - [self location].y;
		ka = [self knobAngleFromOrigin:knobPartCode];
		
		// rotation
		
		if ( rotate )
			[self rotateToAngle:atan2f( dy, dx ) - ka ];
			
		// scaling
		
		// normalise the mouse point by cancelling out any overall rotation.
		
		float	pa = atan2f( dy, dx ) - [self angle];
		float	radius = hypotf( dx, dy );
		float	ndx, ndy;
		
		ndx = radius * cosf( pa );
		ndy = radius * sinf( pa );
		
		// whether we are adjusting the scale width, height or both depends on which knob we have hit
		
		NSSize		oldSize = [self size];
		float		scx, scy;
		unsigned	kbMask;
		
		// allow for offset, which is where the anchor for the resize is currently set.
		
		NSSize	offset = [self offset];
		
		kbMask = kGCDrawableShapeHorizontalSizingKnobs;
		
		if (( knobPartCode & kbMask ) != 0 )
		{
			if (( knobPartCode & kGCDrawableShapeAllLeftHandles ) != 0 )
				scx = ndx / -( offset.width + 0.5 );
			else
				scx = ndx / ( 0.5 - offset.width );
		}
		else
			scx = oldSize.width;
			
		kbMask = kGCDrawableShapeVerticalSizingKnobs;
			
		if (( knobPartCode & kbMask ) != 0 )
		{
			if (( knobPartCode & kGCDrawableShapeAllTopHandles ) != 0 )
				scy = ndy / -( offset.height + 0.5);
			else
				scy = ndy / ( 0.5 - offset.height );
		}
		else
			scy = oldSize.height;
			
		// apply constraint. Which edge dictates the size depends on which knobs we are dragging
		
		if ( constrain )
		{
			BOOL xNeg, yNeg;
			
			xNeg = scx < 0;
			yNeg = scy < 0;
			
			if (( knobPartCode & kbMask ) != 0 )
			{
				scx = scy / sAspect;
				
				if ( xNeg != yNeg )
					scx = -scx;
			}
			else
				scy = sAspect * scx;
		}
		
		// protect against possible infinities if anchor point is placed at same edge as dragging point
		
		if ( isinf( scx ) || isinf( scy ) || isnan( scx ) || isnan( scy ))
			return;
		
		[self setSize:NSMakeSize( scx, scy )];
	}
}




#pragma mark -
///*********************************************************************************************************************
///
/// method:			flipHorizontally
/// scope:			public instance method
/// overrides:		
/// description:	flip the shape horizontally
/// 
/// parameters:		none
/// result:			none
///
/// notes:			a horizontal flip is done with respect to the orthogonal drawing coordinates, based on the current
///					location of the object. In fact the width and angle are simply negated to effect this.
///
///********************************************************************************************************************

- (void)				flipHorizontally
{
	NSSize ss = [self size];
	ss.width *= -1.0;
	[self setSize:ss];
	
	float angle = [self angle];
	[self rotateToAngle:-angle];
}


///*********************************************************************************************************************
///
/// method:			flipVertically
/// scope:			public instance method
/// overrides:		
/// description:	set whether the shape is flipped vertically or not
/// 
/// parameters:		none
/// result:			none
///
/// notes:			a vertical flip is done with respect to the orthogonal drawing coordinates, based on the current
///					location of the object. In fact the height and angle are simply negated to effect this
///
///********************************************************************************************************************

- (void)				flipVertically
{
	NSSize ss = [self size];
	ss.height *= -1.0;
	[self setSize:ss];
	
	float angle = [self angle];
	[self rotateToAngle:-angle];
}


#pragma mark -
///*********************************************************************************************************************
///
/// method:			resetBoundingBox
/// scope:			public instance method
/// overrides:		
/// description:	resets the bounding box if the path's shape has changed
/// 
/// parameters:		none
/// result:			none
///
/// notes:			useful after a distortion operation, this re-adopt's the shape's own path so that the effects of
///					the distortion etc are retained while losing the transform itself. Rotation angle is unchanged.
///
///********************************************************************************************************************

- (void)				resetBoundingBox
{
	float angl = [self angle];
	
	NSBezierPath* path = [[self transformedPath] rotatedPath:-angl];
	
	[self rotateToAngle:0.0];
	[self adoptPath:path];
	[self rotateToAngle:angl];
}


///*********************************************************************************************************************
///
/// method:			resetBoundingBoxAndRotation
/// scope:			public instance method
/// overrides:		
/// description:	resets the bounding box and the rotation angle
/// 
/// parameters:		none
/// result:			none
///
/// notes:			this doesn't change the shape's appearance but readopts its current path while resetting the
///					angle to zero. After a series of complex shape transformations this can be useful to realign
///					the bounding box to something the user can deal with.
///
///********************************************************************************************************************

- (void)				resetBoundingBoxAndRotation
{
	// resets the bounding box and rotation angle. The shape's appearance and apparent position etc are not changed.
	
	NSBezierPath* path = [[self transformedPath] copy];
	
	[self rotateToAngle:0.0];
	[self adoptPath:path];
	[path release];
}


///*********************************************************************************************************************
///
/// method:			adjustToFitGrid:
/// scope:			public instance method
/// overrides:		
/// description:	adjusts location and size so that the corners lie on grid intersections if possible
/// 
/// parameters:		<grid> the grid to align to
/// result:			none
///
/// notes:			this can be used to fit the object to a grid. The object's angle is not changed but its size and
///					position may be. The bounding box will change but is not reset. It works by moving specific control
///					points to the corners of the passed rect. Note that for rotated shapes, it's not possible to
///					force the corners to lie at specific points and maintain the rectangular bounds, so the result
///					may not be what you want.
///
///********************************************************************************************************************

- (void)				adjustToFitGrid:(DKGridLayer*) grid
{
	int			k, knob[4] = { kGCDrawableShapeTopLeftHandle, kGCDrawableShapeTopRightHandle, kGCDrawableShapeBottomLeftHandle, kGCDrawableShapeBottomRightHandle };

	for( k = 3; k >= 0; --k )
	{
		NSPoint corner = [grid nearestGridIntersectionToPoint:[self knobPoint:knob[k]]];
		
		[self setDragAnchorToPart:[self partcodeOppositeKnob:knob[k]]];
		[self moveKnob:knob[k] toPoint:corner allowRotate:NO constrain:NO];
		[self setOffset:m_savedOffset];
	}
}


#pragma mark -
///*********************************************************************************************************************
///
/// method:			allowSizeKnobsToRotateShape
/// scope:			public instance method
/// overrides:		
/// description:	sets whether a shape can be rotated by any knob, not just the designated rotation knob
/// 
/// parameters:		none
/// result:			YES to allow rotation by other knobs, NO to disallow
///
/// notes:			the default is NO, subclasses may have other ideas. Note that there are usability implications
///					when returning YES, though the behaviour can definitely be quite useful.
///
///********************************************************************************************************************

- (BOOL)				allowSizeKnobsToRotateShape
{
	return NO;
}


///*********************************************************************************************************************
///
/// method:			knobRect:
/// scope:			private instance method
/// overrides:		
/// description:	given a partcode for one of the control knobs, this returns a rect surrounding its current position
/// 
/// parameters:		<knobPartCode> the partcode for the knob, which is private to the shape class
/// result:			a rect, centred on the knob's current point
///
/// notes:			The DKKnob class is used to compute the actual rect size, and it should also be called to perform
///					the final hit-testing because it takes into account the actual path shape of the knob.
///
///********************************************************************************************************************

- (NSRect)				knobRect:(int) knobPartCode
{
	DKKnobType	knobType = [self knobTypeForPartCode:knobPartCode];
	NSPoint		p = [self knobPoint:knobPartCode];
	
	NSRect kr;
	
	if ([self layer] != nil )
		kr = [[[self layer] knobs] controlKnobRectAtPoint:p ofType:knobType];
	else
	{
		// if no owner, still pass back a valid rect - this is to ensure that the bounds can be determined correctly even
		// when no owner is set.
		
		kr = NSMakeRect( p.x, p.y, 0, 0 );
		kr = NSInsetRect( kr, -3, -3 );
	}
	
	return kr;
}


///*********************************************************************************************************************
///
/// method:			convertPointFromRelativeLocation:
/// scope:			public instance method
/// overrides:		
/// description:	given a point in canonical coordinates (i.e. in the space {0.5,0.5,1,1}) this returns the real
///					location of the point in the drawing, so applies the transforms to it, etc.
/// 
/// parameters:		<rloc> a point expressed in terms of the canonical rect
/// result:			the same point transformed to the actual drawing
///
/// notes:			this works when a distortion is being applied too, and when the shape is part of a group.
///
///********************************************************************************************************************

- (NSPoint)				convertPointFromRelativeLocation:(NSPoint) rloc
{
	if ([self distortionTransform] != nil)
		rloc = [[self distortionTransform] transformPoint:rloc fromRect:[[self class] unitRectAtOrigin]];

	NSAffineTransform*  tx = [self transformIncludingParent];
	return [tx transformPoint:rloc];
}


#pragma mark -
#pragma mark - private
///*********************************************************************************************************************
///
/// method:			knobBounds
/// scope:			private instance method
/// overrides:		
/// description:	return the rectangle that bounds the current control knobs
/// 
/// parameters:		none
/// result:			a rect, the union of all active knob rectangles
///
/// notes:			
///
///********************************************************************************************************************

- (NSRect)				knobBounds
{
	NSRect  br = NSZeroRect;
	
	br = NSUnionRect( br, [self knobRect:kGCDrawableShapeTopLeftHandle]);
	br = NSUnionRect( br, [self knobRect:kGCDrawableShapeTopRightHandle]);
	br = NSUnionRect( br, [self knobRect:kGCDrawableShapeBottomLeftHandle]);
	br = NSUnionRect( br, [self knobRect:kGCDrawableShapeBottomRightHandle]);
	br = NSUnionRect( br, [self knobRect:kGCDrawableShapeOriginTarget]);
	
	if ( m_inRotateOp )
	{
		NSRect rk = [DKKnob controlKnobRectAtPoint:sTempRotationPt];
		br = NSUnionRect( br, rk );
	}
	
	// outset a little to allow the framing of the knobs not to be clipped
	
	return NSInsetRect( br, -0.5, -0.5 );
}


///*********************************************************************************************************************
///
/// method:			partcodeOppositeKnob:
/// scope:			private instance method
/// overrides:		
/// description:	returns the partcode of the knob that is "opposite" the one passed
/// 
/// parameters:		<knobPartCode> a knob part code
/// result:			another knob part code
///
/// notes:			used to set up the origin prior to a drag/move of a control knob
///
///********************************************************************************************************************

- (int)					partcodeOppositeKnob:(int) knobPartCode
{
	static int pc[] = { kGCDrawableShapeRightHandle, kGCDrawableShapeBottomHandle, kGCDrawableShapeLeftHandle, kGCDrawableShapeTopHandle,
						kGCDrawableShapeBottomRightHandle, kGCDrawableShapeBottomLeftHandle,
						kGCDrawableShapeTopRightHandle, kGCDrawableShapeTopLeftHandle };
	
	if ( knobPartCode > kGCDrawableShapeBottomRightHandle )
		return knobPartCode;
	else
	{
		int indx = 0;
		unsigned mask = 1;
		
		while((mask & knobPartCode) == 0 && indx < 8)
		{
			++indx;
			mask <<= 1;
		}
		
		return pc[indx];
	}
}


///*********************************************************************************************************************
///
/// method:			setDragAnchorToPart:
/// scope:			private instance method
/// overrides:		
/// description:	sets the shape's offset to the location of the given knob partcode, after saving the current offset
/// 
/// parameters:		<part> a knob partcode
/// result:			none
///
/// notes:			part of the process of setting up the interactive dragging of a sizing knob
///
///********************************************************************************************************************

- (void)				setDragAnchorToPart:(int) part
{
	// saves the offset, then sets the current offset to the location of the given part. This sets the drag origin to the given point.
	// usually this will be the knob opposite the one being dragged.
	
	m_savedOffset = m_offset;
	
	NSPoint p = [self canonicalCornerPoint:part];
	
	NSSize	offs;
	
	offs.width = p.x;
	offs.height = p.y;
	
	[self setOffset:offs];
}


///*********************************************************************************************************************
///
/// method:			knobAngleFromOrigin:
/// scope:			private instance method
/// overrides:		
/// description:	returns the angle of a given knob relative to the shape's offset
/// 
/// parameters:		<knobPartCode> a knob part code
/// result:			the knob's angle relative to the origin
///
/// notes:			part of the process of setting up an interactive drag of a knob
///
///********************************************************************************************************************

- (float)				knobAngleFromOrigin:(int) knobPartCode
{
	NSPoint		p;
	float		dy, dx;
	
	if ( knobPartCode == kGCDrawableShapeRotationHandle )
		p = [self rotationKnobPoint];
	else
		p = [self knobPoint:knobPartCode];
	
	dy = p.y - [self location].y;
	dx = p.x - [self location].x;
	
	return atan2f( dy, dx ) - [self angle];
}


///*********************************************************************************************************************
///
/// method:			drawKnob:
/// scope:			private instance method
/// overrides:		
/// description:	draws a single knob, given its partcode
/// 
/// parameters:		<knobPartCode> the partcode for the knob, which is private to the shape class
/// result:			none
///
/// notes:			only knobs allowed by the class mask are drawn. The knob is drawn by the DKKnob class attached to
///					the drawing.
///
///********************************************************************************************************************

- (void)				drawKnob:(int) knobPartCode
{
	NSDictionary* knobUserInfo = nil;
	
	// if knob disallowed by mask, ignore it
	
	if (([[self class] knobMask] & knobPartCode ) == knobPartCode )
	{
		NSPoint kp = [self knobPoint:knobPartCode];
		DKKnob* knobs = [[self layer] knobs];
		DKKnobType knobType = [self knobTypeForPartCode:knobPartCode];
		
		if( knobType == kDKBoundingRectKnobType )
			knobUserInfo = [NSDictionary dictionaryWithObject:[[self layer] selectionColour] forKey:kDKKnobPreferredHighlightColour];
		
		[knobs drawKnobAtPoint:kp ofType:knobType angle:[self angle] userInfo:knobUserInfo];
			
#ifdef qIncludeGraphicDebugging
		if ( m_showPartcodes )
		{
			kp.x += 2;
			kp.y += 2;
			[knobs drawPartcode:knobPartCode atPoint:kp fontSize:10];
		}
		
		if( m_showTargets )
		{
			NSRect kr = [self knobRect:knobPartCode];
			
			[[NSColor magentaColor] set];
			NSFrameRectWithWidth( kr, 0.0 );
		}
#endif
	}
}


///*********************************************************************************************************************
///
/// method:			canonicalCornerPoint:
/// scope:			private instance method
/// overrides:		
/// description:	given the partcode of a knob, this returns its corner of the canonical unit rect
/// 
/// parameters:		<knobPartCode> the partcode for the knob, which is private to the shape class
/// result:			the associated knob's corner on the unit rect
///
/// notes:			the result needs to be transformed to the final position
///
///********************************************************************************************************************

- (NSPoint)			canonicalCornerPoint:(int) knobPartCode
{
	NSRect		r = [[self class] unitRectAtOrigin];
	NSPoint		kp;

	switch( knobPartCode )
	{
		default:
			return NSZeroPoint;
			
		case kGCDrawableShapeTopLeftHandle:
			kp.x = NSMinX( r );
			kp.y = NSMinY( r );
			break;
			
		case kGCDrawableShapeTopHandle:
			kp.x = NSMidX( r );
			kp.y = NSMinY( r );
			break;
			
		case kGCDrawableShapeTopRightHandle:
			kp.x = NSMaxX( r );
			kp.y = NSMinY( r );
			break;
			
		case kGCDrawableShapeRightHandle:
			kp.x = NSMaxX( r );
			kp.y = NSMidY( r );
			break;
			
		case kGCDrawableShapeBottomRightHandle:
			kp.x = NSMaxX( r );
			kp.y = NSMaxY( r );
			break;
			
		case kGCDrawableShapeBottomHandle:
			kp.x = NSMidX( r );
			kp.y = NSMaxY( r );
			break;
			
		case kGCDrawableShapeBottomLeftHandle:
			kp.x = NSMinX( r );
			kp.y = NSMaxY( r );
			break;
			
		case kGCDrawableShapeLeftHandle:
			kp.x = NSMinX( r );
			kp.y = NSMidY( r );
			break;
			
		case kGCDrawableShapeObjectCentre:
			kp.x = NSMidX( r );
			kp.y = NSMidY( r );
			break;
			
		case kGCDrawableShapeOriginTarget:
			kp.x = [self offset].width;
			kp.y = [self offset].height;
			break;
			
		case kGCDrawableShapeRotationHandle:
			kp.y = NSMidY( r );
			kp.x = ( NSMaxX( r ) + NSMidX( r )) * 0.75;
			break;
	}
	
	return kp;
}


///*********************************************************************************************************************
///
/// method:			knobPoint:
/// scope:			private instance method
/// overrides:		
/// description:	given the partcode of a knob, this returns its current position
/// 
/// parameters:		<knobPartCode> the partcode for the knob, which is private to the shape class
/// result:			the associated knob's current position
///
/// notes:			this is the transformed point at its true final position
///
///********************************************************************************************************************

- (NSPoint)			knobPoint:(int) knobPartCode
{
	NSPoint		kp;
	NSRect		r = [[self class] unitRectAtOrigin];
	NSPoint		qp[4];

	switch( knobPartCode )
	{
		default:
			kp = [self canonicalCornerPoint:knobPartCode];
			break;
			
		case kGCDrawableShapeTopLeftDistort:
			[[self distortionTransform] getEnvelopePoints:qp];
			kp = qp[0];
			break;
			
		case kGCDrawableShapeTopRightDistort:
			[[self distortionTransform] getEnvelopePoints:qp];
			kp = qp[1];
			break;

		case kGCDrawableShapeBottomRightDistort:
			[[self distortionTransform] getEnvelopePoints:qp];
			kp = qp[2];
			break;

		case kGCDrawableShapeBottomLeftDistort:
			[[self distortionTransform] getEnvelopePoints:qp];
			kp = qp[3];
			break;
	}
	
	// if it's not a distortion handle, apply the distortion transform

	if ( knobPartCode < kGCDrawableShapeTopLeftDistort && [self distortionTransform] != nil )
		kp = [[self distortionTransform] transformPoint:kp fromRect:r];

	NSAffineTransform*  tx = [self transformIncludingParent];
	return [tx transformPoint:kp];
}


///*********************************************************************************************************************
///
/// method:			knobTypeForPartCode:
/// scope:			private instance method
/// overrides:		DKDrawableObject
/// description:	given a partcode, this returns the knob type for it
/// 
/// parameters:		<pc> a knob part code
/// result:			a knob type, as defined by DKKnob (see DKCommonTypes.h)
///
/// notes:			the knob type is used to tell DKKnob the function of a knob in broad terms, which in turn it
///					maps to a specific kind of knob appearance. For convenience the locked flag is also passed as
///					part of the knob type.
///
///********************************************************************************************************************

- (DKKnobType)		knobTypeForPartCode:(int) pc
{
	DKKnobType knobType;

	if ( pc == kGCDrawableShapeRotationHandle )
		knobType = kDKRotationKnobType;
	else if ( pc == kGCDrawableShapeOriginTarget )
		knobType = kDKCentreTargetKnobType;
	else
		knobType = kDKBoundingRectKnobType;

	if ([self locked])
		knobType |= kDKKnobIsDisabledFlag;
		
	return knobType;
}

#pragma mark -
///*********************************************************************************************************************
///
/// method:			undoActionNameForPartCode:
/// scope:			private instance method
/// overrides:		
/// description:	given a partcode, this returns the undo action name which is the name of the action that manipulating
///					that knob will cause.
/// 
/// parameters:		<pc> a knob part code
/// result:			a localized string, the undo action name
///
/// notes:			if your subclass uses hotspots for additional knobs, you need to override this and supply the
///					appropriate string for the hotspot's action, calling super for the standard knobs.
///
///********************************************************************************************************************

- (NSString*)			undoActionNameForPartCode:(int) pc
{
	NSString* s = nil;
	
	switch( pc )
	{
		case kGCDrawingNoPart:
			s = @"????";	// this shouldn't happen
			break;
			
		case kGCDrawingEntireObjectPart:
			s = NSLocalizedString( @"Move", @"undo string for move object");
			break;
			
		case kGCDrawableShapeRotationHandle:
			s = NSLocalizedString( @"Rotate", @"undo string for rotate object");
			break;
			
		case kGCDrawableShapeOriginTarget:
			s = NSLocalizedString( @"Move Origin", @"undo string for object offset");
			break;
			
		case kGCDrawableShapeTopLeftDistort:
		case kGCDrawableShapeTopRightDistort:
		case kGCDrawableShapeBottomRightDistort:
		case kGCDrawableShapeBottomLeftDistort:
		{
			switch([self operationMode])
			{
				default:
					s = NSLocalizedString( @"Distortion Transform", @"undo string for object distortion");
					break;
					
				case kGCShapeTransformHorizontalShear:
					s = NSLocalizedString( @"Horizontal Shear", @"undo string for h shear");
					break;
					
				case kGCShapeTransformVerticalShear:
					s = NSLocalizedString( @"Vertical Shear", @"undo string for v shear");
					break;
					
				case kGCShapeTransformPerspective:
					s = NSLocalizedString( @"Perspective Transform", @"undo string for perspective");
					break;
			}
		}
		break;
		
		default:
			s = NSLocalizedString( @"Resize", @"undo string for resize object");
			break;
	}
	
	return s;

}








///*********************************************************************************************************************
///
/// method:			moveDistortionKnob:toPoint:
/// scope:			private instance method
/// overrides:		
/// description:	allows the distortion transform to be adjusted interactively
/// 
/// parameters:		<partcode> a knob partcode for the distortion envelope private to the class
///					<p> the point where the knob should be moved to.
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				moveDistortionKnob:(int) partCode toPoint:(NSPoint) p
{
	int	qi = 0;
	
	switch( partCode )
	{
		case kGCDrawableShapeTopLeftDistort:
			qi = 0;
			break;
			
		case kGCDrawableShapeTopRightDistort:
			qi = 1;
			break;
		
		case kGCDrawableShapeBottomRightDistort:
			qi = 2;
			break;
			
		case kGCDrawableShapeBottomLeftDistort:
			qi = 3;
			break;
			
		default:
			return;	// ignore all others
	}
	
//	LogEvent_(kStateEvent, @"adjusting transform part %d", qi );
	
	NSPoint old = [self knobPoint:partCode];
	
	[[[self undoManager] prepareWithInvocationTarget:self] moveDistortionKnob:partCode toPoint:old];
	
	[self notifyVisualChange];

	NSAffineTransform*		tfm = [self transform];
	[tfm invert];
	
	p = [tfm transformPoint:p];
	
	DKDistortionTransform*	t = [self distortionTransform];
	NSPoint					q[4];
	[t getEnvelopePoints:q];
	
	switch([self operationMode])
	{
		default:
		case kGCShapeTransformFreeDistort:
			q[qi] = p;
			[t setEnvelopePoints:q];
			break;
			
		case kGCShapeTransformHorizontalShear:
			if ( qi == 2 || qi == 3 )
				[t shearHorizontallyBy: -(p.x - q[qi].x)];
			else
				[t shearHorizontallyBy: p.x - q[qi].x];
			break;
			
		case kGCShapeTransformVerticalShear:
			if ( qi == 0 || qi == 3 )
				[t shearVerticallyBy:- (p.y - q[qi].y)];
			else
				[t shearVerticallyBy:p.y - q[qi].y];
			break;
			
		case kGCShapeTransformPerspective:
			if ( qi == 1 || qi == 3 )
				[t differentialPerspectiveBy:-(p.y - q[qi].y)];
			else
				[t differentialPerspectiveBy:p.y - q[qi].y];
			break;
	}
	
	[self notifyVisualChange];
}


///*********************************************************************************************************************
///
/// method:			drawDistortionEnvelope
/// scope:			private instance method
/// overrides:		
/// description:	in distortion mode, draws the envelope and knobs of the current distortion transform around the shape
/// 
/// parameters:		none
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				drawDistortionEnvelope
{
	NSPoint					q[4];
	NSBezierPath*			ep;
	
	ep = [NSBezierPath bezierPath];
	
	q[0] = [self knobPoint:kGCDrawableShapeTopLeftDistort];
	q[1] = [self knobPoint:kGCDrawableShapeTopRightDistort];
	q[2] = [self knobPoint:kGCDrawableShapeBottomRightDistort];
	q[3] = [self knobPoint:kGCDrawableShapeBottomLeftDistort];
	
	[ep moveToPoint:q[0]];
	[ep lineToPoint:q[1]];
	[ep lineToPoint:q[2]];
	[ep lineToPoint:q[3]];
	[ep closePath];
	
	[[NSColor purpleColor] setStroke];
	[ep setLineWidth:1.0];
	[ep stroke];
	
	[self drawKnob:kGCDrawableShapeTopLeftDistort];
	[self drawKnob:kGCDrawableShapeTopRightDistort];
	[self drawKnob:kGCDrawableShapeBottomRightDistort];
	[self drawKnob:kGCDrawableShapeBottomLeftDistort];
	
	[self drawKnob:kGCDrawableShapeOriginTarget];
}


#pragma mark -
///*********************************************************************************************************************
///
/// method:			prepareRotation
/// scope:			private instance method
/// overrides:		
/// description:	prepares for a rotation operation by setting up the info window and rotation state info
/// 
/// parameters:		none
/// result:			none
///
/// notes:			called internally from a mouse down event
///
///********************************************************************************************************************

- (void)				prepareRotation
{
	NSPoint rkp = [self rotationKnobPoint];
	
	[self updateInfoForOperation:kDKShapeOperationRotate atPoint:rkp];
	m_inRotateOp = YES;
	sTempRotationPt = rkp;
	
	[self notifyVisualChange];
}


///*********************************************************************************************************************
///
/// method:			rotationKnobPoint
/// scope:			private instance method
/// overrides:		
/// description:	gets the location of the rotation knob
/// 
/// parameters:		none
/// result:			a point, the position of the rotation knob
///
/// notes:			factored separately to allow override for special uses
///
///********************************************************************************************************************

- (NSPoint)				rotationKnobPoint
{
	return [self knobPoint:kGCDrawableShapeRotationHandle];
}


///*********************************************************************************************************************
///
/// method:			updateInfoForOperation:
/// scope:			private instance method
/// overrides:		
/// description:	display the appropriate information in the info window when dragging during various operations
/// 
/// parameters:		<op> what info to display
///					<mp> where the mouse is currently
/// result:			none
///
/// notes:			the window is owned by the layer, this supplies its content. If turned off this is a no-op
///
///********************************************************************************************************************

- (void)				updateInfoForOperation:(DKShapeEditOperation) op atPoint:(NSPoint) mp
{
	if([[self class] displaysSizeInfoWhenDragging])
	{
		NSString*	infoStr;
		NSString*	abbrUnits = [[self drawing] abbreviatedDrawingUnits];
		NSPoint		gridPt;
		float		width, height;
		
		switch( op )
		{
			default:
			case kDKShapeOperationResize:
				width = [self convertLength:[self size].width];
				height = [self convertLength:[self size].height];
				infoStr = [NSString stringWithFormat:@"w: %.2f%@\nh: %.2f%@", width, abbrUnits, height, abbrUnits];
				break;
				
			case kDKShapeOperationMove:
				gridPt = [self convertPointToDrawing:[self location]];
				infoStr = [NSString stringWithFormat:@"x: %.2f%@\ny: %.2f%@", gridPt.x, abbrUnits, gridPt.y, abbrUnits];
				break;
				
			case kDKShapeOperationRotate:
				infoStr = [NSString stringWithFormat:@"%.1f%C", [self angleInDegrees], 0xB0];	// UTF-8 for degree symbol is 0xB0
				break;
		}
		
		if( sInfoWindowColour != nil )	
			[[self layer] setInfoWindowBackgroundColour:sInfoWindowColour];
		
		[[self layer] showInfoWindowWithString:infoStr atPoint:mp];
	}
}


#pragma mark -
#pragma mark - operation modes
///*********************************************************************************************************************
///
/// method:			setOperationMode:
/// scope:			public instance method
/// overrides:		
/// description:	sets what kind of operation is performed by dragging the shape's control knobs
/// 
/// parameters:		<mode>
/// result:			none
///
/// notes:			switches between normal location, scaling and rotation operations, and those involving the
///					distortion transform (shearing, free distort, perpective).
///
///********************************************************************************************************************

- (void)				setOperationMode:(int) mode
{
	if ( mode != m_opMode )
	{
		[[[self undoManager] prepareWithInvocationTarget:self] setOperationMode:m_opMode];
		
		m_opMode = mode;
		
		if ( mode != kGCShapeTransformStandard && ([self distortionTransform] == nil ))
		{
			[self setDistortionTransform:[DKDistortionTransform transformWithInitialRect:[[self class] unitRectAtOrigin]]];
			[self notifyVisualChange];
		}
		
		if ( mode == kGCShapeTransformStandard )
		{
			//[self setDistortionTransform:nil];
			[self resetBoundingBox];
		}
	}
}


///*********************************************************************************************************************
///
/// method:			operationMode
/// scope:			public instance method
/// overrides:		
/// description:	returns the current operation mode
/// 
/// parameters:		none
/// result:			ops mode
///
/// notes:			
///
///********************************************************************************************************************

- (int)					operationMode
{
	return m_opMode;
}


#pragma mark -
#pragma mark - distortion ops
///*********************************************************************************************************************
///
/// method:			setDistortionTransform:
/// scope:			public instance method
/// overrides:		
/// description:	sets the current distortion transform to the one passed.
/// 
/// parameters:		<dt> a distortion transform
/// result:			none
///
/// notes:			this can be used in two ways. Either pre-prepare a transform and set it, which will immediately have
///					its effect on the shape. This is the hard way. The easy way is to set the distort mode which creates
///					a transform as needed and allows it to be changed interactively.
///
///********************************************************************************************************************

- (void)				setDistortionTransform:(DKDistortionTransform*) dt
{
	if ( dt != m_distortTransform )
	{
		[dt retain];
		[m_distortTransform release];
		m_distortTransform = dt;
		
		[self notifyVisualChange];
		
		if ( m_distortTransform == nil )
			[self setOperationMode:kGCShapeTransformStandard];
	}
}


///*********************************************************************************************************************
///
/// method:			distortionTransform
/// scope:			public instance method
/// overrides:		
/// description:	return the current distortion transform
/// 
/// parameters:		none
/// result:			the distortion transform if there is one, or nil otherwise
///
/// notes:			
///
///********************************************************************************************************************

- (DKDistortionTransform*) distortionTransform;
{
	return m_distortTransform;
}


#pragma mark -
#pragma mark - convert to editable path
///*********************************************************************************************************************
///
/// method:			makePath
/// scope:			public instance method
/// overrides:		
/// description:	return a path object having the same path and style as this object
/// 
/// parameters:		none
/// result:			a DKDrawablePath object with the same path and style as this
///
/// notes:			part of the process of converting from shape to path. Both the path and the style are copied.
///
///********************************************************************************************************************

- (DKDrawablePath*)		makePath
{
	NSBezierPath* path = [[self transformedPath] copy];
	DKDrawablePath* dp = [DKDrawablePath drawablePathWithPath:path];
	
	[dp setStyle:[self style]];
	[dp setUserInfo:[self userInfo]];

	[path release];

	return dp;
}


#pragma mark -
#pragma mark - user actions
///*********************************************************************************************************************
///
/// method:			convertToPath:
/// scope:			public action method
/// overrides:		
/// description:	replace this object in the owning layer with a path object built from it
/// 
/// parameters:		<sender> the action's sender
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (IBAction)			convertToPath:(id) sender
{
	#pragma unused(sender)
	
	// converts the shape to a path object and replaces itself in the owning layer with the new shape.
	
	DKObjectDrawingLayer*	layer = (DKObjectDrawingLayer*)[self layer];
	int						myIndex = [layer indexOfObject:self];
	
	DKDrawablePath*			po = [self makePath];
	
	[layer recordSelectionForUndo];
	[layer addObject:po atIndex:myIndex];
	[layer replaceSelectionWithObject:po];
	[self retain];
	[layer removeObject:self];
	[layer commitSelectionUndoWithActionName:NSLocalizedString(@"Convert To Path", @"undo string for convert to path")];
	[self release];
}


///*********************************************************************************************************************
///
/// method:			unrotate:
/// scope:			public action method
/// overrides:		
/// description:	set the rotation angle to zero
/// 
/// parameters:		<sender> the action's sender
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (IBAction)			unrotate:(id) sender
{
	#pragma unused(sender)
	
	[self rotateToAngle:0.0];
	[[self undoManager] setActionName:NSLocalizedString(@"Unrotate", @"undo string for shape unrotate")];
}


///*********************************************************************************************************************
///
/// method:			rotate:
/// scope:			public action method
/// overrides:		
/// description:	set the object's rotation angle from the sender's float value
/// 
/// parameters:		<sender> the action's sender
/// result:			none
///
/// notes:			intended to be hooked up to a control rather than a menu
///
///********************************************************************************************************************

- (IBAction)			rotate:(id) sender
{
	// sets the current rotation angle to the sender's floatValue in degrees.
	
	float angle = ([sender floatValue] * pi)/ 180.0f;
	
	[self rotateToAngle:angle];
	[[self undoManager] setActionName:NSLocalizedString(@"Rotation", @"undo string for shape rotate")];
}


///*********************************************************************************************************************
///
/// method:			setDistortMode:
/// scope:			public action method
/// overrides:		
/// description:	sets the operation mode of the shape based on the sender's tag
/// 
/// parameters:		<sender> the action's sender
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (IBAction)			setDistortMode:(id) sender;
{
	int m = [sender tag];
	[self setOperationMode:m];
	[self notifyVisualChange];
	[[self undoManager] setActionName:NSLocalizedString(@"Change Transform Mode", @"undo string for change transform mode")];
}


///*********************************************************************************************************************
///
/// method:			resetBoundingBox:
/// scope:			public action method
/// overrides:		
/// description:	resets the shape's bounding box
/// 
/// parameters:		<sender> the action's sender
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (IBAction)			resetBoundingBox:(id) sender
{
	#pragma unused(sender)
	
	[self resetBoundingBoxAndRotation];
	[[self undoManager] setActionName:NSLocalizedString(@"Reset Bounding Box", @"undo string for reset bbox")];
}


- (IBAction)			toggleHorizontalFlip:(id) sender
{
	#pragma unused(sender)
	
	[self flipHorizontally];
	[[self undoManager] setActionName:NSLocalizedString(@"Flip Horizontally", @"h flip")];
}


- (IBAction)			toggleVerticalFlip:(id) sender
{
	#pragma unused(sender)
	
	[self flipVertically];
	[[self undoManager] setActionName:NSLocalizedString(@"Flip Vertically", @"v flip")];
}


- (IBAction)			pastePath:(id) sender
{
	#pragma unused(sender)
	
	// if there is a native shape or path on the pb, use its path for this shape. This conveniently allows you to draw a fancy
	// path and apply it to an existing shape - especially useful for image and text shapes.
	
	NSPasteboard* pb = [NSPasteboard generalPasteboard];
	NSArray* objects = [[self layer] nativeObjectsFromPasteboard:pb];
	
	// this only works if there is just one object on the pb - otherwise it's ambiguous which path to use
	
	if( objects != nil && [objects count] == 1 )
	{
		DKDrawableObject* od = [objects lastObject];
		
		NSBezierPath* path = [od renderingPath];
		NSRect br = [path bounds];
		
		if ( path != nil && ![path isEmpty] && br.size.width > 0.0 && br.size.height > 0.0 )
		{
			// set this path, but we don't want to use adoptPath: here because it changes our location, etc. Instead
			// we need to transform the path back to its canonical form and set it directly.

			NSAffineTransform* tfm;
			
			if([od isKindOfClass:[DKDrawablePath class]])
			{
				// for paths coming from path objects, just translate and scale them directly back
				// to the unit rect at the origin.
				
				float x, y;
				
				x = NSMidX( br );
				y = NSMidY( br );
				
				tfm = [NSAffineTransform transform];
				
				[tfm scaleXBy:1.0 / NSWidth( br) yBy:1.0 / NSHeight( br )];
				[tfm translateXBy:-x yBy:-y];
			}
			else
			{
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


- (BOOL)				canPastePathWithPasteboard:(NSPasteboard*) pb
{
	NSArray* objects = [[self layer] nativeObjectsFromPasteboard:pb];
	return (objects != nil && [objects count] == 1);
}



#pragma mark -
#pragma mark As a DKDrawableObject

///*********************************************************************************************************************
///
/// method:			initialPartcodeForObjectCreation
/// scope:			public class method
/// overrides:		DKDrawableObject
/// description:	return the partcode that should be used by tools when initially creating a new object
/// 
/// parameters:		none
/// result:			a partcode value - for shapes this is typically the bottom/right knob, or if that has been disabled
///					by the knobMask, the first knob found in reverse order.
///
/// notes:			The client of this method is DKObjectCreationTool.
///
///********************************************************************************************************************

+ (int)				initialPartcodeForObjectCreation
{
	if(([self knobMask] & kGCDrawableShapeBottomRightHandle) == kGCDrawableShapeBottomRightHandle )
		return kGCDrawableShapeBottomRightHandle;
	else
	{
		// bottom/right not available, so return one that is
		
		int i;
		
		for( i = kGCDrawableShapeBottomLeftHandle; i >= kGCDrawableShapeLeftHandle; --i )
		{
			if(([self knobMask] & i) == i )
				return i;
		}
	
		return kGCDrawingNoPart;
	}
}


///*********************************************************************************************************************
///
/// method:			pasteboardTypesForOperation:
/// scope:			public class method
/// overrides:		DKDrawableObject
/// description:	return the pasteboard types that instances of this class are able to receive
/// 
/// parameters:		<op> an operation contsnat (ignored)
/// result:			a list of pasteboard types that can be dropped or pasted on objects of this type
///
/// notes:			
///
///********************************************************************************************************************

+ (NSArray*)			pasteboardTypesForOperation:(DKPasteboardOperationType) op
{
	#pragma unused(op)
	return [NSArray arrayWithObjects:NSColorPboardType, NSPDFPboardType, NSTIFFPboardType, NSFilenamesPboardType, NSStringPboardType, nil];
}


///*********************************************************************************************************************
///
/// method:			angle
/// scope:			public instance method
/// overrides:		
/// description:	return the shape's current rotation angle
/// 
/// parameters:		none
/// result:			the shape's angle in radians
///
/// notes:			
///
///********************************************************************************************************************

- (float)				angle
{
	return m_rotationAngle;
}


///*********************************************************************************************************************
///
/// method:			apparentBounds
/// scope:			public instance method
/// overrides:		DKDrawableObject
/// description:	return the visual bounds of the object
/// 
/// parameters:		none
/// result:			a rect, the apparent bounds of the shape
///
/// notes:			
///
///********************************************************************************************************************

- (NSRect)				apparentBounds
{
	NSRect r = [[self transformedPath] bounds];
	
	if ([self style])
	{
		NSSize  as = [[self style] extraSpaceNeeded];
	
		r = NSInsetRect( r, -as.width, -as.height );
		
		// also make a small allowance for the rotation of the shape - this allows for the
		// hypoteneuse of corners
		
		float f = ABS( sinf([self angle] * 2)) * ([[self style] maxStrokeWidth] * 0.36 );
		
		r = NSInsetRect( r, -f, -f );
	}
	
	return r;
}


///*********************************************************************************************************************
///
/// method:			bounds
/// scope:			public instance method
/// overrides:		DKDrawableObject
/// description:	return the total bounds of the shape
/// 
/// parameters:		none
/// result:			a rect, the overall bounds of the shape
///
/// notes:			WARNING: bounds can be affected by the zoom factor of the current view, since knobs resize with
///					zoom. Thus don't rely on bounds remaining unchanged when the zoom factor changes.
///
///********************************************************************************************************************

- (NSRect)				bounds
{
	NSRect	r = NSZeroRect;
	
	if ( ![[self path] isEmpty])
	{
		r = [self knobBounds];
		
		// add allowance for the style and angle
		
		NSSize  as = [self extraSpaceNeeded];
		// also make a small allowance for the rotation of the shape - this allows for the
		// hypoteneuse of corners

		float f = ABS( sinf([self angle] * 2)) * (MAX([[self style] maxStrokeWidth] * 0.5f, 1.0) * 0.36 );
	
		r = NSInsetRect( r, -( as.width + f ), -( as.height + f ));
	}

	return r;
}


///*********************************************************************************************************************
///
/// method:			drawSelectedState
/// scope:			public instance method
/// overrides:		DKDrawableObject
/// description:	
/// 
/// parameters:		none
/// result:			none
///
/// notes:			takes account of its internal state to draw the appropriate control knobs, etc
///
///********************************************************************************************************************

- (void)				drawSelectedState
{
	if ( m_inRotateOp )
	{
		[[[self layer] knobs] drawRotationBarWithKnobsFromCentre:[self knobPoint:kGCDrawableShapeOriginTarget] toPoint:sTempRotationPt];
	
	}
	else
	{
		if ([self operationMode] != kGCShapeTransformStandard )
			[self drawDistortionEnvelope];
		else
		{
			// draw the bounding box:
			
			NSBezierPath* pp = [NSBezierPath bezierPathWithRect:[[self class] unitRectAtOrigin]];
			
			if ([self distortionTransform] != nil )
				pp = [[self distortionTransform] transformBezierPath:pp];
			
			[pp transformUsingAffineTransform:[self transformIncludingParent]];
			[self drawSelectionPath:pp];
			
			// draw the knobs:
			// n.b. drawKnob is a no-op for knobs not included by +knobMask
			
			[self drawKnob:kGCDrawableShapeLeftHandle];
			[self drawKnob:kGCDrawableShapeTopHandle];
			[self drawKnob:kGCDrawableShapeRightHandle];
			[self drawKnob:kGCDrawableShapeBottomHandle];
			[self drawKnob:kGCDrawableShapeTopLeftHandle];
			[self drawKnob:kGCDrawableShapeTopRightHandle];
			[self drawKnob:kGCDrawableShapeBottomLeftHandle];
			[self drawKnob:kGCDrawableShapeBottomRightHandle];
			
			// the other knobs and any hotspots are not drawn when in a locked state
			
			if( ![self locked])
			{
				[self drawKnob:kGCDrawableShapeRotationHandle];
				
				// draw the shape's origin target
				
				if ( !m_hideOriginTarget )
					[self drawKnob:kGCDrawableShapeOriginTarget];

				// draw the hotspots
				
				[self drawHotspotsInState:kGCHotspotStateOn];
			}
		}
	}
}


///*********************************************************************************************************************
///
/// method:			hitPart:
/// scope:			public instance method
/// overrides:		DKDrawableObject
/// description:	hit test the point against the object
/// 
/// parameters:		<pt> the point to test
/// result:			the partcode hit
///
/// notes:			
///
///********************************************************************************************************************

- (int)					hitPart:(NSPoint) pt
{
	int pc = [super hitPart:pt];
	
	if ( pc == kGCDrawingEntireObjectPart )
	{
		// here we need to carefully check if the hit is in the shape or not. It is in the bounds, but
		// the path might not contain it. However, the hit could be on the stroke or shadow so we need to test against
		// the cached bitmap copy of the shape.
		
		if ([[self style] hasFill] && [[self transformedPath] containsPoint:pt])
			return kGCDrawingEntireObjectPart;
		
		if ([self pointHitsPath:pt])
			return kGCDrawingEntireObjectPart;
			
		pc = kGCDrawingNoPart;
	}
	
	return pc;
}


///*********************************************************************************************************************
///
/// method:			hitSelectedPart:forSnapDetection:
/// scope:			protected instance method
/// overrides:		DKDrawableObject
/// description:	hit test the point against the object's selection knobs
/// 
/// parameters:		<pt> the point to test
///					<snap> YES if this is for detecting snaps, NO otherwise
/// result:			the partcode hit
///
/// notes:			only called if object is selected and unlocked
///
///********************************************************************************************************************

- (int)				hitSelectedPart:(NSPoint) pt forSnapDetection:(BOOL) snap
{
	// it's helpful that parts are tested in the order which allows them to work even if the shape has zero size. 
	
	DKKnob*		knobs = [[self layer] knobs];	// performs the basic hit test based on the functional type of the knob
	NSPoint		kp;
	DKKnobType	knobType;
	int			i;

	NSRect	kr;
		
	if([self operationMode] == kGCShapeTransformStandard )
	{
		knobType = [self knobTypeForPartCode:kGCDrawableShapeOriginTarget];
		
		if(([[self class] knobMask] & kGCDrawableShapeOriginTarget) == kGCDrawableShapeOriginTarget )
		{
			if ([knobs hitTestPoint:pt inKnobAtPoint:[self knobPoint:kGCDrawableShapeOriginTarget] ofType:knobType userInfo:nil])
				return kGCDrawableShapeOriginTarget;
		}

		knobType = [self knobTypeForPartCode:kGCDrawableShapeBottomRightHandle];
		
		for( i = kGCDrawableShapeBottomRightHandle; i >= kGCDrawableShapeLeftHandle; --i )
		{
			if(([[self class] knobMask] & i) == i )
			{
				if ( snap )
				{
					kr = NSInsetRect([self knobRect:i], -3, -3 );

					if ( NSMouseInRect( pt, kr, YES ))
						return i;
				}
				else
				{
					kp = [self knobPoint:i];
					
					if([knobs hitTestPoint:pt inKnobAtPoint:kp ofType:knobType userInfo:nil])
						return i;
				}
			}
		}
		
		knobType = [self knobTypeForPartCode:kGCDrawableShapeRotationHandle];
	
		if(([[self class] knobMask] & kGCDrawableShapeRotationHandle) == kGCDrawableShapeRotationHandle )
		{
			if ([knobs hitTestPoint:pt inKnobAtPoint:[self knobPoint:kGCDrawableShapeRotationHandle] ofType:knobType userInfo:nil])
				return kGCDrawableShapeRotationHandle;
		}	
		// check for hits in hotspots
		
		DKHotspot* hs = [self hotspotUnderMouse:pt];
		
		if ( hs )
			return [hs partcode];
	}
	else
	{
		for( i = kGCDrawableShapeTopLeftDistort; i <= kGCDrawableShapeBottomLeftDistort; ++i )
		{
			kr = [self knobRect:i];
			
			if ( snap )
				kr = NSInsetRect( kr, -3, -3 );
			
			if ( NSMouseInRect( pt, kr, YES ))
				return i;
		}
	}
	
	// to allow snap to work with any part of the path, check if we are close to the path and if so return a special
	// partcode that pointForPartcode knows about. Need to record mouse point as it's not passed along in the next call.
	
	if ( snap && NSMouseInRect( pt, [self bounds], YES) && [self pointHitsPath:pt])
	{
		// need to now check that the point is close to the actual path, not just somewhere in the shape
		
		sMouseForPathSnap = pt;
		return kGCDrawableShapeSnapToPathEdge;
	}
	
	return kGCDrawingEntireObjectPart;
}


///*********************************************************************************************************************
///
/// method:			logicalBounds
/// scope:			public instance method
/// overrides:		DKDrawableObject
/// description:	return the bounds of the shape, ignoring stylistic effects
/// 
/// parameters:		none
/// result:			a rect, the pure path bounds
///
/// notes:			
///
///********************************************************************************************************************

- (NSRect)				logicalBounds
{
	return [[self transformedPath] bounds];
}


///*********************************************************************************************************************
///
/// method:			location
/// scope:			public instance method
/// overrides:		DKDrawableObject
/// description:	return sthe shape's current locaiton
/// 
/// parameters:		none
/// result:			the current location
///
/// notes:			
///
///********************************************************************************************************************

- (NSPoint)				location
{
	return m_location;
}


///*********************************************************************************************************************
///
/// method:			mouseDoubleClickedAtPoint:inPart:event:
/// scope:			public instance method
/// overrides:		DKDrawableObject
/// description:	double-click in shape
/// 
/// parameters:		<mp> the mouse point
///					<partcode> the part that was hit
///					<evt> the original event
/// result:			none
///
/// notes:			this is a shortcut for convert to path, making quickly switching between the two representations
///					more than easy. Maybe too easy - might remove for public release.
///
///********************************************************************************************************************

- (void)				mouseDoubleClickedAtPoint:(NSPoint) mp inPart:(int) partcode event:(NSEvent*) evt
{
	#pragma unused(mp)
	#pragma unused(partcode)
	#pragma unused(evt)
	
	//[self convertToPath:self];
}


///*********************************************************************************************************************
///
/// method:			mouseDownAtPoint:inPart:event:
/// scope:			public instance method
/// overrides:		DKDrawableObject
/// description:	handle mouse down event in this object
/// 
/// parameters:		<mp> mouse point
///					<partcode> the partcode hit, as returned by an earlier call to hitPart:
///					<evt> the original event
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				mouseDownAtPoint:(NSPoint) mp inPart:(int) partcode event:(NSEvent*) evt
{
	[super mouseDownAtPoint:mp inPart:partcode event:evt];
	
	m_inMouseOp = YES;
	m_mouseEverMoved = NO;
	m_dragPart = partcode;
	
	// save the current aspect ratio in case we wish to constrain a resize:
	// if the size is zero assume square
	
	if( NSEqualSizes([self size], NSZeroSize ))
		sAspect = 1.0;
	else
		sAspect = fabs([self size].height / [self size].width);
	
	// for rotation, set up a small info window to track the angle
	
	if ( partcode == kGCDrawableShapeRotationHandle )
	{
		[self prepareRotation];
	}
	else if ( partcode >= kGCHotspotBasePartcode )
	{
		[[self hotspotForPartCode:partcode] startMouseTracking:evt inView:[self currentView]];
	}
	else
		[self updateInfoForOperation:kDKShapeOperationResize atPoint:mp];
}


///*********************************************************************************************************************
///
/// method:			mouseDraggedAtPoint:inPart:event:
/// scope:			public instance method
/// overrides:		DKDrawableObject
/// description:	handle a mouse drag in this object
/// 
/// parameters:		<mp> the mouse point
///					<partcode> partcode being dragged
///					<evt> the original event
/// result:			none
///
/// notes:			calls necessary methods to interactively drag the hit part
///
///********************************************************************************************************************

- (void)				mouseDraggedAtPoint:(NSPoint) mp inPart:(int) partcode event:(NSEvent*) evt
{
	// modifier keys constrain shape sizing and rotation thus:
	
	// +shift	- constrain rotation to 15 degree intervals when rotating
	// +shift	- constrain aspect ratio of the shape to whatever it was at the time the mouse first went down
	// +option	- resize the shape from the centre
	// +option	- for rotation, snap mouse to the grid (normally not snapped for rotation operations)
	
	NSPoint omp = mp;
	
	if ( ! m_mouseEverMoved )
	{
		if ( partcode >= kGCDrawableShapeLeftHandle && partcode <= kGCDrawableShapeBottomRightHandle )
		{
			m_hideOriginTarget = YES;
			
			if (([evt modifierFlags] & NSAlternateKeyMask ) != 0 )
				[self setDragAnchorToPart:kGCDrawableShapeObjectCentre];
			else if (([evt modifierFlags] & NSCommandKeyMask ) != 0)
				[self setDragAnchorToPart:kGCDrawableShapeOriginTarget];
			else
				[self setDragAnchorToPart:[self partcodeOppositeKnob:partcode]];
				
		}
	}
	
	BOOL constrain = (([evt modifierFlags] & NSShiftKeyMask) != 0 );
	BOOL controlKey = (([evt modifierFlags] & NSControlKeyMask) != 0 );
	
	if ( partcode == kGCDrawingEntireObjectPart )
	{
		mp.x -= m_mouseOffset.width;
		mp.y -= m_mouseOffset.height;
		
		mp = [self snappedMousePoint:mp forSnappingPointsWithControlFlag:controlKey];
		
		[self moveToPoint:mp];
		[self updateInfoForOperation:kDKShapeOperationMove atPoint:omp];
	}
	else if ( partcode == kGCDrawableShapeRotationHandle )
	{
		m_hideOriginTarget = YES;
		
		mp = [self snappedMousePoint:mp withControlFlag:controlKey];
		
		[self rotateUsingReferencePoint:mp constrain:constrain];
		[self updateInfoForOperation:kDKShapeOperationRotate atPoint:omp];
	}
	else
	{
		if ([self operationMode] != kGCShapeTransformStandard )
			[self moveDistortionKnob:partcode toPoint:mp];
		else
		{
			// if partcode is for a hotspot, track the hotspot
			
			if ( partcode >= kGCHotspotBasePartcode )
			{
				[[self hotspotForPartCode:partcode] continueMouseTracking:evt inView:[self currentView]];
			}
			else
			{
				mp = [self snappedMousePoint:mp withControlFlag:controlKey];
				[self moveKnob:partcode toPoint:mp allowRotate:[self allowSizeKnobsToRotateShape] constrain:constrain];
				
				// update the info window with size or position according to partcode
				
				mp = [self knobPoint:partcode];
				
				if ( partcode == kGCDrawableShapeOriginTarget )
					[self updateInfoForOperation:kDKShapeOperationMove atPoint:omp];
				else
					[self updateInfoForOperation:kDKShapeOperationResize atPoint:omp];
			}
		}
	}
	m_mouseEverMoved = YES;
}


///*********************************************************************************************************************
///
/// method:			mouseUpAtPoint:inPart:event:
/// scope:			public instance method
/// overrides:		DKDrawableObject
/// description:	complete a drag operation
/// 
/// parameters:		<mp> the mouse point
///					<partcode> the part that was hit
///					<evt> the original event
/// result:			none
///
/// notes:			cleans up after a drag operation completes
///
///********************************************************************************************************************

- (void)				mouseUpAtPoint:(NSPoint) mp inPart:(int) partcode event:(NSEvent*) evt
{
	#pragma unused(mp)
	
	m_inMouseOp = NO;
	m_hideOriginTarget = NO;
	
	if ( m_inRotateOp )
	{
		[self notifyVisualChange];
		sTempRotationPt = [self knobPoint:kGCDrawableShapeRotationHandle];
		m_inRotateOp = NO;
	}
	
	if ( partcode >= kGCHotspotBasePartcode )
		[[self hotspotForPartCode:partcode] endMouseTracking:evt inView:[self currentView]];
	
	if ( m_mouseEverMoved )
	{
		if ( partcode >= kGCDrawableShapeLeftHandle && partcode <= kGCDrawableShapeBottomRightHandle )
			[self setOffset:m_savedOffset];

		[[self undoManager] setActionName: [self undoActionNameForPartCode:partcode]];
		m_mouseEverMoved = NO;
	}
	
	[[self layer] hideInfoWindow];
	m_dragPart = 0;
}


///*********************************************************************************************************************
///
/// method:			moveByX:byY:
/// scope:			public instance method
/// overrides:		DKDrawableObject
/// description:	move the shape by a delta offset
/// 
/// parameters:		<dx> add this much to the x coordinate
///					<dy> add this much to the y coordinate
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				moveByX:(float) dx byY:(float) dy
{
	if ( dx != 0.0 || dy != 0.0 )
	{
		[[[self undoManager] prepareWithInvocationTarget:self] moveToPoint:m_location ];

		[self notifyVisualChange];
		m_location.x += dx;
		m_location.y += dy;
		[self notifyVisualChange];
	}
}


///*********************************************************************************************************************
///
/// method:			moveToPoint:
/// scope:			public instance method
/// overrides:		DKDrawableObject
/// description:	sets the shape's location to the given point
/// 
/// parameters:		<location> the new location of the object
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				moveToPoint:(NSPoint) location;
{
	if ( ! NSEqualPoints( location, m_location ))
	{
		[[[self undoManager] prepareWithInvocationTarget:self] moveToPoint:m_location ];
		
		[self notifyVisualChange];
		m_location = location;
		[self notifyVisualChange];
	}
}


///*********************************************************************************************************************
///
/// method:			objectIsNoLongerSelected
/// scope:			public instance method
/// overrides:		DKDrawableObject
/// description:	turn off distortion mode whenever the shape loses selection focus.
/// 
/// parameters:		none
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				objectIsNoLongerSelected
{
	[super objectIsNoLongerSelected];
	[self setOperationMode:kGCShapeTransformStandard];
}


///*********************************************************************************************************************
///
/// method:			pointForPartcode:
/// scope:			public instance method
/// overrides:		DKDrawableObject
/// description:	return the point currently associated with the given partcode
/// 
/// parameters:		<pc> a partcode
/// result:			the point where the partcode is located
///
/// notes:			
///
///********************************************************************************************************************

- (NSPoint)			pointForPartcode:(int) pc
{
	if ( pc == kGCDrawingEntireObjectPart )
		return [self location];
	else if( pc == kGCDrawableShapeSnapToPathEdge )
		return [[self transformedPath] nearestPointToPoint:sMouseForPathSnap tolerance:4];
	else
		return [self knobPoint:pc];
}


///*********************************************************************************************************************
///
/// method:			populateContextualMenu:
/// scope:			public instance method
/// overrides:		DKDrawableObject
/// description:	build a contextual menu pertaining to shapes
/// 
/// parameters:		<theMenu> add items to this menu
/// result:			YES if at least one item added, NO otherwise
///
/// notes:			
///
///********************************************************************************************************************

- (BOOL)				populateContextualMenu:(NSMenu*) theMenu
{
	[[theMenu addItemWithTitle:NSLocalizedString(@"Convert To Path", @"menu item for convert to path") action:@selector( convertToPath: ) keyEquivalent:@""] setTarget:self];
	
	if([self canPastePathWithPasteboard:[NSPasteboard generalPasteboard]])
		[[theMenu addItemWithTitle:NSLocalizedString(@"Paste Path Into Shape", @"menu item for paste path") action:@selector( pastePath: ) keyEquivalent:@""] setTarget:self];

	[theMenu addItem:[NSMenuItem separatorItem]];
	
	[super populateContextualMenu:theMenu];
	return YES;
}


///*********************************************************************************************************************
///
/// method:			renderingPath:
/// scope:			public instance method
/// overrides:		DKDrawableObject
/// description:	return the path that will be actually drawn
/// 
/// parameters:		none
/// result:			a path
///
/// notes:			when drawing in LQ mode, the path is less smooth
///
///********************************************************************************************************************

- (NSBezierPath*)		renderingPath
{
	NSBezierPath* rPath = [self transformedPath];

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
/// overrides:		
/// description:	rotates the shape to he given angle
/// 
/// parameters:		<angle> the desired new angle, in radians
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				rotateToAngle:(float) angle
{
	if ( angle != m_rotationAngle )
	{
		[[[self undoManager] prepareWithInvocationTarget:self] rotateToAngle:m_rotationAngle ];

		[self notifyVisualChange];
		m_rotationAngle = angle;
		[self notifyVisualChange];
	}
}


///*********************************************************************************************************************
///
/// method:			setSize:
/// scope:			public instance method
/// overrides:		DKDrawableObject
/// description:	set the shape's size to the width and height given
/// 
/// parameters:		<newSize> the shape's new size
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				setSize:(NSSize) newSize
{
	if ( ! NSEqualSizes( newSize, m_scale ))
	{
		[[[self undoManager] prepareWithInvocationTarget:self] setSize:m_scale ];

		[self notifyVisualChange];
		m_scale = newSize;
		
		// give the shape the opportunity to reshape the path to account for the new size, if necessary
		// this is implemented by subclasses. Not called if size is zero in either dimension.
		
		if([self size].width != 0.0 && [self size].height != 0.0 )
			[self reshapePath];
			
		[self notifyVisualChange];
	}
}


///*********************************************************************************************************************
///
/// method:			size
/// scope:			public instance method
/// overrides:		
/// description:	returns the shape's current height and width
/// 
/// parameters:		none
/// result:			the shape's size
///
/// notes:			value returned is not reliable if the shape is grouped
///
///********************************************************************************************************************

- (NSSize)				size
{
	return m_scale;
}


///*********************************************************************************************************************
///
/// method:			transform
/// scope:			public instance method
/// overrides:		
/// description:	returns the transform representing the shape's parameters
/// 
/// parameters:		none
/// result:			an autoreleased affine transform, which will convert the unit path to the final form
///
/// notes:			this transform is local - i.e. it does not factor in the parent's transform
///
///********************************************************************************************************************

- (NSAffineTransform*)	transform
{
	// returns a transform which will transform a path at the origin to the correct location, scale and angle of this object.
	
	NSAffineTransform* xform = [NSAffineTransform transform];
	
	[xform translateXBy:[self location].x yBy:[self location].y];
	[xform rotateByRadians:[self angle]];

	float sx = [self size].width;
	float sy = [self size].height;
	
	//if ( sx != 0.0 && sy != 0.0 )
		[xform scaleXBy:sx yBy:sy];
	
	[xform translateXBy:-[self offset].width yBy:-[self offset].height];
	
	return xform;
}


///*********************************************************************************************************************
///
/// method:			cursorForPartcode:
/// scope:			public instance method
/// overrides:		DKDrawableObject
/// description:	return the cursor displayed when a given partcode is hit or entered
/// 
/// parameters:		<partcode> the partcode
///					<button> YES if the mouse left button is pressed, NO otherwise
/// result:			a cursor object
///
/// notes:			the cursor may be displayed when the mouse hovers over or is clicked in the area indicated by the
///					partcode. This should not try to anticipate the action of the mouse if there is any ambiguity-
///					that's the tool's job. The tool may modify the results of this method, so you can just go ahead
///					and return a cursor.
///
///********************************************************************************************************************

- (NSCursor*)		cursorForPartcode:(int) partcode mouseButtonDown:(BOOL) button
{
	#pragma unused(button)
	
	return [[self class] cursorForShapePartcode:partcode];
}




#pragma mark -
///*********************************************************************************************************************
///
/// method:			setOffset:
/// scope:			public instance method
/// overrides:		DKDrawableObject
/// description:	set the offset bewteen the shape's origin and its location point
/// 
/// parameters:		<offs> the desired offset width and height
/// result:			none
///
/// notes:			the offset is the distance between the origin and the rotation centre of the shape. When setting it,
///					we don't want the shape to change position, so we must compensate the location for the offset.
///					The offset is relative to the original unit path bounds, not to the rendered object.
///
///********************************************************************************************************************

- (void)				setOffset:(NSSize) offs
{
	if( !NSEqualSizes( offs, [self offset]))
	{
		[self notifyVisualChange];
		[[[self undoManager] prepareWithInvocationTarget:self] setOffset:m_offset];

		NSPoint p;
		
		p.x = offs.width;
		p.y = offs.height;
		
		p = [[self transform] transformPoint:p];
		
		// set location ivar directly to avoid undo
		
		m_location = p;
		m_offset = offs;
		[self notifyVisualChange];

		LogEvent_( kReactiveEvent, @"set offset = %@; location = %@", NSStringFromSize(m_offset), NSStringFromPoint( p ));
	}
}


///*********************************************************************************************************************
///
/// method:			offset
/// scope:			public instance method
/// overrides:		DKDrawableObject
/// description:	return the current offset
/// 
/// parameters:		none
/// result:			the offset bewteen the shape's position and its origin
///
/// notes:			the default offset is zero
///
///********************************************************************************************************************

- (NSSize)				offset
{
	return m_offset;
}


///*********************************************************************************************************************
///
/// method:			resetOffset
/// scope:			public instance method
/// overrides:		DKDrawableObject
/// description:	force the offset back to zero
/// 
/// parameters:		none
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				resetOffset
{
	[self setOffset:NSZeroSize];
}



///*********************************************************************************************************************
///
/// method:			snappingPointsWithOffset:
/// scope:			public instance method
/// overrides:		DKDrawableObject
/// description:	obtain a list of snapping points
/// 
/// parameters:		<offset> an offset value that is added to each point
/// result:			a list of points (NSValues)
///
/// notes:			snapping points are locations within an object that will snap to a guide. For a shape, this is
///					the handle locations arounds its boundary.
///
///********************************************************************************************************************

- (NSArray*)			snappingPointsWithOffset:(NSSize) offset
{
	NSMutableArray*		pts = [[NSMutableArray alloc] init];
	NSPoint				p;
	int					j[] = {kGCDrawableShapeLeftHandle, kGCDrawableShapeTopHandle, kGCDrawableShapeRightHandle,
								kGCDrawableShapeBottomHandle, kGCDrawableShapeTopLeftHandle, kGCDrawableShapeTopRightHandle,
								kGCDrawableShapeBottomLeftHandle, kGCDrawableShapeBottomRightHandle, kGCDrawableShapeOriginTarget};
	int					i;
	
	for( i = 0; i < 9; ++i )
	{
		p = [self knobPoint:j[i]];
		p.x += offset.width;
		p.y += offset.height;
		[pts addObject:[NSValue valueWithPoint:p]];
	}
	
	return [pts autorelease];
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
	// shapes are invalid if their size is zero in either dimension or there is no path or the path is empty.
	
	BOOL valid;
	NSSize sz = [self size];
	
	valid = ([self path] != nil && ![[self path] isEmpty] && sz.width != 0.0 && sz.height != 0.0);
	
	return valid;
}


#pragma mark -
#pragma mark As an NSObject
- (void)				dealloc
{
	[m_distortTransform release];
	[m_customHotSpots release];
 	[m_path release];
	
	[super dealloc];
}


- (id)					init
{
	self = [super init];
	if (self != nil)
	{
		m_path = [[NSBezierPath bezierPath] retain];
		NSAssert(m_customHotSpots == nil, @"Expected init to zero");
		NSAssert(m_rotationAngle == 0.0, @"Expected init to zero");
		NSAssert(NSEqualPoints(m_location, NSZeroPoint), @"Expected init to zero");
		NSAssert(NSEqualSizes(m_scale, NSZeroSize), @"Expected init to zero");
		NSAssert(NSEqualSizes(m_offset, NSZeroSize), @"Expected init to zero");
		NSAssert(NSEqualSizes(m_savedOffset, NSZeroSize), @"Expected init to zero");
		
		NSAssert(!m_inRotateOp, @"Expected init to NO");
		NSAssert(!m_hideOriginTarget, @"Expected init to NO");
		
		NSAssert(m_opMode == kGCShapeTransformStandard, @"Expected init to zero");
		NSAssert(m_dragPart == 0, @"Expected init to zero");
		NSAssert(m_distortTransform == nil, @"Expected init to zero");
		
		if (m_path == nil)
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
	NSAssert(coder != nil, @"Expected valid coder");
	[super encodeWithCoder:coder];
	
	[coder encodeObject:m_path forKey:@"path"];
	[coder encodeObject:[self hotspots] forKey:@"hot_spots"];
	[coder encodeFloat:[self angle] forKey:@"angle"];
	[coder encodePoint:[self location] forKey:@"location"];
	[coder encodeSize:[self size] forKey:@"size"];
	[coder encodeSize:[self offset] forKey:@"offset"];
	
	[coder encodeObject:[self distortionTransform] forKey:@"dt"];
}


- (id)					initWithCoder:(NSCoder*) coder
{
	NSAssert(coder != nil, @"Expected valid coder");
//	LogEvent_(kFileEvent, @"decoding drawable shape %@", self);

	self = [super initWithCoder:coder];
	if (self != nil)
	{
		[self setPath:[coder decodeObjectForKey:@"path"]];
		[self setHotspots:[coder decodeObjectForKey:@"hot_spots"]];
		[self rotateToAngle:[coder decodeFloatForKey:@"angle"]];
		
		// init order is critical here: offset must be set before location as the location factors in the offset
		
		[self setOffset:[coder decodeSizeForKey:@"offset"]];
		[self moveToPoint:[coder decodePointForKey:@"location"]];
		
		[self setSize:[coder decodeSizeForKey:@"size"]];
		NSAssert(NSEqualSizes(m_savedOffset, NSZeroSize), @"Expected init to zero");
		
		//[self setFlippedHorizontally:[coder decodeBoolForKey:@"fliph"]];
		//[self setFlippedVertically:[coder decodeBoolForKey:@"flipv"]];
		NSAssert(!m_inRotateOp, @"Expected init to NO");
		NSAssert(!m_hideOriginTarget, @"Expected init to NO");
		
		NSAssert(m_opMode == kGCShapeTransformStandard, @"Expected init to zero");
		NSAssert(m_dragPart == 0, @"Expected init to zero");
		[self setDistortionTransform:[coder decodeObjectForKey:@"dt"]];
	}
	return self;
}


#pragma mark -
#pragma mark As part of NSCopying Protocol
- (id)					copyWithZone:(NSZone*) zone
{
	DKDrawableShape* copy = [super copyWithZone:zone];
	
	[copy setPath:m_path];
	[copy setDistortionTransform:[[self distortionTransform] copy]];
	[copy rotateToAngle:[self angle]];
	[copy setSize:[self size]];
	[copy setOffset:[self offset]];
	[copy moveToPoint:[self location]];
	[copy setHotspots:[[self hotspots] deepCopy]];
	
	return copy;
}


#pragma mark -
#pragma mark As part of NSDraggingDestination protocol

- (BOOL)				performDragOperation:(id <NSDraggingInfo>) sender
{
	// this is called when the owning layer permits it, and the drag pasteboard contains a type that matches the class's
	// pasteboardTypesForOperation result. Generally at this point the object should simply handle the drop.
	
	// default behaviour is to derive a style from the current style.
	
	DKStyle* newStyle = [[self style] derivedStyleWithPasteboard:[sender draggingPasteboard] withOptions:kDKDerivedStyleForShapeHint];
	
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
	
	if ( action == @selector( unrotate: ))
		enable = ![self locked] && [self angle] != 0.0;
	else if ( action == @selector( setDistortMode: ))
	{
		enable = ![self locked];
		// check the relevant menu
		
		[item setState:[item tag] == [self operationMode]? NSOnState : NSOffState];
	}
	else if ( action == @selector( resetBoundingBox: ))
		enable = ![self locked] && [self angle] != 0.0;
	else if ( action == @selector( convertToPath: ) ||
			  action == @selector( toggleHorizontalFlip: ) ||
			  action == @selector( toggleVerticalFlip: ))
		enable = ![self locked];
	else if ( action == @selector(pastePath:))
	{
		enable = ![self locked] && [self canPastePathWithPasteboard:[NSPasteboard generalPasteboard]];
	}
	
	enable |= [super validateMenuItem:item];
	
	return enable;
}


@end
