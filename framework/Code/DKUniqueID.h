//
//  DKUniqueID.h
///  DrawKit ©2005-2008 Apptree.net
//
//  Created by graham on 15/03/2008.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
//

#import <Cocoa/Cocoa.h>


@interface DKUniqueID : NSObject

+ (NSString*)			uniqueKey;

@end



/*

Utility class generates totally unique keys using CFUUID. The keys are guaranteed unique across time, space and different machines.

One intended client for this is to assign unique registry keys to styles to solve the registry merge problem.




*/
