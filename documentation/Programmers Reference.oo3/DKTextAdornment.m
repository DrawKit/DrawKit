///**********************************************************************************************************************************
///  DKTextAdornment.m
///  DrawKit
///
///  Created by graham on 18/05/2007.
///  Released under the Creative Commons license 2007 Apptree.net.
///
/// 
///  This work is licensed under the Creative Commons Attribution-ShareAlike 2.5 License.
///  To view a copy of this license, visit http://creativecommons.org/licenses/by-sa/2.5/ or send a letter to
///  Creative Commons, 543 Howard Street, 5th Floor, San Francisco, California, 94105, USA.
///
///**********************************************************************************************************************************

#import "DKTextAdornment.h"
#import "DKDrawableObject+Metadata.h"
#import "DKObjectOwnerLayer.h"
#import "LogEvent.h"
#import "NSBezierPath+Geometry.h"
#import "DKDrawableShape.h"
#import "NSObject+StringValue.h"
#import "DKBezierTextContainer.h"
#import "DKShapeGroup.h"

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
		[sharedLM setHyphenationFactor:0.5];
    }
    return sharedLM;
}


static NSLayoutManager* sharedLayoutManagerForFlowedText()
{
    static NSLayoutManager *sharedLM = nil;
    
	if ( sharedLM == nil )
	{
        NSTextContainer*	tc = [[DKBezierTextContainer alloc] initWithContainerSize:NSMakeSize(1.0e6, 1.0e6)];
		NSTextView*			tv = [[NSTextView alloc] initWithFrame:NSZeroRect];
        
        sharedLM = [[NSLayoutManager alloc] init];
		
		[tc setTextView:tv];
		[tv release];
		
        [tc setWidthTracksTextView:NO];
        [tc setHeightTracksTextView:NO];
        [sharedLM addTextContainer:tc];
        [tc release];
		
		[sharedLM setUsesScreenFonts:NO];
		[sharedLM setHyphenationFactor:0.5];
    }
    return sharedLM;
}


#pragma mark -
@implementation DKTextAdornment
#pragma mark As a DKTextAdornment

+ (DKTextAdornment*)		textAdornmentWithText:(id) anySortOfText;
{
	DKTextAdornment* dkt = [[self alloc] init];
	
	[dkt setLabel:anySortOfText];
	return [dkt autorelease];
}


