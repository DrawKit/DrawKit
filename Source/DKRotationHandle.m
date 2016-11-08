/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import "DKRotationHandle.h"

@implementation DKRotationHandle

+ (DKKnobType)type
{
	return kDKRotationKnobType;
}

+ (NSBezierPath*)pathWithSize:(NSSize)size
{
	return [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(0, 0, size.width, size.height)];
}

+ (NSColor*)fillColour
{
	return [NSColor purpleColor];
}

+ (NSColor*)strokeColour
{
	return [NSColor whiteColor];
}

+ (CGFloat)scaleFactor
{
	return 1.1;
}

@end

#pragma mark -

@implementation DKLockedRotationHandle

+ (DKKnobType)type
{
	return kDKRotationKnobType | kDKKnobIsDisabledFlag;
}

@end
