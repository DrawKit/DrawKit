/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

/** @brief this helper is used when unarchiving to translate class names from older files to their modern equivalents
*/
@interface DKUnarchivingHelper : NSObject <NSKeyedUnarchiverDelegate> {
	NSUInteger mCount;
	NSString* mLastClassnameSubstituted;
}

- (void)reset;
@property (readonly) NSUInteger numberOfObjectsDecoded;

@property (readonly, copy, nullable) NSString* lastClassnameSubstituted;

@end

/** @brief substitution class for avoiding an exception during dearchiving

if a substitution would return NSObject, return this insead, which provides a stub for -initWithCoder rather than throwing an exception during dearchiving.
*/
@interface DKNullObject : NSObject <NSCoding> {
	NSString* mSubstitutedForClassname;
}

@property (copy, nullable) NSString* substitutionClassname;

@end

extern NSNotificationName const kDKUnarchiverProgressStartedNotification;
extern NSNotificationName const kDKUnarchiverProgressContinuedNotification;
extern NSNotificationName const kDKUnarchiverProgressFinishedNotification;

NS_ASSUME_NONNULL_END
