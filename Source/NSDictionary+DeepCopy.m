/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import "NSDictionary+DeepCopy.h"

// setting this to 1 is not equivalent to a recursive deep copy if the items in the collection are also collections.

#define DO_IT_THE_EASY_WAY 0

@implementation NSDictionary (DeepCopy)

- (NSDictionary*)deepCopy
{
#if DO_IT_THE_EASY_WAY
	return [[NSDictionary alloc] initWithDictionary:self
										  copyItems:YES];
#else
	NSMutableDictionary* copy;
	NSEnumerator* iter = [self keyEnumerator];
	id key, cobj;

	copy = [[NSMutableDictionary alloc] init];

	while ((key = [iter nextObject])) {
		cobj = [[self objectForKey:key] deepCopy];
		[copy setObject:cobj
				 forKey:key];
	}

	return copy;
#endif
}

@end

#pragma mark -
@implementation NSArray (DeepCopy)

- (NSArray*)deepCopy
{
#if DO_IT_THE_EASY_WAY
	return [[NSArray alloc] initWithArray:self
								copyItems:YES];
#else
	NSMutableArray* copy;
	NSEnumerator* iter = [self objectEnumerator];
	id obj, cobj;

	copy = [[NSMutableArray alloc] init];

	while ((obj = [iter nextObject])) {
		cobj = [obj deepCopy];
		[copy addObject:cobj];
	}

	return copy;
#endif
}

@end

#pragma mark -
@implementation NSObject (DeepCopy)

- (id)deepCopy
{
	return [self copy];
}

@end

#pragma mark -
@implementation NSMutableArray (DeepCopy)

- (NSMutableArray*)deepCopy
{
#if DO_IT_THE_EASY_WAY
	return [[NSMutableArray alloc] initWithArray:self
									   copyItems:YES];
#else
	NSMutableArray* copy;
	NSEnumerator* iter = [self objectEnumerator];
	id obj, cobj;

	copy = [[NSMutableArray alloc] init];

	while ((obj = [iter nextObject])) {
		cobj = [obj deepCopy];
		[copy addObject:cobj];
	}

	return copy;
#endif
}

@end
