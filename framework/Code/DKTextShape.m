//
//  DKTextShape.m
///  DrawKit ©2005-2008 Apptree.net
//
//  Created by graham on 16/09/2006.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
//

#import "DKTextShape.h"
#import "DKTextAdornment.h"
#import "DKDrawableObject+Metadata.h"
#import "DKTextPath.h"
#import "DKDrawing.h"
#import "DKDrawKitMacros.h"
#import "DKStyle+Text.h"
#import "DKDrawingView.h"
#import "DKFill.h"
#import "DKObjectDrawingLayer.h"
#import "DKShapeGroup.h"
#import "DKStroke.h"
#import "DKGeometryUtilities.h"
#import "LogEvent.h"
#import "NSAffineTransform+DKAdditions.h"
#import "NSAttributedString+DKAdditions.h"
#import "DKKnob.h"
#import "DKDrawableShape+Utilities.h"


NSString*	kDKTextOverflowIndicatorDefaultsKey = @"DKTextOverflowIndicator";
NSString*	kDKTextAllowsInlineImagesDefaultsKey = @"DKTextAllowsInlineImages";


#pragma mark Static Vars

static NSString*	sDefault_string = @"Double-click to edit this text";

@interface DKTextShape (Private)

- (DKTextAdornment*)makeTextAdornment;
- (void)			changeKeyPath:(NSString*) keypath ofObject:(id) object toValue:(id) value;
- (DKTextPath*)		makeTextPathObject;
- (void)			mutateStyle;
- (void)			textWillChange:(NSNotification*) note;

@end



#pragma mark -
@implementation DKTextShape
#pragma mark As a DKTextShape
///*********************************************************************************************************************
///
/// method:			textShapeWithString:inRect:
/// scope:			public class method
/// description:	create an instance of a DKTextShape with the initial string and rect.
/// 
/// parameters:		<str> the initial string to set
///					<bounds> the bounding rectangle of the shape
/// result:			an autoreleased DKTextShape instance
///
/// notes:			
///
///********************************************************************************************************************

+ (DKTextShape*)			textShapeWithString:(NSString*) str inRect:(NSRect) bounds
{
	DKTextShape*  te = [[self alloc] initWithRect:bounds style:[DKStyle defaultTextStyle]];
	
	[te setText:str];

	return [te autorelease];
}


///*********************************************************************************************************************
///
/// method:			textShapeWithRTFData:inRect:
/// scope:			public class method
/// description:	create an instance of a DKTextShape with the RTF data and rect.
/// 
/// parameters:		<rtfData> NSData representing some RTF text
///					<bounds> the bounding rectangle of the shape
/// result:			an autoreleased DKTextShape instance
///
/// notes:			
///
///********************************************************************************************************************

+ (DKTextShape*)			textShapeWithRTFData:(NSData*) rtfData inRect:(NSRect) bounds
{
	DKTextShape*  te = [[self alloc] initWithRect:bounds style:[DKStyle defaultTextStyle]];
	
	NSAttributedString* str = [[NSAttributedString alloc] initWithRTF:rtfData documentAttributes:nil];
	[te setText:str];
	[str release];

	return [te autorelease];
}


///*********************************************************************************************************************
///
/// method:			textShapeWithAttributedString:
/// scope:			public class method
/// description:	create an instance of a DKTextShape with the given string, laid out on one line.
/// 
/// parameters:		<str> the string
/// result:			an autoreleased DKTextShape instance
///
/// notes:			The object is sized to fit the text string passed on a single line (up to a certain sensible
///					maximum width). The returned object needs to be positioned where it is needed.
///
///********************************************************************************************************************

+ (DKTextShape*)			textShapeWithAttributedString:(NSAttributedString*) str
{
	NSAssert( str != nil, @"string can't be nil");
	
	NSSize	bboxSize = [str size];
	bboxSize.width = MIN( 2000.0, bboxSize.width * 1.1 );
	
	DKTextShape*  te = [[self alloc] initWithRect:NSMakeRect( 0, 0, bboxSize.width, bboxSize.height ) style:[DKStyle defaultTextStyle]];
	
	[te setWrapsLines:NO];
	[te setAlignment:NSLeftTextAlignment];
	[te setText:str];
	[te sizeVerticallyToFitText];
	
	return [te autorelease];
}




#pragma mark -

///*********************************************************************************************************************
///
/// method:			setDefaultTextString:
/// scope:			public class method
/// overrides:
/// description:	set the initial text string for new text shape objects.
/// 
/// parameters:		<str> a string
/// result:			none
///
/// notes:			The default is usually "Double-click to edit this text"
///
///********************************************************************************************************************

+ (void)					setDefaultTextString:(NSString*) str
{
	[str retain];
	[sDefault_string release];
	sDefault_string = str;
}


///*********************************************************************************************************************
///
/// method:			defaultTextString:
/// scope:			public class method
/// overrides:
/// description:	get the initial text string for new text shape objects.
/// 
/// parameters:		none
/// result:			a string
///
/// notes:			The default is usually "Double-click to edit this text"
///
///********************************************************************************************************************

+ (NSString*)				defaultTextString
{
	return sDefault_string;
}



///*********************************************************************************************************************
///
/// method:			textAdornmentClass:
/// scope:			public class method
/// overrides:
/// description:	return the class of object to create as the shape's text adornment.
/// 
/// parameters:		none
/// result:			the object class
///
/// notes:			this provides an opportunity for subclasses to supply a different type of object, which must be
///					a DKTextAdornment, a subclass of it, or one that implements its API.
///
///********************************************************************************************************************

+ (Class)					textAdornmentClass
{
	return [DKTextAdornment class];
}


///*********************************************************************************************************************
///
/// method:			pastableTextTypes
/// scope:			public class method
/// overrides:
/// description:	return a list of types we can paste in priority order.
/// 
/// parameters:		none
/// result:			a list of types
///
/// notes:			Cocoa's -textPasteboardTypes isn't in an order that is useful to us
///
///********************************************************************************************************************

+ (NSArray*)				pastableTextTypes
{
	return [NSArray arrayWithObjects:NSRTFPboardType, NSRTFDPboardType, NSHTMLPboardType, NSStringPboardType, nil];
}


///*********************************************************************************************************************
///
/// method:			textOverflowIndicatorPath
/// scope:			public class method
/// overrides:
/// description:	return a path used for indicating unlaid text in object
/// 
/// parameters:		none
/// result:			a path
///
/// notes:			the path consists of a plus sign within a square with origin at 0,0 and sides 1,1
///
///********************************************************************************************************************

#define PLUS_SIGN_A		0.4
#define PLUS_SIGN_B		0.6

+ (NSBezierPath*)			textOverflowIndicatorPath
{
	static NSBezierPath* mtp = nil;
	
	if( mtp == nil )
	{
		mtp = [[NSBezierPath bezierPathWithRect:NSMakeRect( 0, 0, 1, 1 )] retain];
	
		[mtp moveToPoint:NSMakePoint( PLUS_SIGN_A, 0.1 )];
		[mtp lineToPoint:NSMakePoint( PLUS_SIGN_B, 0.1 )];
		[mtp lineToPoint:NSMakePoint( PLUS_SIGN_B, PLUS_SIGN_A )];
		[mtp lineToPoint:NSMakePoint( 0.9, PLUS_SIGN_A )];
		[mtp lineToPoint:NSMakePoint( 0.9, PLUS_SIGN_B )];
		[mtp lineToPoint:NSMakePoint( PLUS_SIGN_B, PLUS_SIGN_B )];
		[mtp lineToPoint:NSMakePoint( PLUS_SIGN_B, 0.9 )];
		[mtp lineToPoint:NSMakePoint( PLUS_SIGN_A, 0.9 )];
		[mtp lineToPoint:NSMakePoint( PLUS_SIGN_A, PLUS_SIGN_B )];
		[mtp lineToPoint:NSMakePoint( 0.1, PLUS_SIGN_B )];
		[mtp lineToPoint:NSMakePoint( 0.1, PLUS_SIGN_A )];
		[mtp lineToPoint:NSMakePoint( PLUS_SIGN_A, PLUS_SIGN_A )];
		[mtp lineToPoint:NSMakePoint( PLUS_SIGN_A, 0.1 )];
		[mtp closePath];
		[mtp setWindingRule:NSEvenOddWindingRule];
	}
	
	return mtp;
}


