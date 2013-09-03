///**********************************************************************************************************************************
///  DKArcPath.m
///  DrawKit ©2005-2008 Apptree.net
///
///  Created by graham on 25/06/2008.
///
///	 This software is released subject to licensing conditions as detailed in DRAWKIT-LICENSING.TXT, which must accompany this source file. 
///
///**********************************************************************************************************************************


#import "DKArcPath.h"
#import "DKDrawableShape.h"
#import "DKDrawing.h"
#import "DKStyle.h"
#import "DKKnob.h"
#import "DKObjectDrawingLayer.h"
#import "LogEvent.h"
#import "DKDrawkitMacros.h"

@interface DKArcPath (Private)

- (void)		calculatePath;
- (void)		movePart:(NSInteger) pc toPoint:(NSPoint) mp constrainAngle:(BOOL) constrain;

@end

#pragma mark -

@implementation DKArcPath


static CGFloat			sAngleConstraint = 0.261799387799;	// 15°


///*********************************************************************************************************************
///
/// method:			setRadius:
/// scope:			public instance method
/// overrides:		
/// description:	sets the radius of the arc
/// 
/// parameters:		<rad> the radius
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)		setRadius:(CGFloat) rad
{
	if( rad != [self radius])
	{
		[[[self undoManager] prepareWithInvocationTarget:self] setRadius:[self radius]];
		[self notifyVisualChange];
		mRadius = rad;
		[self calculatePath];
		[[self undoManager] setActionName:NSLocalizedString(@"Change Arc Radius", @"undo string for change arc radius")];
	}
}


///*********************************************************************************************************************
///
/// method:			radius
/// scope:			public instance method
/// overrides:		
/// description:	returns the radius of the arc
/// 
/// parameters:		none 
/// result:			the radius
///
/// notes:			
///
///********************************************************************************************************************

- (CGFloat)		radius
{
	return mRadius;
}


///*********************************************************************************************************************
///
/// method:			setStartAngle:
/// scope:			public instance method
/// overrides:		
/// description:	sets the starting angle, which is the more anti-clockwise point on the arc
/// 
/// parameters:		<sa> the angle in degrees anti-clockwise from the horizontal axis extending to the right
/// result:			none
///
/// notes:			angle is passed in DEGREES
///
///********************************************************************************************************************

- (void)		setStartAngle:(CGFloat) sa
{
	if( sa != [self startAngle])
	{
		[[[self undoManager] prepareWithInvocationTarget:self] setStartAngle:[self startAngle]];
		[self notifyVisualChange];
		mStartAngle = DEGREES_TO_RADIANS( sa );
		[self calculatePath];
		[[self undoManager] setActionName:NSLocalizedString(@"Change Arc Angle", @"undo string for change arc angle")];
	}
}


///*********************************************************************************************************************
///
/// method:			startAngle
/// scope:			public instance method
/// overrides:		
/// description:	returns the starting angle, which is the more anti-clockwise point on the arc
/// 
/// parameters:		none 
/// result:			the angle in degrees anti-clockwise from the horizontal axis extending to the right
///
/// notes:			
///
///********************************************************************************************************************

- (CGFloat)		startAngle
{
	return RADIANS_TO_DEGREES( mStartAngle );
}


///*********************************************************************************************************************
///
/// method:			setEndAngle:
/// scope:			public instance method
/// overrides:		
/// description:	sets the ending angle, which is the more clockwise point on the arc
/// 
/// parameters:		<ea> the angle in degrees anti-clockwise from the horizontal axis extending to the right
/// result:			none
///
/// notes:			angle is passed in DEGREES
///
///********************************************************************************************************************

- (void)		setEndAngle:(CGFloat) ea
{
	if( ea != [self endAngle])
	{
		[[[self undoManager] prepareWithInvocationTarget:self] setEndAngle:[self endAngle]];
		[self notifyVisualChange];
		mEndAngle = DEGREES_TO_RADIANS( ea );
		[self calculatePath];
		[[self undoManager] setActionName:NSLocalizedString(@"Change Arc Angle", @"undo string for change arc angle")];
	}
}


///*********************************************************************************************************************
///
/// method:			endAngle
/// scope:			public instance method
/// overrides:		
/// description:	returns the ending angle, which is the more clockwise point on the arc
/// 
/// parameters:		none 
/// result:			the angle in degrees anti-clockwise from the horizontal axis extending to the right
///
/// notes:			
///
///********************************************************************************************************************

