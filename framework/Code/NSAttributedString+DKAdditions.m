//
//  NSAttributedString+DKAdditions.m
///  DrawKit ©2005-2008 Apptree.net
//
//  Created by graham on 27/05/2008.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
//

#import "NSAttributedString+DKAdditions.h"
#import "DKBezierTextContainer.h"
#import "DKBezierLayoutManager.h"
#import "NSAffineTransform+DKAdditions.h"
#import "NSBezierPath+Geometry.h"
#import "DKDrawKitMacros.h"

///*********************************************************************************************************************
///
/// method:			sharedDrawingLayoutManager
/// scope:			global helper function
/// description:	supply a layout manager common to all DKTextShape instances
/// 
/// parameters:		none
/// result:			the shared layout manager instance
///
/// notes:			
///
///********************************************************************************************************************

NSLayoutManager*		sharedDrawingLayoutManager( void )
{
    // This method returns an NSLayoutManager that can be used to draw the contents of a DKTextShape.
	// The same layout manager is used for all instances of the class
	
    static NSLayoutManager*	sharedLM = nil;
	NSTextContainer*		tc = nil;
    
	if ( sharedLM == nil )
	{
        tc = [[DKBezierTextContainer alloc] initWithContainerSize:NSMakeSize(1.0e6, 1.0e6)];
		//NSTextView*	tv = [[NSTextView alloc] initWithFrame:NSZeroRect];
        
        sharedLM = [[NSLayoutManager alloc] init];
		
		//[tc setTextView:tv];
		//[tv release];
		
        [tc setWidthTracksTextView:NO];
        [tc setHeightTracksTextView:NO];
        [sharedLM addTextContainer:tc];
        [tc release];
		
		[sharedLM setUsesScreenFonts:NO];
    }
	else
		tc = [[sharedLM textContainers] lastObject];
	
	[tc setLineFragmentPadding:0];
	return sharedLM;
}


///*********************************************************************************************************************
///
/// method:			sharedCaptureLayoutManager
/// scope:			global helper function
/// description:	supply a layout manager that can be used to capture text layout into a bezier path
/// 
/// parameters:		none
/// result:			the shared layout manager instance
///
/// notes:			
///
///********************************************************************************************************************

NSLayoutManager*		sharedCaptureLayoutManager( void )
{
    static DKBezierLayoutManager*	sharedLM = nil;
	NSTextContainer*				tc = nil;
    
	if ( sharedLM == nil )
	{
        tc = [[DKBezierTextContainer alloc] initWithContainerSize:NSMakeSize(1.0e6, 1.0e6)];
		NSTextView*	tv = [[NSTextView alloc] initWithFrame:NSZeroRect];
        
        sharedLM = [[DKBezierLayoutManager alloc] init];
		
		[tc setTextView:tv];
		[tv release];
		
        [tc setWidthTracksTextView:NO];
        [tc setHeightTracksTextView:NO];
        [sharedLM addTextContainer:tc];
        [tc release];
		
		[sharedLM setUsesScreenFonts:NO];
    }
	else
		tc = [[sharedLM textContainers] lastObject];
	
	[tc setLineFragmentPadding:0];
	return sharedLM;
}

@implementation NSAttributedString (DKAdditions)



///*********************************************************************************************************************
///
/// method:			drawInRect:withLayoutSize:atAngle:
/// scope:			public instance method
/// overrides:		
/// description:	lays out the receiver then draws it to the destination
/// 
/// parameters:		<destRect> the final destination of the text. The text is scaled and translated to draw in this rect
///					<layoutSize> a size describing the text layout container. Text is laid out to fit into this size.
///					<radians> an angle to which the text is rotated before being drawn to <destRect>
/// result:			none
///
/// notes:			this method is intended to be utilised by high-level text objects such as DKTextShape and
///					DKTextAdornment. It both lays out and renders text in many different ways according to its
///					parameters (and the string's attributes themselves). 
///
///********************************************************************************************************************

- (void)	drawInRect:(NSRect) destRect withLayoutSize:(NSSize) layoutSize atAngle:(CGFloat) radians
{
	[self drawInRect:destRect withLayoutPath:[NSBezierPath bezierPathWithRect:NSMakeRect( 0, 0, layoutSize.width, layoutSize.height)] atAngle:radians];
}



