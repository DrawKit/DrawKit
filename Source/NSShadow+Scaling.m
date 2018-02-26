/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import "DKDrawKitMacros.h"
#import "NSColor+DKAdditions.h"
#import "NSShadow+Scaling.h"
#include <tgmath.h>

@implementation NSShadow (DKAdditions)
#pragma mark As a NSShadow

- (void)setAbsolute
{
	[self setAbsoluteFlipped:NO];

	//[self set];
}

- (void)setAbsoluteFlipped:(BOOL)flipped
{
	CGContextRef cc = [[NSGraphicsContext currentContext] graphicsPort];
	CGAffineTransform ctm = CGContextGetCTM(cc);
	CGSize unit = CGSizeApplyAffineTransform(CGSizeMake(1, 1), ctm);

	NSSize os = [self shadowOffset];

	if (flipped)
		os.height = -os.height;

	CGSize offset = CGSizeApplyAffineTransform(NSSizeToCGSize(os), ctm);
	CGFloat blur = [self shadowBlurRadius] * unit.width;
	CGColorRef colour = [[self shadowColor] newQuartzColor];

	CGContextSetShadowWithColor(cc, offset, blur, colour);
	CGColorRelease(colour);
}

#pragma mark -

#ifdef DRAWKIT_DEPRECATED
- (void)setShadowAngle:(CGFloat)radians distance:(CGFloat)dist
{
	NSSize offset;

	offset.width = dist * cos(radians);
	offset.height = dist * sin(radians);

	[self setShadowOffset:offset];
}

- (void)setShadowAngleInDegrees:(CGFloat)degrees distance:(CGFloat)dist
{
	[self setShadowAngle:DEGREES_TO_RADIANS(degrees)
				distance:dist];
}

- (CGFloat)shadowAngle
{
	NSSize offset = [self shadowOffset];
	return atan2(offset.height, offset.width);
}

- (CGFloat)shadowAngleInDegrees
{
	CGFloat angle = RADIANS_TO_DEGREES([self shadowAngle]);

	if (angle < 0)
		angle += 360.0;

	return angle;
}

#endif

- (void)setAngle:(CGFloat)radians
{
	NSSize offset;

	offset.width = [self distance] * cos(radians);
	offset.height = [self distance] * sin(radians);

	[self setShadowOffset:offset];
}

- (void)setAngleInDegrees:(CGFloat)degrees
{
	if (degrees < 0)
		degrees += 360;

	degrees = fmod(degrees, 360.0);

	[self setAngle:DEGREES_TO_RADIANS(degrees)];
}

- (CGFloat)angle
{
	NSSize offset = [self shadowOffset];
	return atan2(offset.height, offset.width);
}

- (CGFloat)angleInDegrees
{
	CGFloat angle = RADIANS_TO_DEGREES([self angle]);

	if (angle < 0)
		angle += 360.0;

	return angle;
}

- (void)setDistance:(CGFloat)distance
{
	NSSize offset;
	CGFloat radians = [self angle];

	offset.width = distance * cos(radians);
	offset.height = distance * sin(radians);

	[self setShadowOffset:offset];
}

- (CGFloat)distance
{
	NSSize offset = [self shadowOffset];
	return hypot(offset.width, offset.height);
}

- (CGFloat)extraSpace
{
	// return the amount of additional space the shadow occupies beyond the edge of any object shadowed

	CGFloat es = 0.0;

	es = fabs(MAX([self shadowOffset].width, [self shadowOffset].height));
	es += [self shadowBlurRadius];

	return es;
}

- (void)drawApproximateShadowWithPath:(NSBezierPath*)path operation:(DKShadowDrawingOperation)op strokeWidth:(NSInteger)sw
{
	// one problem with shadows is that they are expensive in rendering time terms. This may help - it draws a fake shadow for the path
	// using the current shadow parameters, but just block filling/stroking it. Call this *instead* of drawing the shadow (not as well as)
	// to get something approximating the shadow. Later you can use the real shadow for higher quality output.

	NSAssert(path != nil, @"path was nil when drawing fake shadow");
	NSAssert(![path isEmpty], @"path was empty when drawing fake shadow");

	[[NSGraphicsContext currentContext] setCompositingOperation:NSCompositeSourceOver];
	[[[self shadowColor] colorWithAlphaComponent:0.3] set];
	NSSize offset = [self shadowOffset];

	NSBezierPath* temp;
	NSAffineTransform* offsetTfm = [NSAffineTransform transform];
	[offsetTfm translateXBy:offset.width
						yBy:offset.height];
	temp = [offsetTfm transformBezierPath:path];

	if (op & kDKShadowDrawFill)
		[temp fill];

	if (op & kDKShadowDrawStroke) {
		[temp setLineWidth:sw];
		[temp stroke];
	}
}

@end
