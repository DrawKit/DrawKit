/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import "DKHatching.h"
#import "DKDrawKitMacros.h"
#import "DKStrokeDash.h"
#import "NSBezierPath+Geometry.h"
#import "DKRandom.h"

@interface DKHatching (Private)

- (void)invalidateRoughnessCache;

@end

@implementation DKHatching
#pragma mark As a DKHatching

/** @brief Return the default hatching

 Be sure to copy the object if you intend to change its parameters.
 @return the default hatching object (shared instance). The default is black 45 degree lines spaced 8 points
 apart with a width of 0.25 points.
 */
+ (DKHatching*)defaultHatching
{
	static DKHatching* sDefaulthatch = nil;

	if (sDefaulthatch == nil)
		sDefaulthatch = [[DKHatching alloc] init];

	return sDefaulthatch;
}

/** @brief Return a hatching with e basic parameters given

 The colour is set to black
 @param w the line width of the lines
 @param spacing the line spacing
 @param angle the overall angle in radians
 @return a hatching instance
 */
+ (DKHatching*)hatchingWithLineWidth:(CGFloat)w spacing:(CGFloat)spacing angle:(CGFloat)angle
{
	DKHatching* hatch = [[self defaultHatching] copy];

	[hatch setWidth:w];
	[hatch setSpacing:spacing];
	[hatch setAngle:angle];

	return hatch;
}

/** @brief Return a hatching which implements a dot pattern

 The colour is set to black. The dot pattern is created using a dashed line at 45 degrees where
 the line and dash spacing is set to the dot pitch. The line width is the dot diameter and the
 rounded cap style is used. This is an efficient way to implement a dot pattern of a given density.
 @param pitch the spacing between the dots
 @param diameter the dot diameter
 @return a hatching instance having the given dot pattern
 */
+ (DKHatching*)hatchingWithDotPitch:(CGFloat)pitch diameter:(CGFloat)diameter
{
	DKHatching* hatch = [self hatchingWithLineWidth:diameter
											spacing:pitch
											  angle:M_PI_4];

	CGFloat dashPattern[2];

	dashPattern[0] = 0.0;
	dashPattern[1] = pitch;

	DKStrokeDash* dash = [DKStrokeDash dashWithPattern:dashPattern
												 count:2];
	[dash setScalesToLineWidth:NO];
	[hatch setDash:dash];
	[hatch setLineCapStyle:NSRoundLineCapStyle];

	return hatch;
}

/** @brief Return a hatching which implements a dot pattern of given density

 Dots have a diameter of 2.0 points, and are spaced according to density. If density = 1, dots
 touch (spacing = 2.0), 0.5 = dots have a spacing of 4.0, etc. A density of 0 is not allowed.
 @param density a density figure from 0 to 1
 @return a hatching instance having a dot pattern of the given density
 */
+ (DKHatching*)hatchingWithDotDensity:(CGFloat)density
{
	if (density <= 0.0)
		return nil;

	return [self hatchingWithDotPitch:2.0 / density
							 diameter:2.0];
}

#pragma mark -

/** @brief Apply the hatching to the path with an object angle of 0
 @param path the path to fill
 */
- (void)hatchPath:(NSBezierPath*)path
{
	[self hatchPath:path
		objectAngle:0.0];
}

/** @brief Apply the hatching to the path with a given object angle
 @param path the path to fill
 @param oa the additional angle to apply, in radians
 */
