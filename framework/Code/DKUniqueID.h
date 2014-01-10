/**
 @author Graham Cox, Apptree.net
 @author Graham Miln, miln.eu
 @author Contributions from the community
 @date 2005-2014
 @copyright This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file.
 */

#import <Cocoa/Cocoa.h>

/** @brief Utility class generates totally unique keys using CFUUID.

Utility class generates totally unique keys using CFUUID. The keys are guaranteed unique across time, space and different machines.

One intended client for this is to assign unique registry keys to styles to solve the registry merge problem.
*/
@interface DKUniqueID : NSObject

/**  */
+ (NSString*)uniqueKey;

@end
