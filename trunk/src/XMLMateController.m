//
//  XMLMateController.m
//  XMLMatePlugIn
//
//  Created by Todd Ditchendorf on 12/23/06.
//  Copyright 2006 Todd Ditchendorf. All rights reserved.
//

#import "XMLMateController.h"
#import "XMLMatePlugIn.h"
#import "XMLCatalogService.h"
#import "XMLParsingService.h"
#import "XPathService.h"
#import "XMLParseCommand.h"
#import "XMLParsingServiceLibxmlImpl.h"
#import "XMLCatalogServiceLibxmlImpl.h"
#import "XPathServiceLibxmlImpl.h"
#import <WebKit/WebKit.h>

typedef enum {
	CheckboxTagLoadDTD = 0,
	CheckboxTagDefaultDTDAttrs,
	CheckboxTagSubstituteEntities,
	CheckboxTagMergeCDATA
} CheckboxTag;

@interface OakTextView : NSObject {}
@end

@interface OakTextView (ShutUpWarnings)
+ (id)defaultEnvironmentVariables;
- (id)environmentVariables;
- (void)setNeedsDisplay:(BOOL)yn;
- (id)stringValue;
- (void)goToLineNumber:(id)fp8;
- (void)goToColumnNumber:(id)fp8;
- (void)selectToLine:(id)fp8 andColumn:(id)fp12;
- (void)centerSelectionInVisibleArea:(id)fp8;
- (void)scrollViewByX:(float)fp8 byY:(long)fp12;

- (void)centerCaretInDisplay:(id)fp8;
- (void)setSelectionNeedsDisplay:(BOOL)fp8;
- (id)wordAtCaret;
- (id)xmlRepresentationForSelection:(BOOL)fp8;
- (id)xmlRepresentation;
- (id)xmlRepresentationForSelection;
- (int)currentIndentForContent:(id)fp8 atLine:(unsigned long)fp12;
- (int)indentForCurrentLine;
- (unsigned long)currentIndent;
- (unsigned long)indentLine:(unsigned long)fp8;


- (id)attributedSubstringFromRange:(struct _NSRange)fp8;
- (void)setMarkedText:(id)fp8 selectedRange:(struct _NSRange)fp12;
- (BOOL)hasMarkedText;
- (struct _NSRange)markedRange;
- (struct _NSRange)selectedRange;
- (id)validAttributesForMarkedText;
@end

@implementation OakTextView
@end

@interface NSString (HTMLSupport)
- (NSString *)stringByReplacingHTMLEntities;
@end

@implementation NSString (HTMLSupport)

- (NSString *)stringByReplacingHTMLEntities {
	NSMutableString *mstr = [NSMutableString stringWithString:self];
	[mstr replaceOccurrencesOfString:@"&"
						  withString:@"&amp;"
							 options:0
							   range:NSMakeRange(0, [mstr length])];
	[mstr replaceOccurrencesOfString:@"<"
						  withString:@"&lt;"
							 options:0
							   range:NSMakeRange(0, [mstr length])];
	[mstr replaceOccurrencesOfString:@">"
						  withString:@"&gt;"
							 options:0
							   range:NSMakeRange(0, [mstr length])];

	return [NSString stringWithString:mstr];
}

@end

@interface DOMElement (IEExtentions)
- (void)setClassName:(NSString *)className;
- (void)setInnerText:(NSString *)innerText;
- (void)setInnerHTML:(NSString *)innerHTML;
@end

@interface XMLMateController (Private)
- (void)setupFonts;
- (void)loadParseResultsDocument;
- (void)setSchemaURLComboBoxPlaceHolderString;
- (void)registerForNotifications;
- (void)setupCatalog;
- (void)updateCatalog;
- (BOOL)addRecentSchemaURLString:(NSString *)str;
- (BOOL)addRecentXPathString:(NSString *)str;
- (NSArray *)contextMenuItems;
- (void)setContextMenuItems:(NSArray *)newItems;
- (NSString *)HTMLStringForErrorInfo:(NSDictionary *)info;
- (void)appendResultItemWithClassName:(NSString *)className innerHTML:(NSString *)innerHTML attributes:(NSDictionary *)attrs;
- (void)playSuccessSound;
- (void)playErrorSound;
- (void)playWarningSound;
- (void)playSoundNamed:(NSString *)name;
- (void)changeSizeForSettings;
- (void)errorItemClicked:(float)line filename:(NSString *)filename;
- (void)doProblemItemWithClassName:(NSString *)className error:(NSDictionary *)info;
- (id)firstSubviewOfView:(NSView *)superview kindOfClass:(Class)c;
- (void)fetchSourceXMLDataFromOakTextView;
- (NSWindow *)findOpenTextMateWindowForFilename:(NSString *)filename;
- (void)selectTextInCurrentOakTextView:(NSNumber *)lineObj;
- (OakTextView *)currentOakTextView;
- (void)appendQueryConsoleString:(NSString *)str;
@end

@implementation XMLMateController

