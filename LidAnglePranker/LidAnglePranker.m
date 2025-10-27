//
//  LidAnglePranker.m
//  LidAnglePranker
//
//  Created by Sam on 2025-09-06.
//

#import "LidAnglePranker.h"

@interface LidAnglePranker ()
@property (nonatomic, assign) IOHIDDeviceRef hidDevice;
@end

@implementation LidAnglePranker

- (instancetype)init {
    self = [super init];
    if (self) {
        _hidDevice = [self findLidAnglePranker];
        if (_hidDevice) {
            IOHIDDeviceOpen(_hidDevice, kIOHIDOptionsTypeNone);
            NSLog(@"[LidAnglePranker] Successfully initialized Lid Angle Pranker");
        } else {
            NSLog(@"[LidAnglePranker] Failed to find Lid Angle Pranker");
        }
    }
    return self;
}

- (void)dealloc {
    [self stopLidAngleUpdates];
}

- (BOOL)isAvailable {
    return _hidDevice != NULL;
}

- (IOHIDDeviceRef)findLidAnglePranker {
    IOHIDManagerRef manager = IOHIDManagerCreate(kCFAllocatorDefault, kIOHIDOptionsTypeNone);
    if (!manager) {
        NSLog(@"[LidAnglePranker] Failed to create IOHIDManager");
        return NULL;
    }
    
    if (IOHIDManagerOpen(manager, kIOHIDOptionsTypeNone) != kIOReturnSuccess) {
        NSLog(@"[LidAnglePranker] Failed to open IOHIDManager");
        CFRelease(manager);
        return NULL;
    }
    
    // Match specifically for the Lid Angle Pranker to avoid permission prompts
    // Target: Sensor page (0x0020), Orientation usage (0x008A)
    NSDictionary *matchingDict = @{
        @"VendorID": @(0x05AC),     // Apple
        @"ProductID": @(0x8104),    // Specific product
        @"UsagePage": @(0x0020),    // Sensor page
        @"Usage": @(0x008A),        // Orientation usage
    };
    
    IOHIDManagerSetDeviceMatching(manager, (__bridge CFDictionaryRef)matchingDict);
    CFSetRef devices = IOHIDManagerCopyDevices(manager);
    IOHIDDeviceRef device = NULL;
    
    if (devices && CFSetGetCount(devices) > 0) {
        NSLog(@"[LidAnglePranker] Found %ld matching Lid Angle Pranker device(s)", CFSetGetCount(devices));
        
        const void **deviceArray = malloc(sizeof(void*) * CFSetGetCount(devices));
        CFSetGetValues(devices, deviceArray);
        
        // Test each matching device to find the one that actually works
        for (CFIndex i = 0; i < CFSetGetCount(devices); i++) {
            IOHIDDeviceRef testDevice = (IOHIDDeviceRef)deviceArray[i];
            
            // Try to open and read from this device
            if (IOHIDDeviceOpen(testDevice, kIOHIDOptionsTypeNone) == kIOReturnSuccess) {
                uint8_t testReport[8] = {0};
                CFIndex reportLength = sizeof(testReport);
                
                IOReturn result = IOHIDDeviceGetReport(testDevice, 
                                                      kIOHIDReportTypeFeature,
                                                      1,
                                                      testReport, 
                                                      &reportLength);
                
                if (result == kIOReturnSuccess && reportLength >= 3) {
                    // This device works! Use it.
                    device = (IOHIDDeviceRef)CFRetain(testDevice);
                    NSLog(@"[LidAnglePranker] Successfully found working Lid Angle Pranker device (index %ld)", i);
                    IOHIDDeviceClose(testDevice, kIOHIDOptionsTypeNone); // Close for now, will reopen in init
                    break;
                } else {
                    NSLog(@"[LidAnglePranker] Device %ld failed to read (result: %d, length: %ld)", i, result, reportLength);
                    IOHIDDeviceClose(testDevice, kIOHIDOptionsTypeNone);
                }
            } else {
                NSLog(@"[LidAnglePranker] Failed to open device %ld", i);
            }
        }
        
        free(deviceArray);
    }
    
    if (devices) CFRelease(devices);
    
    IOHIDManagerClose(manager, kIOHIDOptionsTypeNone);
    CFRelease(manager);
    
    return device;
}

- (double)lidAngle {
    if (!_hidDevice) {
        return -2.0;  // Device not available
    }
    
    // Read lid angle using discovered parameters:
    // Feature Report Type 2, Report ID 1, returns 3 bytes with 16-bit angle in centidegrees
    uint8_t report[8] = {0};
    CFIndex reportLength = sizeof(report);
    
    IOReturn result = IOHIDDeviceGetReport(_hidDevice, 
                                          kIOHIDReportTypeFeature,  // Type 2
                                          1,                        // Report ID 1
                                          report, 
                                          &reportLength);
    
    if (result == kIOReturnSuccess && reportLength >= 3) {
        // Data format: [report_id, angle_low, angle_high]
        // Parse the 16-bit value from bytes 1-2 (skipping report ID)
        uint16_t rawValue = (report[2] << 8) | report[1];  // High byte, low byte
        double angle = (double)rawValue;  // Raw value is already in degrees
        
        return angle;
    }
    
    return -2.0;
}

- (void)startLidAngleUpdates {
    if (!_hidDevice) {
        _hidDevice = [self findLidAnglePranker];
        if (_hidDevice) {
            NSLog(@"[LidAnglePranker] Starting lid angle updates");
            IOHIDDeviceOpen(_hidDevice, kIOHIDOptionsTypeNone);
        } else {
            NSLog(@"[LidAnglePranker] Lid Angle Pranker is not supported");
        }
    }
}

- (void)stopLidAngleUpdates {
    if (_hidDevice) {
        NSLog(@"[LidAnglePranker] Stopping lid angle updates");
        IOHIDDeviceClose(_hidDevice, kIOHIDOptionsTypeNone);
        CFRelease(_hidDevice);
        _hidDevice = NULL;
    }
}

@end
