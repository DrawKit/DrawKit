//
//  DKFillPattern.m
///  DrawKit ©2005-2008 Apptree.net
//
//  Created by graham on 26/09/2006.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
//

#import "DKFillPattern.h"
#import "DKDrawKitMacros.h"
#import "NSBezierPath+Text.h"
#import "NSBezierPath-OAExtensions.h"
#import "DKGeometryUtilities.h"
#import "LogEvent.h"
#import "DKRandom.h"


@implementation DKFillPattern
#pragma mark As a DKFillPattern


+ (DKFillPattern*)	defaultPattern
{
	// return the default pattern , which is based on some image - unlikely to be really useful so might be
	// better to do something else here???
	
	return [[[self alloc] initWithImage:[NSImage imageNamed:@"Rect"]] autorelease];
}



+ (DKFillPattern*)	fillPatternWithImage:(NSImage*) image
{
	return [[[self alloc] initWithImage:image] autorelease];
}



#pragma mark -
- (void)			setPatternAlternateOffset:(NSSize) altOffset
{
	// sets the vertical and horizontal offset of odd rows/columns to a proportion of the interval, [0...1]
	
	m_altXOffset = LIMIT( altOffset.width, 0, 1 );
	m_altYOffset = LIMIT( altOffset.height, 0, 1 );
}


- (NSSize)			patternAlternateOffset
{
	return NSMakeSize( m_altXOffset, m_altYOffset );
}


#pragma mark -
- (void)			fillRect:(NSRect) rect
{
	NSBezierPath*	fp = [NSBezierPath bezierPathWithRect:rect];
	[self renderPath:fp];
}


