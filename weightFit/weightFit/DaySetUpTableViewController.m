//
//  DaySetUpTableViewController.m
//  weightFit
//
//  Created by Stephen R Printup on 1/2/16.
//  Copyright © 2016 Stephen Printup. All rights reserved.
//

#import "DaySetUpTableViewController.h"
#import "WeighFitModel.h"
#import "PersistedDay+CoreDataProperties.h"
#import "CoreDataStack.h"
#import "HealthKit.h"
#import "HKHealthStore+HKHealthStore_Extensions.h"
#import <Google/Analytics.h>

@interface DaySetUpTableViewController ()
{
    NSDateFormatter *dateFormatter;
    NSDateFormatter *timeFormatter;
    WeighFitModel *instance;
    HealthKit *healthKitInstance;
    CoreDataStack *coreDataStack;
    
    NSNumber *userHeightToCompare;
    NSNumber *userWeightToCompare;
    BOOL healthKitUpdated;
}

@property (nonatomic, strong) NSString *dateToCheck;

@end

@implementation DaySetUpTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    instance = [WeighFitModel getInstance];
    coreDataStack = [CoreDataStack defaultStack];
    
    dateFormatter = [[NSDateFormatter alloc] init];
    timeFormatter = [[NSDateFormatter alloc] init];
    [timeFormatter setDateFormat:@"h:mm a"];
    [dateFormatter setDateFormat:@"MM-dd-yyyy"];
    
    [self setUpHealthKit];
    
    //move view up
    self.textfieldWeight.delegate = self;
}

-(void) viewDidAppear:(BOOL)animated {
    [self setDate];
    [self setHealthKitValues];
    healthKitUpdated = NO;
    
    if (self.day != nil) {
        NSLog(@"day exists: %@",self.day);                                                      //TODO: Ensure proper values are loaded
        [self loadDayToEdit];
    } else
    {
        NSLog(@"day doesn't exist, loading defaults and healthkit data");
        [self loadDefaults];
    }
    
    //google analytics
    id<GAITracker> tracker = [[GAI sharedInstance] defaultTracker];
    [tracker set:kGAIScreenName value:@"daySetup"];
    [tracker send:[[GAIDictionaryBuilder createScreenView] build]];
    
}

-(void)viewDidDisappear:(BOOL)animated {
    //call delegate once if changes were made
    if (healthKitUpdated == YES) {
        [self.delegateCustom healthKitUpdated];
    }
}

#pragma mark - scrolling

-(BOOL)textFieldShouldBeginEditing:(UITextField *)textField {
    NSLog(@"editing");
    dispatch_async(dispatch_get_main_queue(), ^{
        NSIndexPath *rowIndexPath = [NSIndexPath indexPathForRow:5 inSection:0];
        [self.tableView scrollToRowAtIndexPath:rowIndexPath atScrollPosition:UITableViewScrollPositionTop animated:YES];
    });
    return YES;
}

#pragma mark - saving

- (IBAction)buttonSave:(id)sender {
    [self calculateMinutesAwakeToday];  //doesn't save to user defaults
    [self setDate]; //doesn't save to user defaults
    if (self.day != nil) {
        NSLog(@"day exists");
        [self updateDay];
    } else
    {
        NSLog(@"day doesn't yet exist");
        [self insertDay];
    }
    
    //save user defaults
    [self saveUserDefaults];
    
    [self.navigationController popViewControllerAnimated:YES];
}

-(void) updateDay {
    //update defaults
    [self saveUserDefaults];
    
    //update healthKit
    [self updateHealthKit];
    
    //updating day in core data stack
    self.day.todaysDate = self.daySelected;
    self.day.wakeUpTimeToLoad = [self getWakeUpTime];
    self.day.bedTimeToLoad = [self getBedTime];
    
    NSNumber *weightObject = [NSNumber numberWithInt:[self.textfieldWeight.text intValue]];
    //save new weight
    self.day.weight = [weightObject intValue];
    //TODO: reset default weight
    //TODO: update healthkit
    
    NSNumber *heightObject = [NSNumber numberWithInt:[self.textfieldHeight.text intValue]];
    //save new height
    self.day.height = [heightObject intValue];
    //TODO: reset default height
    //TODO: update healthkit
    
    NSNumber *ageObject = [NSNumber numberWithInt:[self.textfieldAge.text intValue]];
    //save new age
    self.day.age = [ageObject intValue];
    //TODO: reset default age
    //TODO: update healthkit
    
    self.day.gender = instance.gender;
    self.day.wakeUpTimeMinutes = self.wakeUpTimeMinutes;
    self.day.minutesAwakeToday = self.minutesAwakeToday;
    self.day.activityLevel = (int)self.segmentedControlActivityLevel.selectedSegmentIndex + 1;
    
    //save to core data
    [coreDataStack saveContext];
}

