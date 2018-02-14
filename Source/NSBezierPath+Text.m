/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import "NSBezierPath+Text.h"
#import "NSBezierPath+Geometry.h"
#import "NSBezierPath+Editing.h"
#import "DKGeometryUtilities.h"
#import "NSShadow+Scaling.h"
#import "DKBezierLayoutManager.h"
#include <tgmath.h>

@interface NSBezierPath (TextOnPathPrivate)

/** @brief Timer callback used by -moveObject:atSpeed:loop:userInfo

 The object must respond to the informal motion protocol.
 @param timer the timer
 */
- (void)motionCallback:(NSTimer*)timer;

@end

// keys used for data in private cache

static NSString* kDKTextOnPathGlyphPositionCacheKey = @"DKTextOnPathGlyphPositions";
static NSString* kDKTextOnPathChecksumCacheKey = @"DKTextOnPathChecksum";
static NSString* kDKTextOnPathTextFittedCacheKey = @"DKTextOnPathTextFitted";

@implementation NSBezierPath (TextOnPath)

/** @brief Returns a layout manager used for text on path layout.

 This shared layout manager is used by text on path drawing unless a specific manager is passed.
 @return a shared layout manager instance */
+ (NSLayoutManager*)textOnPathLayoutManager
{
	// returns a layout manager instance which is used for all text on path layout tasks. Reusing this shared instance saves a little time and memory

	static NSLayoutManager* topLayoutMgr = nil;

	if (topLayoutMgr == nil) {
		topLayoutMgr = [[NSLayoutManager alloc] init];
		NSTextContainer* tc = [[NSTextContainer alloc] initWithContainerSize:NSMakeSize(1.0e6, 1.0e6)];
		[topLayoutMgr addTextContainer:tc];

		[topLayoutMgr setUsesScreenFonts:NO];
	}

	return topLayoutMgr;
}

static NSDictionary* s_TOPTextAttributes = nil;

/** @brief Returns the attributes used to draw strings on paths.

 The default is 12 point Helvetica Roman black text with the default paragraph style.
 @return a dictionary of string attributes */
+ (NSDictionary*)textOnPathDefaultAttributes
{
	if (s_TOPTextAttributes == nil) {
		NSFont* font = [NSFont fontWithName:@"Helvetica"
									   size:12.0];
		s_TOPTextAttributes = @{NSFontAttributeName: font};
	}

	return s_TOPTextAttributes;
}

/** @brief Sets the attributes used to draw strings on paths.

 Pass nil to set the default. The attributes are used by the drawStringOnPath: method.
 @param attrs a dictionary of text attributes */
+ (void)setTextOnPathDefaultAttributes:(NSDictionary*)attrs
{
	s_TOPTextAttributes = attrs;
}

#pragma mark -
#pragma mark - drawing text along a path(high level)

/** @brief Renders a string on a path.

 Positive values of dy place the text's baseline above the path, negative below it, where 'above'
 and 'below' are in the expected sense relative to the orientation of the drawn glyphs. This is the
 highest-level attributed text on path drawing method, and uses the shared layout mamanger and no cache.
 @param str the attributed string to render
 @param dy the offset between the path and the text's baseline when drawn.
 @return YES if the text was fully laid out, NO if some text could not be drawn (for example because it
 would not all fit on the path). */
- (BOOL)drawTextOnPath:(NSAttributedString*)str yOffset:(CGFloat)dy
{
	return [self drawTextOnPath:str
						yOffset:dy
				  layoutManager:nil
						  cache:nil];
}

/** @brief Renders a string on a path.

 Passing nil for the layout manager uses the shared layout manager. If the same cache is passed back
 each time by the client code, certain calculations are cached there which can speed up drawing. The
 client owns the cache and is responsible for invalidating it (setting it empty) when text content changes.
 However the client code doesn't need to consider path changes - they are handled automatically.
 @param str the attributed string to render
 @param dy the offset between the path and the text's baseline when drawn.
 @param lm the layout manager to use for layout
 @param cache an optional cache dictionary (must be a valid mutable dictionary, or nil)
 @return YES if the text was fully laid out, NO if some text could not be drawn (for example because it
 would not all fit on the path). */
- (BOOL)drawTextOnPath:(NSAttributedString*)str yOffset:(CGFloat)dy layoutManager:(NSLayoutManager*)lm cache:(NSMutableDictionary*)cache
{
	NSUInteger cachedCS = [[cache objectForKey:kDKTextOnPathChecksumCacheKey] integerValue];
	NSUInteger CS = [self checksum];

	if (cachedCS != CS) {
		// path has changed so cache is unreliable.
		//NSLog(@"cs mismatch, invalidating cache (old = %@, new cs = %d)", cache, CS );

		// don't remove if value is 0, as that implies cache was already cleared externally, and may contain other informaiton of importance or
		// use the the external client (Alternatively we should remove only the keys that we know are ours, but this is currently quite hard due to the
		// dynamic nature of some of the keys, and the fact that the items are not grouped in any way.).

		if (cachedCS != 0)
			[cache removeAllObjects];

		[cache setObject:@(CS)
				  forKey:kDKTextOnPathChecksumCacheKey];
	}

	BOOL usingStandardLM = NO;

	if (lm == nil) {
		lm = [[self class] textOnPathLayoutManager];
		usingStandardLM = YES;
	}

	NSTextStorage* text = [self preadjustedTextStorageWithString:str
												   layoutManager:lm];

	[self drawUnderlinePathForLayoutManager:lm
									yOffset:dy
									  cache:cache];

	// remove underline and strikethrough attributes from what the layout will use so they aren't drawn again:

	[text removeAttribute:NSUnderlineStyleAttributeName
					range:NSMakeRange(0, [text length])];
	[text removeAttribute:NSStrikethroughStyleAttributeName
					range:NSMakeRange(0, [text length])];

	DKTextOnPathGlyphDrawer* gd = [[DKTextOnPathGlyphDrawer alloc] init];
	BOOL result = [self layoutStringOnPath:text
								   yOffset:dy
						 usingLayoutHelper:gd
							 layoutManager:lm
									 cache:cache];

	// draw strikethrough attributes based on the original string

	if (usingStandardLM) {
		text = [self preadjustedTextStorageWithString:str
										layoutManager:lm];
		[self drawStrikethroughPathForLayoutManager:lm
											yOffset:dy
											  cache:cache];
	}

	return result;
}

/** @brief Renders a string on a path.

 Very high-level, draws the string on the path using the set class attributes.
 @param str the  string to render
 @return YES if the text was fully laid out, NO if some text could not be drawn (for example because it
 would not all fit on the path). */
- (BOOL)drawStringOnPath:(NSString*)str
{
	return [self drawStringOnPath:str
					   attributes:nil];
}

/** @brief Renders a string on a path.

 If attrs is nil, uses the current class attributes
 @param str the  string to render
 @param attrs the attributes to use to draw the string - may be nil
 @return YES if the text was fully laid out, NO if some text could not be drawn (for example because it
 would not all fit on the path). */
