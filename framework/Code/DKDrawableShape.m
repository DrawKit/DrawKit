///**********************************************************************************************************************************
///  DKDrawableShape.m
///  DrawKit ¬©2005-2008 Apptree.net
///
///  Created by graham on 13/08/2006.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
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
#import "DKShapeGroup.h"
#import "DKDrawKitMacros.h"
#import "DKPasteboardInfo.h"

#pragma mark Static Vars

static CGFloat			sAspect = 1.0;
static CGFloat			sAngleConstraint = 0.261799387799; // pi/12 or 15 degrees
static NSPoint			sTempRotationPt;
static NSPoint			sMouseForPathSnap;
static NSColor*			sInfoWindowColour = nil;
static NSInteger				sKnobMask = kDKDrawableShapeAllKnobs;
static NSSize			sTempSavedOffset;


@interface DKDrawableShape (Private)
// private:

- (NSRect)					knobBounds;
- (NSInteger)						partcodeOppositeKnob:(NSInteger) knobPartCode;
- (CGFloat)					knobAngleFromOrigin:(NSInteger) knobPartCode;
- (NSPoint)					canonicalCornerPoint:(NSInteger) knobPartCode;
- (void)					moveDistortionKnob:(NSInteger) partCode toPoint:(NSPoint) p;
- (void)					drawDistortionEnvelope;
- (void)					prepareRotation;
- (NSRect)					knobRect:(NSInteger) knobPartCode;
- (void)					updateInfoForOperation:(DKShapeEditOperation) op atPoint:(NSPoint) mp;

@end

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

+ (NSInteger)				knobMask
{
	return sKnobMask;
}


///*********************************************************************************************************************
///
/// method:			setKnobMask
/// scope:			private class method
/// overrides:		
/// description:	set which particular knobs are used by instances of this class
/// 
/// parameters:		<knobMask> bitmask indicating which knobs are to be used
/// result:			none
///
/// notes:			the default is to use all knobs, but you can use this to set a different mask to use for all
///					instances of this class.
///
///********************************************************************************************************************

