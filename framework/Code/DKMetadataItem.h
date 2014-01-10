/**
 @author Graham Cox, Apptree.net
 @author Graham Miln, miln.eu
 @author Contributions from the community
 @date 2005-2014
 @copyright This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file.
 */

#import <Cocoa/Cocoa.h>

// data types storable by a DKMetadataItem

typedef enum {
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
} DKMetadataType;

/**
DKMetadataItems are used to store metadata (attribute) values in user info dictionaries attached to various objects such as layers and
 drawables. Using a special wrapper preserves the type information under editing whereas using raw NSValue/NSNumber objects does not.
 
 Values passed to -setValue are always converted to the current type wherever possible. Conversely, using -setType converts the current value
 to that type where possible. A conversion is always attempted, so in some cases a nonsensical conversion will result in data loss, e.g.
 converting a URL to a colour. The -isLossyConversionToType: will return YES for lossy conversions, NO if the conversion will succeed.
 
 <type> and <value> properties are KVO-observable, any other methods call these.
  
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

+ (Class)classForType:(DKMetadataType)type;
+ (NSString*)localizedDisplayNameForType:(DKMetadataType)type;

// convenience constructors

+ (DKMetadataItem*)metadataItemWithString:(NSString*)aString;
+ (DKMetadataItem*)metadataItemWithInteger:(NSInteger)anInteger;
+ (DKMetadataItem*)metadataItemWithReal:(CGFloat)aReal;
+ (DKMetadataItem*)metadataItemWithBoolean:(BOOL)aBool;
+ (DKMetadataItem*)metadataItemWithUnsigned:(NSUInteger)anInteger;
+ (DKMetadataItem*)metadataItemWithAttributedString:(NSAttributedString*)attrString;
+ (DKMetadataItem*)metadataItemWithImage:(NSImage*)image;
+ (DKMetadataItem*)metadataItemWithImageData:(NSData*)imageData;
+ (DKMetadataItem*)metadataItemWithURL:(NSURL*)url;
+ (DKMetadataItem*)metadataItemWithDate:(NSDate*)date;
+ (DKMetadataItem*)metadataItemWithColour:(NSColor*)colour;
+ (DKMetadataItem*)metadataItemWithData:(NSData*)data;
+ (DKMetadataItem*)metadataItemWithSize:(NSSize)size;
+ (DKMetadataItem*)metadataItemWithPoint:(NSPoint)point;
+ (DKMetadataItem*)metadataItemWithRect:(NSRect)rect;
+ (DKMetadataItem*)metadataItemWithObject:(id)value;

+ (DKMetadataItem*)metadataItemWithPasteboard:(NSPasteboard*)pb;

// wholesale conversion

+ (NSDictionary*)dictionaryOfMetadataItemsWithDictionary:(NSDictionary*)aDict;
+ (NSArray*)arrayOfMetadataItemsWithArray:(NSArray*)array;
+ (NSDictionary*)metadataItemsWithPasteboard:(NSPasteboard*)pb;

+ (BOOL)writeMetadataItems:(NSArray*)items forKeys:(NSArray*)keys toPasteboard:(NSPasteboard*)pb;

// initializing various types of metadata item

- (id)initWithType:(DKMetadataType)type;
- (id)initWithString:(NSString*)aString;
- (id)initWithInteger:(NSInteger)anInteger;
- (id)initWithReal:(CGFloat)aReal;
- (id)initWithBoolean:(BOOL)aBool;
- (id)initWithUnsigned:(NSUInteger)anInteger;
- (id)initWithAttributedString:(NSAttributedString*)attrString;
- (id)initWithImage:(NSImage*)image;
- (id)initWithImageData:(NSData*)imageData;
- (id)initWithURL:(NSURL*)url;
- (id)initWithDate:(NSDate*)date;
- (id)initWithColour:(NSColor*)colour;
- (id)initWithData:(NSData*)data;
- (id)initWithSize:(NSSize)size;
- (id)initWithPoint:(NSPoint)point;
- (id)initWithRect:(NSRect)rect;

// set value, converting to current type as necessary

- (void)setValue:(id)value;
- (id)value;

- (void)takeObjectValueFrom:(id)sender;
- (id)objectValue;

// set type, converting current value to the type as necessary. Type never mutates unless deliberately
// changed, unlike NSValue/NSNumber. This strictly preserves the original data type under editing operations.

- (void)setType:(DKMetadataType)type;
- (DKMetadataType)type;
- (NSString*)typeDisplayName;

- (BOOL)isLossyConversionToType:(DKMetadataType)type;
- (DKMetadataItem*)metadataItemWithType:(DKMetadataType)type;

// convenient getters convert to indicated return type as necessary, possibly lossily

- (NSString*)stringValue;
- (NSAttributedString*)attributedStringValue;
- (NSInteger)intValue;
- (CGFloat)floatValue;
- (BOOL)boolValue;
- (NSColor*)colourValue;
- (NSSize)sizeValue;
- (NSPoint)pointValue;
- (NSRect)rectValue;

- (NSData*)data;
- (BOOL)writeToPasteboard:(NSPasteboard*)pb;

@end

extern NSString* DKSingleMetadataItemPBoardType;
extern NSString* DKMultipleMetadataItemsPBoardType;

// objects can optionally implement any of the following to assist with additional conversions:

@interface NSObject (DKMetadataItemConversions)

- (NSURL*)url;
- (NSColor*)colorValue;
- (NSColor*)colourValue;
- (NSString*)hexString;
- (NSData*)imageData;
- (NSPoint)point;

@end
