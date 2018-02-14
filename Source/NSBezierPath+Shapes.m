/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import "NSBezierPath+Shapes.h"
#import "NSBezierPath+Geometry.h"

#pragma mark Constants(Non - localized)
//static const CGFloat deg60 = 1.0471975512;
static const CGFloat sin60 = 0.8660254038;

@implementation NSBezierPath (Shapes)
#pragma mark As a NSBezierPath
#pragma mark - chains and sprockets

+ (NSBezierPath*)bezierPathWithStandardChainLink
{
	NSBezierPath* path = [self bezierPath];
	CGFloat r = 1.0 / 2.5;
	NSPoint ep, cp1, cp2;

	[path setWindingRule:NSEvenOddWindingRule];
	[path appendBezierPathWithArcWithCenter:NSZeroPoint
									 radius:r
								 startAngle:90
								   endAngle:270];

	ep.x = 0.5;
	ep.y = -0.707 * r;

	cp1.x = 0.2;
	cp1.y = -r;

	cp2.x = 0.3333333;
	cp2.y = ep.y;

	[path curveToPoint:ep
		 controlPoint1:cp1
		 controlPoint2:cp2];

	cp2.x = 0.66667;
	cp1.x = 0.8;
	ep.x = 1.0;
	ep.y = -r;

	[path curveToPoint:ep
		 controlPoint1:cp2
		 controlPoint2:cp1];
	[path appendBezierPathWithArcWithCenter:NSMakePoint(1, 0)
									 radius:r
								 startAngle:270
								   endAngle:90];

	ep.x = 0.5;
	ep.y = 0.707 * r;
	cp1.y = r;
	cp2.y = ep.y;

	[path curveToPoint:ep
		 controlPoint1:cp1
		 controlPoint2:cp2];

	ep.x = 0;
	ep.y = r;
	cp2.x = 0.333333;
	cp1.x = 0.2;

	[path curveToPoint:ep
		 controlPoint1:cp2
		 controlPoint2:cp1];
	[path closePath];

	NSRect cr = NSMakeRect(-0.5 * r, -0.5 * r, r, r);

	[path appendBezierPathWithOvalInRect:cr];
	cr.origin.x += 1.0;
	[path appendBezierPathWithOvalInRect:cr];

	return path;
}

+ (NSBezierPath*)bezierPathWithStandardChainLinkFromPoint:(NSPoint)a toPoint:(NSPoint)b
{
	NSBezierPath* linkPath = [self bezierPathWithStandardChainLink];
	NSAffineTransform* tfm = [NSAffineTransform transform];

	CGFloat slope = atan2(b.y - a.y, b.x - a.x);
	CGFloat length = hypot(b.x - a.x, b.y - a.y);

	[tfm translateXBy:a.x
				  yBy:a.y];
	[tfm scaleXBy:length
			  yBy:length];
	[tfm rotateByRadians:slope];

	[linkPath transformUsingAffineTransform:tfm];

	return linkPath;
}

+ (NSBezierPath*)bezierPathWithSprocketPitch:(CGFloat)pitch numberOfTeeth:(NSInteger)teeth
{
	CGFloat toothAngle = M_PI / teeth;
	CGFloat radius = pitch / (2 * sin(toothAngle));
	CGFloat rollerRadius = pitch / 3.6;
	CGFloat toothRadius = pitch - rollerRadius;

	// make one tooth then copy it around the circle

	NSPoint rp1, rp2;
	NSBezierPath* tooth = [NSBezierPath bezierPath];

	rp1.x = radius * cos(toothAngle);
	rp1.y = radius * sin(toothAngle);
	rp2.x = radius * cos(-toothAngle);
	rp2.y = radius * sin(-toothAngle);

	// tooth root follows roller radius

	CGFloat taDegrees = (toothAngle * 180.0) / M_PI;

	[tooth appendBezierPathWithArcWithCenter:rp1
									  radius:rollerRadius
								  startAngle:180 + taDegrees
									endAngle:270
								   clockwise:NO];

	// flank of tooth follows the larger radius until it reaches the halfway point. The x3 here stops it slightly short so that
	// the top edge of the tooth is flattened off a little

	CGFloat endAngle = (cos(pitch / (3 * toothRadius)) * 180.0) / M_PI;

	[tooth appendBezierPathWithArcWithCenter:rp2
									  radius:toothRadius
								  startAngle:90
									endAngle:endAngle
								   clockwise:YES];
	[tooth appendBezierPathWithArcWithCenter:rp1
									  radius:toothRadius
								  startAngle:360 - endAngle
									endAngle:270
								   clockwise:YES];
	[tooth appendBezierPathWithArcWithCenter:rp2
									  radius:rollerRadius
								  startAngle:90
									endAngle:180 - taDegrees
								   clockwise:NO];

	// make N copies of the tooth rotated about the centre

	NSBezierPath* path = [NSBezierPath bezierPath];
	NSInteger i;
	NSAffineTransform* tfm = [NSAffineTransform transform];

	[tfm rotateByRadians:toothAngle * -2];
	[path setWindingRule:NSEvenOddWindingRule];
	[path appendBezierPath:tooth];

	for (i = 0; i < teeth - 1; ++i) {
		[tooth transformUsingAffineTransform:tfm];
		[path appendBezierPathRemovingInitialMoveToPoint:tooth];
	}
	[path closePath];

	// inscribe a centre circle

	radius -= toothRadius;

	NSRect cc = NSInsetRect(NSZeroRect, -radius, -radius);
	[path appendBezierPathWithOvalInRect:cc];

	return path;
}

