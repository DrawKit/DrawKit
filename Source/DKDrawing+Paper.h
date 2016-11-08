/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>
#import "DKDrawing.h"

/** @brief This category on DKDrawing simply supplies some common ISO paper sizes in terms of Quartz point dimensions.

This category on DKDrawing simply supplies some common ISO paper sizes in terms of Quartz point dimensions.

The sizes can be passed directly to -initWithSize:
*/
@interface DKDrawing (Paper)

+ (NSSize)isoA0PaperSize:(BOOL)portrait;
+ (NSSize)isoA1PaperSize:(BOOL)portrait;
+ (NSSize)isoA2PaperSize:(BOOL)portrait;
+ (NSSize)isoA3PaperSize:(BOOL)portrait;
+ (NSSize)isoA4PaperSize:(BOOL)portrait;
+ (NSSize)isoA5PaperSize:(BOOL)portrait;

@end
