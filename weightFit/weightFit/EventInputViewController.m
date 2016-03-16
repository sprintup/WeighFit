

//
//  EventInputViewController.m
//  weighFit
//
//  Created by Stephen R Printup on 1/16/16.
//  Copyright © 2016 Stephen Printup. All rights reserved.
//

#import "EventInputViewController.h"
#import "CoreDataStack.h"
#import "HealthKit.h"
#import "HKHealthStore+HKHealthStore_Extensions.h"
#import "FoodObject.h"
#import <Google/Analytics.h>

@interface EventInputViewController () <NSFetchedResultsControllerDelegate, SFSafariViewControllerDelegate, UITextFieldDelegate>
{
    CoreDataStack *coreDataStack;
    NSMutableArray *fetchedObjects;
    PersistedDay *today;
    UIRefreshControl *refreshControl;
    NSArray *sortedEvents;
    HealthKit *healthKitInstance;
    NSDateFormatter *eventTimeFormatter;
    NSDateFormatter *eventDateFormatter;
    NSDateFormatter *combinedDateFormatter;
    
    NSMutableDictionary *filteredEventsDictionary;
    NSMutableArray *filterKeys;
    NSMutableArray *keysThatMatchSearch;
    NSMutableArray *filteredEventsArray;
    
    FoodObject *foodObjectOld;
    FoodObject *foodObjectNew;
    
    HKQuantitySample *mealToDeleteFromHealthKit;
    BOOL healthKitHasChanges;
    
}
@property (nonatomic, strong) NSFetchedResultsController *fetchedResultsController;

@end

@implementation EventInputViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    coreDataStack = [CoreDataStack defaultStack];
    self.labelDate.text = self.dayString;
    
    eventTimeFormatter = [[NSDateFormatter alloc] init];
    [eventTimeFormatter setDateFormat:@"hh:mm:ss a"];
    
    eventDateFormatter = [[NSDateFormatter alloc] init];
    [eventDateFormatter setDateFormat:@"MM-dd-yyyy"];
    
    combinedDateFormatter = [[NSDateFormatter alloc] init];
    [combinedDateFormatter setDateFormat:@"MM-dd-yyyy hh:mm:ss a"];
    
    filteredEventsDictionary = [[NSMutableDictionary alloc] init];
    filterKeys = [[NSMutableArray alloc] init];
    keysThatMatchSearch = [[NSMutableArray alloc] init];
    filteredEventsArray = [[NSMutableArray alloc] init];
    
    [self setUpRefreshControl];
    [self setUpHealthKit];
    
    [self allEventsFetchRequest];           //TODO: POSSIBLY REMOVE THIS
    [self loadEvents];
    
    //text field sorting
    self.textFieldDescription.delegate = self;
    
    //updating and deleting healthkit objects
    foodObjectNew = [[FoodObject alloc] init];
    foodObjectOld = [[FoodObject alloc] init];
}

-(void)viewWillAppear:(BOOL)animated {
    //    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, .5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{               //TODO: Move this to a background thread
    //        [self.fetchedResultsController performFetch:nil];
    //        [self refreshTable];
    //    });
    
    [self.fetchedResultsController performFetch:nil];
    [self refreshTable]; 
    
    //loading event to edit
    if (self.eventToEdit != nil) {
        [self loadEventValues];
    }
    
    //load healthkit data
    [self HKMealQuery];
    
    //google analytics
    id<GAITracker> tracker = [[GAI sharedInstance] defaultTracker];
    [tracker set:kGAIScreenName value:@"eventInput"];
    [tracker send:[[GAIDictionaryBuilder createScreenView] build]];

}

-(void)viewDidDisappear:(BOOL)animated {
    NSLog(@"viewDisappeared");
    if (healthKitHasChanges == YES) {
        [self.delegateCustom savedToHealthKit];
    }
}

