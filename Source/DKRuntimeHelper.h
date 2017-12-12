/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>

@interface DKRuntimeHelper : NSObject

/**  */
+ (NSArray<Class>*)allClasses;
+ (NSArray<Class>*)allClassesOfKind:(Class)aClass;
+ (NSArray<Class>*)allImmediateSubclassesOf:(Class)aClass;

@end

BOOL classIsNSObject(const Class aClass);
BOOL classIsSubclassOfClass(const Class aClass, const Class subclass);
BOOL classIsImmediateSubclassOfClass(const Class aClass, const Class subclass);
