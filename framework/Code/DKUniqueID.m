/**
 @author Graham Cox, Apptree.net
 @author Graham Miln, miln.eu
 @author Contributions from the community
 @date 2005-2014
 @copyright This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file.
 */

#import "DKUniqueID.h"

@implementation DKUniqueID

/**  */
+ (NSString*)uniqueKey
{
    CFUUIDRef uuid = CFUUIDCreate(kCFAllocatorDefault);
    CFStringRef str = CFUUIDCreateString(kCFAllocatorDefault, uuid);
    CFRelease(uuid);

    return [(NSString*)str autorelease];
}

@end
