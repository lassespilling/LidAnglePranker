//
//  CircularAngleSlider.h
//  LidAnglePranker
//
//  Created by Claude on 2025-10-22.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface CircularAngleSlider : NSView

@property(nonatomic, assign) double angle;         // Current angle in degrees (0-90)
@property(nonatomic, assign) double playThreshold; // Play threshold in degrees
@property(nonatomic, assign) id target;
@property(nonatomic, assign) SEL action;

// Set the play threshold and update display
- (void)setPlayThreshold:(double)playThreshold;

@end

NS_ASSUME_NONNULL_END