///**********************************************************************************************************************************
///  DKRandom.m
///  DrawKit ©2005-2008 Apptree.net
///
///  Created by graham on 08/10/2006.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
///
///**********************************************************************************************************************************

#import "DKRandom.h"



@implementation DKRandom
#pragma mark As a DKRandom

+ (CGFloat)		randomNumber
{
	// returns a random value between 0 and 1.

	static unsigned long		seed = 0;

	if (seed == 0)
	{
		srandom([[NSDate date] timeIntervalSince1970]);
		seed = 1;
	}
	CGFloat randomNum = (CGFloat)random();
	randomNum /= (randomNum < 0) ? -2147483647.0f : 2147483647.0f;

	return randomNum;
}


+ (CGFloat)		randomPositiveOrNegativeNumber
{
	return [self randomNumber] - 0.5;
}


@end