///*********************************************************************************************************************
///
/// method:			drawInRect:withLayoutPath:atAngle:
/// scope:			public instance method
/// overrides:		
/// description:	lays out the receiver then draws it to the destination
/// 
/// parameters:		<destRect> the final destination of the text. The text is scaled and translated to draw in this rect
///					<layoutPath> a path describing the text layout container. Text is laid out to fit into this path.
///					<radians> an angle to which the text is rotated before being drawn to <destRect>
/// result:			none
///
/// notes:			this method is intended to be utilised by high-level text objects such as DKTextShape and
///					DKTextAdornment. It both lays out and renders text in many different ways according to its
///					parameters (and the string's attributes themselves). 
///
///********************************************************************************************************************


- (void)	drawInRect:(NSRect) destRect withLayoutPath:(NSBezierPath*) layoutPath atAngle:(CGFloat) radians
{
	[self drawInRect:destRect withLayoutPath:layoutPath atAngle:radians verticalPositioning:kDKTextShapeVerticalAlignmentTop verticalOffset:0];
}


///*********************************************************************************************************************
///
/// method:			drawInRect:withLayoutPath:atAngle:verticalPositioning:verticalOffset:
/// scope:			public instance method
/// overrides:		
/// description:	lays out the receiver then draws it to the destination
/// 
/// parameters:		<destRect> the final destination of the text. The text is scaled and translated to draw in this rect
///					<layoutPath> a path describing the text layout container. Text is laid out to fit into this path.
///					<radians> an angle to which the text is rotated before being drawn to <destRect>
///					<vAlign> whether the text is positioned at top, centre, bottom or at some value
///					<vPos> proportion of srcRect given by interval 0..1 when vAlign is proportional
/// result:			none
///
/// notes:			this method is intended to be utilised by high-level text objects such as DKTextShape and
///					DKTextAdornment. It both lays out and renders text in many different ways according to its
///					parameters (and the string's attributes themselves). 
///
///********************************************************************************************************************

- (void)	drawInRect:(NSRect) destRect
			withLayoutPath:(NSBezierPath*) layoutPath
			atAngle:(CGFloat) radians
			verticalPositioning:(DKVerticalTextAlignment) vAlign
			verticalOffset:(CGFloat) vPos
{
	NSAssert( destRect.size.width > 0.0 && destRect.size.height >= 0.0, @"invalid destination rect for text layout" );
	NSAssert( layoutPath != nil, @"invalid layout path for text layout");
	NSAssert(![layoutPath isEmpty], @"empty layout path for text layout");
	
	vPos = LIMIT( vPos, 0, 1 );
	
	NSTextStorage *contents = [[NSTextStorage alloc] initWithAttributedString:self];

	if ([contents length] > 0)
	{
		NSSize					textSize = [layoutPath bounds].size;
		NSRect					srcRect;
		NSLayoutManager*		layoutMgr = sharedDrawingLayoutManager();
		DKBezierTextContainer*	textContainer = [[layoutMgr textContainers] lastObject];
		
		srcRect.size = textSize;
		srcRect.origin = NSZeroPoint;
		
		[textContainer setBezierPath:layoutPath];
		[textContainer setContainerSize:textSize];
		[contents addLayoutManager:layoutMgr];
	
		NSRange glyphRange;

		// Force layout of the text and find out how much of it fits in the container.
		
		glyphRange = [layoutMgr glyphRangeForTextContainer:textContainer];
	
		if (glyphRange.length > 0)
		{
			textSize = [layoutMgr usedRectForTextContainer:textContainer].size;
			
			// apply vertical alignment setting
			
			NSPoint textOrigin = NSZeroPoint;
			
			switch( vAlign )
			{
				default:
					break;
					
				case kDKTextShapeVerticalAlignmentCentre:
					textOrigin.y = NSMidY( srcRect ) - ( 0.5 * textSize.height );
					break;
					
				case kDKTextShapeVerticalAlignmentBottom:
					textOrigin.y = NSMaxY( srcRect ) - textSize.height;
					break;
					
				case kDKTextShapeVerticalAlignmentProportional:
					textOrigin.y = vPos * ( NSHeight( srcRect ) - textSize.height );
					break;
			}
			
			// ready to actually draw the text, so now is the time to establish the transformations needed to destRect and angle.
			
			NSAffineTransform* xform = [NSAffineTransform transform];
	
			[xform translateXBy:destRect.origin.x yBy:destRect.origin.y];
			[xform scaleXBy:NSWidth(destRect)/NSWidth(srcRect) yBy:NSHeight(destRect)/NSHeight(srcRect)];
			[xform rotateByRadians:radians];

			SAVE_GRAPHICS_CONTEXT	//[NSGraphicsContext saveGraphicsState];
			[xform concat];
			
			// draw the glyphs and their background
			
			//[layoutMgr drawBackgroundForGlyphRange:glyphRange atPoint:textOrigin];
			[layoutMgr drawGlyphsForGlyphRange:glyphRange atPoint:textOrigin];
			
			RESTORE_GRAPHICS_CONTEXT	//[NSGraphicsContext restoreGraphicsState];
		}
		[contents removeLayoutManager:layoutMgr];
		[textContainer setBezierPath:nil];
	}
	[contents release];
}


