/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>
#import "DKGradient.h"

NS_ASSUME_NONNULL_BEGIN

/**
This category of DKGradient supplies a number of prebuilt gradients that implement a variety of user-interface gradients
as found in numerour apps, including Apple's own.
*/
@interface DKGradient (UISupport)

@property (class, readonly, copy) DKGradient* aquaSelectedGradient;
@property (class, readonly, copy) DKGradient* aquaNormalGradient;
@property (class, readonly, copy) DKGradient* aquaPressedGradient;

@property (class, readonly, copy) DKGradient* unifiedSelectedGradient;
@property (class, readonly, copy) DKGradient* unifiedNormalGradient;
@property (class, readonly, copy) DKGradient* unifiedPressedGradient;
@property (class, readonly, copy) DKGradient* unifiedDarkGradient;

@property (class, readonly, copy) DKGradient* sourceListSelectedGradient;
@property (class, readonly, copy) DKGradient* sourceListUnselectedGradient;

+ (void)drawShinyGradientInRect:(NSRect)aRect withColour:(NSColor*)colour;

@end

NS_ASSUME_NONNULL_END
