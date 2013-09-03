///**********************************************************************************************************************************
///  DKTextAdornment.m
///  DrawKit ©2005-2008 Apptree.net
///
///  Created by graham on 18/05/2007.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
///
///**********************************************************************************************************************************

#import "DKTextAdornment.h"
#import "DKDrawableObject+Metadata.h"
#import "DKObjectOwnerLayer.h"
#import "LogEvent.h"
#import "NSBezierPath+Text.h"
#import "NSBezierPath+Geometry.h"
#import "DKDrawableShape.h"
#import "NSObject+StringValue.h"
#import "DKBezierTextContainer.h"
#import "DKBezierLayoutManager.h"
#import "DKShapeGroup.h"
#import "NSAttributedString+DKAdditions.h"
#import "DKDrawKitMacros.h"
#import "DKShapeFactory.h"
#import "DKStyle.h"
#import "DKFill.h"
#import "DKStroke.h"
#import "DKTextSubstitutor.h"
#import "DKGreekingLayoutManager.h"



@interface DKTextAdornment (Private)

- (void)					drawText:(NSTextStorage*) contents withObject:(id<DKRenderable>) obj withPath:(NSBezierPath*) path;
- (void)					drawText:(NSTextStorage*) contents withObject:(id<DKRenderable>) obj withPath:(NSBezierPath*) path layoutManager:(NSLayoutManager*) lm;
- (void)					drawText:(NSTextStorage*) contents centredAtPoint:(NSPoint) p;
- (NSAffineTransform*)		textTransformForObject:(id<DKRenderable>) obj;
- (void)					drawKnockoutWithObject:(id<DKRenderable>) obj;
- (void)					changeTextAttribute:(NSString*) attribute toValue:(id) val;
- (NSPoint)					textOriginForSize:(NSSize) textSize objectSize:(NSSize) osize;
- (CGFloat)					verticalTextOffsetForTextSize:(NSSize) textSize objectSize:(NSSize) osize;
- (void)					applyNonCocoaTextAttributes:(NSDictionary*) attrs;
- (NSLayoutManager*)		layoutManager;
- (void)					masterStringChanged:(NSNotification*) note;

@end

// attrbute keys in the -textAttributes dictionary for DKTextAdornment properties

NSString*	DKTextKnockoutColourAttributeName				= @"DKTextKnockoutColourAttributeName";
NSString*	DKTextKnockoutDistanceAttributeName				= @"DKTextKnockoutDistanceAttributeName";
NSString*	DKTextKnockoutStrokeColourAttributeName			= @"DKTextKnockoutStrokeColourAttributeName";
NSString*	DKTextKnockoutStrokeWidthAttributeName			= @"DKTextKnockoutStrokeWidthAttributeName";
NSString*	DKTextVerticalAlignmentAttributeName			= @"DKTextVerticalAlignmentAttributeName";
NSString*	DKTextVerticalAlignmentProportionAttributeName	= @"DKTextVerticalAlignmentProportionAttributeName";
NSString*	DKTextCapitalizationAttributeName				= @"DKTextCapitalizationAttributeName";

// private keys in the text adornment cache

//static NSString* kDKTextAdornmentLastClientSeenCacheKey		= @"DKTextAdornmentLastClientSeen";
static NSString* kDKTextAdornmentMaskPathCacheKey			= @"DKTextAdornmentMaskPath";
static NSString* kDKTextAdornmentMaskObjectChecksumCacheKey	= @"DKTextAdornmentMaskObjectChecksum";
static NSString* kDKTextAdornmentMetadataChecksumCacheKey	= @"DKTextAdornmentMetadataChecksum";

@implementation DKTextAdornment

static CGFloat s_maximumVerticalOffset = DEFAULT_BASELINE_OFFSET_MAX;

#pragma mark As a DKTextAdornment

+ (DKTextAdornment*)		textAdornmentWithText:(id) anySortOfText;
{
	DKTextAdornment* dkt = [[self alloc] init];
	
	[dkt setLabel:anySortOfText];
	[dkt applyNonCocoaTextAttributes:[[dkt textSubstitutor] attributes]];
	
	return [dkt autorelease];
}


+ (NSDictionary*)			defaultTextAttributes
{
	static NSMutableDictionary* dta = nil;
	
	if ( dta == nil )
	{
		dta = [[NSMutableDictionary alloc] init];
		
		NSFont* font = [NSFont fontWithName:@"Helvetica" size:14];
		[dta setObject:font forKey:NSFontAttributeName];
		
		NSMutableParagraphStyle* ps = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
		[ps setAlignment:NSCenterTextAlignment];
		[dta setObject:ps forKey:NSParagraphStyleAttributeName];
		[ps release];
		
		NSColor* tc = [NSColor blackColor];
		[dta setObject:tc forKey:NSForegroundColorAttributeName];
	}
	
	return dta;
}


+ (NSString*)				defaultLabel
{
	return NSLocalizedString(@"Text Adornment", @"default label for new text adornments");
}


+ (CGFloat)					defaultMaximumVerticalOffset
{
	return s_maximumVerticalOffset;
}


+ (void)					setDefaultMaximumVerticalOffset:(CGFloat) mvo
{
	s_maximumVerticalOffset = mvo;
}



- (NSString*)				string
{
	return [[self textSubstitutor] string];
}


- (void)					setLabel:(id) anySortOfText
{
	// allows any sort (NSString, NSAttributedString) of string/text to be passed to set the label. The label is permitted to include text substitution markers
	// which will be replaced when the text is drawn.
	
	if([anySortOfText isKindOfClass:[NSAttributedString class]])
	{
		NSAttributedString* as = [anySortOfText copy];
		[[self textSubstitutor] setMasterString:as];
		[as release];
	}
	else if([anySortOfText isKindOfClass:[NSString class]])
	{
		NSDictionary*	attributes = [self textAttributes];
		
		// if the string is empty, the current attributes will be discarded. To ensure this doesn't happen, record the
		// default attributes locally so that a non-empty string will use the current attributes instead of the class defaults.
		
		if([anySortOfText length] < 1)
		{
			[attributes retain];
			[mDefaultAttributes release];
			mDefaultAttributes = attributes;
		}
		
		if( attributes == nil )
			attributes = [self  defaultTextAttributes];
		
		[[self textSubstitutor] setString:(NSString*)anySortOfText withAttributes:attributes];
	}
	else
	{
		[[self textSubstitutor] setString:@"" withAttributes:[self defaultTextAttributes]];
	}
}


- (NSAttributedString*)		label
{
	// returns the original text without performing substitution. For the actual text drawn, use -textToDraw:
	
	return [[self textSubstitutor] masterString];
}


- (NSTextStorage*)			textForEditing
{
	NSTextStorage* edText = [[NSTextStorage alloc] initWithAttributedString:[self label]];
	return [edText autorelease];
}


- (void)					setPlaceholderString:(NSString*) str
{
	[str retain];
	[mPlaceholder release];
	mPlaceholder = str;
}


- (NSString*)				placeholderString
{
	return mPlaceholder;
}