- (CGFloat)		endAngle
{
	if (fabs(mEndAngle - mStartAngle) < 0.001)
		return RADIANS_TO_DEGREES( mStartAngle ) + 360.0;
	else
		return RADIANS_TO_DEGREES( mEndAngle );
}


///*********************************************************************************************************************
///
/// method:			setArcType:
/// scope:			public instance method
/// overrides:		
/// description:	sets the arc type, which affects the path geometry
/// 
/// parameters:		<arcType> the required type
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)			setArcType:(DKArcPathType) arcType
{
	if( arcType != [self arcType])
	{
		[[[self undoManager] prepareWithInvocationTarget:self] setArcType:[self arcType]];
		[self notifyVisualChange];
		mArcType = arcType;
		[self calculatePath];
		[[self undoManager] setActionName:NSLocalizedString(@"Change Arc Type", @"undo string for change arc type")];
	}
}


///*********************************************************************************************************************
///
/// method:			arcType
/// scope:			public instance method
/// overrides:		
/// description:	returns the arc type, which affects the path geometry
/// 
/// parameters:		none
/// result:			the current arc type
///
/// notes:			
///
///********************************************************************************************************************

- (DKArcPathType)	arcType
{
	return mArcType;
}


///*********************************************************************************************************************
///
/// method:			calculatePath
/// scope:			private instance method
/// overrides:		
/// description:	sets the path based on the current arc parameters
/// 
/// parameters:		none
/// result:			none
///
/// notes:			calls setPath: which is recorded by undo
///
///********************************************************************************************************************

- (void)		calculatePath
{
	// computes the arc's path from the radius and angle params and sets it
	
	NSBezierPath*	arcPath = [NSBezierPath bezierPath];
	NSPoint			ep;
	
	if([self arcType] == kDKArcPathCircle )
	{
		[arcPath appendBezierPathWithArcWithCenter:[self location] radius:[self radius] startAngle:0.0 endAngle:360.0];
		[arcPath closePath];
	}
	else
	{
		if ([self arcType] == kDKArcPathWedge )
		{
			[arcPath moveToPoint:[self location]];
			ep = [self pointForPartcode:kDKArcPathStartAnglePart];
			[arcPath lineToPoint:ep];
		}
		
		[arcPath appendBezierPathWithArcWithCenter:[self location] radius:[self radius] startAngle:[self startAngle] endAngle:[self endAngle]];
		
		if ([self arcType] == kDKArcPathWedge )
		{
			[arcPath lineToPoint:[self location]];
			[arcPath closePath];
		}
	}
	[self setPath:arcPath];
}


///*********************************************************************************************************************
///
/// method:			movePart:toPoint:constrainAngle:
/// scope:			private instance method
/// overrides:		
/// description:	adjusts the arc parameters based on the mouse location passed and the partcode, etc.
/// 
/// parameters:		<pc> the partcode being manipulated
///					<mp> the current point (from the mouse)
///					<constrain> YES to constrain angles to 15° increments
/// result:			none
///
/// notes:			called from mouseDragged: to implement interactive editing
///
///********************************************************************************************************************

- (void)		movePart:(NSInteger) pc toPoint:(NSPoint) mp constrainAngle:(BOOL) constrain
{
	// move the given control point to the location. This establishes the angular and radial parameters, which in turn define the path.
	
	CGFloat rad = hypotf( mp.x - mCentre.x, mp.y - mCentre.y );
	CGFloat angle = atan2f( mp.y - mCentre.y, mp.x - mCentre.x );
	
	if( constrain )
	{
		CGFloat rem = fmodf( angle, sAngleConstraint );
		
		if ( rem > sAngleConstraint / 2.0 )
			angle += ( sAngleConstraint - rem );
		else
			angle -= rem;
	}
	
	switch( pc )
	{
		case kDKArcPathRadiusPart:
			[self setRadius:rad];
			break;
			
		case kDKArcPathStartAnglePart:
			[self setStartAngle:RADIANS_TO_DEGREES( angle )];
			break;
	
		case kDKArcPathEndAnglePart:
			[self setEndAngle:RADIANS_TO_DEGREES( angle )];
			break;
			
		case kDKArcPathRotationKnobPart:
			[self setAngle:angle];
			break;
			
		default:
			break;
	}
	
	[self clearUndoPath];
}


#pragma mark -