//TODO: I don't have to refetch the event because they share the same MOC
-(void) loadEventValues {
    /*
     There is an event to edit, this method loads this events properties into view
     */
    
    //load description
    if (self.eventToEdit.eventDescription != nil) {
        self.textFieldDescription.text = self.eventToEdit.eventDescription;
    }
    
    //load calories
    self.textFieldCalories.text = [NSString stringWithFormat:@"%d", self.eventToEdit.eventCalories];
    
    //setting meal or actiivty
    if ([self.eventToEdit.eventType isEqualToString:@"Meal"]) {
        self.segmentedControlEventType.selectedSegmentIndex = 0;
    }
    else
    {
        self.segmentedControlEventType.selectedSegmentIndex = 1;
    }
    //loading time
    if (self.eventToEdit.eventTime != nil) {
        self.datePickerEventTime.date = [eventTimeFormatter dateFromString:[self.eventToEdit eventTime]];
    }
    
    //set food object to test for changes
    foodObjectOld.calories = self.eventToEdit.eventCalories;
    foodObjectOld.name = self.eventToEdit.eventDescription;
    foodObjectOld.time = [eventTimeFormatter dateFromString:[self.eventToEdit eventTime]];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.fetchedResultsController.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if ([sortedEvents count] == 0) {
        UIImage *image = [UIImage imageNamed:@"eventInput.png"];
        UIImageView *imageView = [[UIImageView alloc] initWithImage:image];
        imageView.contentMode = UIViewContentModeScaleAspectFit;
        // Add image view on top of table view
        [self.tableViewAllEvents addSubview:imageView];
        
        // Set the background view of the table view
        self.tableViewAllEvents.backgroundView = imageView;
        
        //remove cell seperators
        self.tableViewAllEvents.separatorStyle = UITableViewCellSeparatorStyleNone;
    }
    else
    {
        self.tableViewAllEvents.backgroundView = nil;
        
        //add cell seperators
        self.tableViewAllEvents.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    }
    return [filteredEventsArray count];
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    
    if (!cell)
    {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
    }
    PersistedEvent *singleEvent;
    if (([sortedEvents count] > 0) && (![filteredEventsArray count] > 0)) {
        //no filter
        singleEvent = [sortedEvents objectAtIndex:indexPath.row];
    } else if ([filteredEventsArray count] > 0)
    {
        //filter found something
        singleEvent = [filteredEventsArray objectAtIndex:[indexPath row]];
    }
    
    cell.textLabel.text = [self getDescriptionStringWithEvent:singleEvent];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%d", singleEvent.eventCalories];
    
    return cell;
}

-(NSMutableString *) getDescriptionStringWithEvent:(PersistedEvent *)event {
    NSMutableString *descriptionString = [NSMutableString stringWithString:event.eventDescription];
    if ([event.eventType isEqualToString:@"Activity"]) {
        [descriptionString appendString:@" (Activity)"];
    }
    return descriptionString;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    PersistedEvent *eventSelected = [filteredEventsArray objectAtIndex:indexPath.row];
    self.textFieldCalories.text = [NSString stringWithFormat:@"%d", eventSelected.eventCalories];
    self.textFieldDescription.text = eventSelected.eventDescription;
    if ([eventSelected.eventType isEqualToString:@"Activity"]) {
        self.segmentedControlEventType.selectedSegmentIndex = 1;
    } else {
        self.segmentedControlEventType.selectedSegmentIndex = 0;
    }
}

#pragma mark - core data

-(NSFetchedResultsController *) fetchedResultsController {
    if (_fetchedResultsController != nil) {
        return _fetchedResultsController;
    }
    
    NSFetchRequest *eventFetchRequest = [self allEventsFetchRequest];
    
    _fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:eventFetchRequest managedObjectContext:coreDataStack.managedObjectContext sectionNameKeyPath:nil cacheName:nil];
    _fetchedResultsController.delegate = self;
    
    return _fetchedResultsController;
}

-(NSFetchRequest *) allEventsFetchRequest {
    NSFetchRequest *eventFetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"PersistedDay" inManagedObjectContext:coreDataStack.managedObjectContext];
    [eventFetchRequest setEntity:entity];
    
    eventFetchRequest.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"todaysDate" ascending:YES]];
    
    NSError *error = nil;
    fetchedObjects = [NSMutableArray arrayWithArray:[coreDataStack.managedObjectContext executeFetchRequest:eventFetchRequest error:&error]];
    
    return eventFetchRequest;
}

