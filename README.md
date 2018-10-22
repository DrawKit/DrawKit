# DrawKit [![Build Status](https://travis-ci.org/DrawKit/DrawKit.png?branch=master)](https://travis-ci.org/DrawKit/DrawKit) [![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage) ![podspec Version](https://cocoapod-badges.herokuapp.com/v/DrawKit/badge.png) ![podspec Platform](https://cocoapod-badges.herokuapp.com/p/DrawKit/badge.png)

DrawKit is an illustration and vector artwork framework for macOS. See http://drawkit.github.io for full documentation and a getting started guide.

## Quick Start

Using Terminal.app on macOS, clone the DrawKit project and open the [first example](https://github.com/DrawKit/DrawKit/tree/master/Examples) in Xcode:

```
git clone https://github.com/DrawKit/DrawKit DrawKit
open DrawKit/Examples/0-no-code/drawkit-no-code.xcodeproj
```

> Try pasting in text or dragging an image onto the canvas of the no code example application.

## DrawKit Demos

For a full demonstration of DrawKit, try the [DrawDemo](https://github.com/DrawKit/legacy-DrawKit-demo/releases/download/1.0b7/DrawDemo_app_b7.zip) application. Complete with [source code](https://github.com/DrawKit/legacy-DrawKit-demo) this application highlights what is possible with DrawKit.

[DKMiniDemo](https://github.com/DrawKit/legacy-DrawKit-mini-demo/releases/download/v1.5/DKMiniDemo-1.5.zip) and [source code](https://github.com/DrawKit/legacy-DrawKit-mini-demo)  are great for learning about DrawKit.

## How We Work Together / Contributing

This project is maintained thanks to the contributors who send pull requests. [@grahammiln](https://miln.eu) typically deals with administrative tasks and contributors do the rest.

We will merge any pull request that adds something useful and does not break existing code, and will often grant commit access to the repository.

If you're an active user and want to be a maintainer, please get in touch.

DrawKit needs your help! There are numerous warnings to address and minor updates needed. Pick something easy and make a difference. Please help maintain and support this incredible framework.

## Package Managers

Carthage and CocoaPods are dependency managers. They aim to help automate and simplify the use of 3rd-party libraries like [DrawKit](https://drawkit.github.io/) in your Xcode projects.

### Carthage

For [Carthage](https://github.com/Carthage/Carthage), append the following to your project's `Cartfile`:

```
github "DrawKit/DrawKit" 
```

### CocoaPods

For [CocoaPods](https://github.com/CocoaPods/CocoaPods), append the following to your project's `Podfile`:

```ruby
platform :osx, '10.7'
pod "DrawKit"
```

# Overview

DrawKit is a software framework that enables the macOS Cocoa developer to rapidly implement vector drawing and illustration features in a custom application. It is comprehensive, powerful and complete, but it is also highly modular so you can make use of only those parts that you need, or go the whole hog and drop it in as a complete vector drawing solution.

![DrawKit sample capabilities](https://raw.githubusercontent.com/DrawKit/DrawKit/master/Documentation/drawkit-sample-capabilities.png)

Taking its cue from Cocoa's powerful text handling model, DrawKit provides a general purpose and complete drawing model that can be deployed with very little (or in the most general case, no) code at all. The defaults for most classes and created objects have been selected to give a working system out of the box with minimal set up. As you might expect, the more your requirements deviate from the defaults, the more customising you will need to do, but DrawKit has been designed to make this as straightforward as possible without compromising on the graphical power available. Many classes can be operated in a variety of modes for the most obvious of customisations, and can of course be subclassed when necessary to provide more divergent behaviour.

Where possible, familiar Cocoa idioms and conventions are used to ensure that the Cocoa developer will be able to start using DrawKit as if it were a natural extension of the standard Cocoa frameworks (which in a way, of course, it is).

Generally speaking, DrawKit provides the following:

* A general-purpose "drawing" data model consisting of unlimited layers organised hierarchically.
* Separation into model, view and controller classes gives genuine architectural flexibility
* Built-in classes for shapes and path objects, and various derivations of them to cover most typical needs.
* Standard grid and guide layers supporting object snapping and any "real world" measurement system you need.
* Built-in selection of objects and targeting of the selection for commands and user events.
* Separation of an object's geometry from its appearance gives incredible flexibility for creating exciting graphics.
* Attachment of unlimited arbitrary user data to all objects.
* Style objects can be optionally shared by multiple objects, and contain an entire tree of rasterizers for drawing. This goes way beyond the classic "one stroke and one fill per object" that many drawing applications adopt (though if this is what you want it's easy to implement).
* Built-in gradients, vector pattern fills and hatches.
* Interactively edit any bezier path.
* Image objects support all the formats that Cocoa itself supports.
* Text objects.
* Group objects to any degree of nesting. Groups can be rotated, scaled and moved like any shape.
* Many path operations including boolean (set) operations (requires the inclusion of additional code).
* Tool-based drawing, editing and selection operations.
* Export to PDF or any raster image format, as well as its own keyed archive format.
* Built-in Undo.
* Supports multiple views and multiple view classes.
* Various caching and quality modulating techniques to improve performance when interacting directly.

DrawKit is a moderately large framework but its architecture is straightforward. While you won't be able to learn it in half an hour, it is designed to be easy to deploy and get working with minimal configuration or fuss.

DrawKit does NOT provide a user interface except that of direct manipulation of objects, which is highly customisable. It is intended to form the core of an application or perhaps find a subsidiary role - it is not in and of itself a drawing application. Some classes are provided to help get started with building a GUI for DrawKit, such as a basic document class and a base class for an inspector type of controller.

As its name suggests, DrawKit is a kit - some assembly is required. However getting a "bare bones" system up and running should be very easy, which is intended to give the programmer confidence in the default operation of the framework, providing an excellent starting point for customising and extending DrawKit to suit your own applications' needs.

## License

DrawKit is [MPL2 licensed](https://github.com/DrawKit/DrawKit/blob/master/LICENSE.txt). This licence means **DrawKit can be used within open source and commercial software**, including products distributed on the Mac App Store.

## History

Originally based on, and forked from, [DrawKit 1.0b7 (2010/05/01) source code](http://www.apptree.net/drawkitmain.htm) by [Graham Cox](http://apptree.net/about.htm).

## Maintainers

See [CONTRIBUTORS](https://github.com/DrawKit/DrawKit/blob/master/CONTRIBUTORS.md) for a list of code level contributors.

 - [Graham Miln](https://theworklife.com) ([@grahammiln](https://twitter.com/grahammiln)) / [miln.eu](https://miln.eu)