+ (NSDictionary*)			defaultTextAttributes
{
	static NSMutableDictionary* dta = nil;
	
	if ( dta == nil )
	{
		dta = [[NSMutableDictionary alloc] init];
		
		NSFont* font = [NSFont fontWithName:@"Helvetica" size:18];
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



- (NSString*)				string
{
	return m_labelText;
}


- (void)					setLabel:(id) anySortOfText
{
	// allows any sort (NSString, NSAttributedString) of string/text to be passed to set the label. If the text passed has
	// attributes, they are used for the rasterizer's text attributes (which are applied to all of the text)
	
	//NSLog(@"any text = %@", anySortOfText);
	
	if([anySortOfText isKindOfClass:[NSAttributedString class]])
	{
		// set the text attributes to the attributes of the string, if its length > 0
		
		if([anySortOfText length] > 0 )
		{
			NSDictionary*	attributes = [anySortOfText attributesAtIndex:0 effectiveRange:NULL];
			
			if( attributes != nil )
				[self setTextAttributes:attributes];
		}
		
		[m_labelText release];
		m_labelText = [[anySortOfText string] copy];
	}
	else if([anySortOfText isKindOfClass:[NSString class]])
	{
		[m_labelText release];
		m_labelText = [anySortOfText copy];
	}
	else
	{
		[m_labelText release];
		m_labelText = nil;
	}
}


- (NSAttributedString*)		label
{
	NSAttributedString* str = [[NSAttributedString alloc] initWithString:m_labelText attributes:[self textAttributes]];
	return [str autorelease];
}


#pragma mark -
- (void)					setIdentifier:(NSString*) ident
{
	[ident retain];
	[m_identifier release];
	m_identifier = ident;
}


- (NSString*)				identifier
{
	return m_identifier;
}


#pragma mark -
- (void)					setVerticalAlignment:(DKVerticalTextAlignment) align
{
	m_vertAlign = align;
}


- (DKVerticalTextAlignment)	verticalAlignment
{
	return m_vertAlign;
}


#pragma mark -
- (void)					setLayoutMode:(DKTextLayoutMode) mode
{
	m_layoutMode = mode;
}


- (DKTextLayoutMode)		layoutMode
{
	return m_layoutMode;
}


- (void)					setFlowedTextPathInset:(float) inset
{
	mFlowedTextPathInset = inset;
}


- (float)					flowedTextPathInset
{
	return mFlowedTextPathInset;
}



#pragma mark -
- (void)					setAngle:(float) angle
{
	m_angle = angle;
}


- (float)					angle
{
	return m_angle;
}


- (void)					setAngleInDegrees:(float) degrees
{
	[self setAngle:(degrees * pi)/180.0f];
}


- (float)					angleInDegrees
{
	return fmodf(([self angle] * 180.0f )/ pi, 360.0 );
}


#pragma mark -
- (void)					setAppliesObjectAngle:(BOOL) aa
{
	m_applyObjectAngle = aa;
}


- (BOOL)					appliesObjectAngle
{
	return m_applyObjectAngle;
}


#pragma mark -
- (void)					setWrapsLines:(BOOL) wraps
{
	m_wrapLines = wraps;
}


- (BOOL)					wrapsLines
{
	return m_wrapLines;
}


#pragma mark -
- (void)					setClipsToPath:(BOOL) ctp
{
	m_clipToPath = ctp;
}


- (BOOL)					clipsToPath
{
	return m_clipToPath;
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
- (void)				changeTextAttribute:(NSString*) attribute toValue:(id) val
{
	NSAssert( attribute != nil, @"text attribute name was nil");
	NSAssert([attribute length] > 0, @"text attribute name was empty");
	
	NSMutableDictionary*	attr = [[self textAttributes] mutableCopy];
	
	if ( attr == nil )
		attr = [[NSMutableDictionary alloc] init];
	
	if ( val == nil )
		[attr removeObjectForKey:attribute];
	else
		[attr setObject:val forKey:attribute];
	
	[self setTextAttributes:attr];
	[attr release];
}


#pragma mark -
- (void)					setFont:(NSFont*) font
{
	NSAssert( font != nil, @"font was nil");
	
	[self changeTextAttribute:NSFontAttributeName toValue:font];
}


- (NSFont*)					font
{
	return [[self textAttributes] objectForKey:NSFontAttributeName];
}


- (void)					setColour:(NSColor*) colour
{
	NSAssert( colour != nil, @"colour was nil");
	
	[self changeTextAttribute:NSForegroundColorAttributeName toValue:colour];
}


- (NSColor*)				colour
{
	return [[self textAttributes] objectForKey:NSForegroundColorAttributeName];
}



- (void)					setTextAttributes:(NSDictionary*) attrs
{
	[attrs retain];
	[m_textAttributes release];
	m_textAttributes = attrs;
}


- (NSDictionary*)			textAttributes
{
	return m_textAttributes;
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


#pragma mark -

- (NSTextStorage*)			textToDraw:(id) object
{
	// text to draw consists of the label concatentated with any metadata converted to string form.
	
	NSMutableString*	ttd = [NSMutableString string];
	NSTextStorage*		str;
	
	// if we have fixed text, use it
	
	if([self string] != nil && [[self string] length] > 0 )
		[ttd appendString:[self string]];
	
	// try looking up the text from the object's metadata
	
	if ([self identifier] != nil && [[self identifier] length] > 0 )
	{
		id meta = nil;
		
		@try
		{
			meta = [object metadataObjectForKey:[self identifier]];
		}
		@catch(NSException* ex)
		{
			LogEvent_( kReactiveEvent, @"exception raised when trying to get metadata value for '%@' (ignored)", [self identifier]);
			meta = nil;
		}
		
		if ( meta != nil )
		{
			if ([meta isKindOfClass:[NSString class]])
				[ttd appendString:meta];
			else if ([meta respondsToSelector:@selector(stringValue)])
				[ttd appendString:[meta stringValue]];
			else if ([meta respondsToSelector:@selector(string)])
				[ttd appendString:[meta string]];
				
			//NSLog(@"appended meta = %@, string = %@", meta, ttd);
		}
	}	
	
	// if still no text, bail
		
	if ([ttd length] == 0 )
		return nil;

	// initialise text storage from the string 'ttd' but using the current attributes
		
	str = [[NSTextStorage alloc] initWithString:ttd attributes:[self textAttributes]];
	
	return [str autorelease];
}


- (NSAffineTransform*)		textTransformForObject:(DKDrawableObject*) obj
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

	[xform appendTransform:[[obj container] renderingTransform]];

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
	
	if([self layoutMode] != kGCTextLayoutFlowedInPath)
	{
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
		}
	}
	return textOrigin;

}


#define qShowLineFragRects	0
#define qShowGlyphLocations	0

- (void)					drawText:(NSTextStorage*) contents withObject:(DKDrawableObject*) obj withPath:(NSBezierPath*) path
{
	if ([contents length] > 0)
	{
		NSLayoutManager *lm;
		NSTextContainer *tc;
		NSSize			osize = [obj size];
		
		if([self layoutMode] == kGCTextLayoutFlowedInPath)
		{
			lm = sharedLayoutManagerForFlowedText();
			DKBezierTextContainer* bc = [[lm textContainers] objectAtIndex:0];

			// if the text angle is rel to the object, the layout path should be the unrotated path
			// so the the text is laid out unrotated, then transformed into place. So detect that case here
			// and compensate the path for the angle.
			
			NSBezierPath* textLayoutPath = path;

			if([self flowedTextPathInset] != 0.0 )
			{
				[bc setLineFragmentPadding:[self flowedTextPathInset]];
				
			}
				//textLayoutPath = [path insetPathBy:[self flowedTextPathInset]];

			if([self appliesObjectAngle] || [[obj container] isKindOfClass:[DKShapeGroup class]])
			{
				NSAffineTransform* tfm = [self textTransformForObject:obj];
				[tfm invert];
			
				textLayoutPath = [tfm transformBezierPath:textLayoutPath]; 
			}
			osize = [textLayoutPath bounds].size;
			[bc setBezierPath:textLayoutPath];
			[bc setContainerSize:osize];
			tc = bc;
		}
		else
		{
			lm = sharedDrawingLayoutManager();
			tc = [[lm textContainers] objectAtIndex:0];
			[tc setContainerSize:osize];
		}
		
		NSRange		glyphRange;
		NSRange		grange;
		NSRect		frag;

		[contents addLayoutManager:lm];

		// Force layout of the text and find out how much of it fits in the container.
		
		glyphRange = [lm glyphRangeForTextContainer:tc];

		// because of the object transform applied, draw the text at the origin
		
		if (glyphRange.length > 0)
		{
			NSSize textSize = [lm usedRectForTextContainer:tc].size;
			
			// if not wrapping lines, draw only the first line
			
			if(! [self wrapsLines])
			{
				frag = [lm lineFragmentUsedRectForGlyphAtIndex:0 effectiveRange:&grange];
				textSize.height = frag.size.height;
			}
			else
				grange = glyphRange;
			
			NSPoint textOrigin = [self textOriginForSize:textSize objectSize:osize];
			
			if ([self layoutMode] == kGCTextLayoutFlowedInPath && [self flowedTextPathInset] != 0.0 )
				textOrigin.y += [self flowedTextPathInset] * 0.5;
			
			[lm drawGlyphsForGlyphRange:grange atPoint:textOrigin];
		
		#if qShowLineFragRects
		
			int			glyphIndex = 0;
			
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
		[contents removeLayoutManager:lm];
	}
}


- (float)					baselineOffset
{
	float dy = 0;
	
	switch ([self verticalAlignment])
	{
		case kGCTextShapeVerticalAlignmentTop:
			dy = 8;
			break;
			
		case kGCTextShapeVerticalAlignmentBottom:
			dy = -8;
			break;
			
		default:
			break;
	}
	
	return dy;
}


#pragma mark -
#pragma mark As a DKRasterizer

- (BOOL)					isValid
{
	return YES;
}


- (NSString*)				styleScript
{
	NSMutableString* s = [[NSMutableString alloc] init];
	
	[s setString:@"(text"];
	[s appendString:[NSString stringWithFormat:@" label:'%@'", [self string]]];
	[s appendString:@")"];
	return [s autorelease];
}


- (NSSize)					extraSpaceNeeded
{
	if(([self layoutMode] != kGCTextLayoutInBoundingRect) && [self enabled])
	{
		// add in the current lineheight to both width and height. As we are only interested in the lineheight, we just use
		// some dummy text in conjunction with our current attributes
		
		int opts = NSStringDrawingUsesFontLeading | NSStringDrawingDisableScreenFontSubstitution | NSStringDrawingUsesDeviceMetrics | NSStringDrawingOneShot;
		
		NSSize	textBoxSize = NSMakeSize(1000,200);
		
		NSRect	tbr = [@"Dummy Text" boundingRectWithSize:textBoxSize options:opts attributes:[self textAttributes]];
		
		// factor in the baseline offset
		
		float extra = tbr.size.height + ABS([self baselineOffset]);
		
		return NSMakeSize( extra, extra );
	}
	else
		return NSZeroSize;
}


- (void)					render:(id) object
{
	if(![self enabled])
		return;
	
	NSTextStorage*	str = [self textToDraw:object];
	
	// if no text, nothing to do
	
	if ( str == nil )
		return;
	
	// draw it according to settings with the object's path bounds
	
	[NSGraphicsContext saveGraphicsState];
	NSBezierPath*	path = [self renderingPathForObject:object];
	
	if ( [self layoutMode] == kGCTextLayoutAlongReversedPath )
		path = [path bezierPathByReversingPath];
	
	if([self layoutMode] == kGCTextLayoutAlongReversedPath ||
		[self layoutMode] == kGCTextLayoutAlongPath )
	{
		[path drawTextOnPath:str yOffset:[self baselineOffset]];
	}
	else
	{
		if([self clipsToPath])
			[path addClip];

		NSAffineTransform* tfm = [self textTransformForObject:object];
		[tfm concat];
		
		// draw the text
		
		[self drawText:str withObject:object withPath:path];
	}
	[NSGraphicsContext restoreGraphicsState];
}


#pragma mark -
#pragma mark As a GCObservableObject
+ (NSArray*)		observableKeyPaths
{
	return [[super observableKeyPaths] arrayByAddingObjectsFromArray:[NSArray arrayWithObjects:@"label", @"identifier", @"angle", @"wrapsLines", @"clipsToPath",
				@"appliesObjectAngle", @"verticalAlignment", @"textAttributes",
				@"paragraphStyle", @"layoutMode", @"flowedTextPathInset", nil]];
}


- (void)					registerActionNames
{
	[super registerActionNames];
	[self setActionName:@"#kind# Label" forKeyPath:@"label"];
	[self setActionName:@"#kind# Identifier" forKeyPath:@"identifier"];
	[self setActionName:@"#kind# Font" forKeyPath:@"font"];
	[self setActionName:@"#kind# Text Attributes" forKeyPath:@"textAttributes"];
	[self setActionName:@"#kind# Paragraph Style" forKeyPath:@"paragraphStyle"];
	[self setActionName:@"#kind# Vertical Alignment" forKeyPath:@"verticalAlignment"];
	[self setActionName:@"#kind# Text Angle" forKeyPath:@"angle"];
	[self setActionName:@"#kind# Line Wrap" forKeyPath:@"wrapsLines"];
	[self setActionName:@"#kind# Text Layout" forKeyPath:@"layoutMode"];
	[self setActionName:@"#kind# Clips To Path" forKeyPath:@"clipsToPath"];
	[self setActionName:@"#kind# Tracks Object Angle" forKeyPath:@"appliesObjectAngle"];
	[self setActionName:@"#kind# Text Inset" forKeyPath:@"flowedTextPathInset"];
}


#pragma mark -
#pragma mark As an NSObject
- (void)					dealloc
{
	[m_labelText release];
	[m_identifier release];
	[m_textAttributes release];
	
	[super dealloc];
}


- (id)						init
{
	self = [super init];
	if (self != nil)
	{
		NSAssert(m_identifier == nil, @"Expected init to zero");
		NSAssert(m_labelText == nil, @"Expected init to zero");
		NSAssert(NSEqualRects(m_textRect, NSZeroRect), @"Expected init to zero");
		
		NSAssert(m_angle == 0.0, @"Expected init to zero");
		
		m_layoutMode = kGCTextLayoutFlowedInPath;//kGCTextLayoutInBoundingRect;
		m_vertAlign = kGCTextShapeVerticalAlignmentCentre;
		m_wrapLines = YES;
		m_clipToPath = NO;
		m_applyObjectAngle = YES;
		
		[self setFlowedTextPathInset:3];
	}
	if (self != nil)
	{
		[self setLabel:@"Label"];
		[self setIdentifier:@""];
		[self setTextAttributes:[[self class] defaultTextAttributes]];
	}
	return self;
}


#pragma mark -
#pragma mark As part of NSCoding Protocol
- (void)					encodeWithCoder:(NSCoder*) coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	[super encodeWithCoder:coder];
	
	[coder encodeObject:[self identifier] forKey:@"identifier"];
	[coder encodeObject:[self string] forKey:@"text"];
	[coder encodeObject:[self textAttributes] forKey:@"DKTextAdornment_textAttributes"];
	
	[coder encodeFloat:[self angle] forKey:@"angle"];
	[coder encodeInt:[self verticalAlignment] forKey:@"valign"];
	[coder encodeInt:[self layoutMode] forKey:@"layout_mode"];
	[coder encodeBool:[self wrapsLines] forKey:@"wraps"];
	[coder encodeBool:[self clipsToPath] forKey:@"clips"];
	[coder encodeBool:[self appliesObjectAngle] forKey:@"objangle"];
	[coder encodeFloat:[self flowedTextPathInset] forKey:@"DKTextAdornment_flowedTextInset"];
}


- (id)						initWithCoder:(NSCoder*) coder
{
	NSAssert(coder != nil, @"Expected valid coder");
	self = [super initWithCoder:coder];
	if (self != nil)
	{
		[self setIdentifier:[coder decodeObjectForKey:@"identifier"]];
		
		// reading the label may read an attributed string which will set the text attributes for all text
		
		[self setLabel:[coder decodeObjectForKey:@"text"]];
		
		// read text attributes separately for newer implementation
		
		if([coder containsValueForKey:@"DKTextAdornment_textAttributes"])
			[self setTextAttributes:[coder decodeObjectForKey:@"DKTextAdornment_textAttributes"]];
		else
		{
			// older format may not have saved any attributes - if not, use default
			
			if([self textAttributes] == nil )
				[self setTextAttributes:[[self class] defaultTextAttributes]];
		}
		
		[self setAngle:[coder decodeFloatForKey:@"angle"]];
		[self setVerticalAlignment:[coder decodeIntForKey:@"valign"]];
		[self setLayoutMode:[coder decodeIntForKey:@"layout_mode"]];
		[self setWrapsLines:[coder decodeBoolForKey:@"wraps"]];
		[self setClipsToPath:[coder decodeBoolForKey:@"clips"]];
		[self setAppliesObjectAngle:[coder decodeBoolForKey:@"objangle"]];
		[self setFlowedTextPathInset:[coder decodeFloatForKey:@"DKTextAdornment_flowedTextInset"]];
	}
	return self;
}


#pragma mark -
#pragma mark As part of NSCopying Protocol
- (id)						copyWithZone:(NSZone*) zone
{
	DKTextAdornment* copy = [super copyWithZone:zone];
	
	NSString* label = [[self string] copyWithZone:zone];
	[copy setLabel:label];
	[label release];
	
	NSString* ident = [[self identifier] copyWithZone:zone];
	[copy setIdentifier:ident];
	[ident release];
	
	[copy setTextAttributes:[self textAttributes]];
	
	[copy setVerticalAlignment:[self verticalAlignment]];
	[copy setAngle:[self angle]];
	[copy setAppliesObjectAngle:[self appliesObjectAngle]];
	[copy setWrapsLines:[self wrapsLines]];
	[copy setClipsToPath:[self clipsToPath]];
	[copy setLayoutMode:[self layoutMode]];
	[copy setFlowedTextPathInset:[self flowedTextPathInset]];
	
	return copy;
}


@end
