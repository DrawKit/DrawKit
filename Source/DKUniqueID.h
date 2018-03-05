/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Foundation/Foundation.h>

/** @brief Utility class generates totally unique keys using NSUUID.

 Utility class generates totally unique keys using NSUUID. The keys are guaranteed unique across time, space and different machines.

 One intended client for this is to assign unique registry keys to styles to solve the registry merge problem.
*/
@interface DKUniqueID : NSObject

- (nonnull instancetype)init UNAVAILABLE_ATTRIBUTE;

+ (nonnull NSString*)uniqueKey;

@end
