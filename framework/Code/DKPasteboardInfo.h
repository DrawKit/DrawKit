//
//  DKPasteboardInfo.h
//  GCDrawKit
//
//  Created by graham on 4/06/09.
//  Copyright 2009 Apptree.net. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface DKPasteboardInfo : NSObject <NSCoding>
{
	NSInteger			mCount;
	NSDictionary*		mClassInfo;
	NSRect				mBoundingRect;
	NSString*			mOriginatingLayerKey;
}

+ (DKPasteboardInfo*)	pasteboardInfoForObjects:(NSArray*) objects;
+ (DKPasteboardInfo*)	pasteboardInfoWithData:(NSData*) data;
+ (DKPasteboardInfo*)	pasteboardInfoWithPasteboard:(NSPasteboard*) pb;

- (id)					initWithObjectsInArray:(NSArray*) objects;
- (NSUInteger)			count;
- (NSRect)				bounds;

- (NSDictionary*)		classInfo;
- (NSUInteger)			countOfClass:(Class) aClass;

- (NSString*)			keyOfOriginatingLayer;

- (NSData*)				data;
- (BOOL)				writeToPasteboard:(NSPasteboard*) pb;

@end


extern NSString*		kDKDrawableObjectInfoPasteboardType;


/*

 This object is archived and added to the pasteboard when copying items within DK. It allows information about a paste to be determined without dearchiving the
 actual objects themselves, which is much more efficient for simply managing menus, etc.
 
 Presently this merely supplies the object count and a list of classes present and a count of each, but may be extended later


*/