- (IBAction)		convertToPath:(id) sender
{
	#pragma unused(sender)
	
	// replaces itself in the owning layer with a shape object with the same path.
	
	DKObjectDrawingLayer*	layer = (DKObjectDrawingLayer*)[self layer];
	NSInteger						myIndex = [layer indexOfObject:self];
	
	Class pathClass = [DKDrawableObject classForConversionRequestFor:[DKDrawablePath class]];
	DKDrawablePath*		so = [pathClass drawablePathWithBezierPath:[self path]];
	
	[so setStyle:[self style]];
	[so setUserInfo:[self userInfo]];
	
	[layer recordSelectionForUndo];
	[layer addObject:so atIndex:myIndex];
	[layer replaceSelectionWithObject:so];
	[layer removeObject:self];
	[layer commitSelectionUndoWithActionName:NSLocalizedString(@"Convert To Path", @"undo string for convert to path")];
}

#pragma mark -
#pragma mark - as a DKDrawablePath


///*********************************************************************************************************************
///
/// method:			drawControlPointsOfPath:usingKnobs:
/// scope:			public instance method
/// overrides:		DKDrawablePath
/// description:	draws the selection knobs as required
/// 
/// parameters:		<path> not used
///					<knobs> the knobs object to use for drawing
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)		drawControlPointsOfPath:(NSBezierPath*) path usingKnobs:(DKKnob*) knobs
{
	#pragma unused(path)
	
	NSPoint		kp, rp;
	DKKnobType	kt = 0;
	
	if([self locked])
		kt = kDKKnobIsDisabledFlag;
	
	rp = kp = [self pointForPartcode:kDKArcPathRadiusPart];
	
	if([self isTrackingMouse])
	{
		kp = [self pointForPartcode:kDKArcPathCentrePointPart];
		[knobs drawKnobAtPoint:kp ofType:kDKCentreTargetKnobType | kt userInfo:nil];
		[knobs drawControlBarFromPoint:kp toPoint:rp];
	}

	[knobs drawKnobAtPoint:rp ofType:kDKBoundingRectKnobType | kt angle:[self angle] userInfo:nil];
	
	if([self arcType] != kDKArcPathCircle )
	{
		kp = [self pointForPartcode:kDKArcPathStartAnglePart];
		[knobs drawKnobAtPoint:kp ofType:kDKBoundingRectKnobType | kt angle:mStartAngle userInfo:nil];

		kp = [self pointForPartcode:kDKArcPathEndAnglePart];
		[knobs drawKnobAtPoint:kp ofType:kDKBoundingRectKnobType | kt angle:mEndAngle userInfo:nil];
		
		if(![self locked])
		{
			kp = [self pointForPartcode:kDKArcPathRotationKnobPart];
			[knobs drawKnobAtPoint:kp ofType:kDKRotationKnobType userInfo:nil];
		}
	}
}


///*********************************************************************************************************************
///
/// method:			arcCreateLoop:
/// scope:			public instance method
/// overrides:		DKDrawablePath
/// description:	creates the arc path initially
/// 
/// parameters:		<initialPoint> the starting point for the creation
/// result:			none
///
/// notes:			keeps control while the mouse is being dragged/moved
///
///********************************************************************************************************************

