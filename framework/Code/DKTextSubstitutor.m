//
//  DKTextSubstitutor.m
//  GCDrawKit
//
//  Created by graham on 24/04/09.
//  Copyright 2009 Apptree.net. All rights reserved.
//

#import "DKTextSubstitutor.h"
#import "DKDrawableObject+Metadata.h"
#import "NSString+DKAdditions.h"
#import "LogEvent.h"


NSString*		kDKTextSubstitutorNewStringNotification = @"kDKTextSubstitutorNewStringNotification";


#define TS_LAZY_EVALUATION			1



@implementation DKTextSubstitutor


static NSString* sDelimiter = DEFAULT_DELIMITER_STRING;


+ (NSString*)		delimiterString
{
	return sDelimiter;
}



+ (void)			setDelimiterString:(NSString*) delim
{
	[delim retain];
	[sDelimiter release];
	sDelimiter = delim;
}


+ (NSCharacterSet*)	keyBreakingCharacterSet
{
	// returns the characters that will end an embedded key (which always starts with the delimiter string). Note that to permit
	// key paths as keys, the '.' character is NOT included. This means that any dot is considered part of the key, not the surrounding text. As a
	// special case, a final dot is removed from a key and pushed back to the surrounding text, so a single trailing dot does effectively end a key
	// as long as it's followed by another breaking character or is last character on the line.
	
	static NSMutableCharacterSet* cs = nil;
	
	if( cs == nil )
	{
		cs = [[NSMutableCharacterSet characterSetWithCharactersInString:@" ,;:?-()+=*{}[]\"\\<>|!'%/"] retain];
		[cs formUnionWithCharacterSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	}
	
	return cs;
}


#pragma mark -


- (id)					initWithString:(NSString*) aString
{
	NSAttributedString* str = [[NSAttributedString alloc] initWithString:aString];
	self = [self initWithAttributedString:str];
	[str release];
	
	return self;
}


- (id)					initWithAttributedString:(NSAttributedString*) aString
{
	// designated initializer
	
	self = [super init];
	if( self )
		[self setMasterString:aString];
	
	return self;
}


- (void)				setMasterString:(NSAttributedString*) master
{
	if(![master isEqualToAttributedString:[self masterString]])
	{
		NSString* oldString = [[self string] retain];
		
		[master retain];
		[mMasterString release];
		mMasterString = master;

		// for lazy evaluation, do not process the string immediately. Instead this will be done when the substitutor is asked to
		// perform its first substitution. This is only flagged if the actual string content has changed.
		
	#if TS_LAZY_EVALUATION
		if(![oldString isEqualToString:[master string]])
		{
			mNeedsToEvaluate = YES;
			[mKeys removeAllObjects];
		}
	#else
		if( mMasterString )
			[self processMasterString];
		else
			[mKeys removeAllObjects];
	#endif
		
		[oldString release];
		[[NSNotificationCenter defaultCenter] postNotificationName:kDKTextSubstitutorNewStringNotification object:self];
	}
}



- (NSAttributedString*)	masterString
{
	return mMasterString;
}


- (void)				setString:(NSString*) aString withAttributes:(NSDictionary*) attrs
{
	NSAttributedString* str = [[NSAttributedString alloc] initWithString:aString attributes:attrs];
	[self setMasterString:str];
	[str release];
}


- (NSString*)			string
{
	return [[self masterString] string];
}


- (void)				setAttributes:(NSDictionary*) attrs
{
	// sets the attributes for the current string to the given attributes. Note that this does not preserve existing attributes. Text adornments
	// change attributes using the font manager and -setMasterString, rather than calling this, except when setting a style.
	
	NSRange range = NSMakeRange( 0, [[self masterString] length]);
	
	NSMutableAttributedString* str = [[self masterString] mutableCopy];
	[str beginEditing];
	[str setAttributes:attrs range:range];
	[str fixAttributesInRange:range];
	[str endEditing];
	[self setMasterString:str];
	[str release];
}


- (NSDictionary*)		attributes
{
	// this only returns the attributes that apply at index 0. If there are different attributes applied in ranges, this
	// does not reveal them. This leads to a limitation when cutting and pasting text styles, and also when undoing attribute
	// changes.
	
	if([[self masterString] length] > 0 )
		return [[self masterString] attributesAtIndex:0 effectiveRange:NULL];
	else
		return nil;
}



- (void)				processMasterString
{
	// extracts the keys for the master string and stores them in order with their ranges. This speeds up substitution because
	// the find doesn't need to be repeated, only the replacement. This is redone whenever a new master string is set.
	
	NSScanner*			scanner = [NSScanner scannerWithString:[self string]];
	NSString*			key;
	NSString*			delimiter = [[self class] delimiterString];
	int					delimiterLength = [delimiter length];
	NSRange				range;
	NSCharacterSet*		delimiterSet;
	
	[mKeys removeAllObjects];
	[scanner setCharactersToBeSkipped:nil];
	
	while(![scanner isAtEnd])
	{
		// scan until we hit the '%%' delimiter:
		
		[scanner scanUpToString:delimiter intoString:NULL];
		
		if(![scanner isAtEnd])
		{
			// skip over '%%':
			
			[scanner scanString:delimiter intoString:NULL];
			range.location = [scanner scanLocation] - delimiterLength;
			
			// if the first character of the following string is a quote, we scan until we hit the matching quote - this allows us to
			// quote keys that contain delimiter characters.
			
			unichar firstChar = [[self string] characterAtIndex:[scanner scanLocation]];
			BOOL isQuoted = NO;
			
			if( firstChar == '"')
			{
				delimiterSet = [NSCharacterSet characterSetWithCharactersInString:@"\""];
				[scanner setScanLocation:[scanner scanLocation] + 1];
				isQuoted = YES;
			}
			else	
				delimiterSet = [[self class] keyBreakingCharacterSet];
			
			// scan until we hit an ending delimiter. For unquoted strings this is any character in the delimiter set. For quoted strings
			// it is the closing quote mark:
			
			if([scanner scanUpToCharactersFromSet:delimiterSet intoString:&key])
			{
				// if a reasonable key was found, find its range and store it
				
				if([key length] > 0)
				{
					// if the key ends with a single '.', remove it from the key and leave it with the original text. Otherwise,
					// a . is a legal element within a key.

					NSString* lastCharacter = [key substringFromIndex:[key length] - 1];
					if([lastCharacter isEqualToString:@"."])
					{
						key = [key substringToIndex:[key length] - 1];
						[scanner setScanLocation:[scanner scanLocation] - 1];
					}
					
					range.length = [key length] + delimiterLength;
					
					// for quoted strings, add 2 to cover the pair of quote marks
					
					if( isQuoted )
						range.length += 2;

					// check the stop character. If it's a +, it's treated as invisible. This can be used to 
					// separate a key from following text that must follow without a space or other mark.
					
					if([scanner scanString:@"+" intoString:NULL])
						range.length++;
					
					// store the key and its range
					
					//NSLog(@"saving key: %@", key );
					
					DKTextSubstitutionKey* subsKey = [[DKTextSubstitutionKey alloc] initWithKey:key range:range];
					[mKeys addObject:subsKey];
					[subsKey release];
				}
			}
		}
	}
	
	mNeedsToEvaluate = NO;
	
	LogEvent_( kReactiveEvent, @"completed processing of string '%@', result = %@", mMasterString, mKeys);
}


- (NSArray*)			allKeys
{
	return [mKeys valueForKey:@"key"];
}



- (NSAttributedString*)	substitutedStringWithObject:(id) anObject
{
	// given an object that implements -metadataObjectForKey, this returns a string which is formed by substituting the metadata values in place of
	// the embedded keys in the master string.
	
	// For lazy evaluation, perform the evaluation now if no keys are currently stored.
	
#if TS_LAZY_EVALUATION
	if([mKeys count] == 0 && [self masterString] != nil && mNeedsToEvaluate )
		[self processMasterString];
#endif
	
	// even after lazy evaluation there may be no substitutions to do - in which case just return the original string
	
	if([mKeys count] == 0 )
		return [self masterString];
	
	// apply keys:
	
	NSMutableAttributedString* newString = [[self masterString] mutableCopy];
	
	NSEnumerator*			iter = [mKeys objectEnumerator];
	DKTextSubstitutionKey*	key;
	id						metaObject;
	NSString*				subString;
	int						rangeAdjustment = 0;
	NSRange					range;
	
	while(( key = [iter nextObject]))
	{
		subString = @"";
		
		if([anObject respondsToSelector:@selector(metadataObjectForKey:)])
		{
			metaObject = [anObject metadataObjectForKey:[key key]];
			
			if( metaObject )
				subString = [key stringByApplyingSubkeysToString:[self metadataStringFromObject:metaObject]];
		}
		
		range = [key range];
		
		// compensate for string length changes:
		
		range.location += rangeAdjustment;
		[newString replaceCharactersInRange:range withString:subString];
		
		// work out the range adjustment needed for the next one
		
		rangeAdjustment += [subString length] - range.length;
	}
	
	return [newString autorelease];
}


- (NSString*)		metadataStringFromObject:(id) object
{
	// given an object returned by metadataObjectForKey, this converts it to a string.
	
	if( object == [NSNull null])
		return @"--";

	if ([object isKindOfClass:[NSString class]])
		return object;
	
	if ([object respondsToSelector:@selector(stringValue)])
		return [object stringValue];
	
	if ([object respondsToSelector:@selector(string)])
		return[object string];
	
	return @"";
}


#pragma mark -
#pragma mark - as a NSObject

- (id)				init
{
	self = [super init];
	if( self )
	{
		mKeys = [[NSMutableArray alloc] init];
	}
	
	return self;
}


- (void)			dealloc
{
	[mMasterString release];
	[mKeys release];
	[super dealloc];
}


- (id)				initWithCoder:(NSCoder*) coder
{
	mKeys = [[NSMutableArray alloc] init];
	
	// deal with earlier format
	
	NSString* mStr = [coder decodeObjectForKey:@"DKOTextSubstitutor_masterString"];
	if( mStr )
		[self setString:mStr withAttributes:nil];
	else
		[self setMasterString:[coder decodeObjectForKey:@"DKOTextSubstitutor_attributedString"]];
	
	return self;
}


- (void)			encodeWithCoder:(NSCoder*) coder
{
	[coder encodeObject:[self masterString] forKey:@"DKOTextSubstitutor_attributedString"];
}


- (NSString*)		description
{
	return [NSString stringWithFormat:@"%@ string = %@\n keys = %@", [super description], mMasterString, mKeys];
}


@end


#pragma mark -


@implementation DKTextSubstitutionKey


+ (NSCharacterSet*)	validSubkeysCharacterSet
{
	static NSCharacterSet* sValidSubkeys = nil;
	
	if( sValidSubkeys == nil )
		sValidSubkeys = [[NSCharacterSet characterSetWithCharactersInString:@"0123456789ULCEASulceas"] retain];
	
	return sValidSubkeys;
}


static NSDictionary* s_abbreviationDict = nil;


+ (NSDictionary*)	abbreviationDictionary
{
	return s_abbreviationDict;
}


+ (void)			setAbbreviationDictionary:(NSDictionary*) abbreviations
{
	[abbreviations retain];
	[s_abbreviationDict release];
	s_abbreviationDict = abbreviations;
}


- (id)				initWithKey:(NSString*) key range:(NSRange) aRange
{
	self = [super init];
	if( self )
	{
		mRange = aRange;
		mKey = [key retain];
		[self setPaddingCharacter:@"0"];
		
		// break down non-property keys into any subkeys they may contain
		
		if(![self isPropertyKeyPath])
		{
			NSArray*  components = [[self key] componentsSeparatedByString:@"."];
			
			if([components count] > 1)
			{
				// we have subKeys, so lets store off the sensible ones and also the modified root key.
				
				NSEnumerator*	iter = [components objectEnumerator];
				NSString*		str;
				NSMutableArray*	sKeys = [NSMutableArray array];
				
				[mKey release];
				mKey = [[iter nextObject] retain];
				
				while(( str = [iter nextObject]))
				{
					if([str length] == 0)
						continue;
					
					if([str length] == 1 )
					{
						// sensible subkeys are all single characters that are present in +validSubkeysCharacterSet
						
						unichar c = [str characterAtIndex:0];
						
						if([[[self class] validSubkeysCharacterSet] characterIsMember:c])
							[sKeys addObject:[str uppercaseString]];
					}
					else if([str characterAtIndex:0] == PADDING_DELIMITER)
					{
						// have some padding information. This is a subkey in the form '#[<pad character>]<pad length>', e.g.
						// '#06' pads to a length of 6 with 0, so 17 -> 000017. default pad char is 0 so may be ommitted,
						// '#8' 17 -> 00000017
						
						int numIndex = 1;
						
						if([str length] > 2 )
						{
							NSString* padString = [str substringWithRange:NSMakeRange(1, 1)];
							if([padString integerValue] == 0)
							{
								[self setPaddingCharacter:padString];
								++numIndex;
							}
						}
						
						NSString* valStr = [str substringFromIndex:numIndex];
						[self setPadding:[valStr integerValue]];
					}
				}
				
				if([sKeys count] > 0 )
					mSubKeys = [sKeys copy];
			}
		}
	}
	
	return self;
}


- (NSString*)		key
{
	return mKey;
}



- (NSRange)			range
{
	return mRange;
}


- (BOOL)			isPropertyKeyPath
{
	// returns whether the stored key represents a property keypath. If its first character is '$', it is.
	
	NSString* firstCharacter = [[self key] substringToIndex:1];
	return [firstCharacter isEqualToString:@"$"];
}


- (NSArray*)		subKeys
{
	return mSubKeys;
}


- (NSString*)		stringByApplyingSubkeysToString:(NSString*) inString
{
	// given a string representing the original data looked up by the key, this further processes the string according to any subkeys. If there are no subkeys the
	// input string is returned unchanged. If there are, the returned string is processed according to the rules of the subkeys and returned. Currently supported subkeys
	// include extracting specific words from the string, which is 1-based (e.g. key.1 returns the first word of the string looked up by <key>, 0 = 10th word) and converting
	// the result to upper, lower or capitalized string (.U, .L, .C). If more than one word index is included, all indicated words are extracted and put together in the order
	// given by the subkeys. So <key>.5.1.2 will extract the 5th, 1st and 2nd words, put them together in that order, then apply any capitalization effect to the result.
	// Also, .E can be used to extract the last word (.End), regardless of how many words there are.
	
	if(( mSubKeys == nil && mPadLength == 0 ) || inString == nil || [inString length] == 0)
		return inString;
	else
	{
		NSMutableString*	result = [NSMutableString string];
		NSArray*			words = [inString componentsSeparatedByString:@" "];
		NSEnumerator*		iter = [mSubKeys objectEnumerator];
		NSString*			sKey;
		NSString*			capFlag = nil;
		unsigned			wordsUsed = 0;
		NSInteger			wordIndex;
		BOOL				abbreviate = NO;
		
		while(( sKey = [iter nextObject]))
		{
			if( [sKey isEqualToString:@"U"] || [sKey isEqualToString:@"L"] || [sKey isEqualToString:@"C"] || [sKey isEqualToString:@"A"])
				capFlag = sKey;
			else if([sKey isEqualToString:@"E"])
			{
				// extract last word
				
				if([words count] > 0 )
				{
					[result appendString:[words lastObject]];
					++wordsUsed;
				}
			}
			else if ([sKey isEqualToString:@"S"])
				abbreviate = YES;
			else
			{
				// subkey indexes are 1-based
				
				wordIndex = [sKey integerValue] - 1;
				
				if( wordIndex >= 0 && wordIndex < (int)[words count])
				{
					[result appendString:[words objectAtIndex:wordIndex]];
					[result appendString:@" "];
					++wordsUsed;
				}
			}
		}
		
		// if no words were added, use the complete original string
		
		if( wordsUsed == 0 )
			result = (id)inString;
		
		// apply any abbreviations (e.g. 'St.' for 'Street', etc)
		
		if ( abbreviate )
			result = (id)[result stringByAbbreviatingWordsWithDictionary:[[self class] abbreviationDictionary]];
		
		// apply capitalization flag:
		
		if( capFlag )
		{
			if([capFlag isEqualToString:@"U"])
				result = (id)[result uppercaseString];
			else if([capFlag isEqualToString:@"L"])
				result = (id)[result lowercaseString];
			else if([capFlag isEqualToString:@"C"])
				result = (id)[result capitalizedString];
			else if([capFlag isEqualToString:@"A"])
				result = (id)[result stringByAbbreviatingWithOptions:kDKAbbreviationOptionAddPeriods | kDKAbbreviationOptionAmpersand];
		}
		
		// apply any prefix padding - default is no padding
		
		if([result length] < [self padding])
		{
			int i, amount = [self padding] - [result length];
			NSMutableString* padString = [NSMutableString string];
			
			for( i = 0; i < amount; ++i )
				[padString appendString:[[self paddingCharacter] substringToIndex:1]];
			
			[padString appendString:result];
			result = padString;
		}
		
		return result;
	}
}


- (void)			setPadding:(unsigned) padLength
{
	// sets the padding length - 0 means no padding. Max length is 20.
	
	mPadLength = MIN( 20U, padLength );
}



- (unsigned)		padding
{
	return mPadLength;
}



- (void)			setPaddingCharacter:(NSString*) padStr
{
	// set as a string, but only the first character is used
	
	[padStr retain];
	[mPadCharacter release];
	mPadCharacter = padStr;
}



- (NSString*)		paddingCharacter
{
	return mPadCharacter;
}




#pragma mark -


- (NSString*)		description
{
	return [NSString stringWithFormat:@"key:%@ range = %@", mKey, NSStringFromRange(mRange)];
}


- (void)			dealloc
{
	[mKey release];
	[mSubKeys release];
	[mPadCharacter release];
	[super dealloc];
}


@end

