/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2015
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>

// bezier path category:

@interface NSBezierPath (TextOnPath)

/** @brief Returns a layout manager used for text on path layout.

 This shared layout manager is used by text on path drawing unless a specific manager is passed.
 @return a shared layout manager instance */
+ (NSLayoutManager*)textOnPathLayoutManager;

/** @brief Returns the attributes used to draw strings on paths.

 The default is 12 point Helvetica Roman black text with the default paragraph style.
 @return a dictionary of string attributes */
+ (NSDictionary*)textOnPathDefaultAttributes;

/** @brief Sets the attributes used to draw strings on paths.

 Pass nil to set the default. The attributes are used by the drawStringOnPath: method.
 @param attrs a dictionary of text attributes */
+ (void)setTextOnPathDefaultAttributes:(NSDictionary*)attrs;

// drawing text along a path - high level methods that use a default layout manager and don't use a cache:

/** @brief Renders a string on a path.

 Positive values of dy place the text's baseline above the path, negative below it, where 'above'
 and 'below' are in the expected sense relative to the orientation of the drawn glyphs. This is the
 highest-level attributed text on path drawing method, and uses the shared layout mamanger and no cache.
 @param str the attributed string to render
 @param dy the offset between the path and the text's baseline when drawn.
 @return YES if the text was fully laid out, NO if some text could not be drawn (for example because it
 would not all fit on the path). */
- (BOOL)drawTextOnPath:(NSAttributedString*)str yOffset:(CGFloat)dy;

/** @brief Renders a string on a path.

 Very high-level, draws the string on the path using the set class attributes.
 @param str the  string to render
 @return YES if the text was fully laid out, NO if some text could not be drawn (for example because it
 would not all fit on the path). */
- (BOOL)drawStringOnPath:(NSString*)str;

/** @brief Renders a string on a path.

 If attrs is nil, uses the current class attributes
 @param str the  string to render
 @param attrs the attributes to use to draw the string - may be nil
 @return YES if the text was fully laid out, NO if some text could not be drawn (for example because it
 would not all fit on the path). */
- (BOOL)drawStringOnPath:(NSString*)str attributes:(NSDictionary*)attrs;

// more advanced method called by the others allows use of different layout managers and cached information for better efficiency. If an object passes back the same
// cache each time, text-on-path rendering avoids recalculating several things. The caller is responsible for invalidating the cache if the actual string
// content to be drawn has changed, but the path will detect changes to itself automatically.

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
- (BOOL)drawTextOnPath:(NSAttributedString*)str yOffset:(CGFloat)dy layoutManager:(NSLayoutManager*)lm cache:(NSMutableDictionary*)cache;

// obtaining the paths of the glyphs laid out on the path

/** @brief Returns a list of paths each containing one glyph from the original text.

 Each glyph is returned as a separate path, allowing attributes to be applied if required.
 @param str the  string to render
 @param dy the baseline offset between the path and the text
 @return a list of bezier path objects. */
- (NSArray*)bezierPathsWithGlyphsOnPath:(NSAttributedString*)str yOffset:(CGFloat)dy;

/** @brief Returns a single path consisting of all of the laid out glyphs of the text.

 All glyph paths are added to the single bezier path. This preserves their original shapes but
 attribute information such as colour runs, etc are effectively lost.
 @param str the  string to render
 @param dy the baseline offset between the path and the text
 @return a single bezier path. */
- (NSBezierPath*)bezierPathWithTextOnPath:(NSAttributedString*)str yOffset:(CGFloat)dy;

/** @brief Returns a single path consisting of all of the laid out glyphs of the text.

 The string is drawn using the class attributes.
 @param str the  string to render
 @return a list of bezier path objects. */
- (NSBezierPath*)bezierPathWithStringOnPath:(NSString*)str;

/** @brief Returns a single path consisting of all of the laid out glyphs of the text.
 @param str the  string to render
 @param attrs the drawing attributes for the text
 @return a list of bezier path objects. */
- (NSBezierPath*)bezierPathWithStringOnPath:(NSString*)str attributes:(NSDictionary*)attrs;

// low-level glyph layout method called by all other methods to generate the glyphs. The result depends on the helper object which must conform
// to the textOnPathPlacement informal protocol (see below)

