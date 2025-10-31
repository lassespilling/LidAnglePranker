//
//  AppDelegate.m
//  LidAnglePranker
//
//  Created by Sam on 2025-09-06.
//

#import "AppDelegate.h"
#import "LidAnglePranker.h"
#import "NSLabel.h"
#import "CircularAngleSlider.h"
#import <AVFoundation/AVFoundation.h>

@interface AppDelegate () <AVAudioPlayerDelegate>
@property (strong, nonatomic) LidAnglePranker *lidSensor;
@property (strong, nonatomic) NSLabel *angleLabel;
@property (strong, nonatomic) NSLabel *statusLabel;
@property (strong, nonatomic) NSTextField *thresholdInput;
@property (strong, nonatomic) NSLabel *thresholdLabel;
@property (strong, nonatomic) NSTimer *updateTimer;
@property (strong, nonatomic) CircularAngleSlider *angleSlider;
@property (strong, nonatomic) NSSegmentedControl *soundTypeSelector;
@property (strong, nonatomic) NSButton *selectSoundButton;
@property (strong, nonatomic) NSLabel *selectedSoundLabel;
@property (strong, nonatomic) NSButton *audioToggleButton;
@property (strong, nonatomic) NSLabel *audioStatusLabel;
@property (strong, nonatomic) NSString *selectedAudioFile;
@property (assign, nonatomic) BOOL isAudioActive;
@property (assign, nonatomic) NSTimeInterval lastAudioTrigger;
@property (assign, nonatomic) double lastAngle;
@property (assign, nonatomic) BOOL audioCurrentlyPlaying;
@property (assign, nonatomic) BOOL updatingThreshold;
@property (assign, nonatomic) BOOL hasTriggeredForCurrentCrossing;
@property (assign, nonatomic) BOOL isLoopEnabled;
@property (strong, nonatomic) NSButton *loopToggleButton;
@property (strong, nonatomic) NSButton *builtInAudioToggleButton;
@property (strong, nonatomic) AVAudioPlayer *audioPlayer;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Set default built-in sound
    NSString *bundlePath = [[NSBundle mainBundle] pathForResource:@"trigger" ofType:@"mp3"];
    self.selectedAudioFile = bundlePath ?: @"/Users/lasse/Desktop/LidAnglePranker/LidAnglePranker/trigger.mp3";

    [self createWindow];
    [self initializeLidSensor];
    [self startUpdatingDisplay];

    // Preload the default audio file to eliminate first-time delay
    [self preloadAudioPlayer];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    [self.updateTimer invalidate];
    [self.lidSensor stopLidAngleUpdates];
}

- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app {
    return YES;
}

