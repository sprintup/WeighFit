//
//  EventListTableViewController.m
//  weightFit
//
//  Created by Stephen R Printup on 1/7/16.
//  Copyright © 2016 Stephen Printup. All rights reserved.
//

#import "EventListTableViewController.h"
#import "PersistedEvent+CoreDataProperties.h"
#import "CoreDataStack.h"
#import "EventListTableViewCell.h"
#import "PersistedDay+CoreDataProperties.h"
#import "EventInputViewController.h"
#import "HealthKit.h"
#import "HKHealthStore+HKHealthStore_Extensions.h"
#import "FoodObject.h"
#import <Google/Analytics.h>

@interface EventListTableViewController () <NSFetchedResultsControllerDelegate>
{
    CoreDataStack *coreDataStack;
    NSArray *fetchedObjects;
    PersistedDay *day;
    UIRefreshControl *refreshControl;
    NSArray *sortedEvents;
    PersistedEvent *singleEvent;
    PersistedEvent *selectedEvent;
    
    HealthKit *healthKitInstance;
    
    NSDateFormatter *eventTimeFormatter;
    NSDateFormatter *timeFormatterWithoutSeconds;

    HKQuantitySample *mealToDeleteFromHealthKit;
    
    UIView *healthKitSaveView;
}
@property (nonatomic, strong) NSFetchedResultsController *fetchedResultsController;

@end

@implementation EventListTableViewController

- (void)viewDidLoad{
    [super viewDidLoad];
    self.labelDate.text = self.dayString;
    coreDataStack = [CoreDataStack defaultStack];
    
    [self setUpRefreshControl];
    [self setUpHealthKit];
    
    eventTimeFormatter = [[NSDateFormatter alloc] init];
    [eventTimeFormatter setDateFormat:@"hh:mm:ss a"];
    
    timeFormatterWithoutSeconds = [[NSDateFormatter alloc] init];
    [timeFormatterWithoutSeconds setDateFormat:@"hh:mm a"];
}

-(void)viewWillAppear:(BOOL)animated{
    [self refreshTable];
    
    //fetch HKQuantitySamples
    [self HKMealQuery];

    //google analytics
    id<GAITracker> tracker = [[GAI sharedInstance] defaultTracker];
    [tracker set:kGAIScreenName value:@"eventList"];
    [tracker send:[[GAIDictionaryBuilder createScreenView] build]];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView{
    return self.fetchedResultsController.sections.count;
    
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    if ([sortedEvents count] == 0) {
        UIImage *image = [UIImage imageNamed:@"eventBackground.png"];
        UIImageView *imageView = [[UIImageView alloc] initWithImage:image];
        imageView.contentMode = UIViewContentModeScaleAspectFit;
        // Add image view on top of table view
        [self.tableView addSubview:imageView];
        
        // Set the background view of the table view
        self.tableView.backgroundView = imageView;
        
        //remove cell seperators
        self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    }
    else
    {
        self.tableView.backgroundView = nil;
        
        //add cell seperators
        self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;

    }
    return [sortedEvents count];
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    static NSString *CellIdentifier = @"Cell";
    EventListTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    
    if (!cell)
    {
        NSArray *nib = [[NSBundle mainBundle] loadNibNamed:@"EventListTableViewCell" owner:self options:nil];
        cell = [nib objectAtIndex:0];
    }

    if ([sortedEvents count] > 0) {
        singleEvent = [sortedEvents objectAtIndex:indexPath.row];
        cell.labelCalories.text = [NSString stringWithFormat:@"%d", singleEvent.eventCalories];
        cell.labelDescription.text = singleEvent.eventDescription;
        cell.labelTime.text = [self getProperTimeFormat];
        
        [cell.contentView.layer setBorderColor:[self getColorWithType:singleEvent.eventType].CGColor];
        [cell.contentView.layer setBorderWidth:1.0f];
        
        cell.backgroundColor = [[self getColorWithType:singleEvent.eventType] colorWithAlphaComponent:0.5f];
    }
    return cell;
}

-(NSString *) getProperTimeFormat{
    NSDate *dateWithSeconds = [eventTimeFormatter dateFromString:[singleEvent eventTime]];
    NSString *dateWithoutSeconds = [timeFormatterWithoutSeconds stringFromDate:dateWithSeconds];
    return dateWithoutSeconds;
}

//deleting from tableview
-(UITableViewCellEditingStyle) tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath{
    return UITableViewCellEditingStyleDelete;
}

-(void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        selectedEvent = [sortedEvents objectAtIndex:indexPath.row];
        
        //delete from healthkit
        if ([selectedEvent.eventType isEqualToString:@"Meal"]) {
            [self deleteOldMealFromHealthKit];
        }
        
        //delete from core data
        PersistedEvent *eventToDelete = [sortedEvents objectAtIndex:indexPath.row];
        [[coreDataStack managedObjectContext] deleteObject:eventToDelete];
        [coreDataStack saveContext];
    }
    [self refreshTable];
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    selectedEvent = [sortedEvents objectAtIndex:indexPath.row];
    [self performSegueWithIdentifier:@"editEvent" sender:self];
}

