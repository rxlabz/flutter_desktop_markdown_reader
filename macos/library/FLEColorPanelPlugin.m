// Copyright 2018 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import "FLEColorPanelPlugin.h"

#import "FLEViewController.h"

static NSString *const kSystemMessageMethodKey = @"method";
static NSString *const kSystemMessageArgumentsKey = @"args";

static NSString *const kColorPanelChannel = @"flutter/colorpanel";
static NSString *const kShowColorPanelMethod = @"ColorPanel.Show";
static NSString *const kHideColorPanelMethod = @"ColorPanel.Hide";
static NSString *const kColorPanelCallback = @"ColorPanel.Callback";
static NSString *const kColorPanelSuccessKey = @"success";
static NSString *const kColorComponentRedKey = @"red";
static NSString *const kColorComponentGreenKey = @"green";
static NSString *const kColorComponentBlueKey = @"blue";
static const CGFloat kColorComponentMaxValue = 255.0;

/**
 * Converts a color component to a number object suitable for JSON messages.
 *
 * @param component A CGFloat in the range 0-1.
 * @return An instance of NSNumber that wraps an NSInteger in the range 0-255.
 */
static NSNumber *WrapColorComponent(CGFloat component) {
  return @((NSInteger)(component * kColorComponentMaxValue));
}

@implementation FLEColorPanelPlugin

@synthesize controller = _controller;

- (NSString *)channel {
  return kColorPanelChannel;
}

/**
 * Handles platform messages generated by the Flutter framework on the color
 * panel channel.
 */
- (nullable id)handlePlatformMessage:(NSDictionary *)message {
  if ([message.allKeys containsObject:kSystemMessageMethodKey]) {
    NSString *methodName = message[kSystemMessageMethodKey];
    NSLog(@"rx.log %@ %@", methodName, kShowColorPanelMethod);
    if ([methodName isEqualToString:kShowColorPanelMethod]) {
      [self showColorPanel];
    } else if ([methodName isEqualToString:kHideColorPanelMethod]) {
      [self hideColorPanel];
    } else {
      NSLog(@"ERROR: unsupported method %@", methodName);
    }
  } else {
    NSLog(@"ERROR: malformed platform message %@", message);
  }

  return nil;

}

/**
 * Configures the shared instance of NSColorPanel and makes it the frontmost & key window.
 */
- (void)showColorPanel {
  NSLog(@"=> showColorPanel");
  NSColorPanel *sharedColor = [NSColorPanel sharedColorPanel];
  [sharedColor setTarget:self];
  [sharedColor setAction:@selector(selectedColorDidChange)];
  if (!sharedColor.isKeyWindow) {
    [sharedColor makeKeyAndOrderFront:nil];
  }
}

/**
 * Closes the shared color panel.
 */
- (void)hideColorPanel {
  if (![NSColorPanel sharedColorPanelExists]) {
    return;
  }

  NSColorPanel *sharedColor = [NSColorPanel sharedColorPanel];
  [sharedColor setTarget:nil];
  [sharedColor setAction:nil];
  [sharedColor close];
}

/**
 * Called when the user selects a color in the color panel. Grabs the selected color from the
 * panel and sends it to Flutter via the '_controller'.
 */
- (void)selectedColorDidChange {
  NSColor *color = [NSColorPanel sharedColorPanel].color;
  NSDictionary *colorDictionary = [self dictionaryWithColor:color];
  NSMutableDictionary *response = [NSMutableDictionary dictionary];
  response[kSystemMessageMethodKey] = kColorPanelCallback;
  response[kSystemMessageArgumentsKey] = @[ colorDictionary ];

  if (![NSJSONSerialization isValidJSONObject:response]) {
    NSLog(@"ERROR: response is not a valid JSON OBJECT");
    return;
  }
  NSError *error = nil;
  NSData *message = [NSJSONSerialization dataWithJSONObject:response options:0 error:&error];
  if (error != nil) {
    NSLog(@"ERROR: response object could not be serialized: %@", error.debugDescription);
    return;
  }

  [_controller sendPlatformMessage:message onChannel:kColorPanelChannel];
}

/**
 * Converts an instance of NSColor to a dictionary representation suitable for JSON messages.
 *
 * @param color An instance of NSColor.
 * @return An instance of NSDictionary representing the color.
 */
- (NSDictionary *)dictionaryWithColor:(NSColor *)color {
  NSMutableDictionary *result = [NSMutableDictionary dictionary];
  result[kColorComponentRedKey] = WrapColorComponent(color.redComponent);
  result[kColorComponentGreenKey] = WrapColorComponent(color.greenComponent);
  result[kColorComponentBlueKey] = WrapColorComponent(color.blueComponent);
  return result;
}

@end
