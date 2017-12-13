/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import "DKMetadataItem.h"

NSString* DKSingleMetadataItemPBoardType = @"com.apptree.dk.meta";
NSString* DKMultipleMetadataItemsPBoardType = @"com.apptree.dk.multimeta";

@interface DKMetadataItem (Private)

- (void)assignValue:(id)aValue;
- (id)valueWithCurrentType:(id)inValue;
- (id)convertValue:(id)inValue toType:(DKMetadataType)type wasLossy:(BOOL*)lossy;

@end

#pragma mark -

@implementation DKMetadataItem

+ (Class)classForType:(DKMetadataType)type
{
	switch (type) {
	case DKMetadataTypeString:
		return [NSString class];

	case DKMetadataTypeInteger:
	case DKMetadataTypeReal:
	case DKMetadataTypeUnsignedInt:
	case DKMetadataTypeBoolean:
		return [NSNumber class];

	case DKMetadataTypeURL:
		return [NSURL class];

	case DKMetadataTypeColour:
		return [NSColor class];

	case DKMetadataTypeData:
	case DKMetadataTypeImageData:
		return [NSData class];

	case DKMetadataTypeDate:
		return [NSDate class];

	case DKMetadataTypeImage:
		return [NSImage class];

	case DKMetadataTypeAttributedString:
		return [NSAttributedString class];

	case DKMetadataTypeSize:
	case DKMetadataTypePoint:
	case DKMetadataTypeRect:
		return [NSValue class];

	default:
		return Nil;
	}
}

+ (NSString*)localizedDisplayNameForType:(DKMetadataType)type
{
	switch (type) {
	case DKMetadataTypeString:
		return NSLocalizedString(@"String", nil);

	case DKMetadataTypeInteger:
		return NSLocalizedString(@"Integer", nil);

	case DKMetadataTypeReal:
		return NSLocalizedString(@"Real Number", nil);

	case DKMetadataTypeUnsignedInt:
		return NSLocalizedString(@"Unsigned Integer", nil);

	case DKMetadataTypeBoolean:
		return NSLocalizedString(@"Boolean", nil);

	case DKMetadataTypeURL:
		return NSLocalizedString(@"URL", nil);

	case DKMetadataTypeColour:
		return NSLocalizedString(@"Colour", nil);

	case DKMetadataTypeData:
		return NSLocalizedString(@"Data", nil);

	case DKMetadataTypeImageData:
		return NSLocalizedString(@"Image Data", nil);

	case DKMetadataTypeDate:
		return NSLocalizedString(@"Date", nil);

	case DKMetadataTypeImage:
		return NSLocalizedString(@"Image", nil);

	case DKMetadataTypeAttributedString:
		return NSLocalizedString(@"Styled String", nil);

	case DKMetadataTypeSize:
		return NSLocalizedString(@"Size", nil);

	case DKMetadataTypePoint:
		return NSLocalizedString(@"Point", nil);

	case DKMetadataTypeRect:
		return NSLocalizedString(@"Rectangle", nil);

	case DKMetadataTypeUnknown:
		return NSLocalizedString(@"???", nil);

	case DKMetadataMultipleTypesMarker:
		return NSLocalizedString(@"<multiple types>", nil);

	default:
		return @"";
	}
}

+ (DKMetadataItem*)metadataItemWithString:(NSString*)aString
{
	return [[self alloc] initWithString:aString];
}

+ (DKMetadataItem*)metadataItemWithInteger:(NSInteger)anInteger
{
	return [[self alloc] initWithInteger:anInteger];
}

+ (DKMetadataItem*)metadataItemWithReal:(CGFloat)aReal
{
	return [[self alloc] initWithReal:aReal];
}

+ (DKMetadataItem*)metadataItemWithBoolean:(BOOL)aBool
{
	return [[self alloc] initWithBoolean:aBool];
}

+ (DKMetadataItem*)metadataItemWithUnsigned:(NSUInteger)anInteger
{
	return [[self alloc] initWithUnsigned:anInteger];
}

+ (DKMetadataItem*)metadataItemWithAttributedString:(NSAttributedString*)attrString
{
	return [[self alloc] initWithAttributedString:attrString];
}

+ (DKMetadataItem*)metadataItemWithImage:(NSImage*)image
{
	return [[self alloc] initWithImage:image];
}

