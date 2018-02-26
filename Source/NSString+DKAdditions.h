/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

//! abbreviation flags
typedef NS_OPTIONS(NSUInteger, DKAbbreviationOption) {
	kDKAbbreviationOptionAddPeriods = (1 << 0),
	kDKAbbreviationOptionAmpersand = (1 << 1)
};

@interface NSString (DKAdditions)

- (NSComparisonResult)localisedCaseInsensitiveNumericCompare:(NSString*)anotherString;

/** @brief Remove all characters from the specified set
 */
- (NSString*)stringByRemovingCharactersInSet:(NSCharacterSet*)charSet options:(NSStringCompareOptions)mask;

/** @brief Remove all characters from the specified set
 */
- (NSString*)stringByRemovingCharactersInSet:(NSCharacterSet*)charSet;

- (NSString*)stringByRemovingCharacter:(unichar)character;

/** @brief Characters in \c charSet are replaced by <code>substitute</code>. The process is non-recursive, so if \c substitute contains characters from
 <code>charSet</code>, they will remain there.
 */
- (NSString*)stringByReplacingCharactersInSet:(NSCharacterSet*)charSet withString:(NSString*)substitute;

/** @brief Returns a copy of the receiver with just the first character capitalized, ignoring all others. Thus, the rest of the string isn't necessarily forced to
 lowercase.
 */
@property (readonly, copy) NSString* stringByCapitalizingFirstCharacter;

/** @brief Returns a string consisting of the first letter of each word in the receiver, optionally separated by dots and optionally replacing 'and' with '&'.
 */
- (NSString*)stringByAbbreviatingWithOptions:(DKAbbreviationOption)flags;

/** @brief Breaks a string into words. If any words are keys in the dictionary, the word is substituted by its value. Keys are case insensitive (dictionary should have lower case
 keys) and words are substituted with the verbatim value. If \c dictionary is <code>nil</code>, \c self is returned.
 */
- (NSString*)stringByAbbreviatingWordsWithDictionary:(nullable NSDictionary<NSString*, NSString*>*)abbreviations;

@end

NS_ASSUME_NONNULL_END