#pragma mark -
- (NSBezierPath*)			textAsPathForObject:(id) object
{
	// returns a  NSBezierPath object, representing the adornment's laid-out text. All settings are honoured.
	// do not use ghosted attributes:
	
	BOOL ghosted = NO;
	
	if([object respondsToSelector:@selector(setGhosted:)] && [object respondsToSelector:@selector(isGhosted)])
	{
		ghosted = [object isGhosted];
		[object setGhosted:NO];
	}
	
	NSTextStorage*	str = [self textToDraw:object];
	
	if([object respondsToSelector:@selector(setGhosted:)])
		[object setGhosted:ghosted];
	
	// if no text, nothing to do
	
	if ( str == nil )
		return nil;
	
	NSBezierPath*	path = [self renderingPathForObject:object];
	
	if ( [self layoutMode] == kDKTextLayoutAlongReversedPath )
		path = [path bezierPathByReversingPath];
	
	if([self layoutMode] == kDKTextLayoutAlongReversedPath ||
	   [self layoutMode] == kDKTextLayoutAlongPath )
	{
		CGFloat baseOffset;
		
		if([self verticalAlignment] == kDKTextPathVerticalAlignmentCentredOnPath)
		{
			NSFont*	font = [str attribute:NSFontAttributeName atIndex:0 effectiveRange:NULL];
			baseOffset = [self baselineOffsetForTextHeight:[font xHeight]];
		}
		else
			baseOffset = [self baselineOffset];

		return [path bezierPathWithTextOnPath:str yOffset:baseOffset];
	}
	else
	{
		DKBezierLayoutManager* captureLM = (DKBezierLayoutManager*)sharedCaptureLayoutManager();
		[[captureLM textPath] removeAllPoints];
		
		// by drawing into a temporary flipped image context, text will be right side up with its lines in the right order
		
		NSImage* tempImage = [[NSImage alloc] initWithSize:NSMakeSize( 1, 1 )];
		[tempImage setFlipped:YES];
		[tempImage lockFocus];
		
		[self drawText:str withObject:object withPath:path layoutManager:captureLM];
		[tempImage unlockFocus];
		[tempImage release];
		
		// get the text path and position it aligned with the object
		
		NSBezierPath* newPath = [[captureLM textPath] copy];
		
		NSAffineTransform* tfm = [self textTransformForObject:object];
		[newPath transformUsingAffineTransform:tfm];
		
		return [newPath autorelease];
	}
}


- (NSArray*)				textPathsForObject:(id) object usedSize:(NSSize*) aSize
{
	// returns a list of NSBezierPath objects, representing the individual glyphs of the adornment's laid-out text. All settings are honoured.
	
	BOOL ghosted = [object isGhosted];
	[object setGhosted:NO];

	NSTextStorage*	str = [self textToDraw:object];
	
	[object setGhosted:ghosted];
	
	// if no text, nothing to do
	
	if ( str == nil )
		return nil;
	
	NSBezierPath*	path = [self renderingPathForObject:object];
	
	if ( [self layoutMode] == kDKTextLayoutAlongReversedPath )
		path = [path bezierPathByReversingPath];
	
	if([self layoutMode] == kDKTextLayoutAlongReversedPath ||
	   [self layoutMode] == kDKTextLayoutAlongPath )
	{
		return [path bezierPathsWithGlyphsOnPath:str yOffset:[self baselineOffset]];
	}
	else
	{
		DKBezierLayoutManager* captureLM = (DKBezierLayoutManager*)sharedCaptureLayoutManager();
		NSTextContainer* container = [[captureLM textContainers] lastObject];

		[self drawText:str withObject:object withPath:path layoutManager:captureLM];
		
		[str addLayoutManager:captureLM];
		NSArray* glyphs = [captureLM glyphPathsForContainer:container usedSize:aSize];
		[str removeLayoutManager:captureLM];
		
		return glyphs;
	}
}


- (DKStyle*)				styleFromTextAttributes
{
	// for use with paths such as those returned by the above methods, this returns a style that attempts to mimic the current text attributes
	// When applied to the above paths, it should give similar results to the original text appearance.
	
	DKStyle*	styl = [[DKStyle alloc] init];
	
	DKFill*		fill;
	NSColor*	fc = [[self textAttributes] objectForKey:NSForegroundColorAttributeName];
	
	if ( fc )
		fill = [DKFill fillWithColour:fc];
	else
		fill = [DKFill fillWithColour:[NSColor blackColor]];
	
	// copy the shadow - text shadow is flipped
	
	NSShadow*	shad = [[[self textAttributes] objectForKey:NSShadowAttributeName] copy];
	
	if ( shad )
	{
		NSSize offset = [shad shadowOffset];
		offset.height = -offset.height;
		[shad setShadowOffset:offset];
		
		[fill setShadow:shad];
		[shad release];
	}
	[styl addRenderer:fill];
	
	// see if there are any stroke attributes:
	
	NSColor*	strokeColour = [[self textAttributes] objectForKey:NSStrokeColorAttributeName];
	CGFloat		sw = [[[self textAttributes] objectForKey:NSStrokeWidthAttributeName] doubleValue];
	
	if ( strokeColour && sw != 0.0 )
	{
		DKStroke*	stroke = [DKStroke strokeWithWidth:fabs(sw) colour:strokeColour];
		[styl addRenderer:stroke];
	}
	
	return [styl autorelease];
}


#pragma mark -
- (void)					setVerticalAlignment:(DKVerticalTextAlignment) align
{
	if( align != m_vertAlign )
	{
		m_vertAlign = align;
		[self invalidateCache];
	}
}


- (DKVerticalTextAlignment)	verticalAlignment
{
	return m_vertAlign;
}


- (void)					setVerticalAlignmentProportion:(CGFloat) prop
{
	mVerticalPosition = prop;
	[self invalidateCache];
}


- (CGFloat)					verticalAlignmentProportion
{
	return mVerticalPosition;
}


#pragma mark -
- (void)					setLayoutMode:(DKTextLayoutMode) mode
{
	if( mode != m_layoutMode )
	{
		m_layoutMode = mode;
		[self invalidateCache];
	}
}


- (DKTextLayoutMode)		layoutMode
{
	return m_layoutMode;
}


- (void)					setFlowedTextPathInset:(CGFloat) inset
{
	mFlowedTextPathInset = inset;
	[self invalidateCache];
}


- (CGFloat)					flowedTextPathInset
{
	return mFlowedTextPathInset;
}



#pragma mark -
- (void)					setAngle:(CGFloat) angle
{
	m_angle = angle;
	[self invalidateCache];
}


- (CGFloat)					angle
{
	return m_angle;
}


- (void)					setAngleInDegrees:(CGFloat) degrees
{
	[self setAngle:DEGREES_TO_RADIANS(degrees)];
}


- (CGFloat)					angleInDegrees
{
	CGFloat angle = RADIANS_TO_DEGREES([self angle]);
	
	if ( angle < 0 )
		angle += 360.0f;
		
	return angle;
}


#pragma mark -
- (void)					setAppliesObjectAngle:(BOOL) aa
{
	m_applyObjectAngle = aa;
	[self invalidateCache];
}


- (BOOL)					appliesObjectAngle
{
	return m_applyObjectAngle;
}


#pragma mark -
- (void)					setWrapsLines:(BOOL) wraps
{
	if( wraps != m_wrapLines )
	{
		m_wrapLines = wraps;
		[self invalidateCache];
	}
}


- (BOOL)					wrapsLines
{
	return m_wrapLines;
}


- (void)					setAllowsTextToExtendHorizontally:(BOOL) hExtends
{
	mAllowIndefiniteWidth = hExtends;
}


- (BOOL)					allowsTextToExtendHorizontally
{
	return mAllowIndefiniteWidth;
}


- (void)					setTextKnockoutDistance:(CGFloat) distance
{
	mTextKnockoutDistance = distance;
	[mTACache removeObjectForKey:kDKTextAdornmentMaskPathCacheKey];
}


- (CGFloat)					textKnockoutDistance
{
	return mTextKnockoutDistance;
}


- (void)					setTextKnockoutStrokeWidth:(CGFloat) width
{
	mTextKnockoutStrokeWidth = width;
}


- (CGFloat)					textKnockoutStrokeWidth
{
	return mTextKnockoutStrokeWidth;
}


- (void)					setTextKnockoutColour:(NSColor*) colour
{
	[colour retain];
	[mTextKnockoutColour release];
	mTextKnockoutColour = colour;
}


- (NSColor*)				textKnockoutColour
{
	return mTextKnockoutColour;
}


- (void)					setTextKnockoutStrokeColour:(NSColor*) colour
{
	[colour retain];
	[mTextKnockoutStrokeColour release];
	mTextKnockoutStrokeColour = colour;
}


