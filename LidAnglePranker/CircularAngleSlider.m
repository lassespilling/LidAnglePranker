//
//  CircularAngleSlider.m
//  LidAnglePranker
//
//  Created by Claude on 2025-10-22.
//

#import "CircularAngleSlider.h"

@interface CircularAngleSlider ()
@property (nonatomic, assign) BOOL isDragging;
@property (nonatomic, assign) NSPoint lastMouseLocation;
@end

@implementation CircularAngleSlider

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        _angle = 45.0; // Default to 45 degrees (half open)
        _playThreshold = 30.0;
        _isDragging = NO;
    }
    return self;
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];

    NSRect bounds = self.bounds;
    NSPoint center = NSMakePoint(NSMidX(bounds), NSMidY(bounds));
    CGFloat radius = MIN(bounds.size.width, bounds.size.height) / 2.0 - 10.0;

    // Clear background
    [[NSColor controlBackgroundColor] setFill];
    NSRectFill(bounds);

    // Draw quarter circle arc (background) - from 0° (right) to 90° (top)
    [[NSColor tertiaryLabelColor] setStroke];
    NSBezierPath *outerArc = [NSBezierPath bezierPath];
    [outerArc appendBezierPathWithArcWithCenter:center
                                         radius:radius
                                     startAngle:0  // 0° at right
                                       endAngle:90]; // 90° at top
    [outerArc setLineWidth:2.0];
    [outerArc stroke];

    // Draw threshold zones
    [self drawThresholdZones:center radius:radius];

    // Draw current lid angle
    [self drawLidAngle:center radius:radius];

    // Draw threshold markers
    [self drawThresholdMarkers:center radius:radius];

    // Draw angle labels
    [self drawAngleLabels:center radius:radius];
}

- (void)drawThresholdZones:(NSPoint)center radius:(CGFloat)radius {
    // Convert angles to radians for drawing
    // 0° is at right (0 rad), 90° is at top (π/2 rad) - quarter circle

    // Draw play zone (from 0° to play threshold)
    [[[NSColor systemRedColor] colorWithAlphaComponent:0.2] setFill];
    NSBezierPath *playZone = [NSBezierPath bezierPath];
    [playZone moveToPoint:center];
    [playZone appendBezierPathWithArcWithCenter:center
                                         radius:radius - 5
                                     startAngle:0  // 0° at right
                                       endAngle:self.playThreshold]; // to play threshold
    [playZone closePath];
    [playZone fill];
}

- (void)drawLidAngle:(NSPoint)center radius:(CGFloat)radius {
    // Convert angle to radians (0° at right, 90° at top)
    CGFloat angleRad = self.angle * M_PI / 180.0;

    // Calculate end point
    NSPoint endPoint = NSMakePoint(
        center.x + cos(angleRad) * (radius - 15),
        center.y + sin(angleRad) * (radius - 15)
    );

    // Draw current angle line
    [[NSColor labelColor] setStroke];
    NSBezierPath *angleLine = [NSBezierPath bezierPath];
    [angleLine moveToPoint:center];
    [angleLine lineToPoint:endPoint];
    [angleLine setLineWidth:3.0];
    [angleLine stroke];

    // Draw current angle dot
    [[NSColor systemBlueColor] setFill];
    NSBezierPath *dot = [NSBezierPath bezierPathWithOvalInRect:
        NSMakeRect(endPoint.x - 4, endPoint.y - 4, 8, 8)];
    [dot fill];
}

- (void)drawThresholdMarkers:(NSPoint)center radius:(CGFloat)radius {
    // Draw play threshold marker only
    CGFloat playAngleRad = self.playThreshold * M_PI / 180.0;
    NSPoint playPoint = NSMakePoint(
        center.x + cos(playAngleRad) * radius,
        center.y + sin(playAngleRad) * radius
    );

    [[NSColor systemRedColor] setFill];
    NSBezierPath *playMarker = [NSBezierPath bezierPathWithOvalInRect:
        NSMakeRect(playPoint.x - 3, playPoint.y - 3, 6, 6)];
    [playMarker fill];

    // Add "will play here" text next to the red dot
    NSString *playText = @"will play here";
    NSDictionary *playTextAttributes = @{
        NSFontAttributeName: [NSFont systemFontOfSize:10],
        NSForegroundColorAttributeName: [NSColor systemRedColor]
    };
    NSSize playTextSize = [playText sizeWithAttributes:playTextAttributes];

    // Position text slightly outside the red dot
    NSPoint textOffset = NSMakePoint(
        cos(playAngleRad) * 15, // Move text 15 points away from center
        sin(playAngleRad) * 15
    );
    NSPoint textPoint = NSMakePoint(
        playPoint.x + textOffset.x - playTextSize.width / 2,
        playPoint.y + textOffset.y - playTextSize.height / 2
    );

    [playText drawAtPoint:textPoint withAttributes:playTextAttributes];
}

