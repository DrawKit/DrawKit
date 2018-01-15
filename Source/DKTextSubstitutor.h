/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

/** @brief This objects abstracts the text substitution task used by text adornments, et.

This objects abstracts the text substitution task used by text adornments, et. al. It allows strings of the form:
 
 "This is fixed text %%sub1 more fixed text %%sub2 and so on..."
 
 Where %%sub1 and %%sub2 (where the word following %% represents a metadata key) are replaced by the metadata value keyed.
 
 A non-property key can also have further flags, called subKeys. These are . delimited single character attributes which invoke specific behaviours. By default these
 are the digits 0-9 which extract the nth word from the original data, and the flags U, L and C which convert the data to upper, lower and capitalized strings respectively.
*/
@interface DKTextSubstitutor : NSObject <NSCoding> {
	NSAttributedString* mMasterString;
	NSMutableArray* mKeys;
	BOOL mNeedsToEvaluate;
}

@property (class, copy, nullable) NSString *delimiterString;
/** returns the characters that will end an embedded key (which always starts with the delimiter string). Note that to permit
 key paths as keys, the '.' character is \b not included. This means that any dot is considered part of the key, not the surrounding text. As a
 special case, a final dot is removed from a key and pushed back to the surrounding text, so a single trailing dot does effectively end a key
 as long as it's followed by another breaking character or is last character on the line.
 */
@property (class, readonly, copy) NSCharacterSet *keyBreakingCharacterSet;

- (instancetype)init NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithString:(NSString*)aString;
- (instancetype)initWithAttributedString:(NSAttributedString*)aString NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithCoder:(NSCoder*)coder NS_DESIGNATED_INITIALIZER;

@property (nonatomic, strong) NSAttributedString *masterString;

- (void)setString:(NSString*)aString withAttributes:(nullable NSDictionary<NSAttributedStringKey,id>*)attrs;
@property (readonly, copy) NSString *string;

@property (copy, nullable) NSDictionary<NSAttributedStringKey,id> *attributes;

- (void)processMasterString;
- (NSArray<NSString*>*)allKeys;

- (nullable NSAttributedString*)substitutedStringWithObject:(id)anObject;
- (nullable NSString*)metadataStringFromObject:(id)object;

@end

extern NSString* const kDKTextSubstitutorNewStringNotification;

#define DEFAULT_DELIMITER_STRING @"%%"
#define PADDING_DELIMITER '#'

@interface DKTextSubstitutionKey : NSObject {
	NSString* mKey;
	NSRange mRange;
	NSArray<NSString*>* mSubKeys;
	NSUInteger mPadLength;
	NSString* mPadCharacter;
}

@property (class, readonly, retain) NSCharacterSet *validSubkeysCharacterSet;
@property (class, copy, nullable) NSDictionary *abbreviationDictionary;

- (instancetype)init UNAVAILABLE_ATTRIBUTE;
- (instancetype)initWithKey:(NSString*)key range:(NSRange)aRange NS_DESIGNATED_INITIALIZER;

@property (readonly, copy) NSString *key;
@property (readonly) NSRange range;
@property (readonly, getter=isPropertyKeyPath) BOOL propertyKeyPath;
@property (readonly, copy) NSArray<NSString*> *subKeys;
- (NSString*)stringByApplyingSubkeysToString:(NSString*)inString;

@property (nonatomic) NSUInteger padding;
@property (copy) NSString *paddingCharacter;

@end

NS_ASSUME_NONNULL_END