- (BOOL)drawStringOnPath:(NSString*)str attributes:(NSDictionary*)attrs
{
	// draws a string along the path with the supplied attributes

	if (attrs == nil)
		attrs = [[self class] textOnPathDefaultAttributes];

	NSAttributedString* as = [[NSAttributedString alloc] initWithString:str
															 attributes:attrs];
	BOOL result = [self drawTextOnPath:as
							   yOffset:0];

	return result;
}

#pragma mark -
#pragma mark - obtaining the paths of the laid - out text

- (NSBezierPath*)bezierPathWithTextOnPath:(NSAttributedString*)str yOffset:(CGFloat)dy
{
	// returns the laid out glyphs as a single path for the entire laid out string

	NSEnumerator* iter = [[self bezierPathsWithGlyphsOnPath:str
													yOffset:dy] objectEnumerator];
	NSBezierPath* path = [NSBezierPath bezierPath];

	for (NSBezierPath* temp in iter)
		[path appendBezierPath:temp];

	return path;
}

- (NSArray*)bezierPathsWithGlyphsOnPath:(NSAttributedString*)str yOffset:(CGFloat)dy
{
	// returns the laid out glyphs as an array of separate paths

	DKTextOnPathGlyphAccumulator* ga = [[DKTextOnPathGlyphAccumulator alloc] init];
	NSLayoutManager* lm = [[self class] textOnPathLayoutManager];
	NSTextStorage* text = [self preadjustedTextStorageWithString:str
												   layoutManager:lm];

	[self layoutStringOnPath:text
					 yOffset:dy
		   usingLayoutHelper:ga
			   layoutManager:lm
					   cache:nil];
	return [ga glyphs];
}

- (NSBezierPath*)bezierPathWithStringOnPath:(NSString*)str
{
	// returns the path of the string laid out on the path with default attributes

	return [self bezierPathWithStringOnPath:str
								 attributes:nil];
}

- (NSBezierPath*)bezierPathWithStringOnPath:(NSString*)str attributes:(NSDictionary*)attrs
{
	// returns the path of the laid out string with the given attributes

	if (attrs == nil)
		attrs = [[self class] textOnPathDefaultAttributes];

	NSAttributedString* as = [[NSAttributedString alloc] initWithString:str
															 attributes:attrs];
	NSBezierPath* np = [self bezierPathWithTextOnPath:as
											  yOffset:0];
	return np;
}

#pragma mark -
#pragma mark - low level glyph layout methods

- (BOOL)layoutStringOnPath:(NSTextStorage*)str
				   yOffset:(CGFloat)dy
		 usingLayoutHelper:(id<DKTextOnPathPlacement>)helperObject
			 layoutManager:(NSLayoutManager*)lm
					 cache:(NSMutableDictionary*)cache
{

	if ([self elementCount] < 2 || [str length] < 1)
		return NO; // nothing useful to do

	// if the helper is invalid, throw exception

	NSAssert(helperObject != nil, @" cannot proceed without a valid helper object");
	NSAssert(lm != nil, @"cannot proceed without a valid layout manager");

	if (![helperObject respondsToSelector:@selector(layoutManager:
											  willPlaceGlyphAtIndex:
														 atLocation:
														  pathAngle:
															yOffset:)])
		[NSException raise:NSInternalInconsistencyException
					format:@"The helper object does not implement the TextOnPathPlacement informal protocol"];

	// set the line break mode to clipping - this prevents unwanted wrapping of the text if the path is too short

	NSMutableParagraphStyle* para = [[[str attributesAtIndex:0
											  effectiveRange:NULL] valueForKey:NSParagraphStyleAttributeName] mutableCopy];
	[para setLineBreakMode:NSLineBreakByClipping];

	if (para) {
		NSDictionary* attrs = @{NSParagraphStyleAttributeName: para};
		[str addAttributes:attrs
					 range:NSMakeRange(0, [str length])];
	}

	NSTextContainer* tc = [[lm textContainers] lastObject];
	NSBezierPath* temp;
	NSUInteger glyphIndex;
	NSRect gbr;
	BOOL result = YES;

	gbr.origin = NSZeroPoint;
	gbr.size = [tc containerSize];

	NSRange glyphRange = [lm glyphRangeForBoundingRect:gbr
									   inTextContainer:tc];

	// all the layout positions and angles may be cached for more performance. An array of previously calculated glyph positions can be retrieved and
	// simply iterated to lay out the glyphs.

	NSArray* glyphCache = [cache objectForKey:kDKTextOnPathGlyphPositionCacheKey];

	if (glyphCache == nil) {
		// not cached, so work it out and cache it this time

		NSMutableArray* newGlyphCache = [NSMutableArray array];
		DKPathGlyphInfo* posInfo;
		CGFloat baseline;

		// lay down the glyphs along the path

		for (glyphIndex = glyphRange.location; glyphIndex < NSMaxRange(glyphRange); ++glyphIndex) {
			@autoreleasepool {

				NSRect lineFragmentRect = [lm lineFragmentRectForGlyphAtIndex:glyphIndex
															   effectiveRange:NULL];
				NSPoint viewLocation, layoutLocation = [lm locationForGlyphAtIndex:glyphIndex];

				// if this represents anything other than the first line, ignore it

				if (lineFragmentRect.origin.y > 0.0) {
					result = NO;
					break;
				}

				gbr = [lm boundingRectForGlyphRange:NSMakeRange(glyphIndex, 1)
									inTextContainer:tc];
				CGFloat half = NSWidth(gbr) * 0.5;

				// if the character width is zero or -ve, skip it - some control glyphs appear to need suppressing in this way.
				// Note that this prevents some kinds of accents from getting drawn - need to work out a fix for that.

				if (half > 0) {
					// get a shortened path that starts at the character location

					temp = [self bezierPathByTrimmingFromLength:NSMinX(lineFragmentRect) + layoutLocation.x + half];

					// if no more room on path, stop laying glyphs

					if ([temp length] < half) {
						result = NO;
						break;
					}

					[temp elementAtIndex:0
						associatedPoints:&viewLocation];
					CGFloat angle = [temp slopeStartingPath];

					// view location needs to be offset vertically normal to the path to account for the baseline

					baseline = NSHeight(gbr) - [[lm typesetter] baselineOffsetInLayoutManager:lm
																				   glyphIndex:glyphIndex];

					viewLocation.x -= baseline * cos(angle + NINETY_DEGREES);
					viewLocation.y -= baseline * sin(angle + NINETY_DEGREES);

					// view location needs to be projected back along the baseline tangent by half the character width to align
					// the character based on the middle of the glyph instead of the left edge

					viewLocation.x -= half * cos(angle);
					viewLocation.y -= half * sin(angle);

					// cache the glyph positioning information to avoid recalculation next time round

					posInfo = [[DKPathGlyphInfo alloc] initWithGlyphIndex:glyphIndex
																 position:viewLocation
																	slope:angle];
					[newGlyphCache addObject:posInfo];

					// call the helper object to finish off what we intend to do with this glyph

					[helperObject layoutManager:lm
						  willPlaceGlyphAtIndex:glyphIndex
									 atLocation:viewLocation
									  pathAngle:angle
										yOffset:dy];
				}

			}
		}

		[cache setObject:newGlyphCache
				  forKey:kDKTextOnPathGlyphPositionCacheKey];
		[cache setObject:@(result)
				  forKey:kDKTextOnPathTextFittedCacheKey];
	} else {
		//NSLog(@"drawing from cache, %d glyphs", [glyphCache count]);
		// glyph layout info was cached, so all we need do is to feed the information to the helper object

		for (DKPathGlyphInfo* info in glyphCache)
			[helperObject layoutManager:lm
				  willPlaceGlyphAtIndex:[info glyphIndex]
							 atLocation:[info point]
							  pathAngle:[info slope]
								yOffset:dy];

		result = [[cache objectForKey:kDKTextOnPathTextFittedCacheKey] boolValue];
	}

	return result;
}

