//
//  DKUniqueID.m
///  DrawKit ©2005-2008 Apptree.net
//
//  Created by graham on 15/03/2008.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
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
