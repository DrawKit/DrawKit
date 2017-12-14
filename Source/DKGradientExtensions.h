/**
 @author Jason Jobe
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import "DKGradient.h"

@interface NSView (DKGradientExtensions)

- (void)dragGradient:(DKGradient*)gradient swatchSize:(NSSize)size
		   slideBack:(BOOL)slideBack
			   event:(NSEvent*)event;

/**  */
- (void)dragStandardSwatchGradient:(DKGradient*)gradient slideBack:(BOOL)slideBack event:(NSEvent*)event;

- (void)dragColor:(NSColor*)color swatchSize:(NSSize)size slideBack:(BOOL)slideBack event:(NSEvent*)event;

@end

@interface NSColor (DKGradientExtensions)

- (NSImage*)swatchImageWithSize:(NSSize)size withBorder:(BOOL)showBorder;

@end

@interface DKGradient (DKGradientExtensions)

- (void)setUpExtensionData;

- (void)setRadialStartingPoint:(NSPoint)p;
- (void)setRadialEndingPoint:(NSPoint)p;
- (void)setRadialStartingRadius:(CGFloat)rad;
- (void)setRadialEndingRadius:(CGFloat)rad;

- (NSPoint)radialStartingPoint;
- (NSPoint)radialEndingPoint;
- (CGFloat)radialStartingRadius;
- (CGFloat)radialEndingRadius;

@property NSPoint radialStartingPoint;
@property NSPoint radialEndingPoint;
@property CGFloat radialStartingRadius;
@property CGFloat radialEndingRadius;

- (BOOL)hasRadialSettings;
@property (readonly) BOOL hasRadialSettings;

- (NSPoint)mapPoint:(NSPoint)p fromRect:(NSRect)rect;
- (NSPoint)mapPoint:(NSPoint)p toRect:(NSRect)rect;

- (void)convertOldKey:(NSString*)key;
- (void)convertOldKeys;

@end

@interface NSDictionary (StructEncoding)

- (void)setPoint:(NSPoint)p forKey:(id)key;
- (NSPoint)pointForKey:(id)key;

- (void)setFloat:(float)f forKey:(id)key;
- (float)floatForKey:(id)key;

@end