- (void)			drawPatternInPath:(NSBezierPath*) aPath
{
	// this does all the work. It repeatedly draws the motif path to fill <rect> using the set spacing. If the spacings are zero, a suitable offset is
	// calculated from the path bounds. The offsets set the row/column spacing and the odd row/col offset. All patterns are based on the
	// origin of the rect passed.
	
	if([self image] == nil)
		return;	// no image, nothing to do
	
	NSRect rect = [aPath bounds];
		
	// because the shape may have any rotation, we cannot rely on the passed rect being aligned to the shape. Thus to prevent the pattern
	// shifting around and having missing elements at the edges, take the longest side of rect, make it square, then multiply by sqrt(2) to
	// allow for the worst-case diagonal.
	
	NSPoint	cp;
	
	cp.x = NSMidX( rect );
	cp.y = NSMidY( rect );

	CGFloat max = MAX( NSWidth( rect), NSHeight( rect ));
	rect.size.width = rect.size.height = max * 1.4142f;
	rect = CentreRectOnPoint( rect, cp );
	
	NSSize			mb = [[self image] size];
	CGFloat			dx, dy, angle, mangle;
	
	// image must have some positive size
	
	if( mb.width <= 0.0 || mb.height <= 0.0 )
		return;
	
	// interval is also scaled so that relative placement is maintained as scale is altered - this is
	// slightly different from earlier versions where the interval was fixed and unaffected by scale - it may cause
	// a minor change in the appearance of patterns created in previous versions.
	
	dx = ( mb.width + [self interval]) * [self scale];
	dy = ( mb.height + [self interval]) * [self scale];
	
	// if either of these values <= 0, bail - it would cause an infinite loop and no drawing. This
	// could occur for negative values of interval, which is now legal.
	
	if( dx <= 0.0 || dy <= 0.0 )
		return;

	// what angles for the pattern as a whole and each motif?
	
	angle = [self angle];
	mangle = [self motifAngle];
	
	if([self angleIsRelativeToObject])
	{
		angle += m_objectAngle;
		mangle += m_objectAngle;
	}
	
	if([self motifAngleIsRelativeToPattern])
		mangle += [self angle];
	
	// how many rows and columns of the motif will we need to fill the rect?
	// n.b. div by 2 because we go from -cols to +cols etc
	
	NSInteger		rows, cols, x, y;
	
	cols = (( rect.size.width /  dx ) / 2) + 1;
	rows = (( rect.size.height / dy ) / 2) + 1;
	
	NSPoint	mp, tp;
	
//	LogEvent_(kInfoEvent, @"drawing patterm, %d rows x %d cols: rect = %@", rows, cols, NSStringFromRect( rect ) );
	
	NSRect motifBounds;
	
	motifBounds.size.width = mb.width * [self scale];
	motifBounds.size.height = mb.height * [self scale];
	
	NSAutoreleasePool* pool = [NSAutoreleasePool new];
	
	// set up a transform that will transform each motif point to allow for the object's
	// origin and angle, so the pattern can be rotated as a pattern rather than as individual images
	
	NSAffineTransform*	tfm = RotationTransform( angle, cp );
	NSPoint				wobblePoint = NSZeroPoint;
	CGFloat				tempAngle = mangle;
	
	// ok, draw 'em...
	
	for( y = -rows; y < rows; ++y )
	{
		for ( x = -cols; x < cols; ++x )
		{
			if ( y & 1 )
				mp.x = dx * (x + m_altXOffset) + cp.x;
			else
				mp.x = ( x * dx ) + cp.x;
			
			if ( x & 1 )
				mp.y = dy * (y + m_altYOffset) + cp.y;
			else
				mp.y = (y * dy) + cp.y;
				
			if([self wobblyness] > 0.0 )
			{
				// wobblyness is a randomising positioning factor from 0..1. Cached to avoid recalculation on every redraw.
				
				if( mPlacementCount < [mWobbleCache count])
					wobblePoint = [[mWobbleCache objectAtIndex:mPlacementCount] pointValue];
				else
				{
					wobblePoint.x = [DKRandom randomPositiveOrNegativeNumber] * dx * [self wobblyness];
					wobblePoint.y = [DKRandom randomPositiveOrNegativeNumber] * dy * [self wobblyness];
					[mWobbleCache addObject:[NSValue valueWithPoint:wobblePoint]];
				}
				
				mp.x += wobblePoint.x;
				mp.y += wobblePoint.y;
			}

			if([self motifAngleRandomness] > 0.0 )
			{
				CGFloat ra = 0.0;
				
				if( mPlacementCount < [mMotifAngleRandCache count])
					ra = [[mMotifAngleRandCache objectAtIndex:mPlacementCount] floatValue];
				else
				{
					ra = [DKRandom randomPositiveOrNegativeNumber] * 2.0 * pi * [self motifAngleRandomness];
					[mMotifAngleRandCache addObject:[NSNumber numberWithFloat:ra]];
				}
				tempAngle = mangle;
				tempAngle += ra;
			}
			
			tp = [tfm transformPoint:mp];
			++mPlacementCount;
			
			if( m_noClippedElements )
			{
				// if this option is set, we don't draw pattern images that intersect the path. To detect whether that happens, the bounding rect
				// of the element is calculated in position and intersected with the path. The text for intersection can be potentially intensive,
				// so this option may incur a significant performance hit depending on pattern density, as every placed element needs to be checked.
				
				// first, if <tp> is outside the path, we already know it's clipped or intersecting, so we can trivially discard that case
				
				if(![aPath containsPoint:tp])
					continue;
				
				// tp is inside the path but not all of the image's bounds may be, so need to do full intersection test
				
				motifBounds.origin.x = tp.x - motifBounds.size.width * 0.5f;
				motifBounds.origin.y = tp.y - motifBounds.size.height * 0.5f;
				
				// uses Omni's code to perform the detection - returns as soon as it has an answer
				
				if([aPath intersectsRect:motifBounds])
					continue;
			}
			
			// defer to superclass's placement method to actually draw the elements which applies further transformations, etc.
			
			[self placeObjectAtPoint:tp onPath:nil position:0 slope:tempAngle userInfo:NULL];
		}
	}
	
	[pool drain];
}


#pragma mark -
- (void)			setAngle:(CGFloat) radians
{
	m_angle = radians;
}


- (CGFloat)			angle
{
	return m_angle;
}


- (void)			setAngleInDegrees:(CGFloat) degrees
{
	[self setAngle:DEGREES_TO_RADIANS(degrees)];
}


