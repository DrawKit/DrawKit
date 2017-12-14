/**
 @author Contributions from the community; see CONTRIBUTORS.md
 @date 2005-2016
 @copyright MPL2; see LICENSE.txt
*/

#import "DKImageDataManager.h"
#import "DKUniqueID.h"
#import "DKKeyedUnarchiver.h"

NSString* kDKImageDataManagerPasteboardType = @"net.apptree.drawkit.imgdatamgrtype";

@interface DKImageDataManager ()

/** hash list maps hash (or checksum) -> key, so is inverse to repository. As it can be built from the repo, it is safer to do this following dearchiving
 rather than archive the hash list itself. Earlier versions did archive the hash list but that data can be ignored.
*/
- (void)buildHashList;

@end

@implementation DKImageDataManager

- (NSData*)imageDataForKey:(NSString*)key
{
	return [mRepository objectForKey:key];
}

- (void)setImageData:(NSData*)imageData forKey:(NSString*)key
{
	NSAssert(imageData != nil, @"cannot set nil image data");

	//NSLog(@"%@ set data (%d bytes), key = %@", self, [imageData length], key);

	[mRepository setObject:imageData
					forKey:key];
	[mHashList setObject:key
				  forKey:[imageData checksumString]];
}

- (BOOL)hasImageDataForKey:(NSString*)key
{
	return ([mRepository objectForKey:key] != nil);
}

- (NSString*)keyForImageData:(NSData*)imageData
{
	// if the imagedata is known to the repository, its key is returned, otherwise nil.

	if (imageData)
		return [mHashList objectForKey:[imageData checksumString]];
	else
		return nil;
}

- (NSString*)generateKey
{
	return [DKUniqueID uniqueKey];
}

- (NSArray*)allKeys
{
	return [mRepository allKeys];
}

- (void)removeKey:(NSString*)key
{
	// removes the key and all data associated with it

	NSData* data = [self imageDataForKey:key];

	if (data) {
		NSString* cs = [data checksumString];
		[mHashList removeObjectForKey:cs];
	}

	[mRepository removeObjectForKey:key];
}

- (NSImage*)makeImageWithData:(NSData*)imageData key:(NSString**)key
{
	// if <imageData> exists in the repository, it is used to make an image which is returned. If <key> is not NULL, the key is returned. If the image data is
	// not already in the repository, it is added using a new key. The resulting image and new key are returned. This is used when you have imageData.

	NSAssert(imageData != nil, @"cannot create image from nil data");

	NSString* theKey = [self keyForImageData:imageData];

	if (theKey == nil) {
		// not known, so store the data using a new key

		theKey = [self generateKey];
		[self setImageData:imageData
					forKey:theKey];
	}

	// return the key

	if (key != NULL)
		*key = theKey;

	// create and return the image

	return [[NSImage alloc] initWithData:imageData];
}

- (NSImage*)makeImageWithPasteboard:(NSPasteboard*)pb key:(NSString**)key
{
	// create an image, if possible, from the pasteboard. This first tries to see if the pasteboard contains our private image key type, and if so
	// uses that. Otherwise it extracts the data and proceeds conventionally.

	NSData* imageData = nil;
	NSString* privateType = [pb availableTypeFromArray:@[kDKImageDataManagerPasteboardType]];

	if (privateType) {
		// could be already cached by this - may not be, because it could have come from a different document, but will be here if the same
		// document.

		NSString* theKey = [pb stringForType:kDKImageDataManagerPasteboardType];

		if ([self hasImageDataForKey:theKey]) {
			imageData = [self imageDataForKey:theKey];
			if (key != NULL)
				*key = theKey;

			return [[NSImage alloc] initWithData:imageData];
		}
	}

	// if here, just read the pb in the conventional way, caching the data here as we go

	if ([NSImage canInitWithPasteboard:pb]) {
		// first see if it's a URL

		NSURL* fileURL = [NSURL URLFromPasteboard:pb];

		if (fileURL)
			return [self makeImageWithContentsOfURL:fileURL
												key:key];
		else {
			NSString* imageType = [pb availableTypeFromArray:[NSImage imagePasteboardTypes]];

			if (imageType) {
				imageData = [pb dataForType:imageType];
				return [self makeImageWithData:imageData
										   key:key];
			}
		}
	}
	return nil;
}

