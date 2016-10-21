/*
 Copyright (C) 2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 IKImageBrowserView subclass used to override newCellForRepresentedItem.
 */

#import "ImageBrowserView.h"
#import "ImageBrowserCell.h"

@interface ImageBrowserView ()

@property NSRect lastVisibleRect;

@end


#pragma mark -

@implementation ImageBrowserView

//---------------------------------------------------------------------------------
// newCellForRepresentedItem:
//
// Allocate and return our own cell class for the specified item. The returned cell must not be autoreleased 
//---------------------------------------------------------------------------------
- (IKImageBrowserCell *)newCellForRepresentedItem:(id)cell
{
	return [[ImageBrowserCell alloc] init];
}

//---------------------------------------------------------------------------------
// drawRect:
//
// override draw rect and force the background layer to redraw if the view did resize or did scroll 
//---------------------------------------------------------------------------------
- (void)drawRect:(NSRect) rect
{
	// retrieve the visible area
	NSRect visibleRect = self.visibleRect;
	
	// compare with the visible rect at the previous frame
	if (!NSEqualRects(visibleRect, self.lastVisibleRect))
    {
		// we did scroll or resize, redraw the background
		[[self backgroundLayer] setNeedsDisplay];
		
		// update last visible rect
		_lastVisibleRect = visibleRect;
	}
	
	[super drawRect:rect];
}

@end
