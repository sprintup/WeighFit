//
//  DayListTableViewController.m
//  weightFit
//
//  Created by Stephen R Printup on 1/6/16.
//  Copyright © 2016 Stephen Printup. All rights reserved.
//

#import "DayListTableViewController.h"
#import "CoreDataStack.h"
#import "PersistedDay+CoreDataProperties.h"
#import "DayValuesTableViewCell.h"
#import "EventListTableViewController.h"
#import "WeighFitModel.h"
#import "PersistedEvent+CoreDataProperties.h"
#import "NotificationsTableViewController.h"
#import "DaySetUpTableViewController.h"
#import "HealthKit.h"
#import "HKHealthStore+HKHealthStore_Extensions.h"
#import <Google/Analytics.h>


@interface DayListTableViewController () <NSFetchedResultsControllerDelegate, SwipeableCellDelegate>
{
    NSString *daySelected;
    UIRefreshControl *refreshControl;
    CoreDataStack *coreDataStack;
    WeighFitModel *instance;
    PersistedDay *persistedDay;
    PersistedDay *dayToPass;
    NSString *dateNow;
    NSDateFormatter *dateFormatter;
    NSDateFormatter *timeFormatter;
    
    HealthKit *healthKitInstance;
    UIView *healthKitSaveView;
    
    float minutesUntilBedTime;
    float minutesUntilNotification;
    float minutesUntilNotionalNotification;
    
    UIImageView *slideViewTutorial;
    NSMutableArray *arrayOfToday;
}

@property (nonatomic, strong) NSFetchedResultsController *fetchedResultsController;

@property (nonatomic) float caloriesPerMinute;
@property (nonatomic) int caloriesConsumed;
@property (nonatomic) int dayBalance;
@property (nonatomic) int vpPace;
@property (nonatomic) int userBalance;
@property (nonatomic, strong) NSMutableSet *cellsCurrentlyEditing;

@end

@implementation DayListTableViewController

- (void)viewDidLoad{
    [super viewDidLoad];
    coreDataStack = [CoreDataStack defaultStack];
    instance = [WeighFitModel getInstance];
    timeFormatter = [[NSDateFormatter alloc] init];
    
    dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"MM-dd-yyyy"];
    dateNow = [dateFormatter stringFromDate:[NSDate date]];
    
    //set refresh control
    refreshControl = [[UIRefreshControl alloc]init];
    [self.tableView addSubview:refreshControl];
    [refreshControl addTarget:self action:@selector(refreshTable) forControlEvents:UIControlEventValueChanged];
    
    //set up healthkit
    [self setUpHealthKit];
    
    //swipable cells
    self.cellsCurrentlyEditing = [NSMutableSet new];

    //delete objects more than 30 days old
    if ([self.fetchedResultsController.fetchedObjects count] > 7) {
        [self deleteOldDaysAlert];
    }
    
    //check if today's day exists
    self.todayString = [dateFormatter stringFromDate:[NSDate date]];
    arrayOfToday = [[NSMutableArray alloc] init];
}