- (id)init {
	self = [super initWithWindowNibName:@"XMLMatePalette"];
	if (self != nil) {
		[self setPlaySounds:YES];
		[self setPreferedCatalogItemType:2];
		parsingService = [[XMLParsingServiceLibxmlImpl alloc] initWithDelegate:self];
		xpathService = [[XPathServiceLibxmlImpl alloc] initWithDelegate:self];
		//id vars = [OakTextView defaultEnvironmentVariables];
		id vars = [[self currentOakTextView] environmentVariables];
		//NSLog(@"defaultEnvironmentVariables: %@",[OakTextView defaultEnvironmentVariables]);
		//NSLog(@"defaultEnvironmentVariables: %@",[[self currentOakTextView] environmentVariables]);
		catalogService = [[XMLCatalogServiceLibxmlImpl alloc] initWithDelegate:self environmentVariables:vars];
	}
	return self;
}


- (void)dealloc {
	[parsingService release];
	[catalogService release];
	[xpathService release];
	[self setContextMenuItems:nil];
	[self setCatalogItems:nil];
	[self setCommand:nil];
	[self setRecentSchemaURLStrings:nil];
	[self setRecentXPathStrings:nil];
	[self setSourceXMLString:nil];
	[self setCatalogXMLString:nil];
	[self setQueryResultNodes:nil];
	[self setQueryResultString:nil];
	[super dealloc];
}


#pragma mark -
#pragma mark NSWindowcontroller

- (void)windowDidLoad {
	[self setupFonts];
	[self loadParseResultsDocument];
	[self setSchemaURLComboBoxPlaceHolderString];
	[self registerForNotifications];
	[self setupCatalog];
}


#pragma mark -
#pragma mark Actions

- (void)showWindow:(id)sender {
	[super showWindow:sender];
	[catalogService putCatalogContents:catalogItems];
}


- (IBAction)parameterWasChanged:(id)sender {
	//NSLog(@"parameterWasChanged: %i boolval: %i", [sender tag], [sender state]);
	
	BOOL checked = (NSOnState == [sender state]);
	
	switch ([sender tag]) {
		
		case CheckboxTagLoadDTD:
			if (!checked) {
				[command setDefaultDTDAttributes:NO];
				[command setSubstituteEntities:NO];
			}
			break;
		case CheckboxTagDefaultDTDAttrs:
			if (checked) {
				[command setLoadDTD:YES];
			}
			break;
		case CheckboxTagSubstituteEntities:
			if (checked) {
				[command setLoadDTD:YES];
			}
			break;
	}
}


- (IBAction)validationTypeWasChanged:(id)sender {
	//XMLValidationType type = [command validationType];
	
	[command setSchemaURLString:nil];

	[self setSchemaURLComboBoxPlaceHolderString];
}


- (IBAction)browse:(id)sender {
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	const int res = [panel runModalForDirectory:nil file:nil];
	if (NSFileHandlingPanelOKButton == res) {
		[command setSchemaURLString:[panel filename]];
	}
}


- (IBAction)parse:(id)sender {
	[self clear:self];
	
	NSString *sourceURLString = [[NSApp mainWindow] representedFilename];

	if (![sourceURLString length]) {
		NSBeep();
		return;
	}
	
	[command setSourceURLString:sourceURLString];

	[self fetchSourceXMLDataFromOakTextView];
	
	if (![[command sourceXMLData] length]) {
		NSBeep();
		return;
	}
		
	XMLValidationType type		= [command validationType];
	NSString *schemaURLString	= [command schemaURLString];
	
	if (XMLValidationTypeXSD == type || 
		XMLValidationTypeRNG == type || 
		XMLValidationTypeRNC == type || 
		XMLValidationTypeSchematron == type) {
		
		if (![schemaURLString length]) {
			NSBeep();
			return;
		}
	}
	
	[self setBusy:YES];
	errorCount = 0;
	
	if ([schemaURLString length]) {
		[self addRecentSchemaURLString:schemaURLString];
	}
	
	[parsingService parse:command];
}


- (IBAction)clear:(id)sender {
	DOMDocument *document = [[parseResultsWebView mainFrame] DOMDocument];
	DOMElement *ul = [document getElementById:@"result-list"];
	[ul setInnerHTML:@""];

	[self setSourceXMLString:nil];
}


- (IBAction)executeQuery:(id)sender {
	[self setQueryResultLength:0];
	[self setQueryResultNodes:nil];
	[self setQueryResultString:nil];
	
	if (![XPathString length]) {
		NSBeep();
		return;
	}
	
	[self fetchSourceXMLDataFromOakTextView];
	
	if (![[command sourceXMLData] length]) {
		NSBeep();
		return;
	}
		
	[self setBusy:YES];

	if ([XPathString length]) {
		[self addRecentXPathString:XPathString];
	}
		
	[xpathService executeQuery:XPathString withCommand:command];
}


#pragma mark -
#pragma mark Private

- (void)setupFonts {
	NSFont *monaco = [NSFont fontWithName:@"Monaco" size:9.];
	[sourceXMLTextView setFont:monaco];
	[catalogXMLTextView setFont:monaco];
	[xpathArrayTextView setFont:monaco];
}