#pragma mark - animations

-(void) controllerWillChangeContent:(NSFetchedResultsController *)controller{
    [self.tableView beginUpdates];
}

-(void) controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type newIndexPath:(NSIndexPath *)newIndexPath {
    switch (type) {
        case NSFetchedResultsChangeInsert:
            [self.tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
            break;
        case NSFetchedResultsChangeDelete:
            [self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
            break;
        case NSFetchedResultsChangeUpdate:
            [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
            break;
    }
}

-(void) controller:(NSFetchedResultsController *)controller didChangeSection:(id<NSFetchedResultsSectionInfo>)sectionInfo atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type{
    switch (type) {
        case NSFetchedResultsChangeInsert:
            [self.tableView insertSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationAutomatic];
            break;
            
        case NSFetchedResultsChangeDelete:
            [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationAutomatic];
            break;
    }
}

-(void) controllerDidChangeContent:(NSFetchedResultsController *)controller{
    [coreDataStack saveContext];
    [self.tableView endUpdates];
}

#pragma mark - core data

-(NSFetchedResultsController *) fetchedResultsController{
    if (_fetchedResultsController != nil) {
        return _fetchedResultsController;
    }
    
    NSFetchRequest *fetchRequest = [self dayFetchRequest];
    
    _fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:coreDataStack.managedObjectContext sectionNameKeyPath:nil cacheName:nil];
    _fetchedResultsController.delegate = nil;
    
    return _fetchedResultsController;
}

-(NSFetchRequest *) dayFetchRequest{
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"PersistedDay" inManagedObjectContext:coreDataStack.managedObjectContext];
    [fetchRequest setEntity:entity];
    
    // Specify criteria for filtering which objects to fetch
    NSString *attributeName  = @"todaysDate";
    NSString *attributeValue = self.dayString;
    NSPredicate *predicate   = [NSPredicate predicateWithFormat:@"%K like %@", attributeName, attributeValue];
    [fetchRequest setPredicate:predicate];
    
    // Specify how the fetched objects should be sorted
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"todaysDate" ascending:YES];
    [fetchRequest setSortDescriptors:[NSArray arrayWithObjects:sortDescriptor, nil]];
    
    NSError *error = nil;
    fetchedObjects = [coreDataStack.managedObjectContext executeFetchRequest:fetchRequest error:&error];
    
    return fetchRequest;
}

-(void) sortEvents {
    day = [fetchedObjects objectAtIndex:0];                                                                                             //TODO: refactor this to leverage shared MOC. No need to refetch days
    NSArray *events = [day.event allObjects];
    
//    NSDateFormatter *timeFormatter = [[NSDateFormatter alloc] init];
//    [timeFormatter setDateFormat:@"hh:mm a"];
    
    sortedEvents = [events sortedArrayUsingComparator:^NSComparisonResult(PersistedEvent *obj1, PersistedEvent *obj2) {
        NSDate *date1 = [eventTimeFormatter dateFromString:obj1.eventTime];
        NSDate *date2 = [eventTimeFormatter dateFromString:obj2.eventTime];
        return [date2 compare:date1];
    }];
}

#pragma mark - buttons

- (IBAction)buttonInsertEvent:(id)sender {
    [self performSegueWithIdentifier:@"insertEvent" sender:self];
}

#pragma mark - segues

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender{
    if ([segue.identifier isEqualToString:@"insertEvent"]) {
        EventInputViewController *newEvent = [segue destinationViewController];
        newEvent.dayString = self.dayString;                                            //TODO: Maybe delete this daystring
        newEvent.eventToEdit = nil;
        newEvent.delegateCustom = self;
    }
    else if ([segue.identifier isEqualToString:@"editEvent"])
    {
        EventInputViewController *eventToEdit = [segue destinationViewController];
        eventToEdit.dayString = self.dayString; 
        eventToEdit.eventToEdit = selectedEvent;                                             //TODO: Needs to set the event input date picker to the day being modified
        eventToEdit.delegateCustom = self;
    }}

#pragma mark - refresh control

