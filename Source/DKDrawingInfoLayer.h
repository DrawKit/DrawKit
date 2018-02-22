/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>
#import "DKLayer.h"
#import "DKDrawing.h"

NS_ASSUME_NONNULL_BEGIN

//! placement of info panel:
typedef NS_ENUM(NSInteger, DKInfoBoxPlacement) {
	kDKDrawingInfoPlaceBottomRight = 0,
	kDKDrawingInfoPlaceBottomLeft = 1,
	kDKDrawingInfoPlaceTopLeft = 2,
	kDKDrawingInfoPlaceTopRight = 3
};

/** @brief This is a DKLayer subclass which is able to draw an information panel in a corner of the drawing.

 This is a \c DKLayer subclass which is able to draw an information panel in a corner of the drawing.

 The info panel takes data from DKDrawing's metadata dictionary ind displays some of it - standard
 keys such as the drawing number, name of the draughtsman, creation and modification dates and so on.

 This can also directly edit the same information.

 This is not a very important class within DK, and mays apps will not want to use it, or to use it in
 modified form. It is provided as another example of how to implement layer subclasses as much as anything.
*/
@interface DKDrawingInfoLayer : DKLayer <NSCoding, NSTextViewDelegate> {
	DKInfoBoxPlacement m_placement; // which corner is the panel placed in
	NSSize m_size; // the size of the panel
	NSString* m_editingKeyRef; // which info key is being edited
	BOOL m_drawBorder; // YES if a border is drawn around the drawing
}

/** @name General Settings:
 @brief General settings.
 @{
 */

/** @brief The size of the drawing info box.
 */
@property (nonatomic) NSSize size;

@property (nonatomic) DKInfoBoxPlacement placement;

@property (strong) NSColor *backgroundColour;

@property (nonatomic) BOOL drawsBorder;

/** @} */

/** @name Internal Stuff:
 @brief Internal stuff.
 @{
 */

/** @brief Returns the bounds of the info box relative to the layer.
 @discussion This will take into account the size, placement and margins of the drawing.
 */
@property (readonly) NSRect infoBoxRect;
/** @brief Draws the info, labels, subdivisions, etc.
 @discussion \c br is the bounds of the info box. The border and background are drawn by the time
 this is called.
 @param br The bounds of the info box.
 */
- (void)drawInfoInRect:(NSRect)br;
- (nullable NSDictionary<NSAttributedStringKey, id>*)attributesForDrawingInfoItem:(NSString*)key;
- (void)drawString:(NSString*)str inRect:(NSRect)r withAttributes:(NSDictionary<NSAttributedStringKey, id>*)attr;

/** @brief returns the infobox label for the given drawing info item. The string is localisable.
*/
- (nullable NSAttributedString*)labelForDrawingInfoItem:(DKDrawingInfoKey)key;

/** @brief Returns the rect within \c bounds that the given item is to be laid out in. This rect will also be framed so add margins etc
 for positioning text as required.
 */
- (NSRect)layoutRectForDrawingInfoItem:(DKDrawingInfoKey)key inRect:(NSRect)bounds;
- (NSRect)labelRectInRect:(NSRect)itemRect forLabel:(NSAttributedString*)ls;

- (nullable NSString*)keyForEditableRegionUnderMouse:(NSPoint)p;
- (void)textViewDidChangeSelection:(NSNotification*)aNotification;

/** @} */

@end

extern NSString *const kDKDrawingInfoTextLabelAttributes;

NS_ASSUME_NONNULL_END
