///**********************************************************************************************************************************
///  DKRandom.h
///  DrawKit ©2005-2008 Apptree.net
///
///  Created by Graham Cox on 08/10/2006.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
///
///**********************************************************************************************************************************

#import <Cocoa/Cocoa.h>


@interface DKRandom : NSObject
{
}


+ (CGFloat)		randomNumber;
+ (CGFloat)		randomPositiveOrNegativeNumber;

@end


/* returns a random number between 0 and 1 */
