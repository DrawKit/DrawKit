Data handling
-------------

Drawkit is able to archive its entire state and return it to you as `NSData`. Conversely, it is able to be instantiated complete from a suitably formatted `NSData`. By saving the data to disk you can save and open a complete drawing. Because DrawKit uses the `NSKeyedArchiver` and `NSKeyedUnarchiver`, its format is fairly well insulated from future changes and features added to DrawKit - and it's easy to accommodate older forms automatically when new versions of DK are released, and older versions will ignore new keys added by more recent versions. So in general DK's forrmat is robust and easily adapted and extended without impacting on compatibility.

You can of course simply add DK's data to some other data you are reading and writing, or just rely on supporting `NSCoding` for new objects that you add within DK.

`DKDrawingDocument` simply reads and writes DrawKit's data as its complete file type, with a .drawing extension and a UTI of net.apptree.drawing