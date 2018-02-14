/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

/** @brief This object is archived and added to the pasteboard when copying items within DK.

 This object is archived and added to the pasteboard when copying items within DK. It allows information about a paste to be determined without dearchiving the
 actual objects themselves, which is much more efficient for simply managing menus, etc.
 
 Presently this merely supplies the object count and a list of classes present and a count of each, but may be extended later
*/
@interface DKPasteboardInfo : NSObject <NSCoding> {
	NSUInteger mCount;
	NSDictionary<NSString*,NSNumber*>* mClassInfo;
	NSRect mBoundingRect;
	NSString* mOriginatingLayerKey;
}

+ (instancetype)pasteboardInfoForObjects:(NSArray*)objects NS_SWIFT_UNAVAILABLE("");
+ (nullable instancetype)pasteboardInfoWithData:(NSData*)data;
+ (nullable instancetype)pasteboardInfoWithPasteboard:(NSPasteboard*)pb;

- (instancetype)init UNAVAILABLE_ATTRIBUTE;
- (instancetype)initWithObjectsInArray:(NSArray*)objects NS_DESIGNATED_INITIALIZER;
- (nullable instancetype)initWithCoder:(NSCoder*)coder NS_DESIGNATED_INITIALIZER;

@property (readonly) NSUInteger count;
@property (readonly) NSRect bounds;

@property (readonly, copy) NSDictionary<NSString*,NSNumber*> *classInfo;
- (NSUInteger)countOfClass:(Class)aClass;

@property (readonly, copy) NSString *keyOfOriginatingLayer;

- (NSData*)data;
- (BOOL)writeToPasteboard:(NSPasteboard*)pb;

@end

NS_ASSUME_NONNULL_END