-(void)loadEvents {
    NSMutableArray *events = [[NSMutableArray alloc] init];
    
    for (PersistedDay *dayRandom in fetchedObjects) {
        //set today
        if ([dayRandom.todaysDate isEqualToString:self.dayString]) {
            today = dayRandom; //this represents today
        }
        //add events to array
        [events addObjectsFromArray:[dayRandom.event allObjects]];
    }
    
    //remove duplicates in events
    NSMutableDictionary *filterDuplicateEventsDictionary = [[NSMutableDictionary alloc] init];
    NSMutableArray *filteredDuplicateEventsArray = [[NSMutableArray alloc] init];
    for (PersistedEvent *event in events) {
        if (![filterDuplicateEventsDictionary valueForKey:event.eventDescription]) {
            //if the event description is not in the list of filtered events
            NSMutableArray *eventsCaloriesArray = [[NSMutableArray alloc] init];
            [eventsCaloriesArray addObject:[NSNumber numberWithInt:event.eventCalories]];
            [filterDuplicateEventsDictionary setObject:eventsCaloriesArray forKey:event.eventDescription];
            [filteredDuplicateEventsArray addObject:event];
        }
        else if ([filterDuplicateEventsDictionary valueForKey:event.eventDescription])
        {
            //if the event is in the list of filtered events, but maybe the calories are not
            NSMutableArray *caloiresArray = [filterDuplicateEventsDictionary objectForKey:event.eventDescription];
            
            if (![caloiresArray containsObject:[NSNumber numberWithInt:event.eventCalories]]) {
                //event calories is not a duplicate, add number of calories
                [caloiresArray addObject:[NSNumber numberWithInt: event.eventCalories]];
                [filteredDuplicateEventsArray addObject:event];
            }
        }
    }
    
    //sort array
    NSSortDescriptor *sortDescriptorDescription = [[NSSortDescriptor alloc] initWithKey:@"eventDescription" ascending:YES];
    NSSortDescriptor *sortDescriptorCalories = [[NSSortDescriptor alloc] initWithKey:@"eventCalories" ascending:YES];
    NSMutableArray *sortDescriptors = [NSMutableArray arrayWithObjects:sortDescriptorCalories, sortDescriptorDescription, nil];
    sortedEvents = [filteredDuplicateEventsArray sortedArrayUsingDescriptors:sortDescriptors];
    
    //set events user can filter through
    for (PersistedEvent *event in sortedEvents) {
        [filteredEventsDictionary setObject:event forKey:event.eventDescription];
    }
    
    filterKeys = [NSMutableArray arrayWithArray:[filteredEventsDictionary allKeys]];
    filteredEventsArray = [NSMutableArray arrayWithArray:sortedEvents];
}

#pragma mark - buttons

- (IBAction)buttonSave:(id)sender {                                                         //TODO: CHECK IF IT IS AN ACTIVITY
    if ((self.eventToEdit != nil) && [self doesTheEventHaveChanges]) {
        //day to modify has modifications made
        [self updateDay];
    }
    else if (![self doesTheEventHaveChanges]) {
        //day to modify has no changes
        [self dismissViewControllerAnimated:YES completion:nil];
    }
    else {
        //add new day
        [self insertNewEvent];
    }
    
    [self.navigationController popViewControllerAnimated:YES];
}

-(BOOL) doesTheEventHaveChanges {
    BOOL hasChanges = NO;
    
    //set object to test against
    foodObjectNew.calories = [self.textFieldCalories.text intValue];
    foodObjectNew.name = self.textFieldDescription.text;
    foodObjectNew.time = self.datePickerEventTime.date;
    
    if (foodObjectNew.calories != foodObjectOld.calories) {
        hasChanges = YES;
    }
    if (foodObjectNew.name != foodObjectOld.name) {
        hasChanges = YES;
    }
    if (foodObjectNew.time != foodObjectOld.time) {
        hasChanges = YES;
    }
    return hasChanges;
}

-(void) insertNewEvent {
    //save event to core data
    PersistedEvent *eventToPersist = [NSEntityDescription insertNewObjectForEntityForName:@"PersistedEvent" inManagedObjectContext:coreDataStack.managedObjectContext];
    PersistedDay *dayToHoldEvent = today;     //TODAY IS SET DURING THE LOADING OF EVENTS
    
    eventToPersist.eventTime = [eventTimeFormatter stringFromDate:self.datePickerEventTime.date];
    eventToPersist.eventDate = [eventDateFormatter stringFromDate:self.datePickerEventTime.date];
    eventToPersist.eventDescription = self.textFieldDescription.text;
    eventToPersist.eventCalories = [self.textFieldCalories.text intValue];
    eventToPersist.eventType = [self getEventType];
    [eventToPersist setDay:dayToHoldEvent];
    
    [coreDataStack saveContext];
    
    //save to health kit if it's a meal
    if ([[self getEventType] isEqualToString:@"Meal"]) {
        [self saveMealToHealthKit];
    }
}