- (void)loadParseResultsDocument {
	NSBundle *bundle = [XMLMatePlugIn bundle];
	NSString *path	 = [bundle pathForResource:@"results" ofType:@"html"];

	NSURLRequest *req = [NSURLRequest requestWithURL:[NSURL fileURLWithPath:path]];
	[[parseResultsWebView mainFrame] loadRequest:req];
}


- (void)setSchemaURLComboBoxPlaceHolderString {
	XMLValidationType type = [command validationType];

	NSString *str = nil;
	
	switch(type) {
		case XMLValidationTypeNone:
			str = @"";
			break;
		case XMLValidationTypeDTD:
			str = @"Auto-Detect DTD";
			break;
		case XMLValidationTypeXSD:
		case XMLValidationTypeRNG:
		case XMLValidationTypeRNC:
		case XMLValidationTypeSchematron:
			str = @"Required";
			break;
	}
	
	[[schemaURLComboBox cell] setPlaceholderString:str];
}


- (void)registerForNotifications {
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	[nc addObserver:self
		   selector:@selector(textDidEndEditing:) 
			   name:NSControlTextDidEndEditingNotification
			 object:nil];
	
	[nc addObserver:self
		   selector:@selector(menuDidSendAction:) 
			   name:NSMenuDidSendActionNotification
			 object:nil];
	
	[nc addObserver:self
		   selector:@selector(tableSelectionDidChange:) 
			   name:NSTableViewSelectionDidChangeNotification
			 object:catalogTable];
}


- (void)setupCatalog {
	NSPopUpButtonCell *pCell = [[catalogTable tableColumnWithIdentifier:@"type"] dataCell];
	[pCell setFont:[NSFont controlContentFontOfSize:10.]];
	[pCell setMenu:catalogItemTypeMenu];
	
	[catalogTable setNeedsDisplay:YES];
}


- (void)updateCatalog {
	[self setBusy:YES];
	[catalogService putCatalogContents:catalogItems];
}


- (BOOL)addRecentSchemaURLString:(NSString *)str {
	BOOL res = NO;
	if (![recentSchemaURLStrings containsObject:str]) {
		res = YES;
		[recentSchemaURLStrings addObject:str];
	}
	return res;
}


- (BOOL)addRecentXPathString:(NSString *)str {
	BOOL res = NO;
	if (![recentXPathStrings containsObject:str]) {
		res = YES;
		[recentXPathStrings addObject:str];
	}
	return res;
}


- (NSArray *)contextMenuItems {
	@synchronized (self) {
		if (!contextMenuItems) {
            NSString *title = NSLocalizedString(@"Clear", @"");
			NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title action:@selector(clear:) keyEquivalent:@""];
			NSArray *a = [NSArray arrayWithObject:item];
            [item release];
			[self setContextMenuItems:a];
		}
	}
	return contextMenuItems;
}


- (void)setContextMenuItems:(NSArray *)newItems {
	if (contextMenuItems != newItems) {
		[contextMenuItems autorelease];
		contextMenuItems = [newItems retain];
	}
}


- (NSString *)HTMLStringForErrorInfo:(NSDictionary *)info {
	NSMutableString *res = [NSMutableString string];
	
	[res appendString:[NSString stringWithFormat:@"%@ %@: ", 
		[info objectForKey:XMLParseErrorDomainStrKey],
		[info objectForKey:XMLParseErrorLevelStrKey]]];

	NSNumber *line = [info objectForKey:XMLParseErrorLineKey];
	if (line) {
		[res appendString:[NSString stringWithFormat:@"line %@: ", line]];
	}
	[res appendString:[info objectForKey:XMLParseErrorMessageKey]];
	
	NSString *ctxtStr = [[info objectForKey:XMLParseErrorContextStrKey] stringByReplacingHTMLEntities];
	
	BOOL isSchematron = [[info objectForKey:XMLParseErrorDomainStrKey] hasPrefix:@"Schematron"];
	NSString *formatStr = nil;	
	if (isSchematron) {
		formatStr = @"<div>For Pattern: <pre>%@</pre></div>";
	} else {
		formatStr = @"<div><pre>%@</pre></div>";
	}
	[res appendString:[NSString stringWithFormat:formatStr, ctxtStr]];

	if (isSchematron) {
		NSString *diagnostics = [info objectForKey:XMLParseErrorDiagnosticsKey];
		if ([diagnostics length]) {
			[res appendFormat:@"<div>Diagnostics: %@</div>", diagnostics];
		}
		NSString *role = [info objectForKey:XMLParseErrorRoleKey];
		if ([role length]) {
			[res appendFormat:@"<div>Role: %@</div>", role];
		}
		NSString *subject = [info objectForKey:XMLParseErrorSubjectKey];
		if ([subject length]) {
			[res appendFormat:@"<div>Subject: %@</div>", subject];
		}
	}
	return res;
}