- (void)createWindow {
    // Create the main window (with audio controls)
    NSRect windowFrame = NSMakeRect(100, 100, 450, 600);
    self.window = [[NSWindow alloc] initWithContentRect:windowFrame
                                              styleMask:NSWindowStyleMaskTitled |
                                                       NSWindowStyleMaskClosable |
                                                       NSWindowStyleMaskMiniaturizable
                                                backing:NSBackingStoreBuffered
                                                  defer:NO];

    [self.window setTitle:@"Lid Angle Pranker"];
    [self.window makeKeyAndOrderFront:nil];
    [self.window center];

    // Create the content view
    NSView *contentView = [[NSView alloc] initWithFrame:windowFrame];
    [self.window setContentView:contentView];

    // Create angle display label with tabular numbers (larger, light font)
    self.angleLabel = [[NSLabel alloc] init];
    [self.angleLabel setStringValue:@"Initializing..."];
    [self.angleLabel setFont:[NSFont monospacedDigitSystemFontOfSize:48 weight:NSFontWeightLight]];
    [self.angleLabel setAlignment:NSTextAlignmentCenter];
    [self.angleLabel setTextColor:[NSColor systemBlueColor]];
    [contentView addSubview:self.angleLabel];

    // Create status label
    self.statusLabel = [[NSLabel alloc] init];
    [self.statusLabel setStringValue:@"Detecting sensor..."];
    [self.statusLabel setFont:[NSFont systemFontOfSize:14]];
    [self.statusLabel setAlignment:NSTextAlignmentCenter];
    [self.statusLabel setTextColor:[NSColor secondaryLabelColor]];
    [contentView addSubview:self.statusLabel];

    // Create threshold label
    self.thresholdLabel = [[NSLabel alloc] init];
    [self.thresholdLabel setStringValue:@"Play threshold (degrees):"];
    [self.thresholdLabel setFont:[NSFont systemFontOfSize:14 weight:NSFontWeightMedium]];
    [self.thresholdLabel setAlignment:NSTextAlignmentCenter];
    [self.thresholdLabel setTextColor:[NSColor labelColor]];
    [contentView addSubview:self.thresholdLabel];

    // Create threshold input
    self.thresholdInput = [[NSTextField alloc] init];
    [self.thresholdInput setStringValue:@"30.0"];
    [self.thresholdInput setFont:[NSFont systemFontOfSize:14]];
    [self.thresholdInput setAlignment:NSTextAlignmentCenter];
    [self.thresholdInput setTarget:self];
    [self.thresholdInput setAction:@selector(thresholdChanged:)];
    [self.thresholdInput setTranslatesAutoresizingMaskIntoConstraints:NO];
    [contentView addSubview:self.thresholdInput];


    // Create sound type selector
    self.soundTypeSelector = [[NSSegmentedControl alloc] init];
    [self.soundTypeSelector setSegmentCount:2];
    [self.soundTypeSelector setLabel:@"Built-in" forSegment:0];
    [self.soundTypeSelector setLabel:@"Custom" forSegment:1];
    [self.soundTypeSelector setSelectedSegment:0]; // Default to built-in
    [self.soundTypeSelector setTarget:self];
    [self.soundTypeSelector setAction:@selector(soundTypeChanged:)];
    [self.soundTypeSelector setTranslatesAutoresizingMaskIntoConstraints:NO];
    [contentView addSubview:self.soundTypeSelector];

    // Create sound file selection button
    self.selectSoundButton = [[NSButton alloc] init];
    [self.selectSoundButton setTitle:@"Select Custom File"];
    [self.selectSoundButton setBezelStyle:NSBezelStyleRounded];
    [self.selectSoundButton setTarget:self];
    [self.selectSoundButton setAction:@selector(selectSoundFile:)];
    [self.selectSoundButton setTranslatesAutoresizingMaskIntoConstraints:NO];
    [self.selectSoundButton setHidden:YES]; // Hidden by default for built-in sound
    [contentView addSubview:self.selectSoundButton];

    // Create selected sound label
    self.selectedSoundLabel = [[NSLabel alloc] init];
    [self.selectedSoundLabel setStringValue:@"Built-in: trigger.mp3"];
    [self.selectedSoundLabel setFont:[NSFont systemFontOfSize:12]];
    [self.selectedSoundLabel setAlignment:NSTextAlignmentCenter];
    [self.selectedSoundLabel setTextColor:[NSColor labelColor]];
    [contentView addSubview:self.selectedSoundLabel];

    // Create audio toggle button
    self.audioToggleButton = [[NSButton alloc] init];
    [self.audioToggleButton setTitle:@"Start Audio"];
    [self.audioToggleButton setBezelStyle:NSBezelStyleRounded];
    [self.audioToggleButton setTarget:self];
    [self.audioToggleButton setAction:@selector(toggleAudio:)];
    [self.audioToggleButton setTranslatesAutoresizingMaskIntoConstraints:NO];
    [self.audioToggleButton setEnabled:YES]; // Enabled by default with built-in sound
    [contentView addSubview:self.audioToggleButton];

    // Create loop toggle button
    self.loopToggleButton = [[NSButton alloc] init];
    [self.loopToggleButton setTitle:@"Loop: OFF"];
    [self.loopToggleButton setBezelStyle:NSBezelStyleRounded];
    [self.loopToggleButton setTarget:self];
    [self.loopToggleButton setAction:@selector(toggleLoop:)];
    [self.loopToggleButton setTranslatesAutoresizingMaskIntoConstraints:NO];
    [self.loopToggleButton setEnabled:YES];
    [contentView addSubview:self.loopToggleButton];

    // Create built-in audio toggle button
    self.builtInAudioToggleButton = [[NSButton alloc] init];
    [self.builtInAudioToggleButton setTitle:@"trigger.mp3"];
    [self.builtInAudioToggleButton setBezelStyle:NSBezelStyleRounded];
    [self.builtInAudioToggleButton setTarget:self];
    [self.builtInAudioToggleButton setAction:@selector(toggleBuiltInAudio:)];
    [self.builtInAudioToggleButton setTranslatesAutoresizingMaskIntoConstraints:NO];
    [self.builtInAudioToggleButton setEnabled:YES];
    [contentView addSubview:self.builtInAudioToggleButton];

    // Create audio status label
    self.audioStatusLabel = [[NSLabel alloc] init];
    [self.audioStatusLabel setStringValue:@"Audio ready - Click 'Start Audio' to enable threshold alerts"];
    [self.audioStatusLabel setFont:[NSFont systemFontOfSize:12]];
    [self.audioStatusLabel setAlignment:NSTextAlignmentCenter];
    [self.audioStatusLabel setTextColor:[NSColor secondaryLabelColor]];
    [contentView addSubview:self.audioStatusLabel];

    // Create circular angle slider for visualization
    self.angleSlider = [[CircularAngleSlider alloc] init];
    [self.angleSlider setTranslatesAutoresizingMaskIntoConstraints:NO];
    [self.angleSlider setTarget:self];
    [self.angleSlider setAction:@selector(sliderThresholdChanged:)];
    [contentView addSubview:self.angleSlider];

    // Set up auto layout constraints
    [NSLayoutConstraint activateConstraints:@[
        // Angle label (main display, now at top)
        [self.angleLabel.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:40],
        [self.angleLabel.centerXAnchor constraintEqualToAnchor:contentView.centerXAnchor],
        [self.angleLabel.widthAnchor constraintLessThanOrEqualToAnchor:contentView.widthAnchor constant:-40],

        // Status label
        [self.statusLabel.topAnchor constraintEqualToAnchor:self.angleLabel.bottomAnchor constant:15],
        [self.statusLabel.centerXAnchor constraintEqualToAnchor:contentView.centerXAnchor],
        [self.statusLabel.widthAnchor constraintLessThanOrEqualToAnchor:contentView.widthAnchor constant:-40],

        // Threshold label
        [self.thresholdLabel.topAnchor constraintEqualToAnchor:self.statusLabel.bottomAnchor constant:25],
        [self.thresholdLabel.centerXAnchor constraintEqualToAnchor:contentView.centerXAnchor],
        [self.thresholdLabel.widthAnchor constraintLessThanOrEqualToAnchor:contentView.widthAnchor constant:-40],

        // Threshold input
        [self.thresholdInput.topAnchor constraintEqualToAnchor:self.thresholdLabel.bottomAnchor constant:10],
        [self.thresholdInput.centerXAnchor constraintEqualToAnchor:contentView.centerXAnchor],
        [self.thresholdInput.widthAnchor constraintEqualToConstant:100],
        [self.thresholdInput.heightAnchor constraintEqualToConstant:24],

        // Sound type selector
        [self.soundTypeSelector.topAnchor constraintEqualToAnchor:self.thresholdInput.bottomAnchor constant:20],
        [self.soundTypeSelector.centerXAnchor constraintEqualToAnchor:contentView.centerXAnchor],
        [self.soundTypeSelector.widthAnchor constraintEqualToConstant:140],
        [self.soundTypeSelector.heightAnchor constraintEqualToConstant:28],

        // Sound file selection button
        [self.selectSoundButton.topAnchor constraintEqualToAnchor:self.soundTypeSelector.bottomAnchor constant:10],
        [self.selectSoundButton.centerXAnchor constraintEqualToAnchor:contentView.centerXAnchor],
        [self.selectSoundButton.widthAnchor constraintEqualToConstant:150],
        [self.selectSoundButton.heightAnchor constraintEqualToConstant:32],

        // Selected sound label
        [self.selectedSoundLabel.topAnchor constraintEqualToAnchor:self.selectSoundButton.bottomAnchor constant:8],
        [self.selectedSoundLabel.centerXAnchor constraintEqualToAnchor:contentView.centerXAnchor],
        [self.selectedSoundLabel.widthAnchor constraintLessThanOrEqualToAnchor:contentView.widthAnchor constant:-40],

        // Audio toggle button
        [self.audioToggleButton.topAnchor constraintEqualToAnchor:self.selectedSoundLabel.bottomAnchor constant:15],
        [self.audioToggleButton.centerXAnchor constraintEqualToAnchor:contentView.centerXAnchor],
        [self.audioToggleButton.widthAnchor constraintEqualToConstant:120],
        [self.audioToggleButton.heightAnchor constraintEqualToConstant:32],

        // Loop toggle button
        [self.loopToggleButton.topAnchor constraintEqualToAnchor:self.audioToggleButton.bottomAnchor constant:8],
        [self.loopToggleButton.centerXAnchor constraintEqualToAnchor:contentView.centerXAnchor],
        [self.loopToggleButton.widthAnchor constraintEqualToConstant:120],
        [self.loopToggleButton.heightAnchor constraintEqualToConstant:32],

        // Built-in audio toggle button
        [self.builtInAudioToggleButton.topAnchor constraintEqualToAnchor:self.loopToggleButton.bottomAnchor constant:8],
        [self.builtInAudioToggleButton.centerXAnchor constraintEqualToAnchor:contentView.centerXAnchor],
        [self.builtInAudioToggleButton.widthAnchor constraintEqualToConstant:120],
        [self.builtInAudioToggleButton.heightAnchor constraintEqualToConstant:32],

        // Audio status label
        [self.audioStatusLabel.topAnchor constraintEqualToAnchor:self.builtInAudioToggleButton.bottomAnchor constant:8],
        [self.audioStatusLabel.centerXAnchor constraintEqualToAnchor:contentView.centerXAnchor],
        [self.audioStatusLabel.widthAnchor constraintLessThanOrEqualToAnchor:contentView.widthAnchor constant:-40],

        // Circular angle slider
        [self.angleSlider.topAnchor constraintEqualToAnchor:self.audioStatusLabel.bottomAnchor constant:20],
        [self.angleSlider.centerXAnchor constraintEqualToAnchor:contentView.centerXAnchor],
        [self.angleSlider.widthAnchor constraintEqualToConstant:200],
        [self.angleSlider.heightAnchor constraintEqualToConstant:200],
        [self.angleSlider.bottomAnchor constraintLessThanOrEqualToAnchor:contentView.bottomAnchor constant:-20]
    ]];
}

