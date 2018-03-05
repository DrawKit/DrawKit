/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Foundation/Foundation.h>

/** @brief Random number generation. */
@interface DKRandom : NSObject

- (instancetype)init UNAVAILABLE_ATTRIBUTE;

/** @brief Returns a random value between \c 0 and <code>1</code>.
 */
+ (CGFloat)randomNumber;
/** @brief Returns a random value between \c -0.5 and <code>0.5</code>.
 */
+ (CGFloat)randomPositiveOrNegativeNumber;

@end
