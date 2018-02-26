/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import "NSString+DKAdditions.h"

@implementation NSString (DKAdditions)

- (NSComparisonResult)localisedCaseInsensitiveNumericCompare:(NSString*)anotherString
{
	return [self compare:anotherString
				 options:NSCaseInsensitiveSearch | NSNumericSearch
				   range:NSMakeRange(0, [self length])
				  locale:[NSLocale currentLocale]];
}

- (NSString*)stringByRemovingCharactersInSet:(NSCharacterSet*)charSet options:(NSStringCompareOptions)mask
{
	NSRange range;
	NSMutableString* newString = [NSMutableString string];
	NSUInteger len = [self length];

	mask &= ~NSBackwardsSearch;
	range = NSMakeRange(0, len);
	while (range.length) {
		NSRange substringRange;
		NSUInteger pos = range.location;

		range = [self rangeOfCharacterFromSet:charSet
									  options:mask
										range:range];
		if (range.location == NSNotFound)
			range = NSMakeRange(len, 0);

		substringRange = NSMakeRange(pos, range.location - pos);
		[newString appendString:[self substringWithRange:substringRange]];

		range.location += range.length;
		range.length = len - range.location;
	}

	return newString;
}

- (NSString*)stringByRemovingCharactersInSet:(NSCharacterSet*)charSet
{
	return [self stringByRemovingCharactersInSet:charSet
										 options:0];
}

- (NSString*)stringByRemovingCharacter:(unichar)character
{
	NSCharacterSet* charSet = [NSCharacterSet characterSetWithRange:NSMakeRange(character, 1)];

	return [self stringByRemovingCharactersInSet:charSet];
}

- (NSString*)stringByReplacingCharactersInSet:(NSCharacterSet*)charSet withString:(NSString*)substitute
{
	NSRange range;
	NSMutableString* newString = [NSMutableString string];
	NSUInteger len = [self length];

	range = NSMakeRange(0, len);
	while (range.length) {
		NSRange substringRange;
		NSUInteger pos = range.location;

		range = [self rangeOfCharacterFromSet:charSet
									  options:0
										range:range];
		if (range.location == NSNotFound)
			range = NSMakeRange(len, 0);

		substringRange = NSMakeRange(pos, range.location - pos);
		[newString appendString:[self substringWithRange:substringRange]];

		if (range.length > 0)
			[newString appendString:substitute];

		range.location += range.length;
		range.length = len - range.location;
	}

	return newString;
}

- (NSString*)stringByCapitalizingFirstCharacter
{
	NSMutableString* sc = [self mutableCopy];

	if ([self length] > 0)
		[sc replaceCharactersInRange:NSMakeRange(0, 1)
						  withString:[[self substringToIndex:1] uppercaseString]];

	return sc;
}

- (NSString*)stringByAbbreviatingWithOptions:(DKAbbreviationOption)flags
{
	NSArray* words = [self componentsSeparatedByString:@" "];
	NSMutableString* result = [NSMutableString string];
	unichar chr;
	BOOL addPeriods = flags & kDKAbbreviationOptionAddPeriods;

	for (NSString* word in words) {
		if (flags & kDKAbbreviationOptionAmpersand) {
			if ([[word lowercaseString] isEqualToString:@"and"]) {
				[result appendString:@"&"];
				continue;
			}
		}

		if ([word length] > 0) {
			chr = [word characterAtIndex:0];
			if (addPeriods)
				[result appendFormat:@"%C.", chr];
			else
				[result appendFormat:@"%C", chr];
		}
	}

	return [result uppercaseString];
}

- (NSString*)stringByAbbreviatingWordsWithDictionary:(NSDictionary*)abbreviations
{
	if (abbreviations == nil)
		return self;

	NSArray* words = [self componentsSeparatedByString:@" "];
	NSMutableString* result = [NSMutableString string];
	NSString* newWord;

	for (__strong NSString* word in words) {
		newWord = [abbreviations objectForKey:[word lowercaseString]];

		if (newWord)
			word = newWord;

		[result appendFormat:@"%@ ", word];
	}
	[result deleteCharactersInRange:NSMakeRange([result length] - 1, 1)];

	return result;
}

@end
