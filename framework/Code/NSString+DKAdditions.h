//
//  NSString+DKAdditions.h
//  GCDrawKit
//
//  Created by graham on 12/08/2008.
//  Copyright 2008 Apptree.net. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSString (DKAdditions)

- (NSComparisonResult)		localisedCaseInsensitiveNumericCompare:(NSString*) anotherString;

- (NSString*)				stringByRemovingCharactersInSet:(NSCharacterSet*) charSet options:(NSUInteger) mask;
- (NSString*)				stringByRemovingCharactersInSet:(NSCharacterSet*) charSet;
- (NSString*)				stringByRemovingCharacter:(unichar) character;
- (NSString*)				stringByReplacingCharactersInSet:(NSCharacterSet*) charSet withString:(NSString*) substitute;

- (NSString*)				stringByCapitalizingFirstCharacter;
- (NSString*)				stringByAbbreviatingWithOptions:(NSUInteger) flags;
- (NSString*)				stringByAbbreviatingWordsWithDictionary:(NSDictionary*) abbreviations;

- (NSString*)				stringValue;

@end


// abbreviation flags

enum
{
	kDKAbbreviationOptionAddPeriods			= ( 1 << 0 ),
	kDKAbbreviationOptionAmpersand			= ( 1 << 1 )
};

