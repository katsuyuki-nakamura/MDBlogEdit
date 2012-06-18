#
#  AppDelegate.rb
#  MarkPad
#
#  Created by 克之 中村 on 12/06/03.
#  Copyright 2012年 __MyCompanyName__. All rights reserved.
#

require 'rubygems'
require 'redcarpet'
require 'coderay'

DOC_HEADER =  "<!DOCTYPE html>\n" \
"<html lang=\"en\">\n" \
"<head>\n" \
"<link href=\"markdown.css\" rel=\"stylesheet\">\n" \
"</head>\n" \
"<body>\n"

DOC_FOOTER =  "</body>\n" \
"</html>"

class CustomHTML < Redcarpet::Render::HTML
    def block_code(code, language)
        CodeRay.scan(code, language).div()
    end
	def doc_header()
		#DOC_HEADER
	end
	def doc_footer()
		#DOC_FOOTER
	end
end

class AppDelegate
    attr_accessor :window
    attr_accessor :webview
    attr_accessor :textview
    
    @parser
    @thread
    @html
    @timer = nil
    @locker
    @filepath = nil

    def initialize
        @locker = Mutex::new
        @parser = Redcarpet::Markdown.new(CustomHTML.new(:hard_wrap => true), 
                                          :autolink => true,
                                          :space_after_headers => true,
                                          :tables => true,
                                          :fenced_code_blocks => true
                                          )
    end

    def updateWebView(sender)
        @locker.synchronize do
            path = NSBundle.mainBundle.bundlePath + "/Contents/Resources"
            baseURL = NSURL.fileURLWithPath(path)
            html_full = DOC_HEADER + @html + DOC_FOOTER
            webview.mainFrame.loadHTMLString(html_full, baseURL: baseURL)
        end
    end 

    def renderMarkdown(dummy)
        if (@thread != nil)
            @thread.join
            @thread.kill
        end
        @thread = Thread.new do
            @locker.synchronize do
                @html = @parser.render(textview.textStorage.string)
            end
            self.performSelectorOnMainThread(:'updateWebView:', withObject:nil, waitUntilDone:false)
        end
    end

    def _open_file(path)
        webview.mainFrame.loadHTMLString("<html><head></head><body></body></html>", baseURL: nil)
        @filepath = path
        NSDocumentController.sharedDocumentController.noteNewRecentDocumentURL(NSURL.fileURLWithPath(@filepath));
        source = File.read(@filepath)
        textview.setString source
    end

    def _saveas
        panel = NSSavePanel.savePanel
        filetypes = ["md", "mkd", "markdown", "gfm"]
        text = textview.textStorage.string
        range = text.lineRangeForRange(NSMakeRange(0, 0))
        filename = text.substringWithRange(range) + ".md"
        panel.setNameFieldStringValue(filename)
        panel.setExtensionHidden(false)
        panel.setAllowedFileTypes(filetypes)
        panel.setAllowsOtherFileTypes(false)
        panel.setFloatingPanel(true)
        panel.setCanChooseDirectories(false)
        panel.setCanChooseFiles(true)
        panel.setAllowsMultipleSelection(false)
        result = panel.runModal
        if (result == NSOKButton)
            @filepath = panel.filename
            NSDocumentController.sharedDocumentController.noteNewRecentDocumentURL(NSURL.fileURLWithPath(@filepath));
            File.open(@filepath, "w") {|f| f.write textview.textStorage.string}
        end
    end

    # delegate
    def application(theApplication, openFile: filename)
        _open_file(filename)
        return true
    end

    # delegate
    def textStorageDidProcessEditing(notification)
        if (@timer != nil)
            @timer.invalidate
        end
        @timer = NSTimer.scheduledTimerWithTimeInterval(0.3,
                                                        target:self,
                                                        selector:"renderMarkdown:",
                                                        userInfo:nil,
                                                        repeats:false)
    end

    #delegate
    def applicationDidFinishLaunching(a_notification)
        # to handle text input
        textview.textStorage.setDelegate(self);
        controller = NSDocumentController.sharedDocumentController
        documents = controller.recentDocumentURLs
        if (documents.length > 0)
            @filepath = documents[0].path
            source = File.read(@filepath)
            textview.setString source
        end
    end

    def new(sender)
        @filepath = nil
        textview.setString("")
        webview.mainFrame.loadHTMLString("<html><head></head><body></body></html>", baseURL: nil)
    end

    def open(sender)
        panel = NSOpenPanel.openPanel
        
        result = panel.runModalForDirectory(NSHomeDirectory(),
                                          file: nil,
                                          types: ["md", "mkd", "markdown", "gfm"])
        if (result == NSOKButton)
            _open_file(panel.filename)
        end
    end

    def saveas(sender)
        _saveas
    end

    def save(sender)
        if (@filepath == nil)
            _saveas
            return
        end
        NSDocumentController.sharedDocumentController.noteNewRecentDocumentURL(NSURL.fileURLWithPath(@filepath));
        File.open(@filepath, "w") {|f| f.write textview.textStorage.string}
    end

    def copyhtml(sender)
        pasteBoard = NSPasteboard.generalPasteboard
        pasteBoard.declareTypes([NSStringPboardType], owner: nil)
        pasteBoard.setString(@html, forType: NSStringPboardType)
    end

    def exporthtml(sender)
        pasteBoard = NSPasteboard.generalPasteboard
        pasteBoard.declareTypes([NSStringPboardType], owner: nil)
        pasteBoard.setString(DOC_HEADER + @html + DOC_FOOTER, forType: NSStringPboardType)
    end
end

