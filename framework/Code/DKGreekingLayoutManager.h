/**
 @author Graham Cox, Apptree.net
 @author Graham Miln, miln.eu
 @author Contributions from the community
 @date 2005-2014
 @copyright This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file.
 */

#import <Cocoa/Cocoa.h>
#import "DKCommonTypes.h"

/** @brief This layout manager subclass draws greeking rectangles instead of glyphs, either as entire line fragement rectangles or as glyph rectangles.

This layout manager subclass draws greeking rectangles instead of glyphs, either as entire line fragement rectangles or as glyph rectangles.
 
 Greeking can be faster for certain operations such as hit-testing where exact glyph rendition is not needed.
*/
@interface DKGreekingLayoutManager : NSLayoutManager {
	DKGreeking mGreeking;
	NSColor* mGreekingColour;
}

- (void)setGreeking:(DKGreeking)greeking;
- (DKGreeking)greeking;

- (void)setGreekingColour:(NSColor*)aColour;
- (NSColor*)greekingColour;

@end
