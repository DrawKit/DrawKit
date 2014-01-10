/**
 @author Graham Cox, Apptree.net
 @author Graham Miln, miln.eu
 @author Contributions from the community
 @date 2005-2014
 @copyright This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file.
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
