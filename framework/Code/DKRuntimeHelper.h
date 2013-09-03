//
//  DKRuntimeHelper.h
///  DrawKit ©2005-2008 Apptree.net
//
//  Created by graham on 27/03/2008.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
//

#import <Cocoa/Cocoa.h>


@interface DKRuntimeHelper : NSObject

+ (NSArray*)	allClasses;
+ (NSArray*)	allClassesOfKind:(Class) aClass;
+ (NSArray*)	allImmediateSubclassesOf:(Class) aClass;

@end



BOOL	classIsNSObject( const Class aClass );
BOOL	classIsSubclassOfClass( const Class aClass, const Class subclass );
BOOL	classIsImmediateSubclassOfClass( const Class aClass, const Class subclass );