- (void)				arcCreateLoop:(NSPoint) initialPoint
{
	// creates a circle segment. First click sets the centre, second the first radius, third the second radius.
	
	NSEvent*		theEvent;
	NSInteger				mask = NSLeftMouseDownMask | NSMouseMovedMask | NSPeriodicMask | NSScrollWheelMask;
	NSView*			view = [[self layer] currentView];
	BOOL			loop = YES, constrain = NO;
	NSInteger				phase;
	NSPoint			p, lp, nsp;
	NSString*		abbrUnits = [[self drawing] abbreviatedDrawingUnits];
	
	p = mCentre = [self snappedMousePoint:initialPoint withControlFlag:NO];
	phase = 0;	// set radius
	lp = mCentre;
	
	while( loop )
	{
		theEvent = [NSApp nextEventMatchingMask:mask untilDate:[NSDate distantFuture] inMode:NSEventTrackingRunLoopMode dequeue:YES];
		
		nsp = [view convertPoint:[theEvent locationInWindow] fromView:nil];
		p = [self snappedMousePoint:nsp withControlFlag:NO];
		
		constrain = (([theEvent modifierFlags] & NSShiftKeyMask) != 0 );
		
		if ( constrain )
		{
			// slope of line is forced to be on 15° intervals
			
			CGFloat	angle = atan2f( p.y - lp.y, p.x - lp.x );
			CGFloat	rem = fmodf( angle, sAngleConstraint );
			CGFloat	rad = hypotf( p.x - lp.x, p.y - lp.y );
		
			if ( rem > sAngleConstraint / 2.0 )
				angle += ( sAngleConstraint - rem );
			else
				angle -= rem;
				
			p.x = lp.x + ( rad * cosf( angle ));
			p.y = lp.y + ( rad * sinf( angle ));
		}

		switch ([theEvent type])
		{
			case NSLeftMouseDown:
			{
				if ( phase == 0 )
				{
					// set radius as the distance from this click to the centre, and the
					// start angle based on the slope of this line
					
					mRadius = hypotf( p.x - mCentre.x, p.y - mCentre.y );
					mEndAngle = atan2f( p.y - mCentre.y, p.x - mCentre.x );
					++phase;	// now setting the arc
					
					if([self arcType] == kDKArcPathCircle )
						loop = NO;
				}
				else
					loop = NO;
			}
			break;
			
			case NSMouseMoved:
				[self notifyVisualChange];
				[view autoscroll:theEvent];
				if ( phase == 0 )
				{
					mRadius = hypotf( p.x - mCentre.x, p.y - mCentre.y );
					
					if([self arcType] == kDKArcPathCircle )
						[self calculatePath];
					else
						[self setAngle:atan2f( p.y - mCentre.y, p.x - mCentre.x )];
					
					if([[self class] displaysSizeInfoWhenDragging])
					{			
						CGFloat rad = [[self drawing] convertLength:mRadius];
						CGFloat angle = RADIANS_TO_DEGREES([self angle]);
						
						if( angle < 0 )
							angle += 360.0f;

						[[self layer] showInfoWindowWithString:[NSString stringWithFormat:@"radius: %.2f%@\nangle: %.1f%C", rad, abbrUnits, angle, 0xB0] atPoint:nsp];
					}
				}
				else if ( phase == 1 )
				{
					mStartAngle = atan2f( p.y - mCentre.y, p.x - mCentre.x );
					[self calculatePath];

					if([[self class] displaysSizeInfoWhenDragging])
					{			
						CGFloat rad = [[self drawing] convertLength:mRadius];
						CGFloat angle = RADIANS_TO_DEGREES( mEndAngle - mStartAngle );
						
						if ( angle < 0 )
							angle = 360.0 + angle;
							
						[[self layer] showInfoWindowWithString:[NSString stringWithFormat:@"radius: %.2f%@\narc angle: %.1f%C", rad, abbrUnits, angle, 0xB0] atPoint:nsp];
					}
				}
				break;
				
			case NSScrollWheel:
				[view scrollWheel:theEvent];
				break;
			
			default:
				break;
		}
		
		[self notifyVisualChange];
	}

	LogEvent_(kReactiveEvent, @"ending arc create loop");
	
	[NSApp discardEventsMatchingMask:NSAnyEventMask beforeEvent:theEvent];

	[self setPathCreationMode:kDKPathCreateModeEditExisting];
	[self notifyVisualChange];
}


#pragma mark -
#pragma mark - as a DKDrawableObject

///*********************************************************************************************************************
///
/// method:			initialPartcodeForObjectCreation
/// scope:			public class method
/// overrides:
/// description:	return the partcode that should be used by tools when initially creating a new object
/// 
/// parameters:		none
/// result:			a partcode value
///
/// notes:			The client of this method is DKObjectCreationTool. An arc is created by dragging its radius to
///					some initial value, so the inital partcode is the radius knob.
///
///********************************************************************************************************************

+ (NSInteger)				initialPartcodeForObjectCreation
{
	return kDKArcPathRadiusPart;
}

///*********************************************************************************************************************
///
/// method:			hitSelectedPart:forSnapDetection:
/// scope:			public instance method
/// overrides:		DKDrawableObject
/// description:	hit test the point against the knobs
/// 
/// parameters:		<pt> the point to hit-test
///					<snap> YES if the test is being done for snap-detecting purposes, NO for normal mouse hits
/// result:			the partcode hit by the point, if any
///
/// notes:			
///
///********************************************************************************************************************

