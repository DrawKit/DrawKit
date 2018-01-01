/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>
#import "DKStyle.h"

@class DKStrokeDash, DKStroke, DKFill;

NS_ASSUME_NONNULL_BEGIN

/** @brief This category on \c DKStyle provides some simple accessors if your app only has the most basic use of styles in mind, e.

This category on \c DKStyle provides some simple accessors if your app only has the most basic use of styles in mind, e.g. one solid fill and
a single simple solid or dashed stroke.

This operates on the topmost DKStroke/DKFill rasterizers in a style's list, and does not touch any others. By passing a colour of nil, the
associated rasterizer is disabled. If a non-nil colour is passed, and there is no suitable rasterizer, one is created and added. If the
rasterizer has to be created for both properies, the stroke will be placed in front of the fill.

Note that this does not require or use and specially created style. It is recommended that if using these accessors, style sharing is
turned off so that every object has its own style - then these accessors effectively operate on the graphic object's stroke and fill properties. 
 
The string setter sets or creates a \c DKTextAdornment component having the default text parameters and the string as its label.

If the style is locked these do nothing.
*/
@interface DKStyle (SimpleAccess)

+ (DKStyle*)styleWithDotDensity:(CGFloat)percent foreColour:(NSColor*)fore backColour:(NSColor*)back;

@property (readonly, retain, nullable) DKStroke *stroke;
@property (readonly, retain, nullable) DKFill *fill;

@property (retain, nullable) NSColor *fillColour;

@property (retain, nullable) NSColor *strokeColour;

@property CGFloat strokeWidth;

@property (retain, nullable) DKStrokeDash *strokeDash;

@property NSLineCapStyle strokeLineCapStyle;

@property NSLineJoinStyle strokeLineJoinStyle;

@property (nullable, copy) NSString *string;

@property (readonly) BOOL hasImageComponent;
@property (retain, nullable) NSImage *imageComponent;

@end

NS_ASSUME_NONNULL_END
