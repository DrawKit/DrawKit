/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2015
 @copyright GNU LGPL3; see LICENSE
*/

#import <Cocoa/Cocoa.h>

@interface DKRuntimeHelper : NSObject

/**  */
+ (NSArray*)allClasses;
+ (NSArray*)allClassesOfKind:(Class)aClass;
+ (NSArray*)allImmediateSubclassesOf:(Class)aClass;

@end

BOOL classIsNSObject(const Class aClass);
BOOL classIsSubclassOfClass(const Class aClass, const Class subclass);
BOOL classIsImmediateSubclassOfClass(const Class aClass, const Class subclass);
