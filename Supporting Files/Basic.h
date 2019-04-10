//
//  Basic.h
//  Basic
//
//  Copyright 2018 bujiandi
//  Licensed under Apache License 2.0
//
//  https://github.com/bujiandi/Basic
//

#include <TargetConditionals.h>

#if TARGET_OS_IPHONE || TARGET_OS_TV || TARGET_IPHONE_SIMULATOR
	#import <UIKit/UIKit.h>
#else
    #import <Cocoa/Cocoa.h>
#endif

//! Project version number for Basic.
FOUNDATION_EXPORT double BasicVersionNumber;

//! Project version string for Basic.
FOUNDATION_EXPORT const unsigned char BasicVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <Basic/PublicHeader.h>


