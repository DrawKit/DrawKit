/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import "DKFill.h"
#import "DKStyle.h"
#import "NSShadow+Scaling.h"
#import "DKGradient.h"
#import "NSObject+GraphicsAttributes.h"
#import "DKDrawableObject.h"
#import "DKDrawing.h"

@implementation DKFill
#pragma mark As a DKFill
+ (DKFill*)fillWithColour:(NSColor*)colour
{
	DKFill* fill = [[DKFill alloc] init];
	[fill setColour:colour];

	return fill;
}

+ (DKFill*)fillWithGradient:(DKGradient*)gradient
{
	DKFill* fill = [[DKFill alloc] init];

	[fill setGradient:gradient];
	[fill setColour:nil];
	return fill;
}

+ (DKFill*)fillWithPatternImage:(NSImage*)image
{
	NSColor* pc = [NSColor colorWithPatternImage:image];

	return [self fillWithColour:pc];
}

+ (DKFill*)fillWithPatternImageNamed:(NSString*)path
{
	NSImage* ip = [NSImage imageNamed:path];

	return [self fillWithPatternImage:ip];
}

#pragma mark -
@synthesize colour=m_fillColour;

#pragma mark -
@synthesize shadow=m_shadow;

#pragma mark -
- (void)setGradient:(DKGradient*)grad
{
	if (grad != [self gradient]) {

		m_gradient = grad;
	}
}

@synthesize gradient=m_gradient;

#pragma mark -
@synthesize tracksObjectAngle=m_angleTracksObject;

#pragma mark -
#pragma mark As a DKRasterizer
- (BOOL)isValid
{
	return (m_fillColour != nil || m_gradient != nil);
}

#pragma mark -
#pragma mark As a GCObservableObject
+ (NSArray*)observableKeyPaths
{
	return [[super observableKeyPaths] arrayByAddingObjectsFromArray:@[@"colour", @"shadow", @"tracksObjectAngle", @"gradient"]];
}

- (void)registerActionNames
{
	[super registerActionNames];
	[self setActionName:@"#kind# Fill Colour"
			 forKeyPath:@"colour"];
	[self setActionName:@"#kind# Fill Shadow"
			 forKeyPath:@"shadow"];
	[self setActionName:@"#kind# Gradient"
			 forKeyPath:@"gradient"];
	[self setActionName:@"#kind# Tracks Object Angle"
			 forKeyPath:@"tracksObjectAngle"];
}

#pragma mark -
#pragma mark As an NSObject

- (instancetype)init
{
	self = [super init];
	if (self != nil) {
		[self setColour:[NSColor grayColor]];
		NSAssert(m_shadow == nil, @"Expected init to zero");
		NSAssert(m_gradient == nil, @"Expected init to zero");
		m_angleTracksObject = YES;
	}
	return self;
}

#pragma mark -
#pragma mark As part of DKRasterizerProtocol
- (NSSize)extraSpaceNeeded
{
	NSSize es = NSZeroSize;

	if ([self shadow] != nil && [self enabled]) {
		es.width += ABS([[self shadow] shadowOffset].width);
		es.height += ABS([[self shadow] shadowOffset].height);

		CGFloat br = [[self shadow] shadowBlurRadius];

		es.width += br;
		es.height += br;
	}

	return es;
}

- (void)render:(id<DKRenderable>)obj
{
	if ([self enabled]) {
		if (![obj conformsToProtocol:@protocol(DKRenderable)])
			return;

		NSBezierPath* path = [self renderingPathForObject:obj];

		// if the path is empty, or has zero width or height, do nothing:

		if ([path isEmpty] || [path bounds].size.width <= 0.0 || [path bounds].size.height <= 0.0)
			return;

		[[NSGraphicsContext currentContext] saveGraphicsState];

		// if low quality, don't bother with shadow - shadows really sap performance

		BOOL lowQuality = [obj useLowQualityDrawing];

		if ([self shadow] != nil && [DKStyle willDrawShadows]) {
			if (!lowQuality)
				[[self shadow] setAbsolute];
			else
				[[self shadow] drawApproximateShadowWithPath:path
												   operation:kDKShadowDrawFill
												 strokeWidth:0];
		}

		if ([self colour])
			[[self colour] setFill];
		else
			[[NSColor clearColor] setFill];

		[path fill];

		if ([self gradient]) {
			// TO DO: look for gradient hint metadata in the object and render using that
			// if tracks angle is YES, add the object's angle to the gradient's.

			CGFloat ga = 0.0;

			if ([self tracksObjectAngle]) {
				ga = [[self gradient] angle];
				[[self gradient] setAngleWithoutNotifying:ga + [obj angle]];
			}

			[[self gradient] fillPath:path];

			if ([self tracksObjectAngle])
				[[self gradient] setAngleWithoutNotifying:ga];
		}

		[[NSGraphicsContext currentContext] restoreGraphicsState];
	}
}

- (BOOL)isFill
{
	return YES;
}

#pragma mark -
#pragma mark As part of GraphicAttributtes Protocol
- (void)setValue:(id)val forNumericParameter:(NSInteger)pnum
{
	// 0 -> colour, 1 -> shadow, 2 -> gradient

	if (pnum == 0)
		[self setColour:val];
	else if (pnum == 1)
		[self setShadow:val];
	else if (pnum == 2)
		[self setGradient:val];
}

#pragma mark -
#pragma mark As part of NSCoding Protocol
- (void)encodeWithCoder:(NSCoder*)coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	[super encodeWithCoder:coder];

	[coder encodeObject:[self colour]
				 forKey:@"fill_colour"];
	[coder encodeObject:[self shadow]
				 forKey:@"fill_shadow"];
	[coder encodeObject:[self gradient]
				 forKey:@"fill_gradient"];
	[coder encodeBool:[self tracksObjectAngle]
			   forKey:@"fill_tracks_angle"];
}

- (instancetype)initWithCoder:(NSCoder*)coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	self = [super initWithCoder:coder];
	if (self != nil) {
		[self setColour:[coder decodeObjectForKey:@"fill_colour"]];
		[self setShadow:[coder decodeObjectForKey:@"fill_shadow"]];
		[self setGradient:[coder decodeObjectForKey:@"fill_gradient"]];
		[self setTracksObjectAngle:[coder decodeBoolForKey:@"fill_tracks_angle"]];
	}
	return self;
}

#pragma mark -
#pragma mark As part of NSCopying Protocol
- (id)copyWithZone:(NSZone*)zone
{
	DKFill* copy = [super copyWithZone:zone];

	[copy setColour:[self colour]];

	NSShadow* shcopy = [[self shadow] copyWithZone:zone];
	[copy setShadow:shcopy];

	DKGradient* grcopy = [[self gradient] copyWithZone:zone];
	[copy setGradient:grcopy];

	[copy setTracksObjectAngle:[self tracksObjectAngle]];

	return copy;
}

@end
