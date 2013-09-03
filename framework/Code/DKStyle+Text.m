///**********************************************************************************************************************************
///  DKStyle-Text.m
///  DrawKit ©2005-2008 Apptree.net
///
///  Created by graham on 21/09/2006.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
///
///**********************************************************************************************************************************


#import "DKStyle+Text.h"
#import "DKFill.h"
#import "DKStroke.h"
#import "DKStyleRegistry.h"


static NSString* kDKBasicTextStyleDefaultKey	= @"326CF635-7863-42C6-900D-CFFC7D57505E";


@implementation DKStyle (TextAdditions)
#pragma mark As a DKStyle

///****************************************************************************************************************
///
/// method:			defaultTextStyle
/// scope:			public class method
/// overrides:
/// description:	returns a basic text style with the default font and atrributes
/// 
/// parameters:		none
/// result:			a style having 18pt Helvetica centred text
///
/// notes:			
///
///***************************************************************************************************************

+ (DKStyle*)		defaultTextStyle
{
	// default text style is a singleton with no fill or stroke, Helvetica 18 regular centred text
	
	DKStyle*		dts = [DKStyleRegistry styleForKey:kDKBasicTextStyleDefaultKey];
	
	if ( dts == nil )
	{
		NSFont* font = [NSFont fontWithName:@"Helvetica" size:14];
		
		dts = [[DKStyle alloc] init];
		[dts setFont:font];
		[dts setAlignment:NSCenterTextAlignment];
		[dts setName:[self styleNameForFont:font]];
		
		// because this is a framework default, its unique key must always be recreated the same. This is not something any client
		// code or other part of the framework should ever attempt.

		dts->m_uniqueKey = kDKBasicTextStyleDefaultKey;
		
		[DKStyleRegistry registerStyle:dts inCategories:[NSArray arrayWithObject:kDKStyleRegistryDKDefaultsCategory]];
		[dts release];
	}
	
	return dts;
}


///****************************************************************************************************************
///
/// method:			textStyleWithFont:
/// scope:			public class method
/// overrides:
/// description:	returns a basic text style with the given font
/// 
/// parameters:		<font> a font
/// result:			a style incorporating the given font in its text attributes
///
/// notes:			the style's name is set based on the font. Initial text alignment is the natural alignment.
///
///***************************************************************************************************************

+ (DKStyle*)		textStyleWithFont:(NSFont*) font
{
	NSAssert( font != nil, @"cannot create a style with a nil font");
	
	DKStyle*	ts = [[DKStyle defaultTextStyle] mutableCopy];
	[ts setFont:font];
	[ts setAlignment:NSNaturalTextAlignment];
	[ts setName:[self styleNameForFont:font]];
	
	return [ts autorelease];
}


///****************************************************************************************************************
///
/// method:			styleNameForFont:
/// scope:			public class method
/// overrides:
/// description:	returns the name and size of the font in a form that can be used as a style name
/// 
/// parameters:		<font> a font
/// result:			a string, such as "Helvetica Bold 18pt"
///
/// notes:			
///
///***************************************************************************************************************

+ (NSString*)			styleNameForFont:(NSFont*) font
{
	return [NSString stringWithFormat:@"%@ %.1fpt", [font displayName], [font pointSize]];
}


#pragma mark -
- (void)				setParagraphStyle:(NSParagraphStyle*) style
{
	[self changeTextAttribute:NSParagraphStyleAttributeName toValue:style];
}


- (NSParagraphStyle*)	paragraphStyle
{
	return [[self textAttributes] objectForKey:NSParagraphStyleAttributeName];
}


#pragma mark -
- (void)				setAlignment:(NSTextAlignment) align
{
	if(![self locked])
	{
		NSMutableParagraphStyle* mps = [[self paragraphStyle] mutableCopy];
		
		if ( mps == nil )
			mps = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
		
		[mps setAlignment:align];
		[self setParagraphStyle:mps];
		[mps release];
		
		NSString* actionName = nil;
		
		switch( align )
		{
			default:
			case NSLeftTextAlignment:
				actionName = NSLocalizedString(@"Align Left", @"undo string for align text left");
				break;
				
			case NSRightTextAlignment:
				actionName = NSLocalizedString(@"Align Right", @"undo string for align text right");
				break;
				
			case NSCenterTextAlignment:
				actionName = NSLocalizedString(@"Align Center", @"undo string for align text centre");
				break;
				
			case NSJustifiedTextAlignment:
				actionName = NSLocalizedString(@"Justify Text", @"undo string for align justify");
				break;
		}
		
		[[self undoManager] setActionName:actionName];
	}
}


- (NSTextAlignment)		alignment
{
	return [[self paragraphStyle] alignment];
}


#pragma mark -

