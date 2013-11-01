Subclass Notes
--------------

*This is just a note to self which will help inform the documentation. - Graham Cox*

Creating DKArcPath highlighted a number of things that are necessary to ensure that a subclassed object becomes a full DK citizen. In no particular order:

- Must implement NSCopying and NSCoding in order to allow object to be archived (used for both cut/paste and save to file). Duplicate requires NSCopying as do numerous corners of DK.
- Overriding -drawControlPointsOfPath:usingKnobs: don't forget to pass the state of [self locked] as a knob type flag.
- Don't inset or outset a rect using NSInsetRect when calculating bounds, knob rects or anything else that is sensitive to the view scale. Rects should be modified using ScaleRect or else factor in the view scale. This is because at very high zoom factors you need to ensure that things don't blow up to enormous size.
- Override -pointForPartcode: if necessary and implement it sensibly to support object-object snapping. Same goes for -hitSelectedPart:forSnapDetection: Snapping is easy to support if you use these methods instead of going down a DIY route.
- If subclassing DKDrawablePath, you may need to override notifiyVisualChange to overcome the optimisations that the inherited method performs. You can also substitute optimisations of your own.
- You need to actively handle undo for any properties your class defines that are not inherited and need to be undoable.
- If drawing knobs with DKKnob (you should do), work with the knob size it tells you to use – don't guess and definitely don't outset using NSInsetRect.
- You may need to override -group:willUngroupObjectWithTransform: to allow your object to be correctly ungrouped.
- If you use some other definition of where your "location" is, you need to override -setLocation: and -location. If you implement a variable angle, override -angle and -setAngle:
- Override -snappingPointsWithOffset: if the partcodes/knobs you define differ from the class you're based on.