#pragma mark -
#pragma mark - nuts and bolts
+ (NSBezierPath*)bezierPathWithThreadedBarOfLength:(CGFloat)length diameter:(CGFloat)dia threadPitch:(CGFloat)pitch options:(DKShapeOptions)options
{
	NSPoint p;
	NSBezierPath* path = [self bezierPath];
	CGFloat xIncrement = pitch * 0.5;
	CGFloat yIncrement = pitch * sin60;
	CGFloat phase = -1;

	// draw the top side thread

	p.x = 0;
	p.y = (dia * -0.5) + (yIncrement * 0.5);
	[path moveToPoint:p];

	while (p.x < (length - xIncrement)) {
		p.x += xIncrement;
		p.y += (phase * yIncrement);
		[path lineToPoint:p];
		phase *= -1.0;
	}

	// length is rounded up to nearest whole multiple of pitch

	p.y += dia;

	// optionally draw right-hand cap

	if (options & kThreadedBarRightEndCapped)
		[path lineToPoint:p];
	else
		[path moveToPoint:p];

	// draw bottom edge

	while (p.x > xIncrement) {
		p.x -= xIncrement;
		p.y += (phase * yIncrement);
		[path lineToPoint:p];
		phase *= -1.0;
	}

	if (options & kThreadedBarLeftEndCapped)
		[path closePath];

	// if drawing thread lines, calc opposite point and draw the line

	if (options & kThreadedBarThreadLinesDrawn) {
		NSBezierPath* temp = [self bezierPathWithThreadLinesOfLength:length
															diameter:dia
														 threadPitch:pitch];
		[path appendBezierPath:temp];
	}

	return path;
}

+ (NSBezierPath*)bezierPathWithThreadLinesOfLength:(CGFloat)length diameter:(CGFloat)dia threadPitch:(CGFloat)pitch
{
	NSPoint p, opp;
	NSBezierPath* path = [self bezierPath];
	CGFloat xIncrement = pitch * 0.5;
	CGFloat yIncrement = pitch * sin60;
	CGFloat phase = -1;

	p.x = 0;
	p.y = (dia * -0.5) + (yIncrement * 0.5);
	[path moveToPoint:p];

	while (p.x < (length - xIncrement)) {
		p.x += xIncrement;
		p.y += (phase * yIncrement);
		opp.x = p.x - xIncrement;
		opp.y = p.y + dia;

		if (phase < 0)
			opp.y += yIncrement;
		else
			opp.y -= yIncrement;

		[path moveToPoint:p];
		[path lineToPoint:opp];
		phase *= -1.0;
	}

	return path;
}

+ (NSBezierPath*)bezierPathWithHexagonHeadSideViewOfHeight:(CGFloat)height diameter:(CGFloat)dia options:(DKShapeOptions)options
{
	CGFloat fh = dia / sin60;

	NSRect br = NSMakeRect(0, fh * -0.5, height, fh);
	NSBezierPath* path = [self bezierPathWithRect:br];

	// cross lines

	NSPoint a, b;

	a.x = 0;
	a.y = b.y = dia / 4.0;
	b.x = height;

	[path moveToPoint:a];
	[path lineToPoint:b];

	a.y -= dia * 0.5;
	b.y = a.y;

	[path moveToPoint:a];
	[path lineToPoint:b];

	// face curves

	if (options & kHexFastenerFaceCurvesDrawn) {
		// TO DO
	}

	return path;
}