- (NSSize)	accurateSize
{
	// returns the accurate size needed to draw the string on a single line. This works by forcing the text layout, so is considerably more
	// expensive than -size. However, it is a lot more accurate!
	
	NSSize			as = NSZeroSize;
	NSTextStorage*	contents = [[NSTextStorage alloc] initWithAttributedString:self];
	
	if ([contents length] > 0)
	{
		NSLayoutManager*		layoutMgr = sharedDrawingLayoutManager();
		DKBezierTextContainer*	textContainer = [[layoutMgr textContainers] lastObject];
		
		[textContainer setBezierPath:nil];
		[textContainer setContainerSize:NSMakeSize(50000, 50000)];
		[contents addLayoutManager:layoutMgr];
		
		NSRange glyphRange = [layoutMgr glyphRangeForTextContainer:textContainer];
		
		if (glyphRange.length > 0)
			as = [layoutMgr usedRectForTextContainer:textContainer].size;
		
		[contents removeLayoutManager:layoutMgr];
	}
	[contents release];
	
	return as;
}


- (BOOL)	isHomogeneous
{
	// returns YES if all the attributes at index 0 apply to the entire string, or if string is empty.
	
	NSRange eff, fullRange = NSMakeRange( 0, [self length]);
	
	if( fullRange.length > 0 )
	{
		(void)[self attributesAtIndex:0 effectiveRange:&eff];
		return NSEqualRanges( eff, fullRange );
	}
	else
		return YES;
}


- (BOOL)	attributeIsHomogeneous:(NSString*) attrName
{
	// returns YES if the attribute named applies over the entire length of the string or the string is empty, NO otherwise (including if the attribute doesn't exist).
	
	NSRange eff, fullRange = NSMakeRange( 0, [self length]);
	
	if( fullRange.length > 0 )
	{
		(void)[self attribute:attrName atIndex:0 effectiveRange:&eff];
		return NSEqualRanges( eff, fullRange );
	}
	else
		return YES;
}


- (BOOL)	attributesAreHomogeneous:(NSDictionary*) attrs
{
	// returns yes if the attributes listed in <attrs> are homogeneous, otherwise NO.
	
	NSEnumerator*	iter = [attrs keyEnumerator];
	NSString*		key;
	
	while(( key = [iter nextObject]))
	{
		if( ![self attributeIsHomogeneous:key])
			return NO;
	}
	
	return YES;
}


@end


#pragma mark -

@implementation NSMutableAttributedString (DKAdditions)

- (void)	makeUppercase
{
	NSRange			effectiveRange = NSMakeRange( 0, 0 );
	NSRange			rangeLimit = NSMakeRange( 0, [self length]);
	NSDictionary*   attributes;
	
	[self beginEditing];
	
	while( rangeLimit.length > 0 )
	{
		attributes = [self attributesAtIndex:rangeLimit.location longestEffectiveRange:&effectiveRange inRange:rangeLimit];
		
		NSString* str = [[[self string] substringWithRange:effectiveRange] uppercaseString];
		[self replaceCharactersInRange:effectiveRange withString:str];
		
		//NSLog(@"replacement range: %@, attributes = %@", NSStringFromRange( effectiveRange ), attributes);
		
		rangeLimit = NSMakeRange( NSMaxRange( effectiveRange ), [self length] - NSMaxRange( effectiveRange ));
	}
	
	[self fixAttributesInRange:NSMakeRange( 0, [self length])];
	[self endEditing];
}


- (void)	makeLowercase
{
	NSRange			effectiveRange = NSMakeRange( 0, 0 );
	NSRange			rangeLimit = NSMakeRange( 0, [self length]);
	NSDictionary*   attributes;
	
	[self beginEditing];
	
	while( rangeLimit.length > 0 )
	{
		attributes = [self attributesAtIndex:rangeLimit.location longestEffectiveRange:&effectiveRange inRange:rangeLimit];
		
		NSString* str = [[[self string] substringWithRange:effectiveRange] lowercaseString];
		[self replaceCharactersInRange:effectiveRange withString:str];
		
		rangeLimit = NSMakeRange( NSMaxRange( effectiveRange ), [self length] - NSMaxRange( effectiveRange ));
	}

	[self fixAttributesInRange:NSMakeRange( 0, [self length])];
	[self endEditing];
}