- (void)initializeLidSensor {
    self.lidSensor = [[LidAnglePranker alloc] init];

    if (self.lidSensor.isAvailable) {
        [self.statusLabel setStringValue:@"Sensor detected - Reading angle..."];
        [self.statusLabel setTextColor:[NSColor systemGreenColor]];
    } else {
        [self.statusLabel setStringValue:@"Lid Angle Pranker not available on this device"];
        [self.statusLabel setTextColor:[NSColor systemRedColor]];
        [self.angleLabel setStringValue:@"Not Available"];
        [self.angleLabel setTextColor:[NSColor systemRedColor]];
    }
}

- (IBAction)thresholdChanged:(id)sender {
    if (self.updatingThreshold) return; // Prevent loop

    NSTextField *textField = (NSTextField *)sender;
    double value = [textField.stringValue doubleValue];

    if (value > 0 && value <= 90) { // Changed to 90 for quarter circle
        double playThreshold = [self.thresholdInput.stringValue doubleValue];

        self.updatingThreshold = YES;
        // Update the circular slider with new threshold
        [self.angleSlider setPlayThreshold:playThreshold];
        self.updatingThreshold = NO;

        NSLog(@"Play threshold updated: %.1f°", playThreshold);
    } else {
        // Invalid threshold, reset to default
        [textField setStringValue:@"30.0"];
    }
}


