/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface DKStrokeDash : NSObject <NSCoding, NSCopying> {
@private
	CGFloat m_pattern[8];
	CGFloat m_phase;
	NSUInteger m_count;
	BOOL m_scaleToLineWidth;
	BOOL mEditing;
}

+ (DKStrokeDash*)defaultDash NS_SWIFT_UNAVAILABLE("Use `init()` instead");
+ (DKStrokeDash*)dashWithPattern:(const CGFloat[_Nonnull])dashes count:(NSInteger)count NS_SWIFT_UNAVAILABLE("Use `init(pattern:count:)` instead");
+ (nullable DKStrokeDash*)dashWithName:(NSString*)name;
+ (void)registerDash:(DKStrokeDash*)dash withName:(NSString*)name;
@property (class, readonly, copy) NSArray<DKStrokeDash*>* registeredDashes;

+ (DKStrokeDash*)equallySpacedDashToFitSize:(NSSize)aSize dashLength:(CGFloat)len;

- (instancetype)initWithPattern:(const CGFloat[_Nonnull])dashes count:(NSInteger)count NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_DESIGNATED_INITIALIZER;
- (nullable instancetype)initWithCoder:(NSCoder*)aDecoder NS_DESIGNATED_INITIALIZER;
- (void)setDashPattern:(const CGFloat[_Nonnull])dashes count:(NSInteger)count NS_SWIFT_NAME(setPattern(_:count:));
- (void)getDashPattern:(CGFloat[_Nonnull])dashes count:(NSInteger*)count;

/** @brief The count of dashes.
 */
@property (readonly) NSUInteger count;

- (void)setPhaseWithoutNotifying:(CGFloat)ph;

/** @brief The phase of the dash, ignoring any line width scaling.
 */
@property (nonatomic) CGFloat phase;

/** @brief Returns the length of the dash pattern before it repeats.
 
 Note that if the pattern is scaled to the line width,
 this returns the unscaled length, so the client needs to multiply the result by the line width if necessary.
 */
@property (readonly) CGFloat length;
- (CGFloat)lengthAtIndex:(NSUInteger)indx;

@property BOOL scalesToLineWidth;

/** An editor should set this for the duration of an edit. It prevents certain properties being changed by rasterizers during the edit
 which can cause contention for those properties.
 */
@property BOOL isBeingEdited;

- (void)applyToPath:(NSBezierPath*)path;
/** @brief Applies the stroke to <code>path</code>.
 @discussion If scales to line width, use path's line width to multiply each element of the pattern.
 */
- (void)applyToPath:(NSBezierPath*)path withPhase:(CGFloat)phase;

- (NSImage*)dashSwatchImageWithSize:(NSSize)size strokeWidth:(CGFloat)width;
- (NSImage*)standardDashSwatchImage;

@end

@interface DKStrokeDash (Deprecated)

+ (void)saveDefaults DEPRECATED_ATTRIBUTE;
+ (void)loadDefaults DEPRECATED_ATTRIBUTE;

@end

/*
 This stores a particular dash pattern for stroking an NSBezierPath, and can be owned by a DKStroke.
*/

#define kDKStandardDashSwatchImageSize (NSMakeSize(80.0, 4.0))
#define kDKStandardDashSwatchStrokeWidth 2.0

NS_ASSUME_NONNULL_END
