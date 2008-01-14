//
//  XMLMateController.h
//  XMLMatePlugIn
//
//  Created by Todd Ditchendorf on 12/23/06.
//  Copyright 2006 Todd Ditchendorf. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class WebView;
@class XMLParseCommand;
@protocol XMLParsingService;
@protocol XMLCatalogService;
@protocol XPathService;

@interface XMLMateController : NSWindowController {
	IBOutlet NSTabView *tabView;
	IBOutlet WebView *parseResultsWebView;
	IBOutlet NSComboBox *schemaURLComboBox;
	IBOutlet NSComboBox *xpathComboBox;
	IBOutlet NSButton *browseButton;
	IBOutlet NSTextView *sourceXMLTextView;
	IBOutlet NSTextView *catalogXMLTextView;
	IBOutlet NSTextView *xpathTreeTextView;
	IBOutlet NSTextView *xpathArrayTextView;
	IBOutlet NSView *bottomView;
	IBOutlet NSTableView *catalogTable;
	IBOutlet NSMenu *catalogItemTypeMenu;

	id <XMLCatalogService> catalogService;
	NSMutableArray *catalogItems;
	NSString *catalogXMLString;
	int preferedCatalogItemType;
	
	BOOL busy;
	BOOL showSettings;
	BOOL playSounds;

	id <XMLParsingService> parsingService;
	int errorCount;
	NSArray *contextMenuItems;
	XMLParseCommand *command;
	NSMutableArray *recentSchemaURLStrings;
	NSMutableArray *recentXPathStrings;
	NSString *sourceXMLString;
	
	id <XPathService> xpathService;
	NSString *XPathString;
	NSAttributedString *queryResultString;
	NSMutableString *queryConsoleString;
	int queryResultLength;
	NSArray *queryResultNodes;
}
- (IBAction)parameterWasChanged:(id)sender;
- (IBAction)validationTypeWasChanged:(id)sender;
- (IBAction)browse:(id)sender;
- (IBAction)parse:(id)sender;
- (IBAction)clear:(id)sender;
- (IBAction)executeQuery:(id)sender;

- (BOOL)busy;
- (void)setBusy:(BOOL)yn;
- (BOOL)showSettings;
- (void)setShowSettings:(BOOL)yn;
- (BOOL)playSounds;
- (void)setPlaySounds:(BOOL)yn;
- (int)preferedCatalogItemType;
- (void)setPreferedCatalogItemType:(int)n;
- (NSMutableArray *)catalogItems;
- (void)setCatalogItems:(NSMutableArray *)newItems;
- (XMLParseCommand *)command;
- (void)setCommand:(XMLParseCommand *)c;
- (NSMutableArray *)recentSchemaURLStrings;
- (void)setRecentSchemaURLStrings:(NSMutableArray *)newStrs;
- (NSMutableArray *)recentXPathStrings;
- (void)setRecentXPathStrings:(NSMutableArray *)newStrs;
- (NSString *)sourceXMLString;
- (void)setSourceXMLString:(NSString *)newStr;
- (NSString *)catalogXMLString;
- (void)setCatalogXMLString:(NSString *)newStr;

- (NSString *)XPathString;
- (void)setXPathString:(NSString *)newStr;
- (NSAttributedString *)queryResultString;
- (void)setQueryResultString:(NSAttributedString *)newStr;
- (NSMutableString *)queryConsoleString;
- (void)setQueryConsoleString:(NSMutableString *)newStr;
- (int)queryResultLength;
- (void)setQueryResultLength:(int)n;
- (NSArray *)queryResultNodes;
- (void)setQueryResultNodes:(NSArray *)a;

@end
