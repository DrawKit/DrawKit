/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

//! data types storable by a DKMetadataItem
typedef NS_ENUM(NSInteger, DKMetadataType) {
	DKMetadataTypeUnknown = -2,
	DKMetadataMultipleTypesMarker = -1,
	DKMetadataTypeString = 0,
	DKMetadataTypeInteger = 1,
	DKMetadataTypeReal = 2,
	DKMetadataTypeBoolean = 3,
	DKMetadataTypeUnsignedInt = 4,
	DKMetadataTypeAttributedString = 5,
	DKMetadataTypeImage = 6,
	DKMetadataTypeImageData = 7,
	DKMetadataTypeURL = 8,
	DKMetadataTypeDate = 9,
	DKMetadataTypeColour = 10,
	DKMetadataTypeData = 11,
	DKMetadataTypeSize = 12,
	DKMetadataTypePoint = 13,
	DKMetadataTypeRect = 14
};

/**
DKMetadataItems are used to store metadata (attribute) values in user info dictionaries attached to various objects such as layers and
 drawables. Using a special wrapper preserves the type information under editing whereas using raw NSValue/NSNumber objects does not.
 
 Values passed to -setValue are always converted to the current type wherever possible. Conversely, using \c -setType converts the current value
 to that type where possible. A conversion is always attempted, so in some cases a nonsensical conversion will result in data loss, e.g.
 converting a URL to a colour. The \c -isLossyConversionToType: will return \c YES for lossy conversions, \c NO if the conversion will succeed.
 
 \c type and \c value properties are KVO-observable, any other methods call these.
  
 Values are stored in whatever class is appropriate to the type, viz:
 
 Type				Class
 ----------------------------
 String				NSString
 Integer			NSNumber (int)
 Real				NSNumber (double)
 Boolean			NSNumber (BOOL)
 Unsigned			NSNumber (int)
 Attributed String	NSAttributedString
 Image				NSImage
 Image Data			NSData
 Data				NSData
 URL				NSURL
 Date				NSDate
 Size				NSString
 Point				NSString
 Rect				NSString
*/
@interface DKMetadataItem : NSObject <NSCoding, NSCopying> {
@private
	id mValue;
	DKMetadataType mType;
}

+ (nullable Class)classForType:(DKMetadataType)type;
+ (NSString*)nameForType:(DKMetadataType)type;
+ (NSString*)localizedDisplayNameForType:(DKMetadataType)type;

// convenience constructors

+ (instancetype)metadataItemWithString:(NSString*)aString;
+ (instancetype)metadataItemWithInteger:(NSInteger)anInteger;
+ (instancetype)metadataItemWithReal:(CGFloat)aReal;
+ (instancetype)metadataItemWithBoolean:(BOOL)aBool;
+ (instancetype)metadataItemWithUnsigned:(NSUInteger)anInteger;
+ (instancetype)metadataItemWithAttributedString:(NSAttributedString*)attrString;
+ (instancetype)metadataItemWithImage:(NSImage*)image;
+ (instancetype)metadataItemWithImageData:(NSData*)imageData;
+ (instancetype)metadataItemWithURL:(NSURL*)url;
+ (instancetype)metadataItemWithDate:(NSDate*)date;
+ (instancetype)metadataItemWithColour:(NSColor*)colour;
+ (instancetype)metadataItemWithData:(NSData*)data;
+ (instancetype)metadataItemWithSize:(NSSize)size;
+ (instancetype)metadataItemWithPoint:(NSPoint)point;
+ (instancetype)metadataItemWithRect:(NSRect)rect;
+ (nullable instancetype)metadataItemWithObject:(id)value;

+ (nullable DKMetadataItem*)metadataItemWithPasteboard:(NSPasteboard*)pb;

// wholesale conversion

/** @brief Returns a dictionary of <code>DKMetadataItem</code>s built by iterating the input dictionary and wrapping each object using \c metadataItemWithObject:
 
 @discussion This is designed as a way to convert existing dictionaries of attributes wholesale. If the dictionary already contains meta items, the
 result is effectively a copy of those items.
 */
+ (NSDictionary<NSString*, DKMetadataItem*>*)dictionaryOfMetadataItemsWithDictionary:(NSDictionary<NSString*, id>*)aDict;

/** @brief Returns an array of <code>DKMetadataItem</code>s built by iterating the input array and wrapping each object using metadataItemWithObject:
 
@discussion This is designed as a way to convert existing arrays of attributes wholesale.
 */
+ (NSArray<DKMetadataItem*>*)arrayOfMetadataItemsWithArray:(NSArray*)array;
+ (nullable NSDictionary<NSString*, DKMetadataItem*>*)metadataItemsWithPasteboard:(NSPasteboard*)pb;

