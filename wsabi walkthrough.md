##Major structure

###Really, really high level.
* UI: The whole thing is a table view. 
	* Each row represents one person, including biometrics and biographical info. Those rows have GMGridViews in them; each capture item is a grid view cell.
* Data Model: it's really simple. The database is a bunch of WSCDPerson objects, each of which can have 0 or more WSCDItems (biometric data items). Each of those items has one WSCDDeviceDefinition, which contains the network information that will be used to capture data for that item.
* Network: All communication between the app and its sensors takes place through the NBCLDeviceLinkManager and its NBCLDeviceLinks. Each link represents a connection to one URI, although there can be two links to the same URI with different names.
	* When a person's row is selected, all links in that row try to connect to their sensors.  
	* When the user taps on an item, that item's device link tries to configure itself (in case configure takes a while). If the link isn't initialized, it tries to go back through the full connect/configure sequence while opening the popover.
	* Once the link is available for use, the capture popover presents the user with the animated hand graphic.
* Notifications: whenever possible (well, whenever time permitted), the app uses notifications to handle interactions between the UI and the sensor. 
	* e.g.1, When a download arrives, the link manager fires a notification with the image included and a pointer to the data item that initially requested that download. All of the little grid cells check to see if they match the item, and if so, they use the image.
	* e.g.2, when the user wants to edit sensor properties, rather than bringing up the sensor configuration walkthrough directly, a notification is fired. The main view controller catches it, performs some cleanup, and then brings up the sensor walkthrough. This prevents any other class that wants to call the walkthrough from having to include a whole bunch of extra include files and logic.
* It's an optimistic UI. The intent is to avoid notifying the user of issues until it's something that directly affects their workflow.
* Debugging note: NSZombie is ENABLED for the wsabi app target. That means that if the app tries to access a deallocated object, rather than just crashing, XCode will tell you and show you what the message was that triggered the error. This is awesome, but hits performance, so turn it off once you're building a release build.
* `constants.h` has... constants.