///*********************************************************************************************************************
///
/// method:			setShowsTextOverflowIndicator
/// scope:			public class method
/// overrides:
/// description:	set whether objects of this class should display an overflow symbol when text can't be fully laid
/// 
/// parameters:		<overflowShown> YES to dislay, NO otherwise
/// result:			none
///
/// notes:			setting is persistent
///
///********************************************************************************************************************

+ (void)					setShowsTextOverflowIndicator:(BOOL) overflowShown
{
	[[NSUserDefaults standardUserDefaults] setBool:overflowShown forKey:kDKTextOverflowIndicatorDefaultsKey];
}


///*********************************************************************************************************************
///
/// method:			showsTextOverflowIndicator
/// scope:			public class method
/// overrides:
/// description:	return whether objects of this class should display an overflow symbol when text can't be fully laid
/// 
/// parameters:		none 
/// result:			YES to dislay, NO otherwise
///
/// notes:			see also: -drawSelectedState
///
///********************************************************************************************************************

+ (BOOL)					showsTextOverflowIndicator
{
	return [[NSUserDefaults standardUserDefaults] boolForKey:kDKTextOverflowIndicatorDefaultsKey];
}


///*********************************************************************************************************************
///
/// method:			setAllowsInlineImages:
/// scope:			public class method
/// overrides:
/// description:	set whether text editing permits inline images to be pasted
/// 
/// parameters:		<allowed> YES to allow images, NO to disallow 
/// result:			none
///
/// notes:			this state is persistent and ends up as the parameter to [NSTextView setImportsGraphics:]
///
///********************************************************************************************************************

+ (void)					setAllowsInlineImages:(BOOL) allowed
{
	[[NSUserDefaults standardUserDefaults] setBool:allowed forKey:kDKTextAllowsInlineImagesDefaultsKey];
}


///*********************************************************************************************************************
///
/// method:			allowsInlineImages:
/// scope:			public class method
/// overrides:
/// description:	whether text editing permits inline images to be pasted
/// 
/// parameters:		none
/// result:			YES to allow images, NO to disallow
///
/// notes:			this state is persistent and ends up as the parameter to [NSTextView setImportsGraphics:]
///
///********************************************************************************************************************

+ (BOOL)					allowsInlineImages
{
	return [[NSUserDefaults standardUserDefaults] boolForKey:kDKTextAllowsInlineImagesDefaultsKey];
}

#pragma mark -
#pragma mark - the text

///*********************************************************************************************************************
///
/// method:			setText:
/// scope:			public instance method
/// overrides:
/// description:	set the text string for the text shape
/// 
/// parameters:		<newText> any sort of string - NSString, NSAttributedString, NSTextStorage, etc
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)					setText:(id) newText
{
	if(![self locked])
	{
		[mTextAdornment setLabel:newText];
		[self updateFontPanel];
	}
}


///*********************************************************************************************************************
///
/// method:			text
/// scope:			public instance method
/// overrides:
/// description:	get the text of the text shape
/// 
/// parameters:		none
/// result:			the object's text
///
/// notes:			the returned text has attributes applied wherever they come from - the style or local.
///
///********************************************************************************************************************

- (NSTextStorage*)			text
{
	return [mTextAdornment textToDraw:self];
}


///*********************************************************************************************************************
///
/// method:			string
/// scope:			public instance method
/// overrides:
/// description:	get the string of the text shape
/// 
/// parameters:		none
/// result:			the object's text string
///
/// notes:			this returns just the characters - no attributes
///
///********************************************************************************************************************

- (NSString*)				string
{
	return [[self text] string];
}


///*********************************************************************************************************************
///
/// method:			sizeVerticallyToFitText
/// scope:			public instance method
/// overrides:
/// description:	adjust the object's height to match the height of the current text
/// 
/// parameters:		none
/// result:			none
///
/// notes:			Honours the minimum and maximum sizes set
///
///********************************************************************************************************************

- (void)					sizeVerticallyToFitText
{
	if(![self locked])
		[self setSize:[self idealTextSize]];
}


#pragma mark -

///*********************************************************************************************************************
///
/// method:			pasteTextFromPasteboard:ignoreFormatting:
/// scope:			public instance method
/// overrides:
/// description:	set the object's text from the pasteboard, optionally ignoring its formatting
/// 
/// parameters:		<pb> a pasteboard
///					<fmt> YES to just paste the string and use the existing attributes, NO to update with the pasted
///					formatting, if any
/// result:			none
///
/// notes:			if the style is locked, even if fmt is NO it won't be updated.
///
///********************************************************************************************************************

- (void)					pasteTextFromPasteboard:(NSPasteboard*) pb ignoreFormatting:(BOOL) fmt
{
	NSAssert( pb != nil, @"pasteboard was nil");
	
	NSArray*	types = [[self class] pastableTextTypes];
	NSString*	pbtype = [pb availableTypeFromArray:types];
	
	if ( pbtype )
	{
		NSData* data = [pb dataForType:pbtype];
		
		NSAttributedString*	str;
		
		if ([pbtype isEqualToString:NSRTFPboardType])
			str = [[NSAttributedString alloc] initWithRTF:data documentAttributes:nil];
		else if ([pbtype isEqualToString:NSRTFDPboardType])
			str = [[NSAttributedString alloc] initWithRTFD:data documentAttributes:nil];
		else if ([pbtype isEqualToString:NSHTMLPboardType])
			str = [[NSAttributedString alloc] initWithHTML:data documentAttributes:nil];
		else if ([pbtype isEqualToString:NSStringPboardType])
			str = [[NSAttributedString alloc] initWithString:[pb stringForType:pbtype]];
		else
			str = nil;
			
		if ( fmt )
			[self setText:[str string]];
		else
		{
			// use the pasted formatting:
			
			[self setText:str];
		}
			
		[str release];
	}
}


///*********************************************************************************************************************
///
/// method:			canPasteText:
/// scope:			public instance method
/// overrides:
/// description:	test whether the pasteboard contains any text we can paste
/// 
/// parameters:		<pb> a pasteboard
/// result:			YES if there is text of any kind that we can paste, NO otherwise
///
/// notes:			
///
///********************************************************************************************************************

- (BOOL)					canPasteText:(NSPasteboard*) pb
{
	return ([pb availableTypeFromArray:[[self class] pastableTextTypes]] != nil && ![self locked]);
}


#pragma mark -
#pragma mark - text layout and drawing

///*********************************************************************************************************************
///
/// method:			minSize
/// scope:			public instance method
/// overrides:
/// description:	return the minimum size of the text layout area
/// 
/// parameters:		none 
/// result:			a size, the smallest width and height text can be laid out in
///
/// notes:			subclasses can specify something else
///
///********************************************************************************************************************

- (NSSize)					minSize
{
	return NSMakeSize( 10.0, 16.0 );
}


///*********************************************************************************************************************
///
/// method:			maxSize
/// scope:			public instance method
/// overrides:
/// description:	return the maximum size of the text layout area
/// 
/// parameters:		none 
/// result:			a size, the largest width and height of the text
///
/// notes:			subclasses can specify something else
///
///********************************************************************************************************************

- (NSSize)					maxSize
{
    NSRect br   = [self bounds];
    NSSize size;
    
	size.width		= MAX( 400.0, ( br.size.width  * 5));
    size.height		= (br.size.height * 10);
    return size;
}


///*********************************************************************************************************************
///
/// method:			idealTextSize
/// scope:			public instance method
/// overrides:
/// description:	return the ideal size of the text layout area
/// 
/// parameters:		none 
/// result:			a size, the ideal text size
///
/// notes:			returns the size needed to accommodate the text, honouring min and max and whether the shape has
///					already had its size set
///
///********************************************************************************************************************