+ (DKMetadataItem*)metadataItemWithImageData:(NSData*)imageData
{
	return [[self alloc] initWithImageData:imageData];
}

+ (DKMetadataItem*)metadataItemWithURL:(NSURL*)url
{
	return [[self alloc] initWithURL:url];
}

+ (DKMetadataItem*)metadataItemWithDate:(NSDate*)date
{
	return [[self alloc] initWithDate:date];
}

+ (DKMetadataItem*)metadataItemWithColour:(NSColor*)colour
{
	return [[self alloc] initWithColour:colour];
}

+ (DKMetadataItem*)metadataItemWithData:(NSData*)data
{
	return [[self alloc] initWithData:data];
}

+ (DKMetadataItem*)metadataItemWithSize:(NSSize)size
{
	return [[self alloc] initWithSize:size];
}

+ (DKMetadataItem*)metadataItemWithPoint:(NSPoint)point
{
	return [[self alloc] initWithPoint:point];
}

+ (DKMetadataItem*)metadataItemWithRect:(NSRect)rect
{
	return [[self alloc] initWithRect:rect];
}

+ (DKMetadataItem*)metadataItemWithObject:(id)value
{
	// this should only be used when definitive type information is not known. This will attempt to infer the type from the object. It is
	// mainly provided as a mechanism for migrating older metadata values to DKMetadataItem values.

	if ([value isKindOfClass:[self class]])
		return [value copy];

	if ([value isKindOfClass:[NSString class]])
		return [self metadataItemWithString:value];
	else if ([value isKindOfClass:[NSAttributedString class]])
		return [self metadataItemWithAttributedString:value];
	else if ([value isKindOfClass:[NSColor class]])
		return [self metadataItemWithColour:value];
	else if ([value isKindOfClass:[NSImage class]])
		return [self metadataItemWithImage:value];
	else if ([value isKindOfClass:[NSURL class]])
		return [self metadataItemWithURL:value];
	else if ([value isKindOfClass:[NSDate class]])
		return [self metadataItemWithDate:value];
	else if ([value isKindOfClass:[NSData class]])
		return [self metadataItemWithData:value];
	else if ([value isKindOfClass:[NSNumber class]]) {
		// a number - what sort is it? This info may be unreliable

		const char* eType = [value objCType];

		if (strcmp(eType, @encode(NSInteger)) == 0)
			return [self metadataItemWithInteger:[value integerValue]];
		else if (strcmp(eType, @encode(double)) == 0 || strcmp(eType, @encode(CGFloat)) == 0)
			return [self metadataItemWithReal:[value doubleValue]];
		else if (strcmp(eType, @encode(NSUInteger)) == 0)
			return [self metadataItemWithUnsigned:[value unsignedIntegerValue]];
		else if (strcmp(eType, @encode(BOOL)) == 0)
			return [self metadataItemWithBoolean:[value boolValue]];
	} else if ([value isKindOfClass:[NSValue class]]) {
		const char* eType = [value objCType];

		if (strcmp(eType, @encode(NSSize)) == 0)
			return [self metadataItemWithSize:[value sizeValue]];
		else if (strcmp(eType, @encode(NSPoint)) == 0)
			return [self metadataItemWithPoint:[value pointValue]];
		else if (strcmp(eType, @encode(NSRect)) == 0)
			return [self metadataItemWithRect:[value rectValue]];
	}

	// fallback to string if the value can return a string value and we didn't get anything else yet

	if ([value respondsToSelector:@selector(stringValue)])
		return [self metadataItemWithString:[value stringValue]];

	// if all else fails, fail.

	return nil;
}

+ (DKMetadataItem*)metadataItemWithPasteboard:(NSPasteboard*)pb
{
	NSAssert(pb != nil, @"can't read from nil pasteboard");

	NSString* type = [pb availableTypeFromArray:@[DKSingleMetadataItemPBoardType]];
	if (type) {
		NSData* data = [pb dataForType:DKSingleMetadataItemPBoardType];

		if (data)
			return [NSKeyedUnarchiver unarchiveObjectWithData:data];
	}

	return nil;
}

