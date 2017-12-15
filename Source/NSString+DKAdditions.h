/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Foundation/Foundation.h>

//! abbreviation flags
typedef NS_ENUM(NSUInteger, DKAbbreviationOption) {
	kDKAbbreviationOptionAddPeriods = (1 << 0),
	kDKAbbreviationOptionAmpersand = (1 << 1)
};

@interface NSString (DKAdditions)

- (NSComparisonResult)localisedCaseInsensitiveNumericCompare:(NSString*)anotherString;

- (NSString*)stringByRemovingCharactersInSet:(NSCharacterSet*)charSet options:(NSStringCompareOptions)mask;
- (NSString*)stringByRemovingCharactersInSet:(NSCharacterSet*)charSet;
- (NSString*)stringByRemovingCharacter:(unichar)character;
- (NSString*)stringByReplacingCharactersInSet:(NSCharacterSet*)charSet withString:(NSString*)substitute;

@property (readonly, copy) NSString *stringByCapitalizingFirstCharacter;
- (NSString*)stringByAbbreviatingWithOptions:(DKAbbreviationOption)flags;
- (NSString*)stringByAbbreviatingWordsWithDictionary:(NSDictionary*)abbreviations;

@end