- (NSSize)					idealTextSize
{
    NSTextStorage *contents = [self text];
    NSSize minsize = [self minSize];
    NSSize maxsize = [self maxSize];
    NSUInteger len = [contents length];
    
    if (len > 0)
	{
		NSLayoutManager *lm = sharedDrawingLayoutManager();
        NSTextContainer *tc = [[lm textContainers] objectAtIndex:0];
        NSSize requiredSize = [self size];
		
		if ( requiredSize.height < maxsize.height )
			requiredSize.height = maxsize.height;
        
        [tc setContainerSize:requiredSize];
        [contents addLayoutManager:lm];
		
		NSRange glyphRange = [lm glyphRangeForTextContainer:tc];
		NSRect br = [lm boundingRectForGlyphRange:glyphRange inTextContainer:tc];

        requiredSize = br.size;//[lm usedRectForTextContainer:tc].size;

        if (requiredSize.width < minsize.width)
            requiredSize.width = minsize.width;

        if (requiredSize.height < minsize.height)
            requiredSize.height = minsize.height;

        [contents removeLayoutManager:lm];
		
		requiredSize.width += 2.0;
        return requiredSize;
    }
	else
        return minsize;
}


#pragma mark -
#pragma mark - conversion to path/shape with text path

///*********************************************************************************************************************
///
/// method:			textPath
/// scope:			public instance method
/// overrides:
/// description:	return the current text as a path
/// 
/// parameters:		none
/// result:			the path contains the glyphs laid out exactly as the object displays them, with the same line
///					breaks, etc. The path is transformed to the object's current location and angle.
///
/// notes:			
///
///********************************************************************************************************************

- (NSBezierPath*)			textPath
{
	return [mTextAdornment textAsPathForObject:self];
}


///*********************************************************************************************************************
///
/// method:			textPathGlyphs
/// scope:			protected instance method
/// overrides:
/// description:	return the individual glyph paths in an array
/// 
/// parameters:		none
/// result:			an array containing all of the individual glyph paths (i.e. each item in the array is one letter).
///
/// notes:			
///
///********************************************************************************************************************

- (NSArray*)				textPathGlyphs
{
	return [self textPathGlyphsUsedSize:NULL];
}


///*********************************************************************************************************************
///
/// method:			textPathGlyphsUsedSize
/// scope:			protected instance method
/// overrides:
/// description:	return the individual glyph paths in an array and the size used
/// 
/// parameters:		<textSize> receives the resulting sixe occupied by the text
/// result:			an array containing all of the individual glyph paths (i.e. each item in the array is one letter).
///
/// notes:			
///
///********************************************************************************************************************

- (NSArray*)				textPathGlyphsUsedSize:(NSSize*) textSize
{
	return [mTextAdornment textPathsForObject:self usedSize:textSize];
}


///*********************************************************************************************************************
///
/// method:			makeShapeWithText
/// scope:			public instance method
/// overrides:
/// description:	high level method turns the text into a drawable shape having the text as its path
/// 
/// parameters:		none
/// result:			a new shape object.
///
/// notes:			this tries to maintain as much fidelity as it can in terms of the text's appearance - attributes
///					such as the colour and shadow are used to construct a style for the new object.
///
///********************************************************************************************************************

- (DKDrawableShape*)		makeShapeWithText
{
	// creates a shape object that uses the current text converted to a path as its path. The result can't be edited as text but
	// it can be scaled instead of word-wrapped.
	
	Class shapeClass = [DKDrawableObject classForConversionRequestFor:[DKDrawableShape class]];
	DKDrawableShape* ds = [shapeClass drawableShapeWithBezierPath:[self textPath] rotatedToAngle:[self angle]];
	
	[ds setStyle:[self styleWithTextAttributes]];
	
	// keep a note of the original text in the meta-data, in case anyone wants to know - allows
	// the text of a shape to be "read" by code if necessary (e.g. by a find)
			
	[ds setOriginalText:[self text]];

	return ds;
}


///*********************************************************************************************************************
///
/// method:			makeShapeGroupWithText
/// scope:			public instance method
/// overrides:
/// description:	high level method turns the text into a drawable shape group having each glyph as a subobject
/// 
/// parameters:		none
/// result:			a new shape group object.
///
/// notes:			creates a group object containing individual path objects each with one letter of the text, but
///					overall retaining the same spatial relationships as the original text in the shape. This allows you
///					to convert text to a graphic in a way that allows you to get at each individual letter, as opposed
///					to converting to a path and then breaking it apart, which goes too far in that subcurves
///					within letters become separated. May fail (returning nil) if there are fewer than 2 valid paths
///					submitted to make a group.
///
///********************************************************************************************************************

- (DKShapeGroup*)			makeShapeGroupWithText
{
	NSArray*	paths = [self textPathGlyphs];
	
	// must be at least two paths at this point or can't make a group
	
	if([paths count] < 2)
		return nil;
	
	Class groupClass = [DKDrawableObject classForConversionRequestFor:[DKShapeGroup class]];
	DKShapeGroup* group = [groupClass groupWithBezierPaths:paths objectType:kDKCreateGroupWithShapes style:[self styleWithTextAttributes]];
	
	// move the group to the right place so that it is in the same place in the drawing as this
	
	[group setLocation:[self location]];
	[group setAngle:[self angle]];
	
	// keep a note of the original text in the meta-data, in case anyone wants to know - allows
	// the text of a shape to be "read" by code if necessary (e.g. by a find)

	[group setOriginalText:[self text]];
	
	return group;
}


///*********************************************************************************************************************
///
/// method:			styleWithTextAttributes
/// scope:			protected instance method
/// overrides:
/// description:	creates a style that attempts to maintain fidelity of appearance based on the text's attributes
/// 
/// parameters:		none
/// result:			a new style object.
///
/// notes:			
///
///********************************************************************************************************************

- (DKStyle*)				styleWithTextAttributes
{
	if(![[self style] hasTextAttributes])
		return [[self textAdornment] styleFromTextAttributes];
	else
	{
		if ([self style] == nil )
			return [DKStyle defaultStyle];
		else
			return [[self style] drawingStyleFromTextAttributes];
	}
}


///*********************************************************************************************************************
///
/// method:			syntheticStyle
/// scope:			public instance method
/// overrides:
/// description:	creates a style that is the current style + any text attributes
/// 
/// parameters:		none
/// result:			a new style object
///
/// notes:			a style which is the current style if it has text attributes, otherwise the current style with added text
///					attributes. When cutting or copying the object's style, this is what should be used.
///
///********************************************************************************************************************

- (DKStyle*)				syntheticStyle
{
	
	DKStyle* currentStyle = [self style];
	
	if([currentStyle hasTextAttributes])
		return currentStyle;
	else
	{
		currentStyle = [currentStyle mutableCopy];
		NSDictionary* ta = [[self textAdornment] textAttributes];
		
		[currentStyle setTextAttributes:ta];
		
		return [currentStyle autorelease];
	}
}


#pragma mark -
#pragma mark - basic text attributes


- (NSDictionary*)			textAttributes
{
	return [[self textAdornment] textAttributes];
}


- (void)					updateFontPanel
{
	[[NSFontManager sharedFontManager] setSelectedFont:[self font] isMultiple:![[self textAdornment] attributeIsHomogeneous:NSFontAttributeName]];
	[[NSFontManager sharedFontManager] setSelectedAttributes:[self textAttributes] isMultiple:![[self textAdornment] isHomogeneous]];
}


///*********************************************************************************************************************
///
/// method:			setFont:
/// scope:			public instance method
/// overrides:
/// description:	sets the text's font, if permitted
/// 
/// parameters:		<font> a new font
/// result:			none
///
/// notes:			updates the style if using it and it's not locked
///
///********************************************************************************************************************

- (void)					setFont:(NSFont*) font
{
	if ( ![self locked])
	{
		[mTextAdornment setFont:font];
		[self updateFontPanel];
	}
}