-(void) updateDay {
    //delete HKObject
    [self deleteOldMealFromHealthKit];
    
    //create HKObject to save to healthkit only if it's a meal
    if ([[self getEventType] isEqualToString:@"Meal"]) {
    [self saveMealToHealthKit];
    }
    
    //save changes to core data must be later than deleting meal from healthkit
    [self saveChangesToCoreData];
}

-(void) saveChangesToCoreData {
    self.eventToEdit.eventTime = [eventTimeFormatter stringFromDate:self.datePickerEventTime.date];;
    self.eventToEdit.eventDescription = self.textFieldDescription.text;
    self.eventToEdit.eventCalories = [self.textFieldCalories.text intValue];
    self.eventToEdit.eventType = [self getEventType];
    [coreDataStack saveContext];
}

- (IBAction)buttonSearch:(id)sender {
    SFSafariViewController *safariViewController = [[SFSafariViewController alloc] initWithURL:[NSURL URLWithString:@"http://www.google.com"]];
    [self.navigationController presentViewController:safariViewController animated:YES completion:nil];
}

#pragma mark - healthkit
//initializing
-(void) setUpHealthKit {
    healthKitInstance = [HealthKit getInstance];
    self.healthStore = healthKitInstance.healthStore;
    self.foodItemsHKQuantitySamples = [[NSMutableArray alloc] init];
}

-(void) HKMealQuery {
    NSCalendar *calendar = [NSCalendar currentCalendar];
    
    NSDate *now = [eventDateFormatter dateFromString:self.dayString];
    
    NSDateComponents *components = [calendar components:NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay fromDate:now];
    
    NSDate *startDate = [calendar dateFromComponents:components];
    
    NSDate *endDate = [calendar dateByAddingUnit:NSCalendarUnitDay value:1 toDate:startDate options:0];
    
    HKSampleType *sampleType = [HKSampleType quantityTypeForIdentifier:HKQuantityTypeIdentifierDietaryEnergyConsumed];
    NSPredicate *predicate = [HKQuery predicateForSamplesWithStartDate:startDate endDate:endDate options:HKQueryOptionNone];
    
    HKSampleQuery *query = [[HKSampleQuery alloc] initWithSampleType:sampleType predicate:predicate limit:HKObjectQueryNoLimit sortDescriptors:nil resultsHandler:^(HKSampleQuery *query, NSArray *results, NSError *error) {
        if (!results) {
            NSLog(@"An error occured fetching the user's tracked food. In your app, try to handle this gracefully. The error was: %@.", error);
            abort();
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.foodItemsHKQuantitySamples removeAllObjects];
            //loads objects from health kit into an array
            for (HKQuantitySample *sample in results) {
                [self.foodItemsHKQuantitySamples addObject:sample];
            }
        });
    }];
    [self.healthStore executeQuery:query];
}

//saving        TODO: CHANGE DATE INPUT SO DATE SHOWS UP AS TODAY
-(void) saveMealToHealthKit {
    FoodObject *mealToAddToHealthKit = [[FoodObject alloc] initWithCalories:[self.textFieldCalories.text doubleValue] andDescription:self.textFieldDescription.text andTime:[self getDateTimeOfMealToEnterToHealthKit]];
    
    [self addFoodItem:mealToAddToHealthKit];
}

-(void)addFoodItem:(FoodObject *)foodItem {
    // Create a new food correlation for the given food item.
    HKCorrelation *foodCorrelationForFoodItem = [self foodCorrelationForFoodItemToAdd:foodItem];
    HKQuantityType *dietaryCalorieEnergyType = [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierDietaryEnergyConsumed];
    
    if ([self.healthStore authorizationStatusForType:dietaryCalorieEnergyType] == 2) {
        [self.healthStore saveObject:foodCorrelationForFoodItem withCompletion:^(BOOL success, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (success) {
                    NSLog(@"Food Saved to HK: %@",foodItem.description);
                    
                    //set off animation
                    healthKitHasChanges = YES;
                }
                else {
                    NSLog(@"An error occured saving the food %@. In your app, try to handle this gracefully. The error was: %@.", foodItem.description, error);
                    
                    abort();
                }
            });
        }];
    };
}