- (NSColor*)				textKnockoutStrokeColour
{
	return mTextKnockoutStrokeColour;
}


- (void)					setCapitalization:(DKTextCapitalization) cap
{
	if( mCapitalization != cap )
	{
		mCapitalization = cap;
		[self invalidateCache];
	}
}


- (DKTextCapitalization)	capitalization
{
	return mCapitalization;
}


- (void)					setGreeking:(DKGreeking) greeking
{
	// greeking is a text rendition method that substitutes simple rectangles for the actual drawn glyphs. It can be used to render extremely small point text
	// more quickly, or to give an impression of text. It is rarely used, but can be handy for hit-testing where the exact glyphs are not required and don't work
	// well when rendered using scaling to small bitmap contexts (as when hit-testing).
	
	// currently the greeking setting is considered temporary so isn't archived or exported as an observable property
	
	mGreeking = greeking;
}


- (DKGreeking)				greeking
{
	return mGreeking;
}


#pragma mark -
- (void)					setTextRect:(NSRect) rect
{
	// the textRect defines a rect relative to the shape's original path bounds that the text is laid out in. If you pass NSZeroRect (the default), the text
	// is laid out using the shape's bounds. This additional rect gives you the flexibility to modify the text layout to anywhere within the shape. Note the
	// coordinate system it uses is transformed by the shape's transform - so if you wanted to lay the text out in half the shape's width, the rect's width
	// would be 0.5. Similarly, to offset the text halfway across, its origin would be 0. This means this rect maintains its correct effect no matter how
	// the shape is scaled or rotated, and it does the thing you expect. Otherwise it would have to be recalculated for every new shape size.
	
	m_textRect = rect;
}


- (NSRect)					textRect
{
	return m_textRect;
}


#pragma mark -
- (void)					changeTextAttribute:(NSString*) attribute toValue:(id) val
{
	// adds or removes the given attribute directly to the underlying string. This is called by many other methods that change text attributes,
	// but does preserve unrelated attributes that are applied to character ranges within the string.
	
	NSAssert( attribute != nil, @"text attribute name was nil");
	NSAssert([attribute length] > 0, @"text attribute name was empty");

	NSMutableAttributedString* str = [[[self textSubstitutor] masterString] mutableCopy];
	
	[str beginEditing];
	
	if( val == nil )
		[str removeAttribute:attribute range:NSMakeRange( 0, [str length])];
	else
		[str addAttribute:attribute value:val range:NSMakeRange( 0, [str length])];
	
	[str fixAttributesInRange:NSMakeRange( 0, [str length])];
	[str endEditing];
	
	// setting the label notifies us to invalidate cache
	
	[self setLabel:str];
}


#pragma mark -


- (void)					changeFont:(id) sender
{
	NSMutableAttributedString* str = [[[self textSubstitutor] masterString] mutableCopy];
	[str changeFont:sender];
	[self setLabel:str];
}


- (void)					changeAttributes:(id) sender
{
	NSMutableAttributedString* str = [[[self textSubstitutor] masterString] mutableCopy];
	[str changeAttributes:sender];
	[self setLabel:str];
}


- (void)					setFont:(NSFont*) font
{
	NSAssert( font != nil, @"font was nil");
	
	[self changeTextAttribute:NSFontAttributeName toValue:font];
}


- (NSFont*)					font
{
	NSFont* font = [[self textAttributes] objectForKey:NSFontAttributeName];
	
	if( font == nil )
		font = [NSFont fontWithName:@"Helvetica" size:14];
	
	return font;
}


- (void)					setFontSize:(CGFloat) fontSize
{
	NSMutableAttributedString* str = [[[self textSubstitutor] masterString] mutableCopy];
	[str convertFontsToSize:fontSize];
	[self setLabel:str];
}


- (CGFloat)					fontSize
{
	return [[self font] pointSize];
}


- (void)					scaleTextBy:(CGFloat) factor
{
	// adjusts the text by multiplying all font sizes by <factor>. Values of 0 or 1.0 do nothing.
	
	if( factor > 0.0 && factor != 1.0 )
	{
		NSMutableAttributedString* ms = [[self label] mutableCopy];
		NSRange		range;
		NSUInteger	indx = 0;
		NSFont*		attr;
		CGFloat		fontSize;
		
		while( indx < [ms length])
		{
			attr = (NSFont*)[ms attribute:NSFontAttributeName atIndex:indx effectiveRange:&range];
			
			if( attr )
			{
				fontSize = [attr pointSize] * factor;
				
				attr = [[NSFontManager sharedFontManager] convertFont:attr toSize:fontSize];
				
				[ms addAttribute:NSFontAttributeName value:attr range:range];
			}
			indx = NSMaxRange( range );
		}
		
		[self setLabel:ms];
		[ms release];
	}
}


- (void)					setColour:(NSColor*) colour
{
	if( colour == nil )
		colour = [NSColor blackColor];
	
	[self changeTextAttribute:NSForegroundColorAttributeName toValue:colour];
}


- (NSColor*)				colour
{
	return [[self textAttributes] objectForKey:NSForegroundColorAttributeName];
}



- (void)					setTextAttributes:(NSDictionary*) attrs
{
	// sets the text attributes to those passed in. Attributes can include adornment properties which are removed from the dictionary
	// and applied separately. Note that this method is not effectively undoable, because the 'old' attributes would only give the value at
	// character index 0. However this method is not normally observed directly, so doesn't generate an undo task of its own. Properties
	// set by embedded DK attributes will do so via each property setter. For interactive changing of text attributes, the changeFont:
	// and changeAttributes: methods should be used. For programmatic setting of attributes, use the individual appropriate setter method,
	// which will generate observations normally.
	
	NSMutableDictionary* modAttrs = [attrs mutableCopy];
	
	[modAttrs removeObjectForKey:DKTextCapitalizationAttributeName];
	[modAttrs removeObjectForKey:DKTextKnockoutColourAttributeName];
	[modAttrs removeObjectForKey:DKTextKnockoutDistanceAttributeName];
	[modAttrs removeObjectForKey:DKTextKnockoutStrokeColourAttributeName];
	[modAttrs removeObjectForKey:DKTextKnockoutStrokeWidthAttributeName];
	[modAttrs removeObjectForKey:DKTextVerticalAlignmentAttributeName];
	
	[[self textSubstitutor] setAttributes:modAttrs];
	[modAttrs release];
	
	[self applyNonCocoaTextAttributes:attrs];
}


- (NSDictionary*)			textAttributes
{
	// text attributes returned by this method are the attributes at character index 0. In general you should avoid applying the attributes
	// wholesale to another adornment because any attributes further along will be discarded. This is primarily useful for extracting a single
	// set of attributes to turn into a style, etc.
	
	NSMutableDictionary* attrs = [[[self textSubstitutor] attributes] mutableCopy];
	
	if( attrs == nil )
		attrs = [[self defaultTextAttributes] mutableCopy];
	
	// add all DK-specific attributes that are really properties of the adornment. This conveniently allows these attributes to be copied and pasted to other
	// text and saved in styles.
	
	[attrs setObject:[NSNumber numberWithInteger:[self capitalization]]	forKey:DKTextCapitalizationAttributeName];
	
	if([self textKnockoutColour])
		[attrs setObject:[self textKnockoutColour] forKey:DKTextKnockoutColourAttributeName];
	[attrs setObject:[NSNumber numberWithDouble:[self textKnockoutDistance]] forKey:DKTextKnockoutDistanceAttributeName];
	
	if([self textKnockoutStrokeColour])
		[attrs setObject:[self textKnockoutStrokeColour] forKey:DKTextKnockoutStrokeColourAttributeName];
	
	[attrs setObject:[NSNumber numberWithDouble:[self textKnockoutStrokeWidth]] forKey:DKTextKnockoutStrokeWidthAttributeName];
	[attrs setObject:[NSNumber numberWithInteger:[self verticalAlignment]] forKey:DKTextVerticalAlignmentAttributeName];
	
	return [attrs autorelease];
}