- (void)kernText:(NSTextStorage*)text toFitLength:(CGFloat)length
{
	// adjusts the kerning of the text passed so that it fits exactly into <length>

	NSAssert(text != nil, @"oops, text storage was nil");

	NSLayoutManager* lm = [[text layoutManagers] lastObject];
	NSTextContainer* tc = [[lm textContainers] lastObject];
	NSRect gbr;

	gbr.size = NSMakeSize(length, 50000.0);
	gbr.origin = NSZeroPoint;

	// set container size so that the width is the path's length - this will honour left/right/centre paragraphs setting
	// and truncate at the end of the last whole word that can be fitted.

	[tc setContainerSize:gbr.size];
	NSRange glyphRange = [lm glyphRangeForBoundingRect:gbr
									   inTextContainer:tc];

	// if we are kerning to fit, calculate the kerning amount needed and set it up

	NSRect fragRect = [lm lineFragmentUsedRectForGlyphAtIndex:0
											   effectiveRange:NULL];
	CGFloat kernAmount = (gbr.size.width - fragRect.size.width) / (CGFloat)(glyphRange.length - 1);

	if (kernAmount <= 0) {
		// to squeeze the text down, we now need to know how much space the line would require if the text container weren't constraining it.

		NSSize strSize = [text size];
		kernAmount = (gbr.size.width - strSize.width) / (CGFloat)(glyphRange.length - 1);

		// limit the amount to keep text readable. Once the limit is hit, the text will get clipped off beyond the end of the path.
		// the limit is related to the point size of the glyph which in turn is already encoded in the line height. The value here is
		// derived empirically to give text that is just about readable at the limit.

		CGFloat kernLimit = strSize.height * -0.15;

		if (kernAmount < kernLimit)
			kernAmount = kernLimit;
	}

	NSDictionary* kernAttributes = @{NSKernAttributeName: @(kernAmount)};
	NSRange charRange = [lm characterRangeForGlyphRange:glyphRange
									   actualGlyphRange:NULL];
	[text addAttributes:kernAttributes
				  range:charRange];
}

- (NSTextStorage*)preadjustedTextStorageWithString:(NSAttributedString*)str layoutManager:(NSLayoutManager*)lm
{
	NSAssert(lm != nil, @"nil layout manager passed while processing text on path");
	NSAssert(str != nil, @"nil string passed while processing text on path");

	NSTextContainer* tc = [[lm textContainers] lastObject];

	NSAssert(tc != nil, @" no text container was present in the layout manager");

	// determine whether the text needs to be kerned to fit - yes if the alignment is 'justified'

	NSParagraphStyle* para = [str attribute:NSParagraphStyleAttributeName
									atIndex:0
							 effectiveRange:NULL];
	BOOL autoKern = ([para alignment] == NSJustifiedTextAlignment);

	NSTextStorage* text = [[NSTextStorage alloc] initWithAttributedString:str];
	[text addLayoutManager:lm];

	// wrap the text within the line length but set the height to some arbitrarily large value.
	// lines beyond the first are ignored anyway, regardless of lineheight.

	CGFloat pathLength = [self length];

	// set container size so that the width is the path's length - this will honour left/right/centre paragraphs setting
	// and truncate at the end of the last whole word that can be fitted.

	[tc setContainerSize:NSMakeSize(pathLength, 50000)];

	// apply kerning to fit if necessary

	if (autoKern)
		[self kernText:text
			toFitLength:pathLength];

	return text;
}

#pragma mark -
#pragma mark - drawing underlines and strikethroughs

- (void)drawUnderlinePathForLayoutManager:(NSLayoutManager*)lm yOffset:(CGFloat)dy cache:(NSMutableDictionary*)cache
{
	NSRange effectiveRange = NSMakeRange(0, 0);
	NSUInteger rangeLimit = 0;
	NSNumber* ul;

	while (rangeLimit < [[lm textStorage] length]) {
		ul = [[lm textStorage] attribute:NSUnderlineStyleAttributeName
								 atIndex:rangeLimit
						  effectiveRange:&effectiveRange];

		if (ul && [ul integerValue] > 0)
			[self drawUnderlinePathForLayoutManager:lm
											  range:effectiveRange
											yOffset:dy
											  cache:cache];

		rangeLimit = NSMaxRange(effectiveRange);
	}
}

- (void)drawStrikethroughPathForLayoutManager:(NSLayoutManager*)lm yOffset:(CGFloat)dy cache:(NSMutableDictionary*)cache
{
	NSRange effectiveRange = NSMakeRange(0, 0);
	NSUInteger rangeLimit = 0;
	NSNumber* ul;

	while (rangeLimit < [[lm textStorage] length]) {
		ul = [[lm textStorage] attribute:NSStrikethroughStyleAttributeName
								 atIndex:rangeLimit
						  effectiveRange:&effectiveRange];

		if (ul && [ul integerValue] > 0)
			[self drawStrikethroughPathForLayoutManager:lm
												  range:effectiveRange
												yOffset:dy
												  cache:cache];

		rangeLimit = NSMaxRange(effectiveRange);
	}
}