///*********************************************************************************************************************
///
/// method:			font
/// scope:			public instance method
/// overrides:
/// description:	gets the text's font
/// 
/// parameters:		none
/// result:			the current font
///
/// notes:			
///
///********************************************************************************************************************

- (NSFont*)					font
{
	return [mTextAdornment font];
}


///*********************************************************************************************************************
///
/// method:			setFontSize:
/// scope:			public instance method
/// overrides:
/// description:	sets the text's font size, if permitted
/// 
/// parameters:		<size> the point size of the font
/// result:			none
///
/// notes:			updates the style if using it and it's not locked. Currently does nothing if using local attributes -
///					use setFont: instead.
///
///********************************************************************************************************************

- (void)					setFontSize:(CGFloat) size
{
	if( ![self locked])
	{
		[mTextAdornment setFontSize:size];
		[self updateFontPanel];
	}
}


///*********************************************************************************************************************
///
/// method:			fontSize
/// scope:			public instance method
/// overrides:
/// description:	gets the text's font size
/// 
/// parameters:		none
/// result:			the size of the text's current font
///
/// notes:			
///
///********************************************************************************************************************

- (CGFloat)					fontSize
{
	return [mTextAdornment fontSize];
}


- (void)					setTextColour:(NSColor*) colour
{
	if ( ![self locked])
	{
		[mTextAdornment setColour:colour];
		[self updateFontPanel];
	}
}


- (NSColor*)				textColour
{
	return [mTextAdornment colour];
}


- (void)					scaleTextBy:(CGFloat) factor
{
	// permanently adjusts the text's font size by multiplying it by <factor>. A value of 1.0 has no effect.
	
	if( ![self locked])
		[mTextAdornment scaleTextBy:factor];
}


#pragma mark -
- (void)					setVerticalAlignment:(DKVerticalTextAlignment) align
{
	if( ![self locked])
		[mTextAdornment setVerticalAlignment:align];
}


- (DKVerticalTextAlignment)	verticalAlignment
{
	return [mTextAdornment verticalAlignment];
}


- (void)					setVerticalAlignmentProportion:(CGFloat) prop
{
	if( ![self locked])
		[mTextAdornment setVerticalAlignmentProportion:prop];
}


- (CGFloat)					verticalAlignmentProportion
{
	return [mTextAdornment verticalAlignmentProportion];
}


- (void)					setParagraphStyle:(NSParagraphStyle*) ps
{
	if ( ![self locked])
		[mTextAdornment setParagraphStyle:ps];
}


- (NSParagraphStyle*)		paragraphStyle
{
	return [mTextAdornment paragraphStyle];
}


- (void)					setAlignment:(NSTextAlignment) align
{
	if ( ![self locked])
	{
		[mTextAdornment setAlignment:align];
		[[self undoManager] setActionName:NSLocalizedString(@"Text Alignment", @"undo string for text align")];
	}
}


- (NSTextAlignment)			alignment
{
	return [mTextAdornment alignment];
}


- (void)					setLayoutMode:(DKTextLayoutMode) mode
{
	if( ![self locked])
		[mTextAdornment setLayoutMode:mode];
}


- (DKTextLayoutMode)		layoutMode
{
	return [mTextAdornment layoutMode];
}


- (void)					setWrapsLines:(BOOL) wraps
{
	if(![self locked])
		[mTextAdornment setWrapsLines:wraps];
}


- (BOOL)					wrapsLines
{
	return [mTextAdornment wrapsLines];
}






- (void)					mutateStyle
{
	// when the user makes a direct change to the text attributes, if the style is a library style and has text attributes, it is mutated into
	// an ad-hoc style without text attributes. This prevents a change to the style (or merge) from altering the user's text attributes. It also
	// prevents the objects being changed en-masse by a style edit - such changes require that the user hasn't changed the text attributes.
	
	if([[self style] hasTextAttributes] && !mIsSettingStyle)
	{
		DKStyle* newAdHocStyle = [[self style] mutableCopy];
		[newAdHocStyle removeTextAttributes];
		
		NSString*	newname = [[self style] name];
		if( newname )
			[newAdHocStyle setName:[NSString stringWithFormat:@"%@*", newname]];
		
		[self setStyle:newAdHocStyle];
		[newAdHocStyle release];
		
		//NSLog(@"text shape mutated style: %@", self );
	}
}


#pragma mark -
#pragma mark - editing the text
- (void)					startEditingInView:(DKDrawingView*) view
{
	if ( m_editorRef == nil )
	{
		LogEvent_(kReactiveEvent, @"starting edit of text shape");
	
		NSSize maxsize = [self maxSize];
		NSSize minsize = [self minSize];
		
		NSRect	br = [self logicalBounds];
		CGFloat	offset = [[self textAdornment] verticalTextOffsetForObject:self];
		
		br.origin.y += offset;
		
		m_editorRef = [view editText:[[self textAdornment] textForEditing] inRect:br delegate:self];
		
		[[m_editorRef textContainer] setWidthTracksTextView:NO];
		[m_editorRef setImportsGraphics:[[self class] allowsInlineImages]];
		
		if ( NSWidth(br) > minsize.width + 1.0)
		{
			[[m_editorRef textContainer] setContainerSize:NSMakeSize( NSWidth(br), maxsize.height)];
			[m_editorRef setHorizontallyResizable:NO];
		}
		else
		{
			[[m_editorRef textContainer] setContainerSize:maxsize];
			[m_editorRef setHorizontallyResizable:YES];
		}
		
		[m_editorRef setMinSize:minsize];
		[m_editorRef setMaxSize:maxsize];
		[[m_editorRef textContainer] setHeightTracksTextView:NO];
		[m_editorRef setVerticallyResizable:YES];
		[m_editorRef setTypingAttributes:[self textAttributes]];
	}
}


- (void)					endEditing
{
	if ( m_editorRef )
	{
		LogEvent_(kReactiveEvent, @"finishing edit of text in shape");
		
		[self setText:[m_editorRef textStorage]];

		DKDrawingView* parent = (DKDrawingView*)[m_editorRef superview];
		[parent endTextEditing];
		[self notifyVisualChange];
		m_editorRef = nil;
	}
}


- (BOOL)					isEditing
{
	// returns YES if editing currently in progress - valid during drawing only
	
	return( m_editorRef && ([m_editorRef superview] == [[self drawing] currentView]) && [[NSGraphicsContext currentContext] isDrawingToScreen]);
}


- (DKTextAdornment*)		textAdornment
{
	return mTextAdornment;
}


#pragma mark -
#pragma mark - user actions
- (IBAction)				changeFont:(id) sender
{
	// Font Panel changed by user - change the whole of the text to the panel's style. Note - if text is currently
	// highlighted, do nothing, as the changes are handled by another route.
	
	if ( ![self locked])
	{
		[[self textAdornment] changeFont:sender];
		[[self undoManager] setActionName:NSLocalizedString(@"Font Change", @"undo action string for Font Change")];
		[self updateFontPanel];
	}
}


- (IBAction)				changeFontSize:(id) sender
{
	if ( ![self locked])
		[self setFontSize:[sender doubleValue]];
}


- (IBAction)				changeAttributes:(id) sender
{
	if ( ![self locked])
	{
		[[self textAdornment] changeAttributes:sender];
		[[self undoManager] setActionName:NSLocalizedString(@"Text Attributes", @"undo action string for Text Attributes")];
		[self updateFontPanel];
	}
}


- (IBAction)				editText:(id) sender
{
	#pragma unused(sender)
	
	// start the text editing process. This can also be done by a double-click. The view used must be the first responder which sent us this
	// command in the first place.
	
	if ( ![self locked])
	{
		NSResponder*	dv;
		NSWindow*		w = [NSApp keyWindow];
		
		dv = [w firstResponder];
		
		if ([dv isKindOfClass:[DKDrawingView class]])
			[self startEditingInView:(DKDrawingView*)dv];
	}
}


- (IBAction)				changeLayoutMode:(id) sender
{
	// sender's tag is interpreted as the layout mode
	
	NSInteger tag = [sender tag];
	[self setLayoutMode:tag];
}


