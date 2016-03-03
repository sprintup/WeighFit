//
//  DayValuesTableViewCell.h
//  weightFit
//
//  Created by Stephen R Printup on 1/7/16.
//  Copyright © 2016 Stephen Printup. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "PersistedDay+CoreDataProperties.h"

@protocol SwipeableCellDelegate <NSObject>

- (void)buttonOneDeleteDay:(PersistedDay *)dayToDelete andDayString:(NSString *)dayString;
- (void)buttonTwoEditDay:(PersistedDay *)dayToEdit;
- (void)cellDidOpen:(UITableViewCell *)cell;
- (void)cellDidClose:(UITableViewCell *)cell;

@end

@interface DayValuesTableViewCell : UITableViewCell

@property (weak, nonatomic) IBOutlet UILabel *labelDate;
@property (weak, nonatomic) IBOutlet UILabel *labelBurned;
//@property (weak, nonatomic) IBOutlet UILabel *labelVPPace;
@property (weak, nonatomic) IBOutlet UILabel *labelConsumed;
@property (weak, nonatomic) IBOutlet UILabel *labelNowBalance;
@property (weak, nonatomic) IBOutlet UILabel *labelDayBalance;
@property (nonatomic, weak) IBOutlet UIView *myContentView;
@property (weak, nonatomic) IBOutlet UILabel *labelBalNowDisplay;
@property (weak, nonatomic) IBOutlet UILabel *labelBalDayDisplay;


@property (nonatomic, strong) PersistedDay *day;

@property (nonatomic, weak) id <SwipeableCellDelegate> delegate;

- (void)openCell;

@end
