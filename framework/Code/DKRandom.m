/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2015
 @copyright GNU LGPL3; see LICENSE
*/

#import "DKRandom.h"

@implementation DKRandom
#pragma mark As a DKRandom

+ (CGFloat)randomNumber
{
// returns a random value between 0 and 1.

	static unsigned long seed = 0;

	if (seed == 0) {
		srandom([[NSDate date] timeIntervalSince1970]);
		seed = 1;
	}
	CGFloat randomNum = (CGFloat)random();
	randomNum /= (randomNum < 0) ? -2147483647.0f : 2147483647.0f;

	return randomNum;
}

+ (CGFloat)randomPositiveOrNegativeNumber
{
	return [self randomNumber] - 0.5;
}

@end