-(void) insertDay {
    //saving new day to core data stack
    PersistedDay *dayToPersist = [NSEntityDescription insertNewObjectForEntityForName:@"PersistedDay" inManagedObjectContext:coreDataStack.managedObjectContext];
    
    dayToPersist.todaysDate = self.daySelected;
    dayToPersist.wakeUpTimeToLoad = [self getWakeUpTime];
    dayToPersist.bedTimeToLoad = [self getBedTime];
    
//    NSNumber *weightObject = [NSNumber numberWithInt:instance.weight];
//    dayToPersist.weight = [weightObject intValue];
//    NSNumber *heightObject = [NSNumber numberWithInt:instance.height];
//    dayToPersist.height = [heightObject intValue];
//    NSNumber *ageObject = [NSNumber numberWithInt:instance.age];
//    dayToPersist.age = [ageObject intValue];
    
    dayToPersist.weight = [self.textfieldWeight.text intValue];
    dayToPersist.height = [self.textfieldHeight.text intValue];
    dayToPersist.age = [self.textfieldAge.text intValue];
    
    dayToPersist.gender = instance.gender;
    dayToPersist.wakeUpTimeMinutes = self.wakeUpTimeMinutes;
    dayToPersist.minutesAwakeToday = self.minutesAwakeToday;
    dayToPersist.activityLevel = (int)self.segmentedControlActivityLevel.selectedSegmentIndex + 1;
    
    self.dateToCheck = dayToPersist.todaysDate;
    
    [coreDataStack saveContext];
    
    //save to healthkit
    [self updateHealthKit];
}

-(void) saveUserDefaults {
    //save basal
    NSString *saveGender;
    if (self.selectedSegmentControlGender.selectedSegmentIndex == 0)
    {
        saveGender = @"female";
    }
    else
    {
        saveGender = @"male";
    }
    
    NSNumber *saveAge = [NSNumber numberWithInt:[[self.textfieldAge text] intValue]];
    NSNumber *saveHeight = [NSNumber numberWithInt:[[self.textfieldHeight text] intValue]];
    NSNumber *saveWeight = [NSNumber numberWithInt:[[self.textfieldWeight text] intValue]];
    NSNumber *saveActivityLevel = [NSNumber numberWithInt:(int)self.segmentedControlActivityLevel.selectedSegmentIndex];
    
    [[WeighFitModel getInstance] updateAge:[saveAge intValue] andHeight:[saveHeight intValue] andWeight:[saveWeight intValue] andActivityLevel:[saveActivityLevel intValue] andGender:saveGender];
    
}

-(void) updateHealthKit {
    /*
     Adding a new day
     */
    if (self.day == nil) {
        [self saveHeightIntoHealthStore:[self.textfieldHeight.text doubleValue]];
        [self saveWeightIntoHealthStore:[self.textfieldWeight.text doubleValue]];
    }
    
    /*
     If updated weight, update weight in healthkit
     */
    int weight1 = self.day.weight; //weight saved in core data
    int weight2 = [self.textfieldWeight.text intValue]; //modified weight
    if (weight1 != weight2) {
        /*
         Editing old day weight
         */
        [self saveWeightIntoHealthStore:[self.textfieldWeight.text doubleValue]];

    }
    
    /*
     If updated height, update height in healthkit
     */
    int height1 = self.day.height; //height saved in core data
    int height2 = [self.textfieldHeight.text intValue]; //modified height
    if (height1 != height2)
    {
        /*
         Editing old day height
         */
        [self saveHeightIntoHealthStore:[self.textfieldHeight.text doubleValue]];
    }
}

#pragma mark - loading

- (void) loadDefaults {
    /*
     This loads values from NSUserDefaults
     */
    NSString *gender = instance.gender;
    
    if ([gender  isEqual: @"female"])
    {
        [self.selectedSegmentControlGender setSelectedSegmentIndex:0];
    }
    else
    {
        [self.selectedSegmentControlGender setSelectedSegmentIndex:1];
    }
    
    self.textfieldAge.text = [NSString stringWithFormat:@"%d", instance.age];
    self.textfieldHeight.text = [NSString stringWithFormat:@"%d",instance.height];
    self.textfieldWeight.text = [NSString stringWithFormat:@"%d",instance.weight];
    
    if (instance.activityLevel == 1) {
        self.segmentedControlActivityLevel.selectedSegmentIndex = 1;
    }
    else if (instance.activityLevel == 2)
    {
        self.segmentedControlActivityLevel.selectedSegmentIndex = 2;
    }
    else if (instance.activityLevel == 3)
    {
        self.segmentedControlActivityLevel.selectedSegmentIndex = 3;
    }
    else if (instance.activityLevel == 4)
    {
        self.segmentedControlActivityLevel.selectedSegmentIndex = 4;
    }
    else if (instance.activityLevel == 5)
    {
        self.segmentedControlActivityLevel.selectedSegmentIndex = 5;
    }
}

