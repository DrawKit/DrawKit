/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSImage (DKAdditions)

/** makes a copy of \c srcImage by drawing it into a bitmap representation of <code>size</code>, scaling as needed. A new temporary graphics context is
 made to ensure that there are no side effects such as arbitrary flippedness (the returned image is unflipped). This also sets high quality
 image interpolation for best rendering quality. \c size can be \c NSZeroRect to copy the image at its original size. In addition, if the source
 size is smaller than <code>size</code>, the src image is not scaled UP to the new image, but centred preserving its aspect ratio.
 */
+ (NSImage*)imageFromImage:(NSImage*)srcImage withSize:(NSSize)size;

/** makes a copy of \c srcImage by drawing it into a bitmap representation of <code>size</code>, scaling as needed. A new temporary graphics context is
 made to ensure that there are no side effects such as arbitrary flippedness (the returned image is unflipped). This also sets high quality
 image interpolation for best rendering quality. \c size can be \c NSZeroRect to copy the image at its original size. In addition, if the source
 size is smaller than <code>size</code>, the src image is not scaled UP to the new image, but centred preserving its aspect ratio.
 */
+ (NSImage*)imageFromImage:(NSImage*)srcImage withSize:(NSSize)size fraction:(CGFloat)opacity allowScaleUp:(BOOL)scaleUp;

@end

NS_ASSUME_NONNULL_END
