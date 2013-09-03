//
//  DKFillPattern.m
//  DrawingArchitecture
//
//  Created by graham on 26/09/2006.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "DKFillPattern.h"

#import "DKDrawKitMacros.h"
#import "NSBezierPath+Geometry.h"
#import "DKGeometryUtilities.h"
#import "LogEvent.h"

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


- (void)			drawPatternInRect:(NSRect) rect
{
	// this does all the work. It repeatedly draws the motif path to fill <rect> using the set spacing. If the spacings are zero, a suitable offset is
	// calculated from the path bounds. The offsets set the row/column spacing and the odd row/col offset. All patterns are based on the
	// origin of the rect passed.
	
	if([self image] == nil)
		return;	// no image, nothing to do
		
	// because the shape may have any rotation, we cannot rely on the passed rect being aligned to the shape. Thus to prevent the pattern
	// shifting around and having missing elements at the edges, take the longest side of rect, make it square, then multiply by sqrt(2) to
	// allow for the worst-case diagonal.
	
	NSPoint	cp;
	
	cp.x = NSMidX( rect );
	cp.y = NSMidY( rect );

	float max = MAX( NSWidth( rect), NSHeight( rect ));
	rect.size.width = rect.size.height = max * 1.4142f;
	rect = CentreRectOnPoint( rect, cp );
	
	NSSize			mb = [[self image] size];
	float			dx, dy, angle, mangle;
	
	assert( !NSEqualSizes( mb, NSZeroSize ));
	
	dx = ( mb.width * [self scale]) + [self interval];
	dy = ( mb.height * [self scale]) + [self interval];
	
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
	
	int		rows, cols, x, y;
	
	cols = (( rect.size.width /  dx ) / 2) + 1;
	rows = (( rect.size.height / dy ) / 2) + 1;
	
	NSPoint	mp, tp;
	
//	LogEvent_(kInfoEvent, @"drawing patterm, %d rows x %d cols: rect = %@", rows, cols, NSStringFromRect( rect ) );
	
	// set up a transform that will transform each motif point to allow for the object's
	// origin and angle, so the pattern can be rotated as a pattern rather than as individual images
	
	NSAffineTransform* tfm = RotationTransform( angle, cp );
	
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
				
			tp = [tfm transformPoint:mp];
			
			[self placeObjectAtPoint:tp onPath:nil position:0 slope:mangle userInfo:NULL];
		}
	}
}


#pragma mark -
- (void)			setAngle:(float) radians
{
	m_angle = radians;
}


- (float)			angle
{
	return m_angle;
}


- (void)			setAngleInDegrees:(float) degrees
{
	[self setAngle:(degrees * pi)/180.0f];
}


- (float)			angleInDegrees
{
	return ([self angle] * 180.0f)/ pi;
}



- (void)			setAngleIsRelativeToObject:(BOOL) relAngle
{
	m_angleRelativeToObject = relAngle;
}


- (BOOL)			angleIsRelativeToObject
{
	return m_angleRelativeToObject;
}


- (void)			setMotifAngle:(float) radians
{
	m_motifAngle = radians;
}


- (float)			motifAngle
{
	return m_motifAngle;
}


- (void)			setMotifAngleInDegrees:(float) degrees
{
	[self setMotifAngle:(degrees * pi)/180.f];
}


- (float)			motifAngleInDegrees
{
	return ([self motifAngle] * 180.0f)/ pi;
}


- (void)			setMotifAngleIsRelativeToPattern:(BOOL) mrel
{
	m_motifAngleRelativeToPattern = mrel;
}


- (BOOL)			motifAngleIsRelativeToPattern
{
	return m_motifAngleRelativeToPattern;
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
									@"motifAngle", @"motifAngleIsRelativeToPattern", nil]];
}


- (void)			registerActionNames
{
	[super registerActionNames];
	[self setActionName:@"#kind# Pattern Angle" forKeyPath:@"angle"];
	[self setActionName:@"#kind# Pattern Alternate Offset" forKeyPath:@"patternAlternateOffset"];
	[self setActionName:@"#kind# Angle Relative To Object" forKeyPath:@"angleIsRelativeToObject"];
	[self setActionName:@"#kind# Pattern Motif Angle" forKeyPath:@"motifAngle"];
	[self setActionName:@"#kind# Motif Angle Relative To Pattern" forKeyPath:@"motifAngleIsRelativeToPattern"];
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
		NSAssert(m_angle == 0, @"Expected init to zero");
		m_motifAngle = 0.0;
		[self setMotifAngleIsRelativeToPattern:YES];
	}
	return self;
}


#pragma mark -
#pragma mark As part of DKRasterizerProtocol



- (void)			render:(id) obj
{
	m_objectAngle = [obj angle];
	[super render:obj];
}


- (void)			renderPath:(NSBezierPath*) fPath
{
	if ([self image] != nil )
	{
		[NSGraphicsContext saveGraphicsState];
		[fPath addClip];
		[self drawPatternInRect:[fPath bounds]];
		[NSGraphicsContext restoreGraphicsState];
	}
}


- (NSSize)			extraSpaceNeeded
{
	return NSZeroSize;	// none
}



#pragma mark -
#pragma mark As part of NSCoding Protocol
- (void)			encodeWithCoder:(NSCoder*) coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	[super encodeWithCoder:coder];
	
	[coder encodeSize:[self patternAlternateOffset] forKey:@"DKFillPattern_alternatingOffset"];
	[coder encodeFloat:[self angle] forKey:@"DKFillPattern_angle"];
	[coder encodeBool:[self angleIsRelativeToObject] forKey:@"DKFillPattern_angleRelative"];
	[coder encodeFloat:m_motifAngle forKey:@"DKFillPattern_motifAngle"];
	[coder encodeBool:[self motifAngleIsRelativeToPattern] forKey:@"DKFillPattern_motifAngleRelative"];
}


- (id)				initWithCoder:(NSCoder*) coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	self = [super initWithCoder:coder];
	if (self != nil)
	{
		[self setPatternAlternateOffset:[coder decodeSizeForKey:@"DKFillPattern_alternatingOffset"]];
		[self setAngle:[coder decodeFloatForKey:@"DKFillPattern_angle"]];
		[self setAngleIsRelativeToObject:[coder decodeBoolForKey:@"DKFillPattern_angleRelative"]];
		[self setMotifAngle:[coder decodeFloatForKey:@"DKFillPattern_motifAngle"]];
		
		if([coder containsValueForKey:@"DKFillPattern_motifAngleRelative"])
			[self setMotifAngleIsRelativeToPattern:[coder decodeBoolForKey:@"DKFillPattern_motifAngleRelative"]];
		else
			[self setMotifAngleIsRelativeToPattern:YES];
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
	
	return copy;
}

@end