+ (NSBezierPath*)bezierPathWithBoltOfLength:(CGFloat)length
							 threadDiameter:(CGFloat)tdia
								threadPitch:(CGFloat)tpitch
							   headDiameter:(CGFloat)hdia
								 headHeight:(CGFloat)hheight
								shankLength:(CGFloat)shank
									options:(DKShapeOptions)options
{
#pragma unused(options)

	CGFloat threadLength = length - hheight - shank;

	NSBezierPath* thread = [self bezierPathWithThreadedBarOfLength:threadLength
														  diameter:tdia
													   threadPitch:tpitch
														   options:kThreadedBarLeftEndCapped];

	// if shank non-zero, append lines to represent the shank on the right of the thread

	if (shank > 0) {
		// TO DO
	}

	NSBezierPath* head = [self bezierPathWithHexagonHeadSideViewOfHeight:hheight
																diameter:hdia
																 options:kHexFastenerFaceCurvesDrawn];

	// offset the head to the right-hand end of the thread

	NSAffineTransform* tfm = [NSAffineTransform transform];
	[tfm translateXBy:length - hheight
				  yBy:0];
	[head transformUsingAffineTransform:tfm];
	[thread appendBezierPath:head];

	return thread;
}

#pragma mark -
#pragma mark - crop marks

+ (NSBezierPath*)bezierPathWithCropMarksForRect:(NSRect)aRect length:(CGFloat)length extension:(CGFloat)ext
{
	NSBezierPath* path = [NSBezierPath bezierPath];

	[path moveToPoint:NSMakePoint(NSMinX(aRect) - ext, NSMinY(aRect))];
	[path relativeLineToPoint:NSMakePoint(length + ext, 0)];
	[path moveToPoint:NSMakePoint(NSMinX(aRect), NSMinY(aRect) - ext)];
	[path relativeLineToPoint:NSMakePoint(0, length + ext)];

	[path moveToPoint:NSMakePoint(NSMaxX(aRect) + ext, NSMinY(aRect))];
	[path relativeLineToPoint:NSMakePoint(-(length + ext), 0)];
	[path moveToPoint:NSMakePoint(NSMaxX(aRect), NSMinY(aRect) - ext)];
	[path relativeLineToPoint:NSMakePoint(0, length + ext)];

	[path moveToPoint:NSMakePoint(NSMinX(aRect) - ext, NSMaxY(aRect))];
	[path relativeLineToPoint:NSMakePoint(length + ext, 0)];
	[path moveToPoint:NSMakePoint(NSMinX(aRect), NSMaxY(aRect) + ext)];
	[path relativeLineToPoint:NSMakePoint(0, -(length + ext))];

	[path moveToPoint:NSMakePoint(NSMaxX(aRect) + ext, NSMaxY(aRect))];
	[path relativeLineToPoint:NSMakePoint(-(length + ext), 0)];
	[path moveToPoint:NSMakePoint(NSMaxX(aRect), NSMaxY(aRect) + ext)];
	[path relativeLineToPoint:NSMakePoint(0, -(length + ext))];

	return path;
}

+ (NSBezierPath*)bezierPathWithCropMarksForRect:(NSRect)aRect extension:(CGFloat)ext
{
	if (ext == 0.0)
		return [NSBezierPath bezierPathWithRect:aRect];
	else {
		NSBezierPath* path = [NSBezierPath bezierPath];

		[path moveToPoint:NSMakePoint(NSMinX(aRect), NSMinY(aRect) - ext)];
		[path lineToPoint:NSMakePoint(NSMinX(aRect), NSMaxY(aRect) + ext)];

		[path moveToPoint:NSMakePoint(NSMinX(aRect) - ext, NSMinY(aRect))];
		[path lineToPoint:NSMakePoint(NSMaxX(aRect) + ext, NSMinY(aRect))];

		[path moveToPoint:NSMakePoint(NSMaxX(aRect), NSMinY(aRect) - ext)];
		[path lineToPoint:NSMakePoint(NSMaxX(aRect), NSMaxY(aRect) + ext)];

		[path moveToPoint:NSMakePoint(NSMinX(aRect) - ext, NSMaxY(aRect))];
		[path lineToPoint:NSMakePoint(NSMaxX(aRect) + ext, NSMaxY(aRect))];

		return path;
	}
}

@end