+ (void)			setKnobMask:(NSInteger) knobMask
{
	sKnobMask = knobMask;
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

+ (void)				setAngularConstraintAngle:(CGFloat) radians
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

+ (NSCursor*)			cursorForShapePartcode:(NSInteger) pc
{
	static NSMutableDictionary*		cursorCache = nil;
	
	NSCursor*	curs = nil;
	NSString*	pairKey;
	
	if ( pc == kDKDrawingEntireObjectPart || pc == kDKDrawingNoPart )
		return [NSCursor arrowCursor];
		
	// cursors are used by opposite pairs of knobs for the sizing case, so if the partcode is part
	// of such a pair, generate the common key. The key name does not include the partcode itself
	// directly so resources are insulated from any changes made to the partcode numbering in future.
	
	if (( pc & kDKDrawableShapeNWSECorners) != 0 )
		pairKey = @"NW-SE";
	else if (( pc & kDKDrawableShapeNESWCorners) != 0 )
		pairKey = @"NE-SW";
	else if (( pc & kDKDrawableShapeEWHandles) != 0 )
		pairKey = @"E-W";
	else if (( pc & kDKDrawableShapeNSHandles) != 0 )
		pairKey = @"N-S";
	else if ( pc == kDKDrawableShapeRotationHandle )
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

+ (DKDrawableShape*)	drawableShapeWithCanonicalBezierPath:(NSBezierPath*) path
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

+ (DKDrawableShape*)	drawableShapeWithBezierPath:(NSBezierPath*) path
{
	return [self drawableShapeWithBezierPath:path rotatedToAngle:0.0];
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

+ (DKDrawableShape*)	drawableShapeWithBezierPath:(NSBezierPath*) path rotatedToAngle:(CGFloat) angle
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

+ (DKDrawableShape*)	drawableShapeWithBezierPath:(NSBezierPath*) path withStyle:(DKStyle*) aStyle
{
	return [self drawableShapeWithBezierPath:path rotatedToAngle:0.0 withStyle:aStyle];
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

+ (DKDrawableShape*)	drawableShapeWithBezierPath:(NSBezierPath*) path rotatedToAngle:(CGFloat) angle withStyle:(DKStyle*) aStyle
{
	DKDrawableShape*	shape = [[self alloc] initWithBezierPath:path rotatedToAngle:angle style:aStyle];
	return [shape autorelease];
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
	return [self initWithRect:aRect style:[DKStyle defaultStyle]];
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
	return [self initWithOvalInRect:aRect style:[DKStyle defaultStyle]];
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
	return [self initWithCanonicalBezierPath:path style:[DKStyle defaultStyle]];
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

- (id)					initWithBezierPath:(NSBezierPath*) aPath rotatedToAngle:(CGFloat) angle
{
	return [self initWithBezierPath:aPath rotatedToAngle:angle style:[DKStyle defaultStyle]];
}


- (id)					initWithRect:(NSRect) aRect style:(DKStyle*) aStyle
{
	self = [self initWithStyle:aStyle];
	if (self != nil)
	{
		NSPoint cp;
		cp.x = NSMidX( aRect );
		cp.y = NSMidY( aRect );
		
		[self setSize:aRect.size];
		[self setLocation:cp];
	}
	return self;
}



- (id)					initWithOvalInRect:(NSRect) aRect style:(DKStyle*) aStyle
{
	self = [self initWithStyle:aStyle];
	if (self != nil)
	{
		[[self path] removeAllPoints];
		[[self path] appendBezierPathWithOvalInRect:[[self class] unitRectAtOrigin]];
		
		NSPoint cp;
		cp.x = NSMidX( aRect );
		cp.y = NSMidY( aRect );
		
		[self setSize:aRect.size];
		[self setLocation:cp];
	}
	return self;
}



- (id)					initWithCanonicalBezierPath:(NSBezierPath*) path style:(DKStyle*) aStyle
{
	NSAssert( path != nil, @"can't initialize with a nil path");
	
	// check the path is canonical:
	
	NSRect br = [path bounds];
	
	if( ! NSEqualRects( br, [[self class] unitRectAtOrigin]))
		[NSException raise:NSInternalInconsistencyException format:@"attempt to initialise shape with a non-canonical path"];
	
	self = [self initWithStyle:aStyle];
	if (self != nil)
	{
		[self setPath:path];
	}
	return self;
}



- (id)					initWithBezierPath:(NSBezierPath*) aPath style:(DKStyle*) aStyle
{
	return [self initWithBezierPath:aPath rotatedToAngle:0.0 style:aStyle];
}



- (id)					initWithBezierPath:(NSBezierPath*) aPath rotatedToAngle:(CGFloat) angle style:(DKStyle*) style
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
	
	self = [self initWithRect:br style:style];
	
	if( self != nil )
	{
		NSAffineTransform*	xfm = [self inverseTransform];
		NSBezierPath* transformedPath = [xfm transformBezierPath:aPath];
		
		[self setPath:transformedPath];
		[self setAngle:angle];
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
///					the method adoptPath: will probably be what you want.
///
///********************************************************************************************************************

- (void)				setPath:(NSBezierPath*) path
{
	NSAssert( path != nil, @"can't set a nil path");
	NSAssert( ![path isEmpty], @"can't set an empty path");
	
	NSRect oldBounds = [self bounds];
	mBoundsCache = NSZeroRect;
	
	// sanity check the path - if it's not canonical, throw. Note that testing for exact equality doesn't work - the
	// rect is sometimes a tiny amount off due to fp rounding errors in the transformation. This is intended to
	// catch gross abuses or misunderstanding of this method.
	
	if( ! AreSimilarRects( [path bounds], [[self class] unitRectAtOrigin], 0.01 ))
	{
		NSLog(@"path bounds = %@", NSStringFromRect([path bounds]));
		[NSException raise:NSInternalInconsistencyException format:@"attempt to set non-canonical path in %@", self];
	}
	
	[[self undoManager] registerUndoWithTarget:self selector:@selector(setPath:) object:m_path];
	
	[path retain];
	[m_path release];
	m_path = path;
	[self notifyVisualChange];
	[self notifyGeometryChange:oldBounds];
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
	CGFloat angl = [self angle];

	if (angl != 0.0 )
	{
		// if initially rotated, bounds must be compensated for the angle
		
		NSPoint cp = [self location];
		
		path = [path rotatedPath:-angl aboutPoint:cp];
		br = [path bounds];
		[self setAngle:0];
	}

	NSPoint loc = NSMakePoint( NSMidX( br ), NSMidY( br ));

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
	NSPoint oo = [self knobPoint:kDKDrawableShapeOriginTarget];
	
	CGFloat rotationKnobAngle = [self knobAngleFromOrigin:kDKDrawableShapeRotationHandle];
	CGFloat angle = atan2f( rp.y - oo.y, rp.x - oo.x ) - rotationKnobAngle;
	
	CGFloat dist = hypotf( rp.x - oo.x, rp.y - oo.y );
	
	if ( constrain )
	{
		CGFloat rem = fmodf( angle, sAngleConstraint );
		
		if ( rem > sAngleConstraint / 2.0 )
			angle += ( sAngleConstraint - rem );
		else
			angle -= rem;
	}
	
	// post update prior to recalculating sTempRotationPt
	
	mBoundsCache = NSZeroRect;
	[self notifyVisualChange];
	
	CGFloat ta = angle + rotationKnobAngle;
	
	sTempRotationPt.x = oo.x + ( dist * cosf( ta ));
	sTempRotationPt.y = oo.y + ( dist * sinf( ta ));
	
	mBoundsCache = NSZeroRect;
	[self notifyVisualChange];
	[self setAngle:angle];
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

- (void)				moveKnob:(NSInteger) knobPartCode toPoint:(NSPoint) p allowRotate:(BOOL) rotate constrain:(BOOL) constrain
{
	// if the knob isn't allowed by the class knobmask, ignore it
	
	if (([[self class] knobMask] & knobPartCode ) == 0 )
		return;
	
	if ( knobPartCode == kDKDrawableShapeOriginTarget )
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
		CGFloat		dx, dy, ka;
		
		dx = p.x - [self location].x;
		dy = p.y - [self location].y;
		ka = [self knobAngleFromOrigin:knobPartCode];
		
		// rotation
		
		if ( rotate )
			[self setAngle:atan2f( dy, dx ) - ka ];
			
		// scaling
		
		// normalise the mouse point by cancelling out any overall rotation.
		
		CGFloat	pa = atan2f( dy, dx ) - [self angle];
		CGFloat	radius = hypotf( dx, dy );
		CGFloat	ndx, ndy;
		
		ndx = radius * cosf( pa );
		ndy = radius * sinf( pa );
		
		// whether we are adjusting the scale width, height or both depends on which knob we have hit
		
		NSSize		oldSize = [self size];
		CGFloat		scx, scy;
		NSUInteger	kbMask;
		
		// allow for offset, which is where the anchor for the resize is currently set.
		
		NSSize	offset = [self offset];
		
		kbMask = kDKDrawableShapeHorizontalSizingKnobs;
		
		if (( knobPartCode & kbMask ) != 0 )
		{
			if (( knobPartCode & kDKDrawableShapeAllLeftHandles ) != 0 )
				scx = ndx / -( offset.width + 0.5 );
			else
				scx = ndx / ( 0.5 - offset.width );
		}
		else
			scx = oldSize.width;
			
		kbMask = kDKDrawableShapeVerticalSizingKnobs;
			
		if (( knobPartCode & kbMask ) != 0 )
		{
			if (( knobPartCode & kDKDrawableShapeAllTopHandles ) != 0 )
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
	
	CGFloat angle = [self angle];
	[self setAngle:-angle];
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
	
	CGFloat angle = [self angle];
	[self setAngle:-angle];
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
	CGFloat angl = [self angle];
	
	NSBezierPath* path = [[self transformedPath] rotatedPath:-angl];
	
	[self setAngle:0.0];
	[self adoptPath:path];
	[self setAngle:angl];
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
	
	[self setAngle:0.0];
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
	NSInteger			k, knob[4] = { kDKDrawableShapeTopLeftHandle, kDKDrawableShapeTopRightHandle, kDKDrawableShapeBottomLeftHandle, kDKDrawableShapeBottomRightHandle };

	for( k = 3; k >= 0; --k )
	{
		NSPoint corner = [grid nearestGridIntersectionToPoint:[self knobPoint:knob[k]]];
		
		[self setDragAnchorToPart:[self partcodeOppositeKnob:knob[k]]];
		[self moveKnob:knob[k] toPoint:corner allowRotate:NO constrain:NO];
		[self setOffset:sTempSavedOffset];
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

- (NSRect)				knobRect:(NSInteger) knobPartCode
{
	DKKnobType	knobType = [self knobTypeForPartCode:knobPartCode];
	NSPoint		p = [self knobPoint:knobPartCode];
	
	NSRect kr;
	
	if ([[self layer] knobs])
	{
		kr = [[[self layer] knobs] controlKnobRectAtPoint:p ofType:knobType];
		
		if( kr.size.width < 1 || kr.size.height < 1 )
			kr = NSInsetRect( kr, -3, -3 );
	}
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
	
	if([self operationMode] == kDKShapeTransformStandard)
	{
		br = NSUnionRect( br, [self knobRect:kDKDrawableShapeTopLeftHandle]);
		br = NSUnionRect( br, [self knobRect:kDKDrawableShapeBottomRightHandle]);
		br = NSUnionRect( br, [self knobRect:kDKDrawableShapeOriginTarget]);
		
		if ([self angle] != 0.0 )
		{
			br = NSUnionRect( br, [self knobRect:kDKDrawableShapeTopRightHandle]);
			br = NSUnionRect( br, [self knobRect:kDKDrawableShapeBottomLeftHandle]);
		}
		
		if ( m_inRotateOp )
		{
			NSRect rk = [[[self layer] knobs] controlKnobRectAtPoint:sTempRotationPt ofType:kDKRotationKnobType];
			br = NSUnionRect( br, rk );
		}
	}
	else
	{
		br = NSUnionRect( br, [self knobRect:kDKDrawableShapeTopLeftDistort]);
		br = NSUnionRect( br, [self knobRect:kDKDrawableShapeTopRightDistort]);
		br = NSUnionRect( br, [self knobRect:kDKDrawableShapeBottomLeftDistort]);
		br = NSUnionRect( br, [self knobRect:kDKDrawableShapeBottomRightDistort]);
	}
	
	return br;
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

- (NSInteger)					partcodeOppositeKnob:(NSInteger) knobPartCode
{
	static NSInteger pc[] = { kDKDrawableShapeRightHandle, kDKDrawableShapeBottomHandle, kDKDrawableShapeLeftHandle, kDKDrawableShapeTopHandle,
						kDKDrawableShapeBottomRightHandle, kDKDrawableShapeBottomLeftHandle,
						kDKDrawableShapeTopRightHandle, kDKDrawableShapeTopLeftHandle };
	
	if ( knobPartCode > kDKDrawableShapeBottomRightHandle )
		return knobPartCode;
	else
	{
		NSInteger indx = 0;
		NSUInteger mask = 1;
		
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

- (void)				setDragAnchorToPart:(NSInteger) part
{
	// saves the offset, then sets the current offset to the location of the given part. This sets the drag origin to the given point.
	// usually this will be the knob opposite the one being dragged.
	
	sTempSavedOffset = m_offset;
	
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

- (CGFloat)				knobAngleFromOrigin:(NSInteger) knobPartCode
{
	NSPoint		p;
	CGFloat		dy, dx;
	
	if ( knobPartCode == kDKDrawableShapeRotationHandle )
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

- (void)				drawKnob:(NSInteger) knobPartCode
{
	// if knob disallowed by mask, ignore it
	
	if ([[self class] knobMask] & knobPartCode )
	{
		NSPoint		kp = [self knobPoint:knobPartCode];
		DKKnob*		knobs = [[self layer] knobs];
		DKKnobType	knobType = [self knobTypeForPartCode:knobPartCode];
		NSColor*	selColour = (knobType == kDKRotationKnobType || knobType == kDKCentreTargetKnobType)? nil : [[self layer] selectionColour];
		
		[knobs drawKnobAtPoint:kp ofType:knobType angle:[self angle] highlightColour:selColour];
			
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

- (NSPoint)			canonicalCornerPoint:(NSInteger) knobPartCode
{
	NSRect		r = [[self class] unitRectAtOrigin];
	NSPoint		kp;

	switch( knobPartCode )
	{
		default:
			return NSZeroPoint;
			
		case kDKDrawableShapeTopLeftHandle:
			kp.x = NSMinX( r );
			kp.y = NSMinY( r );
			break;
			
		case kDKDrawableShapeTopHandle:
			kp.x = NSMidX( r );
			kp.y = NSMinY( r );
			break;
			
		case kDKDrawableShapeTopRightHandle:
			kp.x = NSMaxX( r );
			kp.y = NSMinY( r );
			break;
			
		case kDKDrawableShapeRightHandle:
			kp.x = NSMaxX( r );
			kp.y = NSMidY( r );
			break;
			
		case kDKDrawableShapeBottomRightHandle:
			kp.x = NSMaxX( r );
			kp.y = NSMaxY( r );
			break;
			
		case kDKDrawableShapeBottomHandle:
			kp.x = NSMidX( r );
			kp.y = NSMaxY( r );
			break;
			
		case kDKDrawableShapeBottomLeftHandle:
			kp.x = NSMinX( r );
			kp.y = NSMaxY( r );
			break;
			
		case kDKDrawableShapeLeftHandle:
			kp.x = NSMinX( r );
			kp.y = NSMidY( r );
			break;
			
		case kDKDrawableShapeObjectCentre:
			kp.x = NSMidX( r );
			kp.y = NSMidY( r );
			break;
			
		case kDKDrawableShapeOriginTarget:
			kp.x = [self offset].width;
			kp.y = [self offset].height;
			break;
			
		case kDKDrawableShapeRotationHandle:
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

- (NSPoint)			knobPoint:(NSInteger) knobPartCode
{
	NSPoint		kp;
	NSRect		r = [[self class] unitRectAtOrigin];
	NSPoint		qp[4];

	switch( knobPartCode )
	{
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

	if ( knobPartCode < kDKDrawableShapeTopLeftDistort && [self distortionTransform] != nil )
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

- (DKKnobType)		knobTypeForPartCode:(NSInteger) pc
{
	DKKnobType knobType;

	if ( pc == kDKDrawableShapeRotationHandle )
		knobType = kDKRotationKnobType;
	else if ( pc == kDKDrawableShapeOriginTarget )
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

- (NSString*)			undoActionNameForPartCode:(NSInteger) pc
{
	NSString* s = nil;
	
	switch( pc )
	{
		case kDKDrawingNoPart:
			s = @"????";	// this shouldn't happen
			break;
			
		case kDKDrawingEntireObjectPart:
			s = NSLocalizedString( @"Move", @"undo string for move object");
			break;
			
		case kDKDrawableShapeRotationHandle:
			s = NSLocalizedString( @"Rotate", @"undo string for rotate object");
			break;
			
		case kDKDrawableShapeOriginTarget:
			s = NSLocalizedString( @"Move Origin", @"undo string for object offset");
			break;
			
		case kDKDrawableShapeTopLeftDistort:
		case kDKDrawableShapeTopRightDistort:
		case kDKDrawableShapeBottomRightDistort:
		case kDKDrawableShapeBottomLeftDistort:
		{
			switch([self operationMode])
			{
				default:
					s = NSLocalizedString( @"Distortion Transform", @"undo string for object distortion");
					break;
					
				case kDKShapeTransformHorizontalShear:
					s = NSLocalizedString( @"Horizontal Shear", @"undo string for h shear");
					break;
					
				case kDKShapeTransformVerticalShear:
					s = NSLocalizedString( @"Vertical Shear", @"undo string for v shear");
					break;
					
				case kDKShapeTransformPerspective:
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

- (void)				moveDistortionKnob:(NSInteger) partCode toPoint:(NSPoint) p
{
	NSInteger	qi = 0;
	
	switch( partCode )
	{
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
		case kDKShapeTransformFreeDistort:
			q[qi] = p;
			[t setEnvelopePoints:q];
			break;
			
		case kDKShapeTransformHorizontalShear:
			if ( qi == 2 || qi == 3 )
				[t shearHorizontallyBy: -(p.x - q[qi].x)];
			else
				[t shearHorizontallyBy: p.x - q[qi].x];
			break;
			
		case kDKShapeTransformVerticalShear:
			if ( qi == 0 || qi == 3 )
				[t shearVerticallyBy:- (p.y - q[qi].y)];
			else
				[t shearVerticallyBy:p.y - q[qi].y];
			break;
			
		case kDKShapeTransformPerspective:
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
	return [self knobPoint:kDKDrawableShapeRotationHandle];
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
		NSString*	fmt1, *fmt2;
		NSArray*	fmt3;
		
		switch( op )
		{
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

- (void)				setOperationMode:(NSInteger) mode
{
	if ( mode != m_opMode )
	{
		[[[self undoManager] prepareWithInvocationTarget:self] setOperationMode:m_opMode];
		
		m_opMode = mode;
		
		if ( mode != kDKShapeTransformStandard && ([self distortionTransform] == nil ))
		{
			[self setDistortionTransform:[DKDistortionTransform transformWithInitialRect:[[self class] unitRectAtOrigin]]];
			[self notifyVisualChange];
		}
		
		if ( mode == kDKShapeTransformStandard )
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

- (NSInteger)					operationMode
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
			[self setOperationMode:kDKShapeTransformStandard];
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
	
	Class pathClass = [DKDrawableObject classForConversionRequestFor:[DKDrawablePath class]];
	DKDrawablePath* dp = [pathClass drawablePathWithBezierPath:path withStyle:[self style]];
	
	[dp setUserInfo:[self userInfo]];
	
	[path release];

	return dp;
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
	
	NSArray*			subpaths = [[self renderingPath] subPaths];
	NSEnumerator*		iter = [subpaths objectEnumerator];
	NSBezierPath*		pp;
	NSMutableArray*		newObjects;
	DKDrawableShape*	dp;
	
	newObjects = [[NSMutableArray alloc] init];
	
	while(( pp = [iter nextObject]))
	{
		if ( ![pp isEmpty])
		{
			dp = [[self class] drawableShapeWithBezierPath:pp rotatedToAngle:[self angle]];
			
			[dp setStyle:[self style]];
			[dp setUserInfo:[self userInfo]];
			[newObjects addObject:dp];
		}
	}
	
	return [newObjects autorelease];
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
	NSInteger						myIndex = [layer indexOfObject:self];
	
	DKDrawablePath*			po = [self makePath];
	
	[po willBeAddedAsSubstituteFor:self toLayer:layer];
	
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
	
	[self setAngle:0.0];
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
	
	CGFloat angle = DEGREES_TO_RADIANS([sender doubleValue]);
	
	[self setAngle:angle];
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
	NSInteger m = [sender tag];
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
	NSArray* objects = [DKDrawableObject nativeObjectsFromPasteboard:pb];
	
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
				
				CGFloat x, y;
				
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
	NSString* type = [pb availableTypeFromArray:[NSArray arrayWithObject:kDKDrawableObjectInfoPasteboardType]];
	if( type )
	{
		DKPasteboardInfo* info = [DKPasteboardInfo pasteboardInfoWithPasteboard:pb];
		return [info count] == 1;
	}
	
	return NO;
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
		[odl addObjectsFromArray:broken];
		[odl removeObject:self];
		[odl exchangeSelectionWithObjectsFromArray:broken];
		[odl commitSelectionUndoWithActionName:NSLocalizedString(@"Break Apart", @"undo string for break apart")];
	}
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

+ (NSInteger)				initialPartcodeForObjectCreation
{
	if(([self knobMask] & kDKDrawableShapeBottomRightHandle) == kDKDrawableShapeBottomRightHandle )
		return kDKDrawableShapeBottomRightHandle;
	else
	{
		// bottom/right not available, so return one that is
		
		NSInteger i;
		
		for( i = kDKDrawableShapeBottomLeftHandle; i >= kDKDrawableShapeLeftHandle; --i )
		{
			if(([self knobMask] & i) == i )
				return i;
		}
	
		return kDKDrawingNoPart;
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
	return [NSArray arrayWithObjects:NSColorPboardType, NSPDFPboardType, NSTIFFPboardType, NSFilenamesPboardType,
				NSStringPboardType, kDKStyleKeyPasteboardType, kDKStylePasteboardType, nil];
}


///*********************************************************************************************************************
///
/// method:			initWithStyle:
/// scope:			public instance method; designated initializer
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
	if (self != nil)
	{
		m_path = [[NSBezierPath bezierPathWithRect:[[self class] unitRectAtOrigin]] retain];
		
		if (m_path == nil)
		{
			[self autorelease];
			self = nil;
		}
	}
	return self;
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

- (CGFloat)				angle
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
		
		CGFloat f = ABS( sinf([self angle] * 2)) * ([[self style] maxStrokeWidth] * 0.36 );
		
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
	if( NSEqualRects( mBoundsCache, NSZeroRect ))
	{
		NSRect	r = NSZeroRect;
		
		if ( ![[self path] isEmpty])
		{
			r = [self knobBounds];
			
			// add allowance for the style and angle
			
			NSSize  as = [self extraSpaceNeeded];
			// also make a small allowance for the rotation of the shape - this allows for the
			// hypoteneuse of corners
			
			CGFloat f = ABS( sinf([self angle] * 1.0)) * (MAX([[self style] maxStrokeWidth] * 0.5f, 1.0) * 0.25 );
			mBoundsCache = NSInsetRect( r, -( as.width + f ), -( as.height + f ));
		}
	}
	
	return mBoundsCache;
}


///*********************************************************************************************************************
///
/// method:			drawContent
/// scope:			public instance method
/// overrides:		DKDrawableObject
/// description:	
/// 
/// parameters:		none
/// result:			none
///
/// notes:			for hit testing, uses thickened stroke if necessary to make hitting easier
///
///********************************************************************************************************************

- (void)				drawContent
{
	if([self isBeingHitTested])
	{
		// for easier hit-testing of very thin or offset paths, the path is stroked using a
		// centre-aligned 2pt or greater stroke. This is substituted on the fly here and never visible to the user.
		
		BOOL hasStroke = [[self style] hasStroke];
		BOOL hasFill = !hasStroke || [[self style] hasFill] || [[self style] hasHatch];
		
		CGFloat strokeWidth = hasStroke? MAX( 2, [[self style] maxStrokeWidth]) : 0;
		
		DKStyle* temp = [DKStyle styleWithFillColour:hasFill? [NSColor blackColor] : nil strokeColour:hasStroke? [NSColor blackColor] : nil strokeWidth:strokeWidth];
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
	NSAutoreleasePool* pool = [NSAutoreleasePool new];
	
	if ( m_inRotateOp )
	{
		[[[self layer] knobs] drawRotationBarWithKnobsFromCentre:[self knobPoint:kDKDrawableShapeOriginTarget] toPoint:sTempRotationPt];
	
	}
	else
	{
		if ([self operationMode] != kDKShapeTransformStandard )
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
			
			[self drawKnob:kDKDrawableShapeLeftHandle];
			[self drawKnob:kDKDrawableShapeTopHandle];
			[self drawKnob:kDKDrawableShapeRightHandle];
			[self drawKnob:kDKDrawableShapeBottomHandle];
			[self drawKnob:kDKDrawableShapeTopLeftHandle];
			[self drawKnob:kDKDrawableShapeTopRightHandle];
			[self drawKnob:kDKDrawableShapeBottomLeftHandle];
			[self drawKnob:kDKDrawableShapeBottomRightHandle];
			
			// the other knobs and any hotspots are not drawn when in a locked state
			
			if( ![self locked])
			{
				[self drawKnob:kDKDrawableShapeRotationHandle];
				
				// draw the shape's origin target
				
				if ( !m_hideOriginTarget )
					[self drawKnob:kDKDrawableShapeOriginTarget];

				// draw the hotspots
				
				[self drawHotspotsInState:kDKHotspotStateOn];
			}
		}
	}
	
	[pool drain];
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

- (NSInteger)					hitPart:(NSPoint) pt
{
	NSInteger pc = [super hitPart:pt];
	
	if ( pc == kDKDrawingEntireObjectPart )
	{
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

- (NSInteger)				hitSelectedPart:(NSPoint) pt forSnapDetection:(BOOL) snap
{
	// it's helpful that parts are tested in the order which allows them to work even if the shape has zero size. 
	
	DKKnob*		knobs = [[self layer] knobs];	// performs the basic hit test based on the functional type of the knob
	NSPoint		kp;
	DKKnobType	knobType;
	NSRect		kr;
	NSInteger			knob;
		
	if([self operationMode] == kDKShapeTransformStandard )
	{
		knobType = [self knobTypeForPartCode:kDKDrawableShapeOriginTarget];
		
		if(([[self class] knobMask] & kDKDrawableShapeOriginTarget) == kDKDrawableShapeOriginTarget )
		{
			if ([knobs hitTestPoint:pt inKnobAtPoint:[self knobPoint:kDKDrawableShapeOriginTarget] ofType:knobType userInfo:nil])
				return kDKDrawableShapeOriginTarget;
		}
		
		knob = kDKDrawableShapeBottomRightHandle;
		knobType = [self knobTypeForPartCode:knob];
		
		while( knob > 0 )
		{
			if(([[self class] knobMask] & knob) == knob )
			{
				if ( snap )
				{
					kr = ScaleRect([self knobRect:knob], 2.0 );

					if ( NSMouseInRect( pt, kr, [[self drawing] isFlipped] ))
						return knob;
				}
				else
				{
					kp = [self knobPoint:knob];
					
					if([knobs hitTestPoint:pt inKnobAtPoint:kp ofType:knobType userInfo:nil])
						return knob;
				}
			}
			
			knob >>= 1;
		}
		
		knobType = [self knobTypeForPartCode:kDKDrawableShapeRotationHandle];
	
		if(([[self class] knobMask] & kDKDrawableShapeRotationHandle) == kDKDrawableShapeRotationHandle )
		{
			if ([knobs hitTestPoint:pt inKnobAtPoint:[self knobPoint:kDKDrawableShapeRotationHandle] ofType:knobType userInfo:nil])
				return kDKDrawableShapeRotationHandle;
		}	
		// check for hits in hotspots
		
		DKHotspot* hs = [self hotspotUnderMouse:pt];
		
		if ( hs )
			return [hs partcode];
	}
	else
	{
		knob = kDKDrawableShapeTopLeftDistort;
		
		while( knob <=  kDKDrawableShapeBottomLeftDistort )
		{
			kr = [self knobRect:knob];
			
			if ( snap )
				kr = ScaleRect( kr, 2.0 );
			
			if ( NSMouseInRect( pt, kr, [[self drawing] isFlipped] ))
				return knob;
				
			knob <<= 1;
		}
	}
	
	// to allow snap to work with any part of the path, check if we are close to the path and if so return a special
	// partcode that pointForPartcode knows about. Need to record mouse point as it's not passed along in the next call.
	
	if ( snap && NSMouseInRect( pt, [self bounds], YES) && [self pointHitsPath:pt])
	{
		// need to now check that the point is close to the actual path, not just somewhere in the shape
		
		sMouseForPathSnap = pt;
		return kDKDrawableShapeSnapToPathEdge;
	}
	
	return kDKDrawingEntireObjectPart;
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

- (void)				setLocation:(NSPoint) location;
{
	if ( !NSEqualPoints( location, [self location]) && ![self locationLocked])
	{
		NSRect oldBounds = [self bounds];
		[[[self undoManager] prepareWithInvocationTarget:self] setLocation:[self location]];
		
		[self notifyVisualChange];
		m_location = location;
		mBoundsCache = NSZeroRect;
		[self notifyVisualChange];
		[self notifyGeometryChange:oldBounds];
	}
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

- (void)				mouseDownAtPoint:(NSPoint) mp inPart:(NSInteger) partcode event:(NSEvent*) evt
{
	[super mouseDownAtPoint:mp inPart:partcode event:evt];
	
	// save the current aspect ratio in case we wish to constrain a resize:
	// if the size is zero assume square
	
	if( NSEqualSizes([self size], NSZeroSize ))
		sAspect = 1.0;
	else
		sAspect = fabs([self size].height / [self size].width);
	
	// for rotation, set up a small info window to track the angle
	
	if ( partcode == kDKDrawableShapeRotationHandle )
	{
		[self prepareRotation];
	}
	else if ( partcode >= kDKHotspotBasePartcode )
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

- (void)				mouseDraggedAtPoint:(NSPoint) mp inPart:(NSInteger) partcode event:(NSEvent*) evt
{
	// modifier keys constrain shape sizing and rotation thus:
	
	// +shift	- constrain rotation to 15 degree intervals when rotating
	// +shift	- constrain aspect ratio of the shape to whatever it was at the time the mouse first went down
	// +option	- resize the shape from the centre
	// +option	- for rotation, snap mouse to the grid (normally not snapped for rotation operations)
	
	NSPoint omp = mp;
	
	if ( ![self mouseHasMovedSinceStartOfTracking])
	{
		if ( partcode >= kDKDrawableShapeLeftHandle && partcode <= kDKDrawableShapeBottomRightHandle )
		{
			m_hideOriginTarget = YES;
			
			if (([evt modifierFlags] & NSAlternateKeyMask ) != 0 )
				[self setDragAnchorToPart:kDKDrawableShapeObjectCentre];
			else if (([evt modifierFlags] & NSCommandKeyMask ) != 0)
				[self setDragAnchorToPart:kDKDrawableShapeOriginTarget];
			else
				[self setDragAnchorToPart:[self partcodeOppositeKnob:partcode]];
				
		}
	}
	
	BOOL constrain = (([evt modifierFlags] & NSShiftKeyMask) != 0 );
	BOOL controlKey = (([evt modifierFlags] & NSControlKeyMask) != 0 );
	
	if ( partcode == kDKDrawingEntireObjectPart )
	{
		if( ![self locationLocked])
		{
			mp.x -= [self mouseDragOffset].width;
			mp.y -= [self mouseDragOffset].height;
			
			mp = [self snappedMousePoint:mp forSnappingPointsWithControlFlag:controlKey];
			
			[self setLocation:mp];
			[self updateInfoForOperation:kDKShapeOperationMove atPoint:omp];
		}
	}
	else if ( partcode == kDKDrawableShapeRotationHandle )
	{
		m_hideOriginTarget = YES;
		
		mp = [self snappedMousePoint:mp withControlFlag:controlKey];
		
		[self rotateUsingReferencePoint:mp constrain:constrain];
		[self updateInfoForOperation:kDKShapeOperationRotate atPoint:omp];
	}
	else
	{
		if ([self operationMode] != kDKShapeTransformStandard )
			[self moveDistortionKnob:partcode toPoint:mp];
		else
		{
			// if partcode is for a hotspot, track the hotspot
			
			if ( partcode >= kDKHotspotBasePartcode )
			{
				[[self hotspotForPartCode:partcode] continueMouseTracking:evt inView:[self currentView]];
			}
			else
			{
				mp = [self snappedMousePoint:mp withControlFlag:controlKey];
				[self moveKnob:partcode toPoint:mp allowRotate:[self allowSizeKnobsToRotateShape] constrain:constrain];
				
				// update the info window with size or position according to partcode
				
				if ( partcode == kDKDrawableShapeOriginTarget )
					[self updateInfoForOperation:kDKShapeOperationMove atPoint:omp];
				else
					[self updateInfoForOperation:kDKShapeOperationResize atPoint:omp];
			}
		}
	}
	[self setMouseHasMovedSinceStartOfTracking:YES];
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

- (void)				mouseUpAtPoint:(NSPoint) mp inPart:(NSInteger) partcode event:(NSEvent*) evt
{
	#pragma unused(mp)
	
	[self setTrackingMouse:NO];
	m_hideOriginTarget = NO;
	
	if ( m_inRotateOp )
	{
		[self notifyVisualChange];
		sTempRotationPt = [self knobPoint:kDKDrawableShapeRotationHandle];
		m_inRotateOp = NO;
	}
	
	if ( partcode >= kDKHotspotBasePartcode )
		[[self hotspotForPartCode:partcode] endMouseTracking:evt inView:[self currentView]];
	
	if ([self mouseHasMovedSinceStartOfTracking])
	{
		if ( partcode >= kDKDrawableShapeLeftHandle && partcode <= kDKDrawableShapeBottomRightHandle )
			[self setOffset:sTempSavedOffset];

		[[self undoManager] setActionName: [self undoActionNameForPartCode:partcode]];
		[self setMouseHasMovedSinceStartOfTracking:NO];
	}
	
	[[self layer] hideInfoWindow];
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
	[self setOperationMode:kDKShapeTransformStandard];
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

- (NSPoint)			pointForPartcode:(NSInteger) pc
{
	if ( pc == kDKDrawingEntireObjectPart )
		return [self location];
	else if( pc == kDKDrawableShapeSnapToPathEdge )
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
	// put the conversion item into the submenu if it exists
	
	NSMenu* convertMenu = [[theMenu itemWithTag:kDKConvertToSubmenuTag] submenu];
	
	if( convertMenu == nil )
		[[theMenu addItemWithTitle:NSLocalizedString(@"Convert To Path", @"menu item for convert to path") action:@selector( convertToPath: ) keyEquivalent:@""] setTarget:self];
	else
		[[convertMenu addItemWithTitle:NSLocalizedString(@"Path", @"submenu item for convert to path") action:@selector( convertToPath: ) keyEquivalent:@""] setTarget:self];
		
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
		[rPath setFlatness:2.0];
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

- (void)				setAngle:(CGFloat) angle
{
	if ( angle != m_rotationAngle )
	{
		NSRect oldBounds = [self bounds];
		
		[[[self undoManager] prepareWithInvocationTarget:self] setAngle:m_rotationAngle ];

		[self notifyVisualChange];
		m_rotationAngle = angle;
		mBoundsCache = NSZeroRect;
		[self notifyVisualChange];
		
		[self notifyGeometryChange:oldBounds];
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
		NSRect oldBounds = [self bounds];
		
		[[[self undoManager] prepareWithInvocationTarget:self] setSize:m_scale ];

		[self notifyVisualChange];
		m_scale = newSize;
		mBoundsCache = NSZeroRect;
		
		// give the shape the opportunity to reshape the path to account for the new size, if necessary
		// this is implemented by subclasses. Not called if size is zero in either dimension.
		
		if([self size].width != 0.0 && [self size].height != 0.0 )
			[self reshapePath];
			
		[self notifyVisualChange];
		[self notifyGeometryChange:oldBounds];
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

	CGFloat sx = [self size].width;
	CGFloat sy = [self size].height;
	
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

- (NSCursor*)		cursorForPartcode:(NSInteger) partcode mouseButtonDown:(BOOL) button
{
	#pragma unused(button)
	
	return [[self class] cursorForShapePartcode:partcode];
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
	NSAssert( aGroup != nil, @"expected valid group");
	NSAssert( aTransform != nil, @"expected valid transform");

	NSPoint loc = [self location];
	NSBezierPath* path = [[self transformedPath] copy];
	
	[path transformUsingAffineTransform:aTransform];
	loc = [aTransform transformPoint:loc];
	
	NSRect pathBounds = [path bounds];
	
	if( pathBounds.size.height > 0 && pathBounds.size.width > 0 )
	{
		[self setLocation:loc];
		[self rotateByAngle:[aGroup angle]];	// preserves rotated bounds
		[self adoptPath:path];
	}
	else
		[self setSize:NSZeroSize];
	
	[path release];
}


- (void)				setStyle:(DKStyle*) aStyle
{
	mBoundsCache = NSZeroRect;
	[super setStyle:aStyle];
	mBoundsCache = NSZeroRect;
	[self notifyVisualChange];
}


- (void)				styleWillChange:(NSNotification*) note
{
	[super styleWillChange:note];
	mBoundsCache = NSZeroRect;
}


- (void)				setContainer:(id<DKDrawableContainer>) container
{
	[super setContainer:container];
	mBoundsCache = NSZeroRect;
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
///					The offset is relative to the original unit path bounds, not to the rendered object. (In other words,
///					the offset doesn't need to change with a shape's size. So to set e.g. the top, left corner as the origin
///					call [shape setOrigin:NSMakeSize(-0.5,-0.5)]; )
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
		mBoundsCache = NSZeroRect;
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
	NSInteger					j[] = {kDKDrawableShapeLeftHandle, kDKDrawableShapeTopHandle, kDKDrawableShapeRightHandle,
								kDKDrawableShapeBottomHandle, kDKDrawableShapeTopLeftHandle, kDKDrawableShapeTopRightHandle,
								kDKDrawableShapeBottomLeftHandle, kDKDrawableShapeBottomRightHandle, kDKDrawableShapeOriginTarget};
	NSInteger					i;
	
	for( i = 0; i < 9; ++i )
	{
		if(( i & [[self class] knobMask]) != 0)
		{
			p = [self knobPoint:j[i]];
			p.x += offset.width;
			p.y += offset.height;
			[pts addObject:[NSValue valueWithPoint:p]];
		}
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


#pragma mark -
#pragma mark As part of NSCoding Protocol
- (void)				encodeWithCoder:(NSCoder*) coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	[super encodeWithCoder:coder];
	
	[coder encodeObject:m_path forKey:@"path"];
	[coder encodeObject:[self hotspots] forKey:@"hot_spots"];
	[coder encodeDouble:[self angle] forKey:@"angle"];
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
- (id)					copyWithZone:(NSZone*) zone
{
	DKDrawableShape* copy = [super copyWithZone:zone];
	
	[copy setPath:m_path];
	
	DKDistortionTransform* dfm = [[self distortionTransform] copy];
	[copy setDistortionTransform:dfm];
	[dfm release];
	
	[copy setAngle:[self angle]];
	[copy setSize:[self size]];
	[copy setOffset:[self offset]];
	[copy setLocation:[self location]];
	
	NSArray* hots = [[self hotspots] deepCopy];
	[copy setHotspots:hots];
	[hots release];
	
	return copy;
}


#pragma mark -
#pragma mark As part of NSDraggingDestination protocol

- (BOOL)				performDragOperation:(id <NSDraggingInfo>) sender
{
	// this is called when the owning layer permits it, and the drag pasteboard contains a type that matches the class's
	// pasteboardTypesForOperation result. Generally at this point the object should simply handle the drop.
	
	// default behaviour is to derive a style from the current style.
	
	DKStyle* newStyle;
	
	// first see if we have dropped a complete style
	
	newStyle = [DKStyle styleFromPasteboard:[sender draggingPasteboard]];
	
	if( newStyle == nil )
	{
		// no, so perhaps we can derive a style for other data such as text, images or colours:
		
		newStyle = [[self style] derivedStyleWithPasteboard:[sender draggingPasteboard] withOptions:kDKDerivedStyleForShapeHint];
	}
	
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
	
	if ( action == @selector( unrotate: ))
		return ![self locked] && [self angle] != 0.0;
	
	if ( action == @selector( setDistortMode: ))
	{
		[item setState:[item tag] == [self operationMode]? NSOnState : NSOffState];
		return ![self locked];
	}
	
	if ( action == @selector( resetBoundingBox: ))
		return ![self locked] && [self angle] != 0.0;
	
	if ( action == @selector( convertToPath: ) ||
			  action == @selector( toggleHorizontalFlip: ) ||
			  action == @selector( toggleVerticalFlip: ))
		return ![self locked];
	
	if ( action == @selector(pastePath:))
		return ![self locked] && [self canPastePathWithPasteboard:[NSPasteboard generalPasteboard]];
	
	if ( action == @selector( breakApart: ))
		return ![self locked] && [[self path] countSubPaths] > 1;
	
	return [super validateMenuItem:item];
}


@end
