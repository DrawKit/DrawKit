/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import <Cocoa/Cocoa.h>
#import "DKGradient.h"

NS_ASSUME_NONNULL_BEGIN

typedef union pix_int {
	unsigned int pixel;
	struct pix_units {
		unsigned char a;
		unsigned char r;
		unsigned char g;
		unsigned char b;
	} c;
} pix_int;

@interface DKSweptAngleGradient : DKGradient {
	CGImageRef m_sa_image;
	CGContextRef m_sa_bitmap;
	pix_int* m_sa_colours;
	NSInteger m_sa_segments;
	NSPoint m_sa_centre;
	CGFloat m_sa_startAngle;
	NSInteger m_sa_img_width;
	BOOL m_ditherColours;
}

+ (DKSweptAngleGradient*)sweptAngleGradient;
+ (DKSweptAngleGradient*)sweptAngleGradientWithStartingColor:(NSColor*)c1 endingColor:(NSColor*)c2;

@property NSInteger numberOfAngularSegments;

- (void)preloadColours;
- (void)createGradientImageWithRect:(NSRect)rect;
- (void)invalidateCache;

@end

NS_ASSUME_NONNULL_END