-(HKCorrelation *)foodCorrelationForFoodItemToAdd:(FoodObject *)foodItem {
    /*
     Retrieves all of the events for today
     */
    //    NSDate *now = [NSDate date];
    
    HKQuantity *energyQuantityConsumed = [HKQuantity quantityWithUnit:[HKUnit kilocalorieUnit] doubleValue:foodItem.calories];
    
    HKQuantityType *energyConsumedType = [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierDietaryEnergyConsumed];
    
    //    HKQuantitySample *energyConsumedSample = [HKQuantitySample quantitySampleWithType:energyConsumedType quantity:energyQuantityConsumed startDate:self.datePickerEventTime.date endDate:self.datePickerEventTime.date];
    HKQuantitySample *energyConsumedSample = [HKQuantitySample quantitySampleWithType:energyConsumedType quantity:energyQuantityConsumed startDate:[foodItem time]  endDate:[foodItem time]];
    
    NSSet *energyConsumedSamples = [NSSet setWithObject:energyConsumedSample];
    
    HKCorrelationType *foodType = [HKObjectType correlationTypeForIdentifier:HKCorrelationTypeIdentifierFood];
    
    NSDictionary *foodCorrelationMetadata = @{HKMetadataKeyFoodType: foodItem.name};
    
    //    HKCorrelation *foodCorrelation = [HKCorrelation correlationWithType:foodType startDate:now endDate:now objects:energyConsumedSamples metadata:foodCorrelationMetadata];
    HKCorrelation *foodCorrelation = [HKCorrelation correlationWithType:foodType startDate:[foodItem time] endDate:[foodItem time] objects:energyConsumedSamples metadata:foodCorrelationMetadata];
    
    
    return foodCorrelation;
}

-(NSDate *) getDateTimeOfMealToEnterToHealthKit {
    NSDate *dateTimeOfVisibleEvent;
    /*
     if no event to edit then just return todays date and time pickers time
     */
    NSMutableString *dateOfMealToInsert;
    NSMutableString *dateWithSpace;
    NSString *timeOfMealToInsert;
    NSMutableString *combinedString;
    NSDate *combinedDate;
    
    if (self.eventToEdit != nil && [self.dayString isEqualToString:[eventDateFormatter stringFromDate:[NSDate date]]]) {
        /*
         User would like to modify one of today's events. Make a string with which to make date to store in healthkit.
         */
        dateOfMealToInsert = [NSMutableString stringWithString:[self.eventToEdit eventDate]];
        
        dateWithSpace = [NSMutableString stringWithString:[dateOfMealToInsert stringByAppendingString:@" "]];
        
        timeOfMealToInsert = [self.eventToEdit eventTime];
        if (![[eventTimeFormatter stringFromDate:self.datePickerEventTime.date] isEqualToString:[self.eventToEdit eventTime]]) {
            /*
             user changed the time of the event
             */
            timeOfMealToInsert = [eventTimeFormatter stringFromDate:self.datePickerEventTime.date];
        }
        
        //assemble date and time into return
        combinedString = [NSMutableString stringWithString:[dateWithSpace stringByAppendingString:timeOfMealToInsert]];
        combinedDate = [combinedDateFormatter dateFromString:combinedString];
        dateTimeOfVisibleEvent = combinedDate;
    }
    else if (![self.dayString isEqualToString:[eventDateFormatter stringFromDate:[NSDate date]]])
    {
        /*
        This event belogs to a day other than today and the date should change along with the time
         */
        dateOfMealToInsert = [NSMutableString stringWithString:self.dayString];
        dateWithSpace = [NSMutableString stringWithString:[dateOfMealToInsert stringByAppendingString:@" "]];
        if ([self.eventToEdit eventTime] != nil) {
            /*
             modifying event of day other than today
             */
            timeOfMealToInsert = [self.eventToEdit eventTime];
        }
        if (![[eventTimeFormatter stringFromDate:self.datePickerEventTime.date] isEqualToString:[self.eventToEdit eventTime]]) {
            /*
             user changed the time of the event in day other than today
             */
            timeOfMealToInsert = [eventTimeFormatter stringFromDate:self.datePickerEventTime.date];
        }
        
        //assemble date and time into return date
        combinedString = [NSMutableString stringWithString:[dateWithSpace stringByAppendingString:timeOfMealToInsert]];
        combinedDate = [combinedDateFormatter dateFromString:combinedString];
        dateTimeOfVisibleEvent = combinedDate;
    }
    else {
        // no day to edit means new event and hkdate should be today
        dateTimeOfVisibleEvent = self.datePickerEventTime.date;
    }
    return dateTimeOfVisibleEvent;
}

