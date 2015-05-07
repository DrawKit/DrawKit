/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2015
 @copyright GNU LGPL3; see LICENSE
*/

#import <Cocoa/Cocoa.h>

@interface NSImage (DKAdditions)

+ (NSImage*)imageFromImage:(NSImage*)srcImage withSize:(NSSize)size;
+ (NSImage*)imageFromImage:(NSImage*)srcImage withSize:(NSSize)size fraction:(CGFloat)opacity allowScaleUp:(BOOL)scaleUp;

@end