- (NSDictionary*)			defaultTextAttributes
{
	// returns text attributes to be used when there is no text content at present. These will either be what was previously set or the class
	// default.
	
	if( mDefaultAttributes == nil )
		return [[self class] defaultTextAttributes];
	else
		return mDefaultAttributes;
}


- (BOOL)					attributeIsHomogeneous:(NSString*) attributeName
{
	// asks whether a given attribute applies over the entire length of the string.
	
	return [[[self textSubstitutor] masterString] attributeIsHomogeneous:attributeName];
}


- (BOOL)					isHomogeneous
{
	// asks whether all attributes apply over the whole length of the string
	
	return [[[self textSubstitutor] masterString] isHomogeneous];
}


- (void)					applyNonCocoaTextAttributes:(NSDictionary*) attrs
{
	// applies all non-Cocoa attributes in the given dictionary to their individual properties. That in turn adds the same attributes to the current
	// text attributes for the object. This is done when pasting a style with text attributes to apply any attributes that are unique to text adornments.
	
	id val;
	
	val = [attrs objectForKey:DKTextKnockoutColourAttributeName];
	if( val )
		[self setTextKnockoutColour:val];
	
	val = [attrs objectForKey:DKTextKnockoutDistanceAttributeName];
	if( val )
		[self setTextKnockoutDistance:[val doubleValue]];
	else
		[self setTextKnockoutDistance:0];
	
	val = [attrs objectForKey:DKTextKnockoutStrokeColourAttributeName];
	if( val )
		[self setTextKnockoutStrokeColour:val];
	
	val = [attrs objectForKey:DKTextKnockoutStrokeWidthAttributeName];
	if( val )
		[self setTextKnockoutStrokeWidth:[val doubleValue]];
	
	val = [attrs objectForKey:DKTextVerticalAlignmentAttributeName];
	if( val )
		[self setVerticalAlignment:(DKVerticalTextAlignment)[val integerValue]];
	
	val = [attrs objectForKey:DKTextVerticalAlignmentProportionAttributeName];
	if( val )
		[self setVerticalAlignmentProportion:[val doubleValue]];

	val = [attrs objectForKey:DKTextCapitalizationAttributeName];
	if( val )
		[self setCapitalization:(DKTextCapitalization)[val integerValue]];
}


- (void)					setParagraphStyle:(NSParagraphStyle*) style
{
	[self changeTextAttribute:NSParagraphStyleAttributeName toValue:style];
}


- (NSParagraphStyle*)		paragraphStyle
{
	return [[self textAttributes] objectForKey:NSParagraphStyleAttributeName];
}


- (void)					setAlignment:(NSTextAlignment) align
{
	NSMutableParagraphStyle* mps = [[self paragraphStyle] mutableCopy];
	
	if ( mps == nil )
		mps = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
	
	[mps setAlignment:align];
	[self setParagraphStyle:mps];
	[mps release];
}


- (NSTextAlignment)			alignment
{
	return [[self paragraphStyle] alignment];
}


- (void)					setBackgroundColour:(NSColor*) colour
{
	[self changeTextAttribute:NSBackgroundColorAttributeName toValue:colour];
}


- (NSColor*)				backgroundColour
{
	return [[self textAttributes] objectForKey:NSBackgroundColorAttributeName];
}


- (void)					setOutlineColour:(NSColor*) aColour
{
	[self changeTextAttribute:NSStrokeColorAttributeName toValue:aColour];
}


- (NSColor*)				outlineColour
{
	return [[self textAttributes] objectForKey:NSStrokeColorAttributeName];
}


- (void)					setOutlineWidth:(CGFloat) aWidth
{
	// width value is a percentage of font size, see docs for NSStrokeWidthAttributeName
	
	[self changeTextAttribute:NSStrokeWidthAttributeName toValue:[NSNumber numberWithDouble:aWidth]];
}


- (CGFloat)					outlineWidth
{
	return [[[self textAttributes] objectForKey:NSStrokeWidthAttributeName] doubleValue];
}


- (void)					setUnderlines:(NSInteger) under
{
	[self changeTextAttribute:NSUnderlineStyleAttributeName toValue:[NSNumber numberWithInteger:under]];
}


- (NSInteger)						underlines
{
	return [[[self textAttributes] objectForKey:NSUnderlineStyleAttributeName] integerValue];
}


- (void)					setKerning:(CGFloat) kernValue
{
	[self changeTextAttribute:NSKernAttributeName toValue:[NSNumber numberWithDouble:kernValue]];
}


- (CGFloat)					kerning
{
	return [[[self textAttributes] objectForKey:NSKernAttributeName] doubleValue];
}


- (void)					setBaseline:(CGFloat) baseLine
{
	[self changeTextAttribute:NSBaselineOffsetAttributeName toValue:[NSNumber numberWithDouble:baseLine]];
}


- (CGFloat)					baseline
{
	return [[[self textAttributes] objectForKey:NSBaselineOffsetAttributeName] doubleValue];
}


- (void)					setSuperscriptAttribute:(NSInteger) amount
{
	[self changeTextAttribute:NSSuperscriptAttributeName toValue:[NSNumber numberWithInteger:amount]];
}


- (NSInteger)						superscriptAttribute
{
	return [[[self textAttributes] objectForKey:NSSuperscriptAttributeName] integerValue];
}



#pragma mark -

- (void)					loosenKerning
{
	CGFloat increment = MIN([self fontSize] / 72.0, 1.0);
	[self setKerning:[self kerning] + increment];
}



- (void)					tightenKerning
{
	// In the current implementation the increment is (point size) / 72.0,  
	//truncated at two decimal places and limited to a maximum of 1.00.  In  
	//the absence of a font attribute, the default point size is 12.
	
	CGFloat increment = MIN([self fontSize] / 72.0, 1.0);
	[self setKerning:[self kerning] - increment];
}



- (void)					turnOffKerning
{
	[self setKerning:0];
}


- (void)					useStandardKerning
{
	[self changeTextAttribute:NSKernAttributeName toValue:nil];
}


- (void)					lowerBaseline
{
	[self setBaseline:[self baseline] - 1];
}



- (void)					raiseBaseline
{
	[self setBaseline:[self baseline] + 1];
}


- (void)					superscript
{
	[self setSuperscriptAttribute:[self superscriptAttribute] + 1];
}


- (void)					subscript
{
	[self setSuperscriptAttribute:[self superscriptAttribute] - 1];
}



- (void)					unscript
{
	[self setSuperscriptAttribute:0];
}


- (void)					setTextSubstitutor:(DKTextSubstitutor*) subs
{
	if( subs != mSubstitutor )
	{
		[[NSNotificationCenter defaultCenter] removeObserver:self name:kDKTextSubstitutorNewStringNotification object:nil];
		
		[subs retain];
		[mSubstitutor release];
		mSubstitutor = subs;
		
		if( mSubstitutor )
			[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(masterStringChanged:) name:kDKTextSubstitutorNewStringNotification object:mSubstitutor];
	}
}


- (DKTextSubstitutor*)		textSubstitutor
{
	return mSubstitutor;
}


- (BOOL)					allTextWasFitted
{
	return mLastLayoutFittedAllText;
}


- (void)					invalidateCache
{
	// empties the cache, causing all information it contains to be recalculated as needed
	
	[mTACache removeAllObjects];
}


- (void)					masterStringChanged:(NSNotification*) note
{
	// invalidates the cache whenever the substitutor notifies a change to the string content or attributes

#pragma unused(note)
	[self invalidateCache];
}



#pragma mark -