- (NSInteger)				hitSelectedPart:(NSPoint) pt forSnapDetection:(BOOL) snap
{
	CGFloat	tol = [[[self layer] knobs] controlKnobSize].width;
	
	if( snap )
		tol *= 2;
		
	NSInteger		pc;
	
	// test for a hit in any of our knobs
	
	NSRect	kr;
	NSPoint	kp;
	
	kr.size = NSMakeSize( tol, tol );
	
	for( pc = kDKArcPathRadiusPart; pc <= kDKArcPathCentrePointPart; ++pc )
	{
		kp = [self pointForPartcode:pc];
		kr.origin = kp;
		kr = NSOffsetRect( kr, tol * -0.5f, tol * -0.5f );
	
		if( NSPointInRect( pt, kr ))
			return pc;
	}
	
	pc = kDKDrawingEntireObjectPart;

	if ( snap )
	{
		// for snapping to the nearest point on the path, return a special partcode value and cache the mouse point -
		// when pointForPartcode is called with this special code, locate the nearest path point and return it.
		
		if ([self pointHitsPath:pt])
		{
			gMouseForPathSnap = pt;
			pc = kDKSnapToNearestPathPointPartcode;
		}
	}
	
	return pc;
}


///*********************************************************************************************************************
///
/// method:			pointForPartcode:
/// scope:			public instance method
/// overrides:		DKDrawableObject
/// description:	return the current point for a given partcode value
/// 
/// parameters:		<pc> the partcode
/// result:			the partcode hit by the point, if any
///
/// notes:			
///
///********************************************************************************************************************

- (NSPoint)			pointForPartcode:(NSInteger) pc
{
	CGFloat		angle, radius;
	
	radius = mRadius;
	
	switch (pc )
	{
		case kDKSnapToNearestPathPointPartcode:
			return [super pointForPartcode:pc];
		
		case kDKArcPathRotationKnobPart:
			radius *= 0.75;
			// fall through:
		case kDKArcPathRadiusPart:
			angle = [self angle];
			break;
			
		case kDKArcPathStartAnglePart:
			angle = mStartAngle;
			break;
			
		case kDKArcPathEndAnglePart:
			angle = mEndAngle;
			break;
			
		case kDKArcPathCentrePointPart:
			return mCentre;
		
		default:
			return NSZeroPoint;
	}
	
	NSPoint kp;
	
	kp.x = mCentre.x + ( cosf( angle ) * radius);
	kp.y = mCentre.y + ( sinf( angle ) * radius);
	
	return kp;
}


///*********************************************************************************************************************
///
/// method:			mouseDownAtPoint:inPart:event:
/// scope:			protected instance method
/// overrides:		DKDrawablePath
/// description:	handles a mouse down in the object
/// 
/// parameters:		<mp> the mouse point
///					<partcode> the partcode returned earlier by hitPart:
///					<evt> the event this came from
/// result:			none
///
/// notes:			starts edit or creation of object - the creation mode can be anything other then "edit existing"
///					for arc creation. Use the "simple mode" to create arcs in a one-stage drag.
///
///********************************************************************************************************************

- (void)				mouseDownAtPoint:(NSPoint) mp inPart:(NSInteger) partcode event:(NSEvent*) evt
{
	[[self layer] setInfoWindowBackgroundColour:[[self class]infoWindowBackgroundColour]];

	[self setTrackingMouse:YES];
	DKDrawablePathCreationMode mode = [self pathCreationMode];
	
	switch ( mode )
	{
		case kDKPathCreateModeEditExisting:
			[super mouseDownAtPoint:mp inPart:partcode event:evt];
			break;
			
		case kDKArcSimpleCreationMode:
			[self setStartAngle:-22.5];
			[self setEndAngle:22.5];
			[self setPathCreationMode:kDKPathCreateModeEditExisting];
			break;
			
		default:
			[self arcCreateLoop:mp];
			break;
	}
}



///*********************************************************************************************************************
///
/// method:			mouseDraggedAtPoint:inPart:event:
/// scope:			protected instance method
/// overrides:		DKDrawableObject
/// description:	handles a mouse drag in the object
/// 
/// parameters:		<mp> the mouse point
///					<partcode> the partcode returned earlier by hitPart:
///					<evt> the event this came from
/// result:			none
///
/// notes:			used when editing an existing path, but not creating one
///
///********************************************************************************************************************

