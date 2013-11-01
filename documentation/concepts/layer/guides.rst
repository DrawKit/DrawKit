Guides Layer
============

Guides are implemented using `DKGuideLayer`. Again, the use of a separate layer allows you to easily place the layer relative to your other content (Z- order) as you wish. You can have any number of guides, positioned anywhere. Guides are typically set up so that they have a slightly stronger "pull" for snapping than the grid does, so guides will tend to have a more obvious snapping action. However, DrawKit will in fact use the nearest grid or guide to a given point, so guides should not prevent you from positioning objects to either.

DrawKit provides the convenient way to create guides common to many graphics applications of simply dragging a new guide off one of the rulers. This works whether or not the guide layer is active. However, repositioning an existing guide requires that the layer be first made active. You can also snap a guide to the grid when dragging it by holding the shift key, even if the grid snapping is otherwise turned off. To remove a guide, drag it out of the interior area of the drawing and into a margin - that will delete it.

Each guide can have its own colour, though by default they are initially set up to take their colour from the layer's setting. If this is changed, all guides will be updated to use the new colour.

Generally DrawKit is designed to have a single guide layer. If you want to change the guide set according to the active layer or some other state change, you will need to arrange this. The -guides and -setGuides: methods allow you to set multiple guides in one call.
