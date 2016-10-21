/*
 Copyright (C) 2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 Main controller class for this application.
 */

@import Quartz;   // for IKImageBrowserView

#import "ImageBrowserView.h"
#import "ImageBrowserController.h"
#import "ImageBrowserBackgroundLayer.h"

// our data source object for the image browser
@interface myImageObject : NSObject

@property (strong) NSURL *url;

@end


#pragma mark -

@implementation myImageObject

#pragma mark - Item data source protocol

// required methods of the IKImageBrowserItem protocol

// -------------------------------------------------------------------------
//  imageRepresentationType
//
//  Let the image browser knows we use a URL representation.
// -------------------------------------------------------------------------
- (NSString *)imageRepresentationType
{
    return IKImageBrowserNSURLRepresentationType;
}

// -------------------------------------------------------------------------
//  imageRepresentation
//
//  Give our representation to the image browser.
// -------------------------------------------------------------------------
- (id)imageRepresentation
{
    return self.url;
}

// -------------------------------------------------------------------------
//  imageUID
//
//  Use the absolute filepath of our URL as identifier.
// -------------------------------------------------------------------------
- (NSString *)imageUID
{
    return self.url.path;
}

// -------------------------------------------------------------------------
//	imageTitle
//
//	Use the last path component as the title.
// -------------------------------------------------------------------------
- (NSString *)imageTitle
{
    return self.url.lastPathComponent.stringByDeletingPathExtension;
}

// -------------------------------------------------------------------------
//	imageSubtitle
//
//	Use the file extension as the subtitle.
// -------------------------------------------------------------------------
- (NSString *)imageSubtitle
{
    return self.url.pathExtension;
}

@end


#pragma mark -

@interface ImageBrowserController ()

@property (weak) IBOutlet ImageBrowserView *imageBrowser;
@property (strong) NSMutableArray *images;
@property (strong) NSMutableArray *importedImages;

- (IBAction)zoomSliderDidChange:(id)sender;
- (IBAction)addImageButtonClicked:(id)sender;

@end


#pragma mark -

@implementation ImageBrowserController

// -------------------------------------------------------------------------
//	viewDidLoad
// -------------------------------------------------------------------------
- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // create two arrays : The first is for the data source representation
	// the second one contains temporary imported images for thread safeness
    _images = [[NSMutableArray alloc] init];
    _importedImages = [[NSMutableArray alloc] init];
    
    // allow reordering, animations and set the dragging destination delegate
    [self.imageBrowser setAllowsReordering:YES];
    [self.imageBrowser setAnimates:YES];
    [self.imageBrowser setDraggingDestinationDelegate:self];
	
	// customize the appearance
	[self.imageBrowser setCellsStyleMask:IKCellsStyleTitled | IKCellsStyleOutlined];

	// background layer
	ImageBrowserBackgroundLayer *backgroundLayer = [[ImageBrowserBackgroundLayer alloc] init];
	[self.imageBrowser setBackgroundLayer:backgroundLayer];
	backgroundLayer.owner = self.imageBrowser;
	
	// change default font
    //
	// create a centered paragraph style
	NSMutableParagraphStyle *paraphStyle = [[NSMutableParagraphStyle alloc] init];
	paraphStyle.lineBreakMode = NSLineBreakByTruncatingMiddle;
	paraphStyle.alignment = NSCenterTextAlignment;
	
    // change the title font
	NSMutableDictionary *attributes = [[NSMutableDictionary alloc] init];
	attributes[NSFontAttributeName] = [NSFont systemFontOfSize:12]; 
	attributes[NSParagraphStyleAttributeName] = paraphStyle;	
	attributes[NSForegroundColorAttributeName] = [NSColor blackColor];
	[self.imageBrowser setValue:attributes forKey:IKImageBrowserCellsTitleAttributesKey];
	
    // change the selected title font
	attributes = [[NSMutableDictionary alloc] init];	
	attributes[NSFontAttributeName] = [NSFont boldSystemFontOfSize:12]; 
	attributes[NSParagraphStyleAttributeName] = paraphStyle;	
	attributes[NSForegroundColorAttributeName] = [NSColor whiteColor];
	[self.imageBrowser setValue:attributes forKey:IKImageBrowserCellsHighlightedTitleAttributesKey];
	
	// change intercell spacing
	[self.imageBrowser setIntercellSpacing:NSMakeSize(10, 80)];
	
	// change selection color
	[self.imageBrowser setValue:[NSColor colorWithCalibratedRed:1 green:0 blue:0.5 alpha:1.0] forKey:IKImageBrowserSelectionColorKey];
	
	// set initial zoom value
	[self.imageBrowser setZoomValue:0.5];
}