-(void) loadDayToEdit {
    
    self.datePickerDay.date = [dateFormatter dateFromString:self.day.todaysDate];
    self.datePickerWakeUp.date = [timeFormatter dateFromString:self.day.wakeUpTimeToLoad];
    self.datePickerBedTime.date = [timeFormatter dateFromString:self.day.bedTimeToLoad];
    self.textfieldWeight.text = [NSString stringWithFormat:@"%d",self.day.weight];
    self.textfieldAge.text = [NSString stringWithFormat:@"%d",self.day.age];
    self.textfieldHeight.text = [NSString stringWithFormat:@"%d",self.day.height];
    
    //set gender
    if ([self.day.gender  isEqual: @"female"])
    {
        [self.selectedSegmentControlGender setSelectedSegmentIndex:0];
    }
    else
    {
        [self.selectedSegmentControlGender setSelectedSegmentIndex:1];
    }

    //set activitylevel
    if (self.day.activityLevel == 1) {
        self.segmentedControlActivityLevel.selectedSegmentIndex = 0;
    }
    else if (self.day.activityLevel == 2)
    {
        self.segmentedControlActivityLevel.selectedSegmentIndex = 1;
    }
    else if (self.day.activityLevel == 3)
    {
        self.segmentedControlActivityLevel.selectedSegmentIndex = 2;
    }
    else if (self.day.activityLevel == 4)
    {
        self.segmentedControlActivityLevel.selectedSegmentIndex = 3;
    }
    else if (self.day.activityLevel == 5)
    {
        self.segmentedControlActivityLevel.selectedSegmentIndex = 4;
    }
}

#pragma mark - segues
//might not do anything
-(void) notificationsSegue {
    [self performSegueWithIdentifier:@"tutorial" sender:self];
}

#pragma mark - date picker

- (IBAction)datePickerDaySet:(id)sender {
    [self setDate];
}

-(NSString *) getWakeUpTime {
    NSString *stringFromWakeUp = [timeFormatter stringFromDate:self.datePickerWakeUp.date];
    return stringFromWakeUp;
}

-(NSString *) getBedTime {
    NSString *stringFromBedTime = [timeFormatter stringFromDate:self.datePickerBedTime.date];
    return stringFromBedTime;
}

#pragma mark - helper methods

-(void) setDate {
    NSString *formattedDate = [dateFormatter stringFromDate:self.datePickerDay.date];
    self.daySelected = formattedDate;
}

- (void) calculateMinutesAwakeToday {
    //wakeup time minutes
    NSDateFormatter *dateFormatterWakeUp = [[NSDateFormatter alloc] init];
    [dateFormatterWakeUp setDateFormat:@"HH"];
    NSString *hours = [dateFormatterWakeUp stringFromDate:self.datePickerWakeUp.date];
    [dateFormatterWakeUp setDateFormat:@"mm"];
    NSString *minutes = [dateFormatterWakeUp stringFromDate:self.datePickerWakeUp.date];
    int minutesAwakeToday = ([hours intValue] * 60) + [minutes intValue];
    self.wakeUpTimeMinutes = minutesAwakeToday;
    
    //bed time minutes
    NSDateFormatter *dateFormatterBedTime = [[NSDateFormatter alloc] init];
    [dateFormatterBedTime setDateFormat:@"HH"];
    NSString *hourGoingToBed = [dateFormatterBedTime stringFromDate:self.datePickerBedTime.date];
    [dateFormatterBedTime setDateFormat:@"mm"];
    NSString *minuteGoingToBed = [dateFormatterBedTime stringFromDate:self.datePickerBedTime.date];
    int minuteGoingToBedToday = ([hourGoingToBed intValue] * 60) + [minuteGoingToBed intValue];
    
    //minutes awake today
    int totalMinutesAwakeToday = (minuteGoingToBedToday - minutesAwakeToday);
    
    self.minutesAwakeToday = totalMinutesAwakeToday;
}

-(NSInteger) getRestingCalTarget {
    int basalMetabolicRate = [WeighFitModel getInstance].basalMetabolicRate;
    return basalMetabolicRate;
}

#pragma mark - healthkit

-(void) setUpHealthKit {
    healthKitInstance = [HealthKit getInstance];
    self.healthStore = healthKitInstance.healthStore;
    [self setHealthKitValues];
}

-(void) setHealthKitValues {
    [self getUsersHeight];
    [self getUsersWeight];
    [self getUsersAge];
}

// Reading HealthKit Data