-(void)viewWillAppear:(BOOL)animated{
    //refresh table
    [self.tableView reloadData];
    
    //healthKit
    if ([healthKitInstance authorization] == YES) {
        [self HKMealQuery]; //loads array with meals to delete
    } else {
        NSLog(@"no HK authorization");
    }
    
    //google analytics
    [self googleAnalytics];
    
    //introduce new day
    [self newDayTest];
    
    //tutorial
    [self startTutorial];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView{
    return self.fetchedResultsController.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    if ([self.fetchedResultsController.fetchedObjects count] == 0) {
        UIImage *image = [UIImage imageNamed:@"dayListBackground.png"];
        UIImageView *imageView = [[UIImageView alloc] initWithImage:image];
        imageView.contentMode = UIViewContentModeScaleAspectFit;
        // Add image view on top of table view
        [self.tableView addSubview:imageView];
        
        //remove cell seperators
        self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
        
        // Set the background view of the table view
        self.tableView.backgroundView = imageView;
    }
    else
    {
        //remove image
        self.tableView.backgroundView = nil;
        
        //add cell seperators
        self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;

    }
    id <NSFetchedResultsSectionInfo> sectionInfo = [self.fetchedResultsController sections][section];
    return [sectionInfo numberOfObjects];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
     
     static NSString *CellIdentifier = @"Cell";
     DayValuesTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    
    if (!cell)
    {
        NSArray *nib = [[NSBundle mainBundle] loadNibNamed:@"DayValuesTableViewCell" owner:self options:nil];
        cell = [nib objectAtIndex:0];
    }

    if ([self.fetchedResultsController.fetchedObjects count] > 0)
    {
        persistedDay = [self.fetchedResultsController objectAtIndexPath:indexPath];
    }

    /*
     All cell values
     */
    
    cell.day = persistedDay;
    cell.labelDate.text = persistedDay.todaysDate;
    cell.labelBurned.text = [self getCaloriesBurnedWithDay:persistedDay];
    cell.labelConsumed.text = [self getCaloriesConsumedWithDay:persistedDay];
    cell.labelDayBalance.text = [self calculateDayBalanceWithDay:persistedDay];
    [self calculateVPCalorieBalanceNowWithDay:persistedDay];
    cell.labelNowBalance.text = [self getUserBalanceWithDay:persistedDay];
    
    /*
     Day specific modifications
     */
    
    //hoisted variables for difference between past days and today
    UIColor *backGroundColor = [UIColor whiteColor];
    BOOL pastDayTest = NO;
    UIColor *balanceColor = [self getBackgroundColorWithDay:persistedDay];
    NSString *labelBalNowValue = @"Balance Now";
    
    if ([persistedDay.todaysDate isEqualToString:dateNow])
    {
        /*
         set up cell for today
         */
        
        //schedule notification
        [self scheduleNotificationWithDay:persistedDay];
        
    }else
    {
        /*
         set up cell for yesterday
         */
        
        //change background color if past day
        backGroundColor = [self getBackgroundColorWithDay:persistedDay];
        
        //hide now balance label
        pastDayTest = YES;
        
        //set past day user balance color
        balanceColor = [self getPastDayUserBalanceColor];
        
        //set userBal label
        labelBalNowValue = @"Calories Left";
    }
    
    cell.myContentView.backgroundColor = backGroundColor;
    cell.labelBalNowDisplay.text = labelBalNowValue;
    cell.labelBalDayDisplay.hidden = pastDayTest;
    cell.labelDayBalance.hidden = pastDayTest;
    cell.labelNowBalance.textColor = balanceColor;

     /*
     swipeable cells
     */
    cell.delegate = self;
    if ([self.cellsCurrentlyEditing containsObject:indexPath]) {
        [cell openCell];
    }
    
     return cell;
 }

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 110.0;
}

-(UITableViewCellEditingStyle) tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath{
    return UITableViewCellEditingStyleDelete;
}

-(void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath{
    PersistedDay *dayToDelete = [self.fetchedResultsController objectAtIndexPath:indexPath];
    [[coreDataStack managedObjectContext] deleteObject:dayToDelete];
    
    [coreDataStack saveContext];
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    persistedDay = [self.fetchedResultsController objectAtIndexPath:indexPath];
    daySelected = persistedDay.todaysDate;                                                                                                              //TODO: Maybe delete this string 
    [self performSegueWithIdentifier:@"eventList" sender:self];
}


#pragma mark - NSFetchedResultsControllerDelegate

-(void) controllerWillChangeContent:(NSFetchedResultsController *)controller{
    [self.tableView beginUpdates];
}

-(void) controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type newIndexPath:(NSIndexPath *)newIndexPath{
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

-(void) controller:(NSFetchedResultsController *)controller didChangeSection:(id<NSFetchedResultsSectionInfo>)sectionInfo atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type {
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
    [self.tableView endUpdates];
//    [coreDataStack saveContext];  TODO: Maybe delete this because no changes to the objects are made here
}

#pragma mark - core data

-(NSFetchedResultsController *) fetchedResultsController{
    if (_fetchedResultsController != nil) {
        return _fetchedResultsController;
    }
    
    NSFetchRequest *dayFetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"PersistedDay"];
    dayFetchRequest.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"todaysDate" ascending:NO]];

    _fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:dayFetchRequest managedObjectContext:coreDataStack.managedObjectContext sectionNameKeyPath:nil cacheName:nil];
    _fetchedResultsController.delegate = self;
    
    [_fetchedResultsController performFetch:nil];
    
    return _fetchedResultsController;
}

