/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import "DKZigZagFill.h"

#import "NSBezierPath+Geometry.h"
#import "NSObject+GraphicsAttributes.h"

@implementation DKZigZagFill
#pragma mark As a DKZigZagFill

@synthesize wavelength = mWavelength;
@synthesize amplitude = mAmplitude;
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
	[self setActionName:@"#kind# Fill Zig-Zag Wavelength"
			 forKeyPath:@"wavelength"];
	[self setActionName:@"#kind# Fill Zig-Zag Amplitude"
			 forKeyPath:@"amplitude"];
	[self setActionName:@"#kind# Fill Zig-Zag Spread"
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
		NSAssert(mSpread == 0.0, @"Expected init to zero");
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

- (NSBezierPath*)renderingPathForObject:(id<DKRenderable>)object
{
	return [[super renderingPathForObject:object] bezierPathWithWavelength:[self wavelength]
																 amplitude:[self amplitude]
																	spread:[self spread]];
}

- (BOOL)isFill
{
	return YES;
}

#pragma mark -
#pragma mark As part of GraphicAttributtes Protocol
- (void)setValue:(id)val forNumericParameter:(NSInteger)pnum
{
	// 3 -> wavelength, 4 -> amplitude, 5 -> spread

	switch (pnum) {
	default:
		[super setValue:val
			forNumericParameter:pnum];
		break;

	case 3:
		[self setWavelength:[val doubleValue]];
		break;

	case 4:
		[self setAmplitude:[val doubleValue]];
		break;

	case 5:
		[self setSpread:[val doubleValue]];
		break;
	}
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
		[self setWavelength:[coder decodeDoubleForKey:@"wavelength"]];
		[self setAmplitude:[coder decodeDoubleForKey:@"amplitude"]];
		[self setSpread:[coder decodeDoubleForKey:@"spread"]];
	}
	return self;
}

#pragma mark -
#pragma mark As part of NSCopying Protocol
- (id)copyWithZone:(NSZone*)zone
{
	DKZigZagFill* copy = [super copyWithZone:zone];

	[copy setWavelength:[self wavelength]];
	[copy setAmplitude:[self amplitude]];
	[copy setSpread:[self spread]];

	return copy;
}

@end
