/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>
#import "DKDrawableObject.h"
#import "DKMetadataItem.h"
#import "DKMetadataStorable.h"

NS_ASSUME_NONNULL_BEGIN

/** Metadata has been through a bit of evolution. This constant indicates which schema is in use
 */
typedef NS_ENUM(NSInteger, DKMetadataSchema) {
	kDKMetadataOriginalSchema NS_SWIFT_NAME(DKMetadataSchema.original)= 1,
	kDKMetadataMark2Schema NS_SWIFT_NAME(DKMetadataSchema.mark2)= 2,
	kDKMetadata107Schema NS_SWIFT_NAME(DKMetadataSchema.metadata107)= 3
};

/** @brief Stores various drawkit private variables in the metadata.

 Stores various drawkit private variables in the metadata.

 Note that the details of how metadata is stored changed in 1.0b6. Now, the metadata is held in a separate dictionary within the overall userinfo dictionary, rather than as
 individual items within userInfo. This permits the userInfo dictionary to be used more extensively while keeping metadata grouped together. Using this API shields you
 from those changes, though if you were accessing userInfo to obtain the metadata, you may need to revise code to call \c -metadata instead.
*/
@interface DKDrawableObject (Metadata) <DKMetadataStorable>

@property (class) BOOL metadataChangesAreUndoable;

- (void)addMetadata:(NSDictionary<NSString*,id>*)dict;
- (void)setMetadata:(NSDictionary<NSString*,DKMetadataItem*>*)dict NS_REFINED_FOR_SWIFT;
- (nullable NSMutableDictionary<NSString*,DKMetadataItem*>*)metadata NS_REFINED_FOR_SWIFT;
@property (readonly, copy, nullable) NSArray<NSString*> *metadataKeys;

- (void)setupMetadata;
/** Detects the current schema and returns a constant indicating which is in use. When an object is unarchived it is automatically
 migrated to the latest schema using the -updateMetadataKeys method.
 */
@property (readonly) DKMetadataSchema schema;

- (void)setMetadataItem:(DKMetadataItem*)item forKey:(NSString*)key;
- (nullable DKMetadataItem*)metadataItemForKey:(NSString*)key;
- (nullable DKMetadataItem*)metadataItemForKey:(NSString*)key limitToLocalSearch:(BOOL)local;

- (NSArray<DKMetadataItem*>*)metadataItemsForKeysInArray:(NSArray<NSString*>*)keyArray;
- (NSArray<DKMetadataItem*>*)metadataItemsForKeysInArray:(NSArray<NSString*>*)keyArray limitToLocalSearch:(BOOL)local;

- (void)setMetadataItemType:(DKMetadataType)type forKey:(NSString*)key;

/** retrieve the metadata object for the given key. As an extra bonus, if the
 key is a string, and it starts with a dollar sign, the rest of the string is used
 as a keypath, and will return the property at that keypath. This allows stuff that
 reads metadata to introspect objects in the framework - for example $style.name returns the style name, etc.

 to allow metadata retrieval to work smarter with nested objects, if the keyed object isn't found here and
 the container also implements this, the container is searched and so on until a non-confoming container is hit,
 at which point the search gives up and returns nil.
 */
- (nullable id)metadataObjectForKey:(NSString*)key;
- (void)setMetadataItemValue:(nullable id)value forKey:(NSString*)key;

- (BOOL)hasMetadataForKey:(NSString*)key;
- (void)removeMetadataForKey:(NSString*)key;

- (void)setFloatValue:(CGFloat)val forKey:(NSString*)key;
- (CGFloat)floatValueForKey:(NSString*)key;

- (void)setIntValue:(NSInteger)val forKey:(NSString*)key;
- (NSInteger)intValueForKey:(NSString*)key;

- (void)setString:(NSString*)string forKey:(NSString*)key;
- (nullable NSString*)stringForKey:(NSString*)key;

- (void)setColour:(NSColor*)colour forKey:(NSString*)key;
- (nullable NSColor*)colourForKey:(NSString*)key;

- (void)setSize:(NSSize)size forKey:(NSString*)key;
- (NSSize)sizeForKey:(NSString*)key;

- (void)updateMetadataKeys;
@property (readonly) NSUInteger metadataChecksum;

- (void)metadataWillChangeKey:(nullable NSString*)key;
- (void)metadataDidChangeKey:(nullable NSString*)key;

@end

/** deprecated methods - avoid using anonymous objects with metadata - wrap values in DKMetadataItem objects and use
 \c setMetadataItem:forKey: and \c metadataItemForKey: instead. This preserves type and handles far more interconversions.
 */
@interface DKDrawableObject (MetadataDeprecated)

- (void)setMetadataObject:(id)obj forKey:(NSString*)key DEPRECATED_ATTRIBUTE;

@end

/* adds some convenience methods for standard meta data attached to a graphic object. By default the metadata is just an uncomitted
id, but using this sets it to be a mutable dictionary. You can then easily get and set values in that dictionary.

*/

extern NSString* kDKMetaDataUserInfoKey;
extern NSString* kDKMetaDataUserInfo107OrLaterKey;
extern NSString* kDKPrivateShapeOriginalText;
extern NSString* kDKUndoableChangesUserDefaultsKey;

@interface DKDrawableObject (DrawkitPrivateMetadata)

- (void)setOriginalText:(NSAttributedString*)text;
- (NSAttributedString*)originalText;

@end

NS_ASSUME_NONNULL_END
