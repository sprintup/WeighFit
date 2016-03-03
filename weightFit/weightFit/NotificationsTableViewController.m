//
//  NotificationsTableViewController.m
//  weighFit
//
//  Created by Stephen R Printup on 1/18/16.
//  Copyright © 2016 Stephen Printup. All rights reserved.
//

#import "NotificationsTableViewController.h"
#import "WeighFitModel.h"

@interface NotificationsTableViewController ()
{
    WeighFitModel *instance;
}
@end

@implementation NotificationsTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    instance = [WeighFitModel getInstance];
    
    self.boundsArray = [[NSArray alloc] initWithObjects:@"don't remind me", @"50", @"100", @"150", @"200", @"250",@"300", @"400", @"500", nil];
   
    if ([self.boundsArray containsObject:instance.notificationLimit]) {
        [self loadNotificationTime];
    }
}

#pragma mark - picker view

-(NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView
{
    return 1;
}

-(NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component
{
    return self.boundsArray.count;

}

-(NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component
{
    return [self.boundsArray objectAtIndex:row];
}

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component {
    self.indexPathOfSelection = (int)row;
}

#pragma mark - saving and loading

- (IBAction)buttonSave:(id)sender {
    NSString *notificationLimit = [self.boundsArray objectAtIndex:self.indexPathOfSelection];
    [instance updateNotificationLimit:notificationLimit];
    [self.navigationController popViewControllerAnimated:YES];
}

-(void) loadNotificationTime
{
    self.indexPathOfSelection = (int)[self.boundsArray indexOfObject:instance.notificationLimit];
    [self.pickerViewBounds selectRow:self.indexPathOfSelection inComponent:0 animated:YES];
}


@end
