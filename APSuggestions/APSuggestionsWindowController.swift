//
//  APSuggestions.swift
//  APSuggestions
//
//  Created by आश्विन पौडेल  on 2021-01-04.
//

import Cocoa

let kTrackerKey = "whichImageView"
public let kSuggestionLabel = "label"
public var APsuggestionCellNib = "APFramworkDefaultCell"

public class APSuggestionsWindowController: NSWindowController {
    public var action: Selector?
    public var target: Any?
    private var parentTextField: NSSearchField?
    private var suggestions = [[String: Any]]()
    private var viewControllers = [NSViewController]()
    private var trackingAreas = [AnyHashable]()
    private var needsLayoutUpdate = false
    private var localMouseDownEventMonitor: Any?
    private var lostFocusObserver: Any?
    

    public init() {
        let contentRec = NSRect(x: 0, y: 0, width: 20, height: 20)
        let window = APSuggestionsWindow(contentRect: contentRec, defer: true)
        super.init(window: window)

        // APSuggestionsWindow is a transparent window, create RoundedCornersView and set it as the content view to draw a menu like window.
        let contentView = APRoundedCornersView(frame: contentRec)
        window.contentView = contentView
        contentView.autoresizesSubviews = false
        needsLayoutUpdate = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    // Custom selectedView property setter so that we can set the highlighted property of the old and new selected views.
    private var selectedView: NSView? {
        didSet {
            if selectedView != oldValue {
                (oldValue as? APHighlightingView)?.setHighlighted(false)
            }
            (selectedView as? APHighlightingView)?.setHighlighted(true)
        }
    }

    // Set selected view and send action
    func userSetSelectedView(_ view: NSView?) {
        selectedView = view
        NSApp.sendAction(action!, to: target, from: self)
    }

    // Position and lay out the suggestions window, set up auto cancelling tracking, and wires up the logical relationship for accessibility.
    public func begin(for parentTextField: NSSearchField?) {
        let suggestionWindow: NSWindow? = window
        let parentWindow: NSWindow? = parentTextField?.window
        let parentFrame: NSRect? = parentTextField?.frame
        var frame: NSRect? = suggestionWindow?.frame
        frame?.size.width = (parentFrame?.size.width)!
        
        // Place the suggestion window just underneath the text field and make it the same width as th text field.
        var location = parentTextField?.superview?.convert(parentFrame?.origin ?? NSPoint.zero, to: nil)
        location = parentWindow?.convertToScreen(NSRect(x: location!.x, y: location!.y, width: 0, height: 0)).origin
        location?.y -= 2.0
        
        // nudge the suggestion window down so it doesn't overlapp the parent view
        suggestionWindow?.setFrame(frame ?? NSRect.zero, display: false)
        suggestionWindow?.setFrameTopLeftPoint(location ?? NSPoint.zero)
        layoutSuggestions()
        
        // The height of the window will be adjusted in -layoutSuggestions.
        // add the suggestion window as a child window so that it plays nice with Expose
        if let aWindow = suggestionWindow {
            parentWindow?.addChildWindow(aWindow, ordered: .above)
        }
        
        // keep track of the parent text field in case we need to commit or abort editing.
        self.parentTextField = parentTextField
        
        // The window must know its accessibility parent, the control must know the window one of its accessibility children
        // Note that views (controls especially) are often ignored, so we want the unignored descendant - usually a cell
        // Finally, post that we have created the unignored decendant of the suggestions window
        let unignoredAccessibilityDescendant = NSAccessibility.unignoredDescendant(of: parentTextField!)
        (suggestionWindow as? APSuggestionsWindow)?.parentElement = unignoredAccessibilityDescendant
        (unignoredAccessibilityDescendant as? APSuggestibleTextFieldCell)?.suggestionsWindow = suggestionWindow
        
        if let win = suggestionWindow, let winD = NSAccessibility.unignoredDescendant(of: win) {
            NSAccessibility.post(element: winD, notification: .created)
        }
        
        // setup auto cancellation if the user clicks outside the suggestion window and parent text field. Note: this is a local event monitor and will only catch clicks in windows that belong to this application.
        localMouseDownEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [NSEvent.EventTypeMask.leftMouseDown, NSEvent.EventTypeMask.rightMouseDown, NSEvent.EventTypeMask.otherMouseDown], handler: {(_ event: NSEvent) -> NSEvent? in
            // If the mouse event is in the suggestion window, then there is nothing to do.
            var event: NSEvent! = event
            if event.window != suggestionWindow {
                if event.window == parentWindow {
                    /* Clicks in the parent window should either be in the parent text field or dismiss the suggestions window. We want clicks to occur in the parent text field so that the user can move the caret or select the search text.
                     
                     Use hit testing to determine if the click is in the parent text field. Note: when editing an NSTextField, there is a field editor that covers the text field that is performing the actual editing.
                     */
                    let contentView: NSView? = parentWindow?.contentView
                    let locationTest: NSPoint? = contentView?.convert(event.locationInWindow, from: nil)
                    let hitView: NSView? = contentView?.hitTest(locationTest ?? NSPoint.zero)
                    let fieldEditor: NSText? = parentTextField?.currentEditor()
                    if hitView != parentTextField && ((fieldEditor != nil) && hitView != fieldEditor) {
                        // Since the click is not in the parent text field, return nil, so the parent window does not try to process it, and cancel the suggestion window.
                        event = nil
                        self.cancelSuggestions()
                    }
                } else {
                    // Not in the suggestion window, and not in the parent window. This must be another window or palette for this application.
                    self.cancelSuggestions()
                }
            }
            return event
        })
        // as per the documentation, do not retain event monitors.
        // We also need to auto cancel when the window loses key status. This may be done via a mouse click in another window, or via the keyboard (cmd-~ or cmd-tab), or a notificaiton. Observing NSWindowDidResignKeyNotification catches all of these cases and the mouse down event monitor catches the other cases.
        lostFocusObserver = NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification, object: parentWindow, queue: nil, using: {(_ arg1: Notification) -> Void in
            // lost key status, cancel the suggestion window
            self.cancelSuggestions()
        })
    }

    /* Order out the suggestion window, disconnect the accessibility logical relationship and dismantle any observers for auto cancel.
     Note: It is safe to call this method even if the suggestions window is not currently visible.
     */
    public func cancelSuggestions() {
        let suggestionWindow: NSWindow? = window
        if suggestionWindow?.isVisible ?? false {
            // Remove the suggestion window from parent window's child window collection before ordering out or the parent window will get ordered out with the suggestion window.
            if let aWindow = suggestionWindow {
                suggestionWindow?.parent?.removeChildWindow(aWindow)
            }
            suggestionWindow?.orderOut(nil)
            // Disconnect the accessibility parent/child relationship
            ((suggestionWindow as? APSuggestionsWindow)?.parentElement as? APSuggestibleTextFieldCell)?.suggestionsWindow = nil
            (suggestionWindow as? APSuggestionsWindow)?.parentElement = nil
        }
        // dismantle any observers for auto cancel
        if lostFocusObserver != nil {
            NotificationCenter.default.removeObserver(lostFocusObserver!)
            lostFocusObserver = nil
        }
        if localMouseDownEventMonitor != nil {
            NSEvent.removeMonitor(localMouseDownEventMonitor!)
            localMouseDownEventMonitor = nil
        }
    }

    /* Update the array of suggestions. The array should consist of NSDictionaries each containing the following keys:
     kSuggestionImageURL - The URL to an image file
     kSuggestionLabel - The main suggestion string
     kSuggestionDetailedLabel - A longer string that provides more detail about the suggestion
     kSuggestionImage - [optional] The image to show in the suggestion thumbnail. If this key is not provided, a thumbnail image will be created in a background que.
     */
    public func setSuggestions(_ suggestions: [[String: Any]]?) {
        self.suggestions = suggestions!
        // We only need to update the layout if the window is currently visible.
        if (window?.isVisible)! {
            layoutSuggestions()
        }
    }

    /* Returns the dictionary of the currently selected suggestion.
     */
    public func selectedSuggestion() -> [String: Any]? {
        var suggestion: Any? = nil
        // Find the currently selected view's controller (if there is one) and return the representedObject which is the NSMutableDictionary that was passed in via -setSuggestions:
        let selectedView: NSView? = self.selectedView
        for viewController: NSViewController in viewControllers where selectedView == viewController.view {
            suggestion = viewController.representedObject
            break
        }
        return suggestion as? [String: Any]
    }
    // MARK: Mouse Tracking
    public func trackingArea(for view: NSView?) -> Any? {
        // make tracking data (to be stored in NSTrackingArea's userInfo) so we can later determine the imageView without hit testing
        var trackerData: [AnyHashable: Any]? = nil
        if let aView = view {
            trackerData = [
                kTrackerKey: aView
            ]
        }
        let trackingRect: NSRect = window!.contentView!.convert(view?.bounds ?? CGRect.zero, from: view)
        let trackingOptions: NSTrackingArea.Options = [.enabledDuringMouseDrag, .mouseEnteredAndExited, .activeInActiveApp]
        let trackingArea = NSTrackingArea(rect: trackingRect, options: trackingOptions, owner: self, userInfo: trackerData)
        return trackingArea
    }

    // Creates suggestion views from suggestionprototype.xib for every suggestion and resize the suggestion window accordingly. Also creates a thumbnail image on a backgroung aue.
    private func layoutSuggestions() {
        let window: NSWindow? = self.window
        let contentView = window?.contentView as? APRoundedCornersView
        // Remove any existing suggestion view and associated tracking area and set the selection to nil
        selectedView = nil
        for viewController in viewControllers {
            viewController.view.removeFromSuperview()
        }
        viewControllers.removeAll()
        for trackingArea in trackingAreas {
            if let nsTrackingArea = trackingArea as? NSTrackingArea {
                contentView?.removeTrackingArea(nsTrackingArea)
            }
        }
        trackingAreas.removeAll()

        var contentFrame: NSRect? = contentView?.frame
        var frame = NSRect(x: 0, y: (contentView?.cornerRadius)!, width: contentFrame!.width, height: 0.0)
        // offset the Y posistion so that the suggetion view does not try to draw past the rounded corners.
        for entry: [String: Any] in suggestions {
            frame.origin.y += frame.size.height
            var frameworkBundle:Bundle? {
                let bundleId = "com.ashwin.APSuggestions"
                return Bundle(identifier: bundleId)
            }
            var viewController = NSViewController()

            if APsuggestionCellNib == "APFramworkDefaultCell" {
               viewController = NSViewController.init(nibName: "APFramworkDefaultCell", bundle: frameworkBundle)
            } else {
                let bundleID = Bundle.main.bundleIdentifier
                let sdafdasf = Bundle(identifier: bundleID!)
                viewController = NSViewController.init(nibName: APsuggestionCellNib, bundle: sdafdasf)
            }
            
            let view = viewController.view as? APHighlightingView
            // Make the selectedView the samee as the 0th.
            if viewControllers.count == 0 {
                selectedView = view
            }
            // Use the height of set in IB of the prototype view as the heigt for the suggestion view.
            frame.size.height = (view?.frame.size.height)!
            view?.frame = frame
            if let aView = view {
                contentView?.addSubview(aView)
            }
            // don't forget to create the tracking are.
            let trackingArea = self.trackingArea(for: view) as? NSTrackingArea
            if let anArea = trackingArea {
                contentView?.addTrackingArea(anArea)
            }
            // convert the suggestion enty to a mutable dictionary. This dictionary is bound to the view controller's representedObject. The represented object is what all the subviews are bound to in IB. We must use a mutable dictionary because we may change one of its key values.
            let mutableEntry = entry
            viewController.representedObject = mutableEntry
            viewControllers.append(viewController)
            if let anArea = trackingArea {
                trackingAreas.append(anArea)
            }
        }
        /* We have added all of the suggestion to the window. Now set the size of the window.
         */
        // Don't forget to account for the extra room needed the rounded corners.
        contentFrame?.size.height = frame.maxY + (contentView?.cornerRadius)!
        var winFrame: NSRect = NSRect(origin: window!.frame.origin, size: window!.frame.size)
        winFrame.origin.y = winFrame.maxY - contentFrame!.height
        winFrame.size.height = contentFrame!.height
        window?.setFrame(winFrame, display: true)
    }

    // The mouse is now over one of our child image views. Update selection and send action.
    public override func mouseEntered(with event: NSEvent) {
        let view: NSView?
        if let userData = event.trackingArea?.userInfo as? [String: NSView] {
            view = userData[kTrackerKey]!
        } else {
            view = nil
        }
        userSetSelectedView(view)
    }

    // The mouse has left one of our child image views. Set the selection to no selection and send action
    public override func mouseExited(with event: NSEvent) {
        userSetSelectedView(nil)
    }

    /* The user released the mouse button. Force the parent text field to send its return action. Notice that there is no mouseDown: implementation. That is because the user may hold the mouse down and drag into another view.
     */
    public override func mouseUp(with theEvent: NSEvent) {
        parentTextField?.validateEditing()
        parentTextField?.abortEditing()
        parentTextField?.sendAction(parentTextField?.action, to: parentTextField?.target)
        cancelSuggestions()
    }

    // MARK: Keyboard Tracking
    public override func moveUp(_ sender: Any?) {
        let selectedView: NSView? = self.selectedView
        var previousView: NSView? = nil
        for viewController: NSViewController in viewControllers {
            let view: NSView? = viewController.view
            if view == selectedView {
                break
            }
            previousView = view
        }
        if previousView != nil {
            userSetSelectedView(previousView)
        }
    }
    
    public override func moveDown(_ sender: Any?) {
        let selectedView: NSView? = self.selectedView
        var previousView: NSView? = nil
        for viewController: NSViewController in viewControllers.reversed() {
            let view: NSView? = viewController.view
            if view == selectedView {
                break
            }
            previousView = view
        }
        if previousView != nil {
            userSetSelectedView(previousView)
        }
    }
}