+ (NSDictionary*)dictionaryOfMetadataItemsWithDictionary:(NSDictionary*)aDict
{
	// returns a dictionary of DKMetadataItems built by iterating the input dictionary and wrapping each object using metadataItemWithObject:
	// this is designed as a way to convert existing dictionaries of attributes wholesale. If the dictionary already contains meta items, the
	// result is effectively a copy of those items.

	NSEnumerator* iter = [aDict keyEnumerator];
	NSMutableDictionary* newDict = [NSMutableDictionary dictionary];
	id key, value;
	DKMetadataItem* item;

	while ((key = [iter nextObject])) {
		if ([key isKindOfClass:[NSString class]]) {
			value = [aDict objectForKey:key];
			item = [self metadataItemWithObject:value];

			if (item)
				[newDict setObject:item
							forKey:[(NSString*)key lowercaseString]];
		}
	}

	return newDict;
}

+ (NSArray*)arrayOfMetadataItemsWithArray:(NSArray*)array
{
	// returns an array of DKMetadataItems built by iterating the input array and wrapping each object using metadataItemWithObject:
	// this is designed as a way to convert existing arrays of attributes wholesale.

	NSEnumerator* iter = [array objectEnumerator];
	NSMutableArray* newArray = [NSMutableArray array];
	id value;
	DKMetadataItem* item;

	while ((value = [iter nextObject])) {
		item = [self metadataItemWithObject:value];

		if (item)
			[newArray addObject:item];
	}

	return newArray;
}

+ (NSDictionary*)metadataItemsWithPasteboard:(NSPasteboard*)pb
{
	NSAssert(pb != nil, @"can't read from nil pasteboard");

	// multiple items are written to the pasteboard as an archived dictionary having key/item pairs of items. These can be
	// added to an object's metadata with its -addMetadata: method.

	NSString* type = [pb availableTypeFromArray:@[DKMultipleMetadataItemsPBoardType]];
	if (type) {
		NSData* data = [pb dataForType:DKMultipleMetadataItemsPBoardType];

		if (data)
			return [NSKeyedUnarchiver unarchiveObjectWithData:data];
	}

	return nil;
}

+ (BOOL)writeMetadataItems:(NSArray*)items forKeys:(NSArray*)keys toPasteboard:(NSPasteboard*)pb
{
	// convenience method for writing a set of items and keys to the pasteboard

	NSAssert(pb != nil, @"cannot write to a nil pasteboard");
	NSAssert([items count] == [keys count], @"count of items and keys do not match");

	NSDictionary* dict = [NSDictionary dictionaryWithObjects:items
													 forKeys:keys];
	NSData* data = [NSKeyedArchiver archivedDataWithRootObject:dict];
	[pb addTypes:@[DKMultipleMetadataItemsPBoardType, NSTabularTextPboardType, NSStringPboardType]
		   owner:self];

	// add the items as TSV text for other apps to make use of

	NSMutableString* tabText = [NSMutableString string];
	NSEnumerator* iter = [keys objectEnumerator];
	NSString* key;
	DKMetadataItem* item;

	while ((key = [iter nextObject])) {
		item = [dict objectForKey:key];

		[tabText appendString:[key uppercaseString]];
		[tabText appendString:@"\t"];
		[tabText appendString:[item stringValue]];
		[tabText appendString:@"\t"];
		[tabText appendString:[item typeDisplayName]];
		[tabText appendString:@"\t\r"];
	}
	[pb setString:tabText
		  forType:NSTabularTextPboardType];
	[pb setString:tabText
		  forType:NSStringPboardType];

	return [pb setData:data
			   forType:DKMultipleMetadataItemsPBoardType];
}

#pragma mark -

// designated initializer:

- (instancetype)initWithType:(DKMetadataType)type
{
	self = [super init];
	if (self) {
		mType = type;
		mValue = nil;
	}

	return self;
}

- (instancetype)initWithString:(NSString*)aString
{
	self = [self initWithType:DKMetadataTypeString];
	if (self) {
		[self assignValue:aString];
	}

	return self;
}

- (instancetype)initWithInteger:(NSInteger)anInteger
{
	self = [self initWithType:DKMetadataTypeInteger];
	if (self) {
		[self assignValue:@(anInteger)];
	}

	return self;
}

