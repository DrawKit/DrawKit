//
//  DKMetadataStorable.h
//  DrawKit
//
//  Created by C.W. Betts on 12/20/17.
//  Copyright © 2017 DrawKit. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DKMetadataItem.h"

NS_ASSUME_NONNULL_BEGIN

@protocol DKMetadataStorable <NSObject>

@property (class, readwrite) BOOL metadataChangesAreUndoable;

- (void)setupMetadata;
- (nullable NSMutableDictionary<NSString*,DKMetadataItem*>*)metadata NS_REFINED_FOR_SWIFT;
@property (readonly, copy, nullable) NSArray<NSString*> *metadataKeys;

- (void)addMetadata:(NSDictionary<NSString*,id>*)dict;
- (void)setMetadata:(NSDictionary<NSString*,DKMetadataItem*>*)dict NS_REFINED_FOR_SWIFT;

- (void)setMetadataItem:(DKMetadataItem*)item forKey:(NSString*)key;
- (nullable DKMetadataItem*)metadataItemForKey:(NSString*)key;
- (void)setMetadataItemValue:(id)value forKey:(NSString*)key;
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

- (BOOL)hasMetadataForKey:(NSString*)key;
- (void)removeMetadataForKey:(NSString*)key;

- (void)setFloatValue:(CGFloat)val forKey:(NSString*)key NS_SWIFT_NAME(set(_:forKey:));
- (CGFloat)floatValueForKey:(NSString*)key;

- (void)setIntValue:(NSInteger)val forKey:(NSString*)key NS_SWIFT_NAME(set(_:forKey:));
- (NSInteger)intValueForKey:(NSString*)key;

- (void)setString:(NSString*)string forKey:(NSString*)key NS_SWIFT_NAME(set(_:forKey:));
- (nullable NSString*)stringForKey:(NSString*)key;

- (void)setColour:(NSColor*)colour forKey:(NSString*)key NS_SWIFT_NAME(set(_:forKey:));
- (nullable NSColor*)colourForKey:(NSString*)key;

- (void)setSize:(NSSize)size forKey:(NSString*)key NS_SWIFT_NAME(set(_:forKey:));
- (NSSize)sizeForKey:(NSString*)key;

- (void)updateMetadataKeys;
@property (readonly) NSUInteger metadataChecksum;

- (void)metadataWillChangeKey:(nullable NSString*)key;
- (void)metadataDidChangeKey:(nullable NSString*)key;

@end

extern NSNotificationName const kDKMetadataWillChangeNotification;
extern NSNotificationName const kDKMetadataDidChangeNotification;

NS_ASSUME_NONNULL_END
