/**
 * @author Graham Cox, Apptree.net
 * @author Graham Miln, miln.eu
 * @author Contributions from the community
 * @date 2005-2013
 * @copyright This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file.
 */

#import "DKRotationHandle.h"

@implementation DKRotationHandle

+ (DKKnobType)			type
{
	return kDKRotationKnobType;
}

+ (NSBezierPath*)		pathWithSize:(NSSize) size
{
	return [NSBezierPath bezierPathWithOvalInRect:NSMakeRect( 0, 0, size.width, size.height )];
}

+ (NSColor*)			fillColour
{
	return [NSColor purpleColor];
}

+ (NSColor*)			strokeColour
{
	return [NSColor whiteColor];
}

+ (CGFloat)				scaleFactor
{
	return 1.1;
}

@end

#pragma mark -

@implementation DKLockedRotationHandle

+ (DKKnobType)			type
{
	return kDKRotationKnobType | kDKKnobIsDisabledFlag;
}

@end