- (void)				changeTextAttribute:(NSString*) attribute toValue:(id) val
{
	if(![self locked])
	{
		//LogEvent_(kReactiveEvent, @"style changing text attribute '%@'", attribute);
		
		NSAssert( attribute != nil, @"attribute was nil");
		NSAssert([attribute length] > 0, @"attribute was empty");
		
		NSMutableDictionary*	attr = [[self textAttributes] mutableCopy];
		
		if ( attr == nil )
			attr = [[NSMutableDictionary alloc] init];
		
		if( val == nil )
			[attr removeObjectForKey:attribute];
		else
			[attr setObject:val forKey:attribute];
		[self setTextAttributes:attr];
		[attr release];
		[[self undoManager] setActionName:[self actionNameForTextAttribute:attribute]];
	}
}


- (NSString*)			actionNameForTextAttribute:(NSString*) attribute
{
	// returns the undo action name for a particular text attribute
	
	NSString* raw;
	
	if ([attribute isEqualToString:NSFontAttributeName])
		raw = @"Change Font";
	else if ([attribute isEqualToString:NSUnderlineStyleAttributeName])
		raw = @"Underline";
	else if ([attribute isEqualToString:NSParagraphStyleAttributeName])
		raw = @"Paragraph Style";
	else
		raw = @"Text Attributes";
		
	return NSLocalizedString( raw, @"style text attribute undo string" );
}



#pragma mark -
- (void)				setFont:(NSFont*) font
{
	if(![self locked])
	{
		[self changeTextAttribute:NSFontAttributeName toValue:font];
		[[self undoManager] setActionName:[self actionNameForTextAttribute:NSFontAttributeName]];
	}
}


- (NSFont*)				font
{
	return [[self textAttributes] objectForKey:NSFontAttributeName];
}


- (void)				setFontSize:(CGFloat) size
{
	if(![self locked])
	{
		NSFontManager* fm = [NSFontManager sharedFontManager];
		NSFont* newFont = [fm convertFont:[self font] toSize:size];
		[self setFont:newFont];
		[[self undoManager] setActionName:NSLocalizedString(@"Font Size", @"undo string for font size change")];
	}
}


- (CGFloat)				fontSize
{
	return [[self font] pointSize];
}


- (void)				setTextColour:(NSColor*) aColour
{
	if( ![self locked])
	{
		[self changeTextAttribute:NSForegroundColorAttributeName toValue:aColour];
		[[self undoManager] setActionName:NSLocalizedString(@"Text Colour", @"undo string for text colour change")];
	}
}


- (NSColor*)			textColour
{
	return [[self textAttributes] objectForKey:NSForegroundColorAttributeName];
}


#pragma mark -
- (void)				setUnderlined:(NSInteger) uval
{
	if(![self locked])
	{
		[self changeTextAttribute:NSUnderlineStyleAttributeName  toValue:[NSNumber numberWithInteger:uval]];
		[[self undoManager] setActionName:NSLocalizedString(@"Underline", @"undo string for underline text")];
	}
}


- (NSInteger)					underlined
{
	return [[[self textAttributes] objectForKey:NSUnderlineStyleAttributeName] integerValue];
}


- (void)				toggleUnderlined
{
	if ([self underlined] == 0 )
		[self setUnderlined:1];
	else
		[self setUnderlined:0];
}


#pragma mark -
- (void)				applyToText:(NSMutableAttributedString*) text
{
	NSRange rng = NSMakeRange( 0, [text length]);
	
	//LogEvent_(kReactiveEvent, @"applying text style; text = '%@'",[text string]);
	
	[text setAttributes:[self textAttributes] range:rng];
	[text fixAttributesInRange:rng];
}


- (void)				adoptFromText:(NSAttributedString*) text
{
	// sets the style's text attributes to match those of the attributed string passed
	
	if(![self locked])
	{
		NSDictionary* ta = [text attributesAtIndex:0 effectiveRange:NULL];
		[self setTextAttributes:ta];
	}
}


#pragma mark -
- (DKStyle*)			drawingStyleFromTextAttributes
{
	// returns a drawing style whose fill colour and shadow are set from the text atrributes of the receiver.
	// This is useful when converting text to a path or shape, since the appearance of the result is then consistent.
	
	DKStyle*		styl = [[DKStyle alloc] init];
	DKFill*			fill;
	NSColor*		fc = [[self textAttributes] objectForKey:NSForegroundColorAttributeName];
	
	if ( fc )
		fill = [DKFill fillWithColour:fc];
	else
		fill = [DKFill fillWithColour:[NSColor blackColor]];
		
	NSShadow*		shad = [[[self textAttributes] objectForKey:NSShadowAttributeName] copy];

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
	
	CGFloat sw = [[[self textAttributes] objectForKey:NSStrokeWidthAttributeName] doubleValue];
	
	if ( sw > 0.0 )
	{
		DKStroke*	stroke = [DKStroke strokeWithWidth:sw colour:[[self textAttributes] objectForKey:NSStrokeColorAttributeName]];
		[styl addRenderer:stroke];
	}

	return [styl autorelease];
}


@end
