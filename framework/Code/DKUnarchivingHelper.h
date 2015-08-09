/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2015
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>

/** @brief this helper is used when unarchiving to translate class names from older files to their modern equivalents
*/
@interface DKUnarchivingHelper : NSObject {
	NSUInteger mCount;
	NSString* mLastClassnameSubstituted;
}

- (void)reset;
- (NSUInteger)numberOfObjectsDecoded;

- (NSString*)lastClassnameSubstituted;

@end

/** @brief substitution class for avoiding an exception during dearchiving

if a substitution would return NSObject, return this insead, which provides a stub for -initWithCoder rather than throwing an exception during dearchiving.
*/
@interface DKNullObject : NSObject <NSCoding> {
	NSString* mSubstitutedForClassname;
}

- (void)setSubstitutionClassname:(NSString*)classname;
- (NSString*)substitutionClassname;

@end

extern NSString* kDKUnarchiverProgressStartedNotification;
extern NSString* kDKUnarchiverProgressContinuedNotification;
extern NSString* kDKUnarchiverProgressFinishedNotification;
