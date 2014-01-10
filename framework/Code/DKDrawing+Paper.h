/**
 @author Graham Cox, Apptree.net
 @author Graham Miln, miln.eu
 @author Contributions from the community
 @date 2005-2014
 @copyright This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file.
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