- (instancetype)initWithReal:(CGFloat)aReal
{
	self = [self initWithType:DKMetadataTypeReal];
	if (self) {
		[self assignValue:@(aReal)];
	}

	return self;
}

- (instancetype)initWithBoolean:(BOOL)aBool
{
	self = [self initWithType:DKMetadataTypeBoolean];
	if (self) {
		[self assignValue:@(aBool)];
	}

	return self;
}

- (instancetype)initWithUnsigned:(NSUInteger)anInteger
{
	self = [self initWithType:DKMetadataTypeUnsignedInt];
	if (self) {
		[self assignValue:@(anInteger)];
	}

	return self;
}

- (instancetype)initWithAttributedString:(NSAttributedString*)attrString
{
	self = [self initWithType:DKMetadataTypeAttributedString];
	if (self) {
		[self assignValue:attrString];
	}

	return self;
}

- (instancetype)initWithImage:(NSImage*)image
{
	self = [self initWithType:DKMetadataTypeImage];
	if (self) {
		[self assignValue:image];
	}

	return self;
}

- (instancetype)initWithImageData:(NSData*)imageData
{
	self = [self initWithType:DKMetadataTypeImageData];
	if (self) {
		[self assignValue:imageData];
	}

	return self;
}

- (instancetype)initWithURL:(NSURL*)url
{
	self = [self initWithType:DKMetadataTypeURL];
	if (self) {
		[self assignValue:url];
	}

	return self;
}

- (instancetype)initWithDate:(NSDate*)date
{
	self = [self initWithType:DKMetadataTypeDate];
	if (self) {
		[self assignValue:date];
	}

	return self;
}

- (instancetype)initWithColour:(NSColor*)colour
{
	self = [self initWithType:DKMetadataTypeColour];
	if (self) {
		[self assignValue:colour];
	}

	return self;
}

- (instancetype)initWithData:(NSData*)data
{
	self = [self initWithType:DKMetadataTypeData];
	if (self) {
		[self assignValue:data];
	}

	return self;
}

- (instancetype)initWithSize:(NSSize)size
{
	self = [self initWithType:DKMetadataTypeSize];
	if (self) {
		[self assignValue:NSStringFromSize(size)];
	}

	return self;
}

- (instancetype)initWithPoint:(NSPoint)point
{
	self = [self initWithType:DKMetadataTypePoint];
	if (self) {
		[self assignValue:NSStringFromPoint(point)];
	}

	return self;
}

- (instancetype)initWithRect:(NSRect)rect
{
	self = [self initWithType:DKMetadataTypeRect];
	if (self) {
		[self assignValue:NSStringFromRect(rect)];
	}

	return self;
}

#pragma mark -

- (void)setValue:(id)value
{
	// sets the current value, always converting it to the current type, lossily maybe.

	[self assignValue:[self valueWithCurrentType:value]];
}

- (id)value
{
	return mValue;
}

- (void)takeObjectValueFrom:(id)sender
{
	if ([sender respondsToSelector:@selector(objectValue)])
		[self setValue:[sender objectValue]];
}

- (id)objectValue
{
	return [self value];
}

- (void)setType:(DKMetadataType)type
{
	if (type != [self type]) {
		// convert value to the new type

		id newVal = [self convertValue:[self value]
								toType:type
							  wasLossy:NULL];
		mType = type;
		[self assignValue:newVal];
	}
}

- (DKMetadataType)type
{
	return mType;
}

- (NSString*)typeDisplayName
{
	return [[self class] localizedDisplayNameForType:[self type]];
}

- (BOOL)isLossyConversionToType:(DKMetadataType)type
{
	// predicts if a conversion to <type> will succeed. Note that 'lossy' is somewhat vague - some conversions will succeed to an extent
	// but will incur some loss. (e.g. attributed string -> string loses the attributes) but will return NO from here. This really predicts
	// a complete failure to convert, i.e. the conversion is probably nonsensical. You might use this to disable conversions in a UI where
	// a complete inability to convert would occur.

	if (type == [self type])
		return NO;
	else {
		BOOL lossy = NO;
		[self convertValue:[self value]
					toType:type
				  wasLossy:&lossy];

		return lossy;
	}
}

