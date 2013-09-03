//
//  DKTextPath.m
//  GCDrawKit
//
//  Created by graham on 25/11/2008.
//  Copyright 2008 Apptree.net. All rights reserved.
//

#import "DKTextPath.h"
#import "DKTextShape.h"
#import "DKDrawingView.h"
#import "LogEvent.h"
#import "DKTextAdornment.h"
#import "DKFill.h"
#import "DKStyle.h"
#import "DKStroke.h"
#import "DKShapeGroup.h"
#import "DKObjectDrawingLayer.h"
#import "DKDrawableObject+Metadata.h"
#import "NSBezierPath+Geometry.h"
#import "DKKnob.h"

#pragma mark Static Vars
static NSString*	sDefault_string = @"Double-click to edit this text";

@interface DKTextPath (Private)

- (DKTextAdornment*)	makeTextAdornment;
- (void)				changeKeyPath:(NSString*) keypath ofObject:(id) object toValue:(id) value;
- (void)				mutateStyle;
- (void)				updateFontPanel;

@end


@implementation DKTextPath


+ (DKTextPath*)				textPathWithString:(NSString*) str onPath:(NSBezierPath*) aPath
{
	DKTextPath*  te = [[DKTextPath alloc] initWithBezierPath:aPath style:[self textPathDefaultStyle]];
	
	[te setText:str];
	
	return [te autorelease];
}



+ (void)					setDefaultTextString:(NSString*) str
{
	[str retain];
	[sDefault_string release];
	sDefault_string = str;
}



+ (NSString*)				defaultTextString
{
	return sDefault_string;
}



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


+ (DKStyle*)				textPathDefaultStyle
{
	return [DKStyle styleWithFillColour:nil strokeColour:[NSColor clearColor]];
}


#pragma mark -

- (void)					setText:(id) newText
{
	if(![self locked])
	{
		[mTextAdornment setLabel:newText];
		[self updateFontPanel];
	}
}



- (NSTextStorage*)			text
{
	return [mTextAdornment textToDraw:self];
}



- (NSString*)				string
{
	return [[self text] string];
}



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
			[self setText:str];
		
		[str release];
	}
}



- (BOOL)					canPasteText:(NSPasteboard*) pb
{
	return ([pb availableTypeFromArray:[[self class] pastableTextTypes]] != nil );
}



- (NSBezierPath*)			textPath
{
	return [mTextAdornment textAsPathForObject:self];
}



- (NSArray*)				textPathGlyphs
{
	return [self textPathGlyphsUsedSize:NULL];
}



- (NSArray*)				textPathGlyphsUsedSize:(NSSize*) textSize
{
	return [mTextAdornment textPathsForObject:self usedSize:textSize];
}


- (DKDrawablePath*)			makePathWithText
{
	// creates a path object having the current text as its path.
	
	Class pathClass = [DKDrawableObject classForConversionRequestFor:[DKDrawablePath class]];
	DKDrawablePath* dp = [pathClass drawablePathWithBezierPath:[self textPath]];

	[dp setStyle:[self styleWithTextAttributes]];
	
	// keep a note of the original text in the meta-data, in case anyone wants to know - allows
	// the text of a shape to be "read" by code if necessary (e.g. by a find)
	
	[dp setUserInfo:[self userInfo]];
	[dp setOriginalText:[self text]];
	
	return dp;
}



- (DKDrawableShape*)		makeShapeWithText
{
	// creates a shape object that uses the current text converted to a path as its path. The result can't be edited as text but
	// it can be scaled instead of word-wrapped.
	
	Class shapeClass = [DKDrawableObject classForConversionRequestFor:[DKDrawableShape class]];
	DKDrawableShape* ds = [shapeClass drawableShapeWithBezierPath:[self textPath] rotatedToAngle:[self angle]];
	
	[ds setStyle:[self styleWithTextAttributes]];
	
	// keep a note of the original text in the meta-data, in case anyone wants to know - allows
	// the text of a shape to be "read" by code if necessary (e.g. by a find)
	
	[ds setUserInfo:[self userInfo]];
	[ds setOriginalText:[self text]];
	
	return ds;
}



- (DKShapeGroup*)			makeShapeGroupWithText
{
	NSArray*	paths = [self textPathGlyphs];
	Class groupClass = [DKDrawableObject classForConversionRequestFor:[DKShapeGroup class]];
	DKShapeGroup* group = [groupClass groupWithBezierPaths:paths objectType:kDKCreateGroupWithShapes style:[self styleWithTextAttributes]];
	
	// keep a note of the original text in the meta-data, in case anyone wants to know - allows
	// the text of a shape to be "read" by code if necessary (e.g. by a find)
	
	[group setUserInfo:[self userInfo]];
	[group setOriginalText:[self text]];
	
	return group;
}



