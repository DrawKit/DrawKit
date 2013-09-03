///**********************************************************************************************************************************
///  DKStyle-Text.h
///  DrawKit ©2005-2008 Apptree.net
///
///  Created by graham on 21/09/2006.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
///
///**********************************************************************************************************************************

#import "DKStyle.h"


@interface DKStyle (TextAdditions)

+ (DKStyle*)			defaultTextStyle;
+ (DKStyle*)			textStyleWithFont:(NSFont*) font;
+ (NSString*)			styleNameForFont:(NSFont*) font;

- (void)				setParagraphStyle:(NSParagraphStyle*) style;
- (NSParagraphStyle*)	paragraphStyle;

- (void)				setAlignment:(NSTextAlignment) align;
- (NSTextAlignment)		alignment;

- (void)				changeTextAttribute:(NSString*) attribute toValue:(id) val;
- (NSString*)			actionNameForTextAttribute:(NSString*) attribute;

- (void)				setFont:(NSFont*) font;
- (NSFont*)				font;
- (void)				setFontSize:(CGFloat) size;
- (CGFloat)				fontSize;

- (void)				setTextColour:(NSColor*) aColour;
- (NSColor*)			textColour;

- (void)				setUnderlined:(NSInteger) uval;
- (NSInteger)			underlined;
- (void)				toggleUnderlined;

- (void)				applyToText:(NSMutableAttributedString*) text;
- (void)				adoptFromText:(NSAttributedString*) text;

- (DKStyle*)			drawingStyleFromTextAttributes;

@end


/*

This adds text attributes to the DKStyle object. A DKTextShape makes use of styles with attached text attributes to style
the text it displays. Other objects that use text can make use of this as they wish.

*/
