/**
 @author Graham Cox, Apptree.net
 @author Graham Miln, miln.eu
 @author Contributions from the community
 @date 2005-2014
 @copyright This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file.
 */

#import "DKRasterizerProtocol.h"
#import "GCObservableObject.h"

@class DKRastGroup;

// clipping values:

typedef enum {
    kDKClippingNone = 0,
    kDKClipOutsidePath = 1,
    kDKClipInsidePath = 2
} DKClippingOption;

/** @brief Renderers can now have a delegate attached which is able to modify behaviours such as changing the path rendered, etc.

Renderers can now have a delegate attached which is able to modify behaviours such as changing the path rendered, etc.
*/
@interface DKRasterizer : GCObservableObject <DKRasterizer, NSCoding, NSCopying> {
@private
    DKRastGroup* mContainerRef; // group that contains this
    NSString* m_name; // optional name
    BOOL m_enabled; // YES if actually drawn
    DKClippingOption mClipping; // set path clipping to this
}

+ (DKRasterizer*)rasterizerFromPasteboard:(NSPasteboard*)pb;

/** @brief Returns the immediate container of this object, if owned by a group
 @return the object's container group, if any
 */
- (DKRastGroup*)container;

/** @brief Sets the immediate container of this object

 This is a weak reference as the object is owned by its container. Generally this is called as
 required when the object is added to a group, so should not be used by app code
 @param container the objects's container - must be a group, or nil
 */
- (void)setContainer:(DKRastGroup*)container;

- (void)setName:(NSString*)name;
- (NSString*)name;
- (NSString*)label;

- (BOOL)isValid;
- (NSString*)styleScript;

- (void)setEnabled:(BOOL)enable;
- (BOOL)enabled;

- (void)setClipping:(DKClippingOption)clipping;
- (void)setClippingWithoutNotifying:(DKClippingOption)clipping;

/** @brief Whether the rasterizer's effect is clipped to the path or not, and if so, which side
 @return a DKClippingOption value
 */
- (DKClippingOption)clipping;

/** @brief Returns the path to render given the object doing the rendering

 This method is called internally by render: to obtain the path to be rendered. It is factored to
 allow a delegate to modify the path just before rendering, and to allow special subclasses to
 override it to modify the path for special effects. The normal behaviour is simply to ask the
 object for its rendering path.
 @param object the object to render
 @return the rendering path */
- (NSBezierPath*)renderingPathForObject:(id<DKRenderable>)object;

- (BOOL)copyToPasteboard:(NSPasteboard*)pb;

@end

extern NSString* kDKRasterizerPasteboardType;

extern NSString* kDKRasterizerPropertyWillChange;
extern NSString* kDKRasterizerPropertyDidChange;
extern NSString* kDKRasterizerChangedPropertyKey;

/*
 DKRasterizer is an abstract base class that implements the DKRasterizer protocol. Concrete subclasses
 include DKStroke, DKFill, DKHatching, DKFillPattern, DKGradient, etc.
 
 A renderer is given an object and renders it according to its behaviour to the current context. It can
 do whatever it wants. Normally it will act upon the object's path so as a convenience the renderPath method
 is called by default. Subclasses can override at the object or the path level, as they wish.
 
 Renderers are obliged to accurately return the extra space they need to perform their rendering, over and
 above the bounds of the path. For example a standard stroke is aligned on the path, so the extra space should
 be half of the stroke width in both width and height. This additional space is used to compute the correct bounds
 of a shape when a set of rendering operations is applied to it.

*/

@interface NSObject (DKRendererDelegate)

- (NSBezierPath*)renderer:(DKRasterizer*)aRenderer willRenderPath:(NSBezierPath*)aPath;

@end