- (DKMetadataItem*)metadataItemWithType:(DKMetadataType)type
{
	// returns a new metadata item having the same value as the receiver, converted to <type>. If <type> is the current type, self is returned.
	// Take care to ensure that this doesn't lead to inadvertent sharing of an item.

	if (type == [self type])
		return self;
	else {
		DKMetadataItem* item = [[[self class] alloc] initWithType:type];
		id valCopy = [[self value] copy];
		[item setValue:valCopy];

		return item;
	}
}

- (NSString*)stringValue
{
	return [self convertValue:[self value]
					   toType:DKMetadataTypeString
					 wasLossy:NULL];
}

- (NSAttributedString*)attributedStringValue
{
	return [self convertValue:[self value]
					   toType:DKMetadataTypeAttributedString
					 wasLossy:NULL];
}

- (int)intValue
{
	return [[self convertValue:[self value]
						toType:DKMetadataTypeInteger
					  wasLossy:NULL] integerValue];
}

- (NSInteger)integerValue
{
	return [[self convertValue:[self value]
						toType:DKMetadataTypeInteger
					  wasLossy:NULL] integerValue];
}

- (float)floatValue
{
	return [[self convertValue:[self value]
						toType:DKMetadataTypeReal
					  wasLossy:NULL] doubleValue];
}

- (double)doubleValue
{
	return [[self convertValue:[self value]
						toType:DKMetadataTypeReal
					  wasLossy:NULL] doubleValue];
}

- (BOOL)boolValue
{
	return [[self convertValue:[self value]
						toType:DKMetadataTypeBoolean
					  wasLossy:NULL] boolValue];
}

- (NSColor*)colourValue
{
	return [self convertValue:[self value]
					   toType:DKMetadataTypeColour
					 wasLossy:NULL];
}

- (NSSize)sizeValue
{
	return NSSizeFromString([self convertValue:[self value]
										toType:DKMetadataTypeSize
									  wasLossy:NULL]);
}

- (NSPoint)pointValue
{
	return NSPointFromString([self convertValue:[self value]
										 toType:DKMetadataTypePoint
									   wasLossy:NULL]);
}

- (NSRect)rectValue
{
	return NSRectFromString([self convertValue:[self value]
										toType:DKMetadataTypeRect
									  wasLossy:NULL]);
}

- (NSData*)data
{
	return [NSKeyedArchiver archivedDataWithRootObject:self];
}

- (BOOL)writeToPasteboard:(NSPasteboard*)pb
{
	NSAssert(pb != nil, @"can't write to nil pasteboard");

	[pb addTypes:@[DKSingleMetadataItemPBoardType]
		   owner:self];
	return [pb setData:[self data]
			   forType:DKSingleMetadataItemPBoardType];
}

#pragma mark -

- (void)assignValue:(id)aValue
{
	// sets the current value ignoring type and without notifying

	mValue = aValue;
}

- (id)valueWithCurrentType:(id)inValue
{
	return [self convertValue:inValue
					   toType:[self type]
					 wasLossy:NULL];
}

