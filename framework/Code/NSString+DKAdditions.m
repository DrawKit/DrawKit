//
//  NSString+DKAdditions.m
//  GCDrawKit
//
//  Created by graham on 12/08/2008.
//  Copyright 2008 Apptree.net. All rights reserved.
//

#import "NSString+DKAdditions.h"


@implementation NSString (DKAdditions)


- (NSComparisonResult)		localisedCaseInsensitiveNumericCompare:(NSString*) anotherString
{
	return [self compare:anotherString options:NSCaseInsensitiveSearch | NSNumericSearch range:NSMakeRange(0, [self length]) locale:[NSLocale currentLocale]];
}


/* Remove all characters from the specified set */


- (NSString *)				stringByRemovingCharactersInSet:(NSCharacterSet*) charSet options:(NSUInteger) mask
{
	NSRange				range;
	NSMutableString*	newString = [NSMutableString string];
	NSUInteger			len = [self length];
	
	mask &= ~NSBackwardsSearch;
	range = NSMakeRange (0, len);
	while (range.length)
	{
		NSRange substringRange;
		NSUInteger pos = range.location;
		
		range = [self rangeOfCharacterFromSet:charSet options:mask range:range];
		if (range.location == NSNotFound)
			range = NSMakeRange (len, 0);
		
		substringRange = NSMakeRange (pos, range.location - pos);
		[newString appendString:[self substringWithRange:substringRange]];
		
		range.location += range.length;
		range.length = len - range.location;
	}
	
	return newString;
}


- (NSString *)			stringByRemovingCharactersInSet:(NSCharacterSet*) charSet
{
	return [self stringByRemovingCharactersInSet:charSet options:0];
}


- (NSString *)			stringByRemovingCharacter:(unichar) character
{
	NSCharacterSet *charSet = [NSCharacterSet characterSetWithRange:NSMakeRange (character, 1)];
	
	return [self stringByRemovingCharactersInSet:charSet];
}


- (NSString*)			stringByReplacingCharactersInSet:(NSCharacterSet*) charSet withString:(NSString*) substitute
{
	//characters in <charSet> are replaced by <substitute>. The process is non-recursive, so if <substitute> contains characters from
	// <charSet>, they will remain there.

	NSRange				range;
	NSMutableString*	newString = [NSMutableString string];
	NSUInteger			len = [self length];
	
	range = NSMakeRange (0, len);
	while (range.length)
	{
		NSRange substringRange;
		NSUInteger pos = range.location;
		
		range = [self rangeOfCharacterFromSet:charSet options:0 range:range];
		if (range.location == NSNotFound)
			range = NSMakeRange (len, 0);
		
		substringRange = NSMakeRange (pos, range.location - pos);
		[newString appendString:[self substringWithRange:substringRange]];
		
		if( range.length > 0 )
			[newString appendString:substitute];
		
		range.location += range.length;
		range.length = len - range.location;
	}
	
	return newString;
}


- (NSString*)			stringByCapitalizingFirstCharacter
{
	// returns a copy of the receiver with just the first character capitalized, ignoring all others. Thus, the rest of the string isn't necessarily forced to
	// lowercase.
	
	NSMutableString*	sc = [[self mutableCopy] autorelease];
	
	if([self length] > 0 )
		[sc replaceCharactersInRange:NSMakeRange(0,1) withString:[[self substringToIndex:1] uppercaseString]];
	
	return sc;
}


- (NSString*)			stringByAbbreviatingWithOptions:(NSUInteger) flags
{
	// returns a string consisting of the first letter of each word in the receiver, optionally separated by dots and optionally replacing 'and' with '&'. 
	
	NSArray*			words = [self componentsSeparatedByString:@" "];
	NSEnumerator*		iter = [words objectEnumerator];
	NSMutableString*	result = [NSMutableString string];
	NSString*			word;
	unichar				chr;
	BOOL				addPeriods = flags & kDKAbbreviationOptionAddPeriods;
	
	while(( word = [iter nextObject]))
	{
		if( flags & kDKAbbreviationOptionAmpersand )
		{
			if([[word lowercaseString] isEqualToString:@"and"])
			{
				[result appendString:@"&"];
				continue;
			}
		}
		
		if([word length] > 0 )
		{
			chr = [word characterAtIndex:0];
			if( addPeriods )
				[result appendFormat:@"%C.", chr];
			else
				[result appendFormat:@"%C", chr];
		}
	}
	
	return [result uppercaseString];
}


- (NSString*)			stringByAbbreviatingWordsWithDictionary:(NSDictionary*) abbreviations
{
	// breaks a string into words. If any words are keys in the dictionary, the word is substituted by its value. Keys are case insensitive (dictionary should have lower case
	// keys) and words are substituted with the verbatim value. If dictionary is nil, self is returned.
	
	if( abbreviations == nil )
		return self;
	
	NSArray*			words = [self componentsSeparatedByString:@" "];
	NSMutableString*	result = [NSMutableString string];
	NSEnumerator*		iter = [words objectEnumerator];
	NSString*			word;
	NSString*			newWord;
	
	while(( word = [iter nextObject]))
	{
		newWord = [abbreviations objectForKey:[word lowercaseString]];
		
		if( newWord )
			word = newWord;
		
		[result appendFormat:@"%@ ", word];
	}
	[result deleteCharactersInRange:NSMakeRange([result length] - 1, 1)];
	
	return result;
}


- (NSString*)				stringValue
{
	return self;
}

@end