/** @brief Low level method performs all text on path layout.

 This method does all the actual work of glyph generation and positioning of the glyphs along the path.
 It is called by all other methods. The helper object does the appropriate thing, either adding the
 glyph outline to a list or actually drawing the glyph. Note that the glyph layout is handled by the
 layout manager as usual, but the helper is responsible for the last step.
 @param str the attributed string to render
 @param dy the text baseline offset
 @param helperObject a helper object used to process each glyph as it is laid out
 @param lm the layout manager that performs the layout
 @param cache a cache used to save layout informaiton to avoid recalculation
 @return YES if all text was laid out, NO if some text was not laid out. */
- (BOOL)layoutStringOnPath:(NSTextStorage*)str
				   yOffset:(CGFloat)dy
		 usingLayoutHelper:(id)helperObject
			 layoutManager:(NSLayoutManager*)lm
					 cache:(NSMutableDictionary*)cache;

/** @brief Low level method adjusts text to fit the path length.

 Modifies the text storage in place by setting NSKernAttribute to stretch or compress the text to
 fit the given length. Text is only compressed by a certain amount - beyond that characters are
 dropped from the end of the line when laid out.
 @param text text storage containing the text to lay out
 @param length the path length
 @return none.
 */
- (void)kernText:(NSTextStorage*)text toFitLength:(CGFloat)length;

/** @brief Low level method adjusts justified text to fit the path length.

 This does two things - it sets up the text's container so that text will be laid out properly
 within the path's length, and secondly if the text is "justified" it kerns the text to fit the path.
 @param text text storage containing the text to lay out
 @param length the path length
 @return none.
 */
- (NSTextStorage*)preadjustedTextStorageWithString:(NSAttributedString*)str layoutManager:(NSLayoutManager*)lm;

// drawing underline and strikethrough paths

/** @brief Low level method draws the underline attributes for the text if necessary.

 Underlining text on a path is very involved, as it needs to bypass NSLayoutManager's normal
 underline processing and handle it directly, in order to get smooth unbroken lines. While this
 sometimes results in underlining that differs from standard, it is very close and visually
 far nicer than leaving it to NSLayoutManager.
 @param lm the layout manager in use
 @param dy the text baseline offset from the path
 @param cache a cache used to store intermediate calculations to speed up repeated drawing
 @return none.
 */
- (void)drawUnderlinePathForLayoutManager:(NSLayoutManager*)lm yOffset:(CGFloat)dy cache:(NSMutableDictionary*)cache;

/** @brief Low level method draws the strikethrough attributes for the text if necessary.

 Strikethrough text on a path is involved, as it needs to bypass NSLayoutManager's normal
 processing and handle it directly, in order to get smooth unbroken lines. While this
 sometimes results in strikethrough that differs from standard, it is very close and visually
 far nicer than leaving it to NSLayoutManager.
 @param lm the layout manager in use
 @param dy the text baseline offset from the path
 @param cache a cache used to store intermediate calculations to speed up repeated drawing
 @return none.
 */
- (void)drawStrikethroughPathForLayoutManager:(NSLayoutManager*)lm yOffset:(CGFloat)dy cache:(NSMutableDictionary*)cache;

/** @brief Low level method draws the undeline attributes for ranges of text.

 Here be dragons.
 @param lm the layout manager in use
 @param range the range of text to apply the underline attribute to
 @param dy the text baseline offset from the path
 @param cache a cache used to store intermediate calculations to speed up repeated drawing
 @return none.
 */
- (void)drawUnderlinePathForLayoutManager:(NSLayoutManager*)lm range:(NSRange)range yOffset:(CGFloat)dy cache:(NSMutableDictionary*)cache;

/** @brief Low level method draws the strikethrough attributes for ranges of text.

 Here be more dragons.
 @param lm the layout manager in use
 @param range the range of text to apply the underline attribute to
 @param dy the text baseline offset from the path
 @param cache a cache used to store intermediate calculations to speed up repeated drawing
 @return none.
 */
- (void)drawStrikethroughPathForLayoutManager:(NSLayoutManager*)lm range:(NSRange)range yOffset:(CGFloat)dy cache:(NSMutableDictionary*)cache;

/** @brief Calculates the start and end locations of ranges of text on the path.

 Used to compute start positions and length of runs of attributes along the path, such as underlines and
 strikethroughs. Paragraph styles affect this, so the results tell you where to draw.
 @param start receives the starting position of the range of characters
 @param length receives the length of the range of characters
 @param str the string in question
 @param range the range of characters of interest within the string
 */
