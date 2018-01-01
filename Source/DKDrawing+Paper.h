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

/** @brief Returns the size (in Quartz drawing units) of an A0 piece of paper.
 
 Result may be passed directly to \c setDrawingSize:
 @param portrait \c YES if in portrait orientation, \c NO for landscape.
 @return the paper size
 */
+ (NSSize)isoA0PaperSize:(BOOL)portrait NS_SWIFT_NAME(isoA0PaperSize(portrait:));

/** @brief Returns the size (in Quartz drawing units) of an A1 piece of paper.
 
 Result may be passed directly to \c setDrawingSize:
 @param portrait \c YES if in portrait orientation, \c NO for landscape.
 @return the paper size
 */
+ (NSSize)isoA1PaperSize:(BOOL)portrait NS_SWIFT_NAME(isoA1PaperSize(portrait:));

/** @brief Returns the size (in Quartz drawing units) of an A2 piece of paper.
 
 Result may be passed directly to \c setDrawingSize:
 @param portrait \c YES if in portrait orientation, \c NO for landscape.
 @return the paper size
 */
+ (NSSize)isoA2PaperSize:(BOOL)portrait NS_SWIFT_NAME(isoA2PaperSize(portrait:));

/** @brief Returns the size (in Quartz drawing units) of an A3 piece of paper.
 
 Result may be passed directly to \c setDrawingSize:
 @param portrait \c YES if in portrait orientation, \c NO for landscape.
 @return the paper size
 */
+ (NSSize)isoA3PaperSize:(BOOL)portrait NS_SWIFT_NAME(isoA3PaperSize(portrait:));

/** @brief Returns the size (in Quartz drawing units) of an A4 piece of paper.
 
 Result may be passed directly to \c setDrawingSize:
 @param portrait \c YES if in portrait orientation, \c NO for landscape.
 @return the paper size
 */
+ (NSSize)isoA4PaperSize:(BOOL)portrait NS_SWIFT_NAME(isoA4PaperSize(portrait:));

/** @brief Returns the size (in Quartz drawing units) of an A5 piece of paper.
 
 Result may be passed directly to \c setDrawingSize:
 @param portrait \c YES if in portrait orientation, \c NO for landscape.
 @return the paper size
 */
+ (NSSize)isoA5PaperSize:(BOOL)portrait NS_SWIFT_NAME(isoA5PaperSize(portrait:));

@end