#pragma mark -
- (IBAction)				alignLeft:(id) sender
{
	#pragma unused(sender)
	
	// apply the align left attribute to the text's paragraph style
	
	[self setAlignment:NSLeftTextAlignment];
}


- (IBAction)				alignRight:(id) sender
{
	#pragma unused(sender)
	
	[self setAlignment:NSRightTextAlignment];
}


- (IBAction)				alignCenter:(id) sender
{
	#pragma unused(sender)
	
	[self setAlignment:NSCenterTextAlignment];
}


- (IBAction)				alignJustified:(id) sender
{
	#pragma unused(sender)
	
	[self setAlignment:NSJustifiedTextAlignment];
}


- (IBAction)				underline:(id) sender
{
	#pragma unused(sender)
	
	if ( ![self locked])
	{
		NSInteger unders = [mTextAdornment underlines];
		
		if( unders == 0 )
			unders = 1;
		else
			unders = 0;
		
		[mTextAdornment setUnderlines:unders];
		[self mutateStyle];
	}
}


- (IBAction)				loosenKerning:(id) sender
{
#pragma unused(sender)
	
	if ( ![self locked])
		[mTextAdornment loosenKerning];
}



- (IBAction)				tightenKerning:(id) sender
{
#pragma unused(sender)
	
	if ( ![self locked])
		[mTextAdornment tightenKerning];
}



- (IBAction)				turnOffKerning:(id)sender
{
#pragma unused(sender)
	
	if ( ![self locked])
		[mTextAdornment turnOffKerning];
}


- (IBAction)				useStandardKerning:(id) sender;
{
#pragma unused(sender)
	
	if ( ![self locked])
		[mTextAdornment useStandardKerning];
}



- (IBAction)				lowerBaseline:(id) sender
{
#pragma unused(sender)
	
	if ( ![self locked])
		[mTextAdornment lowerBaseline];
}



- (IBAction)				raiseBaseline:(id) sender
{
#pragma unused(sender)
	
	if ( ![self locked])
		[mTextAdornment raiseBaseline];
}


- (IBAction)				superscript:(id) sender
{
#pragma unused(sender)
	
	if ( ![self locked])
		[mTextAdornment superscript];
}



- (IBAction)				subscript:(id) sender
{
#pragma unused(sender)
	
	if ( ![self locked])
		[mTextAdornment subscript];
}



- (IBAction)				unscript:(id) sender
{
#pragma unused(sender)
	
	if ( ![self locked])
		[mTextAdornment unscript];
}







#pragma mark -
- (IBAction)				fitToText:(id) sender
{
	#pragma unused(sender)
	
	if ( ![self locked] )
	{
		[self sizeVerticallyToFitText];
		[[self undoManager] setActionName:NSLocalizedString(@"Fit To Text", @"undo string for fit to text")];
	}
}


- (IBAction)				verticalAlign:(id) sender
{
	// sender's tag is the alignment desired
	
	if ( ![self locked] )
	{
		[self setVerticalAlignment:(DKVerticalTextAlignment)[sender tag]];
		[[self undoManager] setActionName:NSLocalizedString(@"Vertical Alignment", @"undo string for vertical align")];
	}
}


- (IBAction)				convertToShape:(id) sender
{
	#pragma unused(sender)
	
	// converts the text shape to a plain shape using the text as its path
	
	DKObjectDrawingLayer*	layer = (DKObjectDrawingLayer*)[self layer];
	NSInteger				myIndex = [layer indexOfObject:self];
	
	DKDrawableShape*		so = [self makeShapeWithText];
	
	if( so )
	{
		[layer recordSelectionForUndo];
		[layer addObject:so atIndex:myIndex];
		[layer replaceSelectionWithObject:so];
		[self retain];
		[layer removeObject:self];
		[layer commitSelectionUndoWithActionName:NSLocalizedString(@"Convert To Shape", @"undo string for convert text to shape")];
		[self release];
	}
	else
		NSBeep();
}


- (IBAction)				convertToShapeGroup:(id) sender
{
	#pragma unused(sender)
	
	DKObjectDrawingLayer*	layer = (DKObjectDrawingLayer*)[self layer];
	NSInteger				myIndex = [layer indexOfObject:self];
	
	DKDrawableShape*		so = [self makeShapeGroupWithText];
	
	if( so )
	{
		[layer recordSelectionForUndo];
		[layer addObject:so atIndex:myIndex];
		[layer replaceSelectionWithObject:so];
		[self retain];
		[layer removeObject:self];
		[layer commitSelectionUndoWithActionName:NSLocalizedString(@"Convert To Shape Group", @"undo string for convert text to group")];
		[self release];
	}
	else
		NSBeep();
}


- (IBAction)				convertToTextPath:(id) sender
{
#pragma unused(sender)
	// replaces self with a DKTextPath object having the same text, a path that is a single segment curve arranged in a straight line
	// across the shape and vertically centred. The new object has the text on the path and the same style. While this can result in
	// a substantial change in appearance of the object, it is a useful way to turn block labels into path based ones.
	
	DKObjectDrawingLayer*	layer = (DKObjectDrawingLayer*)[self layer];
	NSInteger				myIndex = [layer indexOfObject:self];
	
	DKTextPath*	so = [self makeTextPathObject];
	
	if ( so )
	{
		[layer recordSelectionForUndo];
		[layer addObject:so atIndex:myIndex];
		[layer replaceSelectionWithObject:so];
		[self retain];
		[layer removeObject:self];
		[layer commitSelectionUndoWithActionName:NSLocalizedString(@"Convert To Text Path", @"undo string for convert to text path")];
		[self release];
	}
	else
		NSBeep();
}


#pragma mark -
- (IBAction)				paste:(id) sender
{
	#pragma unused(sender)
	
	if ( ![self locked] && [self canPasteText:[NSPasteboard generalPasteboard]])
	{
		[self pasteTextFromPasteboard:[NSPasteboard generalPasteboard] ignoreFormatting:NO];
		[[self undoManager] setActionName:NSLocalizedString(@"Paste Text", @"undo string for paste text into text shape")];
	}
}


- (IBAction)				capitalize:(id) sender
{
	if( ![self locked])
	{
		[[self textAdornment] setCapitalization:(DKTextCapitalization)[sender tag]];
		[[self undoManager] setActionName:NSLocalizedString(@"Change Case", @"undo string for capitalization")];
	}
}


- (IBAction)				takeTextAlignmentFromSender:(id) sender
{
	// this method is designed to act as an action for a segmented button. The tag of the selected segment is interpreted as an alignment setting. The whole
	// segmented control should be connected to this as its action.
	
	if(![self locked])
	{
		NSInteger clickedSegment = [sender selectedSegment];
		NSInteger clickedSegmentTag = [[sender cell] tagForSegment:clickedSegment];
	
		[self setAlignment:clickedSegmentTag];
	}
}


- (IBAction)				takeTextVerticalAlignmentFromSender:(id) sender
{
	// this method is designed to act as an action for a segmented button. The tag of the selected segment is interpreted as a vertical alignment setting. The whole
	// segmented control should be connected to this as its action.
	
	if(![self locked])
	{
		NSInteger clickedSegment = [sender selectedSegment];
		NSInteger clickedSegmentTag = [[sender cell] tagForSegment:clickedSegment];
		
		[self setVerticalAlignment:(DKVerticalTextAlignment)clickedSegmentTag];
		[[self undoManager] setActionName:NSLocalizedString(@"Vertical Alignment", @"undo string for vertical align")];
	}
}


#pragma mark -


- (DKTextAdornment*)	makeTextAdornment
{
	
	DKTextAdornment* adorn = [[[[self class] textAdornmentClass] alloc] init];
	
	// set initial attributes from attached style, if it has any.
	
	if([[self style] hasTextAttributes])
		[adorn setTextAttributes:[[self style] textAttributes]];
	
	return [adorn autorelease];
	
}


