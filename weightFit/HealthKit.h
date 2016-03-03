//
//  HealthKit.h
//  weighFit
//
//  Created by Stephen R Printup on 1/24/16.
//  Copyright © 2016 Stephen Printup. All rights reserved.
//

#import <Foundation/Foundation.h>
@import HealthKit;

@interface HealthKit : NSObject

@property (nonatomic) HKHealthStore *healthStore;
@property (nonatomic) bool authorization;

+ (HealthKit *)getInstance;
-(void) requestAuthorizationToUseHealthData;
@end
