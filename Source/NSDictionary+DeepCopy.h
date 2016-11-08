/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>

/** @brief implements a deep copy of a dictionary and array.

implements a deep copy of a dictionary and array. The keys are unchanged but each object is copied.

if the dictionary contains another dictionary or an array, it is also deep copied.

to retain the semantics of a normal copy, the object returned is not autoreleased.
*/
@interface NSDictionary (DeepCopy)

- (NSDictionary*)deepCopy;

@end

@interface NSArray (DeepCopy)

- (NSArray*)deepCopy;

@end

@interface NSObject (DeepCopy)

- (id)deepCopy;

@end

@interface NSMutableArray (DeepCopy)

- (NSMutableArray*)deepCopy;

@end
