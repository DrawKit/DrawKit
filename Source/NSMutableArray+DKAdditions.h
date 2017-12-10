/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>

@interface NSMutableArray<Object> (DKAdditions)

/** adds objects from \c array to the receiver, but only those not already contained by it */
- (void)addUniqueObjectsFromArray:(NSArray<Object>*)array;

@end
