//
//  PersistedDay+CoreDataProperties.h
//  TriFitness
//
//  Created by Stephen Printup on 2/8/16.
//  Copyright © 2016 Stephen Printup. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

#import "PersistedDay.h"

NS_ASSUME_NONNULL_BEGIN

@interface PersistedDay (CoreDataProperties)

@property (nonatomic) int32_t activityLevel;
@property (nonatomic) int16_t age;
@property (nullable, nonatomic, retain) NSString *bedTimeToLoad;
@property (nonatomic) int32_t caloriesConsumed;
@property (nonatomic) float caloriesPerMinute;
@property (nullable, nonatomic, retain) NSString *gender;
@property (nonatomic) int32_t height;
@property (nonatomic) int32_t minutesAwakeToday;
@property (nullable, nonatomic, retain) NSString *todaysDate;
@property (nonatomic) int32_t totalCalorieTarget;
@property (nonatomic) int32_t userBalance;
@property (nonatomic) int32_t vpPace;
@property (nonatomic) int32_t wakeUpTimeMinutes;
@property (nullable, nonatomic, retain) NSString *wakeUpTimeToLoad;
@property (nonatomic) int32_t weight;
@property (nullable, nonatomic, retain) NSSet<PersistedEvent *> *event;

@end

@interface PersistedDay (CoreDataGeneratedAccessors)

- (void)addEventObject:(PersistedEvent *)value;
- (void)removeEventObject:(PersistedEvent *)value;
- (void)addEvent:(NSSet<PersistedEvent *> *)values;
- (void)removeEvent:(NSSet<PersistedEvent *> *)values;

@end

NS_ASSUME_NONNULL_END
