/*
 Copyright (C) 2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 IKImageBrowserView's background CALayer subclass for drawing a custom background image.
 */

@import Quartz;
@import Cocoa;

@interface ImageBrowserBackgroundLayer : CALayer

@property (weak) IKImageBrowserView *owner;

@end
