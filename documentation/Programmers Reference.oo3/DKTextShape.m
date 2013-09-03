//
//  DKTextShape.m
//  DrawingArchitecture
//
//  Created by graham on 16/09/2006.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "DKTextShape.h"

#import "DKDrawableObject+Metadata.h"
#import "DKDrawablePath.h"
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


#pragma mark Static Vars
static BOOL			sDefaultIgnoresStyleAttributes = NO;
static NSString*	sDefault_string = @"Double-click to edit this text";


///*********************************************************************************************************************
///
/// method:			sharedDrawingLayoutManager
/// scope:			static helper function
/// description:	supply a layout manager common to all DKTextShape instances
/// 
/// parameters:		none
/// result:			the shared layout manager instance
///
/// notes:			
///
///********************************************************************************************************************

static NSLayoutManager*		sharedDrawingLayoutManager()
{
    // This method returns an NSLayoutManager that can be used to draw the contents of a DKTextShape.
	// The same layout manager is used for all instances of the class
	
    static NSLayoutManager *sharedLM = nil;
    
	if ( sharedLM == nil )
	{
        NSTextContainer*	tc = [[NSTextContainer alloc] initWithContainerSize:NSMakeSize(1.0e6, 1.0e6)];
		NSTextView*			tv = [[NSTextView alloc] initWithFrame:NSZeroRect];
        
        sharedLM = [[NSLayoutManager alloc] init];
		
		[tc setTextView:tv];
		[tv release];
		
        [tc setWidthTracksTextView:NO];
        [tc setHeightTracksTextView:NO];
        [sharedLM addTextContainer:tc];
        [tc release];
		
		[sharedLM setUsesScreenFonts:NO];
    }
    return sharedLM;
}


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
	DKTextShape*  te = [[DKTextShape alloc] initWithRect:bounds];
	
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
	DKTextShape*  te = [[DKTextShape alloc] initWithRect:bounds];
	
	NSAttributedString* str = [[NSAttributedString alloc] initWithRTF:rtfData documentAttributes:nil];
	[te setText:str];
	[str release];

	return [te autorelease];
}


#pragma mark -

///*********************************************************************************************************************
///
/// method:			setDefaultIgnoresStyleAttributes:
/// scope:			public class method
/// overrides:
/// description:	set the default ignore flag for new text shapes.
/// 
/// parameters:		<ignore> YES if text attributes are independent, NO if they come from the style
/// result:			none
///
/// notes:			The attributes of the text displayed can either be local to the object or come from the style. The
///					latter is especially useful if the style is shared, as you can apply attribute changes to many
///					objects at once. This method sets the default for new text shapes.
///
///********************************************************************************************************************

+ (void)					setDefaultIgnoresStyleAttributes:(BOOL) ignore
{
	sDefaultIgnoresStyleAttributes = ignore;
}


///*********************************************************************************************************************
///
/// method:			defaultIgnoresStyleAttributes:
/// scope:			public class method
/// overrides:
/// description:	get the default ignore flag for new text shapes.
/// 
/// parameters:		none
/// result:			YES if text attributes are independent, NO if they come from the style
///
/// notes:			The attributes of the text displayed can either be local to the object or come from the style. The
///					latter is especially useful if the style is shared, as you can apply attribute changes to many
///					objects at once. This method sets the default for new text shapes.
///
///********************************************************************************************************************