- (void)pathPosition:(CGFloat*)start andLength:(CGFloat*)length forCharactersOfString:(NSAttributedString*)str inRange:(NSRange)range;

/** @brief Determines the positions of any descender breaks for drawing underlines.

 In order to correctly and accurately interrupt an underline where a glyph descender 'cuts' through
 it, the locations of the start and end of each break must be computed. This does that by finding
 the intersections of the glyph paths and a notional underline path. As such it is computationally
 expensive (but is cached at a higher level).
 @param str the string in question
 @param range the range of characters of interest within the string
 @param offset the distance between the text baseline and the underline
 @return A list of descender break positions (NSValues with NSPoint values)
 */
- (NSArray*)descenderBreaksForString:(NSAttributedString*)str range:(NSRange)range underlineOffset:(CGFloat)offset;

/** @brief Converts all the information about an underline into a path that can be drawn.

 Where descender breaks are passed in, the gap on either side of the break is widened by a factor
 based on gt, which in turn is usually derived from the text size. This allows the breaks to size
 proportionally to give pleasing results. The result may differ from Apple's standard text block
 rendition (but note that for some fonts, DK's way works where Apple's does not, e.g. Zapfino)
 @param mask the underline attributes mask value
 @param sp the starting position for the underline on the path
 @param length the length of the underline on the path
 @param offset the distance between the text baseline and the underline
 @param lineThickness the thickness of the underline
 @param breaks an array of descender breakpoints, or nil
 @param gt threshold value to suppress inclusion of very short "bits" of underline (a.k.a "grot")
 @return A path. Stroking this path draws the underline.
 */
- (NSBezierPath*)textLinePathWithMask:(NSInteger)mask
						startPosition:(CGFloat)sp
							   length:(CGFloat)length
							   offset:(CGFloat)offset
						lineThickness:(CGFloat)lineThickness
					  descenderBreaks:(NSArray*)breaks
						grotThreshold:(CGFloat)gt;

// getting text layout rects for running text within a shape

/** @brief Find the points where a line drawn horizontally across the path will intersect it.

 This works by approximating the curve as a series of straight lines and testing each one for
 intersection with the line at y. This is the primitive method used to determine line layout
 rectangles - a series of calls to this is needed for each line (incrementing y by the
 lineheight) and then rects forming from the resulting points. See -lineFragmentRectsForFixedLineheight:
 This is also used when calculating descender breaks for underlining text on a path. This method is
 guaranteed to return an even number of (or none) results.
 @param yPosition the distance between the top edge of the bounds and the line to test
 @return a list of NSValues containing NSPoints */
- (NSArray*)intersectingPointsWithHorizontalLineAtY:(CGFloat)yPosition;

/** @brief Find rectangles within which text can be laid out to place the text within the path.

 Given a lineheight value, this returns an array of rects (as NSValues) which are the ordered line
 layout rects from left to right and top to bottom within the shape to layout text in. This is
 computationally intensive, so the result should probably be cached until the shape is actually changed.
 This works with a fixed lineheight, where every line is the same. Note that this method isn't really
 suitable for use with NSTextContainer or Cocoa's text system in general - for flowing text using
 NSLayoutManager use DKBezierTextContainer which calls the -lineFragmentRectForProposedRect:remainingRect:
 method below.
 @param lineHeight the lineheight for the lines of text
 @return a list of NSValues containing NSRects */
- (NSArray*)lineFragmentRectsForFixedLineheight:(CGFloat)lineHeight;

/** @brief Find a line fragement rectange for laying out text in this shape.

 See -lineFragmentRectForProposedRect:remainingRect:datumOffset:
 @param aRect the proposed rectangle
 @return the available rectangle for the text given the proposed rect */
- (NSRect)lineFragmentRectForProposedRect:(NSRect)aRect remainingRect:(NSRect*)rem;

/** @brief Find a line fragement rectange for laying out text in this shape.

 This offsets <proposedRect> to the right to the next even-numbered intersection point, setting its
 length to the difference between that point and the next. That part is the return value. If there
 are any further points, the remainder is set to the rest of the rect. This allows this method to
 be used directly by a NSTextContainer subclass (see DKBezierTextContainer)
 @param aRect the proposed rectangle
 @param dOffset a value between +0.5 and -0.5 that represents the relative position within the line used
 @return the available rectangle for the text given the proposed rect */
- (NSRect)lineFragmentRectForProposedRect:(NSRect)aRect remainingRect:(NSRect*)rem datumOffset:(CGFloat)dOffset;

