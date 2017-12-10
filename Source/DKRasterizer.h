/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import "DKRasterizerProtocol.h"
#import "GCObservableObject.h"

@class DKRastGroup;
@protocol DKRendererDelegate;

//! clipping values:
typedef NS_ENUM(NSInteger, DKClippingOption) {
	kDKClippingNone = 0,
	kDKClipOutsidePath = 1,
	kDKClipInsidePath = 2
};

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
	
@property (assign) DKRastGroup *container;

/** @brief Set the name of the renderer
 
 Named renderers can be referred to in scripts or bound to in the UI. The name is copied for safety.
 @param name the name to give the renderer
 */
- (void)setName:(NSString*)name;

/** @brief Get the name of the renderer
 
 Named renderers can be referred to in scripts or bound to in the UI
 @return the renderer's name
 */
- (NSString*)name;
@property (nonatomic, copy) NSString *name;

- (NSString*)label;
@property (readonly, copy/*, nonnull*/) NSString *label;

- (BOOL)isValid;
- (NSString*)styleScript;

@property (readonly, getter=isValid) BOOL valid;

/** @brief Set whether the renderer is enabled or not
 
 Disabled renderers won't draw anything, so this can be used to temporarily turn off part of a
 larget set of renderers (in a style, say) from the UI, but without actually deleting the renderer
 @param enable \c YES to enable, \c NO to disable.
 */
- (void)setEnabled:(BOOL)enable;
	
/** @brief Query whether the renderer is enabled or not
 
 Disabled renderers won't draw anything, so this can be used to temporarily turn off part of a
 larget set of renderers (in a style, say) from the UI, but without actually deleting the renderer
 @return \c YES if enabled, \c NO if not.
 */
- (BOOL)enabled;
@property BOOL enabled;

/** @brief Set whether the rasterizer's effect is clipped to the path or not, and if so, which side
 @param clipping a DKClippingOption value
 */
- (void)setClipping:(DKClippingOption)clipping;
- (void)setClippingWithoutNotifying:(DKClippingOption)clipping;

/** @brief Whether the rasterizer's effect is clipped to the path or not, and if so, which side
 @return a DKClippingOption value
 */
- (DKClippingOption)clipping;

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

extern NSString* kDKRasterizerPasteboardType;

extern NSNotificationName kDKRasterizerPropertyWillChange;
extern NSNotificationName kDKRasterizerPropertyDidChange;
extern NSString* kDKRasterizerChangedPropertyKey;

/*!
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
@protocol DKRendererDelegate <NSObject>

- (NSBezierPath*)renderer:(DKRasterizer*)aRenderer willRenderPath:(NSBezierPath*)aPath;

@end