- (void)hatchPath:(NSBezierPath*)path objectAngle:(CGFloat)oa
{
	// if the bounds size of <path> is larger than the cached hatch, then we'll need to enlarge the cache, so invalidate
	// it.

	NSRect cr, br = [path bounds];

	if (m_cache) {
		cr = [m_cache bounds];

		if ((br.size.width * 1.5) > cr.size.width || (br.size.height * 1.5) > cr.size.height)
			[self invalidateCache];
	}

	if (m_cache == nil)
		[self calcHatchInRect:br];

	NSAssert(m_cache != nil, @"couldn't craete the hatch cache");

	if (m_cache) {
		cr = [m_cache bounds];

		// now we have a hatch cached, set the clip to the path and draw the hatch. The hatch cache always has its
		// path centred at the origin so we also need to transform the cache to the drawn position

		SAVE_GRAPHICS_CONTEXT //[NSGraphicsContext saveGraphicsState];
			[path addClip];

		// enforce a minimum line width of 0.1 - sizees of zero do not print.

		CGFloat actualLineWidth = [self width];

		if (![NSGraphicsContext currentContextDrawingToScreen]) {
			if (actualLineWidth <= 0.0)
				actualLineWidth = 0.05; // hairline
		}

		[m_cache setLineWidth:actualLineWidth];

		if ([self dash])
			[[self dash] applyToPath:m_cache];
		else
			[m_cache setLineDash:nil
						   count:0
						   phase:0.0];

		[m_cache setLineCapStyle:[self lineCapStyle]];
		[m_cache setLineJoinStyle:[self lineJoinStyle]];

		[[self colour] set];

		NSAffineTransform* xform;

		xform = [NSAffineTransform transform];
		[xform translateXBy:NSMidX(br)
						yBy:NSMidY(br)];
		[xform concat];

		NSBezierPath* hatch;

		// compensate for the object's angle by applying that rotation to the hatch path

		if (oa != 0.0) {
			xform = [NSAffineTransform transform];
			[xform rotateByRadians:oa];
			hatch = [xform transformBezierPath:m_cache];
		} else
			hatch = m_cache;

		if (mRoughenStrokes) {
			NSBezierPath* roughHatch;

			if (mRoughenedCache == nil)
				mRoughenedCache = [m_cache bezierPathWithRoughenedStrokeOutline:[self roughness] * [self width]];

			if (oa != 0.0)
				roughHatch = [xform transformBezierPath:mRoughenedCache];
			else
				roughHatch = mRoughenedCache;

			[roughHatch fill];
		} else
			[hatch stroke];

		RESTORE_GRAPHICS_CONTEXT //[NSGraphicsContext restoreGraphicsState];
	}
}

#pragma mark -

/** @brief Set the angle of the hatching
 @param radians the angle in radians
 */
- (void)setAngle:(CGFloat)radians
{
	if (radians != m_angle) {
		// cache doesn't need rebuilding, just rotating to the new angle.

		if (m_cache) {
			NSAffineTransform* xform = [NSAffineTransform transform];
			[xform rotateByRadians:radians - m_angle];
			[m_cache transformUsingAffineTransform:xform];
			[mRoughenedCache transformUsingAffineTransform:xform];
		}

		m_angle = radians;
	}
}

@synthesize angle=m_angle;

/** @brief Set the angle of the hatching in degrees
 @param degs the angle in degrees 
 */
- (void)setAngleInDegrees:(CGFloat)degs
{
	[self setAngle:DEGREES_TO_RADIANS(degs)];
}

/** @brief The angle of the hatching in degrees
 @return the angle in degrees
 */
- (CGFloat)angleInDegrees
{
	CGFloat angle = RADIANS_TO_DEGREES([self angle]);

	if (angle < 0)
		angle += 360.0;

	return angle;
}

@synthesize angleIsRelativeToObject=m_angleRelativeToObject;

#pragma mark -
- (void)setSpacing:(CGFloat)spacing
{
	NSAssert(spacing > 0, @"spacing value must be > 0");

	if (spacing != m_spacing) {
		m_spacing = MAX([self width], spacing);
		[self invalidateCache];
	}
}

@synthesize spacing=m_spacing;

- (void)setLeadIn:(CGFloat)amount
{
	if (amount != m_leadIn) {
		m_leadIn = amount;
		[self invalidateCache];
	}
}

@synthesize leadIn=m_leadIn;

#pragma mark -
- (void)setWidth:(CGFloat)width
{
	m_lineWidth = width;
	[self invalidateRoughnessCache];
}

@synthesize width=m_lineWidth;

- (void)setLineCapStyle:(NSLineCapStyle)lcs
{
	m_cap = lcs;
	[self invalidateRoughnessCache];
}

@synthesize lineCapStyle=m_cap;

- (void)setLineJoinStyle:(NSLineJoinStyle)ljs
{
	m_join = ljs;
	[self invalidateRoughnessCache];
}

@synthesize lineJoinStyle=m_join;

#pragma mark -
@synthesize colour=m_hatchColour;

#pragma mark -
- (void)setDash:(DKStrokeDash*)dash
{
	m_hatchDash = dash;
	[self invalidateRoughnessCache];
}

@synthesize dash=m_hatchDash;

- (void)setAutoDash
{
	// sets a simple on/off dash in proportion to the current width

	DKStrokeDash* dash = [[DKStrokeDash alloc] init];
	CGFloat dp[2];

	dp[0] = dp[1] = [self width] * 3.0;
	[dash setDashPattern:dp
				   count:2];

	[self setDash:dash];
}

