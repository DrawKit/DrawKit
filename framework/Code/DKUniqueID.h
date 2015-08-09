/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2015
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>

/** @brief Utility class generates totally unique keys using CFUUID.

Utility class generates totally unique keys using CFUUID. The keys are guaranteed unique across time, space and different machines.

One intended client for this is to assign unique registry keys to styles to solve the registry merge problem.
*/
@interface DKUniqueID : NSObject

/**  */
+ (NSString*)uniqueKey;

@end
