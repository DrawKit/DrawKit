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
	NSUUID *uuid = [NSUUID UUID];
	NSString *str = uuid.UUIDString;

	return str;
}

@end