- (void)				mouseDraggedAtPoint:(NSPoint) mp inPart:(NSInteger) partcode event:(NSEvent*) evt
{
	BOOL shift	= (([evt modifierFlags] & NSShiftKeyMask ) != 0 );
	BOOL ctrl	= (([evt modifierFlags] & NSControlKeyMask ) != 0 );
	
	// modifier keys change the editing of path control points thus:
	
	// +shift	- constrains curve control point angles to 15° intervals
	// +ctrl	- temporarily disables snap to grid
	
	NSPoint smp = [self snappedMousePoint:mp withControlFlag:ctrl];
	
	if ( partcode == kDKArcPathCentrePointPart )
		[self setLocation:smp];
	else if ( partcode == kDKDrawingEntireObjectPart )
		[super mouseDraggedAtPoint:mp inPart:kDKDrawingEntireObjectPart event:evt];
	else
		[self movePart:partcode toPoint:smp constrainAngle:shift];
	
	if([[self class] displaysSizeInfoWhenDragging])
	{			
		NSString*	abbrUnits = [[self drawing] abbreviatedDrawingUnits];
		CGFloat		rad = [[self drawing] convertLength:mRadius];
		CGFloat		angle;
		NSString*	infoStr;
		NSPoint		gridPt;
		
		switch ( partcode )
		{
			case kDKDrawingEntireObjectPart:
			case kDKArcPathCentrePointPart:
				gridPt = [self convertPointToDrawing:[self location]];
				infoStr = [NSString stringWithFormat:@"centre x: %.2f%@\ncentre y: %.2f%@", gridPt.x, abbrUnits, gridPt.y, abbrUnits];
				break;
			
			case kDKArcPathRotationKnobPart:
				angle = [self angleInDegrees];
				infoStr = [NSString stringWithFormat:@"radius: %.2f%@\nangle: %.1f%C", rad, abbrUnits, angle, 0xB0];
				break;
				
			default:
				angle = RADIANS_TO_DEGREES( mEndAngle - mStartAngle );
				if ( angle < 0 )
					angle += 360.0f;
				infoStr = [NSString stringWithFormat:@"radius: %.2f%@\narc angle: %.1f%C", rad, abbrUnits, angle, 0xB0];
				break;
		}
		
		[[self layer] showInfoWindowWithString:infoStr atPoint:mp];
	}

	[self setMouseHasMovedSinceStartOfTracking:YES];
}


///*********************************************************************************************************************
///
/// method:			notifyVisualChange
/// scope:			public instance method
/// overrides:		DKDrawableObject
/// description:	sets the path's bounds to be updated
/// 
/// parameters:		none
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)			notifyVisualChange
{
	[[self layer] drawable:self needsDisplayInRect:[self bounds]];
	[[self drawing] updateRulerMarkersForRect:[self logicalBounds]];
	[[NSNotificationCenter defaultCenter] postNotificationName:kDKDrawableDidChangeNotification object:self];
}


///*********************************************************************************************************************
///
/// method:			location
/// scope:			public instance method
/// overrides:		DKDrawableObject
/// description:	return the object's location within the drawing
/// 
/// parameters:		none
/// result:			the position of the object within the drawing
///
/// notes:			arc objects consider their centre origin as the datum of the location
///
///********************************************************************************************************************

- (NSPoint)			location
{
	return mCentre;
}


///*********************************************************************************************************************
///
/// method:			setLocation:
/// scope:			public instance method
/// overrides:		DKDrawableObject
/// description:	move the object to a given location within the drawing
/// 
/// parameters:		<p> the point at which to place the object
/// result:			none
///
/// notes:			arc objects consider their centre origin as the datum of the location
///
///********************************************************************************************************************

- (void)			setLocation:(NSPoint) p
{
	if( !NSEqualPoints( p, mCentre ) && ![self locked] && ![self locationLocked])
	{
		[[[self undoManager] prepareWithInvocationTarget:self] setLocation:[self location]];
		[self notifyVisualChange];
		mCentre = p;
		[self calculatePath];
	}
}


///*********************************************************************************************************************
///
/// method:			bounds
/// scope:			public instance method
/// overrides:		DKDrawableObject
/// description:	return the total area the object is enclosed by
/// 
/// parameters:		none
/// result:			the bounds rect
///
/// notes:			bounds includes the centre point, even if it's not visible
///
///********************************************************************************************************************

