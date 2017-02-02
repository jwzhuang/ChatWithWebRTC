/*
 *  Copyright 2016 The WebRTC Project Authors. All rights reserved.
 *
 *  Use of this source code is governed by a BSD-style license
 *  that can be found in the LICENSE file in the root of the source
 *  tree. An additional intellectual property rights grant can be found
 *  in the file PATENTS.  All contributing project authors may
 *  be found in the AUTHORS file in the root of the source tree.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Light-weight persistent store for user settings.
 *
 * It will persist between application launches and application updates.
 */
@interface SettingsStore : NSObject

/**
 * Returns current video resolution media constraint string stored in the store.
 */
- (nullable NSString *)videoResolutionConstraints;

/**
 * Stores the provided value as video resolution media constraint.
 * @param value the string to be stored
 */
- (void)setVideoResolutionConstraints:(NSString *)value;

/**
 * Returns current max bitrate number stored in the store.
 */
- (nullable NSNumber *)maxBitrate;

/**
 * Stores the provided value as maximum bitrate setting.
 * @param value the number to be stored
 */
- (void)setMaxBitrate:(nullable NSNumber *)value;

@end
NS_ASSUME_NONNULL_END