-(void) deleteOldDaysAlert {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Stay Fast"
                                                                   message:@"Keep WeighFit running fast by deleting days older than your most recent 7. You can keep data for these deleted days in Health App for future review, but will not be able to edit them. You can always delete data directly in the Health App"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:@"Keep all days" style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction * action) {}];
    UIAlertAction *keepThirtyAction = [UIAlertAction actionWithTitle:@"Keep recent 7" style:UIAlertActionStyleDefault
                                                             handler:^(UIAlertAction * action) {
                                                                 for (int count = 0; count < [self.fetchedResultsController.fetchedObjects count]; count++) {
                                                                     if (count > 6) {
                                                                         NSLog(@"inside if statement with: %@",[self.fetchedResultsController.fetchedObjects objectAtIndex:count]);
                                                                         [[coreDataStack managedObjectContext] deleteObject:[self.fetchedResultsController.fetchedObjects objectAtIndex:count]];
                                                                     }
                                                                 }
                                                                 [coreDataStack saveContext];
                                                             }];
    
    
    [alert addAction:defaultAction];
    [alert addAction:keepThirtyAction];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - segues

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender{
    if ([segue.identifier isEqualToString:@"eventList"]) {
        EventListTableViewController *eventList = [segue destinationViewController];
        eventList.dayString = daySelected;
    }
    else if ([segue.identifier isEqualToString:@"editDay"])
    {
        DaySetUpTableViewController *daySetupTVC = segue.destinationViewController;
        daySetupTVC.day = dayToPass;
        daySetupTVC.delegateCustom = self;
    }
    else if ([segue.identifier isEqualToString:@"addDay"])
    {
        DaySetUpTableViewController *daySetupTVC = segue.destinationViewController;
        daySetupTVC.day = nil;
        daySetupTVC.delegateCustom = self;
    }
}

#pragma mark - refresh control

- (void)refreshTable{
    dateNow = [dateFormatter stringFromDate:[NSDate date]];
    [self.fetchedResultsController performFetch:nil];
    [self.tableView reloadData];
    [refreshControl endRefreshing];
}

#pragma mark - buttons

- (IBAction)addDayButton:(id)sender {
    [self performSegueWithIdentifier:@"addDay" sender:self];
}

- (void)buttonOneDeleteDay:(PersistedDay *)dayToDelete andDayString:(NSString *)dayString{
    // SwipeableCellDelegate
    
    //delete from Core Data
    [[coreDataStack managedObjectContext] deleteObject:dayToDelete];
    [coreDataStack saveContext];
    
    //delete from healthkit
    self.dayString = dayString;
    [self deleteMealsInHKForDay];
    
    [self.tableView reloadData];
}

- (void)buttonTwoEditDay:(PersistedDay *)dayToEdit{
    NSLog(@"In the delegate, Clicked button two to edit");
    // SwipeableCellDelegate
    dayToPass = dayToEdit;
    [self performSegueWithIdentifier:@"editDay" sender:self];
}

#pragma mark - local notifications