- (NSImage*)makeImageWithContentsOfURL:(NSURL*)url key:(NSString**)key
{
	// read the data from the URL and proceed as for the data case

	NSData* data = [NSData dataWithContentsOfURL:url];
	return [self makeImageWithData:data
							   key:key];
}

- (NSImage*)makeImageForKey:(NSString*)key
{
	NSData* imageData = [self imageDataForKey:key];

	if (imageData)
		return [[NSImage alloc] initWithData:imageData];
	else
		return nil;
}

- (void)setKey:(NSString*)key isInUse:(BOOL)inUse
{
	if ([self hasImageDataForKey:key]) {
		NSInteger useCount = [[mKeyUsage objectForKey:key] integerValue];

		if (inUse) {
			++useCount;
		} else {
			--useCount;
		}

		// protect against over-decrementing

		if (useCount < 0)
			useCount = 0;

		[mKeyUsage setObject:@(useCount)
					  forKey:key];
	}
}

- (BOOL)keyIsInUse:(NSString*)key
{
	return [[mKeyUsage objectForKey:key] integerValue] > 0;
}

- (void)removeUnusedData
{
	// delete all data and associated keys for keys not in use

	NSArray<NSString*>* keys = [[self allKeys] copy];

	for (NSString *key in keys) {
		if (![self keyIsInUse:key]) {
			[self removeKey:key];
		}
	}
}

- (void)buildHashList
{
	[mHashList removeAllObjects];

	for (NSString *key in mRepository) {
		NSData* data = [mRepository objectForKey:key];
		[mHashList setObject:key
					  forKey:[data checksumString]];
	}
}

#pragma mark -

- (instancetype)init
{
	self = [super init];
	if (self) {
		mRepository = [[NSMutableDictionary alloc] init];
		mHashList = [[NSMutableDictionary alloc] init];
		mKeyUsage = [[NSMutableDictionary alloc] init];
	}

	return self;
}

- (void)encodeWithCoder:(NSCoder*)coder
{
	[coder encodeObject:mRepository
				 forKey:@"DKImageDataManager_repo"];
}

- (instancetype)initWithCoder:(NSCoder*)coder
{
	if (self = [super init]) {
	mRepository = [[coder decodeObjectForKey:@"DKImageDataManager_repo"] mutableCopy];
	mHashList = [[NSMutableDictionary alloc] init];

	// hash list is built from repository, so there is no need to archive it.

	[self buildHashList];

	// key usage isn't archived, will manage itself as clients make use of the object

	mKeyUsage = [[NSMutableDictionary alloc] init];

	// if the coder can keep a note of the image manager, set it to self (on the basis that only one image manager should
	// exist per archive, therefore this must be it)

	if ([coder respondsToSelector:@selector(setImageManager:)])
		[(DKKeyedUnarchiver*)coder setImageManager:self];
	}
	
	return self;
}

- (NSString*)description
{
	return [NSString stringWithFormat:@"%@, keys = %@", [super description], [self allKeys]];
}

@end

#pragma mark -

@implementation NSData (Checksum)

- (NSUInteger)checksum
{
	NSUInteger sum = 0, weight = 0;
	unsigned char* p = (unsigned char*)[self bytes];
	NSInteger bc = MIN((NSInteger)[self length], 1024);

	while (bc--)
		sum += (*p++ * ((++weight % 17) + 1));

	sum ^= [self length];

	//NSLog(@"<%p> checksum: %d", self, sum );

	return sum;
}

- (NSString*)checksumString
{
	return [NSString stringWithFormat:@"%ld", (long)[self checksum]];
}

@end