- (NSTextStorage*)			textToDraw:(id) object
{
	// text actually drawn consists of the master string with any substitutions from the object's metadata performed.
	
	NSTextStorage*				str;
	NSMutableAttributedString*	ttd;
	
	ttd = [[[self textSubstitutor] substitutedStringWithObject:object] mutableCopy];
	
	// if resulting string is empty, use the placeholder string
	
	if ([ttd length] == 0 && [self placeholderString])
	{
		NSAttributedString* placeholder = [[NSAttributedString alloc] initWithString:[self placeholderString] attributes:[self textAttributes]];
		[ttd appendAttributedString:placeholder];
		[placeholder release];
	}
	// capitalize the text according to our capitalization setting:
	
	switch([self capitalization])
	{
		default:
			break;
			
		case kDKTextCapitalizationUppercase:
			[ttd makeUppercase];
			break;
			
		case kDKTextCapitalizationLowercase:
			[ttd makeLowercase];
			break;
			
		case kDKTextCapitalizationCapitalize:
			[ttd capitalize];
			break;
	}

	// initialise text storage from the string 'ttd'
	
	str = [[NSTextStorage alloc] initWithAttributedString:ttd];
	
	// if the object is ghosted, use a text outline style
	
	if([object respondsToSelector:@selector(isGhosted)] && [object isGhosted])
	{
		NSMutableDictionary* ta = [[self textAttributes] mutableCopy];
		[ta setObject:[[object class] ghostColour] forKey:NSStrokeColorAttributeName];
		[ta setObject:[[object class] ghostColour] forKey:NSForegroundColorAttributeName];
		[ta setObject:[NSNumber numberWithDouble:1.5f] forKey:NSStrokeWidthAttributeName];
		[str setAttributes:ta range:NSMakeRange(0, [str length])];
		[ta release];
	}
	[ttd release];
	
	return [str autorelease];
}


- (NSAffineTransform*)		textTransformForObject:(id<DKRenderable>) obj
{
	// returns a transform that will draw the text at the shape's location and rotation. This transform doesn't apply the shape's scale
	// since the text is laid out based on the final shape size, not on the original path.
	
	NSPoint loc;

	if([obj respondsToSelector:@selector(locationIgnoringOffset)])
		loc = [(id)obj locationIgnoringOffset];
	else
	{
		// must be a path, or flowing text, so pretend its location is in the centre - this allows
		// text to be laid out correctly in a path object
		
		NSRect pb =[[obj renderingPath] bounds];
		
		loc.x = NSMidX( pb );
		loc.y = NSMidY( pb );
	}

	NSAffineTransform* xform = [NSAffineTransform transform];
	[xform translateXBy:loc.x yBy:loc.y];
	
	if ([self appliesObjectAngle])
		[xform rotateByRadians:[self angle] + [obj angle]];
	else
		[xform rotateByRadians:[self angle]];
	
	// 'containerTransform' isn't part of the rendering protocol, so under some circumstances the object may
	// not actually implement it.
	
	if([obj respondsToSelector:@selector(containerTransform)])
		[xform appendTransform:[obj containerTransform]];

	return xform;
}


- (NSPoint)					textOriginForSize:(NSSize) textSize objectSize:(NSSize) osize
{
	NSPoint textOrigin = NSZeroPoint;
	NSRect	tr = [self textRect];
	
	if ( NSEqualRects( NSZeroRect, tr ))
		tr.size = osize;
	else
	{
		tr.size.width *= osize.width;
		tr.size.height *= osize.height;
	}
	
	textOrigin.x -= ( 0.5 * osize.width );
	textOrigin.y -= ( 0.5 * osize.height );
	
	// factor in textRect offset
	
	textOrigin.x += ( tr.origin.x * osize.width);
	textOrigin.y += ( tr.origin.y * osize.height);
	
	// factor in setting for vertical alignment

	textOrigin.y += [self verticalTextOffsetForTextSize:textSize objectSize:tr.size];

	return textOrigin;
}


- (void)					drawText:(NSTextStorage*) contents withObject:(id<DKRenderable>) obj withPath:(NSBezierPath*) path
{
	[self drawText:contents withObject:obj withPath:path layoutManager:[self layoutManager]];
}


- (void)					drawText:(NSTextStorage*) contents withObject:(id<DKRenderable>) obj withPath:(NSBezierPath*) path layoutManager:(NSLayoutManager*) lm
{
	NSAssert( lm != nil, @"there must be a valid layout manager when calling -drawText:withObject:withPath:layoutManager:");
	
	if ([contents length] > 0)
	{
		NSSize				osize = obj? [obj size] : [path bounds].size;
		
		DKBezierTextContainer* bc = [[lm textContainers] lastObject];

		if([self layoutMode] == kDKTextLayoutFlowedInPath)
		{
			// if the text angle is rel to the object, the layout path should be the unrotated path
			// so the the text is laid out unrotated, then transformed into place. So detect that case here
			// and compensate the path for the angle.
			
			NSBezierPath* textLayoutPath = path;

			if([self flowedTextPathInset] != 0.0 )
			{
				[bc setLineFragmentPadding:[self flowedTextPathInset]];
				
			}

			NSAffineTransform* tfm = [self textTransformForObject:obj];
			[tfm invert];
			
			textLayoutPath = [tfm transformBezierPath:textLayoutPath]; 

			osize = [textLayoutPath bounds].size;
			[bc setContainerSize:osize];
			[bc setBezierPath:textLayoutPath];
		}
		else
		{
			if([self allowsTextToExtendHorizontally])
				osize.width = 50000;
			
			[bc setBezierPath:nil];
			[bc setContainerSize:osize];
		}
		
		NSRange		glyphRange;
		NSRange		grange;
		NSRect		frag;

		[contents addLayoutManager:lm];

		// Force layout of the text and find out how much of it fits in the container.
		
		glyphRange = [lm glyphRangeForTextContainer:bc];
		
		// flag whether all the text was laid out. This can be queried to see if a "more text" marker should be shown
		// by the bject that is using this service.
		
		NSRange fullRange = [lm glyphRangeForCharacterRange:NSMakeRange( 0, [contents length]) actualCharacterRange:NULL];
		mLastLayoutFittedAllText = NSEqualRanges( fullRange, glyphRange );
		
		// because of the object transform applied, draw the text at the origin
		
		if (glyphRange.length > 0)
		{
			NSSize textSize = [lm usedRectForTextContainer:bc].size;
			
			// if not wrapping lines, draw only the first line
			
			if(! [self wrapsLines])
			{
				frag = [lm lineFragmentUsedRectForGlyphAtIndex:0 effectiveRange:&grange];
				textSize.height = frag.size.height;
			}
			else
				grange = glyphRange;
			
			NSPoint textOrigin = [self textOriginForSize:textSize objectSize:osize];
			
			if ([self layoutMode] == kDKTextLayoutFlowedInPath && [self flowedTextPathInset] != 0.0 )
				textOrigin.y += [self flowedTextPathInset] * 0.5;
			
			[lm drawBackgroundForGlyphRange:grange atPoint:textOrigin];
			[lm drawGlyphsForGlyphRange:grange atPoint:textOrigin];
		}
		[contents removeLayoutManager:lm];
	}
}



- (CGFloat)					baselineOffset
{
	return [self baselineOffsetForTextHeight:0];
}


- (CGFloat)					baselineOffsetForTextHeight:(CGFloat) height
{
	CGFloat dy = 0;
	
	switch ([self verticalAlignment])
	{
		case kDKTextShapeVerticalAlignmentTop:
			dy = [[self class] defaultMaximumVerticalOffset];
			break;
			
		case kDKTextShapeVerticalAlignmentBottom:
			dy = -[[self class] defaultMaximumVerticalOffset];
			break;
			
		case kDKTextShapeVerticalAlignmentCentre:
			dy = 1;
			break;
			
		case kDKTextShapeVerticalAlignmentProportional:
			dy = ([self verticalAlignmentProportion] - 0.5) * -([[self class] defaultMaximumVerticalOffset] * 2);
			break;
			
		case kDKTextPathVerticalAlignmentCentredOnPath:
			// text height is used so that the text is centred on the path exactly. dy will be typically slightly negative.
			// <height> is the distance between the top of the characters and the baseline (i.e. the xHeight)
			
			dy = ( height * -0.5f );
			break;
			
		default:
			break;
	}
	
	return dy;
}