- (void)appendResultItemWithClassName:(NSString *)className innerHTML:(NSString *)innerHTML attributes:(NSDictionary *)attrs {
	DOMDocument *document = [[parseResultsWebView mainFrame] DOMDocument];
	DOMElement *li = [document createElement:@"li"];
	[li setClassName:className];
	[li setInnerHTML:innerHTML];
	
	NSEnumerator *e = [attrs keyEnumerator];
	NSString *key;
	while (key = [e nextObject]) {
		[li setAttribute:key :[attrs objectForKey:key]];
	}
	
	[[document getElementById:@"result-list"] appendChild:li];
}


- (NSString *)nameForValidationType:(XMLValidationType)type {
	NSString *res = nil;
	
	switch ([command validationType]) {
		case XMLValidationTypeNone:
			res = @"";
			break;
		case XMLValidationTypeDTD:
			res = @"DTD";
			break;
		case XMLValidationTypeXSD:
			res = @"XML Schema";
			break;
		case XMLValidationTypeRNG:
			res = @"RELAX NG";
			break;
		case XMLValidationTypeRNC:
			res = @"RELAX NG Compact Syntax";
			break;
		case XMLValidationTypeSchematron:
			res = @"Schematron";
			break;
	}

	return res;
}


- (void)playSuccessSound {
	[self playSoundNamed:@"Hero"];
}


- (void)playErrorSound {
	[self playSoundNamed:@"Basso"];
}


- (void)playWarningSound {
	[self playSoundNamed:@"Bottle"];
}


- (void)playSoundNamed:(NSString *)name {
	if (playSounds) {
		[[NSSound soundNamed:name] play];
	}
}


- (void)doProblemItemWithClassName:(NSString *)className error:(NSDictionary *)info {
	//NSLog(@"info: %@", info);
	
	NSString *msg = [self HTMLStringForErrorInfo:info];
	
	
	NSString *filename = [info objectForKey:XMLParseErrorFilenameKey];
	
	NSDictionary *attrs = nil;
	NSNumber *line = [info objectForKey:XMLParseErrorLineKey]; 
	if (line) {
		NSString *attrVal = [NSString stringWithFormat:@"errorItemClicked(%d, '%@')", [line intValue], filename];
		attrs = [NSDictionary dictionaryWithObject:attrVal forKey:@"onclick"];
	}
	
	[self appendResultItemWithClassName:className innerHTML:msg attributes:attrs];
}


- (void)changeSizeForSettings {
	NSPoint p = [bottomView bounds].origin;
	p.y = (showSettings) ? 60. : 0.;
	[bottomView setBoundsOrigin:p];
	[bottomView setNeedsDisplay:YES];	
}


- (NSWindow *)findOpenTextMateWindowForFilename:(NSString *)filename {
	NSWindow *win = nil;
	NSEnumerator *e = [[NSApp windows] objectEnumerator];
	while (win = [e nextObject]) {
		if ([[win representedFilename] isEqualToString:filename]) {
			return win;
		}
	}
	return nil;
}


- (void)errorItemClicked:(float)line filename:(NSString *)filename {
	//NSLog(@"errorItemClicked: line: %f, filename: %@", line, filename);

	NSWindow *win = [self findOpenTextMateWindowForFilename:filename];

	NSTimeInterval delay = 0.;
	
	if (win) {
		[win makeMainWindow];
	} else {
		delay = .5;
		
		NSTask *task = [[[NSTask alloc] init] autorelease];
		
		if (!filename || [filename isEqualToString:@"(null)"]) {
			filename = [command schemaURLString];
		}
		
		NSArray *args = [NSArray arrayWithObject:filename];
		[task setArguments:args];
		[task setLaunchPath:@"/usr/bin/open"];
		[task launch];
		[task waitUntilExit];
	}

	[self performSelector:@selector(selectTextInCurrentOakTextView:) 
			   withObject:[NSNumber numberWithFloat:line]
			   afterDelay:delay];
}


- (void)selectTextInCurrentOakTextView:(NSNumber *)lineObj {	
	OakTextView *textView = [self currentOakTextView];
	[textView goToLineNumber:lineObj];
	[textView selectToLine:lineObj andColumn:[NSNumber numberWithFloat:1000.]];
	[textView centerSelectionInVisibleArea:self];
	[textView scrollViewByX:-1000. byY:0.];
	
	[[NSApp mainWindow] makeKeyAndOrderFront:self];
}


- (OakTextView *)currentOakTextView {
	NSWindow *win = [NSApp mainWindow];
	if (!win) {
		return nil;
	}
	
	NSView *contentView = [win contentView];
	if (!contentView) {
		return nil;
	}
	
	NSScrollView *scrollView = [self firstSubviewOfView:contentView kindOfClass:[NSScrollView class]];
	if (!scrollView) {
		return nil;
	}
	
	NSClipView *clipView = [self firstSubviewOfView:scrollView kindOfClass:[NSClipView class]];
	if (!clipView) {
		return nil;
	}
	
	OakTextView *textView = [self firstSubviewOfView:clipView kindOfClass:[OakTextView class]];
	if (!textView) {
		return nil;
	}

	return textView;	
}


- (id)firstSubviewOfView:(NSView *)superview kindOfClass:(Class)c {
	id view = nil;
	
	NSEnumerator *e = [[superview subviews] objectEnumerator];
	
	while (view = [e nextObject]) {
		if ([view isKindOfClass:c]) {
			return view;
		}
	}
	
	return nil;
}


