/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>

/**
The purpose of this class is to allow images to be archived much more efficiently, by archiving the original data that the image was created from rather than any bitmaps or
 other uncompressed forms, and to avoid storing multiple copies of the same image. Each drawing will have an instance of this class and any image using objects such as DKImageShape
 can make use of it.
 
 This only comes into play when archiving, dearchiving or creating images - each object still maintains an NSImage derived from the data stored here.
 
 When images are cut/pasted within the framework, the image key can be used to effect that operation without having to move the actual image data.
*/
@interface DKImageDataManager : NSObject <NSCoding> {
@private
	NSMutableDictionary* mRepository;
	NSMutableDictionary* mHashList;
	NSMutableDictionary* mKeyUsage;
}

- (NSData*)imageDataForKey:(NSString*)key;
- (void)setImageData:(NSData*)imageData forKey:(NSString*)key;
- (BOOL)hasImageDataForKey:(NSString*)key;
- (NSString*)generateKey;
- (NSString*)keyForImageData:(NSData*)imageData;
- (NSArray*)allKeys;
- (void)removeKey:(NSString*)key;

- (NSImage*)makeImageWithData:(NSData*)imageData key:(NSString**)key;
- (NSImage*)makeImageWithPasteboard:(NSPasteboard*)pb key:(NSString**)key;
- (NSImage*)makeImageWithContentsOfURL:(NSURL*)url key:(NSString**)key;
- (NSImage*)makeImageForKey:(NSString*)key;

- (void)setKey:(NSString*)key isInUse:(BOOL)inUse;
- (BOOL)keyIsInUse:(NSString*)key;
- (void)removeUnusedData;

@end

extern NSString* kDKImageDataManagerPasteboardType;

@interface NSData (Checksum)

- (NSUInteger)checksum;
- (NSString*)checksumString;

@end
