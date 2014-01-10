/**
 @author Graham Cox, Apptree.net
 @author Graham Miln, miln.eu
 @author Contributions from the community
 @date 2005-2014
 @copyright This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file.
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