-(void) scheduleNotificationWithDay:(PersistedDay *)day{
    [[UIApplication sharedApplication] cancelAllLocalNotifications];
    
    // When notification should be scheduled
    float minutesUntilReachedThreshold = [instance.notificationLimit floatValue] - self.userBalance;
    minutesUntilNotification = minutesUntilReachedThreshold / self.caloriesPerMinute;
    NSNumber *secondsUntilNotification = [NSNumber numberWithFloat:minutesUntilNotification * 60.0];
    NSDate *dateTimeOfNotification = [NSDate dateWithTimeIntervalSinceNow: [secondsUntilNotification doubleValue]];
    
    [[UIApplication sharedApplication] scheduleLocalNotification:[self getLocalNotificationToScheduleWithDate:dateTimeOfNotification]];
    
    minutesUntilBedTime = [self calculateMinutesUntilBedTimeWithDay:day];
    
    //if userBalance is in the negative
    if (self.userBalance < 0) {
        [[UIApplication sharedApplication] cancelAllLocalNotifications];
        //add the difference between zero and user balance to minutes until notification
        int difference = (-(self.userBalance));
        
        // When new notification should be scheduled
        float minutesUntilReachedThreshold = [instance.notificationLimit floatValue] + difference;
        minutesUntilNotification = minutesUntilReachedThreshold / self.caloriesPerMinute;
        
        NSNumber *secondsUntilNotification = [NSNumber numberWithFloat:minutesUntilNotification * 60.0];
        NSDate *dateTimeOfNotification = [NSDate dateWithTimeIntervalSinceNow: [secondsUntilNotification doubleValue]];

        [[UIApplication sharedApplication] scheduleLocalNotification:[self getLocalNotificationToScheduleWithDate:dateTimeOfNotification]];
    }
    
     //if notification is beyond bedtime
    if (minutesUntilNotification > minutesUntilBedTime) {
        //don't schedule notification, not enough time
        [[UIApplication sharedApplication] cancelAllLocalNotifications];
    }
    
    //time past bed time notification would go off if it were scheduled with time it took to consume remaining calories
    minutesUntilNotionalNotification = self.caloriesPerMinute * self.dayBalance;

    //set label
    [self setUserNotificationLabel];
}

-(UILocalNotification *) getLocalNotificationToScheduleWithDate:(NSDate *)date {
    UILocalNotification* localNotification = [[UILocalNotification alloc] init];
    localNotification.alertTitle = @"It's time to eat";
    localNotification.alertBody = [self getRandomAdvice];
    localNotification.alertAction = @"OK";
    localNotification.fireDate = date;
    localNotification.soundName = UILocalNotificationDefaultSoundName;
    localNotification.timeZone = [NSTimeZone defaultTimeZone];
    return localNotification;
}

-(NSString *) getRandomAdvice {
    NSArray *adviceArray = [[NSArray alloc] initWithObjects:@"Remember to eat around 20-25 grams of protein every 3-4 hours", @"Be mindful of calorie packed condiments or dressings", @"Hummus and yogurt are convenient sources of protein", @"Smile, it's time to eat", @"Eat protein with every meal or snack", @"Fruits and vegetable are separate food groups, make sure to eat them both", @"Calories in the form of fluid count", @"Pastries have a lot of calories", @"Vegetables, especially roughage, are low in calories and will fill you up", @"YOU'VE GOT THIS!", @"Snacking on your baseline will prevent hunger and overeating", @"Greek Yogurt has great probiotics to help with digestion", @"Everyone has off days, as long as it's not everyday it's ok", @"Eating out might mean higher calories, maybe split entrees", @"Eating some protein at breakfast is important", @"We metabolize alcohol directly to fat", @"Spread nutrients out throughout the day", @"Cottage cheese, string cheese, or 2-3 oz of meat are great sources of protein", @"Nuts are a great source of protein and calories",  nil];
    int variable = arc4random() % [adviceArray count];
    NSMutableString *timeToEat = [NSMutableString stringWithString:@"It's time to eat: "];
    return [timeToEat stringByAppendingString:adviceArray[variable]];
}

