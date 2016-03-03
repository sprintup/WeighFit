//
//  EventListTableViewController.h
//  weightFit
//
//  Created by Stephen R Printup on 1/7/16.
//  Copyright © 2016 Stephen Printup. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "EventInputViewController.h"
@import HealthKit;

@interface EventListTableViewController : UITableViewController <healthKitSaveDelegate>

@property (strong, nonatomic) IBOutlet UITableView *tableViewEventList;
@property (weak, nonatomic) IBOutlet UILabel *labelDate;

@property (strong, nonatomic) NSString *dayString;

@property (nonatomic) HKHealthStore *healthStore;
@property (strong, nonatomic) NSMutableArray *foodItemsHKQuantitySamples;

@end
