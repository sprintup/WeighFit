//
//  FoodDiaryTableViewCell.h
//  weightFit
//
//  Created by Stephen Printup on 12/25/15.
//  Copyright © 2015 Stephen Printup. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface FoodDiaryTableViewCell : UITableViewCell

@property (weak, nonatomic) IBOutlet UILabel *labelDateCell;
@property (weak, nonatomic) IBOutlet UILabel *labelCalorieTargetCell;
@property (weak, nonatomic) IBOutlet UILabel *labelCaloriesConsumed;
@property (weak, nonatomic) IBOutlet UILabel *labelCalorieBalanceToday;
@property (weak, nonatomic) IBOutlet UILabel *labelUserBalance;
@property (weak, nonatomic) IBOutlet UILabel *labelVPCalorieBalance;

@end