-(void) setUserNotificationLabel {
    // Is there a notification scheduled?
    BOOL notificationTest = [[[UIApplication sharedApplication] scheduledLocalNotifications] count] > 0;
    NSString *stringToSetLabel = [[NSString alloc] init];
    
    //notification is scheduled                                                                                                  // TODO: Maybe delete day.calorieBalance
    if (notificationTest) {
        NSDate *dateOfNextNotification = [[UIApplication sharedApplication].scheduledLocalNotifications objectAtIndex:0].fireDate;
        [timeFormatter setDateFormat:@"hh:mm a"];
        NSString *timeToShow = [timeFormatter stringFromDate:dateOfNextNotification];       //gets date of next notification
        NSArray *sentenceArray = [NSArray arrayWithObjects:@"At ",timeToShow,@" eat ",instance.notificationLimit,@" calories", nil];
        stringToSetLabel = [sentenceArray componentsJoinedByString:@""];
    }
    
    //notification is not scheduled because it would have already gone off
    if (self.userBalance > [instance.notificationLimit intValue]) {
        /*
         This is meant for when notification would be scheduled for the past
         -To test make set notification limit to lower than user balance
         */
        stringToSetLabel = @"It's time to eat";
    }
    
    //notification can't be scheduled because there is not enough time
    if ((self.caloriesConsumed < self.totalCalorieTarget) && (minutesUntilNotification > minutesUntilBedTime)) {

        /*
         This is meant for the end of the day, when the notification would be scheduled after bed time and there are still calories to eat. 
         -This means there are more calories to eat then there is time to eat them. 
         -Time to eat them means that caloriesPerMinute X caloriesRemaining schedules a notification after bedTime.
         -To test make bedtime sooner than notification can be scheduled
         */
        stringToSetLabel = @"Last chance to eat remaining calories";
    }
    
    //user reached calorie target for day
    if ((self.caloriesConsumed >= self.totalCalorieTarget) && (minutesUntilNotification > minutesUntilBedTime)) {            //TODO SET DAY BALANCE
        /*
         This is meant for the end of they day when user balance has transcended calorie target. 
         -Should be displayed over all else
         -To test make user balance higher than calorie target
         */
        stringToSetLabel = @"You've reached today's calorie target";
    }
    
    //notification is not scheduled because user does not want to be reminded
    if ([instance.notificationLimit isEqualToString:@"don't remind me"]) {
        /*
         displayed if user elects not to be reminded. 
         -Should be displayed at a high level
         -To test set notification to 'don't remind me' and
         */
        stringToSetLabel = @"No reminder scheduled";
    }
    
    //values need to be refreshed
        /*
         This is meant if view loads with outdated values as a reminder to the user to refresh the content before reviewing it.
         */
//    stringToSetLabel = @"Pull to refresh";
    
    self.labelNextMeal.text = stringToSetLabel;}

#pragma mark - helpers

-(NSString *) getCaloriesBurnedWithDay:(PersistedDay *)day{
    NSNumber *basalRate = [instance calculateBasalMetabolicRateWithGender:day.gender weight:[NSNumber numberWithInt:day.weight] height:[NSNumber numberWithInt:day.height] age:[NSNumber numberWithInt:day.age]];
    
    double activityFactor = [instance getActivityFactorWithLevel:day.activityLevel];
    double caloricNeeds = [basalRate doubleValue] * activityFactor;
    NSNumber *caloriesBurned = [self getCalorieCountWithType:@"Activity" andDay:day];
    double totalCaloriesBurned = caloricNeeds + [caloriesBurned doubleValue];
    double roundedTotalCaloriesBurned = round(totalCaloriesBurned);
    NSNumber *totalCaloriesBurnedObject = [NSNumber numberWithDouble:roundedTotalCaloriesBurned];
    
//    day.totalCalorieTarget = [totalCaloriesBurnedObject intValue]; //TODO: change totalCalorieTarget to calories burned in data model
    self.totalCalorieTarget = [totalCaloriesBurnedObject intValue];
    
    return [totalCaloriesBurnedObject stringValue];         //TODO: On override of days activity factor resets to zero
}

-(NSString *) getCaloriesConsumedWithDay:(PersistedDay *)day{
    NSNumber *caloriesConsumed;
    caloriesConsumed = [self getCalorieCountWithType:@"Meal" andDay:day];
    
//    day.caloriesConsumed = [caloriesConsumed intValue];       //TODO: Delete calories consumed from model
    self.caloriesConsumed = [caloriesConsumed intValue];
    
    return [caloriesConsumed stringValue];
}

-(NSNumber *) getCalorieCountWithType:(NSString *)type andDay:(PersistedDay *)day{
    NSMutableArray *arrayOfType = [[NSMutableArray alloc] init];
    int calorieCount = 0;
    NSArray *eventsArray = [day.event allObjects];
    
    for (PersistedEvent *event in eventsArray) {
        if ([event.eventType isEqualToString:type]) {
            [arrayOfType addObject:event];
        }
    }
    for (PersistedEvent *event in arrayOfType) {
        calorieCount += event.eventCalories;
    }
    return [NSNumber numberWithInt:calorieCount];
}

