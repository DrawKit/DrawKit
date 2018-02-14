/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import "DKDrawing+Paper.h"

@implementation DKDrawing (Paper)

+ (NSSize)isoA0PaperSize:(BOOL)portrait
{
	// A0 is defined as a sheet 1m^2 in area with sides of ratio 1:sqrt(2) which gives 841 x 1189 mm

	NSSize a0;

	if (portrait) {
		a0.width = 841.0 * 2.83465;
		a0.height = 1189.0 * 2.83465;
	} else {
		a0.width = 1189.0 * 2.83465;
		a0.height = 841.0 * 2.83465;
	}

	return a0;
}

+ (NSSize)isoA1PaperSize:(BOOL)portrait
{
	NSSize a1 = [self isoA0PaperSize:!portrait];

	if (portrait)
		a1.width /= 2.0;
	else
		a1.height /= 2.0;

	return a1;
}

+ (NSSize)isoA2PaperSize:(BOOL)portrait
{
	NSSize a2 = [self isoA1PaperSize:!portrait];

	if (portrait)
		a2.width /= 2.0;
	else
		a2.height /= 2.0;

	return a2;
}

+ (NSSize)isoA3PaperSize:(BOOL)portrait
{
	NSSize a3 = [self isoA2PaperSize:!portrait];

	if (portrait)
		a3.width /= 2.0;
	else
		a3.height /= 2.0;

	return a3;
}

+ (NSSize)isoA4PaperSize:(BOOL)portrait
{
	NSSize a4 = [self isoA3PaperSize:!portrait];

	if (portrait)
		a4.width /= 2.0;
	else
		a4.height /= 2.0;

	return a4;
}

+ (NSSize)isoA5PaperSize:(BOOL)portrait
{
	NSSize a5 = [self isoA4PaperSize:!portrait];

	if (portrait)
		a5.width /= 2.0;
	else
		a5.height /= 2.0;

	return a5;
}

@end