- (void)			setTextAdornment:(DKTextAdornment*) adornment
{
	if( adornment != mTextAdornment )
	{
		if( mTextAdornment )
		{
			[[NSNotificationCenter defaultCenter] removeObserver:self name:nil object:mTextAdornment];
			
			[mTextAdornment tearDownKVOForObserver:self];
			[mTextAdornment release];
			mTextAdornment = nil;
		}
		
		mTextAdornment = [adornment retain];
		
		[mTextAdornment setUpKVOForObserver:self];
		
		if( mTextAdornment )
			[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(textWillChange:) name:kDKRasterizerPropertyWillChange object:mTextAdornment];
	}
}


- (DKTextPath*)				makeTextPathObject
{
	// create a text path object having the same style and text, but with different path and probably different layout.
	 
	NSBezierPath* path = [NSBezierPath bezierPath];
	NSRect br = [self logicalBounds];
	[path moveToPoint:NSMakePoint(NSMinX(br), NSMidY(br))];
	[path curveToPoint:NSMakePoint(NSMaxX(br), NSMidY(br))
		 controlPoint1:NSMakePoint(NSMinX(br) + (NSMaxX(br) - NSMinX(br)) * 0.25, NSMidY(br))
		 controlPoint2:NSMakePoint(NSMinX( br) + (NSMaxX(br) - NSMinX(br)) * 0.75, NSMidY(br))];
	
	Class textPathClass = [DKDrawableObject classForConversionRequestFor:[DKTextPath class]];
	DKTextPath* textPath = [textPathClass textPathWithString:@"" onPath:path];
	
	BOOL ghosted = [self isGhosted];
	[self setGhosted:NO];
	
	[textPath setStyle:[self style]];

	DKTextAdornment* ta = [[self textAdornment] copy];
	[textPath setTextAdornment:ta];
	[ta release];
	
	[self setGhosted:ghosted];
	
	[textPath setLayoutMode:kDKTextLayoutAlongPath];
	[textPath setUserInfo:[self userInfo]];

	return textPath;
}


#pragma mark -
#pragma mark As a DKDrawableShape

- (DKDrawablePath*)			makePath
{
	// overrides DKDrawableShape to make a path of the actual text
	
	Class pathClass = [DKDrawableObject classForConversionRequestFor:[DKDrawablePath class]];
	DKDrawablePath* dp = [pathClass drawablePathWithBezierPath:[self textPath]];
	
	// convert the text style into a path style
	
	[dp setStyle:[self styleWithTextAttributes]];
	[dp setUserInfo:[self userInfo]];

	// keep a note of the original text in the meta-data, in case anyone wants to know - allows
	// the text of a shape to be "read" by code if necessary (e.g. by a find)

	[dp setOriginalText:[self text]];

	return dp;
}

#define SCALE_TEXT_WHEN_UNGROUPING		1

#if SCALE_TEXT_WHEN_UNGROUPING
- (void)				group:(DKShapeGroup*) aGroup willUngroupObjectWithTransform:(NSAffineTransform*) aTransform
{
	NSSize size = [self size];
	
	[super group:aGroup willUngroupObjectWithTransform:aTransform];

	CGFloat factor = MAX([self size].width/size.width, [self size].height/size.height);
	[self scaleTextBy:factor];
}
#endif


#pragma mark -
#pragma mark As a DKDrawableObject


- (id)					initWithStyle:(DKStyle*) aStyle
{
	self = [super initWithStyle:aStyle];
	if (self != nil)
	{
		[self setTextAdornment:[self makeTextAdornment]];
		[self setText:[[self class] defaultTextString]];
		
#ifdef DRAWKIT_DEPRECATED
		m_textRect = NSZeroRect;
		m_ignoreStyleAttributes = YES; //[DKTextShape defaultIgnoresStyleAttributes];
#endif	
	}
	if (self != nil)
	{
		[self setPath:[NSBezierPath bezierPathWithRect:[DKDrawableShape unitRectAtOrigin]]];
		[self setVerticalAlignment:kDKTextShapeVerticalAlignmentTop];
	}
	return self;
}

- (NSRect)				bounds
{
	NSRect br = [super bounds];
	
	if ( m_editorRef )
		br = NSUnionRect( br, NSInsetRect([m_editorRef frame], -2.0, -2.0 ));
	
	return br;
}


- (NSSize)				extraSpaceNeeded
{
	NSSize extra = [super extraSpaceNeeded];
	NSSize taExtra = [mTextAdornment extraSpaceNeeded];
	
	extra.width += taExtra.width;
	extra.height += taExtra.height;
	
	return extra;
}


- (NSInteger)					hitPart:(NSPoint) pt
{
	NSInteger part = [super hitPart:pt];
	
	if( part == kDKDrawingNoPart )
	{
		// check if contained by the path (regardless of style fill, etc) - this is
		// done to make text objects generally easier to hit since they frequently may
		// have sparse pixels, or none at all.
		
		if ([[self renderingPath] containsPoint:pt])
			part = kDKDrawingEntireObjectPart;
	}
	
	return part;
}



- (void)				drawContent
{
	if( ![[self style] isEmpty])
		[super drawContent];
	
	if( ![self isEditing])
	{
		// for hit-testing, standard text layout is slow and doesn't work well with the scaling mechanism used. Thus we use
		// greeked text for hit testing which solves both problems nicely.
		
		if([self isBeingHitTested])
		{
			DKGreeking saveGreek = [[self textAdornment] greeking];
			[[self textAdornment] setGreeking:kDKGreekingByLineRectangle];
			[mTextAdornment render:self];
			[[self textAdornment] setGreeking:saveGreek];
		}
		else
			[mTextAdornment render:self];
	}
}


- (void)				drawSelectedState
{
	// draw a "more text" indicator if the current text can't be fully laid out in the box
	
	if(![[self textAdornment] allTextWasFitted] && [[self class] showsTextOverflowIndicator])
	{
		DKKnob* knob = [[self layer] knobs];
		NSSize knobSize = [knob controlKnobSize];
		
		knobSize.width *= 1.6;
		knobSize.height *= 1.6;
		
		NSBezierPath* np = [[self class] textOverflowIndicatorPath];
		np = [self path:np withFinalSize:knobSize offsetBy:NSMakePoint( -knobSize.width, -knobSize.height ) fromPartcode:kDKDrawableShapeBottomRightHandle];
		
		if([self locked])
			[[NSColor lightGrayColor] set];
		else
			[[[self layer] selectionColour] set];
		[np fill];
	}
	
	[super drawSelectedState];
}



- (void)				mouseDoubleClickedAtPoint:(NSPoint) mp inPart:(NSInteger) partcode event:(NSEvent*) evt
{
	[super mouseDoubleClickedAtPoint:mp inPart:partcode event:evt];
	
	if ( ![self locked])
		[self startEditingInView:(DKDrawingView*)[[self layer] currentView]];
}


- (void)				objectDidBecomeSelected
{
	[super objectDidBecomeSelected];
	[self updateFontPanel];
}


- (void)					objectIsNoLongerSelected
{
	[super objectIsNoLongerSelected];
	[self endEditing];
}

#define INCLUDE_ALIGNMENT_COMMANDS		0