- (id)convertValue:(id)inValue toType:(DKMetadataType)type wasLossy:(BOOL*)lossy
{
	// if the class already matches the current type, no conversion necessary

	if (lossy)
		*lossy = NO;

	if ([inValue isKindOfClass:[[self class] classForType:type]]) {
		// numbers are tricky, as they match on class type but not necessarily on what they actually encode. Thus NSNumbers are passed
		// on to the cnversion routines regardless.

		if (![inValue isKindOfClass:[NSNumber class]])
			return inValue;
	}

	// if <inValue> is another metadata item, return a copy of its value if the type matches

	if ([inValue isKindOfClass:[self class]]) {
		DKMetadataType inType = [(DKMetadataItem*)inValue type];
		if (inType == [self type])
			return [[inValue value] copy];
	}

	// conversion is necessary, but may not succeed:

	switch (type) {
	case DKMetadataTypeString:
		if ([inValue respondsToSelector:@selector(string)])
			return [inValue string];
		else if ([inValue respondsToSelector:@selector(stringValue)])
			return [inValue stringValue];
		else if ([inValue respondsToSelector:@selector(hexString)])
			return [inValue hexString];
		else {
			if (lossy)
				*lossy = YES;

			return @""; // unable to convert to string, return the empty string
		}

	case DKMetadataTypeUnsignedInt:
	case DKMetadataTypeInteger:
		if ([inValue respondsToSelector:@selector(integerValue)])
			return @([inValue integerValue]);
		else {
			if (lossy)
				*lossy = YES;

			return @0; // unable to convert - return 0
		}

	case DKMetadataTypeBoolean:
		if ([inValue respondsToSelector:@selector(boolValue)])
			return @([inValue boolValue]);
		else if ([inValue respondsToSelector:@selector(integerValue)])
			return @((BOOL)([inValue integerValue] != 0));
		else {
			if (lossy)
				*lossy = YES;

			return @NO; // unable to convert - return NO
		}

	case DKMetadataTypeReal:
		if ([inValue respondsToSelector:@selector(doubleValue)])
			return @([inValue doubleValue]);
		else if ([inValue respondsToSelector:@selector(doubleValue)])
			return @([inValue doubleValue]);
		else {
			if (lossy)
				*lossy = YES;

			return @0.0; // unable to convert - return 0
		}

	case DKMetadataTypeColour:
		if ([inValue respondsToSelector:@selector(colorValue)])
			return [inValue colorValue];
		else if ([inValue respondsToSelector:@selector(colourValue)])
			return [inValue colourValue];
		else if ([inValue respondsToSelector:@selector(doubleValue)])
			return [NSColor colorWithCalibratedWhite:[inValue doubleValue]
											   alpha:1.0];
		else {
			if (lossy)
				*lossy = YES;

			return [NSColor blackColor]; // unable to convert - return black
		}

	case DKMetadataTypeURL:
		if ([inValue respondsToSelector:@selector(url)])
			return [inValue url];
		else if ([inValue respondsToSelector:@selector(stringValue)])
			return [NSURL URLWithString:[inValue stringValue]];
		else if ([inValue isKindOfClass:[NSString class]])
			return [NSURL URLWithString:inValue];
		else {
			if (lossy)
				*lossy = YES;

			return nil; // unable to convert to URL
		}

	case DKMetadataTypeDate:
		if ([inValue respondsToSelector:@selector(dateValue)])
			return [inValue dateValue];
		else if ([inValue respondsToSelector:@selector(date)])
			return [inValue date];
		else if ([inValue respondsToSelector:@selector(stringValue)])
			return [NSDate dateWithNaturalLanguageString:[inValue stringValue]];
		else if ([inValue isKindOfClass:[NSString class]])
			return [NSDate dateWithNaturalLanguageString:inValue];
		else if ([inValue respondsToSelector:@selector(doubleValue)])
			return [NSDate dateWithTimeIntervalSinceReferenceDate:[inValue doubleValue]];
		else {
			if (lossy)
				*lossy = YES;

			return [NSDate dateWithTimeIntervalSinceReferenceDate:0]; //unable to convert - return ref date
		}

	case DKMetadataTypeData:
		if ([inValue respondsToSelector:@selector(data)])
			return [inValue data];
		else if ([inValue isKindOfClass:[NSURL class]])
			return [NSData dataWithContentsOfURL:inValue];
		else if ([inValue isKindOfClass:[NSString class]])
			return [NSData dataWithContentsOfFile:inValue];
		else if ([inValue conformsToProtocol:@protocol(NSCoding)])
			return [NSKeyedArchiver archivedDataWithRootObject:inValue];
		else {
			if (lossy)
				*lossy = YES;

			return [NSData data]; // no conversion possible, return empty data
		}

	case DKMetadataTypeImage:
		if ([inValue respondsToSelector:@selector(image)])
			return [inValue image];
		else if ([inValue isKindOfClass:[NSData class]])
			return [[NSImage alloc] initWithData:inValue];
		else if ([inValue isKindOfClass:[NSURL class]])
			return [[NSImage alloc] initWithContentsOfURL:inValue];
		else if ([inValue isKindOfClass:[NSString class]])
			return [[NSImage alloc] initWithContentsOfFile:inValue];
		else {
			if (lossy)
				*lossy = YES;

			return nil;
		}

	case DKMetadataTypeImageData:
		if ([inValue respondsToSelector:@selector(imageData)])
			return [inValue imageData];
		else if ([inValue respondsToSelector:@selector(data)])
			return [inValue data];
		else if ([inValue isKindOfClass:[NSURL class]])
			return [NSData dataWithContentsOfURL:inValue];
		else if ([inValue isKindOfClass:[NSString class]])
			return [NSData dataWithContentsOfFile:inValue];
		else if ([inValue conformsToProtocol:@protocol(NSCoding)])
			return [NSKeyedArchiver archivedDataWithRootObject:inValue];
		else {
			if (lossy)
				*lossy = YES;

			return [NSData data]; // no conversion possible
		}

	case DKMetadataTypeAttributedString:
		if ([inValue respondsToSelector:@selector(attributedString)])
			return [inValue attributedString];
		else if ([inValue isKindOfClass:[NSString class]])
			return [[NSAttributedString alloc] initWithString:inValue];
		else if ([inValue respondsToSelector:@selector(stringValue)])
			return [[NSAttributedString alloc] initWithString:[inValue stringValue]];
		else {
			if (lossy)
				*lossy = YES;

			return [[NSAttributedString alloc] initWithString:@""];
		}

	case DKMetadataTypeSize:
		if ([inValue respondsToSelector:@selector(size)])
			return NSStringFromSize([inValue size]);
		else if ([inValue respondsToSelector:@selector(sizeValue)])
			return NSStringFromSize([inValue sizeValue]);
		else if ([inValue isKindOfClass:[NSString class]])
			return NSStringFromSize(NSSizeFromString(inValue));
		else {
			if (lossy)
				*lossy = YES;

			return NSStringFromSize(NSZeroSize); // unable to convert
		}

	case DKMetadataTypePoint:
		if ([inValue respondsToSelector:@selector(point)])
			return NSStringFromPoint([inValue point]);
		else if ([inValue respondsToSelector:@selector(pointValue)])
			return NSStringFromPoint([inValue pointValue]);
		else if ([inValue isKindOfClass:[NSString class]])
			return NSStringFromPoint(NSPointFromString(inValue));
		else {
			if (lossy)
				*lossy = YES;

			return NSStringFromPoint(NSZeroPoint); // unable to convert
		}

	case DKMetadataTypeRect:
		if ([inValue respondsToSelector:@selector(rect)])
			return NSStringFromRect([inValue rect]);
		else if ([inValue respondsToSelector:@selector(rectValue)])
			return NSStringFromRect([inValue rectValue]);
		else if ([inValue isKindOfClass:[NSString class]])
			return NSStringFromRect(NSRectFromString(inValue));
		else {
			if (lossy)
				*lossy = YES;

			return NSStringFromRect(NSZeroRect); // unable to convert
		}

	default:
			NSLog(@"an unknown type (%ld) was passed to DKMetadataItem <%@> for conversion, value = %@", (long)type, self, inValue);
		break;
	}

	if (lossy)
		*lossy = YES;

	return nil; // unable to convert
}

