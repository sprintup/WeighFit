//
//  DayListTableViewController.h
//  weightFit
//
//  Created by Stephen R Printup on 1/6/16.
//  Copyright © 2016 Stephen Printup. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "PersistedDay+CoreDataProperties.h"
#import "DaySetUpTableViewController.h"
@import HealthKit;

@interface DayListTableViewController : UITableViewController <healthKitUpdateDelegate>

@property (weak, nonatomic) IBOutlet UILabel *labelNextMeal;

@property (nonatomic) int totalCalorieTarget;

@property (nonatomic) HKHealthStore *healthStore;
@property (strong, nonatomic) NSMutableArray *foodItemsHKQuantitySamples;
@property (strong, nonatomic) NSMutableArray *foodItemsHKQuantitySamplesForDayToDelete;
@property (strong, nonatomic) NSString *dayString;
@property (strong, nonatomic) NSString *todayString;

@end