// -------------------------------------------------------------------------
//	updateDatasource
//
//	This is the entry point for reloading image browser data and triggering setNeedsDisplay.
// -------------------------------------------------------------------------
- (void)updateDatasource
{
    // update the datasource, add recently imported items
    [self.images addObjectsFromArray:self.importedImages];
	
	// empty the temporary array
    [self.importedImages removeAllObjects];
    
    // reload the image browser, which triggers setNeedsDisplay
    [self.imageBrowser reloadData];
}


#pragma mark - Import images from file system

// -------------------------------------------------------------------------
//	isImageFile:filePath
//
//	This utility method indicates if the file located at 'filePath' is
//	an image file based on the UTI. It relies on the ImageIO framework for the
//	supported type identifiers.
//
// -------------------------------------------------------------------------
- (BOOL)isImageFile:(NSString *)filePath
{
	BOOL isImageFile = NO;
	LSItemInfoRecord info;
	CFStringRef	uti = NULL;
	
	CFURLRef url = CFURLCreateWithFileSystemPath(NULL, (CFStringRef)filePath, kCFURLPOSIXPathStyle, FALSE);
	
	if (LSCopyItemInfoForURL(url, kLSRequestExtension | kLSRequestTypeCreator, &info) == noErr)
	{
		// obtain the UTI using the file information
		
		// if there is a file extension, get the UTI
		if (info.extension != NULL)
		{
			uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, info.extension, kUTTypeData);
			CFRelease(info.extension);
		}

		// no UTI yet
		if (uti == NULL)
		{
			// if there is an OSType, get the UTI
			CFStringRef typeString = UTCreateStringForOSType(info.filetype);
			if ( typeString != NULL)
			{
				uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassOSType, typeString, kUTTypeData);
				CFRelease(typeString);
			}
		}
		
		// verify that this is a file that the ImageIO framework supports
		if (uti != NULL)
		{
			CFArrayRef  supportedTypes = CGImageSourceCopyTypeIdentifiers();
			CFIndex	i, typeCount = CFArrayGetCount(supportedTypes);

			for (i = 0; i < typeCount; i++)
			{
				if (UTTypeConformsTo(uti, (CFStringRef)CFArrayGetValueAtIndex(supportedTypes, i)))
				{
					isImageFile = YES;
					break;
				}
			}
            
            CFRelease(supportedTypes);
            CFRelease(uti);
		}
	}
    
    CFRelease(url);
	
	return isImageFile;
}

// -------------------------------------------------------------------------
//	addAnImageWithPath:url
// -------------------------------------------------------------------------
- (void)addAnImageWithPath:(NSURL *)url
{   
	BOOL addObject = NO;
	
	NSDictionary *fileAttribs = [[NSFileManager defaultManager] attributesOfItemAtPath:url.path error:nil];
	if (fileAttribs != nil)
	{
		// check for packages
		if ([NSFileTypeDirectory isEqualTo:fileAttribs[NSFileType]])
		{
            if ([[NSWorkspace sharedWorkspace] isFilePackageAtPath:url.path] == NO)
            {
				addObject = YES;	// if it is a file, it's OK to add
            }
		}
		else
		{
			addObject = YES;	// it is a file, so it's OK to add
		}
	}
	
	if (addObject && [self isImageFile:url.path])
	{
		// add a URL to the temporary images array
		myImageObject *imageObj = [[myImageObject alloc] init];
        imageObj.url = url;
		[self.importedImages addObject:imageObj];
	}
}

// -------------------------------------------------------------------------
//	addImagesWithPath:url
// -------------------------------------------------------------------------
- (void)addImagesWithPath:(NSURL *)url
{
    BOOL dir = NO;
    [[NSFileManager defaultManager] fileExistsAtPath:url.path isDirectory:&dir];
    if (dir)
	{
		// load all the images in this directory
        NSArray *content = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:url.path error:nil];
        
		// parse the directory content
        for (NSUInteger i = 0; i < content.count; i++)
		{
            NSURL *imageURL = [NSURL fileURLWithPath:[url.path stringByAppendingPathComponent:content[i]]];
            [self addAnImageWithPath:imageURL];
        }
    }
    else
	{
		// single image, just load the one
        [self addAnImageWithPath:url];
	}
}


#pragma mark - Actions