- (IBAction)soundTypeChanged:(id)sender {
    NSSegmentedControl *control = (NSSegmentedControl *)sender;
    NSInteger selectedSegment = [control selectedSegment];

    if (selectedSegment == 0) { // Built-in
        [self.selectSoundButton setHidden:YES]; // Hide the button for built-in
        [self.builtInAudioToggleButton setHidden:NO]; // Show built-in audio toggle
        [self.selectedSoundLabel setStringValue:@"Built-in: trigger.mp3"];
        [self.selectedSoundLabel setTextColor:[NSColor labelColor]];
        NSString *bundlePath = [[NSBundle mainBundle] pathForResource:@"trigger" ofType:@"mp3"];
    self.selectedAudioFile = bundlePath ?: @"/Users/lasse/Desktop/LidAnglePranker/LidAnglePranker/trigger.mp3";
        [self.audioToggleButton setEnabled:YES];
        [self preloadAudioPlayer];
    } else { // Custom
        [self.selectSoundButton setHidden:NO]; // Show the button for custom
        [self.builtInAudioToggleButton setHidden:YES]; // Hide built-in audio toggle
        [self.selectSoundButton setTitle:@"Select Custom File"];
        [self.selectedSoundLabel setStringValue:@"No custom file selected"];
        [self.selectedSoundLabel setTextColor:[NSColor secondaryLabelColor]];
        self.selectedAudioFile = nil;
        [self.audioToggleButton setEnabled:NO];
    }
}