+ (BOOL)					defaultIgnoresStyleAttributes
{
	return sDefaultIgnoresStyleAttributes;
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
/// notes:			If the string has attributes, they are adopted locally if the style attributes are ignored. If the
///					style isn't locked, its text attributes are set to the string's attributes. If the style isn't
///					being ignored, the style's attributes are used and any attributes passed in are not used.
///
///********************************************************************************************************************

- (void)					setText:(id) newText
{
	if ( newText != m_text)
	{
        if ( m_text == nil )
			m_text = [[NSTextStorage alloc] init];
		
		NSAttributedString *contentsCopy = [[NSAttributedString alloc] initWithAttributedString:m_text];
        [[[self undoManager] prepareWithInvocationTarget:self] setText:contentsCopy];
        
		[contentsCopy release];
       
        if ([newText isKindOfClass:[NSAttributedString class]])
            [m_text replaceCharactersInRange:NSMakeRange(0, [m_text length]) withAttributedString:newText];
		else
            [m_text replaceCharactersInRange:NSMakeRange(0, [m_text length]) withString:newText];
        
		LogEvent_(kStateEvent, @"set new text = '%@'", [self string]);
		
		[self syncWithStyle];
		[self notifyVisualChange];
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
	return m_text;
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
	
	NSArray*	types = [NSAttributedString textPasteboardTypes];
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
			// use the pasted formatting, so remove text attributes from the style, which will then get reset
			// from the pasted attributes when the style is synced by setText:
			
			[[self style] setTextAttributes:nil];
			[[self style] adoptFromText:str];
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
	return ([pb availableTypeFromArray:[NSAttributedString textPasteboardTypes]] != nil );
}


#pragma mark -
#pragma mark - text layout and drawing

///*********************************************************************************************************************
///
/// method:			setTextRect:
/// scope:			public instance method
/// overrides:
/// description:	set a layout rectangle within the shape's bounds to lay text out in
/// 
/// parameters:		<rect> a rectangle relative to the canonical bounds
/// result:			none
///
/// notes:			defines a rect relative to the shape's original path bounds that the text is laid out in. If you
///					pass NSZeroRect (the default), the text is laid out using the shape's bounds. This additional rect
///					gives you the flexibility to modify the text layout to anywhere within the shape. Note the
///					coordinate system it uses is transformed by the shape's transform - so if you wanted to lay the
///					text out in half the shape's width, the rect's width would be 0.5. Similarly, to offset the text
///					halfway across, its x origin would be 0. This means this rect maintains its correct effect no matter
///					how the shape is scaled or rotated, and it does the thing you expect.
///
///********************************************************************************************************************

- (void)					setTextRect:(NSRect) rect
{
	
	if ( ! NSEqualRects( m_textRect, rect ))
	{
		m_textRect = rect;
		[self notifyVisualChange];
	}
}


///*********************************************************************************************************************
///
/// method:			textRect:
/// scope:			public instance method
/// overrides:
/// description:	get the layout rectangle within the shape's bounds to lay text out in
/// 
/// parameters:		none 
/// result:			a rectangle relative to the canonical bounds
///
/// notes:			see setTextRect:
///
///********************************************************************************************************************

- (NSRect)					textRect
{
	return m_textRect;
}


#pragma mark -


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
    unsigned len = [contents length];
    
    if (len > 0)
	{
        NSRange	glyphRange;
		NSLayoutManager *lm = sharedDrawingLayoutManager();
        NSTextContainer *tc = [[lm textContainers] objectAtIndex:0];
        NSSize requiredSize = [self size];
		
		if ( requiredSize.height < maxsize.height )
			requiredSize.height = maxsize.height;
        
        [tc setContainerSize:requiredSize];
        [contents addLayoutManager:lm];

		glyphRange = [lm glyphRangeForTextContainer:tc];
        requiredSize = [lm usedRectForTextContainer:tc].size;

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


///*********************************************************************************************************************
///
/// method:			drawText
/// scope:			protected method
/// description:	renders the text in the shape's bounds.
/// 
/// parameters:		none
/// result:			none
///
/// notes:			applies the shape's rotation and position to the text, as well as other parameters such as the
///					vertical alignment. The text is wrapped into the shape's bounds and is clipped to the shape's
///					path. The textRect is factored in as necessary.
///
///********************************************************************************************************************


#define qShowLineFragRects	0
#define qShowGlyphLocations	0

- (void)				drawText
{
	NSTextStorage *contents = [self text];

	if ([contents length] > 0)
	{
		NSLayoutManager *lm = sharedDrawingLayoutManager();
		NSTextContainer *tc = [[lm textContainers] objectAtIndex:0];
		
		NSRange glyphRange;
		NSRect	tr = [self textRect];
		NSSize	bSize = [self size];
		
		if( NSEqualSizes( bSize, NSZeroSize ))
			return;
		
		if ( NSEqualRects( NSZeroRect, tr ))
			tr.size = bSize;
		else
		{
			tr.size.width *= bSize.width;
			tr.size.height *= bSize.height;
		}
		[tc setContainerSize:tr.size];
		[contents addLayoutManager:lm];

		// Force layout of the text and find out how much of it fits in the container.
		glyphRange = [lm glyphRangeForTextContainer:tc];

		// because of the object transform applied, draw the text at the origin

		[NSGraphicsContext saveGraphicsState];
		
		NSBezierPath* clipPath = [self transformedPath];
		[clipPath addClip];
		
		NSAffineTransform* tt = [self textTransform];
		[tt concat];
		
		if (glyphRange.length > 0)
		{
			NSSize textSize = [lm usedRectForTextContainer:tc].size;
			NSPoint textOrigin = [self textOriginForSize:textSize];
			
			[lm drawBackgroundForGlyphRange:glyphRange atPoint:textOrigin];
			[lm drawGlyphsForGlyphRange:glyphRange atPoint:textOrigin];
		
		#if qShowLineFragRects
		
			int			glyphIndex = 0;
			NSRange		grange;
			NSRect		frag;
			
			
			while ( glyphIndex < [contents length])
			{
				frag = [lm lineFragmentUsedRectForGlyphAtIndex:glyphIndex effectiveRange:&grange];
				frag = NSOffsetRect( frag, textOrigin.x, textOrigin.y );
				
				[[NSColor redColor] set];
				NSFrameRectWithWidth( frag, 1.0 );
				
				#if qShowGlyphLocations
				
				int			ig;
				NSPoint		gloc, previous;
				NSRect		grect;
				
				grect = frag;
				previous = frag.origin;
				
				[[NSColor blueColor] set];
				for( ig = grange.location; ig < grange.location + grange.length; ++ig )
				{
					gloc = [lm locationForGlyphAtIndex:ig];
					
					gloc.x += textOrigin.x;
					gloc.y += textOrigin.y;
					
					grect.origin.x = previous.x;
					grect.size.width = gloc.x - previous.x;
					previous = gloc;
					
					NSFrameRectWithWidth( grect, 0.5 );
				}
				
				#endif
			
				glyphIndex += grange.length;
			}
		
		#endif
		}
		[NSGraphicsContext restoreGraphicsState];
		[contents removeLayoutManager:lm];
	}
}


///*********************************************************************************************************************
///
/// method:			textTransform
/// scope:			protected instance method
/// overrides:
/// description:	return a transform for placing the text within the shape
/// 
/// parameters:		none 
/// result:			a transform object
///
/// notes:			returns a transform that will draw the text at the shape's location and rotation. This transform
///					doesn't apply the shape's scale since the text is laid out based on the final shape size, not on
///					the original path. Text is rewrapped as the shape itself changes size.
///
///********************************************************************************************************************

- (NSAffineTransform*)		textTransform
{
	NSAffineTransform* xform = [NSAffineTransform transform];
	[xform translateXBy:[self location].x yBy:[self location].y];
	[xform rotateByRadians:[self angle]];
	
	if ([self size].width != 0.0 && [self size].height != 0.0 )
		[xform translateXBy:-[self offset].width * [self size].width yBy:-[self offset].height * [self size].height];
		
	// factor in container transform:
	
	NSAffineTransform* xt = [self containerTransform];
	
	if( xt != nil )
		[xform appendTransform:xt];
	
	return xform;
}


///*********************************************************************************************************************
///
/// method:			textOriginForSize:
/// scope:			protected instance method
/// overrides:
/// description:	return a transform for placing the text within the shape
/// 
/// parameters:		<textSize> the width and height of the text 
/// result:			a point, the top, left point where text should start drawing
///
/// notes:			
///
///********************************************************************************************************************

- (NSPoint)					textOriginForSize:(NSSize) textSize
{
	NSPoint textOrigin = NSZeroPoint;
	NSRect	tr = [self textRect];
	
	if ( NSEqualRects( NSZeroRect, tr ))
		tr.size = [self size];
	else
	{
		tr.size.width *= [self size].width;
		tr.size.height *= [self size].height;
	}
	
	textOrigin.x -= ( 0.5 * [self size].width );
	textOrigin.y -= ( 0.5 * [self size].height );
	
	// factor in textRect offset
	
	textOrigin.x += ( tr.origin.x * [self size].width);
	textOrigin.y += ( tr.origin.y * [self size].height);
	
	// factor in setting for vertical alignment
	
	switch([self verticalAlignment])
	{
		default:
		case kGCTextShapeVerticalAlignmentTop:
			break;
			
		case kGCTextShapeVerticalAlignmentCentre:
			textOrigin.y += 0.5 * (tr.size.height - textSize.height);
			break;
			
		case kGCTextShapeVerticalAlignmentBottom:
			textOrigin.y += (tr.size.height - textSize.height);
			break;
			
		case kGCTextShapeVerticalAlignmentProportional:
			textOrigin.y += mVerticalAlignmentAmount * (tr.size.height - textSize.height);
			break;
	}
	
	return textOrigin;
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
	NSSize			textSize;
	NSEnumerator*	iter = [[self textPathGlyphsUsedSize:&textSize] objectEnumerator];
	NSBezierPath*	path = [NSBezierPath bezierPath];
	NSBezierPath*	gp;
	
	// turn it into a single path
	
	while(( gp = [iter nextObject]))
		[path appendBezierPath:gp];
		
	// set the path to the overall position and angle in the drawing
	
	NSPoint				textOrigin = [self textOriginForSize:textSize];
	NSAffineTransform*	xform = [self textTransform];
	
	NSAffineTransform* tp = [NSAffineTransform transform];
	[tp translateXBy:textOrigin.x yBy:textOrigin.y];
	[xform prependTransform:tp];
	
	[path transformUsingAffineTransform:xform];

	return path;
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
	NSMutableArray*	array = [NSMutableArray array];
	NSLayoutManager *lm = sharedDrawingLayoutManager();
	NSTextContainer *tc = [[lm textContainers] objectAtIndex:0];
	
	NSRange glyphRange;
	NSRect	tr = [self textRect];
	
	if ( NSEqualRects( NSZeroRect, tr ))
		tr.size = [self size];
	else
	{
		tr.size.width *= [self size].width;
		tr.size.height *= [self size].height;
	}
	[tc setContainerSize:tr.size];
	[[self text] addLayoutManager:lm];

	// lay out the text and find out how much of it fits in the container.
	
	glyphRange = [lm glyphRangeForTextContainer:tc];

	if ( textSize )
		*textSize = [lm usedRectForTextContainer:tc].size;
	
	NSBezierPath*	temp;
	NSRect			fragRect;
	NSRange			grange;
	unsigned		glyphIndex = 0;	
	
	if (glyphRange.length > 0)
	{
		while( glyphIndex < glyphRange.length )
		{
			// look at the formatting applied to individual glyphs so that the path applies that formatting as necessary.
			
			unsigned	g;
			NSPoint		gloc, ploc;
			NSFont*		font;
			float		base;
			
			fragRect = [lm lineFragmentRectForGlyphAtIndex:glyphIndex effectiveRange:&grange];
			
			for( g = grange.location; g < grange.location + grange.length; ++g )
			{
				temp = [NSBezierPath bezierPath];
				ploc = gloc = [lm locationForGlyphAtIndex:g];
				
				ploc.x -= fragRect.origin.x;
				ploc.y -= fragRect.origin.y;
				
				font = [[[self text] attributesAtIndex:g effectiveRange:NULL] objectForKey:NSFontAttributeName];
				[temp moveToPoint:ploc];
				[temp appendBezierPathWithGlyph:[lm glyphAtIndex:g] inFont:font];
				
				base = [font pointSize] - [font ascender];
				
				// need to vertically flip and offset each glyph as it is created
				
				NSAffineTransform* xform = [NSAffineTransform transform];
				[xform translateXBy:0 yBy:( fragRect.size.height - base ) * 2];
				[xform scaleXBy:1.0 yBy:-1.0];
				[temp transformUsingAffineTransform:xform];

				[array addObject:temp];
			}
			// next line:
			glyphIndex += grange.length;
		}
	}
	[[self text] removeLayoutManager:lm];

	return array;
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
	
	DKDrawableShape* ds = [DKDrawableShape drawableShapeWithPath:[self textPath] rotatedToAngle:[self angle]];
	
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
///					within letters become separated.
///
///********************************************************************************************************************

- (DKShapeGroup*)			makeShapeGroupWithText
{
	NSSize		textSize;
	NSArray*	paths = [self textPathGlyphsUsedSize:&textSize];
	
	DKShapeGroup* group = [DKShapeGroup groupWithBezierPaths:paths objectType:kGCCreateGroupWithShapes style:[self styleWithTextAttributes]];
	
	// need to move the group to the right place so that it is in the same place in the drawing as this
	
	NSPoint				textOrigin = [self textOriginForSize:textSize];
	NSAffineTransform*	xform = [self textTransform];
	
	NSAffineTransform* tp = [NSAffineTransform transform];
	[tp translateXBy:textOrigin.x yBy:textOrigin.y];
	[xform prependTransform:tp];
	
	NSPoint loc = [xform transformPoint:[group location]];
	[group moveToPoint:loc];
	[group rotateToAngle:[self angle]];
	
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
	if([self ignoresStyleAttributes])
	{
		DKStyle*	styl = [[DKStyle alloc] init];
		DKFill*		fill;
		NSColor*	fc = [self localTextAttribute:NSForegroundColorAttributeName];
		
		if ( fc )
			fill = [DKFill fillWithColour:fc];
		else
			fill = [DKFill fillWithColour:[NSColor blackColor]];
			
		// copy the shadow - text shadow is flipped
			
		NSShadow*	shad = [[self localTextAttribute:NSShadowAttributeName] copy];

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
		
		NSColor*	strokeColour = [self localTextAttribute:NSStrokeColorAttributeName];
		float		sw = [[self localTextAttribute:NSStrokeWidthAttributeName] floatValue];
		
		if ( strokeColour && sw > 0.0 )
		{
			DKStroke*	stroke = [DKStroke strokeWithWidth:sw colour:strokeColour];
			[styl addRenderer:stroke];
		}

		return [styl autorelease];
	}
	else
	{
		if ([self style] == nil )
			return [DKStyle defaultStyle];
		else
			return [[self style] drawingStyleFromTextAttributes];
	}
}


#pragma mark -
#pragma mark - basic text attributes
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
		if([self ignoresStyleAttributes])
		{
			[[[self undoManager] prepareWithInvocationTarget:self] setFont:[self font]];
			[[self text] setFont:font];
			[self notifyVisualChange];
			[[self undoManager] setActionName:NSLocalizedString(@"Change Font", @"change font text shape no style")];
		}
		else
			[[self style] setFont:font];
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
	if([self ignoresStyleAttributes])
		return[[self text] font];
	else
		return [[self style] font];
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

- (void)					setFontSize:(float) size
{
	if ( ![self locked] && ![self ignoresStyleAttributes])
		[[self style] setFontSize:size];
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

- (float)					fontSize
{
	return [[self font] pointSize];
}


- (void)					setTextColour:(NSColor*) colour
{
	if ( ![self locked])
	{
		if([self ignoresStyleAttributes])
			[self changeLocalTextAttribute:NSForegroundColorAttributeName toValue:colour];
		else
			[[self style] changeTextAttribute:NSForegroundColorAttributeName toValue:colour];
	}
}


- (NSColor*)				textColour
{
	if ([self ignoresStyleAttributes])
		return [self localTextAttribute:NSForegroundColorAttributeName];
	else
		return [[[self style] textAttributes] objectForKey:NSForegroundColorAttributeName];
}


#pragma mark -
- (void)					setVerticalAlignment:(DKVerticalTextAlignment) align
{
	if ( ![self locked] && align != m_vertAlign )
	{
		[[[self undoManager] prepareWithInvocationTarget:self] setVerticalAlignment:m_vertAlign];
		m_vertAlign = align;
		[self notifyVisualChange];
	}
}


- (DKVerticalTextAlignment)	verticalAlignment
{
	return m_vertAlign;
}


- (void)					setVerticalAlignmentProportion:(float) prop
{
	prop = LIMIT( prop, 0, 1 );
	
	if ( ![self locked] && prop != mVerticalAlignmentAmount )
	{
		[[[self undoManager] prepareWithInvocationTarget:self] setVerticalAlignmentProportion:[self verticalAlignmentProportion]];
		mVerticalAlignmentAmount = prop;
		[self notifyVisualChange];
	}
}


- (float)					verticalAlignmentProportion
{
	return mVerticalAlignmentAmount;
}


- (void)					setParagraphStyle:(NSParagraphStyle*) ps
{
	if ( ![self locked])
	{
		if ([self ignoresStyleAttributes])
			[self changeLocalTextAttribute:NSParagraphStyleAttributeName toValue:ps];
		else
			[[self style] setParagraphStyle:ps];
	}
}


- (NSParagraphStyle*)		paragraphStyle
{
	if ([self ignoresStyleAttributes])
		return [self localTextAttribute:NSParagraphStyleAttributeName];
	else
		return [[self style] paragraphStyle];
}


- (NSTextAlignment)			alignment
{
	return [[self paragraphStyle] alignment];
}


#pragma mark -
#pragma mark - attributes of the local text when ignoring the style
- (void)					setLocalTextAttributes:(NSDictionary*) attrs
{
	NSAttributedString *contentsCopy = [[NSAttributedString alloc] initWithAttributedString:m_text];
	[[[self undoManager] prepareWithInvocationTarget:self] setText:contentsCopy];

	NSRange rng = NSMakeRange( 0, [[self text] length]);
	
	[self notifyVisualChange];
	[[self text] setAttributes:attrs range:rng];
	[[self text] fixAttributesInRange:rng];
	[self notifyVisualChange];
}


- (NSDictionary*)			localTextAttributes
{
	return [[self text] attributesAtIndex:0 effectiveRange:NULL];
}


- (void)					changeLocalTextAttribute:(NSString*) attr toValue:(id) val
{
	NSAssert( attr != nil, @"attribute was nil");
	NSAssert([attr length] > 0, @"attribute was empty");

	NSMutableDictionary* attrs = [[self localTextAttributes] mutableCopy];
	
	if ( val != nil )
		[attrs setObject:val forKey:attr];
	else
		[attrs removeObjectForKey:attr];
	[self setLocalTextAttributes:attrs];
	[attrs release];
	
	// get the action name from the style which already has code to deal with this
	
	[[self undoManager] setActionName:[[self style] actionNameForTextAttribute:attr]];
}


- (id)						localTextAttribute:(NSString*) attr
{
	return [[self localTextAttributes] objectForKey:attr];
}


#pragma mark -
#pragma mark - style stuff
- (void)					syncWithStyle
{
	// sets the text attributes of the stored text to match the style if the style has text attributes available. If
	// the style does not, the current text's attributes are set as the style's text attributes, which 'syncs' the
	// style going the other way too.
	
	static BOOL alreadySyncing = NO;
	
	if( ![self ignoresStyleAttributes])
	{
		if([[self style] hasTextAttributes])
		{
			[[self style] applyToText:[self text]];
		}
		else if (! alreadySyncing )
		{
			alreadySyncing = YES;
			
			NSDictionary* ta = [[self text] attributesAtIndex:0 effectiveRange:NULL];
			[[self style] setTextAttributes:ta];
			
			alreadySyncing = NO;
		}
	}
}


- (void)					setIgnoresStyleAttributes:(BOOL) ignore
{
	if( ignore != [self ignoresStyleAttributes])
	{
		if( !ignore && [[self style] hasTextAttributes])
			[self setLocalTextAttributes:[[self style] textAttributes]];

		[[[self undoManager] prepareWithInvocationTarget:self] setIgnoresStyleAttributes:[self ignoresStyleAttributes]];
		m_ignoreStyleAttributes = ignore;
	}
}


- (BOOL)					ignoresStyleAttributes
{
	return m_ignoreStyleAttributes;
}


- (BOOL)					willRespondToTextAttributes
{
	// returns YES if the object will accept text attribute commands, NO if the object is locked, or the style is locked and
	// not being ignored.
	
	if([self locked])
		return NO;
	else
		return (![[self style] locked] || [self ignoresStyleAttributes]);
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
		
		NSRect	br = [self textRect];
		
		if ( NSEqualRects( NSZeroRect, br ))
			br.size = [self size];
		else
		{
			br.size.width *= [self size].width;
			br.size.height *= [self size].height;
		}
		br.origin.x = [self location].x - ( 0.5 * [self size].width );
		br.origin.y = [self location].y - ( 0.5 * [self size].height );
		
		br.origin.x += ([self textRect].origin.x * [self size].width);
		br.origin.y += ([self textRect].origin.y * [self size].height);
		
		m_editorRef = [view editText:[self text] inRect:br delegate:self];
		
		[[m_editorRef textContainer] setWidthTracksTextView:NO];
		
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
	}
}


- (void)					endEditing
{
	if ( m_editorRef )
	{
		LogEvent_(kReactiveEvent, @"finishing edit of text in shape");
		
		DKDrawingView* parent = (DKDrawingView*)[m_editorRef superview];
		[parent endTextEditing];
		
		if (! [self ignoresStyleAttributes])
		{
			[[self style] adoptFromText:[self text]];
			[self syncWithStyle];
		}
		[self notifyVisualChange];
		m_editorRef = nil;
	}
}


#pragma mark -
#pragma mark - user actions
- (IBAction)				changeFont:(id) sender
{
	// Font Panel changed by user - change the whole of the text to the panel's style. Note - if text is currently
	// highlighted, do nothing, as the changes are handled by another route.
	
	if ( ![self locked])
	{
		NSFont*		newFont = [sender convertFont:[self font]];
		[self setFont:newFont];
	}
}


- (IBAction)				changeFontSize:(id) sender
{
	if ( ![self locked])
		[self setFontSize:[sender floatValue]];
}


- (IBAction)				changeAttributes:(id) sender
{
	if ( ![self locked])
	{
		NSDictionary*		oldAttrs;
		NSDictionary*		newAttrs;
		
		if([self ignoresStyleAttributes])
		{
			//NSRange rng = NSMakeRange( 0, [[self text] length]);
			
			oldAttrs = [[self text] attributesAtIndex:0 effectiveRange:NULL];
			newAttrs = [sender convertAttributes:oldAttrs];
			/*
			[[self text] setAttributes:newAttrs range:rng];
			[[self text] fixAttributesInRange:rng];
			*/
			
			[self setLocalTextAttributes:newAttrs];
		}
		else
		{
			oldAttrs = [[self style] textAttributes];
			newAttrs = [sender convertAttributes:oldAttrs];
			[[self style] setTextAttributes:newAttrs];
		}
		[self notifyVisualChange];
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


- (IBAction)				toggleIgnoreStyleAttributes:(id) sender
{
	#pragma unused(sender)
	
	[self setIgnoresStyleAttributes:![self ignoresStyleAttributes]];
	[[self undoManager] setActionName:NSLocalizedString(@"Use Style Text Attributes", @"undo string for toggle ignores attributes")];

}

#pragma mark -
- (IBAction)				alignLeft:(id) sender
{
	#pragma unused(sender)
	
	// apply the align left attribute to the text's paragraph style
	
	if ( ![self locked])
	{
		if ([self ignoresStyleAttributes])
		{
			NSMutableParagraphStyle* ps = [[self paragraphStyle] mutableCopy];
			
			if ( ps == nil )
				ps = [[NSMutableParagraphStyle defaultParagraphStyle] retain];
				
			[ps setAlignment:NSLeftTextAlignment];
			[self setParagraphStyle:ps];
			[ps release];
		}
		else
			[[self style] setAlignment:NSLeftTextAlignment];
	}
}


- (IBAction)				alignRight:(id) sender
{
	#pragma unused(sender)
	
	if ( ![self locked])
	{
		if ([self ignoresStyleAttributes])
		{
			NSMutableParagraphStyle* ps = [[self paragraphStyle] mutableCopy];
			
			if ( ps == nil )
				ps = [[NSMutableParagraphStyle defaultParagraphStyle] retain];
				
			[ps setAlignment:NSRightTextAlignment];
			[self setParagraphStyle:ps];
			[ps release];
		}
		else
			[[self style] setAlignment:NSRightTextAlignment];
	}
}


- (IBAction)				alignCenter:(id) sender
{
	#pragma unused(sender)
	
	if ( ![self locked])
	{
		if ([self ignoresStyleAttributes])
		{
			NSMutableParagraphStyle* ps = [[self paragraphStyle] mutableCopy];
			
			if ( ps == nil )
				ps = [[NSMutableParagraphStyle defaultParagraphStyle] retain];
				
			[ps setAlignment:NSCenterTextAlignment];
			[self setParagraphStyle:ps];
			[ps release];
		}
		else
			[[self style] setAlignment:NSCenterTextAlignment];
	}
}


- (IBAction)				alignJustified:(id) sender
{
	#pragma unused(sender)
	
	if ( ![self locked])
	{
		if ([self ignoresStyleAttributes])
		{
			NSMutableParagraphStyle* ps = [[self paragraphStyle] mutableCopy];
			
			if ( ps == nil )
				ps = [[NSMutableParagraphStyle defaultParagraphStyle] retain];
				
			[ps setAlignment:NSJustifiedTextAlignment];
			[self setParagraphStyle:ps];
			[ps release];
		}
		else
			[[self style] setAlignment:NSJustifiedTextAlignment];
	}
}


- (IBAction)				underline:(id) sender
{
	#pragma unused(sender)
	
	if ( ![self locked])
	{
		if([self ignoresStyleAttributes])
		{
			int ul = [[self localTextAttribute:NSUnderlineStyleAttributeName] intValue];
			
			ul = ul? 0 : 1;
			
			[self changeLocalTextAttribute:NSUnderlineStyleAttributeName toValue:[NSNumber numberWithInt:ul]];
		}
		else
			[[self style] toggleUnderlined];
	}
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
	int						myIndex = [layer indexOfObject:self];
	
	DKDrawableShape*		so = [self makeShapeWithText];
	
	[layer recordSelectionForUndo];
	[layer addObject:so atIndex:myIndex];
	[layer replaceSelectionWithObject:so];
	[self retain];
	[layer removeObject:self];
	[layer commitSelectionUndoWithActionName:NSLocalizedString(@"Convert To Shape", @"undo string for convert text to shape")];
	[self release];
}


- (IBAction)				convertToShapeGroup:(id) sender
{
	#pragma unused(sender)
	
	DKObjectDrawingLayer*	layer = (DKObjectDrawingLayer*)[self layer];
	int						myIndex = [layer indexOfObject:self];
	
	[layer recordSelectionForUndo];
	DKDrawableShape*		so = [self makeShapeGroupWithText];
	
	[layer addObject:so atIndex:myIndex];
	[layer replaceSelectionWithObject:so];
	[self retain];
	[layer removeObject:self];
	[layer commitSelectionUndoWithActionName:NSLocalizedString(@"Convert To Shape Group", @"undo string for convert text to group")];
	[self release];
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


#pragma mark -
#pragma mark As a DKDrawableShape
+ (int)						knobMask
{
	return kGCDrawableShapeAllKnobs & ~kGCDrawableShapeOriginTarget;
}


#pragma mark -
- (DKDrawablePath*)			makePath
{
	// overrides DKDrawableShape to make a path of the actual text
	
	DKDrawablePath* dp = [DKDrawablePath drawablePathWithPath:[self textPath]];
	
	// convert the text style into a path style
	
	[dp setStyle:[self styleWithTextAttributes]];

	// keep a note of the original text in the meta-data, in case anyone wants to know - allows
	// the text of a shape to be "read" by code if necessary (e.g. by a find)

	[dp setOriginalText:[self text]];

	return dp;
}


#pragma mark -
#pragma mark As a DKDrawableObject
- (NSRect)				bounds
{
	NSRect br = [super bounds];
	
	if ( m_editorRef )
		br = NSUnionRect( br, NSInsetRect([m_editorRef frame], -2.0, -2.0 ));
	
	return br;
}


- (int)					hitPart:(NSPoint) pt
{
	int part = [super hitPart:pt];
	
	if( part == kGCDrawingNoPart )
	{
		// check if contained by the path (regardless of style fill, etc) - this is
		// done to make text objects generally easier to hit since they frequently may
		// have sparse pixels, or none at all.
		
		if ([[self transformedPath] containsPoint:pt])
			part = kGCDrawingEntireObjectPart;
	}
	
	return part;
}


- (void)				drawContent
{
	// don't call [super drawContent] because we don't want the grey border
	
	[super drawContentWithStyle:[self style]];
	[self drawText];
}


- (void)				drawContentForHitBitmap
{
	[super drawContentForHitBitmap];
	[self drawText];
}



- (void)				drawContentWithSelectedState:(BOOL) selected
{
	[super drawContentWithSelectedState:NO];

	if ( m_editorRef && ([m_editorRef superview] == [[self drawing] currentView]) && [[NSGraphicsContext currentContext] isDrawingToScreen])
	{
		NSRect er = [m_editorRef frame];
		
		NSBezierPath* sp = [NSBezierPath bezierPathWithRect:er];
		[[NSColor whiteColor] setFill];
		[sp fill];
		[[NSColor highlightColor] setStroke];
		[sp stroke];
	}
	
	if ( selected )
		[self drawSelectedState];
}


- (void)					mouseDoubleClickedAtPoint:(NSPoint) mp inPart:(int) partcode event:(NSEvent*) evt;
{
	#pragma unused(mp)
	#pragma unused(partcode)
	#pragma unused(evt)
	
	if ( ![self locked])
		[self startEditingInView:(DKDrawingView*)[[self layer] currentView]];
}


- (void)					objectDidBecomeSelected
{
	[super objectDidBecomeSelected];
	[[NSFontManager sharedFontManager] setSelectedFont:[self font] isMultiple:NO];
	[[NSFontManager sharedFontManager] setSelectedAttributes:[[self style] textAttributes] isMultiple:NO];
}


- (void)					objectIsNoLongerSelected
{
	[super objectIsNoLongerSelected];
	[self endEditing];
}


- (BOOL)					populateContextualMenu:(NSMenu*) theMenu
{
	// if the object supports any contextual menu commands, it should add them to the menu and return YES. If subclassing,
	// you should call the inherited method first so that the menu is the union of all the ancestor's added methods.
	
	[[theMenu addItemWithTitle:NSLocalizedString(@"Edit Text", @"menu item for edit text") action:@selector( editText: ) keyEquivalent:@""] setTarget:self];
	[[theMenu addItemWithTitle:NSLocalizedString(@"Fit To Text", @"menu item for fit to text") action:@selector(fitToText:) keyEquivalent:@""] setTarget:self];	
	[[theMenu addItemWithTitle:NSLocalizedString(@"Paste", @"menu item for Paste") action:@selector(paste:) keyEquivalent:@""] setTarget:self];	
	
	NSMenu* fm = [[[NSFontManager sharedFontManager] fontMenu:YES] copy];
	[[theMenu addItemWithTitle:NSLocalizedString(@"Font", @"menu item for Font") action:nil keyEquivalent:@""] setSubmenu:fm];
	[fm release];
	
	[theMenu addItem:[NSMenuItem separatorItem]];
	[[theMenu addItemWithTitle:NSLocalizedString(@"Align Left", @"menu item for align left") action:@selector(alignLeft:) keyEquivalent:@""] setTarget:self];
	[[theMenu addItemWithTitle:NSLocalizedString(@"Centre", @"menu item for centre") action:@selector(alignCenter:) keyEquivalent:@""] setTarget:self];
	[[theMenu addItemWithTitle:NSLocalizedString(@"Justify", @"menu item for justify") action:@selector(alignJustified:) keyEquivalent:@""] setTarget:self];
	[[theMenu addItemWithTitle:NSLocalizedString(@"Align Right", @"menu item for align right") action:@selector(alignRight:) keyEquivalent:@""] setTarget:self];
	
	NSMenu*	vert = [[NSMenu alloc] initWithTitle:NSLocalizedString(@"Vertical Alignment", @"menu item for vertical alignment")];
	
	NSMenuItem* item;
	
	item = [vert addItemWithTitle:NSLocalizedString(@"Top", @"menu item for top (VA)") action:@selector(verticalAlign:) keyEquivalent:@""];
	
	[item setTarget:self];
	[item setTag:kGCTextShapeVerticalAlignmentTop];
	
	item = [vert addItemWithTitle:NSLocalizedString(@"Middle", @"menu item for middle (VA)") action:@selector(verticalAlign:) keyEquivalent:@""];
	[item setTarget:self];
	[item setTag:kGCTextShapeVerticalAlignmentCentre];
	
	item = [vert addItemWithTitle:NSLocalizedString(@"Bottom", @"menu item for bottom (VA)") action:@selector(verticalAlign:) keyEquivalent:@""];
	[item setTarget:self];
	[item setTag:kGCTextShapeVerticalAlignmentBottom];
	
	[[theMenu addItemWithTitle:NSLocalizedString(@"Vertical Alignment", @"menu item for vertical alignment") action:nil keyEquivalent:@""] setSubmenu:vert];
	[vert release];	
	
	[theMenu addItem:[NSMenuItem separatorItem]];
	
	[[theMenu addItemWithTitle:NSLocalizedString(@"Convert to Basic Shape", @"menu item for basic shape") action:@selector(convertToShape:) keyEquivalent:@""] setTarget:self];
	[[theMenu addItemWithTitle:NSLocalizedString(@"Convert to Shape Group", @"menu item for convert to shape group") action:@selector(convertToShapeGroup:) keyEquivalent:@""] setTarget:self];
	[super populateContextualMenu:theMenu];
	return YES;
}


- (void)					setStyle:(DKStyle*) aStyle
{
	if ( aStyle != [self style])
	{
		[super setStyle:aStyle];
		[self syncWithStyle];
		[self notifyVisualChange];
	}
}


- (void)					styleDidChange:(NSNotification*) note
{
	if (![self ignoresStyleAttributes])
		[self syncWithStyle];
	
	[super styleDidChange:note];
}


#pragma mark -
#pragma mark As an NSObject
- (void)					dealloc
{
	[self endEditing];
	[m_text release];
	
	[super dealloc];
}


- (id)						init
{
	self = [super init];
	if (self != nil)
	{
		[self setText:[DKTextShape defaultTextString]];
		NSAssert(m_editorRef == nil, @"Expected init to zero");
		m_textRect = NSZeroRect;
		NSAssert(m_vertAlign == kGCTextShapeVerticalAlignmentTop, @"Expected init to zero");
		m_ignoreStyleAttributes = [DKTextShape defaultIgnoresStyleAttributes];
		
		if (m_text == nil)
		{
			[self autorelease];
			self = nil;
		}
	}
	if (self != nil)
	{
		[self setPath:[NSBezierPath bezierPathWithRect:[DKDrawableShape unitRectAtOrigin]]];
		[self setStyle:[DKStyle defaultTextStyle]];
		[self setVerticalAlignment:kGCTextShapeVerticalAlignmentTop];
	}
	return self;
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
	
	[coder encodeBool:[self ignoresStyleAttributes] forKey:@"ignoreStyleAttribs"];
	[coder encodeObject:[self text] forKey:@"text"];
	[coder encodeRect:[self textRect] forKey:@"textRect"];
	[coder encodeInt:[self verticalAlignment] forKey:@"vAlign"];
	[coder encodeFloat:[self verticalAlignmentProportion] forKey:@"DKTextShape_verticalAlignmentProportion"];
}


- (id)						initWithCoder:(NSCoder*) coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	self = [super initWithCoder:coder];
	if (self != nil)
	{
		[self setIgnoresStyleAttributes:[coder decodeBoolForKey:@"ignoreStyleAttribs"]];
		[self setText:[coder decodeObjectForKey:@"text"]];
		NSAssert(m_editorRef == nil, @"Expected init to zero");
		[self setTextRect:[coder decodeRectForKey:@"textRect"]];
		[self setVerticalAlignment:[coder decodeIntForKey:@"vAlign"]];
		[self setVerticalAlignmentProportion:[coder decodeFloatForKey:@"DKTextShape_verticalAlignmentProportion"]];
	}
	
	return self;
}


#pragma mark -
#pragma mark As part of NSCopying Protocol
- (id)						copyWithZone:(NSZone*) zone
{
	DKTextShape* copy = [super copyWithZone:zone];
	
	[copy setText:[self text]];
	[copy setTextRect:[self textRect]];
	[copy setVerticalAlignment:[self verticalAlignment]];
	[copy setIgnoresStyleAttributes:[self ignoresStyleAttributes]];
	[copy setVerticalAlignmentProportion:[self verticalAlignmentProportion]];
	
	return copy;
}


#pragma mark -
#pragma mark As part of NSMenuValidation Protocol
- (BOOL)				validateMenuItem:(NSMenuItem*) item
{
	BOOL enable = NO;
	SEL	action = [item action];
	
	if(	action == @selector( changeFont: )	||
		action == @selector( changeFontSize: )	||
		action == @selector( alignLeft: ) ||
		action == @selector( alignRight: ) ||
		action == @selector( alignCenter: ) ||
		action == @selector( alignJustified: ) ||
		action == @selector( underline: ) ||
		action == @selector( changeFont: ) ||
		action == @selector( changeFontSize: ) ||
		action == @selector( changeAttributes: ))
		enable = [self willRespondToTextAttributes];
	else if( action == @selector( verticalAlign: ) ||
			action == @selector( fitToText: )	||
			action == @selector( convertToShapeGroup: )	||
			action == @selector( convertToShape: ) ||
			action == @selector( editText: ))
		enable = ![self locked];
	else if ( action == @selector( paste: ))
		enable = ![self locked] && [self canPasteText:[NSPasteboard generalPasteboard]];
	else if ( action == @selector(toggleIgnoreStyleAttributes:))
	{
		enable = ![self locked];
		[item setState:[self ignoresStyleAttributes]? NSOffState : NSOnState];
	}
	// set checkmarks against various items

	if ( action == @selector( alignLeft: ))
		[item setState:([self alignment] == NSLeftTextAlignment)? NSOnState : NSOffState ];
	else if ( action == @selector( alignRight: ))
		[item setState:([self alignment] == NSRightTextAlignment)? NSOnState : NSOffState ];
	else if ( action == @selector( alignCenter: ))
		[item setState:([self alignment] == NSCenterTextAlignment)? NSOnState : NSOffState ];
	else if ( action == @selector( alignJustified: ))
		[item setState:([self alignment] == NSJustifiedTextAlignment)? NSOnState : NSOffState ];
	else if ( action == @selector( paste: ))
		enable = [self canPasteText:[NSPasteboard generalPasteboard]];
	else if ( action == @selector( verticalAlign: ))
	{
		[item setState:[item tag] == (int)[self verticalAlignment]? NSOnState : NSOffState];
	}

	enable |= [super validateMenuItem:item];
	
	return enable;
}


#pragma mark -
#pragma mark As a NSTextView delegate

- (void)					textDidEndEditing:(NSNotification*)	aNotification
{
	#pragma unused(aNotification)
	
	[self endEditing];
}


- (void)					textDidChange:(NSNotification*) notification
{
	#pragma unused(notification)
	//[self notifyVisualChange];
}


@end
