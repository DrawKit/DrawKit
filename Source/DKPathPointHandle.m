/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import "DKPathPointHandle.h"

@implementation DKOnPathPointHandle

+ (DKKnobType)type
{
	return kDKOnPathKnobType;
}

+ (NSBezierPath*)pathWithSize:(NSSize)size
{
	return [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(0, 0, size.width, size.height)];
}

+ (NSColor*)fillColour
{
	return [NSColor orangeColor];
}

+ (NSColor*)strokeColour
{
	return nil;
}

+ (CGFloat)scaleFactor
{
	return 0.85;
}

@end

#pragma mark -

@implementation DKLockedOnPathPointHandle

+ (DKKnobType)type
{
	return kDKOnPathKnobType | kDKKnobIsDisabledFlag;
}

+ (NSColor*)fillColour
{
	return [NSColor whiteColor];
}

+ (NSColor*)strokeColour
{
	return [NSColor grayColor];
}

@end

#pragma mark -

@implementation DKInactiveOnPathPointHandle

+ (DKKnobType)type
{
	return kDKOnPathKnobType | kDKKnobIsInactiveFlag;
}

+ (NSColor*)fillColour
{
	return [NSColor lightGrayColor];
}

+ (NSColor*)strokeColour
{
	return [NSColor grayColor];
}

@end

#pragma mark -

@implementation DKOffPathPointHandle

+ (DKKnobType)type
{
	return kDKControlPointKnobType;
}

+ (NSColor*)fillColour
{
	return [NSColor cyanColor];
}

@end

#pragma mark -

@implementation DKLockedOffPathPointHandle

+ (DKKnobType)type
{
	return kDKControlPointKnobType | kDKKnobIsDisabledFlag;
}

+ (NSColor*)fillColour
{
	return [NSColor lightGrayColor];
}

@end

#pragma mark -

@implementation DKInactiveOffPathPointHandle

+ (DKKnobType)type
{
	return kDKControlPointKnobType | kDKKnobIsInactiveFlag;
}

+ (NSColor*)fillColour
{
	return [NSColor lightGrayColor];
}

+ (NSColor*)strokeColour
{
	return [NSColor grayColor];
}

@end
