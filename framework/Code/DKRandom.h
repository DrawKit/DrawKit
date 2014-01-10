/**
 @author Graham Cox, Apptree.net
 @author Graham Miln, miln.eu
 @author Contributions from the community
 @date 2005-2014
 @copyright This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file.
 */

#import <Cocoa/Cocoa.h>

/** @brief returns a random number between 0 and 1 */
@interface DKRandom : NSObject {
}

+ (CGFloat)randomNumber;
+ (CGFloat)randomPositiveOrNegativeNumber;

@end