-(void) setUpRefreshControl{
    refreshControl = [[UIRefreshControl alloc]init];
    [self.tableViewEventList addSubview:refreshControl];
    [refreshControl addTarget:self action:@selector(refreshTable) forControlEvents:UIControlEventValueChanged];
}

- (void)refreshTable{
    [self.fetchedResultsController performFetch:nil];
    [self sortEvents];
    [self.tableViewEventList reloadData];
    
    if ([self.foodItemsHKQuantitySamples count] >0) {
        NSLog(@"Meals retrieved from healthKit");
    }
    
    [refreshControl endRefreshing];
}

#pragma mark - healthkit
//HealthKit strategy
/*This method makes sure all HK objects are represented by a row in the tableview:
 
 deleting objects
 -if an event is to be modified when didSelectRow is selected, it will be deleted from HK
 -only if modifications occured, user could still hit back button and the Food object will be deleted
 -implement a bool hasModifications in input and delete and add new object there
 -if it has modifications then delete and add new
 -it will only have modifications if save button is pressed
 -in the save button, test if there are updates to the foodObject properties
 -if yes, delete and resave food object
 -events that are deleted from this tableview are deleted from healthkit
 
 saving objects
 -all objects added to core data are added to healthkit
 -all objects that are modified are added to healthkit
 */

-(void) setUpHealthKit {
    healthKitInstance = [HealthKit getInstance];
    self.healthStore = healthKitInstance.healthStore;
    self.foodItemsHKQuantitySamples = [[NSMutableArray alloc] init];
    [self setHealthKitAnimationView];
}

-(void) HKMealQuery {
    NSCalendar *calendar = [NSCalendar currentCalendar];
    
    NSDate *now = [eventTimeFormatter dateFromString:self.dayString];
    
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
            
            for (HKQuantitySample *sample in results) {
                [self.foodItemsHKQuantitySamples addObject:sample];
            }
        });
    }];
    
    [self.healthStore executeQuery:query];
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
                    [self startHealthKitSavedAnimation];
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
        NSString *time = [eventTimeFormatter stringFromDate:sample.endDate];
        if ([time isEqualToString:[selectedEvent eventTime]]) {
            mealToDelete = sample;
        }
    }
    return mealToDelete;
}

//save animation
-(void) savedToHealthKit {
    [self startHealthKitSavedAnimation];
}

-(void) setHealthKitAnimationView {
    //HealthKit animation
    CGRect rectFrame = CGRectMake(0.0, self.view.frame.size.height, self.view.frame.size.width, 75.0);
    healthKitSaveView = [[UIView alloc] initWithFrame:rectFrame];
    healthKitSaveView.backgroundColor = [UIColor colorWithRed:237.0/255.0 green:112.0/255.0 blue:106.0/255.0 alpha:1]; //red
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0.0, 0.0, 300.0, 20.0)];
    label.text = @"Health App Updated";
    label.textColor = [UIColor whiteColor];
    label.textAlignment = NSTextAlignmentCenter;
    [label setCenter:CGPointMake(healthKitSaveView.frame.size.width / 2, healthKitSaveView.frame.size.height / 2.5)];
    [healthKitSaveView addSubview:label];
    [self.navigationController.view addSubview:healthKitSaveView];
}

-(void) startHealthKitSavedAnimation {
    //start animation on main thread
    dispatch_async(dispatch_get_main_queue(), ^{
        //animation
        [UIView animateWithDuration:1.0f animations:^{
            healthKitSaveView.frame = CGRectMake(0.0, healthKitSaveView.frame.origin.y - 75,healthKitSaveView.frame.size.width,healthKitSaveView.frame.size.height);
        } completion:^(BOOL finished) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [UIView animateWithDuration:1.0f animations:^{
                    healthKitSaveView.frame = CGRectMake(0.0, healthKitSaveView.frame.origin.y + 75,healthKitSaveView.frame.size.width,healthKitSaveView.frame.size.height);
                }];
            });
        }];
    });
}

#pragma mark - helpers

-(UIColor *) getColorWithType:(NSString *)type{
    UIColor *uIColorToReturn = [[UIColor alloc] init];
    if ([type isEqualToString:@"Meal"]) {
        uIColorToReturn = [UIColor colorWithRed:252.0/255.0 green:194.0/255.0 blue:0 alpha:1.0]; //gold
    }
    else if ([type isEqualToString:@"Activity"])
    {
        uIColorToReturn = [UIColor colorWithRed:0.0 green:102/255.0 blue:255/255.0 alpha:1.0]; //blue
    }
    else
    {
        uIColorToReturn = [UIColor whiteColor];
    }
    return uIColorToReturn;
}

@end