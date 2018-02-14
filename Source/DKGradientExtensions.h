/**
 @author Jason Jobe
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>
#import "DKGradient.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSView (DKGradientExtensions)

- (void)dragGradient:(DKGradient*)gradient swatchSize:(NSSize)size
		   slideBack:(BOOL)slideBack
			   event:(NSEvent*)event;

- (void)dragStandardSwatchGradient:(DKGradient*)gradient slideBack:(BOOL)slideBack event:(NSEvent*)event;

- (void)dragColor:(NSColor*)color swatchSize:(NSSize)size slideBack:(BOOL)slideBack event:(NSEvent*)event;

@end

@interface NSColor (DKGradientExtensions)

- (NSImage*)swatchImageWithSize:(NSSize)size withBorder:(BOOL)showBorder;

@end

@interface DKGradient (DKGradientExtensions)

- (void)setUpExtensionData;

@property NSPoint radialStartingPoint;
@property NSPoint radialEndingPoint;
@property CGFloat radialStartingRadius;
@property CGFloat radialEndingRadius;

/** return \c YES if there are valid radial settings.
 */
@property (readonly) BOOL hasRadialSettings;

/** @brief Given a point \c p within \c rect this returns it mapped to a \c 0..1 interval.
 */
- (NSPoint)mapPoint:(NSPoint)p fromRect:(NSRect)rect;
/** @brief Given a point \c p in \c 0..1 space, maps it to <code>rect</code>.
 */
- (NSPoint)mapPoint:(NSPoint)p toRect:(NSRect)rect;

/** given a key to an old \c NSPoint based struct, this converts it to the new archiver-compatible storage.
 */
- (void)convertOldKey:(NSString*)key;
/** Converts all keys of an old NSPoint based struct to the new archiver-compatible storage.
 */
- (void)convertOldKeys;

@end

@interface NSDictionary (StructEncoding)

- (NSPoint)pointForKey:(id)key;

- (float)floatForKey:(id)key;

@end

@interface NSMutableDictionary (StructEncoding)

- (void)setPoint:(NSPoint)p forKey:(id)key;

- (void)setFloat:(float)f forKey:(id)key;

@end

NS_ASSUME_NONNULL_END
