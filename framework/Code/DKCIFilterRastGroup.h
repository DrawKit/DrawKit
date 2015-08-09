/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2015
 @copyright MPL2; see LICENSE.txt
*/

#import "DKRastGroup.h"

/** @brief Captures the output of its contained renderers in an image

 This class implements a special rendergroup that captures the output of its contained renderers in an image, then
 allows that image to be manipulated or processed (e.g. by core image) before rendering it back to the drawing. This
 allows us to leverage all sorts of imaging code to extend the range of available styles and effects.
*/
@interface DKCIFilterRastGroup : DKRastGroup <NSCoding, NSCopying> {
	NSString* m_filter;
	NSDictionary* m_arguments;
	NSImage* m_cache;
}

+ (DKCIFilterRastGroup*)effectGroupWithFilter:(NSString*)filter;

- (void)setFilter:(NSString*)filter;
- (NSString*)filter;

- (void)setArguments:(NSDictionary*)dict;
- (NSDictionary*)arguments;

- (void)invalidateCache;

@end

@interface NSImage (CoreImage)
/** @brief Draws the specified image using Core Image. */
- (void)drawAtPoint:(NSPoint)point fromRect:(NSRect)fromRect coreImageFilter:(NSString*)filterName arguments:(NSDictionary*)arguments;

/** @brief Gets a bitmap representation of the image, or creates one if the image does not have any. */
- (NSBitmapImageRep*)bitmapImageRepresentation;
@end

#define CIIMAGE_PADDING 32.0f

@interface NSBitmapImageRep (CoreImage)
/** @brief Draws the specified image representation using Core Image. */
- (void)drawAtPoint:(NSPoint)point fromRect:(NSRect)fromRect coreImageFilter:(NSString*)filterName arguments:(NSDictionary*)arguments;
@end
