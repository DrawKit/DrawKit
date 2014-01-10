/**
 @author Graham Cox, Apptree.net
 @author Graham Miln, miln.eu
 @author Contributions from the community
 @date 2005-2014
 @copyright This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file.
 */

#import "DKDrawingTool.h"

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
    id m_prototypeObject;
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
+ (void)registerDrawingToolForObject:(id<NSCopying>)shape withName:(NSString*)name;

/** @brief Set a style to be used for subsequently created objects

 If you set nil, the style set in the prototype object for the individual tool will be used instead.
 @param aStyle a style object that will be applied to each new object as it is created
 */
+ (void)setStyleForCreatedObjects:(DKStyle*)aStyle;

/** @brief Return a style to be used for subsequently created objects

 If you set nil, the style set in the prototype object for the individual tool will be used instead.
 @return a style object that will be applied to each new object as it is created, or nil
 */
+ (DKStyle*)styleForCreatedObjects;

/** @brief Initialize the tool
 @param aPrototype an object that will be used as the tool's prototype - each new object created will
 @return the tool object
 */
- (id)initWithPrototypeObject:(id<NSObject>)aPrototype;

/** @brief Set the object to be copied when the tool created a new one
 @param aPrototype an object that will be used as the tool's prototype - each new object created will
 */
- (void)setPrototype:(id<NSObject>)aPrototype;

/** @brief Return the object to be copied when the tool creates a new one
 @return an object - each new object created will be a copy of this one.
 */
- (id)prototype;

/** @brief Return a new object copied from the prototype, but with the current class style if there is one

 The returned object is autoreleased
 @return a new object based on the prototype.
 */
- (id)objectFromPrototype;

- (void)setStyle:(DKStyle*)aStyle;
- (DKStyle*)style;

- (void)setStylePickupEnabled:(BOOL)pickup;
- (BOOL)stylePickupEnabled;

/** @brief Return an image showing what the tool creates

 The image may be used as an icon for this tool in a UI, for example
 @return an image
 */
- (NSImage*)image;

@end

#define kDKDefaultToolSwatchSize (NSMakeSize(64, 64))

extern NSString* kDKDrawingToolWillMakeNewObjectNotification;
extern NSString* kDKDrawingToolCreatedObjectsStyleDidChange;
