/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

/** @brief implements a deep copy of a dictionary and array.

implements a deep copy of a dictionary and array. The keys are unchanged but each object is copied.

if the dictionary contains another dictionary or an array, it is also deep copied.

to retain the semantics of a normal copy, the object returned is not autoreleased.
*/
@interface NSDictionary<KeyType, ObjectType> (DeepCopy)

- (NSDictionary<KeyType, ObjectType>*)deepCopy NS_RETURNS_RETAINED;

@end

@interface NSArray<ObjectType> (DeepCopy)

- (NSArray<ObjectType>*)deepCopy NS_RETURNS_RETAINED;

@end

@interface NSObject (DeepCopy)

- (id)deepCopy NS_RETURNS_RETAINED;

@end

@interface NSMutableArray<ObjectType> (DeepCopy)

- (NSMutableArray<ObjectType>*)deepCopy NS_RETURNS_RETAINED;

@end

NS_ASSUME_NONNULL_END
