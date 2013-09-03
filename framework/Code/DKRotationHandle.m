//
//  DKRotationHandle.m
//  GCDrawKit
//
//  Created by graham on 4/09/09.
//  Copyright 2009 Apptree.net. All rights reserved.
//

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