- (NSNumber *) getUsersHeight {
    // Fetch user's default height unit in inches.
    HKQuantityType *heightType = [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierHeight];
    // Query to get the user's latest height, if it exists.
    [self.healthStore mostRecentQuantitySampleOfType:heightType predicate:nil completion:^(HKQuantity *mostRecentQuantity, NSError *error) {
        if (!mostRecentQuantity) {
            NSLog(@"Either an error occured fetching the user's height information or none has been stored yet. In your app, try to handle this gracefully.");
        }
        else {
            // Determine the height in the required unit.
            HKUnit *heightUnit = [HKUnit inchUnit];
            double usersHeight = [mostRecentQuantity doubleValueForUnit:heightUnit];
            
            //set height to textfield
            userHeightToCompare = [NSNumber numberWithFloat:usersHeight];
            
            self.textfieldHeight.text = [userHeightToCompare stringValue];                     //TODO: MOVE THIS SOMEWHERE ELSE
        }
    }];
    return userHeightToCompare;
}

- (NSNumber *) getUsersWeight {
    // Query to get the user's latest weight, if it exists.
    HKQuantityType *weightType = [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierBodyMass];
    
    [self.healthStore mostRecentQuantitySampleOfType:weightType predicate:nil completion:^(HKQuantity *mostRecentQuantity, NSError *error) {
        if (!mostRecentQuantity) {
            NSLog(@"Either an error occured fetching the user's weight information or none has been stored yet. In your app, try to handle this gracefully.");
        }
        else {
            // Determine the weight in the required unit.
            HKUnit *weightUnit = [HKUnit poundUnit];
            double userWeight = [mostRecentQuantity doubleValueForUnit:weightUnit];
            userWeightToCompare = [NSNumber numberWithDouble:userWeight];
            
            self.textfieldWeight.text = [userWeightToCompare stringValue];                         //TODO: MOVE THIS SOMEWHERE ELSE
        }
    }];
    return userWeightToCompare;
}

- (void) getUsersAge {
    NSError *error;
    NSDate *dateOfBirth = [self.healthStore dateOfBirthWithError:&error];
    
    if (!dateOfBirth){
        //no birtdate found
    }
    else {
        // Compute the age of the user.
        NSDate *now = [NSDate date];
        
        NSDateComponents *ageComponents = [[NSCalendar currentCalendar] components:NSCalendarUnitYear fromDate:dateOfBirth toDate:now options:NSCalendarWrapComponents];
        
        NSUInteger usersAge = [ageComponents year];
        
        self.textfieldAge.text = [NSNumberFormatter localizedStringFromNumber:@(usersAge) numberStyle:NSNumberFormatterNoStyle];
    }
}

// Writing HealthKit Data                                                                   //TODO: Get Users Gender and nslog

- (void)saveHeightIntoHealthStore:(double)height {
    // Save the user's height into HealthKit.
    HKUnit *inchUnit = [HKUnit inchUnit];
    HKQuantity *heightQuantity = [HKQuantity quantityWithUnit:inchUnit doubleValue:height];
    
    HKQuantityType *heightType = [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierHeight];
    NSDate *now = [NSDate date];
    
    HKQuantitySample *heightSample = [HKQuantitySample quantitySampleWithType:heightType quantity:heightQuantity startDate:now endDate:now];
    
    HKQuantityType *heightObjectType = [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierHeight];
    
    if ([self.healthStore authorizationStatusForType:heightObjectType] == 2) {
        [self.healthStore saveObject:heightSample withCompletion:^(BOOL success, NSError *error) {
            if (!success) {
                NSLog(@"An error occured saving the height sample %@. In your app, try to handle this gracefully. The error was: %@.", heightSample, error);
                abort();
            }
            else if (success)
            {
                NSLog(@"Saved height to healthkit");
                healthKitUpdated = YES;
            }
        }];
    };
}

- (void)saveWeightIntoHealthStore:(double)weight {
    // Save the user's weight into HealthKit.
    HKUnit *poundUnit = [HKUnit poundUnit];
    HKQuantity *weightQuantity = [HKQuantity quantityWithUnit:poundUnit doubleValue:weight];
    
    HKQuantityType *weightType = [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierBodyMass];
    NSDate *now = [dateFormatter dateFromString:self.daySelected];
    
    HKQuantitySample *weightSample = [HKQuantitySample quantitySampleWithType:weightType quantity:weightQuantity startDate:now endDate:now];
    
    HKQuantityType *weightObjectType = [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierBodyMass];
    
    if ([self.healthStore authorizationStatusForType:weightObjectType] == 2) {
        [self.healthStore saveObject:weightSample withCompletion:^(BOOL success, NSError *error) {
            if (!success) {
                NSLog(@"An error occured saving the weight sample %@. In your app, try to handle this gracefully. The error was: %@.", weightSample, error);
                abort();
            }
            else if (success)
            {
                NSLog(@"Saved weight to healthkit");
                healthKitUpdated = YES;
            }
        }];
    };
}

@end