- (void)fetchSourceXMLDataFromOakTextView {
	NSData *sourceXMLData = [[[self currentOakTextView] stringValue] dataUsingEncoding:NSUTF8StringEncoding];
	[command setSourceXMLData:sourceXMLData];
}


- (void)appendQueryConsoleString:(NSString *)str {
	@synchronized (self) {
		if (!queryConsoleString) {
			[self setQueryConsoleString:[NSMutableString string]];
		}
	}
	[queryConsoleString appendString:str];
}


#pragma mark -
#pragma mark WebScripting

+ (NSString *)webScriptNameForSelector:(SEL)sel {
	if (@selector(errorItemClicked:filename:) == sel) {
		return @"errorItemClicked";
	} else {
		return nil;
	}
}


+ (BOOL)isSelectorExcludedFromWebScript:(SEL)sel {
	return (nil == [self webScriptNameForSelector:sel]);
}


+ (BOOL)isKeyExcludedFromWebScript:(const char *)name {
	return YES;
}


#pragma mark -
#pragma mark XMLCatalogServiceDelegate

- (void)catalogService:(id <XMLCatalogService>)service didUpdate:(NSString *)XMLString {
	[self setCatalogXMLString:XMLString];
	[self setBusy:NO];
}


- (void)catalogService:(id <XMLCatalogService>)service didError:(NSDictionary *)errInfo {
	//NSLog(@"error!!!!!!!!!");
	[self setBusy:NO];
}


#pragma mark -
#pragma mark XMLParsingServiceDelegate

- (void)parsingService:(id <XMLParsingService>)service willParse:(XMLParseCommand *)c {
	//NSLog(@"controller willParse:");
	
	if (![command verbose]) {
		return;
	}	
	
	BOOL checkedValidity = (XMLValidationTypeNone != [command validationType]);

	NSString *filename = [[command sourceURLString] lastPathComponent];
	
	NSMutableString *msg = nil;
	NSString *schemaFilename = [[command schemaURLString] lastPathComponent];
	
	if (checkedValidity) {
		msg = [NSMutableString stringWithFormat:@"Checking <tt>%@</tt> for validity against ", filename];
		switch ([command validationType]) {
            case XMLValidationTypeNone:
                break;
			case XMLValidationTypeDTD:
				if ([schemaFilename length]) {
					[msg appendFormat:@"user-specified DTD: <tt>%@</tt>", schemaFilename];
				} else {
					[msg appendString:@"auto-detected DTD"];
				}
				break;
			case XMLValidationTypeXSD:
				if ([schemaFilename length]) {
					[msg appendFormat:@"user-specified XML Schema: <tt>%@</tt>", schemaFilename];
				} else {
					[msg appendString:@"auto-detected XML Schema"];
				}
				break;
			case XMLValidationTypeRNG:
				[msg appendFormat:@"RELAX NG schema: <tt>%@</tt>", schemaFilename];
				break;
			case XMLValidationTypeRNC:
				[msg appendFormat:@"RELAX NG Compact Syntax schema: <tt>%@</tt>", schemaFilename];
				break;
			case XMLValidationTypeSchematron:
				[msg appendFormat:@"Schematron schema: <tt>%@</tt>", schemaFilename];
				break;
		}
			
	} else {
		msg = [NSMutableString stringWithFormat:@"Checking <tt>%@</tt> for well-formedness", filename];
	}
	
	[self appendResultItemWithClassName:@"info-item" innerHTML:msg attributes:nil];
}


- (void)parsingService:(id <XMLParsingService>)service didParse:(XMLParseCommand *)c {
	NSString *filename = [[command sourceURLString] lastPathComponent];
	
	BOOL checkedValidity = (XMLValidationTypeNone != [command validationType]);
	NSString *result = (checkedValidity ? @"valid" : @"well-formed");
	
	if (!errorCount) {
		
		NSString *msg = [NSString stringWithFormat:@"<tt>%@</tt> is %@", filename, result];
		[self appendResultItemWithClassName:@"success-item" innerHTML:msg attributes:nil];
		[self playSuccessSound];
		
	} else {
		
		NSString *msg = [NSString stringWithFormat:@"<tt>%@</tt> is NOT %@", filename, result];
		[self appendResultItemWithClassName:@"error-item" innerHTML:msg attributes:nil];
		[self playErrorSound];
		
	}
	
	[parseResultsWebView setNeedsDisplay:YES];
	[[self window] makeFirstResponder:schemaURLComboBox];
	[self setBusy:NO];
}


- (void)parsingService:(id <XMLParsingService>)service willFetchSchema:(NSString *)schemaURLString {
	//NSLog(@"controller willFetchSchema:");
	
	if (![command verbose]) {
		return;
	}
	
	NSString *schemaType = [self nameForValidationType:[command validationType]];
	
	NSString *schemaFilename = [schemaURLString lastPathComponent];
	
	NSString *msg = [NSString stringWithFormat:@"Fetching %@: <tt>%@</tt>", schemaType, schemaFilename];
	
	[self appendResultItemWithClassName:@"info-item" innerHTML:msg attributes:nil];
}