- (void)drawUnderlinePathForLayoutManager:(NSLayoutManager*)lm range:(NSRange)range yOffset:(CGFloat)dy cache:(NSMutableDictionary*)cache
{
	NSAttributedString* str = [lm textStorage];
	NSFont* font = [str attribute:NSFontAttributeName
						  atIndex:0
				   effectiveRange:NULL]; // UL thickness taken from first character on line regardless
	NSInteger ulAttribute = [[str attribute:NSUnderlineStyleAttributeName
										atIndex:range.location
								 effectiveRange:NULL] integerValue];
	CGFloat ulOffset, ulThickness = [font underlineThickness];
	CGFloat start, length, grot;
	NSBezierPath* ulp;

// see if the path we need is cached, in which case we can avoid recomputing it. Because there could be several different paths that apply to ranges,
// the cache key is generated from the various parameters

	NSString* pathKey = [NSString stringWithFormat:@"DKUnderlinePath_%@_%.2f", NSStringFromRange(range), dy];
	ulp = [cache objectForKey:pathKey];

	if (ulp == nil) {
		// Apple's text rendering appears to ignore the font's underlinePosition and instead relies on some internal magic in NSTypesetter. For parity, we'll try and
		// do the same. By trial and error it appears as if the underline position is set to half the baseline offset returned by the typesetter. However this must ignore
		// any subscripted parts which don't affect the underline (but do break it).

		// layout without superscripts and subscripts:

		NSLayoutManager* tempLM = [[NSLayoutManager alloc] init];
		[tempLM addTextContainer:[[lm textContainers] lastObject]];
		NSTextStorage* tempStr = [[NSTextStorage alloc] initWithAttributedString:str];
		[tempStr removeAttribute:NSSuperscriptAttributeName
						   range:NSMakeRange(0, [tempStr length])];
		[tempStr addLayoutManager:tempLM];

		NSUInteger glyphIndex = [tempLM glyphIndexForCharacterAtIndex:range.location];
		ulOffset = [[tempLM typesetter] baselineOffsetInLayoutManager:tempLM
														   glyphIndex:glyphIndex] * -0.5;

		// if the underline metrics aren't set for the font, use an average of those for Times + Helvetica for the same point size. According to Apple that's what
		// they do, though it's not clear if just a value of 0 is considered bad, as there are discrepancies with certain fonts.

		if (ulThickness <= 0)
			ulThickness = [font valueForInvalidUnderlineThickness];

		[self pathPosition:&start
						andLength:&length
			forCharactersOfString:str
						  inRange:range];

		// breaks can also be cached separately. It's unusual that the breaks would exist without the path in the cache, but we'll permit that to
		// be possible.

		NSArray* descenderBreaks;
		NSString* breaksKey = [NSString stringWithFormat:@"DKUnderlineBreaks_%@_%.2f", NSStringFromRange(range), ulOffset];
		descenderBreaks = [cache objectForKey:breaksKey];

		if (descenderBreaks == nil) {
			descenderBreaks = [self descenderBreaksForString:str
													   range:range
											 underlineOffset:ulOffset];
			if (descenderBreaks)
				[cache setObject:descenderBreaks
						  forKey:breaksKey];
		}

		//NSLog(@"descender breaks; %@", descenderBreaks);
		//NSLog(@"will draw underline from: %.3f to: %.3f; path length = %.3f, character range = %@", start, start + length, [self length], NSStringFromRange( range ));

		// to arrive at a sensible grot value, we need some measure of the average character width of the string. To do this we take the width of the glyph run
		// and divide by the number of characters in the range, and then apply a scaling.

		NSPoint glyphPosition = [lm locationForGlyphAtIndex:glyphIndex];

		CGFloat runWidth = glyphPosition.x;
		glyphIndex = [lm glyphIndexForCharacterAtIndex:NSMaxRange(range) - 1];
		glyphPosition = [lm locationForGlyphAtIndex:glyphIndex];
		runWidth = glyphPosition.x - runWidth;

		grot = (runWidth * 0.67) / (CGFloat)(range.length - 1);

		ulp = [self textLinePathWithMask:ulAttribute
						   startPosition:start
								  length:length
								  offset:dy + ulOffset
						   lineThickness:ulThickness
						 descenderBreaks:descenderBreaks
						   grotThreshold:grot];

		if (ulp)
			[cache setObject:ulp
					  forKey:pathKey];
	}
	//else
	//	NSLog(@"drawing cached underline path (cache key = %@)", pathKey );

	// what colour to draw it in. Unless explicitly set, use foreground colour.

	NSColor* ulc = [str attribute:NSUnderlineColorAttributeName
						  atIndex:range.location
				   effectiveRange:NULL];

	if (ulc == nil)
		ulc = [str attribute:NSForegroundColorAttributeName
					 atIndex:range.location
			  effectiveRange:NULL];

	if (ulc == nil)
		ulc = [NSColor blackColor];

	// any text shadow?

	NSShadow* shad = [str attribute:NSShadowAttributeName
							atIndex:range.location
					 effectiveRange:NULL];

	SAVE_GRAPHICS_CONTEXT

	if (shad)
		[shad set];

	[ulc set];
	[ulp stroke];

	RESTORE_GRAPHICS_CONTEXT
}

- (void)drawStrikethroughPathForLayoutManager:(NSLayoutManager*)lm range:(NSRange)range yOffset:(CGFloat)dy cache:(NSMutableDictionary*)cache
{
	NSAttributedString* str = [lm textStorage];
	NSFont* font = [str attribute:NSFontAttributeName
						  atIndex:0
				   effectiveRange:NULL];
	NSInteger ulAttribute = [[str attribute:NSStrikethroughStyleAttributeName
										atIndex:range.location
								 effectiveRange:NULL] integerValue];
	CGFloat start, length;
	CGFloat xHeight = [font xHeight];
	CGFloat ulThickness = [font underlineThickness];
	NSBezierPath* ulp;

// see if we can reuse a previously cached path here

	NSString* pathKey = [NSString stringWithFormat:@"DKStrikethroughPath_%@_%.2f", NSStringFromRange(range), dy];
	ulp = [cache objectForKey:pathKey];

	if (ulp == nil) {
		// calculate the strikethrough position. Must take into account the true baseline of the glyphs because
		// if they are superscripted, the strikethrough must be positioned accordingly.

		NSUInteger glyphIndex = [lm glyphIndexForCharacterAtIndex:range.location];
		NSRect gbr = [lm boundingRectForGlyphRange:NSMakeRange(glyphIndex, 1)
								   inTextContainer:[[lm textContainers] lastObject]];
		CGFloat base = NSHeight(gbr) - [[lm typesetter] baselineOffsetInLayoutManager:lm
																		   glyphIndex:glyphIndex];
		NSPoint loc = [lm locationForGlyphAtIndex:glyphIndex];

		base -= loc.y;

		[self pathPosition:&start
						andLength:&length
			forCharactersOfString:str
						  inRange:range];

		ulp = [self textLinePathWithMask:ulAttribute
						   startPosition:start
								  length:length
								  offset:base + dy + (xHeight * 0.5)
						   lineThickness:ulThickness
						 descenderBreaks:nil
						   grotThreshold:0];

		if (ulp)
			[cache setObject:ulp
					  forKey:pathKey];
	}

	// what colour to draw it in. Unless explicitly set, use foreground colour.

	NSColor* ulc = [str attribute:NSStrikethroughColorAttributeName
						  atIndex:range.location
				   effectiveRange:NULL];

	if (ulc == nil)
		ulc = [str attribute:NSForegroundColorAttributeName
					 atIndex:range.location
			  effectiveRange:NULL];

	if (ulc == nil)
		ulc = [NSColor blackColor];

	// any text shadow?

	NSShadow* shad = [str attribute:NSShadowAttributeName
							atIndex:range.location
					 effectiveRange:NULL];

	SAVE_GRAPHICS_CONTEXT

	if (shad)
		[shad set];

	[ulc set];
	[ulp stroke];

	RESTORE_GRAPHICS_CONTEXT
}