- (IBAction)selectSoundFile:(id)sender {
    NSInteger selectedSegment = [self.soundTypeSelector selectedSegment];

    if (selectedSegment == 0) { // Built-in sound
        // Just confirm the built-in sound
        NSString *bundlePath = [[NSBundle mainBundle] pathForResource:@"trigger" ofType:@"mp3"];
    self.selectedAudioFile = bundlePath ?: @"/Users/lasse/Desktop/LidAnglePranker/LidAnglePranker/trigger.mp3";
        [self.selectedSoundLabel setStringValue:@"Built-in: trigger.mp3"];
        [self.selectedSoundLabel setTextColor:[NSColor labelColor]];
        [self.audioToggleButton setEnabled:YES];
        [self.audioStatusLabel setStringValue:@"Audio ready - Click 'Start Audio' to enable threshold alerts"];
        [self preloadAudioPlayer];
        NSLog(@"Using built-in audio file: trigger.mp3");
    } else { // Custom sound
        NSOpenPanel *openPanel = [NSOpenPanel openPanel];
        [openPanel setAllowedFileTypes:@[@"wav", @"mp3", @"m4a", @"aiff", @"aac"]];
        [openPanel setCanChooseFiles:YES];
        [openPanel setCanChooseDirectories:NO];
        [openPanel setAllowsMultipleSelection:NO];
        [openPanel setTitle:@"Select Audio File"];

        if ([openPanel runModal] == NSModalResponseOK) {
            NSURL *selectedURL = [[openPanel URLs] objectAtIndex:0];
            self.selectedAudioFile = [selectedURL path];

            NSString *fileName = [selectedURL lastPathComponent];
            [self.selectedSoundLabel setStringValue:[NSString stringWithFormat:@"Custom: %@", fileName]];
            [self.selectedSoundLabel setTextColor:[NSColor labelColor]];

            // Enable the audio toggle button
            [self.audioToggleButton setEnabled:YES];
            [self.audioStatusLabel setStringValue:@"Audio ready - Click 'Start Audio' to enable threshold alerts"];

            // Preload the newly selected custom audio file
            [self preloadAudioPlayer];
            NSLog(@"Selected custom audio file: %@", self.selectedAudioFile);
        }
    }
}