- (void)drawAngleLabels:(NSPoint)center radius:(CGFloat)radius {
    NSDictionary *textAttributes = @{
        NSFontAttributeName: [NSFont systemFontOfSize:10],
        NSForegroundColorAttributeName: [NSColor secondaryLabelColor]
    };

    // Draw degree markers only (no text labels)
    // 0° position (right)
    NSString *zeroLabel = @"0°";
    NSSize zeroSize = [zeroLabel sizeWithAttributes:textAttributes];
    NSPoint zeroPoint = NSMakePoint(center.x + radius + 5, center.y - zeroSize.height / 2);
    [zeroLabel drawAtPoint:zeroPoint withAttributes:textAttributes];

    // 90° position (top)
    NSString *ninetyLabel = @"90°";
    NSSize ninetySize = [ninetyLabel sizeWithAttributes:textAttributes];
    NSPoint ninetyPoint = NSMakePoint(center.x - ninetySize.width / 2, center.y + radius + 5);
    [ninetyLabel drawAtPoint:ninetyPoint withAttributes:textAttributes];

    // Draw current angle value (offset left to avoid line overlap)
    NSString *currentLabel = [NSString stringWithFormat:@"%.0f°", self.angle];
    NSDictionary *currentAttributes = @{
        NSFontAttributeName: [NSFont boldSystemFontOfSize:14],
        NSForegroundColorAttributeName: [NSColor labelColor]
    };
    NSSize currentSize = [currentLabel sizeWithAttributes:currentAttributes];
    NSPoint currentPoint = NSMakePoint(center.x - currentSize.width - 10, center.y - currentSize.height / 2);
    [currentLabel drawAtPoint:currentPoint withAttributes:currentAttributes];
}

- (void)setPlayThreshold:(double)playThreshold {
    _playThreshold = playThreshold;
    [self setNeedsDisplay:YES];
}

- (void)setAngle:(double)angle {
    _angle = fmax(0.0, fmin(90.0, angle));
    [self setNeedsDisplay:YES];
}

// Mouse handling for interactive threshold adjustment
- (void)mouseDown:(NSEvent *)event {
    NSPoint locationInView = [self convertPoint:[event locationInWindow] fromView:nil];
    NSPoint center = NSMakePoint(NSMidX(self.bounds), NSMidY(self.bounds));
    CGFloat radius = MIN(self.bounds.size.width, self.bounds.size.height) / 2.0 - 10.0;

    // Check if click is near the threshold markers
    CGFloat distance = sqrt(pow(locationInView.x - center.x, 2) + pow(locationInView.y - center.y, 2));

    if (distance >= radius - 10 && distance <= radius + 10) {
        self.isDragging = YES;
        self.lastMouseLocation = locationInView;
        [self updateThresholdFromMouseLocation:locationInView];
    }
}

- (void)mouseDragged:(NSEvent *)event {
    if (self.isDragging) {
        NSPoint locationInView = [self convertPoint:[event locationInWindow] fromView:nil];
        [self updateThresholdFromMouseLocation:locationInView];
        self.lastMouseLocation = locationInView;
    }
}

- (void)mouseUp:(NSEvent *)event {
    self.isDragging = NO;
}

- (void)updateThresholdFromMouseLocation:(NSPoint)location {
    NSPoint center = NSMakePoint(NSMidX(self.bounds), NSMidY(self.bounds));

    // Calculate angle from mouse position
    CGFloat deltaX = location.x - center.x;
    CGFloat deltaY = location.y - center.y;
    CGFloat angleRad = atan2(deltaY, deltaX);

    // Convert to degrees and adjust for our quarter circle (0° at right, 90° at top)
    CGFloat angleDegrees = angleRad * 180.0 / M_PI;

    // Handle negative angles and convert to 0-90 range
    if (angleDegrees < 0) {
        angleDegrees += 360; // Convert negative to positive
    }

    // Only allow quarter circle from 0° (right) to 90° (top)
    if (angleDegrees > 180) {
        return; // Ignore clicks in lower half
    }

    // Clamp to 0-90 range
    angleDegrees = fmax(0.0, fmin(90.0, angleDegrees));

    // Update play threshold only
    self.playThreshold = angleDegrees;

    [self setNeedsDisplay:YES];

    // Send action to target (notify AppDelegate that threshold changed)
    if (self.target && self.action) {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self.target performSelector:self.action withObject:self];
        #pragma clang diagnostic pop
    }
}

@end