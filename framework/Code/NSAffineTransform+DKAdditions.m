//
//  NSAffineTransform+DKAdditions.m
///  DrawKit ©2005-2008 Apptree.net
//
//  Created by graham on 27/05/2008.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
//

#import "NSAffineTransform+DKAdditions.h"


@implementation NSAffineTransform (DKAdditions)

- (NSAffineTransform*)		mapFrom:(NSRect) src to:(NSRect) dst
{
	NSAffineTransformStruct at;
	at.m11 = (dst.size.width/src.size.width);
	at.m12 = 0.0;
	at.tX = dst.origin.x - at.m11*src.origin.x;
	at.m21 = 0.0;
	at.m22 = (dst.size.height/src.size.height);
	at.tY = dst.origin.y - at.m22*src.origin.y;
	[self setTransformStruct: at];
	return self;
}


- (NSAffineTransform*)		mapFrom:(NSRect) src to:(NSRect) dst dstAngle:(CGFloat) radians
{
	NSAffineTransformStruct at;
	at.m11 = (dst.size.width/src.size.width) * cosf( radians );
	at.m12 = sinf( radians );
	at.tX = dst.origin.x - at.m11*src.origin.x;
	at.m21 = -sinf( radians );
	at.m22 = (dst.size.height/src.size.height) * cosf( radians );
	at.tY = dst.origin.y - at.m22*src.origin.y;
	[self setTransformStruct: at];
	return self;
}


	/* create a transform that proportionately scales bounds to a rectangle of height
	centered distance units above a particular point.   */
- (NSAffineTransform*)		scaleBounds:(NSRect) bounds toHeight:(CGFloat) height centeredDistance:(CGFloat) distance abovePoint:(NSPoint) location
{
	NSRect dst = bounds;
	CGFloat scale = (height / dst.size.height);
	dst.size.width *= scale;
	dst.size.height *= scale;
	dst.origin.x = location.x - dst.size.width/2.0;
	dst.origin.y = location.y + distance;
	return [self mapFrom:bounds to:dst];
}

	/* create a transform that proportionately scales bounds to a rectangle of height
	centered distance units above the origin.   */
	
	
- (NSAffineTransform*)		scaleBounds:(NSRect) bounds toHeight: (CGFloat) height centeredAboveOrigin:(CGFloat) distance
{
	return [self scaleBounds: bounds toHeight: height centeredDistance:
			distance abovePoint: NSMakePoint(0,0)];
}


	/* initialize the NSAffineTransform so it will flip the contents of bounds
	vertically. */

- (NSAffineTransform*)		flipVertical:(NSRect) bounds
{
	NSAffineTransformStruct at;
	at.m11 = 1.0;
	at.m12 = 0.0;
	at.tX = 0;
	at.m21 = 0.0;
	at.m22 = -1.0;
	at.tY = bounds.size.height;
	[self setTransformStruct: at];
	return self;
}

@end
