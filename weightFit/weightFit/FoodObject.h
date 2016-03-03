//
//  FoodObject.h
//  weighFit
//
//  Created by Stephen Printup on 1/25/16.
//  Copyright © 2016 Stephen Printup. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FoodObject : NSObject

//@property (strong ,nonatomic) NSString *eventDescription;
//@property (nonatomic, readwrite) double eventCalories;

@property (nonatomic, readwrite, copy) NSString *name;
@property (nonatomic, readwrite) double calories;
@property (nonatomic, readwrite) NSDate *time;


- (instancetype)initWithCalories:(double)calories andDescription:(NSString *)description andTime:(NSDate *)time;
+ (instancetype)foodItemWithName:(NSString *)name calories:(double)calories andTime:(NSDate *)time;
//+ (instancetype)fooDItemWithTime:(NSString *)time;


@end