- (void)pathPosition:(CGFloat*)start andLength:(CGFloat*)length forCharactersOfString:(NSAttributedString*)str inRange:(NSRange)range
{
	if (start == nil || length == nil)
		return;

	DKTextOnPathMetricsHelper* mh = [[DKTextOnPathMetricsHelper alloc] init];
	[mh setCharacterRange:range];

	[self layoutStringOnPath:(NSTextStorage*)str
					 yOffset:0
		   usingLayoutHelper:mh
			   layoutManager:[[self class] textOnPathLayoutManager]
					   cache:nil];

	*start = [mh position];
	*length = [mh length];
}

- (NSArray*)descenderBreaksForString:(NSAttributedString*)str range:(NSRange)range underlineOffset:(CGFloat)offset
{
	// returns a list of NSPoint values which are the places where an underline attribute intersects the descenders of <str> within <range>.
	// This works by obtaining the path of the glyphs in the range then intersecting the underline Y offset with it. As such it's likely to be slow.
	// The offsets are relative to the beginning of the text. The <offset<> is the distance from the baseline to the underline as derived from the
	// font in use.

	NSTextStorage* subString = [[NSTextStorage alloc] initWithAttributedString:[str attributedSubstringFromRange:range]];

	DKBezierLayoutManager* lm = [[DKBezierLayoutManager alloc] init];
	NSTextContainer* btc = [[NSTextContainer alloc] initWithContainerSize:NSMakeSize(1.0e6, 1.0e6)];
	[lm addTextContainer:btc];
	[subString setAlignment:NSLeftTextAlignment
					  range:NSMakeRange(0, range.length)];
	[subString addLayoutManager:lm];

	NSRange glyphRange = [lm glyphRangeForTextContainer:btc];
	[lm drawGlyphsForGlyphRange:glyphRange
						atPoint:NSZeroPoint];

	// find the baseline for the glyph which is where the underline is placed relative to

	CGFloat baseline = [[lm typesetter] baselineOffsetInLayoutManager:lm
														   glyphIndex:glyphRange.location];
	NSRect lineFrag = [lm lineFragmentRectForGlyphAtIndex:glyphRange.location
										   effectiveRange:NULL];
	CGFloat yOffset = NSHeight(lineFrag) - baseline + fabs(offset);

	NSBezierPath* glyphPath = [lm textPath];
	NSArray* result = [glyphPath intersectingPointsWithHorizontalLineAtY:yOffset];

	return result;
}

#define DESCENDER_BREAK_PADDING 3
#define DESCENDER_BREAK_OFFSET -5

- (NSBezierPath*)textLinePathWithMask:(NSUnderlineStyle)mask
						startPosition:(CGFloat)sp
							   length:(CGFloat)length
							   offset:(CGFloat)offset
						lineThickness:(CGFloat)lineThickness
					  descenderBreaks:(NSArray*)breaks
						grotThreshold:(CGFloat)gt
{
	// extract the path we are based on. Note: underline by word is not yet supported.

	if ((mask & 0x0F) == NSUnderlineStyleNone)
		return nil;

	// line width is between 3 and 4% of the point size
	// if we require a double line, add another offset path. The mask is 0x09 (1001) but the lower 1 indicates the first line, so we mask with 8 (1000).

	BOOL isDouble = (mask & 0x08);

	if (mask & NSUnderlineStyleThick)
		lineThickness *= 2.0;

	if (isDouble) {
		lineThickness *= 0.75;
		offset += (lineThickness * 0.5);
	}

	NSBezierPath* trimmedPath;

	// factor in any descender breaks if we have them. Each break alternates between the start of a break and the resumption of the line.

	if (breaks && [breaks count] > 0) {
		NSEnumerator* iter = [breaks objectEnumerator];
		NSValue* breakVal;
		CGFloat pos, breakOffset, padding;
		BOOL hadFirst = NO;

		trimmedPath = [NSBezierPath bezierPath];
		pos = sp;

		padding = gt * 0.3;

		while ((breakVal = [iter nextObject])) {
			breakOffset = sp + [breakVal pointValue].x - padding + DESCENDER_BREAK_OFFSET;

			if ((breakOffset - pos) > gt || !hadFirst)
				[trimmedPath appendBezierPath:[self bezierPathByTrimmingFromLength:pos
																		  toLength:breakOffset - pos]];

			breakVal = [iter nextObject];
			if (breakVal)
				pos = sp + [breakVal pointValue].x + padding + DESCENDER_BREAK_OFFSET;

			hadFirst = YES;
		}

		if ((sp + length - pos) > gt || !hadFirst)
			[trimmedPath appendBezierPath:[self bezierPathByTrimmingFromLength:pos
																	  toLength:sp + length - pos]];
	} else
		trimmedPath = [self bezierPathByTrimmingFromLength:sp
												  toLength:length];

	[trimmedPath setFlatness:0.1];
	CGFloat savedFlatness = [NSBezierPath defaultFlatness];
	[NSBezierPath setDefaultFlatness:0.1];

	// parallel offset has opposite sign to text offset

	trimmedPath = [trimmedPath paralleloidPathWithOffset2:-offset];
	[trimmedPath setLineWidth:lineThickness];

	if (isDouble) {
		NSBezierPath* bp = [trimmedPath paralleloidPathWithOffset2:2.0 * lineThickness];
		[trimmedPath appendBezierPath:bp];
	}

	[NSBezierPath setDefaultFlatness:savedFlatness];

	if (mask & 0x0F00) {
		// some dash pattern is indicated, so work it out and apply it

		CGFloat dashPattern[6];
		NSInteger count = 0;

		switch (mask & 0x0F00) {
		default:
		case NSUnderlinePatternDot:
			dashPattern[0] = dashPattern[1] = 1.0;
			count = 2;
			break;

		case NSUnderlinePatternDash:
			dashPattern[0] = 4.0;
			dashPattern[1] = 2.0;
			count = 2;
			break;

		case NSUnderlinePatternDashDot:
			dashPattern[0] = 4.0;
			dashPattern[1] = 2.0;
			dashPattern[2] = 1.0;
			dashPattern[3] = 2.0;
			count = 4;
			break;

		case NSUnderlinePatternDashDotDot:
			dashPattern[0] = 4.0;
			dashPattern[1] = 2.0;
			dashPattern[2] = 1.0;
			dashPattern[3] = 2.0;
			dashPattern[4] = 1.0;
			dashPattern[5] = 2.0;
			count = 6;
			break;
		}
		[trimmedPath setLineDash:dashPattern
						   count:count
						   phase:0.0];
	}

	return trimmedPath;
}

#pragma mark -
#pragma mark - drawing / placing / moving anything along a path

- (NSArray*)placeObjectsOnPathAtInterval:(CGFloat)interval factoryObject:(id<DKBezierPlacement>)object userInfo:(void*)userInfo
{
	if (![object respondsToSelector:@selector(placeObjectAtPoint:
														  onPath:
														position:
														   slope:
														userInfo:)])
		[NSException raise:NSInvalidArgumentException
					format:@"Factory object %@ does not implement the required protocol", object];

	if ([self elementCount] < 2 || interval <= 0)
		return nil;

	NSMutableArray* array = [[NSMutableArray alloc] init];
	NSPoint p;
	CGFloat slope, distance, length;
	id placedObject;

	distance = 0;

	length = [self length];

	while (distance <= length) {
		p = [self pointOnPathAtLength:distance
								slope:&slope];

		placedObject = [object placeObjectAtPoint:p
										   onPath:self
										 position:distance
											slope:slope
										 userInfo:userInfo];

		if (placedObject)
			[array addObject:placedObject];

		distance += interval;
	}

	return array;
}

