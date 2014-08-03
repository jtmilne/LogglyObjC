//
//  Loggly.h
//
//  Created by Mehul Dhorda on 5/8/14.
//
//

#import <Foundation/Foundation.h>

enum LogglyLevel
{
    LOG_DEBUG,
    LOG_INFO,
    LOG_WARNING,
    LOG_ERROR
};

@interface Loggly : NSObject

/**
 * Initialize Loggly class
 *
 * @param token The Loggly customer token (unique identifier)
 */
+(void) initializeWithCustomerToken:(NSString *)token;

/**
 * Log a message
 *
 * @param message Message to log
 */
+(void) log:(NSString *)message, ...;

/**
 * Log a message with specified log level
 *
 * @param level Log level from LogglyLevel enumeration
 * @param message Message to log
 */
+(void) logWithLevel:(int)level message:(NSString *)message, ...;

/**
 * Additional fields that will be included in JSON log messages
 */
+(NSMutableDictionary *) fields;

/**
 * Tags that log messages will be marked with
 */
+(NSMutableArray *) tags;

@end
