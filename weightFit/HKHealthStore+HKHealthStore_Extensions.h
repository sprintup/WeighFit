//
//  HKHealthStore+HKHealthStore_Extensions.h
//  weighFit
//
//  Created by Stephen R Printup on 1/24/16.
//  Copyright © 2016 Stephen Printup. All rights reserved.
//

#import <HealthKit/HealthKit.h>
@import HealthKit;

@interface HKHealthStore (HKHealthStore_Extensions)

- (void) mostRecentQuantitySampleOfType:(HKQuantityType *)quantityType predicate:(NSPredicate *)predicate completion:(void (^)(HKQuantity *mostRecentQuantity, NSError *error))completion;

@end