- (NSBezierPath*)bezierPathWithObjectsOnPathAtInterval:(CGFloat)interval factoryObject:(id)object userInfo:(void*)userInfo
{
	// as above, but where the returned objects are in themselves paths, they are appended into one general path and returned.

	if ([self elementCount] < 2 || interval <= 0)
		return nil;

	NSBezierPath* newPath = nil;
	NSArray* placedObjects = [self placeObjectsOnPathAtInterval:interval
												  factoryObject:object
													   userInfo:userInfo];

	if ([placedObjects count] > 0) {
		newPath = [NSBezierPath bezierPath];

		for (id obj in placedObjects) {
			if ([obj isKindOfClass:[NSBezierPath class]])
				[newPath appendBezierPath:obj];
		}
	}

	return newPath;
}

- (NSBezierPath*)bezierPathWithPath:(NSBezierPath*)path atInterval:(CGFloat)interval
{
	return [self bezierPathWithPath:path
						 atInterval:interval
							  phase:0.0
						  alternate:NO
					  taperDelegate:nil];
}

- (NSBezierPath*)bezierPathWithPath:(NSBezierPath*)path atInterval:(CGFloat)interval phase:(CGFloat)phase alternate:(BOOL)alt taperDelegate:(id)taperDel
{
	if ([self elementCount] < 2 || interval <= 0)
		return nil;

	NSBezierPath* newPath = [NSBezierPath bezierPath];
	NSBezierPath* temp;
	NSPoint p;
	CGFloat slope, distance, length;
	NSUInteger count = 0;

	distance = phase;

	length = [self length];

	while (distance <= length) {
		p = [self pointOnPathAtLength:distance
								slope:&slope];

		if (alt && ((count & 1) == 1))
			slope += M_PI;

		temp = [path copy];

		NSAffineTransform* tfm = [NSAffineTransform transform];

		[tfm translateXBy:p.x
					  yBy:p.y];
		[tfm rotateByRadians:slope];

		if (taperDel && [taperDel respondsToSelector:@selector(taperFactorAtDistance:
																			  onPath:
																			ofLength:)]) {
			CGFloat normalisedDistance = [taperDel taperFactorAtDistance:distance
																  onPath:self
																ofLength:length];
			[tfm scaleXBy:normalisedDistance
					  yBy:normalisedDistance];
		}

		[temp transformUsingAffineTransform:tfm];
		[newPath appendBezierPath:temp];

		distance += interval;
		++count;
	}

	return newPath;
}

#pragma mark -
#pragma mark - placing "chain links" along a path

- (NSArray*)placeLinksOnPathWithLinkLength:(CGFloat)ll factoryObject:(id)object userInfo:(void*)userInfo
{
	return [self placeLinksOnPathWithEvenLinkLength:ll
									  oddLinkLength:ll
									  factoryObject:object
										   userInfo:userInfo];
}

- (NSArray*)placeLinksOnPathWithEvenLinkLength:(CGFloat)ell oddLinkLength:(CGFloat)oll factoryObject:(id)object userInfo:(void*)userInfo
{

	if (![object respondsToSelector:@selector(placeLinkFromPoint:
														 toPoint:
														  onPath:
													  linkNumber:
														userInfo:)])
		[NSException raise:NSInvalidArgumentException
					format:@"Factory object %@ does not implement the required protocol", object];

	if ([self elementCount] < 2 || ell <= 0 || oll <= 0)
		return nil;

	NSMutableArray* array = [[NSMutableArray alloc] init];
	NSInteger linkCount = 0;
	NSPoint prevLink;
	NSPoint p = NSZeroPoint;
	CGFloat distance, length, angle, radius;
	id placedObject;

	distance = 0;
	length = [self length];
	prevLink = [self firstPoint];

	while (distance <= length) {
		// find an initial point

		if (linkCount & 1)
			radius = oll;
		else
			radius = ell;

		distance += radius;

		if (distance <= length) {
			p = [self pointOnPathAtLength:distance
									slope:NULL];

			// point to use will be in this general direction but ensure link length is correct:

			angle = atan2(p.y - prevLink.y, p.x - prevLink.x);
			p.x = prevLink.x + (cos(angle) * radius);
			p.y = prevLink.y + (sin(angle) * radius);

			placedObject = [object placeLinkFromPoint:prevLink
											  toPoint:p
											   onPath:self
										   linkNumber:linkCount++
											 userInfo:userInfo];

			if (placedObject)
				[array addObject:placedObject];
		}
		prevLink = p;
	}

	return array;
}

#pragma mark -
#pragma mark - moving objects along a path

- (void)moveObject:(id)object atSpeed:(CGFloat)speed loop:(BOOL)loop userInfo:(id)userInfo
{
	NSAssert(object != nil, @"can't move a nil object");

	if (![object respondsToSelector:@selector(moveObjectTo:
												  position:
													 slope:
												  userInfo:)])
		[NSException raise:NSInvalidArgumentException
					format:@"Moved object %@ does not implement the required protocol", object];

	if ([self elementCount] < 2 || speed <= 0)
		return;

	if (object) {
		// set the object's position to the start of the path initially

		NSPoint where;
		CGFloat slope;

		where = [self pointOnPathAtLength:0
									slope:&slope];
		if ([object moveObjectTo:where
						position:0
						   slope:slope
						userInfo:userInfo]) {
			// set up a dictionary of parameters we can pass using the timer (allows many concurrent motions since there are no state variables
			// cached by the object)

			NSMutableDictionary* parameters = [[NSMutableDictionary alloc] init];

			[parameters setObject:self
						   forKey:@"path"];
			[parameters setObject:@(speed)
						   forKey:@"speed"];

			if (userInfo != nil)
				[parameters setObject:userInfo
							   forKey:@"userinfo"];

			[parameters setObject:object
						   forKey:@"target"];
			[parameters setObject:@([self length])
						   forKey:@"path_length"];
			[parameters setObject:@(loop)
						   forKey:@"loop"];
			[parameters setObject:@([NSDate timeIntervalSinceReferenceDate])
						   forKey:@"start_time"];

			NSTimer* t = [NSTimer timerWithTimeInterval:1.0 / 30.0
												 target:self
											   selector:@selector(motionCallback:)
											   userInfo:parameters
												repeats:YES];

			[[NSRunLoop currentRunLoop] addTimer:t
										 forMode:NSEventTrackingRunLoopMode];
			[[NSRunLoop currentRunLoop] addTimer:t
										 forMode:NSDefaultRunLoopMode];
		}
	}
}

