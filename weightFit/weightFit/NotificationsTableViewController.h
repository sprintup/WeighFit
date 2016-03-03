//
//  NotificationsTableViewController.h
//  weighFit
//
//  Created by Stephen R Printup on 1/18/16.
//  Copyright © 2016 Stephen Printup. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface NotificationsTableViewController : UITableViewController <UIPickerViewDelegate, UIPickerViewDataSource>

@property (strong, nonatomic) NSArray *boundsArray;
@property (weak, nonatomic) IBOutlet UIPickerView *pickerViewBounds;

@property (nonatomic) int indexPathOfSelection;

@end