- (DKStyle*)				styleWithTextAttributes
{
	return [[self textAdornment] styleFromTextAttributes];
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




- (NSDictionary*)			textAttributes
{
	return [mTextAdornment textAttributes];
}



- (void)					setFont:(NSFont*) font
{
	if ( ![self locked])
	{
		[mTextAdornment setFont:font];
		[self updateFontPanel];
	}
}



- (NSFont*)					font
{
	return [mTextAdornment font];	
}



- (void)					setFontSize:(CGFloat) size
{
	if( ![self locked])
	{
		[mTextAdornment setFontSize:size];
		[self updateFontPanel];
	}
}



- (CGFloat)					fontSize
{
	return [mTextAdornment fontSize];
}


- (void)					scaleTextBy:(CGFloat) factor
{
	// permanently adjusts the text's font size by multiplying it by <factor>. A value of 1.0 has no effect.
	
	if( ![self locked])
	{
		[mTextAdornment scaleTextBy:factor];
		[self updateFontPanel];
	}
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
	{
		[mTextAdornment setParagraphStyle:ps];
		//[self mutateStyle];
	}
}



- (NSParagraphStyle*)		paragraphStyle
{
	return [mTextAdornment paragraphStyle];
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



- (void)					startEditingInView:(DKDrawingView*) view
{
	if ( mEditorRef == nil )
	{
		NSRect	br = [[self path] bounds];
		
		LogEvent_(kReactiveEvent, @"starting edit of text shape, bounds = %@", NSStringFromRect( br ));
		
		// make sure the bounds is reasonable. A purely horizontal or vertical straight path will have an empty bounds rect
		
		if( NSIsEmptyRect( br ))
		{
			if( NSHeight( br ) > NSWidth( br ))
			{
				br.size.width = MAX( 100.0, NSHeight( br ));
				br.origin.x -= NSWidth( br ) * 0.5; 
			}
			else
			{
				br.size.width = 100.0;
				br.size.height = MAX([self fontSize] * 1.5, NSHeight( br ));
			}
		}
		else
		{
			if( NSWidth( br ) < 100.0 )
			{
				br.size.width = 100.0;
				br.origin.x = NSMidX( br ) - 50.0;
			}
			
			if( NSHeight( br ) < [self fontSize])
				br.size.height = [self fontSize];
		}

		
		mEditorRef = [view editText:[[self textAdornment] textForEditing] inRect:br delegate:self];
		
		[[mEditorRef textContainer] setWidthTracksTextView:NO];
		[[mEditorRef textContainer] setContainerSize:NSMakeSize( NSWidth(br), 10000.0)];
		[mEditorRef setHorizontallyResizable:NO];
		
		[[mEditorRef textContainer] setHeightTracksTextView:NO];
		[mEditorRef setVerticallyResizable:YES];
		[mEditorRef setTypingAttributes:[self textAttributes]];
		[mEditorRef setImportsGraphics:NO];
	}
}



- (void)					endEditing
{
	if ( mEditorRef )
	{
		[self setText:[mEditorRef textStorage]];

		DKDrawingView* parent = (DKDrawingView*)[mEditorRef superview];
		[parent endTextEditing];
		[self notifyVisualChange];
		mEditorRef = nil;
	}
}


- (BOOL)					isEditing
{
	return ( mEditorRef != nil);
}



- (DKTextAdornment*)		textAdornment
{
	return mTextAdornment;	
}



#pragma mark -

- (IBAction)				changeFont:(id) sender
{
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



- (IBAction)				alignLeft:(id) sender
{
#pragma unused(sender)
	
	// apply the align left attribute to the text's paragraph style
	
	if ( ![self locked])
		[mTextAdornment setAlignment:NSLeftTextAlignment];
}



- (IBAction)				alignRight:(id) sender
{
#pragma unused(sender)
	
	if ( ![self locked])
		[mTextAdornment setAlignment:NSRightTextAlignment];
}



- (IBAction)				alignCenter:(id) sender
{
#pragma unused(sender)
	
	if ( ![self locked])
		[mTextAdornment setAlignment:NSCenterTextAlignment];
}



- (IBAction)				alignJustified:(id) sender
{
#pragma unused(sender)
	
	if ( ![self locked])
		[mTextAdornment setAlignment:NSJustifiedTextAlignment];
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



- (IBAction)				useStandardKerning:(id) sender
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


- (IBAction)				convertToTextShape:(id) sender
{
#pragma unused(sender)
	// to do
}


- (IBAction)				convertToPath:(id) sender
{
#pragma unused(sender)

	// converts the text shape to a plain shape using the text as its path
	
	DKObjectDrawingLayer*	layer = (DKObjectDrawingLayer*)[self layer];
	NSInteger				myIndex = [layer indexOfObject:self];
	
	DKDrawablePath*		so = [self makePathWithText];
	
	if( so )
	{
		[layer recordSelectionForUndo];
		[layer addObject:so atIndex:myIndex];
		[layer replaceSelectionWithObject:so];
		[self retain];
		[layer removeObject:self];
		[layer commitSelectionUndoWithActionName:NSLocalizedString(@"Convert To Path", @"undo string for convert text to path")];
		[self release];
	}
	else
		NSBeep();
}



- (IBAction)				paste:(id) sender
{
#pragma unused(sender)
	
	if ( ![self locked] && [self canPasteText:[NSPasteboard generalPasteboard]])
	{
		[self pasteTextFromPasteboard:[NSPasteboard generalPasteboard] ignoreFormatting:NO];
		[[self undoManager] setActionName:NSLocalizedString(@"Paste Text", @"undo string for paste text into text path")];
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
		
		[[self textAdornment] setAlignment:clickedSegmentTag];
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
	
	// inital layout mode is set to along path, justified
	
	[adorn setLayoutMode:kDKTextLayoutAlongPath];
	[adorn setAlignment:NSJustifiedTextAlignment];
	
	return [adorn autorelease];
}



- (void)				setTextAdornment:(DKTextAdornment*) adornment
{
	if( adornment != mTextAdornment )
	{
		if( mTextAdornment )
		{
			[mTextAdornment tearDownKVOForObserver:self];
			[mTextAdornment release];
			mTextAdornment = nil;
		}
		
		if( adornment )
		{
			mTextAdornment = [adornment retain];
			// debug - test greeking
			//[mTextAdornment setGreeking:kDKGreekingByGlyphRectangle];
			[mTextAdornment setUpKVOForObserver:self];
		}
	}
}


- (void)				changeKeyPath:(NSString*) keypath ofObject:(id) object toValue:(id) value
{
	if([value isEqual:[NSNull null]])
		value = nil;
	
	[object setValue:value forKeyPath:keypath];
}



- (void)				mutateStyle
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
	}
}


- (void)					updateFontPanel
{
	[[NSFontManager sharedFontManager] setSelectedFont:[self font] isMultiple:![[self textAdornment] attributeIsHomogeneous:NSFontAttributeName]];
	[[NSFontManager sharedFontManager] setSelectedAttributes:[self textAttributes] isMultiple:![[self textAdornment] isHomogeneous]];
}


#pragma mark -
#pragma mark - as a DKDrawablePath

- (void)					drawContent
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


- (void)					drawSelectedState
{
	if(![[self textAdornment] allTextWasFitted] && [DKTextShape showsTextOverflowIndicator])
	{
		// if text is overflowing, show the "more text" symbol. This is placed just above the path's right-hand end
		
		DKKnob* knob = [[self layer] knobs];
		NSSize knobSize = [knob controlKnobSize];
		
		knobSize.width *= 1.6;
		knobSize.height *= 1.6;

		NSBezierPath* moreText = [[DKTextShape textOverflowIndicatorPath] copy];
		
		// transform the path to the correct place, size and angle
		
		NSPoint endPoint;
		CGFloat	slope;
		
		endPoint = [[self path] pointOnPathAtLength:[self length] - knobSize.width slope:&slope];
		
		NSAffineTransform* transform = [NSAffineTransform transform];
		[transform translateXBy:endPoint.x yBy:endPoint.y];
		[transform rotateByRadians:slope];
		[transform scaleXBy:knobSize.width yBy:-knobSize.height];
		[moreText transformUsingAffineTransform:transform];
		
		if([self locked])
			[[NSColor lightGrayColor] set];
		else
			[[[self layer] selectionColour] set];
		[moreText fill];
		[moreText release];
	}
	
	[super drawSelectedState];
}


- (NSSize)					extraSpaceNeeded
{
	NSSize extra = [super extraSpaceNeeded];
	NSSize taExtra = [mTextAdornment extraSpaceNeeded];
	
	extra.width += taExtra.width;
	extra.height += taExtra.height;
	
	return extra;
}


- (void)					mouseDoubleClickedAtPoint:(NSPoint) mp inPart:(NSInteger) partcode event:(NSEvent*) evt
{
	[super mouseDoubleClickedAtPoint:mp inPart:partcode event:evt];
	
	if ( ![self locked])
		[self startEditingInView:(DKDrawingView*)[[self layer] currentView]];
}


- (void)					setStyle:(DKStyle*) aStyle
{
	if ( aStyle != [self style])
	{
		[super setStyle:aStyle];
		
		// set initial text attributes from style if it has them
		
		if([[self style] hasTextAttributes])
		{
			mIsSettingStyle = YES;
			[mTextAdornment setTextAttributes:[[self style] textAttributes]];
			mIsSettingStyle = NO;
		}
		
		[self notifyVisualChange];
	}
}


#define INCLUDE_ALIGNMENT_COMMANDS		0

- (BOOL)					populateContextualMenu:(NSMenu*) theMenu
{
	// if the object supports any contextual menu commands, it should add them to the menu and return YES. If subclassing,
	// you should call the inherited method first so that the menu is the union of all the ancestor's added methods.
	
	NSMenuItem* item;
	
	[[theMenu addItemWithTitle:NSLocalizedString(@"Edit Text", @"menu item for edit text") action:@selector( editText: ) keyEquivalent:@""] setTarget:self];
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
	
	[[convert addItemWithTitle:NSLocalizedString(@"Path", @"submenu item for convert to path") action:@selector(convertToPath:) keyEquivalent:@""] setTarget:self];
	[[convert addItemWithTitle:NSLocalizedString(@"Shape Group", @"menu item for convert to shape group") action:@selector(convertToShapeGroup:) keyEquivalent:@""] setTarget:self];
	item = [theMenu addItemWithTitle:NSLocalizedString(@"Convert To", @"menu item for convert submenu") action:nil keyEquivalent:@""];
	
	[item setSubmenu:convert];
	[convert release];	
	[item setTag:kDKConvertToSubmenuTag];
	
	[super populateContextualMenu:theMenu];
	return YES;
}


#pragma mark -
#pragma mark - as a DKDrawableObject


- (id)						initWithStyle:(DKStyle*) aStyle
{
	self = [super initWithStyle:aStyle];
	if (self != nil)
	{
		[self setTextAdornment:[self makeTextAdornment]];
		[self setText:[[self class] defaultTextString]];
	}
	
	return self;
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



- (void)					objectDidBecomeSelected
{
	[super objectDidBecomeSelected];
	[self updateFontPanel];
}


- (void)					objectIsNoLongerSelected
{
	[super objectIsNoLongerSelected];
	[self endEditing];
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
	if( [pb addTypes:[NSArray arrayWithObjects:NSRTFPboardType, NSStringPboardType, nil] owner:self])
	{
		NSRange range = NSMakeRange( 0, [[self text] length]);
		NSData* rtfData = [[self text] RTFFromRange:range documentAttributes:nil];
		
		[pb setData:rtfData forType:NSRTFPboardType];
		[pb setString:[self string] forType:NSStringPboardType];
	}
}


#pragma mark -
#pragma mark - as a NSObject


- (id)						init
{
	return [self initWithStyle:[[self class] textPathDefaultStyle]];
}


- (void)			dealloc
{
	[self endEditing];
	[self setTextAdornment:nil];
	[super dealloc];
}



- (void)			observeValueForKeyPath:(NSString*) keypath ofObject:(id) object change:(NSDictionary*) change context:(void*) context
{
#pragma unused(context)
	
	// this is called whenever a property of a renderer contained in the style is changed. Its job is to consolidate both undo
	// and client object refresh when properties are altered directly, which of course they usually will be. This powerfully
	// means that renderers themselves do not need to know anything about undo or how they fit into the overall scheme of things.
	
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

#pragma mark -
#pragma mark As part of NSCoding Protocol
- (void)					encodeWithCoder:(NSCoder*) coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	[super encodeWithCoder:coder];
	
	[coder encodeObject:mTextAdornment forKey:@"DKTextPath_textAdornment"];
}


- (id)						initWithCoder:(NSCoder*) coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	self = [super initWithCoder:coder];
	if (self != nil)
	{
		[self setTextAdornment:[coder decodeObjectForKey:@"DKTextPath_textAdornment"]];
	}
	
	return self;
}


#pragma mark -
#pragma mark As part of NSCopying Protocol

- (id)						copyWithZone:(NSZone*) zone
{
	DKTextPath* copy = [super copyWithZone:zone];
	
	DKTextAdornment* ta = [[self textAdornment] copyWithZone:zone];
	[copy setTextAdornment:ta];
	[ta release];
	
	return copy;
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
	   action == @selector( convertToShapeGroup: )	||
	   action == @selector( convertToShape: ) ||
	   action == @selector( convertToTextShape: ) ||
	   action == @selector( convertToPath: ) ||
	   action == @selector( editText: ))
		return ![self locked];
	
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


- (BOOL)					textView:(NSTextView*) tv doCommandBySelector:(SEL) selector
{
	// this allows the texview to act as a special field editor. Return + Enter complete text editing, but Tab does not. Also, for convenience to
	// Windows switchers, Shift+Return/Shift+Enter insert new lines.
	
	if( tv == mEditorRef )
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


@end