#pragma mark -
#pragma mark - as a NSObject

- (instancetype)init
{
	return [self initWithString:@""];
}

- (id)copyWithZone:(NSZone*)zone
{
	// copy always returns a mutable, independent copy. See also -metadataItemWithType:

	DKMetadataItem* copy = [[[self class] allocWithZone:zone] initWithType:[self type]];
	id valCopy = [[self value] copy];
	[copy assignValue:valCopy];

	return copy;
}

- (instancetype)initWithCoder:(NSCoder*)aDecoder
{
	self = [super init];
	if (self) {
		[self setType:[aDecoder decodeIntegerForKey:@"DKMetadataItem_type"]];
		[self assignValue:[aDecoder decodeObjectForKey:@"DKMetadataItem_value"]];
	}

	return self;
}

- (void)encodeWithCoder:(NSCoder*)aCoder
{
	[aCoder encodeInteger:[self type]
				   forKey:@"DKMetadataItem_type"];
	[aCoder encodeObject:[self value]
				  forKey:@"DKMetadataItem_value"];
}

- (BOOL)isEqual:(id)obj
{
	if (obj == self)
		return YES;
	else {
		if ([obj isKindOfClass:[self class]]) {
			if ([(DKMetadataItem*)obj type] == [self type])
				return [[obj value] isEqual:[self value]];
		}
	}

	return NO;
}

- (NSString*)description
{
	return [NSString stringWithFormat:@"%@ Type:%@ Value:%@", [super description], [self typeDisplayName], [self value]];
}

@end
