/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>

@interface NSString (DKAdditions)

- (NSComparisonResult)localisedCaseInsensitiveNumericCompare:(NSString*)anotherString;

- (NSString*)stringByRemovingCharactersInSet:(NSCharacterSet*)charSet options:(NSUInteger)mask;
- (NSString*)stringByRemovingCharactersInSet:(NSCharacterSet*)charSet;
- (NSString*)stringByRemovingCharacter:(unichar)character;
- (NSString*)stringByReplacingCharactersInSet:(NSCharacterSet*)charSet withString:(NSString*)substitute;

- (NSString*)stringByCapitalizingFirstCharacter;
- (NSString*)stringByAbbreviatingWithOptions:(NSUInteger)flags;
- (NSString*)stringByAbbreviatingWordsWithDictionary:(NSDictionary*)abbreviations;

- (NSString*)stringValue;

@end

// abbreviation flags

enum {
	kDKAbbreviationOptionAddPeriods = (1 << 0),
	kDKAbbreviationOptionAmpersand = (1 << 1)
};