//deleting
-(void) deleteOldMealFromHealthKit {
    mealToDeleteFromHealthKit = [self findObjectInTodaysHKObjectsToDelete];                             //TODO: THIS IS NOT LOADING THE ARRAY OF MEALS TO DELETE
    
    //delete mealToDelete if not nil
    if (mealToDeleteFromHealthKit != nil) {
        [self.healthStore deleteObject:mealToDeleteFromHealthKit withCompletion:^(BOOL success, NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (success) {
                    NSLog(@"Food Deleted from HK: %@",mealToDeleteFromHealthKit.description);
                    
                    //set off animation
                    healthKitHasChanges = YES;
                }
                else {
                    NSLog(@"An error occured deleting the food %@. In your app, try to handle this gracefully. The error was: %@.", mealToDeleteFromHealthKit.description, error);
                    abort();
                }
            });
        }];
    }
    else
    {
        NSLog(@"food item was not found in hk store or hkobjects not loaded into array");
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Manual HealthKit Modifications Needed"
                                                               message:@"Please open the HealthKit app, navigate to the dietary calories section, open all data and update your calories to accurately reflect actual consumption"
                                                        preferredStyle:UIAlertControllerStyleAlert];

        UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault
                                                              handler:^(UIAlertAction * action) {}];
        [alert addAction:defaultAction];
        [self presentViewController:alert animated:YES completion:nil];
    }
}

-(HKQuantitySample *) findObjectInTodaysHKObjectsToDelete {
    HKQuantitySample *mealToDelete;
    for (HKQuantitySample *sample in self.foodItemsHKQuantitySamples) {
        NSString *time = [eventTimeFormatter stringFromDate:sample.endDate];           //TODO: MAKE THIS FIND QUANTITY SAMPLES IF MULTIPLE MODIFICATIONS ARE MADE TO THE SAME SAMPLE.
        if ([time isEqualToString:[self.eventToEdit eventTime]]) {
            mealToDelete = sample;
        }
    }
    return mealToDelete;
}

#pragma mark - refresh control

-(void) setUpRefreshControl {
    refreshControl = [[UIRefreshControl alloc]init];
    [self.tableViewAllEvents addSubview:refreshControl];
    [refreshControl addTarget:self action:@selector(refreshTable) forControlEvents:UIControlEventValueChanged];
}

- (void)refreshTable {
    filteredEventsArray = [NSMutableArray arrayWithArray:sortedEvents];
    [self.tableViewAllEvents reloadData];
    [refreshControl endRefreshing];
}

#pragma mark - description sorting

-(BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    BOOL containsString = NO;
    [keysThatMatchSearch removeAllObjects];
    
    //get keys that match the search
    for (NSString *key in filterKeys) {
        containsString = [key containsString:self.textFieldDescription.text];
        if (containsString) {
            [keysThatMatchSearch addObject:key];
        }
    }
    return YES;
}

-(BOOL)textFieldShouldReturn:(UITextField *)textField {
    [filteredEventsArray removeAllObjects];
    
    for (NSString *key in keysThatMatchSearch) {
        [filteredEventsArray addObject:[filteredEventsDictionary objectForKey:key]];
    }
    
    //fill it back up if it's empty
    if ([filteredEventsArray count] == 0) {
        filteredEventsArray = [NSMutableArray arrayWithArray:sortedEvents];
    }
    
    //reload tableview with filter results
    [self.tableViewAllEvents reloadData];
    
    [self.view endEditing:YES];
    return YES;
}

#pragma mark - helpers

-(NSString *) getEventType {
    NSString *eventType;
    if (self.segmentedControlEventType.selectedSegmentIndex == 0 ) {
        eventType = @"Meal";
    }
    else
    {
        eventType = @"Activity";
    }
    return eventType;
}

@end