- (void)motionCallback:(NSTimer*)timer
{
	CGFloat distance, speed, elapsedTime, length;
	BOOL loop, shouldStop = NO;
	NSDictionary* params = [timer userInfo];

	elapsedTime = [NSDate timeIntervalSinceReferenceDate] - [[params objectForKey:@"start_time"] doubleValue];
	speed = [[params objectForKey:@"speed"] doubleValue];

	distance = speed * elapsedTime;
	length = [[params objectForKey:@"path_length"] doubleValue];
	loop = [[params objectForKey:@"loop"] boolValue];

	if (!loop && distance > length) {
		distance = length;

		// reached the end of the path, so kill the timer if not looping

		shouldStop = YES;
	} else if (loop)
		distance = fmod(distance, length);

	// move the target object to the calculated point

	NSPoint where;
	CGFloat slope;
	id obj = [params objectForKey:@"target"];

	where = [self pointOnPathAtLength:distance
								slope:&slope];
	shouldStop |= ![obj moveObjectTo:where
							position:distance
							   slope:slope
							userInfo:[params objectForKey:@"userinfo"]];

	// if the target returns NO, it is telling us to stop immediately, whether or not we are looping

	if (shouldStop)
		[timer invalidate];
}

#pragma mark -
#pragma mark - calculating text layout rects for running text within a shape

/** @brief Compares NSPoint values and returns them in order of their horizontal position
 @param value1 the first value to compare
 @param value2 the second value to compare
 @return comparison result */
static NSInteger SortPointsHorizontally(NSValue* value1, NSValue* value2, void* context)
{
#pragma unused(context)
	NSPoint a, b;

	a = [value1 pointValue];
	b = [value2 pointValue];

	if (a.x > b.x)
		return NSOrderedDescending;
	else if (a.x < b.x)
		return NSOrderedAscending;
	else
		return NSOrderedSame;
}

- (NSArray*)intersectingPointsWithHorizontalLineAtY:(CGFloat)yPosition
{
	NSAssert(yPosition > 0.0, @"y value must be greater than 0");

	if ([self isEmpty])
		return nil; // nothing here, so bail

	NSRect br = [self bounds];

	// see if y is within the bounds - if not, there can't be any intersecting points so we can bail now.

	if (yPosition < NSMinY(br) || yPosition > NSMaxY(br))
		return nil;

	// set up the points for the horizontal line:

	br = NSInsetRect(br, -1, -1);

	NSPoint hla, hlb;

	hla.y = hlb.y = yPosition;
	hla.x = NSMinX(br) - 1;
	hlb.x = NSMaxX(br) + 1;

	// we can use a relatively coarse flatness for more speed - exact precision isn't needed for text layout.

	CGFloat savedFlatness = [self flatness];
	[self setFlatness:5.0];
	NSBezierPath* flatpath = [self bezierPathByFlatteningPath];
	[self setFlatness:savedFlatness];

	NSMutableArray* result = [NSMutableArray array];
	NSInteger i, m = [flatpath elementCount];
	NSBezierPathElement lm;
	NSPoint fp, lp, ap, ip;
	fp = lp = ap = ip = NSZeroPoint;

	for (i = 0; i < m; ++i) {
		lm = [flatpath elementAtIndex:i
					 associatedPoints:&ap];

		if (lm == NSMoveToBezierPathElement)
			fp = lp = ap;
		else {
			if (lm == NSClosePathBezierPathElement)
				ap = fp;

			ip = Intersection2(ap, lp, hla, hlb);
			lp = ap;

			// if the result is NSNotFoundPoint, lines are parallel and don't intersect. The intersection point may also fall outside the bounds,
			// so we discard that result as well.

			if (NSEqualPoints(ip, NSNotFoundPoint))
				continue;

			if (NSPointInRect(ip, br))
				[result addObject:[NSValue valueWithPoint:ip]];
		}
	}

	// if the result is not empty, sort the points into order horizontally

	if ([result count] > 0) {
		[result sortUsingFunction:SortPointsHorizontally
						  context:NULL];

		// if the result is odd, it means that we don't have a closed path shape at the line position -
		// i.e. there's an open endpoint. So to ensure that we return an even number of items (or none),
		// delete the last item to make the result even.

		if (([result count] & 1) == 1) {
			[result removeLastObject];

			if ([result count] == 0)
				result = nil;
		}
	} else
		result = nil; // nothing found, so just return nil

	return result;
}

- (NSArray*)lineFragmentRectsForFixedLineheight:(CGFloat)lineHeight
{

	NSAssert(lineHeight > 0.0, @"lineheight must be positive and greater than 0");

	NSRect br = [self bounds];
	NSMutableArray* result = [NSMutableArray array];

	// how many lines will fit in the shape?

	NSInteger lineCount = (floor(NSHeight(br) / lineHeight)) + 1;

	if (lineCount > 0) {
		@autoreleasepool {
			NSArray* previousLine = nil;
			NSArray* currentLine;
			NSInteger i;
			CGFloat linePosition = NSMinY(br);
			NSRect lineRect;

			lineRect.size.height = lineHeight;

			for (i = 0; i < lineCount; ++i) {
				lineRect.origin.y = linePosition;

				if (i == 0)
					previousLine = [self intersectingPointsWithHorizontalLineAtY:linePosition + 1];
				else {
					linePosition = NSMinY(br) + (i * lineHeight);
					currentLine = [self intersectingPointsWithHorizontalLineAtY:linePosition];

					if (currentLine != nil) {
						// go through the points of the previous line and this one, forming rects
						// by taking the inner points

						NSUInteger j, ur, lr, rectsOnLine;

						ur = [previousLine count];
						lr = [currentLine count];

						rectsOnLine = MAX(ur, lr);

						for (j = 0; j < rectsOnLine; ++j) {
							NSPoint upper, lower;

							upper = [[previousLine objectAtIndex:j % ur] pointValue];
							lower = [[currentLine objectAtIndex:j % lr] pointValue];

							// even values of j are left edges, odd values are right edges

							if ((j & 1) == 0)
								lineRect.origin.x = MAX(upper.x, lower.x);
							else {
								lineRect.size.width = MIN(upper.x, lower.x) - lineRect.origin.x;
								lineRect = NormalizedRect(lineRect);

								// if any corner of the rect is outside the path, chuck it

								NSRect tr = NSInsetRect(lineRect, 1, 1);
								NSPoint tp = NSMakePoint(NSMinX(tr), NSMinY(tr));

								if (![self containsPoint:tp])
									continue;

								tp = NSMakePoint(NSMaxX(tr), NSMinY(tr));
								if (![self containsPoint:tp])
									continue;

								tp = NSMakePoint(NSMaxX(tr), NSMaxY(tr));
								if (![self containsPoint:tp])
									continue;

								tp = NSMakePoint(NSMinX(tr), NSMaxY(tr));
								if (![self containsPoint:tp])
									continue;

								[result addObject:[NSValue valueWithRect:lineRect]];
							}
						}

						previousLine = currentLine;
					}
				}
			}
		}
	}

	return result;
}

- (NSRect)lineFragmentRectForProposedRect:(NSRect)aRect remainingRect:(NSRect*)rem
{
	return [self lineFragmentRectForProposedRect:aRect
								   remainingRect:rem
									 datumOffset:0];
}

