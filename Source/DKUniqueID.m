/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import "DKUniqueID.h"

@implementation DKUniqueID

/**  */
+ (NSString*)uniqueKey
{
	CFUUIDRef uuid = CFUUIDCreate(kCFAllocatorDefault);
	CFStringRef str = CFUUIDCreateString(kCFAllocatorDefault, uuid);
	CFRelease(uuid);

	return CFBridgingRelease(str);
}

@end
