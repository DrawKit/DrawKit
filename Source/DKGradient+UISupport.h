/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>
#import "DKGradient.h"

/**
This category of DKGradient supplies a number of prebuilt gradients that implement a variety of user-interface gradients
as found in numerour apps, including Apple's own.
*/
@interface DKGradient (UISupport)

+ (DKGradient*)aquaSelectedGradient;
+ (DKGradient*)aquaNormalGradient;
+ (DKGradient*)aquaPressedGradient;

+ (DKGradient*)unifiedSelectedGradient;
+ (DKGradient*)unifiedNormalGradient;
+ (DKGradient*)unifiedPressedGradient;
+ (DKGradient*)unifiedDarkGradient;

+ (DKGradient*)sourceListSelectedGradient;
+ (DKGradient*)sourceListUnselectedGradient;

+ (void)drawShinyGradientInRect:(NSRect)aRect withColour:(NSColor*)colour;

@end

typedef struct
	{
	CGFloat color[4];
	CGFloat caustic[4];
	CGFloat expCoefficient;
	CGFloat expScale;
	CGFloat expOffset;
	CGFloat initialWhite;
	CGFloat finalWhite;
} GlossParameters;
