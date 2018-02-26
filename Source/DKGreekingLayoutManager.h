/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>
#import "DKCommonTypes.h"

NS_ASSUME_NONNULL_BEGIN

/** @brief This layout manager subclass draws greeking rectangles instead of glyphs, either as entire line fragement rectangles or as glyph rectangles.

This layout manager subclass draws greeking rectangles instead of glyphs, either as entire line fragement rectangles or as glyph rectangles.
 
 Greeking can be faster for certain operations such as hit-testing where exact glyph rendition is not needed.
*/
@interface DKGreekingLayoutManager : NSLayoutManager {
	DKGreeking mGreeking;
	NSColor* mGreekingColour;
}

@property DKGreeking greeking;

@property (strong) NSColor* greekingColour;

@end

NS_ASSUME_NONNULL_END
