//
//  EventListTableViewCell.h
//  weightFit
//
//  Created by Stephen R Printup on 1/7/16.
//  Copyright © 2016 Stephen Printup. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "PersistedDay+CoreDataProperties.h"

@interface EventListTableViewCell : UITableViewCell

@property (weak, nonatomic) IBOutlet UILabel *labelDescription;
@property (weak, nonatomic) IBOutlet UILabel *labelTime;
@property (weak, nonatomic) IBOutlet UILabel *labelCalories;
@property (weak, nonatomic) IBOutlet UILabel *labelType;

@end
