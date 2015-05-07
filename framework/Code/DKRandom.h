/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2015
 @copyright GNU LGPL3; see LICENSE
*/

#import <Cocoa/Cocoa.h>

/** @brief returns a random number between 0 and 1 */
@interface DKRandom : NSObject {
}

+ (CGFloat)randomNumber;
+ (CGFloat)randomPositiveOrNegativeNumber;

@end
