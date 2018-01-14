/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSImage (DKAdditions)

+ (NSImage*)imageFromImage:(NSImage*)srcImage withSize:(NSSize)size;
+ (NSImage*)imageFromImage:(NSImage*)srcImage withSize:(NSSize)size fraction:(CGFloat)opacity allowScaleUp:(BOOL)scaleUp;

@end

NS_ASSUME_NONNULL_END
