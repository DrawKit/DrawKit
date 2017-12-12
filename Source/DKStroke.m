/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import "DKStroke.h"
#import "DKStyle.h"
#import "DKStrokeDash.h"
#import "NSBezierPath+Geometry.h"
#import "NSShadow+Scaling.h"
#import "DKDrawableObject.h"
#import "DKDrawing.h"

@implementation DKStroke
#pragma mark As a DKStroke
+ (DKStroke*)defaultStroke
{
	return [[[self alloc] init] autorelease];
}

+ (DKStroke*)strokeWithWidth:(CGFloat)width colour:(NSColor*)colour
{
	DKStroke* stroke = [[self alloc] init];

	stroke.width = width;
	stroke.colour = colour;

	return [stroke autorelease];
}

#pragma mark -
- (instancetype)initWithWidth:(CGFloat)width colour:(NSColor*)colour
{
	self = [super init];
	if (self != nil) {
		[self setColour:colour];
		[self setLineCapStyle:NSButtLineCapStyle];
		[self setLineJoinStyle:NSRoundLineJoinStyle];
		[self setWidth:width];
		[self setMiterLimit:10.0];

		m_trimLength = 0.0;

		if (m_colour == nil) {
			[self autorelease];
			self = nil;
		}
	}
	return self;
}

#pragma mark -
@synthesize colour=m_colour;

#pragma mark -
@synthesize width=m_width;

- (void)scaleWidthBy:(CGFloat)scale
{
	// n.b. important that this doesn't call setWidth: which triggers KVO messages - this must do its thing stealthily.

	m_width = [self width] * scale;
}

- (CGFloat)allowance
{
	CGFloat allow = ([self width] * 0.5) + fabs([self lateralOffset]);

	// factor in miter limit if that's the join style. Note that miter limits can be extremely generous, and cause the bounds
	// to blow out quite substantially.

	if ([self lineJoinStyle] == NSMiterLineJoinStyle) {
		CGFloat m = ([self miterLimit] * [self width] * 0.5);
		CGFloat om = ([self miterLimit] * fabs([self lateralOffset]));

		if (m > allow)
			allow = m;

		if (om > allow)
			allow = om;
	}

	// factor in shadow, if any

	if ([self shadow]) {
		CGFloat es = [[self shadow] extraSpace];

		if (es > allow)
			allow = es;
	}

	return allow;
}

#pragma mark -
@synthesize dash=m_dash;

- (void)setAutoDash
{
	// sets a simple on/off dash in proportion to the current width

	DKStrokeDash* dash = [[DKStrokeDash alloc] init];
	CGFloat dp[2];

	dp[0] = dp[1] = [self width] * 3.0;
	[dash setDashPattern:dp
				   count:2];

	[self setDash:dash];
	[dash release];
}

#pragma mark -
@synthesize lateralOffset=mLateralOffset;

#pragma mark -
@synthesize shadow=m_shadow;

#pragma mark -
- (void)strokeRect:(NSRect)rect
{
	[self renderPath:[NSBezierPath bezierPathWithRect:rect]];
}

- (void)applyAttributesToPath:(NSBezierPath*)path
{
	// applies the stroke's width, cap, join, mitre limit and dash to the path

	[path setLineWidth:[self width]];
	[path setLineCapStyle:[self lineCapStyle]];
	[path setLineJoinStyle:[self lineJoinStyle]];
	[path setMiterLimit:[self miterLimit]];

	if ([self dash])
		[[self dash] applyToPath:path];
	else
		[path setLineDash:NULL
					count:0
					phase:0.0];
}

#pragma mark -
@synthesize lineCapStyle=m_cap;
@synthesize lineJoinStyle=m_join;
@synthesize miterLimit=m_mitreLimit;

#pragma mark -
- (void)setTrimLength:(CGFloat)tl
{
	// trim length is an amount to remove from both ends of the stroked path before stroking it (useful mainly for open paths)
	// note that the value cannot be negative.

	NSAssert(tl >= 0.0, @"trim length must be zero or positive");
	m_trimLength = tl;
}

@synthesize trimLength=m_trimLength;

- (NSSize)extraSpaceNeededIgnoringMitreLimit
{
	NSLineJoinStyle savedJS = m_join;
	m_join = NSRoundLineJoinStyle;

	NSSize es = [self extraSpaceNeeded];
	m_join = savedJS;

	return es;
}

#pragma mark -
#pragma mark As a DKRasterizer
- (BOOL)isValid
{
	return ([self colour] != nil);
}

#pragma mark -
#pragma mark As a GCObservableObject
+ (NSArray*)observableKeyPaths
{
	return [[super observableKeyPaths] arrayByAddingObjectsFromArray:@[@"colour", @"width", @"dash",
																							   @"shadow", @"lineCapStyle", @"lineJoinStyle",
																							   @"lateralOffset", @"trimLength"]];
}

- (void)registerActionNames
{
	[super registerActionNames];
	[self setActionName:@"#kind# Stroke Colour"
			 forKeyPath:@"colour"];
	[self setActionName:@"#kind# Stroke Width"
			 forKeyPath:@"width"];
	[self setActionName:@"#kind# Stroke Dash"
			 forKeyPath:@"dash"];
	[self setActionName:@"#kind# Stroke Shadow"
			 forKeyPath:@"shadow"];
	[self setActionName:@"#kind# Line Cap Style"
			 forKeyPath:@"lineCapStyle"];
	[self setActionName:@"#kind# Line Join Style"
			 forKeyPath:@"lineJoinStyle"];
	[self setActionName:@"#kind# Stroke Offset"
			 forKeyPath:@"lateralOffset"];
	[self setActionName:@"#kind# Trim Length"
			 forKeyPath:@"trimLength"];
}