- (void)setRoughness:(CGFloat)amount
{
	mRoughness = LIMIT(amount, 0, 1);
	mRoughenStrokes = amount > 0.0;
	[self invalidateRoughnessCache];
}

@synthesize roughness=mRoughness;

- (void)setWobblyness:(CGFloat)wobble
{
	mWobblyness = LIMIT(wobble, 0, 2);
	[self invalidateCache];
}

@synthesize wobblyness=mWobblyness;

#pragma mark -
- (void)invalidateCache
{
	m_cache = nil;
	[self invalidateRoughnessCache];
}

- (void)calcHatchInRect:(NSRect)rect
{
	// this does the actual work of calculating the hatch. Given the rect, we build a series of lines at the origin in a square
	// based on the largest side of <rect> *~ sqrt(2). Then we transform the cache to the current angle. This is much simpler than
	// calculating where to start and end each line.

	if (m_cache == nil) {
		m_cache = [NSBezierPath bezierPath];

		NSRect cr;

		cr.size.width = cr.size.height = (MAX(rect.size.width, rect.size.height) * 1.5);
		cr.origin.x = cr.origin.y = (cr.size.width * -0.5);

		//LogEvent_(kReactiveEvent,  @"hatch origin rect = {%f, %f},{%f, %f}", cr.origin.x, cr.origin.y, cr.size.width, cr.size.height );

		NSInteger i, m;

		m = _CGFloatLround(cr.size.width / [self spacing]) + 1;
		NSPoint a, b;

		a.y = NSMinY(cr);
		b.y = NSMaxY(cr);

		// wobblyness is a randomising factor 0..1 which displaces the end points of the hatch by a random amount
		// relative to the spacing. It is used to give a more naturalistic type of hatch (esp. in conjunction with roughness).

		CGFloat maxWobble = mWobblyness * [self spacing];

		for (i = 0; i < m; i++) {
			a.x = cr.origin.x + m_leadIn + (i * [self spacing]) + ([DKRandom randomPositiveOrNegativeNumber] * maxWobble);
			b.x = cr.origin.x + m_leadIn + (i * [self spacing]) + ([DKRandom randomPositiveOrNegativeNumber] * maxWobble);

			[m_cache moveToPoint:a];
			[m_cache lineToPoint:b];
		}

		// now rotate the cache to the current angle

		NSAffineTransform* rot = [NSAffineTransform transform];
		[rot rotateByRadians:[self angle]];
		[m_cache transformUsingAffineTransform:rot];
	}
}

- (void)invalidateRoughnessCache
{
	mRoughenedCache = nil;
}

#pragma mark -
#pragma mark As a DKRasterizer
- (BOOL)isValid
{
	return YES;
}

#pragma mark -
#pragma mark As a GCObservableObject
+ (NSArray*)observableKeyPaths
{
	return [[super observableKeyPaths] arrayByAddingObjectsFromArray:@[@"colour", @"angle", @"spacing",
																							   @"width", @"dash", @"leadIn",
																							   @"lineCapStyle", @"lineJoinStyle", @"angleIsRelativeToObject", @"roughness", @"wobblyness"]];
}

- (void)registerActionNames
{
	[super registerActionNames];
	[self setActionName:@"#kind# Hatch Colour"
			 forKeyPath:@"colour"];
	[self setActionName:@"#kind# Hatch Angle"
			 forKeyPath:@"angle"];
	[self setActionName:@"#kind# Hatch Spacing"
			 forKeyPath:@"spacing"];
	[self setActionName:@"#kind# Hatch Line Width"
			 forKeyPath:@"width"];
	[self setActionName:@"#kind# Hatch Dash"
			 forKeyPath:@"dash"];
	[self setActionName:@"#kind# Hatch Lead-in"
			 forKeyPath:@"leadIn"];
	[self setActionName:@"#kind# Hatch Line Cap Style"
			 forKeyPath:@"lineCapStyle"];
	[self setActionName:@"#kind# Hatch Line Join Style"
			 forKeyPath:@"lineJoinStyle"];
	[self setActionName:@"#kind# Hatch Is Relative"
			 forKeyPath:@"angleIsRelativeToObject"];
	[self setActionName:@"#kind# Hatch Roughness"
			 forKeyPath:@"roughness"];
	[self setActionName:@"#kind# Hatch Wobble"
			 forKeyPath:@"wobblyness"];
}

