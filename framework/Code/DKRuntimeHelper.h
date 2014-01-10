/**
 @author Graham Cox, Apptree.net
 @author Graham Miln, miln.eu
 @author Contributions from the community
 @date 2005-2014
 @copyright This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file.
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
