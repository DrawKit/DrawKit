/**
 @author Graham Cox, Apptree.net
 @author Graham Miln, miln.eu
 @author Contributions from the community
 @date 2005-2014
 @copyright This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file.
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