-(NSString *) calculateDayBalanceWithDay:(PersistedDay *)day{
    self.dayBalance = self.totalCalorieTarget - self.caloriesConsumed;
    return [[NSNumber numberWithInt:self.dayBalance] stringValue];
}

-(float) calculateMinuteNow{
    NSDateFormatter *dateFormatterVP = [[NSDateFormatter alloc] init];
    
    [dateFormatterVP setDateFormat:@"HH"];
    NSString *hours = [dateFormatterVP stringFromDate:[NSDate date]];
    
    [dateFormatterVP setDateFormat:@"mm"];
    NSString *minutes = [dateFormatterVP stringFromDate:[NSDate date]];
    
    //what minute is the vp at right now?
    float nowMinutesToday = ([hours intValue] * 60) + [minutes intValue];
    return nowMinutesToday;
}

-(float) calculateMinutesUntilBedTimeWithDay:(PersistedDay *)day{
    NSDateFormatter *bedTimeDateFormatter = [[NSDateFormatter alloc] init];
    [bedTimeDateFormatter setDateFormat:@"h:mm a"];
    
    NSDate *bedTimeDate = [bedTimeDateFormatter dateFromString:day.bedTimeToLoad];
    
    //seperate hours and minutes
    NSDateFormatter *dateFormatterBedTime = [[NSDateFormatter alloc] init];
    
    [dateFormatterBedTime setDateFormat:@"HH"];
    NSString *hours = [dateFormatterBedTime stringFromDate:bedTimeDate];
    [dateFormatterBedTime setDateFormat:@"mm"];
    NSString *minutes = [dateFormatterBedTime stringFromDate:bedTimeDate];
    
    //how many minutes at bedtime?
    float minutesAtBedtime = ([hours intValue] * 60) + [minutes intValue];
    
    //how many minutes until bedtime?
    float minutesUntilBedTimeDay = minutesAtBedtime - [self calculateMinuteNow];

    return minutesUntilBedTimeDay;
}

-(NSString *) calculateVPCalorieBalanceNowWithDay:(PersistedDay *)day{
    float totalCalorieTarget = self.totalCalorieTarget;
    float minutesAwakeToday = day.minutesAwakeToday;
    
    float awakeFor = [self calculateMinuteNow] - day.wakeUpTimeMinutes;
    
    //calculate calories per minute
    self.caloriesPerMinute = totalCalorieTarget / minutesAwakeToday;
    
    //how many calories is the vp at right now?
    float caloriePacer = roundf(awakeFor * self.caloriesPerMinute);
    NSNumber *caloriePacerObject = [NSNumber numberWithFloat:caloriePacer];
    
    //set the day vp pace to make calculations for user balance
    self.vpPace = [caloriePacerObject intValue];
    
    // past day and past time vp values remain at target
    if (![day.todaysDate isEqualToString:dateNow] || [caloriePacerObject intValue] > totalCalorieTarget)
    {
        caloriePacerObject = [NSNumber numberWithFloat:totalCalorieTarget];
        self.vpPace = totalCalorieTarget;
    }
    
    return [caloriePacerObject stringValue];
}

-(NSString *) getUserBalanceWithDay:(PersistedDay *)day{
    self.userBalance = self.vpPace - self.caloriesConsumed;
    return [NSString stringWithFormat:@"%d",self.userBalance];
}

#pragma mark - colors

