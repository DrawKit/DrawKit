/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>
#import "DKRasterizerProtocol.h"
#import "GCObservableObject.h"

NS_ASSUME_NONNULL_BEGIN

@class DKRastGroup;
@protocol DKRendererDelegate;

//! clipping values:
typedef NS_ENUM(NSInteger, DKClippingOption) {
	kDKClippingNone = 0,
	kDKClippingOutsidePath = 1,
	kDKClippingInsidePath = 2
};

/** @brief Renderers can now have a delegate attached which is able to modify behaviours such as changing the path rendered, etc.

 Renderers can now have a delegate attached which is able to modify behaviours such as changing the path rendered, etc.
*/
@interface DKRasterizer : GCObservableObject <DKRasterizer, NSCoding, NSCopying> {
@private
	DKRastGroup* __weak mContainerRef; // group that contains this
	NSString* m_name; // optional name
	BOOL m_enabled; // YES if actually drawn
	DKClippingOption mClipping; // set path clipping to this
}

+ (nullable DKRasterizer*)rasterizerFromPasteboard:(NSPasteboard*)pb;

- (instancetype)init NS_DESIGNATED_INITIALIZER;
- (nullable instancetype)initWithCoder:(NSCoder*)coder NS_DESIGNATED_INITIALIZER;

/** @brief The immediate container of this object.
 
 This is a weak reference as the object is owned by its container. Generally the setter is called as
 required when the object is added to a group, so should not be set by app code.
 */
@property (nonatomic, weak) DKRastGroup *container;

/** @brief The name of the renderer.
 
 Named renderers can be referred to in scripts or bound to in the UI. The name is copied for safety.
 */
@property (nonatomic, copy, nullable) NSString *name;

/** @brief Get the name or classname of the renderer.
 
 Named renderers can be referred to in scripts or bound to in the UI.
 @return the renderer's name or classname
 */
@property (readonly, copy, nonnull) NSString *label;

/** @brief Return the equivalent style script for this renderer

 Subclasses shold override this - the default method returns the object's description for debugging.
 Is a string, representing the script that would create an equivalent renderer if parsed.
 */
@property (readonly, copy, nonnull) NSString *styleScript;

/** @brief Queries whether the renderer is valid, that is, it will draw something.
 
 Used to optimize drawing - invalid renderers are skipped.
 Is \c YES if the renderer will draw something, \c NO otherwise.
 */
@property (readonly, getter=isValid) BOOL valid;

/** @brief Whether the renderer is enabled or not
 
 Disabled renderers won't draw anything, so this can be used to temporarily turn off part of a
 larget set of renderers (in a style, say) from the UI, but without actually deleting the renderer.
 */
@property BOOL enabled;

/** @brief Set whether the rasterizer's effect is clipped to the path or not, and if so, which side
 @param clipping a DKClippingOption value
 */
- (void)setClipping:(DKClippingOption)clipping;
- (void)setClippingWithoutNotifying:(DKClippingOption)clipping;

/** @brief Whether the rasterizer's effect is clipped to the path or not, and if so, which side.
 */
@property DKClippingOption clipping;

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

extern NSPasteboardType const kDKRasterizerPasteboardType;

extern NSNotificationName const kDKRasterizerPropertyWillChange;
extern NSNotificationName const kDKRasterizerPropertyDidChange;
extern NSString* const kDKRasterizerChangedPropertyKey;

/*! @brief DKRasterizer is an abstract base class that implements the DKRasterizer protocol. Concrete subclasses
 include DKStroke, DKFill, DKHatching, DKFillPattern, DKGradient, etc.
 
 A renderer is given an object and renders it according to its behaviour to the current context. It can
 do whatever it wants. Normally it will act upon the object's path so as a convenience the renderPath method
 is called by default. Subclasses can override at the object or the path level, as they wish.
 
 Renderers are obliged to accurately return the extra space they need to perform their rendering, over and
 above the bounds of the path. For example a standard stroke is aligned on the path, so the extra space should
 be half of the stroke width in both width and height. This additional space is used to compute the correct bounds
 of a shape when a set of rendering operations is applied to it.

*/
@protocol DKRendererDelegate <NSObject>

- (NSBezierPath*)renderer:(DKRasterizer*)aRenderer willRenderPath:(NSBezierPath*)aPath;

@end


static const DKClippingOption kDKClipOutsidePath API_DEPRECATED_WITH_REPLACEMENT("kDKClippingOutsidePath", macosx(10.0, 10.6)) = kDKClippingOutsidePath;
static const DKClippingOption kDKClipInsidePath API_DEPRECATED_WITH_REPLACEMENT("kDKClippingInsidePath", macosx(10.0, 10.6)) = kDKClippingInsidePath;

NS_ASSUME_NONNULL_END
