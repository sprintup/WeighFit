//
//  EventInputViewController.h
//  weighFit
//
//  Created by Stephen R Printup on 1/16/16.
//  Copyright © 2016 Stephen Printup. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "PersistedEvent+CoreDataProperties.h"
@import HealthKit;
@import SafariServices;

@protocol healthKitSaveDelegate <NSObject>

-(void) savedToHealthKit;

@end

@interface EventInputViewController : UIViewController <UITableViewDelegate, UITableViewDataSource>

@property (weak, nonatomic) IBOutlet UILabel *labelDate;
@property (weak, nonatomic) IBOutlet UITextField *textFieldCalories;
@property (weak, nonatomic) IBOutlet UISegmentedControl *segmentedControlEventType;
@property (weak, nonatomic) IBOutlet UITextField *textFieldDescription;
@property (weak, nonatomic) IBOutlet UIDatePicker *datePickerEventTime;

@property (weak, nonatomic) IBOutlet UITableView *tableViewAllEvents;
@property (strong, nonatomic) NSString *dayString;

@property (nonatomic) HKHealthStore *healthStore;
@property (strong, nonatomic) NSMutableArray *foodItemsHKQuantitySamples;

@property (strong, nonatomic) PersistedEvent *eventToEdit;

@property (strong, nonatomic) id <healthKitSaveDelegate> delegateCustom;

@end
