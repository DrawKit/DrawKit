# No Code - DrawKit Example

An example OS X application demonstrating [DrawKit](https://github.com/drawkit/DrawKit) without any additional code.

## Adding DrawKit.framework

The `DrawKit.framework` is embedded into the no code example project:

![Add the DrawKit framework](https://raw.githubusercontent.com/DrawKit/DrawKit/master/example/0-no-code/images/xcode-drawkit-build-phases.png)

A `DKDrawingView` is embedded within an `NSScrollView` within the application's main window:

![Create a DKDrawingView](https://raw.githubusercontent.com/DrawKit/DrawKit/master/example/0-no-code/images/xcode-dkdrawingview.png)

No other changes were made to the template project created by Xcode 6.

## Behaviour

The application demonstrates DrawKit's behaviour without any customisation or configuration.

A set of default layers is created and you are able to right-click, or Control-click on the view to paste in the clipboard. Images can also be dragged from other applications onto the view.

![The no-code example](https://raw.githubusercontent.com/DrawKit/DrawKit/master/example/0-no-code/images/no-code-first-run.png)

![Paste in content](https://raw.githubusercontent.com/DrawKit/DrawKit/master/example/0-no-code/images/no-code-pasted-in-text.png)
