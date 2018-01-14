/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DKRuntimeHelper : NSObject

+ (NSArray<Class>*)allClasses;
+ (NSArray<Class>*)allClassesOfKind:(Class)aClass;
+ (NSArray<Class>*)allImmediateSubclassesOf:(Class)aClass;

@end

/** returns \c YES if \c aClass is an \c NSObject derivative, otherwise <code>NO</code>. It does this without invoking any methods on the class being tested.
 */
BOOL classIsNSObject(const Class aClass);
BOOL classIsSubclassOfClass(const Class aClass, const Class subclass);
BOOL classIsImmediateSubclassOfClass(const Class aClass, const Class subclass);

NS_ASSUME_NONNULL_END