- (IBAction)toggleAudio:(id)sender {
    self.isAudioActive = !self.isAudioActive;

    if (self.isAudioActive) {
        [self.audioToggleButton setTitle:@"Stop Audio"];
        [self.audioStatusLabel setStringValue:@"Audio monitoring active"];
        [self.audioStatusLabel setTextColor:[NSColor systemGreenColor]];
    } else {
        [self.audioToggleButton setTitle:@"Start Audio"];
        [self.audioStatusLabel setStringValue:@"Audio monitoring stopped"];
        [self.audioStatusLabel setTextColor:[NSColor secondaryLabelColor]];

        // Stop any currently playing audio
        if (self.audioPlayer.isPlaying) {
            [self.audioPlayer stop];
        }
    }
}

- (IBAction)toggleLoop:(id)sender {
    self.isLoopEnabled = !self.isLoopEnabled;

    if (self.isLoopEnabled) {
        [self.loopToggleButton setTitle:@"Loop: ON"];
    } else {
        [self.loopToggleButton setTitle:@"Loop: OFF"];
    }
}

- (IBAction)toggleBuiltInAudio:(id)sender {
    // Get current button title to determine which audio file to use
    NSString *currentTitle = [self.builtInAudioToggleButton title];

    if ([currentTitle isEqualToString:@"trigger.mp3"]) {
        // Switch to trigger2.mp3
        [self.builtInAudioToggleButton setTitle:@"trigger2.mp3"];
        [self.selectedSoundLabel setStringValue:@"Built-in: trigger2.mp3"];
        NSString *bundlePath = [[NSBundle mainBundle] pathForResource:@"trigger2" ofType:@"mp3"];
        self.selectedAudioFile = bundlePath ?: @"/Users/lasse/Desktop/LidAnglePranker/LidAnglePranker/trigger2.mp3";
    } else {
        // Switch to trigger.mp3
        [self.builtInAudioToggleButton setTitle:@"trigger.mp3"];
        [self.selectedSoundLabel setStringValue:@"Built-in: trigger.mp3"];
        NSString *bundlePath = [[NSBundle mainBundle] pathForResource:@"trigger" ofType:@"mp3"];
        self.selectedAudioFile = bundlePath ?: @"/Users/lasse/Desktop/LidAnglePranker/LidAnglePranker/trigger.mp3";
    }

    // Preload the newly selected audio file
    [self preloadAudioPlayer];
}

- (void)preloadAudioPlayer {
    if (!self.selectedAudioFile) {
        return;
    }

    NSError *error;
    NSURL *audioURL = [NSURL fileURLWithPath:self.selectedAudioFile];
    self.audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:audioURL error:&error];

    if (error) {
        NSLog(@"Error preloading audio player: %@", error.localizedDescription);
        return;
    }

    // Set delegate to detect when audio finishes
    self.audioPlayer.delegate = self;

    // Preload the audio by calling prepareToPlay
    [self.audioPlayer prepareToPlay];

    NSLog(@"Audio player preloaded successfully for: %@", self.selectedAudioFile);
}

