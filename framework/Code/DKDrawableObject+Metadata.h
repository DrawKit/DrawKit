/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2015
 @copyright MPL2; see LICENSE.txt
*/

#import "DKDrawableObject.h"
#import "DKMetadataItem.h"

// metadata has been through a bit of evolution. This constant indicates which schema is in use

typedef enum {
	kDKMetadataOriginalSchema = 1,
	kDKMetadataMark2Schema = 2,
	kDKMetadata107Schema = 3
} DKMetadataSchema;

/** @brief Stores various drawkit private variables in the metadata.

Stores various drawkit private variables in the metadata.

Note that the details of how metadata is stored changed in 1.0b6. Now, the metadata is held in a separate dictionary within the overall userinfo dictionary, rather than as
 individual items within userInfo. This permits the userInfo dictionary to be used more extensively while keeping metadata grouped together. Using this API shields you
 from those changes, though if you were accessing userInfo to obtain the metadata, you may need to revise code to call -metadata instead.
*/
@interface DKDrawableObject (Metadata)

+ (void)setMetadataChangesAreUndoable:(BOOL)undo;
+ (BOOL)metadataChangesAreUndoable;

- (void)addMetadata:(NSDictionary*)dict;
- (void)setMetadata:(NSDictionary*)dict;
- (NSMutableDictionary*)metadata;
- (NSArray*)metadataKeys;

- (void)setupMetadata;
- (DKMetadataSchema)schema;

- (void)setMetadataItem:(DKMetadataItem*)item forKey:(NSString*)key;
- (DKMetadataItem*)metadataItemForKey:(NSString*)key;
- (DKMetadataItem*)metadataItemForKey:(NSString*)key limitToLocalSearch:(BOOL)local;

- (NSArray*)metadataItemsForKeysInArray:(NSArray*)keyArray;
- (NSArray*)metadataItemsForKeysInArray:(NSArray*)keyArray limitToLocalSearch:(BOOL)local;

- (void)setMetadataItemType:(DKMetadataType)type forKey:(NSString*)key;

- (id)metadataObjectForKey:(NSString*)key;
- (void)setMetadataItemValue:(id)value forKey:(NSString*)key;

- (BOOL)hasMetadataForKey:(NSString*)key;
- (void)removeMetadataForKey:(NSString*)key;

- (void)setFloatValue:(float)val forKey:(NSString*)key;
- (CGFloat)floatValueForKey:(NSString*)key;

- (void)setIntValue:(int)val forKey:(NSString*)key;
- (NSInteger)intValueForKey:(NSString*)key;

- (void)setString:(NSString*)string forKey:(NSString*)key;
- (NSString*)stringForKey:(NSString*)key;

- (void)setColour:(NSColor*)colour forKey:(NSString*)key;
- (NSColor*)colourForKey:(NSString*)key;

- (void)setSize:(NSSize)size forKey:(NSString*)key;
- (NSSize)sizeForKey:(NSString*)key;

- (void)updateMetadataKeys;
- (NSUInteger)metadataChecksum;

- (void)metadataWillChangeKey:(NSString*)key;
- (void)metadataDidChangeKey:(NSString*)key;

@end

// deprecated methods - avoid using anonymous objects with metadata - wrap values in DKMetadataItem objects and use
// setMetadataItem:forKey: and metadataItemForKey: instead. This preserves type and handles far more interconversions.

@interface DKDrawableObject (MetadataDeprecated)

- (void)setMetadataObject:(id)obj forKey:(NSString*)key;

@end

/* adds some convenience methods for standard meta data attached to a graphic object. By default the metadata is just an uncomitted
id, but using this sets it to be a mutable dictionary. You can then easily get and set values in that dictionary.

*/

extern NSString* kDKMetaDataUserInfoKey;
extern NSString* kDKMetaDataUserInfo107OrLaterKey;
extern NSString* kDKPrivateShapeOriginalText;
extern NSString* kDKMetadataWillChangeNotification;
extern NSString* kDKMetadataDidChangeNotification;
extern NSString* kDKUndoableChangesUserDefaultsKey;

@interface DKDrawableObject (DrawkitPrivateMetadata)

- (void)setOriginalText:(NSAttributedString*)text;
- (NSAttributedString*)originalText;

@end