- (BOOL)					populateContextualMenu:(NSMenu*) theMenu
{
	// if the object supports any contextual menu commands, it should add them to the menu and return YES. If subclassing,
	// you should call the inherited method first so that the menu is the union of all the ancestor's added methods.
	
	NSMenuItem* item;

	[[theMenu addItemWithTitle:NSLocalizedString(@"Edit Text", @"menu item for edit text") action:@selector( editText: ) keyEquivalent:@""] setTarget:self];
	[[theMenu addItemWithTitle:NSLocalizedString(@"Fit To Text", @"menu item for fit to text") action:@selector(fitToText:) keyEquivalent:@""] setTarget:self];	
	[[theMenu addItemWithTitle:NSLocalizedString(@"Paste", @"menu item for Paste") action:@selector(paste:) keyEquivalent:@""] setTarget:self];	
	
	NSMenu* fm = [[[NSFontManager sharedFontManager] fontMenu:YES] copy];
	[[theMenu addItemWithTitle:NSLocalizedString(@"Font", @"menu item for Font") action:nil keyEquivalent:@""] setSubmenu:fm];
	[fm release];
	
	[theMenu addItem:[NSMenuItem separatorItem]];

	// the font menu may contain all the alignment commands - in which case we can leave these out
	
#if INCLUDE_ALIGNMENT_COMMANDS
	[[theMenu addItemWithTitle:NSLocalizedString(@"Align Left", @"menu item for align left") action:@selector(alignLeft:) keyEquivalent:@""] setTarget:self];
	[[theMenu addItemWithTitle:NSLocalizedString(@"Centre", @"menu item for centre") action:@selector(alignCenter:) keyEquivalent:@""] setTarget:self];
	[[theMenu addItemWithTitle:NSLocalizedString(@"Justify", @"menu item for justify") action:@selector(alignJustified:) keyEquivalent:@""] setTarget:self];
	[[theMenu addItemWithTitle:NSLocalizedString(@"Align Right", @"menu item for align right") action:@selector(alignRight:) keyEquivalent:@""] setTarget:self];
	
	[theMenu addItem:[NSMenuItem separatorItem]];
	NSMenu*	vert = [[NSMenu alloc] initWithTitle:NSLocalizedString(@"Vertical Alignment", @"menu item for vertical alignment")];
	
	
	item = [vert addItemWithTitle:NSLocalizedString(@"Top", @"menu item for top (VA)") action:@selector(verticalAlign:) keyEquivalent:@""];
	
	[item setTarget:self];
	[item setTag:kDKTextShapeVerticalAlignmentTop];
	
	item = [vert addItemWithTitle:NSLocalizedString(@"Middle", @"menu item for middle (VA)") action:@selector(verticalAlign:) keyEquivalent:@""];
	[item setTarget:self];
	[item setTag:kDKTextShapeVerticalAlignmentCentre];
	
	item = [vert addItemWithTitle:NSLocalizedString(@"Bottom", @"menu item for bottom (VA)") action:@selector(verticalAlign:) keyEquivalent:@""];
	[item setTarget:self];
	[item setTag:kDKTextShapeVerticalAlignmentBottom];
	
	[[theMenu addItemWithTitle:NSLocalizedString(@"Vertical Alignment", @"menu item for vertical alignment") action:nil keyEquivalent:@""] setSubmenu:vert];
	[vert release];	
#endif
	
	NSMenu* convert = [[NSMenu alloc] initWithTitle:NSLocalizedString(@"Convert To", @"menu item for convert to submenu")];
	
	[[convert addItemWithTitle:NSLocalizedString(@"Shape", @"menu item for basic shape") action:@selector(convertToShape:) keyEquivalent:@""] setTarget:self];
	[[convert addItemWithTitle:NSLocalizedString(@"Shape Group", @"menu item for convert to shape group") action:@selector(convertToShapeGroup:) keyEquivalent:@""] setTarget:self];
	[[convert addItemWithTitle:NSLocalizedString(@"Text On Path", @"menu item for convert to text path") action:@selector(convertToTextPath:) keyEquivalent:@""] setTarget:self];
	item = [theMenu addItemWithTitle:NSLocalizedString(@"Convert To", @"menu item for convert submenu") action:nil keyEquivalent:@""];
	
	[item setSubmenu:convert];
	[convert release];	
	[item setTag:kDKConvertToSubmenuTag];
	
	[super populateContextualMenu:theMenu];
	return YES;
}


- (void)					setStyle:(DKStyle*) aStyle
{
	if ( aStyle != [self style])
	{
		[super setStyle:aStyle];
		
		// set initial text attributes from style if it has them
		
		if([[self style] hasTextAttributes])
		{
			// this flag prevents style mutation
			
			mIsSettingStyle = YES;
			[mTextAdornment setTextAttributes:[[self style] textAttributes]];
			mIsSettingStyle = NO;
		}
		
		[self notifyVisualChange];
	}
}


- (void)					creationTool:(id) tool willEndCreationAtPoint:(NSPoint) p
{
#pragma unused(tool, p)
	
	NSSize size = [self size];
	
	if( size.height <= 0 || size.width <= 0 )
	{
		NSSize offset = [self offset];
		[self setDragAnchorToPart:kDKDrawableShapeObjectCentre];
		[self setSize:NSMakeSize( 250, [self fontSize] + 6 )];
		[self setOffset:offset];
		
		//[self setText:@""];
		[self editText:self];
	}
}


///*********************************************************************************************************************
///
/// method:			copyDrawingStyle:
/// scope:			public action method
/// overrides:
/// description:	copies the object's style to the general pasteboard
/// 
/// parameters:		<sender> the action's sender
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (IBAction)		copyDrawingStyle:(id) sender
{
#pragma unused(sender)
	[[self syntheticStyle] copyToPasteboard:[NSPasteboard generalPasteboard]];
}


///*********************************************************************************************************************
///
/// method:			writeSupplementaryDataToPasteboard:
/// scope:			public instance method
/// overrides:
/// description:	write additional data to the pasteboard specific to the object
/// 
/// parameters:		<pb> the pasteboard to write to
/// result:			none
///
/// notes:			Text objects add the text itself to the pasteboard
///
///********************************************************************************************************************

- (void)				writeSupplementaryDataToPasteboard:(NSPasteboard*) pb
{
	if([pb addTypes:[NSArray arrayWithObjects:NSRTFPboardType, NSStringPboardType, nil] owner:self])
	{
		NSRange range = NSMakeRange( 0, [[self text] length]);
		NSData* rtfData = [[self text] RTFFromRange:range documentAttributes:nil];
		
		[pb setData:rtfData forType:NSRTFPboardType];
		[pb setString:[self string] forType:NSStringPboardType];
	}
}


///*********************************************************************************************************************
///
/// method:			styleDidChange
/// scope:			private notification method
/// overrides:
/// description:	called just after the attached style has changed
/// 
/// parameters:		none
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)			styleDidChange:(NSNotification*) note
{
	if([[self style] hasTextAttributes])
	{
		mIsSettingStyle = YES;
		[mTextAdornment setTextAttributes:[[self style] textAttributes]];
		mIsSettingStyle = NO;
	}
	
	[super styleDidChange:note];
}




#pragma mark -
#pragma mark As an NSObject
- (void)					dealloc
{
	[self endEditing];
	
#ifdef DRAWKIT_DEPRECATED
	[m_text release];
#endif
	[self setTextAdornment:nil];
	[super dealloc];
}


- (id)						init
{
	return [self initWithStyle:[DKStyle defaultTextStyle]];
}


#pragma mark -
#pragma mark As part of NSDraggingDestination protocol

- (BOOL)				performDragOperation:(id <NSDraggingInfo>) sender
{
	// if there's text on the pasteboard, set it as the object's text
	
	NSPasteboard* pb = [sender draggingPasteboard];
	
	if([self canPasteText:pb])
	{
		[self pasteTextFromPasteboard:pb ignoreFormatting:NO];
		[[self undoManager] setActionName:NSLocalizedString(@"Drop Text", @"undo string for drop text")];
		return YES;
	}
	
	NSColor* pc = [NSColor colorFromPasteboard:pb];
	
	if( pc )
	{
		[self setTextColour:pc];
		[[self undoManager] setActionName:NSLocalizedString(@"Drop Colour", @"unso string for drop colour")];
		return YES;
	}
	
	return [super performDragOperation:sender];
}




#pragma mark -
#pragma mark As part of NSCoding Protocol
- (void)					encodeWithCoder:(NSCoder*) coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	[super encodeWithCoder:coder];
	
	[coder encodeObject:mTextAdornment forKey:@"DKTextShape_textAdornment"];
}