- (CGFloat)					verticalTextOffsetForObject:(id<DKRenderable>) object
{
	NSRect tlr = [self textLayoutRectForObject:object];
	return tlr.origin.y;
}


- (NSRect)					textLayoutRectForObject:(id<DKRenderable>) object
{
	// returns the vertical offset from the top of the layout object to the top of the text. This performs text layout in order to measure the
	// text height, so should be considered relatively expensive. It can be used by a client object to position a text editor exactly with respect to the
	// displayed text. Note that in certain layout modes this immediately returns an empty rect.
	
	if([self layoutMode] == kDKTextLayoutAlongReversedPath ||
	   [self layoutMode] == kDKTextLayoutAlongPath )
		return NSZeroRect;
	else
	{
		NSTextStorage*	str = [self textToDraw:object];
		
		// if no text, nothing to do
		
		if ( str == nil )
			return NSZeroRect;
		
		NSSize					oSize = [object size];
		NSLayoutManager*		lm = sharedDrawingLayoutManager();
		DKBezierTextContainer*	bc = [[lm textContainers] lastObject];
		
		if([self allowsTextToExtendHorizontally])
			oSize.width = 50000;
		
		[bc setBezierPath:nil];
		[bc setContainerSize:oSize];
		[str addLayoutManager:lm];
		
		NSRange		glyphRange;
		NSRect		tlr = NSZeroRect;
		
		// Force layout of the text and find out how much of it fits in the container.
		
		glyphRange = [lm glyphRangeForTextContainer:bc];
		tlr = [lm usedRectForTextContainer:bc];
		CGFloat offset = [self verticalTextOffsetForTextSize:tlr.size objectSize:oSize];
		tlr.origin.y += offset;
		
		[str removeLayoutManager:lm];
		
		return tlr;
	}
}


- (CGFloat)					verticalTextOffsetForTextSize:(NSSize) textSize objectSize:(NSSize) osize
{
	// returns the distance from the top of the layout rectangle <osize> to the top of the text with size <textSize>, taking into account the current vertical
	// alignment settings.
	
	CGFloat offset = 0;
	
	if([self layoutMode] != kDKTextLayoutFlowedInPath)
	{
		switch([self verticalAlignment])
		{
			default:
			case kDKTextShapeVerticalAlignmentTop:
				break;
				
			case kDKTextShapeVerticalAlignmentCentre:
				offset = 0.5 * (osize.height - textSize.height);
				break;
				
			case kDKTextShapeVerticalAlignmentBottom:
				offset = (osize.height - textSize.height);
				break;
				
			case kDKTextShapeVerticalAlignmentProportional:
				offset = mVerticalPosition * (osize.height - textSize.height);
				break;
				
			case kDKTextShapeAlignTextToPoint:
				// this sets the origin of the text to a point nominated by the host object itself
				// and the positioning is set up elsewhere
				break;
		}
	}
	
	return offset;
}

#define qDebugTextPoint		1


- (void)					drawText:(NSTextStorage*) contents centredAtPoint:(NSPoint) p
{
	NSSize	bboxSize = [contents size];
	NSPoint origin;
	
	origin.x = p.x - ( bboxSize.width * 0.5f );
	origin.y = p.y - ( bboxSize.height * 0.5f );
	
	[contents drawAtPoint:origin];
	
#if qDebugTextPoint
	
	[[NSColor redColor] set];
	NSBezierPath* path = [DKShapeFactory cross];
	
	NSAffineTransform* tfm = [NSAffineTransform transform];
	[tfm translateXBy:p.x yBy:p.y];
	[tfm scaleXBy:10 yBy:10];
	[path transformUsingAffineTransform:tfm];
	
	[path stroke];
	
#endif
}


- (void)					drawKnockoutWithObject:(id<DKRenderable>) obj
{
	BOOL ghost = NO;
	
	if([obj respondsToSelector:@selector(isGhosted)])
		ghost = [(id)obj isGhosted];
	
	if([self textKnockoutDistance] > 0.0 && !ghost)
	{
		// see if the object size has changed since last time - if so, the cached info can't be reliable. Note that
		// the general case of a text change will have invalidated the entire cache. This checks for a layout change
		// that is only in consideration of the text mask effect.
		
		NSUInteger	cs = [[mTACache objectForKey:kDKTextAdornmentMaskObjectChecksumCacheKey] integerValue];
		NSUInteger	geoCheck = [(id)obj geometryChecksum] ^ [(id)obj metadataChecksum];
		
		if( geoCheck != cs )
		{
			[mTACache removeObjectForKey:kDKTextAdornmentMaskPathCacheKey];
			[mTACache setObject:[NSNumber numberWithInteger:geoCheck] forKey:kDKTextAdornmentMaskObjectChecksumCacheKey];
		}
		
		NSBezierPath* textPath;
		
		// see if an earlier path was cached:
		
		textPath = [mTACache objectForKey:kDKTextAdornmentMaskPathCacheKey];
		
		if( textPath == nil )
		{
			// not in cache, so calculate it
			
			textPath = [self textAsPathForObject:obj];
			
			// knockout distance is expressed in terms of percentage of font height. So convert that to absolute value.
			// distance is doubled to give effective strokewidth for calculating the outline path
			
			CGFloat fontHeight = [[self font] pointSize];
			CGFloat dist = ([self textKnockoutDistance] * fontHeight ) / 50.0f;
			
			[textPath setLineJoinStyle:NSRoundLineJoinStyle];
			[textPath setLineCapStyle:NSRoundLineCapStyle];
			textPath = [textPath strokedPathWithStrokeWidth:dist];
			[textPath setWindingRule:NSNonZeroWindingRule];
			
			[mTACache setObject:textPath forKey:kDKTextAdornmentMaskPathCacheKey];
		}
		
		if([self textKnockoutColour])
		{
			[[self textKnockoutColour] set];
			[textPath fill];
		}
		
		if([self textKnockoutStrokeWidth] > 0 && [self textKnockoutStrokeColour])
		{
			[[self textKnockoutStrokeColour] set];
			[textPath setLineWidth:[self textKnockoutStrokeWidth]];
			[textPath stroke];
		}
	}
}


- (void)					drawInRect:(NSRect) aRect
{
	// this is used when drawing style swatches and should not be used for drawing normally
	
	DKDrawableShape* shape = [DKDrawableShape drawableShapeWithRect:aRect];
	[self render:shape];
}


- (NSLayoutManager*)		layoutManager
{
	if([self greeking] == kDKGreekingNone )
		return sharedDrawingLayoutManager();
	else
	{
		// greeking is implemented using a greeking layout manager
		
		DKGreekingLayoutManager* glm = [[DKGreekingLayoutManager alloc] init];
		[glm setGreeking:[self greeking]];
		
		DKBezierTextContainer* tc = [[DKBezierTextContainer alloc] initWithContainerSize:NSMakeSize(1.0e6, 1.0e6)];
		[tc setWidthTracksTextView:NO];
		[tc setHeightTracksTextView:NO];
		[glm addTextContainer:tc];
		[tc release];
		
		[glm setUsesScreenFonts:NO];
		
		return [glm autorelease];
	}
}


#pragma mark -
#pragma mark As a DKRasterizer

- (BOOL)					isValid
{
	return YES;
}