- (void)	capitalize
{
	NSRange			effectiveRange = NSMakeRange( 0, 0 );
	NSRange			rangeLimit = NSMakeRange( 0, [self length]);
	NSDictionary*   attributes;
	
	[self beginEditing];

	while( rangeLimit.length > 0 )
	{
		attributes = [self attributesAtIndex:rangeLimit.location longestEffectiveRange:&effectiveRange inRange:rangeLimit];
		
		NSString* str = [[[self string] substringWithRange:effectiveRange] capitalizedString];
		[self replaceCharactersInRange:effectiveRange withString:str];
		
		rangeLimit = NSMakeRange( NSMaxRange( effectiveRange ), [self length] - NSMaxRange( effectiveRange ));
	}
	
	[self fixAttributesInRange:NSMakeRange( 0, [self length])];
	[self endEditing];
}


- (void)	convertFontsToFace:(NSString*) face
{
	NSRange			effectiveRange = NSMakeRange( 0, 0 );
	NSRange			rangeLimit = NSMakeRange( 0, [self length]);
	NSFont*			font;
	NSFontManager*	fm = [NSFontManager sharedFontManager];
	
	[self beginEditing];
	
	while( rangeLimit.length > 0 )
	{
		font = [self attribute:NSFontAttributeName atIndex:rangeLimit.location longestEffectiveRange:&effectiveRange inRange:rangeLimit];
		
		NSFont* newFont = [fm convertFont:font toFace:face];
		
		if( newFont != font )
			[self addAttribute:NSFontAttributeName value:newFont range:effectiveRange];
		
		rangeLimit = NSMakeRange( NSMaxRange( effectiveRange ), [self length] - NSMaxRange( effectiveRange ));
	}
	
	[self fixFontAttributeInRange:NSMakeRange( 0, [self length])];
	[self endEditing];
}



- (void)	convertFontsToFamily:(NSString*) family
{
	NSRange			effectiveRange = NSMakeRange( 0, 0 );
	NSRange			rangeLimit = NSMakeRange( 0, [self length]);
	NSFont*			font;
	NSFontManager*	fm = [NSFontManager sharedFontManager];
	
	[self beginEditing];
	
	while( rangeLimit.length > 0 )
	{
		font = [self attribute:NSFontAttributeName atIndex:rangeLimit.location longestEffectiveRange:&effectiveRange inRange:rangeLimit];
		
		NSFont* newFont = [fm convertFont:font toFamily:family];
		
		if( newFont != font )
			[self addAttribute:NSFontAttributeName value:newFont range:effectiveRange];
		
		rangeLimit = NSMakeRange( NSMaxRange( effectiveRange ), [self length] - NSMaxRange( effectiveRange ));
	}
	
	[self fixFontAttributeInRange:NSMakeRange( 0, [self length])];
	[self endEditing];
}



- (void)	convertFontsToSize:(CGFloat) aSize
{
	NSRange			effectiveRange = NSMakeRange( 0, 0 );
	NSRange			rangeLimit = NSMakeRange( 0, [self length]);
	NSFont*			font;
	NSFontManager*	fm = [NSFontManager sharedFontManager];
	
	[self beginEditing];
	
	while( rangeLimit.length > 0 )
	{
		font = [self attribute:NSFontAttributeName atIndex:rangeLimit.location longestEffectiveRange:&effectiveRange inRange:rangeLimit];
		
		NSFont* newFont = [fm convertFont:font toSize:aSize];
		
		if( newFont != font )
			[self addAttribute:NSFontAttributeName value:newFont range:effectiveRange];
		
		rangeLimit = NSMakeRange( NSMaxRange( effectiveRange ), [self length] - NSMaxRange( effectiveRange ));
	}
	
	[self fixFontAttributeInRange:NSMakeRange( 0, [self length])];
	[self endEditing];
}



- (void)	convertFontsByAddingSize:(CGFloat) aSize
{
	NSRange			effectiveRange = NSMakeRange( 0, 0 );
	NSRange			rangeLimit = NSMakeRange( 0, [self length]);
	NSFont*			font;
	NSFontManager*	fm = [NSFontManager sharedFontManager];
	
	[self beginEditing];
	
	while( rangeLimit.length > 0 )
	{
		font = [self attribute:NSFontAttributeName atIndex:rangeLimit.location longestEffectiveRange:&effectiveRange inRange:rangeLimit];
		
		NSFont* newFont = [fm convertFont:font toSize:[font pointSize] + aSize];
		
		if( newFont != font )
			[self addAttribute:NSFontAttributeName value:newFont range:effectiveRange];
		
		rangeLimit = NSMakeRange( NSMaxRange( effectiveRange ), [self length] - NSMaxRange( effectiveRange ));
	}
	
	[self fixFontAttributeInRange:NSMakeRange( 0, [self length])];
	[self endEditing];
}