- (NSRect)			bounds
{
	NSRect	pb = [[self path] bounds];
	NSRect	kr;
	
	CGFloat	tol = [[[self layer] knobs] controlKnobSize].width;
	NSPoint	kp;
	NSInteger		pc, pcm;
	
	kr.size = NSMakeSize( tol, tol );
	
	pcm = kDKArcPathCentrePointPart;//m_inMouseOp? kDKArcPathCentrePointPart : kDKArcPathRotationKnobPart;
	
	for( pc = kDKArcPathRadiusPart; pc <= pcm; ++pc )
	{
		kp = [self pointForPartcode:pc];
		kr.origin = kp;
		kr = NSOffsetRect( kr, tol * -0.5f, tol * -0.5f );
		pb = NSUnionRect( pb, kr );
	}
	
	NSSize ex = [super extraSpaceNeeded];
	return NSInsetRect( pb, -(ex.width + tol), -( ex.height + tol ) );
}


///*********************************************************************************************************************
///
/// method:			setAngle:
/// scope:			public instance method
/// overrides:		DKDrawableObject
/// description:	sets the overall angle of the object
/// 
/// parameters:		<angle> the overall angle in radians
/// result:			none
///
/// notes:			the angle is in radians whereas the start/end angles are set in degrees
///
///********************************************************************************************************************

- (void)			setAngle:(CGFloat) angle
{
	if([self arcType] == kDKArcPathCircle )
		return;
		
	CGFloat da = angle - [self angle];
	
	if ( da != 0.0 )
	{
		[[[self undoManager] prepareWithInvocationTarget:self] setAngle:[self angle]];
		[self notifyVisualChange];
		mStartAngle += da;
		mEndAngle += da;
		[self calculatePath];
		[[self undoManager] setActionName:NSLocalizedString(@"Rotate Arc", @"undo string for rotate arc")];
	}
}


///*********************************************************************************************************************
///
/// method:			angle:
/// scope:			public instance method
/// overrides:		DKDrawableObject
/// description:	returns the overall angle of the object
/// 
/// parameters:		none
/// result:			the overall angle
///
/// notes:			the overall angle is considered to be halfway between the start and end points around the arc
///
///********************************************************************************************************************

- (CGFloat)			angle
{
	if([self arcType] == kDKArcPathCircle )
		return 0.0;
	else
	{
		CGFloat angle = ( mStartAngle + mEndAngle ) * 0.5f;
		
		if (fabs(mEndAngle - mStartAngle) < 0.001)
			angle -= pi;
		
		if ( mEndAngle < mStartAngle )
			angle += pi;
		
		return angle;
	}
}


///*********************************************************************************************************************
///
/// method:			group:willUngroupObjectWithTransform:
/// scope:			public instance method
/// overrides:		DKDrawableObject
/// description:	this object is being ungrouped from a group
/// 
/// parameters:		<aGroup> the group containing the object
///					<aTransform> the transform that the group is applying to the object to scale rotate and translate it.
/// result:			none
///
/// notes:			when ungrouping, an object must help the group to the right thing by resizing, rotating and repositioning
///					itself appropriately. At the time this is called, the object has already has its container set to
///					the layer it will be added to but has not actually been added.
///
///********************************************************************************************************************

- (void)				group:(DKShapeGroup*) aGroup willUngroupObjectWithTransform:(NSAffineTransform*) aTransform
{
	// note - arc paths can become very distorted if groups are scaled unequally. Should the path be preserved
	// in the distorted way? Or should the arc be recovered with the most useful radius? Something's got to give... at
	// the moment this does the latter.
	
	NSPoint loc = [self location];
	loc = [aTransform transformPoint:loc];
	
	NSSize radSize = NSMakeSize([self radius], [self radius]);
	radSize = [aTransform transformSize:radSize];
		
	[self setLocation:loc];
	[self setRadius:hypotf( radSize.width, radSize.height ) / _CGFloatSqrt(2.0f)];
	[self setAngle:[self angle] + [aGroup angle]];
}


///*********************************************************************************************************************
///
/// method:			snappingPointsWithOffset:
/// scope:			public action method
/// overrides:		DKDrawableObject
/// description:	returns a list of potential snapping points used when the path is snapped to the grid or guides
/// 
/// parameters:		<offset> add this offset to the points
/// result:			an array of points as NSValue objects
///
/// notes:			part of the snapping protocol
///
///********************************************************************************************************************