- (void)parsingService:(id <XMLParsingService>)service didFetchSchema:(NSString *)schemaURLString {
	//NSLog(@"controller didFetchSchema:");
	
	if (![command verbose]) {
		return;
	}
	
	NSString *schemaType = [self nameForValidationType:[command validationType]];
	
	NSString *schemaFilename = [schemaURLString lastPathComponent];
	
	NSString *msg = [NSString stringWithFormat:@"Successfully fetched %@: <tt>%@</tt>", schemaType, schemaFilename];
	
	[self appendResultItemWithClassName:@"info-item" innerHTML:msg attributes:nil];
}


- (void)parsingService:(id <XMLParsingService>)service willParseSchema:(NSString *)schemaURLString {
	//NSLog(@"controller willParseSchema:");
	
	if (![command verbose]) {
		return;
	}
	
	NSString *schemaType = [self nameForValidationType:[command validationType]];
	
	NSString *schemaFilename = [schemaURLString lastPathComponent];
	
	NSString *msg = [NSString stringWithFormat:@"Parsing %@: <tt>%@</tt>", schemaType, schemaFilename];

	[self appendResultItemWithClassName:@"info-item" innerHTML:msg attributes:nil];
}


- (void)parsingService:(id <XMLParsingService>)service didParseSchema:(NSString *)schemaURLString duration:(NSTimeInterval)duration {
	//NSLog(@"controller didParseSchema:");
	
	if (![command verbose]) {
		return;
	}

	NSString *schemaType = [self nameForValidationType:[command validationType]];
	
	NSString *schemaFilename = [schemaURLString lastPathComponent];
	
	NSString *msg = [NSString stringWithFormat:@"Finished parsing %@: <tt>%@</tt>", schemaType, schemaFilename];
	
	[self appendResultItemWithClassName:@"info-item" innerHTML:msg attributes:nil];
	
}


- (void)parsingService:(id <XMLParsingService>)service willFetchSource:(NSString *)sourceURLString {
	//NSLog(@"controller willFetchSource:");
	
	if (![command verbose]) {
		return;
	}
	
	NSString *filename = [sourceURLString lastPathComponent];
	
	NSString *msg = [NSString stringWithFormat:@"Fetching document: <tt>%@</tt>", filename];
	
	[self appendResultItemWithClassName:@"info-item" innerHTML:msg attributes:nil];
}


- (void)parsingService:(id <XMLParsingService>)service didFetchSource:(NSString *)sourceURLString duration:(NSTimeInterval)duration {
	//NSLog(@"controller didFetchSource:");
	
	if (![command verbose]) {
		return;
	}
	
	NSString *filename = [sourceURLString lastPathComponent];
	
	NSString *msg = [NSString stringWithFormat:@"Successfully fetched document: <tt>%@</tt>", filename];
	
	[self appendResultItemWithClassName:@"info-item" innerHTML:msg attributes:nil];
}


- (void)parsingService:(id <XMLParsingService>)service willParseSource:(NSString *)sourceURLString {
	//NSLog(@"controller willParseSource:");
	
	if (![command verbose]) {
		return;
	}

	NSString *filename = [sourceURLString lastPathComponent];
	
	NSString *msg = [NSString stringWithFormat:@"Parsing document: <tt>%@</tt>", filename];
	
	[self appendResultItemWithClassName:@"info-item" innerHTML:msg attributes:nil];
}


- (void)parsingService:(id <XMLParsingService>)service didParseSource:(NSString *)sourceURLString sourceXMLString:(NSString *)data duration:(NSTimeInterval)duration {
	//NSLog(@"controller didParseSource:");

	[self setSourceXMLString:data];

	if (![command verbose]) {
		return;
	}	

	NSString *filename = [sourceURLString lastPathComponent];
	
	NSString *msg = [NSString stringWithFormat:@"Finished parsing document: <tt>%@</tt>", filename];
	
	[self appendResultItemWithClassName:@"info-item" innerHTML:msg attributes:nil];
}


#pragma mark -
#pragma mark ErrorHandler

- (void)parsingService:(id <XMLParsingService>)service warning:(NSDictionary *)info {
	errorCount++;
	[self doProblemItemWithClassName:@"warning-item" error:info];
	[self playWarningSound];
}


- (void)parsingService:(id <XMLParsingService>)service error:(NSDictionary *)info {
	errorCount++;
	[self doProblemItemWithClassName:@"error-item" error:info];
	[self playErrorSound];
}


- (void)parsingService:(id <XMLParsingService>)service fatalError:(NSDictionary *)info {
	errorCount++;
	[self doProblemItemWithClassName:@"error-item" error:info];
	[self playErrorSound];
}


#pragma mark -
#pragma mark SchematronMessageHandler

- (void)parsingService:(id <XMLParsingService>)service assertFired:(NSDictionary *)info {
	errorCount++;
	[self doProblemItemWithClassName:@"assert-item" error:info];
	[self playErrorSound];
}


