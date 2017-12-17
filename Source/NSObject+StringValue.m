/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import "NSObject+StringValue.h"
#import "NSColor+DKAdditions.h"

@implementation NSObject (StringValue)

/**  */
- (NSString*)stringValue
{
	return NSStringFromClass([self class]);
}

- (NSString*)address
{
	return [NSString stringWithFormat:@"%p", self];
}

@end

@implementation NSValue (StringValue)

- (NSString*)stringValue
{
	const char* objcType = [self objCType];
	NSInteger m = -1;

	m = strncmp(objcType, @encode(NSRect), strlen(objcType));

	if (m == 0)
		return NSStringFromRect([self rectValue]);

	m = strncmp(objcType, @encode(NSPoint), strlen(objcType));

	if (m == 0)
		return NSStringFromPoint([self pointValue]);

	m = strncmp(objcType, @encode(NSSize), strlen(objcType));

	if (m == 0)
		return NSStringFromSize([self sizeValue]);

	m = strncmp(objcType, @encode(NSRange), strlen(objcType));

	if (m == 0)
		return NSStringFromRange([self rangeValue]);

	return nil;
}

@end

@implementation NSColor (StringValue)

- (NSString*)stringValue
{
	return [self hexString];
}

@end

@implementation NSArray (StringValue)

- (NSString*)stringValue
{
	NSMutableString* sv = [[NSMutableString alloc] init];
	NSUInteger i;
	id object;

	for (i = 0; i < [self count]; ++i) {
		object = [self objectAtIndex:i];
		[sv appendString:[NSString stringWithFormat:@"%ld: %@\n", (long)i, [object stringValue]]];
	}

	if ([sv length] > 0)
		[sv deleteCharactersInRange:NSMakeRange([sv length] - 1, 1)];

	return sv;
}

@end

@implementation NSDictionary (StringValue)

- (NSString*)stringValue
{
	NSMutableString* sv = [[NSMutableString alloc] init];
	id object;

	for (id key in self) {
		object = [self objectForKey:key];
		[sv appendString:[NSString stringWithFormat:@"%@: %@\n", key, [object stringValue]]];
	}

	if ([sv length] > 0)
		[sv deleteCharactersInRange:NSMakeRange([sv length] - 1, 1)];

	return sv;
}

@end

@implementation NSSet (StringValue)

- (NSString*)stringValue
{
	NSMutableString* sv = [[NSMutableString alloc] init];

	for (id object in self) {
		[sv appendString:[NSString stringWithFormat:@"%@\n", [object stringValue]]];
	}

	if ([sv length] > 0)
		[sv deleteCharactersInRange:NSMakeRange([sv length] - 1, 1)];

	return sv;
}

@end

@implementation NSString (StringValue)

- (NSString*)stringValue
{
	return self;
}

@end

@implementation NSDate (StringValue)

- (NSString*)stringValue
{
	return [self description];
}

@end
