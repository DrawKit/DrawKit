//
//  NSAttributedString+DKAdditions.h
///  DrawKit ©2005-2008 Apptree.net
//
//  Created by graham on 27/05/2008.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
//

#import <Cocoa/Cocoa.h>
#import "DKCommonTypes.h"





@interface NSAttributedString (DKAdditions)

- (void)	drawInRect:(NSRect) destRect withLayoutSize:(NSSize) layoutSize atAngle:(CGFloat) radians;
- (void)	drawInRect:(NSRect) destRect withLayoutPath:(NSBezierPath*) layoutPath atAngle:(CGFloat) radians;
- (void)	drawInRect:(NSRect) destRect withLayoutPath:(NSBezierPath*) layoutPath atAngle:(CGFloat) radians verticalPositioning:(DKVerticalTextAlignment) vAlign verticalOffset:(CGFloat) vPos;
- (NSSize)	accurateSize;
- (BOOL)	isHomogeneous;
- (BOOL)	attributeIsHomogeneous:(NSString*) attrName;
- (BOOL)	attributesAreHomogeneous:(NSDictionary*) attrs;

@end


@interface NSMutableAttributedString (DKAdditions)

- (void)	makeUppercase;
- (void)	makeLowercase;
- (void)	capitalize;

- (void)	convertFontsToFace:(NSString*) face;
- (void)	convertFontsToFamily:(NSString*) family;
- (void)	convertFontsToSize:(CGFloat) aSize;
- (void)	convertFontsByAddingSize:(CGFloat) aSize;
- (void)	convertFontsToHaveTrait:(NSFontTraitMask) traitMask;
- (void)	convertFontsToNotHaveTrait:(NSFontTraitMask) traitMask;

- (void)	changeFont:(id) sender;
- (void)	changeAttributes:(id) sender;

@end


// can be used by text drawers everywhere

NSLayoutManager*		sharedDrawingLayoutManager( void );
NSLayoutManager*		sharedCaptureLayoutManager( void );




/*

These category methods perform high-level text layout.

In the first case, the text is laid out in the layoutRect which dictates the line wrapping and number lines by its width or height (this rect
is the text container in other words). The resulting text is then rotated to the given angle and mapped into <destRect>, which applies any visual scaling
and translation, and drawn into the current context.

The second method is similar except that text is flowed into the layoutPath.

*/