// -------------------------------------------------------------------------
//	addImageButtonClicked:sender
//
//	The user clicked the Add Photos button.
// -------------------------------------------------------------------------
- (IBAction)addImageButtonClicked:(id)sender
{
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    openPanel.canChooseDirectories = YES;
    openPanel.allowsMultipleSelection = YES;
    
    void (^openPanelHandler)(NSInteger) = ^(NSInteger returnCode) {
        if (returnCode == NSFileHandlingPanelOKButton)
        {
            // asynchronously process all URLs from our open panel
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                
                for (NSURL *url in openPanel.URLs)
                {
                    [self addImagesWithPath:url];
                }
                
                // back on the main queue update the data source in the main thread
                dispatch_async(dispatch_get_main_queue(), ^(void) {
                    [self updateDatasource];
                });
            });
        }
    };
    
    [openPanel beginSheetModalForWindow:self.view.window completionHandler:openPanelHandler];
}

// -------------------------------------------------------------------------
//	addImageButtonClicked:sender
//
//	Action called when the zoom slider changes.
// ------------------------------------------------------------------------- 
- (IBAction)zoomSliderDidChange:(id)sender
{
	// update the zoom value to scale images
    [self.imageBrowser setZoomValue:[sender floatValue]];
	
	// redisplay
    [self.imageBrowser setNeedsDisplay:YES];
}


#pragma mark - IKImageBrowserDataSource

// -------------------------------------------------------------------------
//	numberOfItemsInImageBrowser:view
// ------------------------------------------------------------------------- 
- (NSUInteger)numberOfItemsInImageBrowser:(IKImageBrowserView *)view
{
	// The item count to display is the datadsource item count.
    return self.images.count;
}

// -------------------------------------------------------------------------
//	imageBrowser:view:index:
// ------------------------------------------------------------------------- 
- (id)imageBrowser:(IKImageBrowserView *)view itemAtIndex:(NSUInteger)index
{
    return self.images[index];
}


// Implement some optional methods of the image browser  datasource protocol to allow for removing and reodering items.

// -------------------------------------------------------------------------
//	removeItemsAtIndexes:indexes:
//
//	The user wants to delete images, so remove these entries from the data source.	
// ------------------------------------------------------------------------- 
- (void)imageBrowser:(IKImageBrowserView *)view removeItemsAtIndexes:(NSIndexSet *)indexes
{
	[self.images removeObjectsAtIndexes:indexes];
}

// -------------------------------------------------------------------------
//	moveItemsAtIndexes:indexes:toIndex
//
//	The user wants to reorder images, update the datadsource and the browser
//	will reflect our changes.
// ------------------------------------------------------------------------- 
- (BOOL)imageBrowser:(IKImageBrowserView *)aBrowser moveItemsAtIndexes:(NSIndexSet *)indexes toIndex:(NSUInteger)destinationIndex
{
	NSMutableArray *temporaryArray = [[NSMutableArray alloc] init];

	// First remove items from the data source and keep them in a temporary array.
	for (NSUInteger index = indexes.lastIndex; index != NSNotFound; index = [indexes indexLessThanIndex:index])
	{
		if (index < destinationIndex)
        {
            destinationIndex --;
        }

		id obj = self.images[index];
		[temporaryArray addObject:obj];
		[self.images removeObjectAtIndex:index];
	}

	// then insert the removed items at the appropriate location
	for (NSUInteger index = 0; index < temporaryArray.count; index++)
	{
		[self.images insertObject:temporaryArray[index] atIndex:destinationIndex];
	}

	return YES;
}


#pragma mark - Drag and Drop

// -------------------------------------------------------------------------
//	draggingEntered:sender
//
//  Accept any kind of drop.
// ------------------------------------------------------------------------- 
- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
    return NSDragOperationCopy;
}

// -------------------------------------------------------------------------
//	draggingUpdated:sender
// ------------------------------------------------------------------------- 
- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender
{
    return NSDragOperationCopy;
}

// -------------------------------------------------------------------------
//	performDragOperation:sender
// ------------------------------------------------------------------------- 
- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
    NSData *data = nil;
    NSPasteboard *pasteboard = [sender draggingPasteboard];

	// Look for paths on the pasteboard.
    if ([pasteboard.types containsObject:NSFilenamesPboardType])
    {
        data = [pasteboard dataForType:NSFilenamesPboardType];
    }
    
    if (data != nil)
	{
		// retrieve paths
        NSError *error;
        NSArray *filenames =
            [NSPropertyListSerialization propertyListWithData:data options:kCFPropertyListImmutable format:nil error:&error];

        // add path URLs to the data source
        NSMutableArray *urls = [NSMutableArray array];
		for (NSString *file in filenames)
        {
            [urls addObject:[NSURL fileURLWithPath:file]];
        }
        
        for (NSURL *url in urls)
        {
            [self addImagesWithPath:url];
        }
        // make the image browser reload the data source
        [self updateDatasource];
    }

	// we accepted the drag operation
	return YES;
}

@end
