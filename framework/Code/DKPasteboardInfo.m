//
//  DKPasteboardInfo.m
//  GCDrawKit
//
//  Created by graham on 4/06/09.
//  Copyright 2009 Apptree.net. All rights reserved.
//

#import "DKPasteboardInfo.h"
#import "DKGeometryUtilities.h"
#import "DKLayer.h"
#import "LogEvent.h"

@implementation DKPasteboardInfo


+ (DKPasteboardInfo*)	pasteboardInfoForObjects:(NSArray*) objects
{
	DKPasteboardInfo* info = [[self alloc] initWithObjectsInArray:objects];
	return [info autorelease];
}


+ (DKPasteboardInfo*)	pasteboardInfoWithData:(NSData*) data
{
	NSAssert( data != nil, @"cannot decode from nil data");
	
	id obj = [NSKeyedUnarchiver unarchiveObjectWithData:data];
	
	if([obj isKindOfClass:[self class]])
		return (DKPasteboardInfo*)obj;
	
	return nil;
}


+ (DKPasteboardInfo*)	pasteboardInfoWithPasteboard:(NSPasteboard*) pb
{
	NSData* data = [pb dataForType:kDKDrawableObjectInfoPasteboardType];
	
	if( data )
		return [self pasteboardInfoWithData:data];
	else
		return nil;
}



- (id)					initWithObjectsInArray:(NSArray*) objects
{
	self = [super init];
	if( self )
	{
		mCount = [objects count];
		
		// make a list of all the different classes and their counts.
		
		NSMutableDictionary*	clDict = [NSMutableDictionary dictionary];
		NSEnumerator*			iter = [objects objectEnumerator];
		id						obj;
		NSString*				classname;
		NSNumber*				count;
		NSRect					br = NSZeroRect;
		
		while(( obj = [iter nextObject]))
		{
			br = UnionOfTwoRects( br, [obj bounds]);
			
			// record count for each class
			
			classname = NSStringFromClass([obj class]);
			count = [clDict objectForKey:classname];
			
			if( count == nil )
				count = [NSNumber numberWithInteger:1];
			else
				count = [NSNumber numberWithInteger:[count integerValue] + 1];
			
			[clDict setObject:count forKey:classname];
			
			if( mOriginatingLayerKey == nil )
				mOriginatingLayerKey = [[[obj layer] uniqueKey] retain];
		}
		
		mClassInfo = [clDict copy];
		mBoundingRect = br;
		
		LogEvent_( kInfoEvent, @"pasteboard class info = %@", mClassInfo );
	}
	
	return self;
}



- (NSUInteger)			count
{
	return mCount;
}


- (NSRect)				bounds
{
	return mBoundingRect;
}


- (NSDictionary*)		classInfo
{
	return mClassInfo;
}


- (NSUInteger)			countOfClass:(Class) aClass
{
	return [[[self classInfo] objectForKey:NSStringFromClass(aClass)] integerValue];
}


- (NSString*)			keyOfOriginatingLayer
{
	return mOriginatingLayerKey;
}


- (NSData*)				data
{
	NSData* data = [NSKeyedArchiver archivedDataWithRootObject:self];
	return data;
}


- (BOOL)				writeToPasteboard:(NSPasteboard*) pb
{
	NSAssert( pb != nil, @"pasteboard was nil");
	
	return [pb setData:[self data] forType:kDKDrawableObjectInfoPasteboardType];
}


#pragma mark -

- (id)					initWithCoder:(NSCoder*) coder
{
	mCount = [coder decodeIntegerForKey:@"DKPasteboardInfo_count"];
	mClassInfo = [[coder decodeObjectForKey:@"DKPasteboardInfo_classInfo"] retain];
	mBoundingRect = [coder decodeRectForKey:@"DKPasteboardInfo_boundsRect"];
	mOriginatingLayerKey = [[coder decodeObjectForKey:@"DKPasteboardInfo_originatingLayerKey"] retain];
	return self;
}


- (void)				encodeWithCoder:(NSCoder*) coder
{
	[coder encodeInteger:mCount forKey:@"DKPasteboardInfo_count"];
	[coder encodeObject:mClassInfo forKey:@"DKPasteboardInfo_classInfo"];
	[coder encodeRect:mBoundingRect forKey:@"DKPasteboardInfo_boundsRect"];
	[coder encodeObject:[self keyOfOriginatingLayer] forKey:@"DKPasteboardInfo_originatingLayerKey"];
}


- (void)	dealloc
{
	[mClassInfo release];
	[mOriginatingLayerKey release];
	[super dealloc];
}


@end


