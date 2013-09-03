//
//  DKZigZagFill.m
///  DrawKit ©2005-2008 Apptree.net
//
//  Created by graham on 04/01/2008.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
//

#import "DKZigZagFill.h"

#import "NSBezierPath+Geometry.h"
#import "NSObject+GraphicsAttributes.h"


@implementation DKZigZagFill
#pragma mark As a DKZigZagFill

- (void)		setWavelength:(CGFloat) w
{
	mWavelength = w;
}


- (CGFloat)		wavelength
{
	return mWavelength;
}


#pragma mark -
- (void)		setAmplitude:(CGFloat) amp
{
	mAmplitude = amp;
}


- (CGFloat)		amplitude
{
	return mAmplitude;
}


#pragma mark -
- (void)		setSpread:(CGFloat) sp
{
	mSpread = sp;
}


- (CGFloat)		spread
{
	return mSpread;
}


#pragma mark -
#pragma mark As a GCObservableObject
+ (NSArray*)		observableKeyPaths
{
	return [[super observableKeyPaths] arrayByAddingObjectsFromArray:[NSArray arrayWithObjects:@"wavelength", @"amplitude", @"spread", nil]];
}


- (void)		registerActionNames
{
	[super registerActionNames];
	[self setActionName:@"#kind# Fill Zig-Zag Wavelength" forKeyPath:@"wavelength"];
	[self setActionName:@"#kind# Fill Zig-Zag Amplitude" forKeyPath:@"amplitude"];
	[self setActionName:@"#kind# Fill Zig-Zag Spread" forKeyPath:@"spread"];
}


#pragma mark -
#pragma mark As an NSObject
- (id)			init
{
	self = [super init];
	if (self != nil)
	{
		[self setWavelength:10];
		[self setAmplitude:5];
		NSAssert(mSpread == 0.0, @"Expected init to zero");
	}
	return self;
}


#pragma mark -
#pragma mark As part of DKRasterizerProtocol
- (NSSize)		extraSpaceNeeded
{
	if([self enabled])
	{
		NSSize esp = [super extraSpaceNeeded];
		
		esp.width += [self amplitude];
		esp.height += [self amplitude];
		
		return esp;
	}
	else
		return NSZeroSize;
}


- (NSBezierPath*)	renderingPathForObject:(id<DKRenderable>) object
{
	return [[super renderingPathForObject:object] bezierPathWithWavelength:[self wavelength] amplitude:[self amplitude] spread:[self spread]];
}


- (BOOL)		isFill
{
	return YES;
}


#pragma mark -
#pragma mark As part of GraphicAttributtes Protocol
- (void)		setValue:(id) val forNumericParameter:(NSInteger) pnum
{
	// 3 -> wavelength, 4 -> amplitude, 5 -> spread
	
	switch( pnum )
	{
		default:
			[super setValue:val forNumericParameter:pnum];
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
- (void)		encodeWithCoder:(NSCoder*) coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	[super encodeWithCoder:coder];
	
	[coder encodeDouble:[self wavelength] forKey:@"wavelength"];
	[coder encodeDouble:[self amplitude] forKey:@"amplitude"];
	[coder encodeDouble:[self spread] forKey:@"spread"];

}


- (id)			initWithCoder:(NSCoder*) coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	self = [super initWithCoder:coder];
	if (self != nil)
	{
		[self setWavelength:[coder decodeDoubleForKey:@"wavelength"]];
		[self setAmplitude:[coder decodeDoubleForKey:@"amplitude"]];
		[self setSpread:[coder decodeDoubleForKey:@"spread"]];
	}
	return self;
}


#pragma mark -
#pragma mark As part of NSCopying Protocol
- (id)			copyWithZone:(NSZone*) zone
{
	DKZigZagFill* copy = [super copyWithZone:zone];
	
	[copy setWavelength:[self wavelength]];
	[copy setAmplitude:[self amplitude]];
	[copy setSpread:[self spread]];
	
	return copy;
}


@end
