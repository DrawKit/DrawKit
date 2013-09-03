///**********************************************************************************************************************************
///  NSDictionary+DeepCopy.h
///  DrawKit ©2005-2008 Apptree.net
///
///  Created by graham on 12/11/2006.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
///
///**********************************************************************************************************************************

#import <Cocoa/Cocoa.h>


@interface NSDictionary (DeepCopy)

- (NSDictionary*)		deepCopy;

@end


@interface NSArray (DeepCopy)

- (NSArray*)			deepCopy;

@end


@interface NSObject (DeepCopy)

- (id)					deepCopy;

@end


@interface NSMutableArray (DeepCopy)

- (NSMutableArray*)		deepCopy;

@end



/*

implements a deep copy of a dictionary and array. The keys are unchanged but each object is copied.

if the dictionary contains another dictionary or an array, it is also deep copied.

to retain the semantics of a normal copy, the object returned is not autoreleased.




*/