#pragma mark -
#pragma mark As an NSObject
- (void)dealloc
{
	[m_shadow release];
	[m_dash release];
	[m_colour release];

	[super dealloc];
}

- (instancetype)init
{
	return [self initWithWidth:1.0
						colour:[NSColor blackColor]];
}

#pragma mark -
#pragma mark As part of DKRasterizerProtocol
- (NSSize)extraSpaceNeeded
{
	return NSMakeSize([self allowance], [self allowance]);
}

- (void)render:(id<DKRenderable>)obj
{
	if (![obj conformsToProtocol:@protocol(DKRenderable)] || ![self enabled])
		return;

	BOOL lowQuality = [obj useLowQualityDrawing];

	SAVE_GRAPHICS_CONTEXT //[NSGraphicsContext saveGraphicsState];
		if ([self shadow] != nil && [DKStyle willDrawShadows])
	{
		if (!lowQuality)
			[[self shadow] setAbsolute];
		else
			[[self shadow] drawApproximateShadowWithPath:[obj renderingPath]
											   operation:kDKShadowDrawStroke
											 strokeWidth:[self width]];
	}

	[super render:obj];
	RESTORE_GRAPHICS_CONTEXT //[NSGraphicsContext restoreGraphicsState];
}

- (void)renderPath:(NSBezierPath*)path
{
	// copy path as we are about to change many of its properties

	NSBezierPath* pc;

	if ([self trimLength] > 0.0)
		pc = [path bezierPathByTrimmingFromBothEnds:[self trimLength]];
	else
		pc = [[path copy] autorelease];

	if (mLateralOffset != 0.0) {
		// make a parallel copy of the path
		CGFloat savedFlatness = [NSBezierPath defaultFlatness];
		[NSBezierPath setDefaultFlatness:0.05];
		[pc setLineJoinStyle:[self lineJoinStyle]];
		pc = [pc paralleloidPathWithOffset22:[self lateralOffset]];
		[NSBezierPath setDefaultFlatness:savedFlatness];
	}

	[[self colour] setStroke];
	[self applyAttributesToPath:pc];

	[pc stroke];
}

#pragma mark -
#pragma mark As part of GraphicAttributtes Protocol
- (void)setValue:(id)val forNumericParameter:(NSInteger)pnum
{
	// 0 -> width, 1 -> colour, 2 -> dash, 3 -> shadow

	switch (pnum) {
	case 0:
		[self setWidth:[val doubleValue]];
		break;

	case 1:
		[self setColour:val];
		break;

	case 2:
		[self setDash:val];
		break;

	case 3:
		[self setShadow:val];
		break;

	default:
		break;
	}
}

#pragma mark -
#pragma mark As part of NSCoding Protocol
- (void)encodeWithCoder:(NSCoder*)coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	[super encodeWithCoder:coder];

	[coder encodeObject:[self colour]
				 forKey:@"colour"];
	[coder encodeObject:[self dash]
				 forKey:@"dash"];
	[coder encodeObject:[self shadow]
				 forKey:@"stroke_shadow"];
	[coder encodeInteger:[self lineCapStyle]
				  forKey:@"cap_style"];
	[coder encodeInteger:[self lineJoinStyle]
				  forKey:@"join_style"];
	[coder encodeDouble:[self miterLimit]
				 forKey:@"DKStroke_miterLimit"];

	[coder encodeDouble:[self width]
				 forKey:@"width"];
	[coder encodeDouble:[self lateralOffset]
				 forKey:@"DKStroke_lateralOffset"];
	[coder encodeDouble:[self trimLength]
				 forKey:@"trim_length"];
}

- (instancetype)initWithCoder:(NSCoder*)coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	self = [super initWithCoder:coder];
	if (self != nil) {
		[self setColour:[coder decodeObjectForKey:@"colour"]];

		// copy the dash to clear a possible bug with multiple strokes incorrectly having the same dash object

		DKStrokeDash* dash = [[coder decodeObjectForKey:@"dash"] copy];
		[self setDash:dash];
		[dash release];

		[self setShadow:[coder decodeObjectForKey:@"stroke_shadow"]];
		[self setLineCapStyle:[coder decodeIntegerForKey:@"cap_style"]];
		[self setLineJoinStyle:[coder decodeIntegerForKey:@"join_style"]];

		[self setWidth:[coder decodeDoubleForKey:@"width"]];
		[self setLateralOffset:[coder decodeDoubleForKey:@"DKStroke_lateralOffset"]];
		[self setTrimLength:[coder decodeDoubleForKey:@"trim_length"]];

		CGFloat ml = [coder decodeDoubleForKey:@"DKStroke_miterLimit"];

		if (ml == 0.0)
			ml = 10.0;

		self.miterLimit = ml;
	}
	return self;
}

#pragma mark -
#pragma mark As part of NSCopying Protocol
- (id)copyWithZone:(NSZone*)zone
{
	DKStroke* cp = [super copyWithZone:zone];

	cp.colour = self.colour;
	cp.width = self.width;

	DKStrokeDash* dashCopy = [self.dash copyWithZone:zone];
	cp.dash = dashCopy;
	[dashCopy release];

	NSShadow* shcopy = [self.shadow copyWithZone:zone];
	cp.shadow = shcopy;
	[shcopy release];

	cp.lineCapStyle = self.lineCapStyle;
	cp.lineJoinStyle = self.lineJoinStyle;
	cp.lateralOffset = self.lateralOffset;
	cp.trimLength = self.trimLength;
	cp.miterLimit = self.miterLimit;

	return cp;
}

@end
