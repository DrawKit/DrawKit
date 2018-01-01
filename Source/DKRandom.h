/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Foundation/Foundation.h>

/** @brief returns a random number between 0 and 1 */
@interface DKRandom : NSObject

+ (CGFloat)randomNumber;
+ (CGFloat)randomPositiveOrNegativeNumber;

@end
