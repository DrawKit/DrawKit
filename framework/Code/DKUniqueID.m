/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2015
 @copyright GNU LGPL3; see LICENSE
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
