//
//  NSObject+StringValue.m
//
//  Created by Graham Cox on 03/04/2008.
/**
 * @author Graham Cox, Apptree.net
 * @author Graham Miln, miln.eu
 * @author Contributions from the community
 * @date 2005-2013
 * @copyright This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file.
 */
//

#import "NSObject+StringValue.h"
#import "NSColor+DKAdditions.h"

@implementation NSObject (StringValue)

/** 
 */
- (NSString*)	stringValue
{
	return NSStringFromClass([self class]);
}

- (NSString*)	address
{
#warning 64BIT: Check formatting arguments
	return [NSString stringWithFormat:@"0x%X", self];
}

@end

@implementation NSValue (StringValue)

- (NSString*)	stringValue
{
	const char* objcType = [self objCType];
	NSInteger m = -1;
	
	m = strncmp( objcType, @encode(NSRect), strlen( objcType ));
	
	if ( m == 0 )
		return NSStringFromRect([self rectValue]);
		
	m = strncmp( objcType, @encode(NSPoint), strlen( objcType ));
	
	if ( m == 0 )
		return NSStringFromPoint([self pointValue]);
		
	m = strncmp( objcType, @encode(NSSize), strlen( objcType ));
	
	if ( m == 0 )
		return NSStringFromSize([self sizeValue]);
		
	m = strncmp( objcType, @encode(NSRange), strlen( objcType ));
	
	if ( m == 0 )
		return NSStringFromRange([self rangeValue]);
		
	return nil;
}

@end

@implementation NSColor (StringValue)

- (NSString*)	stringValue
{
	return [self hexString];
}

@end

@implementation NSArray (StringValue)

- (NSString*)	stringValue
{
	NSMutableString*	sv = [[NSMutableString alloc] init];
	NSUInteger			i;
	id					object;
	
	for( i = 0; i < [self count]; ++i )
	{
		object = [self objectAtIndex:i];
#warning 64BIT: Inspect use of long
		[sv appendString:[NSString stringWithFormat:@"%ld: %@\n", (long)i, [object stringValue]]];
	}
	
	if ([sv length] > 0)
		[sv deleteCharactersInRange:NSMakeRange([sv length] - 1, 1)];

	return [sv autorelease];
}

@end

@implementation NSDictionary (StringValue)

- (NSString*)	stringValue
{
	NSMutableString*	sv = [[NSMutableString alloc] init];
	id					object;
	id					key;
	NSEnumerator*		iter = [[self allKeys] objectEnumerator];
	
	while(( key = [iter nextObject]))
	{
		object = [self objectForKey:key];
		[sv appendString:[NSString stringWithFormat:@"%@: %@\n", key, [object stringValue]]];
	}
	
	if ([sv length] > 0)
		[sv deleteCharactersInRange:NSMakeRange([sv length] - 1, 1)];

	return [sv autorelease];
}

@end

@implementation NSSet (StringValue)

- (NSString*)	stringValue
{
	NSMutableString*	sv = [[NSMutableString alloc] init];
	id					object;
	NSEnumerator*		iter = [self objectEnumerator];
	
	while(( object = [iter nextObject]))
	{
		[sv appendString:[NSString stringWithFormat:@"%@\n", [object stringValue]]];
	}
	
	if ([sv length] > 0)
		[sv deleteCharactersInRange:NSMakeRange([sv length] - 1, 1)];

	return [sv autorelease];
}

@end

@implementation NSString (StringValue)

- (NSString*)	stringValue
{
	return self;
}

@end

@implementation NSDate (StringValue)

- (NSString*)	stringValue
{
	return [self description];
}

@end