###Categories
* This has all of the Objective-C categories (equiv to extension methods) for all of wsabi.
	* `NSManagedObject+DeepCopy` is (theoretically) a way to deep copy any Core Data object. It kind of works.
	* `NSObject+GCDBlocks` is a convenience method to execute a block of code after a delay.
	* `UIView+FirstResponder` will find any first responder within the specified view's subview hierarchy.
	* `UIView+FindUIViewController` goes up the superview chain to find the UIViewController that contains this view.
	* `UIView+Logging` contains all of the logging behavior available to the system.
		* `startAutomaticGestureLogging` will configure a given view (and optionally all of its subviews) to listen for taps and pinch gestures.
		* `addLongPressGestureLogging` adds...long press gesture logging. Ta da! :-)
		* There are also a lot of manual logging methods available which include relevant information (things like `logScrollStarted`, which include the scroll offset in the log statement)
	* `UIImage+NBCLExtras` has a method to resize images in a way that is slower, but more reliable, than the method used in the other UIImage categories.
	* The other UIImage categories are all from [this blog post](http://vocaro.com/trevor/blog/2009/10/12/resize-a-uiimage-the-right-way/)
		* They give us various capabilites, like producing thumbnail images with rounded corners, resizing images, etc.
		* They are not very good at dealing with certain types of images, including some bitmaps generated by WPF.
	* `UIView+FlipTransition` adds a class method to flip between two UIViews, and optionally run a block after completion of the transition.

###Images
* All of the images for the program are in here.
* Retina images are tagged with an @2x extension (so, moose.png and moose@2x.png will both be used depending on system requirements)
* A number of images are used as "stretchable" images by the app. An example is BreadcrumbButton.png. We specify a top and left "cap" size that isn't allowed to be stretched, and then iOS stretches the next vertical and horizontal pixel to the necessary size (so that the other edge of the image stays intact also).
* The Symbolicons subgroup contains icons from the Symbolicons set, which we purchased from [Symbolicons.com](http://www.symbolicons.com) (Pat has login & license info)
* The "from iOS SDK" images are extracted from the iOS SDK using a tool called [UIKit-Artwork-Extractor](https://github.com/0xced/UIKit-Artwork-Extractor)

###Dependencies
* This is (nearly) all of the third-party code we're using. It contains groups for each project.
* [GMGridView](https://github.com/gmoledina/GMGridView) is the internal grid used to lay out and rearrange individual biometric items. It has been modified a teeny bit according to the README file included in that directory.
* asi-http-request is the library used to handle network communication. It hadn't been updated to ARC-compatibility, so we've turned off ARC for those files
* ActionSheetPicker is used for the biographical data panels choice items (hair color, etc.)
* [ELCTextFieldCell](https://github.com/elc/ELCTextFieldCell)
    * MODIFICATION NOTE: Had to update this for ARC compatibility
	* Added delegate calls for greater interaction with the right text field.
* [Lumberjack](https://github.com/robbiehanson/CocoaLumberjack) is used for logging

###Data Model
* This contains the Core Data model (`wsabi2.xcdatamodeld`) and the generated classes from that model (so that we can enforce typing and method names on the classes in the data model)
* Any time you change the data model, you've got to delete and regenerate those classes.

###Network communication
* This is where all of the classes used to talk to the device live.
* AVCam Demo is a good starting point for live preview; it's used in `NBCLInternalCameraSensorLink`, which really hasn't been updated for wsabi2 and is unlikely to work without modification.
* `NBCLDeviceLinkConstants.h` has constants that are specific to the network communication.
* `NBCLDeviceLink` is the class that does most of the heavy lifting. It's responsible for creating and processing each network operation, and notifying its delegate (the `NBCLDeviceLinkManager`) when things either work or don't.
* `NBCLDeviceLinkManager` is a singleton (effectively) responsible for creating and maintaining device links. When the UI wants a new device connection, it asks the `NBCLDeviceLinkManager` for a link at a given URI. The manager returns one, initializing it first if necessary.
* `NBCLXMLMap` handles *extremely* basic serialization/deserialization mappings between Objective-C types and XML types
* `WSModalityMap` handles mappings between the integers used to represent modality and sub modality types within wsabi, the specific strings used for parameter names, and display-ready strings for the UI.
* `WSBDResult` is an object representation of the XML result from each WS-BD call. It also has a convenience class method to return a nice string for a given WS-BD status value.
* `WSBDParameter` is similar, but for WSBD parameters. :-)

###Main section
* `ELCTextFieldWide` is a quick hack subclass of ELCTextFieldCell (a dependency) to provide a version that works in wider table view cells.
* `WSBiographicalDataController` is the controller that handles editing and saving biographical data for a given person. It's a table view with a bunch of custom cells, most of which are ELCTextFieldCells, or basic cells that, when tapped, bring up ActionSheetPickers.
* `WSCaptureButton` is a UIButton subclass that handles multiple states, including images and messages for each state, and the ability to show a time-delayed message for some states.
* `WSCaptureController` is what goes in the capture popover. It includes the main capture area, the "front" and "back" sides of the card (annotation stuff is on the back)
* `WSPopoverBackgroundView` defines the look and feel of our custom popover. Feel free to change it. Promptly. The way it works is that you specify a subclass of UIPopoverBackgroundView which will manage the appearance of popovers in your app; we've built this one. Note that this is the only place in the iOS SDK where they handle appearance this way, and it's tricky.
* `WSViewController` is the main view controller for the app. It handles:
	* Displaying the main content (one table view cell per person)
	* Sensor configuration management (starting and stopping the walkthrough)
	* Capture (start and stop)
	* Monitoring the Core Data database for changes and updating/reloading the UI as appropriate (for example, when a new person's record is added, it adds a new row to the table view)
	* Making person-level changes to the database (add, update, duplicate, delete, etc.)

###Device Config Process group
* This is a group of UIViewControllers, each responsible for one step in the sensor setup process (which we're calling the sensor walkthrough).
* __IMPORTANT THING__: When the sensor walkthrough starts for a newly created biometric item, it gets handed a **temporary** `WSCDItem` that isn't part of any managed object context (so it can't be saved). Only if the user successfully completes the walkthrough (i.e., presses the Done button on the last view controller) do we add that object to the main managed object context.
	* When the item gets added, `WSViewController` notices, and reloads the necessary interface items to show the new biometric data item for the current person.
	* If the item **isn't** temporary (i.e., if it does have a managed object context), then each controller has a button in the top right to keep the current settings intact and go to the next step.
* `WSModalityChooserController` just contains a table view, one cell per modality.
* `WSSubmodalityChooserController` just contains a table view, one cell per submodality.
* `WSDeviceChooserController` has a table view with a number of sections. Depending on whether autodiscovery is enabled (which it currently isn't), there may be up to 3: recent sensors, autodiscovered sensors, and an unlabeled section that just has an "Add new sensor" cell in it.
* `WSDeviceSetupController` is responsible for setting the URI used to communicate with a sensor.  
* When the user enters text in the URI text field, the system cancels any existing checks that are in progress, waits 3 seconds, and then calls /info on the requested URI. It uses the metadata dictionary that comes back from the sensor to determine whether:  
	1) the sensor exists at that URI  
	2) the sensor supports the requested modality  
	3) the sensor supports the requested submodality  
	* The statusContainer view (in WSDeviceSetupController.xib) is the view that actually displays the appropriate message to the user.

###Table View Cells group
* This group contains custom table view and grid view cells. `WSPersonTableViewCell` is used by the main view controller to represent one person's record; `WSItemGridCell` is used inside that cell, inside a further grid view, to represent a single biometric item.
* `WSPersonTableViewCell` is pretty complicated. It holds a reference to a `WSCDPerson` data object, and displays all the relevant info for that person. It's also responsible for launching the `WSCaptureController` in a popover when the user taps on a grid cell.
	* It uses the `showCapturePopoverAtIndex:(int)index` method to display the capture popover.
	* When the user asks to delete an individual item from the grid, `WSPersonTableViewCell` handles both removing the object from the Core Data record, and updating the UI to match the change.
	* When the user asks to duplicate or delete the entire record, though, rather than have the row perform those actions on itself, `WSPersonTableViewCell` notifies its delegate, which in our case will be the main `WSViewController`, that the user requested whatever the action was. The main view controller then handles animating the old row out (in the case of deletion), and animating the new row in.

###Supporting Files
* `wsabi2-Info.plist` contains properties related to the app (this is a standard iOS system file)
	* The bundle identifier entry is where we set the app's namespace, which has to match up with the provisioning profile we put on the target device that's going to run the app.
	* There's an entry here to indicate that the app supports filesharing through iTunes.
* `wsabi2-Prefix.pch` includes any stuff to be included in all header files by default. In our case, we added 

		#import <QuartzCore/QuartzCore.h>  
		#import "UIView+Logging.h"  
		#import "NSObject+GCDBlocks.h"  
		
to every file.