- (void)parsingService:(id <XMLParsingService>)service reportFired:(NSDictionary *)info {
	[self doProblemItemWithClassName:@"report-item" error:info];
}


#pragma mark -
#pragma mark XPathServiceDelegate

- (void)xpathService:(id <XPathService>)service didFinish:(id)result {
	[self setQueryResultString:[result objectForKey:@"highlitedAttributedString"]];	
	[self setQueryResultNodes:[result objectForKey:@"nodes"]];	
	[self setQueryResultLength:[queryResultNodes count]];	
	[self playSuccessSound];
	[[self window] makeFirstResponder:xpathComboBox];
	[self setBusy:NO];
}


- (void)xpathService:(id <XPathService>)service info:(id)info {
	[self appendQueryConsoleString:info];	
}


- (void)xpathService:(id <XPathService>)service error:(id)error {
	[self setQueryResultString:error];
	[self playErrorSound];
	[[self window] makeFirstResponder:xpathComboBox];
	[self setBusy:NO];
}


- (void)xpathService:(id <XPathService>)service parseError:(id)error {
	[tabView selectFirstTabViewItem:self];
	[self parse:self];
}


#pragma mark -
#pragma mark WebFrameLoadDelegate

- (void)webView:(WebView *)sender windowScriptObjectAvailable:(WebScriptObject *)windowScriptObject {
	[windowScriptObject setValue:self forKey:@"PlugIn"];
}


#pragma mark -
#pragma mark WebResourceLoadDelegate

- (NSURLRequest *)webView:(WebView *)sender resource:(id)identifier willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)redirectResponse fromDataSource:(WebDataSource *)dataSource {
	NSString *absURLStr = [[request URL] absoluteString];
	NSRange r = [absURLStr rangeOfString:@"/TextMate/PlugIns/XMLMate.tmplugin/Contents/Resources/"];
	if (NSNotFound == r.location) {
		return nil;
	}
	return request;
}


#pragma mark -
#pragma mark WebUIDelegate

- (NSArray *)webView:(WebView *)sender contextMenuItemsForElement:(NSDictionary *)element defaultMenuItems:(NSArray *)defaultMenuItems {
	return [self contextMenuItems]; 
}


- (unsigned)webView:(WebView *)sender dragDestinationActionMaskForDraggingInfo:(id <NSDraggingInfo>)draggingInfo {
	return WebDragDestinationActionLoad;
}


- (void)webView:(WebView *)sender willPerformDragDestinationAction:(WebDragDestinationAction)action forDraggingInfo:(id <NSDraggingInfo>)draggingInfo {
	NSPasteboard *pboard = [draggingInfo draggingPasteboard];
	int index = [[pboard types] indexOfObject:NSFilenamesPboardType];
	if (NSNotFound != index) {
		NSString *filename = [[pboard propertyListForType:NSFilenamesPboardType] objectAtIndex:0];
		[command setSchemaURLString:filename];
		[self clear:self];
	}
}


#pragma mark -
#pragma mark NSComboBoxDataSource

- (id)comboBox:(NSComboBox *)aComboBox objectValueForItemAtIndex:(int)index {
	if (aComboBox == schemaURLComboBox) {
		return [recentSchemaURLStrings objectAtIndex:index];
	} else {
		return [recentXPathStrings objectAtIndex:index];
	}
}


- (int)numberOfItemsInComboBox:(NSComboBox *)aComboBox {
	if (aComboBox == schemaURLComboBox) {
		return [recentSchemaURLStrings count];
	} else {
		return [recentXPathStrings count];
	}
}


- (NSString *)comboBox:(NSComboBox *)aComboBox completedString:(NSString *)uncompletedString {
	if (aComboBox == schemaURLComboBox) {
		NSEnumerator *e = [recentSchemaURLStrings objectEnumerator];
		NSString *URLString = nil;
	//	NSString *filename = nil;
		while (URLString = [e nextObject]) {
	//		filename = [URLString lastPathComponent];
			if ([URLString hasPrefix:uncompletedString]) {
	//		if ([filename hasPrefix:uncompletedString]) {
	//			int pathLen = [URLString length] - [filename length];
	//			NSRange r1 = [filename rangeOfString:uncompletedString];
	//			NSRange r2 = NSMakeRange(r1.length + pathLen, [URLString length]);
	//			r2;
	//			return URLString;
				return URLString;
			}
		}
	}
	return nil;
}


- (unsigned int)comboBox:(NSComboBox *)aComboBox indexOfItemWithStringValue:(NSString *)aString {
	NSEnumerator *e = [recentSchemaURLStrings objectEnumerator];
	NSString *str = nil;
	int i = 0;
	while (str = [e nextObject]) {
		if ([[str lastPathComponent] hasPrefix:aString]) {
			return i;
		}
		i++;
	}
	return NSNotFound;
}


#pragma mark -
#pragma mark NSTabViewDelegate
/*
- (void)tabView:(NSTabView *)tabView willSelectTabViewItem:(NSTabViewItem *)tabViewItem {
	if (![[tabViewItem identifier] isEqualToString:@"parser"]) {
		return;
	}
	[self updateCatalog];
}
*/