- (CGFloat)			angleInDegrees
{
	CGFloat angle = RADIANS_TO_DEGREES([self angle]);
	
	if( angle < 0 )
		angle += 360.0f;
		
	return angle;
}



- (void)			setAngleIsRelativeToObject:(BOOL) relAngle
{
	m_angleRelativeToObject = relAngle;
}


- (BOOL)			angleIsRelativeToObject
{
	return m_angleRelativeToObject;
}


- (void)			setMotifAngle:(CGFloat) radians
{
	m_motifAngle = radians;
}


- (CGFloat)			motifAngle
{
	return m_motifAngle;
}


- (void)			setMotifAngleInDegrees:(CGFloat) degrees
{
	[self setMotifAngle:DEGREES_TO_RADIANS(degrees)];
}


- (CGFloat)			motifAngleInDegrees
{
	CGFloat angle = RADIANS_TO_DEGREES([self motifAngle]);
	
	if( angle < 0 )
		angle += 360.0f;
		
	return angle;
}


- (void)			setMotifAngleIsRelativeToPattern:(BOOL) mrel
{
	m_motifAngleRelativeToPattern = mrel;
}


- (BOOL)			motifAngleIsRelativeToPattern
{
	return m_motifAngleRelativeToPattern;
}


- (void)			setMotifAngleRandomness:(CGFloat) maRand
{
	maRand = LIMIT( maRand, 0, 1 );
	
	if( maRand != mMotifAngleRandomness )
	{
		mMotifAngleRandomness = maRand;
		
		if( mMotifAngleRandCache == nil )
			mMotifAngleRandCache = [[NSMutableArray alloc] init];
		
		[mMotifAngleRandCache removeAllObjects];
	}
}


- (CGFloat)			motifAngleRandomness
{
	return mMotifAngleRandomness;
}


- (void)			setDrawingOfClippedElementsSupressed:(BOOL) supress
{
	// setting this causes a test for intersection of the motif's bounds with the object's path. If there is an intersection, the motif is not drawn. This makes patterns
	// appear tidier for certain applications (such as GIS/mapping) but adds a substantial performance overhead. Off by default.
	
	m_noClippedElements = supress;
}


- (BOOL)			drawingOfClippedElementsSupressed
{
	return m_noClippedElements;
}



#pragma mark -
#pragma mark As a DKPathDecorator
- (id)				initWithImage:(NSImage*) image
{
	self = [super initWithImage:image];
	if(self != nil)
	{
		m_altXOffset = 0.0;
		m_altYOffset = 0.5;
		NSAssert(m_angle == 0, @"Expected init to zero");
		m_motifAngle = 0.0;
		[self setMotifAngleIsRelativeToPattern:YES];
	}
	
	return self;
}


#pragma mark -
#pragma mark As a GCObservableObject
+ (NSArray*)		observableKeyPaths
{
	return [[super observableKeyPaths] arrayByAddingObjectsFromArray:[NSArray arrayWithObjects:@"angle",
									@"patternAlternateOffset", @"angleIsRelativeToObject",
									@"motifAngle", @"motifAngleIsRelativeToPattern", @"drawingOfClippedElementsSupressed",
									@"motifAngleRandomness", nil]];
}


- (void)			registerActionNames
{
	[super registerActionNames];
	[self setActionName:@"#kind# Pattern Angle" forKeyPath:@"angle"];
	[self setActionName:@"#kind# Pattern Alternate Offset" forKeyPath:@"patternAlternateOffset"];
	[self setActionName:@"#kind# Angle Relative To Object" forKeyPath:@"angleIsRelativeToObject"];
	[self setActionName:@"#kind# Pattern Motif Angle" forKeyPath:@"motifAngle"];
	[self setActionName:@"#kind# Motif Angle Relative To Pattern" forKeyPath:@"motifAngleIsRelativeToPattern"];
	[self setActionName:@"#kind# Don't draw clipped images" forKeyPath:@"drawingOfClippedElementsSupressed"];
	[self setActionName:@"#kind# Motif Angle Randomness" forKeyPath:@"motifAngleRandomness"];
}