- (void)playAudioAlert {
    if (!self.isAudioActive || !self.selectedAudioFile) {
        return;
    }

    // Don't start new audio if already playing (let it finish first for looping)
    if (self.audioPlayer.isPlaying) {
        return;
    }

    // If audio player doesn't exist or URL doesn't match, preload it
    if (!self.audioPlayer || ![self.audioPlayer.url.path isEqualToString:self.selectedAudioFile]) {
        [self preloadAudioPlayer];
    }

    if (!self.audioPlayer) {
        NSLog(@"Error: Audio player failed to preload");
        [self.audioStatusLabel setStringValue:@"Error playing audio file"];
        [self.audioStatusLabel setTextColor:[NSColor systemRedColor]];
        return;
    }
    
    // Configure looping based on toggle state
    if (self.isLoopEnabled) {
        self.audioPlayer.numberOfLoops = -1; // Loop indefinitely
    } else {
        self.audioPlayer.numberOfLoops = 0; // Play once
    }
    
    [self.audioPlayer play];
    NSLog(@"Audio alert triggered - threshold crossed (Loop: %@)", self.isLoopEnabled ? @"ON" : @"OFF");
}

- (void)startUpdatingDisplay {
    // Update every 16ms (60Hz) for smooth real-time display updates
    self.updateTimer = [NSTimer scheduledTimerWithTimeInterval:0.016
                                                        target:self
                                                      selector:@selector(updateAngleDisplay)
                                                      userInfo:nil
                                                       repeats:YES];
}

- (void)updateAngleDisplay {
    if (!self.lidSensor.isAvailable) {
        return;
    }

    double angle = [self.lidSensor lidAngle];

    if (angle == -2.0) {
        [self.angleLabel setStringValue:@"Read Error"];
        [self.angleLabel setTextColor:[NSColor systemOrangeColor]];
        [self.statusLabel setStringValue:@"Failed to read sensor data"];
        [self.statusLabel setTextColor:[NSColor systemOrangeColor]];
    } else {
        [self.angleLabel setStringValue:[NSString stringWithFormat:@"%.1f°", angle]];
        [self.angleLabel setTextColor:[NSColor systemBlueColor]];


        // Show threshold status
        double playThreshold = [self.thresholdInput.stringValue doubleValue];

        NSString *thresholdStatus;
        if (angle <= playThreshold) {
            thresholdStatus = [NSString stringWithFormat:@"🔴 TRIGGER ZONE (≤%.0f°) - Audio will play!", playThreshold];
            // Trigger audio alert only once when entering the trigger zone
            if (self.isAudioActive && !self.hasTriggeredForCurrentCrossing) {
                [self playAudioAlert];
                self.audioCurrentlyPlaying = YES;
                self.hasTriggeredForCurrentCrossing = YES;
            }
        } else {
            thresholdStatus = [NSString stringWithFormat:@"🟢 Safe zone (>%.0f°)", playThreshold];

            // Reset the trigger flag when leaving the trigger zone
            self.hasTriggeredForCurrentCrossing = NO;

            // Check for automatic audio stopping when angle goes upward past play threshold
            if (self.audioCurrentlyPlaying && angle > playThreshold && angle > self.lastAngle) {
                // Stop audio when lid angle increases past play threshold
                if (self.audioPlayer.isPlaying) {
                    [self.audioPlayer stop];
                    self.audioCurrentlyPlaying = NO;
                    NSLog(@"Audio stopped automatically - lid angle went past %.1f degrees", playThreshold);
                }
            }
        }

        // Update the circular slider with current angle and threshold
        [self.angleSlider setAngle:angle];
        [self.angleSlider setPlayThreshold:[self.thresholdInput.stringValue doubleValue]];

        // Store current angle for next comparison
        self.lastAngle = angle;

        [self.statusLabel setStringValue:thresholdStatus];
        [self.statusLabel setTextColor:[NSColor secondaryLabelColor]];
    }
}

- (IBAction)sliderThresholdChanged:(id)sender {
    if (self.updatingThreshold) return; // Prevent loop

    CircularAngleSlider *slider = (CircularAngleSlider *)sender;
    double newThreshold = slider.playThreshold;

    self.updatingThreshold = YES;
    // Update the text field to reflect the new threshold from slider
    [self.thresholdInput setStringValue:[NSString stringWithFormat:@"%.1f", newThreshold]];
    self.updatingThreshold = NO;

    NSLog(@"Threshold updated via slider drag: %.1f°", newThreshold);
}

@end