- (void)	convertFontsToHaveTrait:(NSFontTraitMask) traitMask
{
	NSRange			effectiveRange = NSMakeRange( 0, 0 );
	NSRange			rangeLimit = NSMakeRange( 0, [self length]);
	NSFont*			font;
	NSFontManager*	fm = [NSFontManager sharedFontManager];
	
	[self beginEditing];
	
	while( rangeLimit.length > 0 )
	{
		font = [self attribute:NSFontAttributeName atIndex:rangeLimit.location longestEffectiveRange:&effectiveRange inRange:rangeLimit];
		
		NSFont* newFont = [fm convertFont:font toHaveTrait:traitMask];
		
		if( newFont != font )
			[self addAttribute:NSFontAttributeName value:newFont range:effectiveRange];
		
		rangeLimit = NSMakeRange( NSMaxRange( effectiveRange ), [self length] - NSMaxRange( effectiveRange ));
	}
	
	[self fixFontAttributeInRange:NSMakeRange( 0, [self length])];
	[self endEditing];
}



- (void)	convertFontsToNotHaveTrait:(NSFontTraitMask) traitMask
{
	NSRange			effectiveRange = NSMakeRange( 0, 0 );
	NSRange			rangeLimit = NSMakeRange( 0, [self length]);
	NSFont*			font;
	NSFontManager*	fm = [NSFontManager sharedFontManager];
	
	[self beginEditing];
	
	while( rangeLimit.length > 0 )
	{
		font = [self attribute:NSFontAttributeName atIndex:rangeLimit.location longestEffectiveRange:&effectiveRange inRange:rangeLimit];
		
		NSFont* newFont = [fm convertFont:font toNotHaveTrait:traitMask];
		
		if( newFont != font )
			[self addAttribute:NSFontAttributeName value:newFont range:effectiveRange];
		
		rangeLimit = NSMakeRange( NSMaxRange( effectiveRange ), [self length] - NSMaxRange( effectiveRange ));
	}
	
	[self fixFontAttributeInRange:NSMakeRange( 0, [self length])];
	[self endEditing];
}


- (void)	changeFont:(id) sender
{
	// this allows any mutable attributed string to make use of the font panel directly. It applies the font change to the entire string but in chunks such that
	// each range is modified separately and minimally. <sender> is assumed to be the font manager, as per normal rules for changeFont:
	
	NSRange			effectiveRange = NSMakeRange( 0, 0 );
	NSRange			rangeLimit = NSMakeRange( 0, [self length]);
	NSFont*			font;
	
	[self beginEditing];
	
	while( rangeLimit.length > 0 )
	{
		font = [self attribute:NSFontAttributeName atIndex:rangeLimit.location longestEffectiveRange:&effectiveRange inRange:rangeLimit];
		
		NSFont* newFont = [sender convertFont:font];
		
		if( newFont != font )
			[self addAttribute:NSFontAttributeName value:newFont range:effectiveRange];
		
		rangeLimit = NSMakeRange( NSMaxRange( effectiveRange ), [self length] - NSMaxRange( effectiveRange ));
	}
	
	[self fixFontAttributeInRange:NSMakeRange( 0, [self length])];
	[self endEditing];
}


- (void)	changeAttributes:(id) sender
{
	NSRange			effectiveRange = NSMakeRange( 0, 0 );
	NSRange			rangeLimit = NSMakeRange( 0, [self length]);
	NSDictionary*   attributes;
	
	[self beginEditing];
	
	while( rangeLimit.length > 0 )
	{
		attributes = [self attributesAtIndex:rangeLimit.location longestEffectiveRange:&effectiveRange inRange:rangeLimit];
		
		NSDictionary*	newAttributes = [sender convertAttributes:attributes];
		
		if( newAttributes != attributes )
			[self setAttributes:newAttributes range:effectiveRange];
		
		rangeLimit = NSMakeRange( NSMaxRange( effectiveRange ), [self length] - NSMaxRange( effectiveRange ));
	}
	
	[self fixAttributesInRange:NSMakeRange( 0, [self length])];
	[self endEditing];
}



@end