-(UIColor *) getBackgroundColorWithDay:(PersistedDay *)day{
    UIColor *colorToReturn = [UIColor whiteColor];
    // if it is time to eat, return green
    if (_userBalance > [instance.notificationLimit intValue] && (![instance.notificationLimit isEqualToString:@"don't remind me"])) {
        colorToReturn = [UIColor colorWithRed:117.0/255.0 green:205.0/255.0 blue:57.0/255.0 alpha:1]; //green
    }
    
    // if user is in the zone return gold
    else if (_userBalance > -[instance.notificationLimit intValue]) {
        colorToReturn = [UIColor blackColor];  //black
    }
    
    // if user is a hundred or more over limit return red to indicate stop eating
    if (_userBalance < -100) {
        colorToReturn = [UIColor colorWithRed:237.0/255.0 green:112.0/255.0 blue:106.0/255.0 alpha:1]; //red
    }
    
    // end of day, last chance to eat remaining calories
    if ((self.caloriesConsumed < self.totalCalorieTarget) && (minutesUntilNotionalNotification > minutesUntilBedTime) && (!(self.userBalance <= 0) || (self.userBalance > 0)) && (minutesUntilNotification > minutesUntilBedTime)) {
        colorToReturn = [UIColor colorWithRed:117.0/255.0 green:205.0/255.0 blue:57.0/255.0 alpha:1]; //green
    }
    
    // if 'don't remind me' is set don't change color to green, but allow to change red
    if ([instance.notificationLimit isEqualToString:@"don't remind me"]) {
        colorToReturn = [UIColor blackColor]; //black
    }
    
    // if cell is previous day return gray
    if (![day.todaysDate isEqualToString:dateNow]) {
        colorToReturn = [UIColor grayColor];  //gray
    }
    return colorToReturn;
}

-(UIColor *) getPastDayUserBalanceColor{
    UIColor *colorToReturn;
    
    //if it's greater than total balance return red
    if (self.dayBalance < -100) {
        colorToReturn = [UIColor colorWithRed:237.0/255.0 green:112.0/255.0 blue:106.0/255.0 alpha:0.8]; //red
    }
    
    //if it's within 100 calories of day balance return white
    if ((self.dayBalance <=  100) && (self.dayBalance >= - 100)) {
//        colorToReturn = [UIColor colorWithRed:255.0/255.0 green:255.0/255.0 blue:255.0/255.0 alpha:0.8]; //white
        colorToReturn = [UIColor colorWithRed:252.0/255.0 green:194.0/255.0 blue:0 alpha:1.0]; //gold
    }
    
    //if it's lower than user balance return green
    if (self.dayBalance > 100) {
        colorToReturn = [UIColor colorWithRed:117.0/255.0 green:205.0/255.0 blue:57.0/255.0 alpha:0.8]; //green
    }
    
    return colorToReturn;
}

#pragma mark - swipeable cells

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return NO;
}

- (void)cellDidOpen:(UITableViewCell *)cell {
    NSIndexPath *currentEditingIndexPath = [self.tableView indexPathForCell:cell];
    [self.cellsCurrentlyEditing addObject:currentEditingIndexPath];
}

- (void)cellDidClose:(UITableViewCell *)cell {
    [self.cellsCurrentlyEditing removeObject:[self.tableView indexPathForCell:cell]];
}

#pragma mark - healthkit

-(void) setUpHealthKit {
    healthKitInstance = [HealthKit getInstance];
    [self informUserHealthkitAccess];
    self.healthStore = healthKitInstance.healthStore;
    self.foodItemsHKQuantitySamples = [[NSMutableArray alloc] init];
    self.foodItemsHKQuantitySamplesForDayToDelete = [[NSMutableArray alloc] init];
    [self setHealthKitAnimationView];
}

-(void) HKMealQuery {
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDate *now = [NSDate date];
    if (self.dayString != nil) {
        now = [dateFormatter dateFromString:self.dayString];
    }
    
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

-(void) deleteMealsInHKForDay {
    //load array with HKQuantitySamples to delete
    [self.foodItemsHKQuantitySamplesForDayToDelete removeAllObjects];
    for (HKQuantitySample *sample in self.foodItemsHKQuantitySamples) {
        NSString *sampleDate = [dateFormatter stringFromDate:[sample endDate]];
        if ([sampleDate isEqualToString:self.dayString]) {
            [self.foodItemsHKQuantitySamplesForDayToDelete addObject:sample];
        }
    }
    
    //delete quantity samples
    [self.healthStore deleteObjects:self.foodItemsHKQuantitySamplesForDayToDelete withCompletion:^(BOOL success, NSError * _Nullable error) {
        if (success) {
            NSLog(@"successfully deleted items from healthKit");
            [self startHealthKitSavedAnimation];
        }
        else if (!success) {
            NSLog(@"meals in healthKit NOT deleted");
            
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Manual HealthKit Modifications Needed"
                                                               message:@"Please open the HealthKit app, navigate to the dietary calories section, open all data and update your calories to accurately reflect actual consumption"
                                                        preferredStyle:UIAlertControllerStyleAlert];

            UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault
                                                                  handler:^(UIAlertAction * action) {}];
            [alert addAction:defaultAction];
            
            if ([self.foodItemsHKQuantitySamplesForDayToDelete count] > 0) {
                //there were items fetched but not deleted
                [self presentViewController:alert animated:YES completion:nil];
            } else
            {
                //items not found
                NSLog(@"Attempted to fetch items, but they were not found");
            }
        }
    }];
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

