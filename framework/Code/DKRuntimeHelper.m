//
//  DKRuntimeHelper.m
///  DrawKit ©2005-2008 Apptree.net
//
//  Created by graham on 27/03/2008.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
//

#import "DKRuntimeHelper.h"

#import "LogEvent.h"

#import <objc/objc-runtime.h>


@implementation DKRuntimeHelper


+ (NSArray*)	allClasses
{
	return [self allClassesOfKind:[NSObject class]];
}


+ (NSArray*)	allClassesOfKind:(Class) aClass
{
	// returns a list of all Class objects that are of kind <aClass> or a subclass of it currently registered in the runtime. This caches the
	// result so that the relatively expensive run-through is only performed the first time
	
	static NSMutableDictionary* cache = nil;
	
	if ( cache == nil )
		cache = [[NSMutableDictionary alloc] init];
		
	// is the list already cached?
	
	NSArray* cachedList = [cache objectForKey:NSStringFromClass( aClass )];
	
	if ( cachedList != nil )
		return cachedList;
		
	// if here, list wasn't in the cache, so build it the hard way
	
	NSMutableArray*	list = [NSMutableArray array];

	Class*			buffer = NULL;
	Class			cl;
	
	NSInteger i, numClasses = objc_getClassList( NULL, 0 );
	
	if( numClasses > 0 )
	{
		buffer = malloc( sizeof(Class) * numClasses );
		
		NSAssert( buffer != nil, @"couldn't allocate the buffer");
		
		(void)	objc_getClassList( buffer, numClasses );
		
		// go through the list and carefully check whether the class can respond to isSubclassOfClass: - if so, add it to the list.
		
		for( i = 0; i < numClasses; ++i )
		{
			cl = buffer[i];
			
			if( classIsSubclassOfClass( cl, aClass ))
				[list addObject:cl];
		}
		
		free( buffer );
	}
	
	// save in cache for next time
	
	[cache setObject:list forKey:NSStringFromClass( aClass )];
	
//	LogEvent_(kReactiveEvent, @"classes: %@", list);

	return list;
}


+ (NSArray*)	allImmediateSubclassesOf:(Class) aClass
{
	static NSMutableDictionary* cache = nil;
	
	if ( cache == nil )
		cache = [[NSMutableDictionary alloc] init];
		
	// is the list already cached?
	
	NSArray* cachedList = [cache objectForKey:NSStringFromClass( aClass )];
	
	if ( cachedList != nil )
		return cachedList;
		
	// if here, list wasn't in the cache, so build it the hard way
	
	NSMutableArray*	list = [NSMutableArray array];

	Class*			buffer = NULL;
	Class			cl;
	
	NSInteger i, numClasses = objc_getClassList( NULL, 0 );
	
	if( numClasses > 0 )
	{
		buffer = malloc( sizeof(Class) * numClasses );
		
		NSAssert( buffer != nil, @"couldn't allocate the buffer");
		
		(void)	objc_getClassList( buffer, numClasses );
		
		// go through the list and carefully check whether the class can respond to isSubclassOfClass: - if so, add it to the list.
		
		for( i = 0; i < numClasses; ++i )
		{
			cl = buffer[i];
			
			if( classIsImmediateSubclassOfClass( aClass, cl ))
				[list addObject:cl];
		}
		
		free( buffer );
	}
	
	// save in cache for next time
	
	[cache setObject:list forKey:NSStringFromClass( aClass )];
	
//	LogEvent_(kReactiveEvent, @"classes: %@", list);

	return list;
}



@end



BOOL	classIsNSObject( const Class aClass )
{
	// returns YES if <aClass> is an NSObject derivative, otherwise NO. It does this without invoking any methods on the class being tested.
	
	return classIsSubclassOfClass( aClass, [NSObject class]);
}


BOOL	classIsSubclassOfClass( const Class aClass, const Class subclass )
{
	Class	temp = aClass;
	NSInteger		match = -1;

#if 1 //MAC_OS_X_VERSION_MAX_ALLOWED < MAC_OS_X_VERSION_10_5
	while(( 0 != ( match = strncmp( temp->name, subclass->name, strlen( subclass->name )))) && ( NULL != temp->super_class ))
		temp = temp->super_class;
#else
	while(( 0 != ( match = strncmp( class_getName( temp ), class_getName( subclass ), strlen( class_getName( subclass ))))) && ( NULL != class_getSuperclass( temp )))
		temp = class_getSuperclass( temp );
#endif
	return ( match == 0 );
}


BOOL	classIsImmediateSubclassOfClass( const Class aClass, const Class subclass )
{
	Class	superClass = subclass->super_class;
	
	if( superClass != Nil )
		return ( 0 == strcmp( aClass->name, superClass->name ));
	else
		return NO;
}
