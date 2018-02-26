/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

/**
The purpose of this class is to allow images to be archived much more efficiently, by archiving the original data that the image was created from rather than any bitmaps or
 other uncompressed forms, and to avoid storing multiple copies of the same image. Each drawing will have an instance of this class and any image using objects such as DKImageShape
 can make use of it.
 
 This only comes into play when archiving, dearchiving or creating images - each object still maintains an NSImage derived from the data stored here.
 
 When images are cut/pasted within the framework, the image key can be used to effect that operation without having to move the actual image data.
*/
@interface DKImageDataManager : NSObject <NSCoding> {
@private
	NSMutableDictionary<NSString*, NSData*>* mRepository;
	NSMutableDictionary<NSString*, NSString*>* mHashList;
	NSMutableDictionary<NSString*, NSNumber*>* mKeyUsage;
}

- (nullable NSData*)imageDataForKey:(NSString*)key;
- (void)setImageData:(NSData*)imageData forKey:(NSString*)key;
- (BOOL)hasImageDataForKey:(NSString*)key;
- (NSString*)generateKey;
- (nullable NSString*)keyForImageData:(NSData*)imageData;
@property (readonly, copy) NSArray<NSString*>* allKeys;
- (void)removeKey:(NSString*)key;

- (nullable NSImage*)makeImageWithData:(NSData*)imageData key:(NSString* _Nullable __autoreleasing* _Nullable)key;
- (nullable NSImage*)makeImageWithPasteboard:(NSPasteboard*)pb key:(NSString* _Nullable __autoreleasing* _Nullable)key;
- (nullable NSImage*)makeImageWithContentsOfURL:(NSURL*)url key:(NSString* _Nullable __autoreleasing* _Nullable)key;
- (nullable NSImage*)makeImageForKey:(NSString*)key;

- (void)setKey:(NSString*)key isInUse:(BOOL)inUse;
- (BOOL)keyIsInUse:(NSString*)key;

/** @brief Delete all data and associated keys for keys not in use.
 */
- (void)removeUnusedData;

@end

extern NSPasteboardType const kDKImageDataManagerPasteboardType NS_SWIFT_NAME(dkImageDataManager);

@interface NSData (Checksum)

/** @brief The checksum is a weighted sum of the first 1024 bytes (or less) of the data XOR the length. This value should be reasonably unique for quickly comparing
 image data.
 */
- (NSUInteger)checksum;
- (NSString*)checksumString;

@end

NS_ASSUME_NONNULL_END
