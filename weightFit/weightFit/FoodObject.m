//
//  FoodObject.m
//  weighFit
//
//  Created by Stephen Printup on 1/25/16.
//  Copyright © 2016 Stephen Printup. All rights reserved.
//

#import "FoodObject.h"

//@interface FoodObject ()
//
//@property (nonatomic, readwrite) double calories;
//@property (nonatomic, readwrite, copy) NSString *name;
//
//@end

@implementation FoodObject

- (instancetype)initWithCalories:(double)calories andDescription:(NSString *)description andTime:(NSDate *)time
{
    FoodObject *foodItem = [[FoodObject alloc] init];

//    foodItem.eventCalories = self.calories;
//    foodItem.eventDescription = self.description;
    
    foodItem.calories = calories;
    foodItem.name = description;
    foodItem.time = time;

    
    return foodItem;
}

+ (instancetype)foodItemWithName:(NSString *)name calories:(double)calories andTime:(NSDate *)time {
    FoodObject *foodItem = [[self alloc] init];
    
    foodItem.name = name;
    foodItem.calories = calories;
    foodItem.time = time;
    
    return foodItem;
}

//+ (instancetype)fooDItemWithTime:(NSString *)time
//{
//    FoodObject *foodItem = [[self alloc] init];
//    
//    foodItem.time = time;
//}

- (NSString *)description {
    return [@{
              @"name": self.name,
              @"calories": @(self.calories),
              @"time": self.time
              } description];
}

@end
