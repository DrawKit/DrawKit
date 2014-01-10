/**
 @author Graham Cox, Apptree.net
 @author Graham Miln, miln.eu
 @author Contributions from the community
 @date 2005-2014
 @copyright This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file.
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
