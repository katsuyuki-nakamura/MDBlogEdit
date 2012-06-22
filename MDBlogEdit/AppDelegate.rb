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

class CustomHTML < Redcarpet::Render::HTML
    def block_code(code, language)
        CodeRay.scan(code, language).div()
    end
	def doc_header()
	end
	def doc_footer()
	end
end

class AppDelegate
    attr_accessor :window
    attr_accessor :webview
    attr_accessor :textview
    
    @parser
    @thread
    @lang
    @css_file
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
        @lang = "ja"
        @css_file = "markdown.css"
        @css = File.read(NSBundle.mainBundle.bundlePath + "/Contents/Resources/" + @css_file)
    end

    def updateWebView(sender)
        @locker.synchronize do
            path = NSBundle.mainBundle.bundlePath + "/Contents/Resources"
            baseURL = NSURL.fileURLWithPath(path)
            html = full_html
            webview.mainFrame.loadHTMLString(html, baseURL: baseURL)
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
        self.window.setTitle(@filepath)
    end

    def _saveas_html(html)
        panel = NSSavePanel.savePanel
        filetypes = ["html", "htm"]
        filename = "Untitled.html"
        if @filepath != nil then
            filename = File.basename(@filepath, ".*") + ".html"
        end
        panel.setNameFieldStringValue(filename)
        panel.setAllowedFileTypes(filetypes)
        panel.setAllowsOtherFileTypes(false)
        panel.setFloatingPanel(true)
        panel.setCanChooseDirectories(false)
        panel.setCanChooseFiles(true)
        panel.setAllowsMultipleSelection(false)
        panel.setExtensionHidden(false)
        result = panel.runModal
        if (result == NSOKButton)
            File.open(panel.filename, "w") {|f| f.write html}
        end
    end

    def _saveas
        panel = NSSavePanel.savePanel
        filetypes = ["md", "mkd", "markdown", "gfm"]
        filename = "Untitled.md"
        if @filepath != nil then
            filename = File.basename(@filepath)
        end
        puts filename

        panel.setNameFieldStringValue(filename)
        panel.setAllowedFileTypes(filetypes)
        panel.setAllowsOtherFileTypes(false)
        panel.setFloatingPanel(true)
        panel.setCanChooseDirectories(false)
        panel.setCanChooseFiles(true)
        panel.setAllowsMultipleSelection(false)
        panel.setExtensionHidden(false)
        result = panel.runModal
        if (result == NSOKButton)
            @filepath = panel.filename
            NSDocumentController.sharedDocumentController.noteNewRecentDocumentURL(NSURL.fileURLWithPath(@filepath));
            File.open(@filepath, "w") {|f| f.write textview.textStorage.string}
        end
        self.window.setTitle(@filepath)
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
        self.window.setTitle(@filepath)
    end

    def new(sender)
        @filepath = nil
        textview.setString("")
        webview.mainFrame.loadHTMLString("<html><head></head><body></body></html>", baseURL: nil)
        self.window.setTitle("Untitled")
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

    def full_html
        html = <<-EOS
<!DOCTYPE html>
<html lang="#{@lang}">
<head>
<meta charset="utf-8">
<style>
#{@css}
</style>
</head>
<body>
#{@html}
</body>
</html>
        EOS
        return html
    end

    def exporthtml(sender)
        html = full_html
        _saveas_html(html)
    end
end



