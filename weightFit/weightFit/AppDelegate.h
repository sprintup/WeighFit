//
//  AppDelegate.h
//  weightFit
//
//  Created by Stephen Printup on 10/24/15.
//  Copyright © 2015 Stephen Printup. All rights reserved.
//

#import <UIKit/UIKit.h>
//#import <GoogleAnalytics/>
#import <Google/Analytics.h>

@import HealthKit;

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (nonatomic) HKHealthStore *healthStore;

@property (strong, nonatomic) UIWindow *window;


@end

