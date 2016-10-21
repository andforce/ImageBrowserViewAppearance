/*
 Copyright (C) 2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 IKImageBrowserView's background CALayer subclass for drawing a custom background image.
 */

#import "ImageBrowserBackgroundLayer.h"

@implementation ImageBrowserBackgroundLayer

// -------------------------------------------------------------------------
//	init
// -------------------------------------------------------------------------
- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
		// needs to redraw when bounds change
		[self setNeedsDisplayOnBoundsChange:YES];
	}
	
	return self;
}

// -------------------------------------------------------------------------
//	actionForKey:
//
// always return nil, to never animate
// -------------------------------------------------------------------------
- (id<CAAction>)actionForKey:(NSString *)event
{
	return nil;
}

// -------------------------------------------------------------------------
//	drawInContext:
//
// draw a metal background that scrolls when the image browser scroll
// -------------------------------------------------------------------------
- (void)drawInContext:(CGContextRef)context
{
	// retreive bounds and visible rect
	NSRect visibleRect = self.owner.visibleRect;
	NSRect bounds = self.owner.bounds;
	
	// retreive background image from our bundle
    NSURL *urlForImage = [[NSBundle mainBundle] URLForResource:@"metal_background" withExtension:@"tif"];
    CGImageSourceRef imageSource = CGImageSourceCreateWithURL((CFURLRef)urlForImage, NULL);
    if (imageSource != nil)
    {
        CGImageRef image = CGImageSourceCreateImageAtIndex(imageSource, 0, NULL);
        if (image != nil)
        {
            float width = (float) CGImageGetWidth(image);
            float height = (float) CGImageGetHeight(image);
            
            // compute coordinates to fill the view
            float left, top, right, bottom;
            
            top = bounds.size.height - NSMaxY(visibleRect);
            top = fmod(top, height);
            top = height - top;
            
            right = NSMaxX(visibleRect);
            bottom = -height;
            
            // tile the image and take in account the offset to 'emulate' a scrolling background
            for (top = visibleRect.size.height-top; top>bottom; top -= height)
            {
                for (left = 0; left < right; left += width)
                {
                    CGContextDrawImage(context, CGRectMake(left, top, width, height), image);
                }
            }
            
            CFRelease(image);
        }
        
        CFRelease(imageSource);
    }
}

@end
