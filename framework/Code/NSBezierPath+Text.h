//
//  NSBezierPath+Text.h
//  GCDrawKit
//
//  Created by graham on 05/02/2009.
//  Copyright 2009 Apptree.net. All rights reserved.
//

#import <Cocoa/Cocoa.h>

// bezier path category:

@interface NSBezierPath (TextOnPath)

+ (NSLayoutManager*)	textOnPathLayoutManager;
+ (NSDictionary*)		textOnPathDefaultAttributes;
+ (void)				setTextOnPathDefaultAttributes:(NSDictionary*) attrs;

// drawing text along a path - high level methods that use a default layout manager and don't use a cache:

- (BOOL)				drawTextOnPath:(NSAttributedString*) str yOffset:(CGFloat) dy;
- (BOOL)				drawStringOnPath:(NSString*) str;
- (BOOL)				drawStringOnPath:(NSString*) str attributes:(NSDictionary*) attrs;

// more advanced method called by the others allows use of different layout managers and cached information for better efficiency. If an object passes back the same
// cache each time, text-on-path rendering avoids recalculating several things. The caller is responsible for invalidating the cache if the actual string
// content to be drawn has changed, but the path will detect changes to itself automatically.

- (BOOL)				drawTextOnPath:(NSAttributedString*) str yOffset:(CGFloat) dy layoutManager:(NSLayoutManager*) lm cache:(NSMutableDictionary*) cache;

// obtaining the paths of the glyphs laid out on the path

- (NSArray*)			bezierPathsWithGlyphsOnPath:(NSAttributedString*) str yOffset:(CGFloat) dy;
- (NSBezierPath*)		bezierPathWithTextOnPath:(NSAttributedString*) str yOffset:(CGFloat) dy;

- (NSBezierPath*)		bezierPathWithStringOnPath:(NSString*) str;
- (NSBezierPath*)		bezierPathWithStringOnPath:(NSString*) str attributes:(NSDictionary*) attrs;

// low-level glyph layout method called by all other methods to generate the glyphs. The result depends on the helper object which must conform
// to the textOnPathPlacement informal protocol (see below)

- (BOOL)				layoutStringOnPath:(NSTextStorage*) str
								   yOffset:(CGFloat) dy
						 usingLayoutHelper:(id) helperObject
							 layoutManager:(NSLayoutManager*) lm
									 cache:(NSMutableDictionary*) cache;

- (void)				kernText:(NSTextStorage*) text toFitLength:(CGFloat) length;
- (NSTextStorage*)		preadjustedTextStorageWithString:(NSAttributedString*) str layoutManager:(NSLayoutManager*) lm;

// drawing underline and strikethrough paths

- (void)				drawUnderlinePathForLayoutManager:(NSLayoutManager*) lm yOffset:(CGFloat) dy cache:(NSMutableDictionary*) cache;
- (void)				drawStrikethroughPathForLayoutManager:(NSLayoutManager*) lm yOffset:(CGFloat) dy cache:(NSMutableDictionary*) cache;
- (void)				drawUnderlinePathForLayoutManager:(NSLayoutManager*) lm range:(NSRange) range yOffset:(CGFloat) dy cache:(NSMutableDictionary*) cache;
- (void)				drawStrikethroughPathForLayoutManager:(NSLayoutManager*) lm range:(NSRange) range yOffset:(CGFloat) dy cache:(NSMutableDictionary*) cache;

- (void)				pathPosition:(CGFloat*) start andLength:(CGFloat*) length forCharactersOfString:(NSAttributedString*) str inRange:(NSRange) range;
- (NSArray*)			descenderBreaksForString:(NSAttributedString*) str range:(NSRange) range underlineOffset:(CGFloat) offset;
- (NSBezierPath*)		textLinePathWithMask:(NSInteger) mask
						  startPosition:(CGFloat) sp
								 length:(CGFloat) length
								 offset:(CGFloat) offset
						  lineThickness:(CGFloat) lineThickness
						descenderBreaks:(NSArray*) breaks
						  grotThreshold:(CGFloat) gt;

// getting text layout rects for running text within a shape

- (NSArray*)			intersectingPointsWithHorizontalLineAtY:(CGFloat) yPosition;
- (NSArray*)			lineFragmentRectsForFixedLineheight:(CGFloat) lineHeight;
- (NSRect)				lineFragmentRectForProposedRect:(NSRect) aRect remainingRect:(NSRect*) rem;
- (NSRect)				lineFragmentRectForProposedRect:(NSRect) aRect remainingRect:(NSRect*) rem datumOffset:(CGFloat) dOffset;

// drawing/placing/moving anything along a path:

- (NSArray*)			placeObjectsOnPathAtInterval:(CGFloat) interval factoryObject:(id) object userInfo:(void*) userInfo;
- (NSBezierPath*)		bezierPathWithObjectsOnPathAtInterval:(CGFloat) interval factoryObject:(id) object userInfo:(void*) userInfo;
- (NSBezierPath*)		bezierPathWithPath:(NSBezierPath*) path atInterval:(CGFloat) interval;
- (NSBezierPath*)		bezierPathWithPath:(NSBezierPath*) path atInterval:(CGFloat) interval phase:(CGFloat) phase alternate:(BOOL) alt taperDelegate:(id) taperDel;

