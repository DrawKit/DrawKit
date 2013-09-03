//
//  DKUniqueID.m
//  DrawKit
//
//  Created by graham on 15/03/2008.
//  Copyright 2008 Apptree.net. All rights reserved.
//

#import "DKUniqueID.h"


@implementation DKUniqueID


+ (NSString*)			uniqueKey
{
	CFUUIDRef uuid = CFUUIDCreate( kCFAllocatorDefault );
	CFStringRef str = CFUUIDCreateString( kCFAllocatorDefault, uuid );
	CFRelease( uuid );
	
	return [(NSString*)str autorelease];
}


@end