#pragma mark -
#pragma mark NSTextViewDelegate

- (BOOL)textView:(NSTextView *)aTextView shouldChangeTextInRange:(NSRange)affectedCharRange replacementString:(NSString *)replacementString {
	NSBeep();
	return NO;
}


#pragma mark -
#pragma mark NSSplitViewDelegate

- (float)splitView:(NSSplitView *)sender constrainMaxCoordinate:(float)proposedMax ofSubviewAt:(int)offset {
	if (offset == 0) {
		NSRect r = [[self window] frame];
		return r.size.height - 129;
	}
	return proposedMax;
}


- (float)splitView:(NSSplitView *)sender constrainMinCoordinate:(float)proposedMin ofSubviewAt:(int)offset {
	if (offset == 0) {
		return 30;
	}
	return proposedMin;
}


#pragma mark -
#pragma mark NSControlNotifications

- (void)textDidEndEditing:(NSNotification *)aNotification {
	id textField = [aNotification object];
	if ([textField isDescendantOf:catalogTable]) {
		//NSLog(@"textField: %@", textField);
		[self updateCatalog];
	}
}


- (void)menuDidSendAction:(NSNotification *)aNotification {	
	id menu = [aNotification object];
	if ([[[menu itemAtIndex:0] title] isEqualToString:@"Disabled"] 
		&& [[[menu itemAtIndex:1] title] isEqualToString:@"Public"]) {
		//NSLog(@"here");
		[self updateCatalog];
	}
}


- (void)tableSelectionDidChange:(NSNotification *)aNotification {
	[self updateCatalog];
}


#pragma mark -
#pragma mark Accessors

- (BOOL)busy {
	return busy;
}


- (void)setBusy:(BOOL)yn {
	busy = yn;
}


- (BOOL)showSettings {
	return showSettings;
}


- (void)setShowSettings:(BOOL)yn {
	showSettings = yn;
	[self changeSizeForSettings];
}


- (BOOL)playSounds {
	return playSounds;
}


- (void)setPlaySounds:(BOOL)yn {
	playSounds = yn;
}


- (int)preferedCatalogItemType {
	return preferedCatalogItemType;
}


- (void)setPreferedCatalogItemType:(int)n {
	preferedCatalogItemType = n;
	[catalogService setPrefer:n];
}

- (NSMutableArray *)catalogItems {
	return catalogItems;
}


- (void)setCatalogItems:(NSMutableArray *)newItems {
	if (catalogItems != newItems) {
		[catalogItems autorelease];
		catalogItems = [newItems retain];
	}
}


- (XMLParseCommand *)command {
	return command;
}


- (void)setCommand:(XMLParseCommand *)c {
	if (command != c) {
		[command autorelease];
		command = [c retain];
	}
}


- (NSMutableArray *)recentSchemaURLStrings {
	return recentSchemaURLStrings;
}


- (void)setRecentSchemaURLStrings:(NSMutableArray *)newStrs {
	if (recentSchemaURLStrings != newStrs) {
		[recentSchemaURLStrings autorelease];
		recentSchemaURLStrings = [newStrs retain];
	}
}


- (NSMutableArray *)recentXPathStrings {
	return recentXPathStrings;
}


- (void)setRecentXPathStrings:(NSMutableArray *)newStrs {
	if (recentXPathStrings != newStrs) {
		[recentXPathStrings autorelease];
		recentXPathStrings = [newStrs retain];
	}
}


- (NSString *)sourceXMLString {
	return sourceXMLString;
}


- (void)setSourceXMLString:(NSString *)newStr {
	if (sourceXMLString != newStr) {
		[sourceXMLString autorelease];
		sourceXMLString = [newStr retain];
	}
}


- (NSString *)catalogXMLString {
	return catalogXMLString;
}


- (void)setCatalogXMLString:(NSString *)newStr {
	if (catalogXMLString != newStr) {
		[catalogXMLString autorelease];
		catalogXMLString = [newStr retain];
	}
}

- (NSString *)XPathString {
	return XPathString;
}


- (void)setXPathString:(NSString *)newStr {
	if (XPathString != newStr) {
		[XPathString autorelease];
		XPathString = [newStr retain];
	}
}


- (NSAttributedString *)queryResultString {
	return queryResultString;
}


- (void)setQueryResultString:(NSAttributedString *)newStr {
	if (queryResultString != newStr) {
		[queryResultString autorelease];
		queryResultString = [newStr retain];
	}
}


- (NSMutableString *)queryConsoleString {
	return queryConsoleString;
}


- (void)setQueryConsoleString:(NSMutableString *)newStr {
	if (queryConsoleString != newStr) {
		[queryConsoleString autorelease];
		queryConsoleString = [newStr retain];
	}
}


- (int)queryResultLength {
	return queryResultLength;
}


- (void)setQueryResultLength:(int)n {
	queryResultLength = n;
}


- (NSArray *)queryResultNodes {
	return queryResultNodes;
}


- (void)setQueryResultNodes:(NSArray *)a {
	if (queryResultNodes != a) {
		[queryResultNodes autorelease];
		queryResultNodes = [a retain];
	}
}

@end