// drawing/placing/moving anything along a path:

/** @brief Places objects at regular intervals along the path.

 The factory object creates an object at each position and it is added to the result array.
 @param interval the distance between each object placed
 @param object a factory object used to supply the paths placed
 @param userInfo information passed to the factory object
 @return A list of placed objects */
- (NSArray*)placeObjectsOnPathAtInterval:(CGFloat)interval factoryObject:(id)object userInfo:(void*)userInfo;

/** @brief Places objects at regular intervals along the path.

 The factory object creates a path at each position and it is added to the resulting path
 @param interval the distance between each object placed
 @param object a factory object used to supply the paths placed
 @param userInfo information passed to the factory object
 @return A single path consisting of all of the added paths */
- (NSBezierPath*)bezierPathWithObjectsOnPathAtInterval:(CGFloat)interval factoryObject:(id)object userInfo:(void*)userInfo;

/** @brief Places copies of a given path at regular intervals along the path.

 The origin of <path> is positioned on the receiver's path at the designated location. The caller
 should ensure that the origin is sensible - paths based on 0,0 work as expected.
 @param path a path to position at intervals on this path
 @param interval the distance between each object placed
 @return A single path consisting of all of the added paths */
- (NSBezierPath*)bezierPathWithPath:(NSBezierPath*)path atInterval:(CGFloat)interval;

/** @brief Places copies of a given path at regular intervals along the path.

 The origin of <path> is positioned on the receiver's path at the designated location. The caller
 should ensure that the origin is sensible - paths based on 0,0 work as expected.
 @param path a path to position at intervals on this path
 @param interval the distance between each object placed
 @param phase an initial offset added to the distance
 @param alternate if YES, odd-numbered elements are reversed 180 degrees
 @param taperDel an optional taper delegate.
 @return A single path consisting of all of the added paths */
- (NSBezierPath*)bezierPathWithPath:(NSBezierPath*)path atInterval:(CGFloat)interval phase:(CGFloat)phase alternate:(BOOL)alt taperDelegate:(id)taperDel;

// placing "chain links" along a path:

/** @brief Places "links" along the path at equal intervals.

 See notes for placeLinksOnPathWithEvenLinkLength:oddLinkLength:factoryObject:userInfo:
 @param ll the interval and length of each "link"
 @param object a factory object used to generate the links themselves
 @param userInfo user info passed to the factory object
 @return a list of created link objects */
- (NSArray*)placeLinksOnPathWithLinkLength:(CGFloat)ll factoryObject:(id)object userInfo:(void*)userInfo;

/** @brief Places "links" along the path at alternating even and odd intervals.

 Similar to object placement, but treats the objects as "links" like in a chain, where a rigid link
 of a fixed length connects two points on the path. The factory object is called with the pair of
 points computed, and returns a path representing the link between those two points. Non-nil results are
 accumulated into the array returned. Even and odd links can have different lengths for added
 flexibility. Note that to keep this working quickly, the link length is used as a path length to
 find the initial link pivot point, then the actual point is calculated by using the link radius
 in this direction. The result can be that links will not exactly follow a very convoluted or
 curved path, but each link is guaranteed to be a fixed length and exactly join to its neighbours.
 In practice, this gives results that are very "physical" in that it emulates the behaviour of
 real chains that are bent through acute angles.
 @param ell the even interval
 @param oll th eodd interval
 @param object a factory object used to generate the links themselves
 @param userInfo user info passed to the factory object
 @return a list of created link objects */
- (NSArray*)placeLinksOnPathWithEvenLinkLength:(CGFloat)ell oddLinkLength:(CGFloat)oll factoryObject:(id)object userInfo:(void*)userInfo;

// easy motion method:

/** @brief Moves an object along the path at a constant speed

 The object must respond to the informal motion protocol. This method starts a timer which runs
 until either the end of the path is reached when loop is NO, or until the object being moved
 itself returns NO. The timer runs at 30 fps and the distance moved is calculated accordingly - this
 gives accurate motion speed regardless of framerate, and will drop frames if necessary.
 @param object the object to be moved (i.e. animated)
 @param speed the linear motion speed in points per second
 @param loop YES to repeatedly loop the movement when it gets to the end, NO for one-time motion.
 @param userInfo user info passed to the object */
- (void)moveObject:(id)object atSpeed:(CGFloat)speed loop:(BOOL)loop userInfo:(id)userInfo;

@end

#pragma mark -