- (id)						initWithCoder:(NSCoder*) coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	self = [super initWithCoder:coder];
	if (self != nil)
	{
		BOOL isOldType = NO;
		
		[self setTextAdornment:[coder decodeObjectForKey:@"DKTextShape_textAdornment"]];
		
		isOldType = ( mTextAdornment == nil );
		
		if( isOldType )
		{
			[self setTextAdornment:[self makeTextAdornment]];
			[self setText:[coder decodeObjectForKey:@"text"]];
			//[self setTextRect:[coder decodeRectForKey:@"textRect"]];
			[self setVerticalAlignment:[coder decodeIntegerForKey:@"vAlign"]];
			[self setVerticalAlignmentProportion:[coder decodeDoubleForKey:@"DKTextShape_verticalAlignmentProportion"]];
		}
	}
	
	return self;
}


#pragma mark -
#pragma mark As part of NSCopying Protocol
- (id)						copyWithZone:(NSZone*) zone
{
	DKTextShape* copy = [super copyWithZone:zone];
	
	DKTextAdornment* ta = [[self textAdornment] copyWithZone:zone];
	[copy setTextAdornment:ta];
	[ta release];
	
	return copy;
}


#pragma mark -
#pragma mark As part of NSMenuValidation Protocol


- (BOOL)				validateMenuItem:(NSMenuItem*) item
{
	SEL	action = [item action];
	
	if(	action == @selector( changeFont: )	||
		action == @selector( changeFontSize: )	||
		action == @selector( changeAttributes: ) ||
		action == @selector( loosenKerning: ) ||
		action == @selector( tightenKerning: ) ||
		action == @selector( useStandardKerning: ) ||
		action == @selector( turnOffKerning: ) ||
		action == @selector( raiseBaseline: ) ||
		action == @selector( lowerBaseline: ) ||
		action == @selector( unscript: ) ||
		action == @selector( superscript: ) ||
		action == @selector( subscript: )	||
		action == @selector( fitToText: )	||
		action == @selector( convertToShape: ) ||
		action == @selector( convertToTextPath: ) ||
		action == @selector( editText: ))
		return ![self locked];
	
	if( action == @selector( convertToShapeGroup: ))
	{
		return ![self locked] && [[self textPathGlyphs] count] > 1;
	}


	// set checkmarks against various items

	if ( action == @selector( alignLeft: ))
	{
		[item setState:([self alignment] == NSLeftTextAlignment)? NSOnState : NSOffState ];
		return ![self locked];
	}
	
	if ( action == @selector( alignRight: ))
	{
		[item setState:([self alignment] == NSRightTextAlignment)? NSOnState : NSOffState ];
		return ![self locked];
	}
	
	if ( action == @selector( alignCenter: ))
	{
		[item setState:([self alignment] == NSCenterTextAlignment)? NSOnState : NSOffState ];
		return ![self locked];
	}
	
	if ( action == @selector( alignJustified: ))
	{
		[item setState:([self alignment] == NSJustifiedTextAlignment)? NSOnState : NSOffState ];
		return ![self locked];
	}
	
	if ( action == @selector( paste: ))
		return ![self locked] && [self canPasteText:[NSPasteboard generalPasteboard]];
	
	if ( action == @selector( verticalAlign: ))
	{
		[item setState:([item tag] == (NSInteger)[self verticalAlignment])? NSOnState : NSOffState];
		
		if([item tag] == kDKTextPathVerticalAlignmentCentredOnPath)
			return NO;	// shapes don't support this alignment mode
		else
			return ![self locked];
	}
	
	if ( action == @selector( capitalize: ))
	{
		[item setState:[[self textAdornment] capitalization] == (DKTextCapitalization)[item tag]? NSOnState : NSOffState];
		return ![self locked];
	}
	
	if( action == @selector( underline: ))
	{
		NSInteger ul = [[self textAdornment] underlines];
		BOOL homo = [[self textAdornment] attributeIsHomogeneous:NSUnderlineStyleAttributeName];
		
		[item setState:ul > 0? (homo? NSOnState : NSMixedState) : NSOffState];
		return ![self locked];
	}
	
	return [super validateMenuItem:item];
}


#pragma mark -
#pragma mark As a NSTextView delegate

- (void)					textDidEndEditing:(NSNotification*)	aNotification
{
	#pragma unused(aNotification)
	[self endEditing];
}


- (void)					textWillChange:(NSNotification*) note
{
#pragma unused(note)
}


- (BOOL)					textView:(NSTextView*) tv doCommandBySelector:(SEL) selector
{
	// this allows the texview to act as a special field editor. Return + Enter complete text editing, but Tab does not. Also, for convenience to
	// Windows switchers, Shift+Return/Shift+Enter insert new lines.
	
	if( tv == m_editorRef )
	{
		NSEvent* evt = [NSApp currentEvent];
		
		if([evt type] == NSKeyDown )
		{
			if( selector == @selector(insertTab:))
			{
				[tv insertTabIgnoringFieldEditor:self];
				return YES;
			}
			else if ( selector == @selector(insertNewline:))
			{
				BOOL shift = ([evt modifierFlags] & NSShiftKeyMask) != 0;
				
				if( shift )
				{
					[tv insertNewlineIgnoringFieldEditor:self];
					return YES;
				}
			}
		}
	}
	return NO;
}

#pragma mark -
#pragma mark - as a KVO observer


- (void)					observeValueForKeyPath:(NSString*) keypath ofObject:(id) object change:(NSDictionary*) change context:(void*) context
{
#pragma unused(context)
	
	// this is called whenever a property of a renderer contained in the style is changed. Its job is to consolidate both undo
	// and client object refresh when properties are altered directly, which of course they usually will be. This powerfully
	// means that renderers themselves do not need to know anything about undo or how they fit into the overall scheme of things.
	
	
	//NSLog(@"got change for keypath '%@' from %@, change = %@", keypath, object, change );
	
	NSKeyValueChange ch = [[change objectForKey:NSKeyValueChangeKindKey] integerValue];
	BOOL	wasChanged = NO;
	
	if ( ch == NSKeyValueChangeSetting )
	{
		if(![[change objectForKey:NSKeyValueChangeOldKey] isEqual:[change objectForKey:NSKeyValueChangeNewKey]])
		{
			if( !([[self undoManager] isUndoing] || [[self undoManager] isRedoing]))
				[self mutateStyle];
			
			[[[self undoManager] prepareWithInvocationTarget:self]	changeKeyPath:keypath
																		ofObject:object
																		 toValue:[change objectForKey:NSKeyValueChangeOldKey]];
			wasChanged = YES;
		}
	}
	else if ( ch == NSKeyValueChangeInsertion || ch == NSKeyValueChangeRemoval )
	{
		if( !([[self undoManager] isUndoing] || [[self undoManager] isRedoing]))
			[self mutateStyle];
		
		// Cocoa has a bug where array insertion/deletion changes don't properly record the old array.
		// GCObserveableObject gives us a workaround
		
		NSArray* old = [object oldArrayValueForKeyPath:keypath];
		[[[self undoManager] prepareWithInvocationTarget:self]	changeKeyPath:keypath
																	ofObject:object
																	 toValue:old];	
		
		wasChanged = YES;
	}
	
	if ( wasChanged && !([[self undoManager] isUndoing] || [[self undoManager] isRedoing]))
	{
		if([object respondsToSelector:@selector(actionNameForKeyPath:changeKind:)])
			[[self undoManager] setActionName:[object actionNameForKeyPath:keypath changeKind:ch]];
		else
			[[self undoManager] setActionName:[GCObservableObject actionNameForKeyPath:keypath objClass:[object class]]];
	}
	[self updateFontPanel];
	[self notifyVisualChange];
}


///*********************************************************************************************************************
///
/// method:			changeKeyPath:ofObject:toValue:
/// scope:			private method
/// overrides:		
/// description:	vectors undo invocations back to the object from whence they came
/// 
/// parameters:		<keypath> the keypath of the action, relative to the object
///					<object> the real target of the invocation
///					<value> the value being restored by the undo/redo task
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)				changeKeyPath:(NSString*) keypath ofObject:(id) object toValue:(id) value
{
	//NSLog(@"changing keypath '%@' of <%@> from Undo task, value = %@", keypath, object, value );
	
	if([value isEqual:[NSNull null]])
		value = nil;
	
	[object setValue:value forKeyPath:keypath];
}

@end
