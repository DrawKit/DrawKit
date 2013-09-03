///**********************************************************************************************************************************
///  DKRandom.m
///  DrawKit
///
///  Created by graham on 08/10/2006.
///  Released under the Creative Commons license 2006 Apptree.net.
///
/// 
///  This work is licensed under the Creative Commons Attribution-ShareAlike 2.5 License.
///  To view a copy of this license, visit http://creativecommons.org/licenses/by-sa/2.5/ or send a letter to
///  Creative Commons, 543 Howard Street, 5th Floor, San Francisco, California, 94105, USA.
///
///**********************************************************************************************************************************

#import "DKRandom.h"



@implementation DKRandom
#pragma mark As a DKRandom

+ (float)		randomNumber
{
	// returns a random value between 0 and 1.
	static unsigned long		seed = 0;

	if (seed == 0)
	{
		srandom([[NSDate date] timeIntervalSince1970]);
		seed = 1;
	}
	float randomNum = (float)random();
	randomNum /= (randomNum < 0) ? -2147483647.0f : 2147483647.0f;

	return randomNum;
}


+ (float)		randomPositiveOrNegativeNumber
{
	return [self randomNumber] - 0.5f;
}


@end
