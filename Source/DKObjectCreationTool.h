/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>
#import "DKDrawingTool.h"

NS_ASSUME_NONNULL_BEGIN

@class DKStyle;

/** @brief This tool class is used to make all kinds of drawable objects.

This tool class is used to make all kinds of drawable objects. It works by copying a prototype object which will be some kind of drawable, adding
it to the target layer as a pending object, then proceeding as for an edit operation. When complete, if the object is valid it is committed to
the layer as a permanent item.

The prototype object can have all of its parameters set up in advance as required, including an attached style.

You can also set up a style to be applied to all new objects initially as an independent parameter.
*/
@interface DKObjectCreationTool : DKDrawingTool {
@private
	id<NSCopying, NSObject> m_prototypeObject;
	BOOL mEnableStylePickup;
	BOOL mDidPickup;
	NSPoint mLastPoint;
	NSInteger mPartcode;

@protected
	id m_protoObject;
}

/** @brief Create a tool for an existing object

 This method conveniently allows you to create tools for any object you already have. For example
 if you create a complex shape from others, or make a group of objects, you can turn that object
 into an interactive tool to make more of the same.
 @param shape a drawable object that can be created by the tool - typically a DKDrawableShape
 @param name the name of the tool to register this with
 */
+ (void)registerDrawingToolForObject:(id<NSCopying, NSObject>)shape withName:(NSString*)name;

/** @brief Set a style to be used for subsequently created objects

 If you set nil, the style set in the prototype object for the individual tool will be used instead.
 @param aStyle a style object that will be applied to each new object as it is created
 */
+ (void)setStyleForCreatedObjects:(nullable DKStyle*)aStyle;

/** @brief Return a style to be used for subsequently created objects

 If you set nil, the style set in the prototype object for the individual tool will be used instead.
 @return a style object that will be applied to each new object as it is created, or nil
 */
+ (nullable DKStyle*)styleForCreatedObjects;

@property (class, retain, nullable) DKStyle *styleForCreatedObjects;

- (instancetype)init UNAVAILABLE_ATTRIBUTE;

/** @brief Initialize the tool
 @param aPrototype an object that will be used as the tool's prototype - each new object created will
 @return the tool object
 */
- (instancetype)initWithPrototypeObject:(id<NSCopying, NSObject>)aPrototype NS_DESIGNATED_INITIALIZER;

/** @brief The object to be copied when the tool created a new one.
 
 An object that will be used as the tool's prototype - each new object created will
 be a copy of this one.
 */
@property (nonatomic, strong/* , nonnull */) id<NSCopying, NSObject> prototype;

/** @brief Return a new object copied from the prototype, but with the current class style if there is one

 The returned object is autoreleased
 @return a new object based on the prototype.
 */
- (id)objectFromPrototype;

@property (strong, nullable) DKStyle *style;

@property BOOL stylePickupEnabled;

/** @brief Return an image showing what the tool creates

 The image may be used as an icon for this tool in a UI, for example
 @return an image
 */
- (nullable NSImage*)image;

@end

#define kDKDefaultToolSwatchSize (NSMakeSize(64, 64))

extern NSNotificationName const kDKDrawingToolWillMakeNewObjectNotification;
extern NSNotificationName const kDKDrawingToolCreatedObjectsStyleDidChange;

NS_ASSUME_NONNULL_END
