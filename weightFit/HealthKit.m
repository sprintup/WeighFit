//
//  HealthKit.m
//  weighFit
//
//  Created by Stephen R Printup on 1/24/16.
//  Copyright © 2016 Stephen Printup. All rights reserved.
//

#import "HealthKit.h"
#import "HKHealthStore+HKHealthStore_Extensions.h"

@implementation HealthKit

static HealthKit *sharedSingleton;

//create singleton
+ (HealthKit *)getInstance
{
    if (sharedSingleton == nil) {
        sharedSingleton = [[super alloc]init];
    }
    return sharedSingleton;
}


//create healthstore
-(instancetype)init {
    self = [super init];
    
    if (self) {
        self.healthStore = [[HKHealthStore alloc] init];
        self.authorization = NO;
    }
    
    return self;
}

-(void) requestAuthorizationToUseHealthData
{
    if ([HKHealthStore isHealthDataAvailable]) {
        NSSet *writeDataTypes = [self dataTypesToWrite];
        NSSet *readDataTypes = [self dataTypesToRead];
        
        [self.healthStore requestAuthorizationToShareTypes:writeDataTypes readTypes:readDataTypes completion:^(BOOL success, NSError *error) {
            if (!success) {
                NSLog(@"You didn't allow HealthKit to access these read/write data types. In your app, try to handle this error gracefully when a user decides not to provide access. The error was: %@. If you're using a simulator, try it on a device.", error);
                return;
            } else {
                NSLog(@"authorized");
                self.authorization = YES;
                return;
            }
        }];
    }
}

#pragma mark - HealthKit Permissions

// Returns the types of data that Fit wishes to write to HealthKit.
- (NSSet *)dataTypesToWrite {
    
    HKQuantityType *dietaryCalorieEnergyType = [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierDietaryEnergyConsumed];
    HKQuantityType *heightType = [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierHeight];
    HKQuantityType *weightType = [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierBodyMass];
    
    return [NSSet setWithObjects: dietaryCalorieEnergyType, heightType, weightType, nil];
}

// Returns the types of data that Fit wishes to read from HealthKit.
- (NSSet *)dataTypesToRead {
    
    HKQuantityType *dietaryCalorieEnergyType = [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierDietaryEnergyConsumed];
    HKQuantityType *heightType = [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierHeight];
    HKQuantityType *weightType = [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierBodyMass];
    HKCharacteristicType *birthdayType = [HKObjectType characteristicTypeForIdentifier:HKCharacteristicTypeIdentifierDateOfBirth];
    HKCharacteristicType *biologicalSexType = [HKObjectType characteristicTypeForIdentifier:HKCharacteristicTypeIdentifierBiologicalSex];
    
    return [NSSet setWithObjects: dietaryCalorieEnergyType, birthdayType, heightType, weightType, biologicalSexType, nil];
}



@end