// placing "chain links" along a path:

- (NSArray*)			placeLinksOnPathWithLinkLength:(CGFloat) ll factoryObject:(id) object userInfo:(void*) userInfo;
- (NSArray*)			placeLinksOnPathWithEvenLinkLength:(CGFloat) ell oddLinkLength:(CGFloat) oll factoryObject:(id) object userInfo:(void*) userInfo;

// easy motion method:

- (void)				moveObject:(id) object atSpeed:(CGFloat) speed loop:(BOOL) loop userInfo:(id) userInfo;


@end

#pragma mark -


// informal protocol for placing objects at linear intervals along a bezier path. Will be called from placeObjectsOnPathAtInterval:withObject:userInfo:
// the <object> is called with this method if it implements it.

// the second method can be used to implement fluid motion along a path using the moveObject:alongPathDistance:inTime:userInfo: method.

// the links method is used to implement chain effects from the "placeLinks..." method.

@interface NSObject (BezierPlacement)

- (id)					placeObjectAtPoint:(NSPoint) p onPath:(NSBezierPath*) path position:(CGFloat) pos slope:(CGFloat) slope userInfo:(void*) userInfo;
- (BOOL)				moveObjectTo:(NSPoint) p position:(CGFloat) pos slope:(CGFloat) slope userInfo:(id) userInfo;
- (id)					placeLinkFromPoint:(NSPoint) pa toPoint:(NSPoint) pb onPath:(NSBezierPath*) path linkNumber:(NSInteger) lkn userInfo:(void*) userInfo;

@end


#pragma mark -

// when laying out glyphs on the path, a helper object with this informal protocol is used. The object can process the glyph appropriately, for example
// just drawing it after applying a transform, or accumulating the glyph path. An object implementing this protocol is passed internally by the text on
// path methods as necessary, or you can supply one. 

@interface NSObject (TextOnPathPlacement)

- (void)				layoutManager:(NSLayoutManager*) lm willPlaceGlyphAtIndex:(NSUInteger) glyphIndex atLocation:(NSPoint) location pathAngle:(CGFloat) angle yOffset:(CGFloat) dy;

@end


#pragma mark -

// when using a tapering method, the taper callback object must implement the following informal protocol

@interface NSObject (TaperPathDelegate)

- (CGFloat)				taperFactorAtDistance:(CGFloat) distance onPath:(NSBezierPath*) path ofLength:(CGFloat) length;
@end



#pragma mark -

// helper objects used internally when accumulating or laying glyphs

@interface DKTextOnPathGlyphAccumulator	: NSObject
{
	NSMutableArray*		mGlyphs;
}

- (NSArray*)			glyphs;
- (void)				layoutManager:(NSLayoutManager*) lm willPlaceGlyphAtIndex:(NSUInteger) glyphIndex atLocation:(NSPoint) location pathAngle:(CGFloat) angle yOffset:(CGFloat) dy;

@end


#pragma mark -

// this just applies the transform and causes the layout manager to draw the glyph. This ensures that all the stylistic variations on the glyph are applied allowing
// attributed strings to be drawn along the path.

@interface DKTextOnPathGlyphDrawer	: NSObject

- (void)				layoutManager:(NSLayoutManager*) lm willPlaceGlyphAtIndex:(NSUInteger) glyphIndex atLocation:(NSPoint) location pathAngle:(CGFloat) angle yOffset:(CGFloat) dy;

@end


#pragma mark -

// this helper calculates the start and length of a given run of characters in the string. The character range should be set prior to use. As each glyph is laid, the
// glyph run position and length along the line fragment rectangle is calculated.

@interface DKTextOnPathMetricsHelper : NSObject
{
	CGFloat		mStartPosition;
	CGFloat		mLength;
	NSRange		mCharacterRange;
}

- (void)				setCharacterRange:(NSRange) range;
- (CGFloat)				length;
- (CGFloat)				position;
- (void)				layoutManager:(NSLayoutManager*) lm willPlaceGlyphAtIndex:(NSUInteger) glyphIndex atLocation:(NSPoint) location pathAngle:(CGFloat) angle yOffset:(CGFloat) dy;

@end


#pragma mark -

// this is a small wrapper object used to cache information about locations on a path, to save recalculating them each time.

@interface DKPathGlyphInfo : NSObject
{
	NSUInteger	mGlyphIndex;
	NSPoint		mPoint;
	CGFloat		mSlope;
}

- (id)			initWithGlyphIndex:(NSUInteger) glyphIndex position:(NSPoint) pt slope:(CGFloat) slope;
- (NSUInteger)	glyphIndex;
- (CGFloat)		slope;
- (NSPoint)		point;


@end


#pragma mark -

// category on NSFont used to fudge the underline offset for invalid fonts. Apparently this is what Apple do also, though currently the
// definition of "invalid font" is not known with any precision. Currently underline offsets of 0 will use this value instead

@interface NSFont (DKUnderlineCategory)

- (CGFloat)	valueForInvalidUnderlinePosition;
- (CGFloat)	valueForInvalidUnderlineThickness;

@end


