/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>

@interface DKStrokeDash : NSObject <NSCoding, NSCopying> {
@private
	CGFloat m_pattern[8];
	CGFloat m_phase;
	NSUInteger m_count;
	BOOL m_scaleToLineWidth;
	BOOL mEditing;
}

/**  */
+ (DKStrokeDash*)defaultDash;
+ (DKStrokeDash*)dashWithPattern:(CGFloat[])dashes count:(NSInteger)count;
+ (DKStrokeDash*)dashWithName:(NSString*)name;
+ (void)registerDash:(DKStrokeDash*)dash withName:(NSString*)name;
+ (NSArray*)registeredDashes;

+ (DKStrokeDash*)equallySpacedDashToFitSize:(NSSize)aSize dashLength:(CGFloat)len;

- (id)initWithPattern:(CGFloat[])dashes count:(NSInteger)count;
- (void)setDashPattern:(CGFloat[])dashes count:(NSInteger)count;
- (void)getDashPattern:(CGFloat[])dashes count:(NSInteger*)count;
- (NSInteger)count;
- (void)setPhase:(CGFloat)ph;
- (void)setPhaseWithoutNotifying:(CGFloat)ph;
- (CGFloat)phase;
- (CGFloat)length;
- (CGFloat)lengthAtIndex:(NSUInteger)indx;

- (void)setScalesToLineWidth:(BOOL)stlw;
- (BOOL)scalesToLineWidth;

- (void)setIsBeingEdited:(BOOL)edit;
- (BOOL)isBeingEdited;

- (void)applyToPath:(NSBezierPath*)path;
- (void)applyToPath:(NSBezierPath*)path withPhase:(CGFloat)phase;

- (NSImage*)dashSwatchImageWithSize:(NSSize)size strokeWidth:(CGFloat)width;
- (NSImage*)standardDashSwatchImage;

@end

@interface DKStrokeDash (Deprecated)

+ (void)saveDefaults;
+ (void)loadDefaults;

@end

/*
 This stores a particular dash pattern for stroking an NSBezierPath, and can be owned by a DKStroke.
*/

#define kDKStandardDashSwatchImageSize (NSMakeSize(80.0, 4.0))
#define kDKStandardDashSwatchStrokeWidth 2.0