/** @brief Convenience method for writing a set of items and keys to the pasteboard.
 */
+ (BOOL)writeMetadataItems:(NSArray<DKMetadataItem*>*)items forKeys:(NSArray<NSString*>*)keys toPasteboard:(NSPasteboard*)pb;

// initializing various types of metadata item

- (instancetype)initWithType:(DKMetadataType)type NS_DESIGNATED_INITIALIZER;
- (nullable instancetype)initWithCoder:(NSCoder*)aDecoder NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithString:(NSString*)aString;
- (instancetype)initWithInt:(int)anInteger;
- (instancetype)initWithInteger:(NSInteger)anInteger;
- (instancetype)initWithReal:(CGFloat)aReal;
- (instancetype)initWithBoolean:(BOOL)aBool;
- (instancetype)initWithUnsigned:(NSUInteger)anInteger;
- (instancetype)initWithAttributedString:(NSAttributedString*)attrString;
- (instancetype)initWithImage:(NSImage*)image;
- (instancetype)initWithImageData:(NSData*)imageData;
- (instancetype)initWithURL:(NSURL*)url;
- (instancetype)initWithDate:(NSDate*)date;
- (instancetype)initWithColour:(NSColor*)colour;
- (instancetype)initWithData:(NSData*)data;
- (instancetype)initWithSize:(NSSize)size;
- (instancetype)initWithPoint:(NSPoint)point;
- (instancetype)initWithRect:(NSRect)rect;

// set value, converting to current type as necessary

/** @brief Sets the current value, always converting it to the current type, lossily maybe. */
@property (nonatomic, copy, nullable) id value;

- (void)takeObjectValueFrom:(id)sender;
@property (readonly, strong, nullable) id objectValue;

/** set type, converting current value to the type as necessary. Type never mutates unless deliberately
 changed, unlike NSValue/NSNumber. This strictly preserves the original data type under editing operations.
*/
@property (nonatomic) DKMetadataType type;
@property (readonly, copy) NSString* typeName;
@property (readonly, copy) NSString* typeDisplayName DEPRECATED_MSG_ATTRIBUTE("Use typeName or localizedTypeDisplayName");
@property (readonly, copy) NSString* localizedTypeDisplayName;

/** @brief Predicts if a conversion to \c type will succeed.
 
 @discussion Note that 'lossy' is somewhat vague - some conversions will succeed to an extent
 but will incur some loss. (e.g. attributed string -> string loses the attributes) but will return \c NO from here. This really predicts
 a complete failure to convert, i.e. the conversion is probably nonsensical. You might use this to disable conversions in a UI where
 a complete inability to convert would occur.
 */
- (BOOL)isLossyConversionToType:(DKMetadataType)type;
/** @brief Returns a new metadata item having the same value as the receiver, converted to <code>type</code>.
 
 @discussion If \c type is the current type, \c self is returned.
 Take care to ensure that this doesn't lead to inadvertent sharing of an item.
 */
- (DKMetadataItem*)metadataItemWithType:(DKMetadataType)type;

// convenient getters convert to indicated return type as necessary, possibly lossily

@property (readonly, copy) NSString* stringValue;
@property (readonly, copy) NSAttributedString* attributedStringValue;
@property (readonly) int intValue;
@property (readonly) NSInteger integerValue;
@property (readonly) float floatValue;
@property (readonly) double doubleValue;
@property (readonly) BOOL boolValue;
@property (readonly, copy) NSColor* colourValue;
@property (readonly) NSSize sizeValue;
@property (readonly) NSPoint pointValue;
@property (readonly) NSRect rectValue;

- (NSData*)data;
- (BOOL)writeToPasteboard:(NSPasteboard*)pb;

@end

extern NSPasteboardType DKSingleMetadataItemPBoardType NS_SWIFT_NAME(dkSingleMetadataItem);
extern NSPasteboardType DKMultipleMetadataItemsPBoardType NS_SWIFT_NAME(dkMultipleMetadataItems);

//! objects can optionally implement any of the following to assist with additional conversions:
@protocol DKMetadataItemConversions <NSObject>

@optional

- (NSURL*)url;
- (NSColor*)colorValue;
- (NSColor*)colourValue;
- (NSString*)hexString;
- (NSData*)imageData;
- (NSPoint)point;

@property (readonly, copy) NSString* hexString;
@property (readonly, copy) NSColor* colorValue;
@property (readonly, copy) NSColor* colourValue;
@property (readonly) NSPoint point;

@end

NS_ASSUME_NONNULL_END
