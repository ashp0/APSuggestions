import Cocoa

class APHighlightingView: NSView {
    var isHighlighted = false

    // Draw with or without a highlight style
    override func draw(_ dirtyRect: NSRect) {
        layer?.cornerRadius = 5
        if isHighlighted {
            if #available(OSX 10.14, *) {
                NSColor.selectedContentBackgroundColor.set()
            } else {
                NSColor.alternateSelectedControlColor.set()
            }
            __NSRectFillUsingOperation(dirtyRect, .sourceOver)
            layer?.cornerRadius = 5
        } else {
            NSColor.clear.set()
            __NSRectFillUsingOperation(dirtyRect, .sourceOver)
            
        }
    }
    /* Custom highlighted property setter because when the property changes we need to redraw and update the containing text fields.
     */
    func setHighlighted(_ highlighted: Bool) {
        if self.isHighlighted != highlighted {
            self.isHighlighted = highlighted
            // Inform each contained text field what type of background they will be displayed on. This is how the txt field knows when to draw white text instead of black text.
            for subview in subviews where subview is NSTextField {
                (subview as? NSTextField)?.cell?.backgroundStyle = highlighted ? NSView.BackgroundStyle.emphasized : NSView.BackgroundStyle.normal
                layer?.cornerRadius = 5
            }
            needsDisplay = true
            // make sure we redraw with the correct highlight style.
        }
    }

}