- (NSSize)					extraSpaceNeeded
{
	NSSize es = NSZeroSize;
	
	if(([self layoutMode] != kDKTextLayoutInBoundingRect) && [self enabled])
	{
		// add in the current lineheight to both width and height. As we are only interested in the lineheight, we just use
		// some dummy text in conjunction with our current attributes
		
		NSInteger opts = NSStringDrawingUsesFontLeading | NSStringDrawingDisableScreenFontSubstitution | NSStringDrawingUsesDeviceMetrics | NSStringDrawingOneShot;
		
		NSSize	textBoxSize = NSMakeSize(1000,200);
		
		NSRect	tbr = [@"Dummy Text" boundingRectWithSize:textBoxSize options:opts attributes:[self textAttributes]];
		
		// factor in the baseline offset
		
		CGFloat extra = tbr.size.height + ABS([self baselineOffset]);
		
		// NOTE: this method cannot help with the space needed for text drawn at the centroid, because we have no way to know
		// precisely what text will be drawn and where (no object). Thus the client will need to compute this if it knows
		// it could be making use of centroid layout.
		
		es = NSMakeSize( extra, extra );
	}
	
	if([self textKnockoutDistance] > 0)
	{
		CGFloat fontHeight = [[self font] pointSize];
		CGFloat dist = ([self textKnockoutDistance] * fontHeight ) / 100.0f;
		
		es.width += dist;
		es.height += dist;
	}
	
	return es;
}


- (void)					render:(id<DKRenderable>) object
{
	if(![self enabled])
		return;
	
	if( ![object conformsToProtocol:@protocol(DKRenderable)])
		return;
	
	// check the cache for the last client of this renderer. If it's not the same one, any cached information can't be reliable
	// so the cache must be invalidated. For TAs associated with text objects, the client object will invariably be the same one.
	
	@try
	{
		NSUInteger cs, ccs = [[mTACache objectForKey:kDKTextAdornmentMetadataChecksumCacheKey] integerValue];
		cs = [(id)object metadataChecksum];
		if( cs != ccs )
		{
			[self invalidateCache];
			[mTACache setObject:[NSNumber numberWithInteger:ccs] forKey:kDKTextAdornmentMetadataChecksumCacheKey];
		}

		NSTextStorage*	str = [self textToDraw:object];
		
		// if no text, nothing to do
		
		if ( str == nil || [str length] == 0 )
			return;
		
		// draw it according to settings with the object's path bounds
		
		if([self layoutMode] == kDKTextLayoutAtCentroid )
		{
			// the object supplies the point at which to position the text - this doesn't necessarily have to be its centroid
			// but that's the intention of this setting
			
			if([object respondsToSelector:@selector(pointForTextLayout)])
			{
				NSPoint tp = [(NSObject*)object pointForTextLayout];
				[self drawText:str centredAtPoint:tp];
			}
		}
		else
		{
			SAVE_GRAPHICS_CONTEXT		//[NSGraphicsContext saveGraphicsState];
			NSBezierPath*	path = [self renderingPathForObject:object];
					
			if ( [self layoutMode] == kDKTextLayoutAlongReversedPath )
				path = [path bezierPathByReversingPath];
			
			if([self layoutMode] == kDKTextLayoutAlongReversedPath ||
				[self layoutMode] == kDKTextLayoutAlongPath )
			{
				// draw any knockout behind the text - warning: potentially expensive.
				
				if([self greeking] == kDKGreekingNone )
					[self drawKnockoutWithObject:object];

				// measure the text height for the centring option based on the font of the first character
				
				CGFloat baseOffset;
				
				if([self verticalAlignment] == kDKTextPathVerticalAlignmentCentredOnPath)
				{
					NSFont*	font = [str attribute:NSFontAttributeName atIndex:0 effectiveRange:NULL];
					baseOffset = [self baselineOffsetForTextHeight:[font xHeight]];
				}
				else
					baseOffset = [self baselineOffset];
				
				NSLayoutManager* lm = nil;
				
				if([self greeking] != kDKGreekingNone )
					lm = [self layoutManager];
				
				// passing nil as lm causes text on path to be laid out using its own shared lm for the purpose
				
				mLastLayoutFittedAllText = [path drawTextOnPath:str yOffset:baseOffset layoutManager:lm cache:mTACache];
			}
			else
			{
				if([self clipping] != kDKClippingNone )
					[path addClip];
				
				// draw any knockout behind the text - warning: potentially expensive.
				
				if([self greeking] == kDKGreekingNone )
					[self drawKnockoutWithObject:object];

				NSAffineTransform* tfm = [self textTransformForObject:object];
				[tfm concat];
				
				// draw the text
				
				[self drawText:str withObject:object withPath:path];
			}
			RESTORE_GRAPHICS_CONTEXT	//[NSGraphicsContext restoreGraphicsState];
		}
	}
	@catch( NSException* exception )
	{
		// an exception while rendering is bad news - this logs the exception and disabled the rasterizer in an effort to avoid a spiral of errors. Any
		// problems found should be properly inverstigated
		
		NSLog(@"Text Adornment (%@) threw an exception during rendering - PLEASE FIX - rasterizer will be disabled. Exception = %@", self, exception);
		[self setEnabled:NO];
		@throw;
	}
}


#pragma mark -
#pragma mark As a GCObservableObject
+ (NSArray*)		observableKeyPaths
{
	return [[super observableKeyPaths] arrayByAddingObjectsFromArray:[NSArray arrayWithObjects:@"label", @"identifier", @"angle", @"wrapsLines",
				 @"appliesObjectAngle", @"verticalAlignment", @"font", @"colour", @"alignment", @"capitalization", @"baseline", @"superscriptAttribute", @"kerning",
				@"paragraphStyle", @"layoutMode", @"flowedTextPathInset", @"allowsTextToExtendHorizontally", @"verticalAlignmentProportion", 
				@"outlineColour", @"outlineWidth", @"textKnockoutDistance", @"textKnockoutColour", @"textKnockoutStrokeWidth", @"textKnockoutStrokeColour",
				@"placeholderString", nil]];
}


- (void)					registerActionNames
{
	[super registerActionNames];
	[self setActionName:@"#kind# Text" forKeyPath:@"label"];
	[self setActionName:@"#kind# Identifier" forKeyPath:@"identifier"];
	[self setActionName:@"#kind# Font" forKeyPath:@"font"];
	[self setActionName:@"#kind# Paragraph Style" forKeyPath:@"paragraphStyle"];
	[self setActionName:@"#kind# Vertical Alignment" forKeyPath:@"verticalAlignment"];
	[self setActionName:@"#kind# Text Angle" forKeyPath:@"angle"];
	[self setActionName:@"#kind# Line Wrap" forKeyPath:@"wrapsLines"];
	[self setActionName:@"#kind# Text Layout" forKeyPath:@"layoutMode"];
	[self setActionName:@"#kind# Tracks Object Angle" forKeyPath:@"appliesObjectAngle"];
	[self setActionName:@"#kind# Text Inset" forKeyPath:@"flowedTextPathInset"];
	[self setActionName:@"#kind# Allow Horizontal Extension" forKeyPath:@"allowsTextToExtendHorizontally"];
	[self setActionName:@"#kind# Vertical Position" forKeyPath:@"verticalAlignmentProportion"];
	[self setActionName:@"#kind# Mask Amount" forKeyPath:@"textKnockoutDistance"];
	[self setActionName:@"#kind# Mask Colour" forKeyPath:@"textKnockoutColour"];
	[self setActionName:@"#kind# Mask Stroke Width" forKeyPath:@"textKnockoutStrokeWidth"];
	[self setActionName:@"#kind# Mask Stroke Colour" forKeyPath:@"textKnockoutStrokeColour"];
	[self setActionName:@"#kind# Capitalization" forKeyPath:@"capitalization"];
	[self setActionName:@"#kind# Placeholder String" forKeyPath:@"placeholderString"];
}


#pragma mark -
#pragma mark As an NSObject
- (void)					dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[mTACache release];
	[mSubstitutor release];
	[mTextKnockoutColour release];
	[mTextKnockoutStrokeColour release];
	[mPlaceholder release];
	[mDefaultAttributes release];
	[super dealloc];
}