- (NSArray*)			snappingPointsWithOffset:(NSSize) offset
{
	NSInteger				i;
	NSPoint			p;
	NSMutableArray* result = [NSMutableArray array];
	
	for( i = kDKArcPathRadiusPart; i <= kDKArcPathCentrePointPart; ++i )
	{
		if( i != kDKArcPathRotationKnobPart )
		{
			p = [self pointForPartcode:i];
	
			p.x += offset.width;
			p.y += offset.height;
			
			[result addObject:[NSValue valueWithPoint:p]];
		}
	}
	return result;
}


- (BOOL)				populateContextualMenu:(NSMenu*) theMenu
{
	[[theMenu addItemWithTitle:NSLocalizedString(@"Convert To Path", @"menu item for convert to path") action:@selector( convertToPath: ) keyEquivalent:@""] setTarget:self];
	return [super populateContextualMenu:theMenu];
}


- (void)				applyTransform:(NSAffineTransform*) transform
{
	[super applyTransform:transform];
	mCentre = [transform transformPoint:mCentre];
}




#pragma mark -
#pragma mark - as a NSObject

///*********************************************************************************************************************
///
/// method:			init
/// scope:			public instance method
/// overrides:		NSObject
/// description:	designated initialiser
/// 
/// parameters:		none
/// result:			the object
///
/// notes:			
///
///********************************************************************************************************************

- (id)				init
{
	self = [super init];
	if (self != nil)
	{
		[self setPathCreationMode:kDKPathCreateModeWedgeSegment];
		[self setArcType:kDKArcPathWedge];
		[self setStyle:[DKStyle defaultStyle]];
	}
	
	return self;
}


///*********************************************************************************************************************
///
/// method:			copyWithZone:
/// scope:			public instance method
/// overrides:		NSObject
/// description:	copies the object
/// 
/// parameters:		<zone> the zone
/// result:			the copy
///
/// notes:			implements <NSCopying>
///
///********************************************************************************************************************

- (id)				copyWithZone:(NSZone*) zone
{
	DKArcPath* copy = [super copyWithZone:zone];
	if( copy != nil )
	{
		copy->mStartAngle = mStartAngle;
		copy->mEndAngle = mEndAngle;
		copy->mRadius = mRadius;
		copy->mCentre = mCentre;
		copy->mArcType = mArcType;
	}
	
	return copy;
}


///*********************************************************************************************************************
///
/// method:			encodeWithCoder:
/// scope:			public instance method
/// overrides:		NSObject<NSCoding>
/// description:	encodes the object for archiving
/// 
/// parameters:		<coder> the coder
/// result:			none
///
/// notes:			
///
///********************************************************************************************************************

- (void)			encodeWithCoder:(NSCoder*) coder
{
	[super encodeWithCoder:coder];
	[coder encodeDouble:mStartAngle forKey:@"DKArcPath_startAngle"];
	[coder encodeDouble:mEndAngle forKey:@"DKArcPath_endAngle"];
	[coder encodeDouble:mRadius forKey:@"DKArcPath_radius"];
	[coder encodeInteger:[self arcType] forKey:@"DKArcPath_arcType"];
	[coder encodePoint:[self location] forKey:@"DKArcPath_location"];
}


///*********************************************************************************************************************
///
/// method:			initWithCoder:
/// scope:			public instance method
/// overrides:		NSObject<NSCoding>
/// description:	decodes the object for archiving
/// 
/// parameters:		<coder> the coder
/// result:			the object
///
/// notes:			
///
///********************************************************************************************************************

- (id)				initWithCoder:(NSCoder*) coder
{
	[super initWithCoder:coder];
	mStartAngle = [coder decodeDoubleForKey:@"DKArcPath_startAngle"];
	mEndAngle = [coder decodeDoubleForKey:@"DKArcPath_endAngle"];
	mRadius = [coder decodeDoubleForKey:@"DKArcPath_radius"];
	[self setArcType:[coder decodeIntegerForKey:@"DKArcPath_arcType"]];
	[self setLocation:[coder decodePointForKey:@"DKArcPath_location"]];
	
	return self;
}


#pragma mark -
#pragma mark As part of NSMenuValidation Protocol

- (BOOL)				validateMenuItem:(NSMenuItem*) item
{
	SEL	action = [item action];
	
	if ( action == @selector( convertToPath: ))
		return ![self locked];

	return [super validateMenuItem:item];
}

@end