- (NSRect)lineFragmentRectForProposedRect:(NSRect)aRect remainingRect:(NSRect*)rem datumOffset:(CGFloat)dOffset
{
	CGFloat od = LIMIT(dOffset, -0.5, +0.5) + 0.5;

	NSRect result;

	result.origin.y = NSMinY(aRect);
	result.size.height = NSHeight(aRect);

	CGFloat y = NSMinY(aRect) + (od * NSHeight(aRect));

	// find the intersection points - these are already sorted left to right

	NSArray* thePoints = [self intersectingPointsWithHorizontalLineAtY:y];
	NSPoint p1, p2;
	NSInteger ptIndex, ptCount;

	ptCount = [thePoints count];

	// search for the next even-numbered intersection point starting at the left edge of proposed rect.

	for (ptIndex = 0; ptIndex < ptCount; ptIndex += 2) {
		p1 = [[thePoints objectAtIndex:ptIndex] pointValue];

		// even, so it's a left edge

		if (p1.x >= aRect.origin.x) {
			// this is the main rect to return

			p2 = [[thePoints objectAtIndex:ptIndex + 1] pointValue];

			result.origin.x = p1.x;
			result.size.width = p2.x - p1.x;

			// and this is the remainder

			if (rem != nil) {
				aRect.origin.x = p2.x;
				*rem = aRect;
			}

			return result;
		}
	}

	// if we went through all the points and there were no more following the left edge of proposedRect, then there's no
	// more space on this line, so return zero rect.

	result = NSZeroRect;
	if (rem != nil)
		*rem = NSZeroRect;

	return result;
}

@end

#pragma mark -
#pragma mark - internal helper objects

@implementation DKTextOnPathGlyphAccumulator

- (NSArray*)glyphs
{
	return mGlyphs;
}

- (void)layoutManager:(NSLayoutManager*)lm willPlaceGlyphAtIndex:(NSUInteger)glyphIndex atLocation:(NSPoint)location pathAngle:(CGFloat)angle yOffset:(CGFloat)dy
{
	// determine the font for the glyph we are laying

	NSUInteger charIndex = [lm characterIndexForGlyphAtIndex:glyphIndex];
	NSFont* font = [[lm textStorage] attribute:NSFontAttributeName
									   atIndex:charIndex
								effectiveRange:NULL];
	NSGlyph glyph = [lm glyphAtIndex:glyphIndex];

	// get the baseline of the glyph

	CGFloat base = [lm locationForGlyphAtIndex:glyphIndex].y;

	// get the path of the glyph

	NSBezierPath* glyphTemp = [[NSBezierPath alloc] init];
	[glyphTemp moveToPoint:NSMakePoint(0, dy - base)];
	[glyphTemp appendBezierPathWithGlyph:glyph
								  inFont:font];

	// set up a transform to rotate the glyph to the path's local angle and flip it vertically

	NSAffineTransform* transform = [NSAffineTransform transform];
	[transform translateXBy:location.x
						yBy:location.y];
	[transform rotateByRadians:angle];
	[transform scaleXBy:1
					yBy:-1]; // assumes destination is flipped

	[glyphTemp transformUsingAffineTransform:transform];

	// add the transformed glyph

	[mGlyphs addObject:glyphTemp];
}

- (instancetype)init
{
	self = [super init];
	if (self)
		mGlyphs = [[NSMutableArray alloc] init];

	return self;
}

@end

#pragma mark -

@implementation DKTextOnPathGlyphDrawer

- (void)layoutManager:(NSLayoutManager*)lm willPlaceGlyphAtIndex:(NSUInteger)glyphIndex atLocation:(NSPoint)location pathAngle:(CGFloat)angle yOffset:(CGFloat)dy
{
	// this simply applies the current angle and transformation to the current context and asks the layout manager to draw the glyph. It is assumed that this is called
	// within a valid drawing context, and that the context is flipped.

	SAVE_GRAPHICS_CONTEXT

	NSPoint gp = [lm locationForGlyphAtIndex:glyphIndex];

	NSAffineTransform* transform = [NSAffineTransform transform];
	[transform translateXBy:location.x
						yBy:location.y];
	[transform rotateByRadians:angle];
	[transform concat];

	[lm drawBackgroundForGlyphRange:NSMakeRange(glyphIndex, 1)
							atPoint:NSMakePoint(-gp.x, 0 - dy)];
	[lm drawGlyphsForGlyphRange:NSMakeRange(glyphIndex, 1)
						atPoint:NSMakePoint(-gp.x, 0 - dy)];

	RESTORE_GRAPHICS_CONTEXT
}

@end

#pragma mark -

@implementation DKTextOnPathMetricsHelper

@synthesize characterRange=mCharacterRange;
@synthesize length=mLength;
@synthesize position=mStartPosition;

- (void)layoutManager:(NSLayoutManager*)lm willPlaceGlyphAtIndex:(NSUInteger)glyphIndex atLocation:(NSPoint)location pathAngle:(CGFloat)angle yOffset:(CGFloat)dy
{
#pragma unused(dy, location, angle)

	NSUInteger charIndex = [lm characterIndexForGlyphAtIndex:glyphIndex];

	if (NSLocationInRange(charIndex, mCharacterRange)) {
		// within the range of interest, so get the glyph's bounding rect
		// if length is 0, this is the first glyph of interest so record its position

		if (mLength == 0.0)
			mStartPosition = [lm locationForGlyphAtIndex:glyphIndex].x;

		if ([lm isValidGlyphIndex:++glyphIndex])
			mLength = [lm locationForGlyphAtIndex:glyphIndex].x - mStartPosition;
		else
			mLength = NSMaxX([lm lineFragmentUsedRectForGlyphAtIndex:glyphIndex - 1
													  effectiveRange:NULL]) - mStartPosition;
	}
}

@end

#pragma mark -

@implementation DKPathGlyphInfo

- (instancetype)initWithGlyphIndex:(NSUInteger)glyphIndex position:(NSPoint)pt slope:(CGFloat)slope
{
	self = [super init];
	if (self) {
		mGlyphIndex = glyphIndex;
		mPoint = pt;
		mSlope = slope;
	}

	return self;
}

@synthesize glyphIndex=mGlyphIndex;
@synthesize slope=mSlope;
@synthesize point=mPoint;

@end

#pragma mark -

@implementation NSFont (DKUnderlineCategory)

- (CGFloat)valueForInvalidUnderlinePosition
{
	CGFloat ulo;
	NSFont* font = [[self class] fontWithName:@"Helvetica"
										 size:[self pointSize]];

	ulo = [font underlinePosition];

	font = [[self class] fontWithName:@"Times"
								 size:[self pointSize]];

	return (ulo + [font underlinePosition]) * 0.5;
}

- (CGFloat)valueForInvalidUnderlineThickness
{
	CGFloat ulo;
	NSFont* font = [[self class] fontWithName:@"Helvetica"
										 size:[self pointSize]];

	ulo = [font underlineThickness];

	font = [[self class] fontWithName:@"Times"
								 size:[self pointSize]];

	return (ulo + [font underlineThickness]) * 0.5;
}

@end
