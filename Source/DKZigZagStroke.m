/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import "DKZigZagStroke.h"

#import "NSBezierPath+Geometry.h"
#import "NSObject+GraphicsAttributes.h"

@implementation DKZigZagStroke
#pragma mark As a DKZigZagStroke

/**  */
- (void)setWavelength:(CGFloat)w
{
	NSAssert(w > 0, @"wavelength must be > 0");

	mWavelength = w;
}

@synthesize wavelength = mWavelength;

#pragma mark -
@synthesize amplitude = mAmplitude;

#pragma mark -
@synthesize spread = mSpread;

#pragma mark -
#pragma mark As a GCObservableObject
+ (NSArray*)observableKeyPaths
{
	return [[super observableKeyPaths] arrayByAddingObjectsFromArray:@[@"wavelength", @"amplitude", @"spread"]];
}

- (void)registerActionNames
{
	[super registerActionNames];
	[self setActionName:@"#kind# Stroke Zig-Zag Wavelength"
			 forKeyPath:@"wavelength"];
	[self setActionName:@"#kind# Stroke Zig-Zag Amplitude"
			 forKeyPath:@"amplitude"];
	[self setActionName:@"#kind# Stroke Zig-Zag Spread"
			 forKeyPath:@"spread"];
}

#pragma mark -
#pragma mark As an NSObject
- (instancetype)init
{
	self = [super init];
	if (self != nil) {
		[self setWavelength:10];
		[self setAmplitude:5];
	}
	return self;
}

#pragma mark -
#pragma mark As part of DKRasterizerProtocol
- (NSSize)extraSpaceNeeded
{
	if ([self enabled]) {
		NSSize esp = [super extraSpaceNeeded];

		esp.width += [self amplitude];
		esp.height += [self amplitude];

		return esp;
	} else
		return NSZeroSize;
}

- (void)renderPath:(NSBezierPath*)path
{
	if ([self amplitude] > 0) {
		NSBezierPath* rp = [path bezierPathWithWavelength:[self wavelength]
												amplitude:[self amplitude]
												   spread:[self spread]];
		[super renderPath:rp];
	} else
		[super renderPath:path];
}

#pragma mark -
#pragma mark As part of GraphicAttributtes Protocol

- (void)setValue:(id)val forNumericParameter:(NSInteger)pnum
{
#pragma unused(val, pnum)
	// no longer supported - style scripting is deprecated

	NSLog(@"style scripting is deprecated - please revise this code");
}

#pragma mark -
#pragma mark As part of NSCoding Protocol
- (void)encodeWithCoder:(NSCoder*)coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	[super encodeWithCoder:coder];

	[coder encodeDouble:[self wavelength]
				 forKey:@"wavelength"];
	[coder encodeDouble:[self amplitude]
				 forKey:@"amplitude"];
	[coder encodeDouble:[self spread]
				 forKey:@"spread"];
}

- (instancetype)initWithCoder:(NSCoder*)coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	self = [super initWithCoder:coder];
	if (self != nil) {
		self.wavelength = [coder decodeDoubleForKey:@"wavelength"];
		self.amplitude = [coder decodeDoubleForKey:@"amplitude"];
		self.spread = [coder decodeDoubleForKey:@"spread"];
	}
	return self;
}

#pragma mark -
#pragma mark As part of NSCopying Protocol
- (id)copyWithZone:(NSZone*)zone
{
	DKZigZagStroke* copy = [super copyWithZone:zone];

	copy.wavelength = self.wavelength;
	copy.amplitude = self.amplitude;
	copy.spread = self.spread;

	return copy;
}

@end