#pragma mark -
#pragma mark As an NSObject
- (void)dealloc
{
	[self invalidateCache];

}

- (instancetype)init
{
	self = [super init];
	if (self != nil) {
		[self setColour:[NSColor blackColor]];

		[self setLeadIn:0.0];
		[self setSpacing:8.0];
		[self setAngle:M_PI_4]; //45 degrees
		[self setWidth:0.25];

		[self setLineCapStyle:NSButtLineCapStyle];
		[self setLineJoinStyle:NSBevelLineJoinStyle];
	}
	return self;
}

#pragma mark -
#pragma mark As part of DKRasterizerProtocol
- (void)render:(id<DKRenderable>)obj
{
	if (![obj conformsToProtocol:@protocol(DKRenderable)] || ![self enabled])
		return;

	NSBezierPath* path = [obj renderingPath];

	if (m_angleRelativeToObject)
		[self hatchPath:path
			objectAngle:[obj angle]];
	else
		[self hatchPath:path
			objectAngle:0.0];
}

#pragma mark -
#pragma mark As part of GraphicAttributtes Protocol
- (void)setValue:(id)val forNumericParameter:(NSInteger)pnum
{
	// 0 -> width, 1 -> spacing, 2 -> angle (degrees), 3 -> colour, 4 -> dash

	switch (pnum) {
	default:
		break;

	case 0:
		[self setWidth:[val doubleValue]];
		break;

	case 1:
		[self setSpacing:[val doubleValue]];
		break;

	case 2:
		[self setAngleInDegrees:[val doubleValue]];
		break;

	case 3:
		[self setColour:val];
		break;

	case 4:
		[self setDash:val];
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

	[coder encodeDouble:[self leadIn]
				 forKey:@"lead-in"];
	[coder encodeDouble:[self spacing]
				 forKey:@"spacing"];
	[coder encodeDouble:[self angle]
				 forKey:@"angle"];
	[coder encodeDouble:[self width]
				 forKey:@"linewidth"];

	[coder encodeInteger:[self lineJoinStyle]
				  forKey:@"DKHatching_lineJoinStyle"];
	[coder encodeInteger:[self lineCapStyle]
				  forKey:@"DKHatching_lineCapStyle"];
	[coder encodeBool:m_angleRelativeToObject
			   forKey:@"DKHatching_relAngle"];
	[coder encodeDouble:mRoughness
				 forKey:@"DKHatching_roughness"];
	[coder encodeDouble:mWobblyness
				 forKey:@"DKHatching_wobble"];
}

- (instancetype)initWithCoder:(NSCoder*)coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	self = [super initWithCoder:coder];
	if (self != nil) {
		NSAssert(m_cache == nil, @"Expected init to zero");
		[self setColour:[coder decodeObjectForKey:@"colour"]];
		[self setDash:[coder decodeObjectForKey:@"dash"]];

		[self setLeadIn:[coder decodeDoubleForKey:@"lead-in"]];
		[self setSpacing:[coder decodeDoubleForKey:@"spacing"]];
		[self setAngle:[coder decodeDoubleForKey:@"angle"]];
		[self setWidth:[coder decodeDoubleForKey:@"linewidth"]];

		[self setLineCapStyle:[coder decodeIntegerForKey:@"DKHatching_lineCapStyle"]];
		[self setLineJoinStyle:[coder decodeIntegerForKey:@"DKHatching_lineJoinStyle"]];

		m_angleRelativeToObject = [coder decodeBoolForKey:@"DKHatching_relAngle"];

		[self setRoughness:[coder decodeDoubleForKey:@"DKHatching_roughness"]];
		mWobblyness = [coder decodeDoubleForKey:@"DKHatching_wobble"];
	}
	return self;
}

#pragma mark -
#pragma mark As part of NSCopying Protocol
- (id)copyWithZone:(NSZone*)zone
{
#pragma unused(zone)

	DKHatching* copy = [super copyWithZone:zone];

	[copy setSpacing:[self spacing]];
	[copy setLeadIn:[self leadIn]];
	[copy setAngle:[self angle]];
	[copy setWidth:[self width]];
	[copy setColour:[self colour]];
	[copy setDash:[self dash]];
	[copy setLineCapStyle:[self lineCapStyle]];
	[copy setLineJoinStyle:[self lineJoinStyle]];
	[copy setAngleIsRelativeToObject:[self angleIsRelativeToObject]];
	[copy setRoughness:[self roughness]];
	[copy setWobblyness:[self wobblyness]];

	return copy;
}

@end