// informal protocol for placing objects at linear intervals along a bezier path. Will be called from placeObjectsOnPathAtInterval:withObject:userInfo:
// the <object> is called with this method if it implements it.

// the second method can be used to implement fluid motion along a path using the moveObject:alongPathDistance:inTime:userInfo: method.

// the links method is used to implement chain effects from the "placeLinks..." method.

@interface NSObject (BezierPlacement)

- (id)placeObjectAtPoint:(NSPoint)p onPath:(NSBezierPath*)path position:(CGFloat)pos slope:(CGFloat)slope userInfo:(void*)userInfo;
- (BOOL)moveObjectTo:(NSPoint)p position:(CGFloat)pos slope:(CGFloat)slope userInfo:(id)userInfo;
- (id)placeLinkFromPoint:(NSPoint)pa toPoint:(NSPoint)pb onPath:(NSBezierPath*)path linkNumber:(NSInteger)lkn userInfo:(void*)userInfo;

@end

#pragma mark -

// when laying out glyphs on the path, a helper object with this informal protocol is used. The object can process the glyph appropriately, for example
// just drawing it after applying a transform, or accumulating the glyph path. An object implementing this protocol is passed internally by the text on
// path methods as necessary, or you can supply one.

@interface NSObject (TextOnPathPlacement)

- (void)layoutManager:(NSLayoutManager*)lm willPlaceGlyphAtIndex:(NSUInteger)glyphIndex atLocation:(NSPoint)location pathAngle:(CGFloat)angle yOffset:(CGFloat)dy;

@end

#pragma mark -

// when using a tapering method, the taper callback object must implement the following informal protocol

@interface NSObject (TaperPathDelegate)

- (CGFloat)taperFactorAtDistance:(CGFloat)distance onPath:(NSBezierPath*)path ofLength:(CGFloat)length;
@end

#pragma mark -

// helper objects used internally when accumulating or laying glyphs

@interface DKTextOnPathGlyphAccumulator : NSObject {
	NSMutableArray* mGlyphs;
}

- (NSArray*)glyphs;
- (void)layoutManager:(NSLayoutManager*)lm willPlaceGlyphAtIndex:(NSUInteger)glyphIndex atLocation:(NSPoint)location pathAngle:(CGFloat)angle yOffset:(CGFloat)dy;

@end

#pragma mark -

// this just applies the transform and causes the layout manager to draw the glyph. This ensures that all the stylistic variations on the glyph are applied allowing
// attributed strings to be drawn along the path.

@interface DKTextOnPathGlyphDrawer : NSObject

- (void)layoutManager:(NSLayoutManager*)lm willPlaceGlyphAtIndex:(NSUInteger)glyphIndex atLocation:(NSPoint)location pathAngle:(CGFloat)angle yOffset:(CGFloat)dy;

@end

#pragma mark -

// this helper calculates the start and length of a given run of characters in the string. The character range should be set prior to use. As each glyph is laid, the
// glyph run position and length along the line fragment rectangle is calculated.

@interface DKTextOnPathMetricsHelper : NSObject {
	CGFloat mStartPosition;
	CGFloat mLength;
	NSRange mCharacterRange;
}

- (void)setCharacterRange:(NSRange)range;
- (CGFloat)length;
- (CGFloat)position;
- (void)layoutManager:(NSLayoutManager*)lm willPlaceGlyphAtIndex:(NSUInteger)glyphIndex atLocation:(NSPoint)location pathAngle:(CGFloat)angle yOffset:(CGFloat)dy;

@end

#pragma mark -

// this is a small wrapper object used to cache information about locations on a path, to save recalculating them each time.

@interface DKPathGlyphInfo : NSObject {
	NSUInteger mGlyphIndex;
	NSPoint mPoint;
	CGFloat mSlope;
}

- (id)initWithGlyphIndex:(NSUInteger)glyphIndex position:(NSPoint)pt slope:(CGFloat)slope;
- (NSUInteger)glyphIndex;
- (CGFloat)slope;
- (NSPoint)point;

@end

#pragma mark -

// category on NSFont used to fudge the underline offset for invalid fonts. Apparently this is what Apple do also, though currently the
// definition of "invalid font" is not known with any precision. Currently underline offsets of 0 will use this value instead

@interface NSFont (DKUnderlineCategory)

- (CGFloat)valueForInvalidUnderlinePosition;
- (CGFloat)valueForInvalidUnderlineThickness;

@end
