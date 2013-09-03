//
//  DKUnarchivingHelper.h
//  GCDrawKit
//
//  Created by graham on 5/05/09.
//  Copyright 2009 Apptree.net. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface DKUnarchivingHelper : NSObject
{
	NSUInteger	mCount;
	NSString*	mLastClassnameSubstituted;
}

- (void)		reset;
- (NSUInteger)	numberOfObjectsDecoded;

- (NSString*)	lastClassnameSubstituted;

@end

// if a substitution would return NSObject, return this insead, which provides a stub for -initWithCoder rather than throwing
// an exception during dearchiving.

@interface DKNullObject : NSObject <NSCoding>
{
	NSString*	mSubstitutedForClassname;
}

- (void)		setSubstitutionClassname:(NSString*) classname;
- (NSString*)	substitutionClassname;

@end



extern NSString*	kDKUnarchiverProgressStartedNotification;
extern NSString*	kDKUnarchiverProgressContinuedNotification;
extern NSString*	kDKUnarchiverProgressFinishedNotification;

// this helper is used when unarchiving to translate class names from older files to their modern equivalents


