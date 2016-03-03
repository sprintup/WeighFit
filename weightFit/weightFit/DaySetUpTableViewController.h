//
//  DaySetUpTableViewController.h
//  weightFit
//
//  Created by Stephen R Printup on 1/2/16.
//  Copyright © 2016 Stephen Printup. All rights reserved.
//

#import <UIKit/UIKit.h>

@class PersistedDay;

@import HealthKit;

@protocol healthKitUpdateDelegate <NSObject>

-(void) healthKitUpdated;

@end

@interface DaySetUpTableViewController : UITableViewController <UITextFieldDelegate>

@property (weak, nonatomic) IBOutlet UIDatePicker *datePickerDay;
@property (weak, nonatomic) IBOutlet UIDatePicker *datePickerWakeUp;
@property (weak, nonatomic) IBOutlet UIDatePicker *datePickerBedTime;
@property (weak, nonatomic) IBOutlet UITextField *textfieldAge;
@property (weak, nonatomic) IBOutlet UITextField *textfieldWeight;
@property (weak, nonatomic) IBOutlet UITextField *textfieldHeight;
@property (weak, nonatomic) IBOutlet UISegmentedControl *selectedSegmentControlGender;
@property (weak, nonatomic) IBOutlet UISegmentedControl *segmentedControlActivityLevel;

@property (nonatomic) HKHealthStore *healthStore;

@property (nonatomic) int minutesAwakeToday;
@property (nonatomic) float wakeUpTimeMinutes;

@property (nonatomic, strong) NSString *daySelected;

@property (nonatomic, strong) PersistedDay *day;

@property (strong, nonatomic) id <healthKitUpdateDelegate> delegateCustom;

- (IBAction)buttonSave:(id)sender;

@end