-(void) healthKitUpdated {
    /*
     custom delegate method from daysetup
     */
    NSLog(@"delegate called");
    [self startHealthKitSavedAnimation];
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

-(void) informUserHealthkitAccess {
    /*
     Inform user how to allow access to healthkit
     */
    //tutorial only once
    if (![[[NSUserDefaults standardUserDefaults] objectForKey:@"HKInstructions"] isEqualToString:@"1"]) {
        [[NSUserDefaults standardUserDefaults] setValue:@"1" forKey:@"HKInstructions"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        //inform users
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"HealthKit Access Setup Instructions"
                                                                       message:@"Please select 'All Categories On' in the Health App and then select 'Allow' at the top right of the screen. The Health App is where you can track your weight and dietary calories over time with graphs"
                                                                preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault
                                                              handler:^(UIAlertAction * action) {
                                                              [healthKitInstance requestAuthorizationToUseHealthData];
                                                              }];
        [alert addAction:defaultAction];
        [self presentViewController:alert animated:YES completion:nil];
    }
}

#pragma mark - tutorial

-(void) startTutorial {
    //tutorial only once
    if ((![[[NSUserDefaults standardUserDefaults] objectForKey:@"Tutorial"] isEqualToString:@"1"]) && ([self.fetchedResultsController.fetchedObjects count] > 0)) {
        [[NSUserDefaults standardUserDefaults] setValue:@"1" forKey:@"Tutorial"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        [self startSlideAnimation];
    }
}

-(void) startSlideAnimation {
    UIImage *image2 = [UIImage imageNamed:@"slide.png"];

        slideViewTutorial = [[UIImageView alloc] initWithImage:image2];
        slideViewTutorial.frame = CGRectMake(self.view.frame.size.width - 180, 130.0, 200.0, 70.0);

//    slide image
        [UIView animateWithDuration:5.0f animations:^{
            [self.navigationController.view addSubview:slideViewTutorial];
            slideViewTutorial.frame = CGRectMake(-200, 130.0, 200.0, 70.0);
            slideViewTutorial.alpha = 0.0;
            slideViewTutorial.alpha = 1.0;
        }];
}

#pragma mark - new day

-(void) newDayTest {
    /*
     find out if today exists in fetched days, if not alert user
     */
    [arrayOfToday removeAllObjects];
    for (PersistedDay *day in self.fetchedResultsController.fetchedObjects) {
        if ([[day todaysDate] isEqualToString:self.todayString]) {
            //day was not present, set up alert
            [arrayOfToday addObject:day];
        }
    }
    
    if ([arrayOfToday count] == 0) {
        [self newDayRecommendationAlert];
    }
}

-(void) newDayRecommendationAlert {
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"Today not created"
                                                                   message:@"Would you like to create a new day?"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction * action) {}];
    UIAlertAction* addAction = [UIAlertAction actionWithTitle:@"Create" style:UIAlertActionStyleDefault
                                                      handler:^(UIAlertAction * action) {
                                                          [self performSegueWithIdentifier:@"addDay" sender:self];
                                                      }];
    
    [alert addAction:defaultAction];
    [alert addAction:addAction];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - analytics

-(void) googleAnalytics {
    //google analytics
    id<GAITracker> tracker = [[GAI sharedInstance] defaultTracker];
    [tracker set:kGAIScreenName value:@"dayList"];
    [tracker send:[[GAIDictionaryBuilder createScreenView] build]];
}

@end

