- (id)						init
{
	self = [super init];
	if (self != nil)
	{
		m_layoutMode = kDKTextLayoutInBoundingRect;
		m_wrapLines = YES;
		m_applyObjectAngle = YES;
		[self setFlowedTextPathInset:3];
		
		mTACache = [[NSMutableDictionary alloc] init];
	}
	
	if (self != nil)
	{
		mSubstitutor = [[DKTextSubstitutor alloc] init];

		[self setLabel:[[self class] defaultLabel]];
		[self setVerticalAlignment:kDKTextShapeVerticalAlignmentCentre];
		
		[self setTextKnockoutColour:[[NSColor whiteColor] colorWithAlphaComponent:0.67]];
		[self setTextKnockoutStrokeColour:[[NSColor blackColor] colorWithAlphaComponent:0.67]];
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(masterStringChanged:) name:kDKTextSubstitutorNewStringNotification object:mSubstitutor];
	}
	return self;
}


#pragma mark -
#pragma mark As part of NSCoding Protocol
- (void)					encodeWithCoder:(NSCoder*) coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	[super encodeWithCoder:coder];
	
	[coder encodeObject:[self textSubstitutor] forKey:@"DKTextAdornment_substitutor"];
	
	[coder encodeDouble:[self angle] forKey:@"angle"];
	[coder encodeInteger:[self verticalAlignment] forKey:@"valign"];
	[coder encodeInteger:[self layoutMode] forKey:@"layout_mode"];
	[coder encodeBool:[self wrapsLines] forKey:@"wraps"];
	[coder encodeBool:[self appliesObjectAngle] forKey:@"objangle"];
	[coder encodeDouble:[self flowedTextPathInset] forKey:@"DKTextAdornment_flowedTextInset"];
	[coder encodeBool:mAllowIndefiniteWidth forKey:@"DKTextAdornment_allowIndefWidth"];
	[coder encodeDouble:mVerticalPosition forKey:@"DKTextAdornment_verticalPosition"];
	
	[coder encodeDouble:[self textKnockoutDistance] forKey:@"DKTextAdornment_knockoutDistance"];
	[coder encodeObject:[self textKnockoutColour] forKey:@"DKTextAdornment_knockoutColour"];
	[coder encodeDouble:[self textKnockoutStrokeWidth] forKey:@"DKTextAdornment_knockoutStrokeWidth"];
	[coder encodeObject:[self textKnockoutColour] forKey:@"DKTextAdornment_knockoutStrokeColour"];
	
	[coder encodeInteger:[self capitalization] forKey:@"DKTextAdornment_capitalization"];
	[coder encodeObject:[self placeholderString] forKey:@"DKTextAdornment_placeholder"];
}


- (id)						initWithCoder:(NSCoder*) coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	self = [super initWithCoder:coder];
	if (self != nil)
	{
		mTACache = [[NSMutableDictionary alloc] init];

		// identifiers are deprecated in favour of substitution - to migrate older objects, we append the identifier
		// to the end of the master string using appropriate delimiters. This gives identical results to the earlier
		// approach which simply appended the identifier to the label.
		
		// Note that substiution itself has evolved to support attributed strings, so the local text attributes are also deprecated.
		// The code here should migrate any older versions of the text adornment to the new model, however they were encoded.
		
		[self setTextSubstitutor:[coder decodeObjectForKey:@"DKTextAdornment_substitutor"]];
		
		if([self textSubstitutor] == nil )
		{
			// older file predating the separate text substitutor
			
			DKTextSubstitutor* subs = [[DKTextSubstitutor alloc] init];
			[self setTextSubstitutor:subs];
			[subs release];

			// reading the label may read an attributed string which will set the text attributes for all text
			
			[self setLabel:[coder decodeObjectForKey:@"text"]];

			// read text attributes separately for in-between implementation, where attributes were not stored
			// by the substitutor.
			
			if([coder containsValueForKey:@"DKTextAdornment_textAttributes"])
				[self setTextAttributes:[coder decodeObjectForKey:@"DKTextAdornment_textAttributes"]];
			else
			{
				// older format may not have saved any attributes - if not, use default
				
				if([self textAttributes] == nil )
					[self setTextAttributes:[[self class] defaultTextAttributes]];
			}
		}
		
		// older files may have an identifier set - if so move it to the modern substitutor
		
		NSString* ident = [coder decodeObjectForKey:@"identifier"];
		
		if([ident length] > 0 )
		{
			NSMutableString* master = [[self string] mutableCopy];
			[master appendFormat:@"%@%@", [DKTextSubstitutor delimiterString], ident];
			[[self textSubstitutor] setString:master withAttributes:nil];
			[master release];
			
			LogEvent_( kInfoEvent, @"%@ migrated identifier '%@' to substitution model", self, ident);
		}
		
		// all other properties
		
		[self setAngle:[coder decodeDoubleForKey:@"angle"]];
		[self setVerticalAlignment:[coder decodeIntegerForKey:@"valign"]];
		[self setLayoutMode:[coder decodeIntegerForKey:@"layout_mode"]];
		[self setWrapsLines:[coder decodeBoolForKey:@"wraps"]];
		[self setAppliesObjectAngle:[coder decodeBoolForKey:@"objangle"]];
		[self setFlowedTextPathInset:[coder decodeDoubleForKey:@"DKTextAdornment_flowedTextInset"]];
		mAllowIndefiniteWidth = [coder decodeBoolForKey:@"DKTextAdornment_allowIndefWidth"];
		mVerticalPosition = [coder decodeDoubleForKey:@"DKTextAdornment_verticalPosition"];
		
		[self setTextKnockoutDistance:[coder decodeDoubleForKey:@"DKTextAdornment_knockoutDistance"]];
		[self setTextKnockoutColour:[coder decodeObjectForKey:@"DKTextAdornment_knockoutColour"]];
		[self setTextKnockoutStrokeWidth:[coder decodeDoubleForKey:@"DKTextAdornment_knockoutStrokeWidth"]];
		[self setTextKnockoutStrokeColour:[coder decodeObjectForKey:@"DKTextAdornment_knockoutStrokeColour"]];
		
		[self setCapitalization:[coder decodeIntegerForKey:@"DKTextAdornment_capitalization"]];
		//[self setPlaceholderString:[coder decodeObjectForKey:@"DKTextAdornment_placeholder"]];
	}
	return self;
}


#pragma mark -
#pragma mark As part of NSCopying Protocol
- (id)						copyWithZone:(NSZone*) zone
{
	DKTextAdornment* copy = [super copyWithZone:zone];
	
	NSAttributedString* label = [[self label] copyWithZone:zone];
	[copy setLabel:label];
	[label release];
	
	[copy setVerticalAlignment:[self verticalAlignment]];
	[copy setAngle:[self angle]];
	[copy setAppliesObjectAngle:[self appliesObjectAngle]];
	[copy setWrapsLines:[self wrapsLines]];
	[copy setLayoutMode:[self layoutMode]];
	[copy setFlowedTextPathInset:[self flowedTextPathInset]];
	[copy setAllowsTextToExtendHorizontally:[self allowsTextToExtendHorizontally]];
	[copy setVerticalAlignmentProportion:[self verticalAlignmentProportion]];
	
	[copy setTextKnockoutDistance:[self textKnockoutDistance]];
	[copy setTextKnockoutColour:[self textKnockoutColour]];
	[copy setTextKnockoutStrokeWidth:[self textKnockoutStrokeWidth]];
	[copy setTextKnockoutStrokeColour:[self textKnockoutStrokeColour]];
	
	[copy setCapitalization:[self capitalization]];
	[copy setPlaceholderString:[self placeholderString]];
	return copy;
}

#pragma mark -
#pragma mark - deprecated

- (void)					setIdentifier:(NSString*) ident
{
#pragma unused(ident)
	NSLog(@"Use of [DKTextAdornment setIdentifier] is deprecated - use embedded substitution instead");
}


- (NSString*)				identifier
{
	return nil;
}



@end