#pragma mark -
#pragma mark As an NSObject
- (id)				init
{
	self = [super init];
	if (self != nil)
	{
		m_altXOffset = 0.0;
		m_altYOffset = 0.5;
		m_motifAngle = 0.0;
		[self setMotifAngleIsRelativeToPattern:YES];
	}
	return self;
}


- (void)			dealloc
{
	[mMotifAngleRandCache release];
	[super dealloc];
}


#pragma mark -
#pragma mark As part of DKRasterizerProtocol



- (void)			render:(id<DKRenderable>) obj
{
	if( ![obj conformsToProtocol:@protocol(DKRenderable)])
		return;
	
	if([self enabled])
	{
		m_objectAngle = [obj angle];
		[super render:obj];
	}
}


- (void)			renderPath:(NSBezierPath*) fPath
{
	if ([self image] != nil )
	{
		SAVE_GRAPHICS_CONTEXT		//[NSGraphicsContext saveGraphicsState];
		[fPath addClip];
		mPlacementCount = 0;
		[self drawPatternInPath:fPath];
		RESTORE_GRAPHICS_CONTEXT	//[NSGraphicsContext restoreGraphicsState];
	}
}


- (NSSize)			extraSpaceNeeded
{
	return NSZeroSize;	// none
}

- (BOOL)		isFill
{
	return YES;
}




#pragma mark -
#pragma mark As part of NSCoding Protocol
- (void)			encodeWithCoder:(NSCoder*) coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	[super encodeWithCoder:coder];
	
	[coder encodeSize:[self patternAlternateOffset] forKey:@"DKFillPattern_alternatingOffset"];
	[coder encodeDouble:[self angle] forKey:@"DKFillPattern_angle"];
	[coder encodeBool:[self angleIsRelativeToObject] forKey:@"DKFillPattern_angleRelative"];
	[coder encodeDouble:m_motifAngle forKey:@"DKFillPattern_motifAngle"];
	[coder encodeBool:[self motifAngleIsRelativeToPattern] forKey:@"DKFillPattern_motifAngleRelative"];
	[coder encodeBool:[self drawingOfClippedElementsSupressed] forKey:@"DKFillPattern_noClippedImages"];
	[coder encodeDouble:[self motifAngleRandomness] forKey:@"DKFillPattern_motifAngleRandomness"];
}


- (id)				initWithCoder:(NSCoder*) coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	self = [super initWithCoder:coder];
	if (self != nil)
	{
		[self setPatternAlternateOffset:[coder decodeSizeForKey:@"DKFillPattern_alternatingOffset"]];
		[self setAngle:[coder decodeDoubleForKey:@"DKFillPattern_angle"]];
		[self setAngleIsRelativeToObject:[coder decodeBoolForKey:@"DKFillPattern_angleRelative"]];
		[self setMotifAngle:[coder decodeDoubleForKey:@"DKFillPattern_motifAngle"]];
		[self setMotifAngleRandomness:[coder decodeDoubleForKey:@"DKFillPattern_motifAngleRandomness"]];
		
		if([coder containsValueForKey:@"DKFillPattern_motifAngleRelative"])
			[self setMotifAngleIsRelativeToPattern:[coder decodeBoolForKey:@"DKFillPattern_motifAngleRelative"]];
		else
			[self setMotifAngleIsRelativeToPattern:YES];
		
		[self setDrawingOfClippedElementsSupressed:[coder decodeBoolForKey:@"DKFillPattern_noClippedImages"]];
	}
	return self;
}

#pragma mark -
#pragma mark As part of NSCopying Protocol
- (id)				copyWithZone:(NSZone*) zone
{
	DKFillPattern* copy = [super copyWithZone:zone];
	[copy setPatternAlternateOffset:[self patternAlternateOffset]];
	[copy setAngle:[self angle]];
	[copy setMotifAngle:[self motifAngle]];
	[copy setAngleIsRelativeToObject:[self angleIsRelativeToObject]];
	[copy setMotifAngleIsRelativeToPattern:[self motifAngleIsRelativeToPattern]];
	[copy setDrawingOfClippedElementsSupressed:[self drawingOfClippedElementsSupressed]];
	[copy setMotifAngleRandomness:[self motifAngleRandomness]];
	
	return copy;
}

@end
