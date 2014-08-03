//
//  Loggly.m
//
//  Created by Mehul Dhorda on 5/8/14.
//
//

#import "Loggly.h"

#define BaseUrl @"https://logs-01.loggly.com/inputs/"
#define HTTP_OK 200
#define ResendDelayInMinutes 5

NSString *customerToken;
NSDictionary *logLevelStrings;
NSMutableDictionary *fields;
NSMutableArray *tags;
NSMutableArray *pendingRequests;
NSDateFormatter *dateFormatter;
dispatch_queue_t logglyQueue;
BOOL initialized;
BOOL pendingRequestsQueued;

@implementation Loggly

+(void) initializeWithCustomerToken:(NSString *)token
{
    customerToken = token;
    initialized = YES;
    pendingRequestsQueued = NO;
    logLevelStrings = @{
                        @(LOG_DEBUG): @"Debug",
                        @(LOG_INFO): @"Info",
                        @(LOG_WARNING): @"Warning",
                        @(LOG_ERROR): @"Error"
                        };
    fields = [NSMutableDictionary dictionary];
    tags = [NSMutableArray array];
    pendingRequests = [NSMutableArray array];
    logglyQueue = dispatch_queue_create("Loggly queue", DISPATCH_QUEUE_SERIAL);
    dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    dateFormatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ssZZZZZ";   // Loggly requires ISO-8601 date format
}

+(void) log:(NSString *)message, ...
{
    va_list vl;
    va_start(vl, message);
    NSString* log_message = [[NSString alloc] initWithFormat:message arguments:vl];
    va_end(vl);
    
    [self logWithLevel:LOG_INFO message:log_message];
}

+(void) logWithLevel:(int)level message:(NSString *)message, ...
{
    va_list vl;
    va_start(vl, message);
    NSString* log_message = [[NSString alloc] initWithFormat:message arguments:vl];
    va_end(vl);
    
    NSLog(@"%@", log_message);
    
    // Only log to loggly if we have been initialized
    if (!initialized)
        return;
    
    dispatch_async(logglyQueue, ^{
        // Create JSON object with log fields
        NSMutableDictionary *jsonFields = [NSMutableDictionary dictionaryWithDictionary:fields];
        [jsonFields setObject:[logLevelStrings objectForKey:@(level)] forKey:@"level"];
        [jsonFields setObject:log_message forKey:@"message"];
        [jsonFields setObject:self.timestamp forKey:@"timestamp"];
        NSData *data = [NSJSONSerialization dataWithJSONObject:jsonFields options:0 error:nil];
        
        // Construct request URL
        NSString *requestUrl = [NSString stringWithFormat:@"%@%@", BaseUrl, customerToken];
        if (tags.count > 0)
        {
            NSString *tagStr = [tags componentsJoinedByString:@","];
            requestUrl = [NSString stringWithFormat:@"%@/tag/%@", requestUrl, tagStr];
        }
        
        // Construct request object
        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString: requestUrl]];
        [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
        request.HTTPMethod = @"POST";
        request.HTTPBody = data;
        
        // Send request
        BOOL sent = [self sendRequest:request];
        if (!sent)
        {
            // Add log message to queue and try again in a few minutes
            [pendingRequests addObject:request];
            if (!pendingRequestsQueued)
                [self sendPendingRequests];
        }
    });
}

+(NSMutableDictionary *) fields
{
    return fields;
}

+(NSMutableArray *) tags
{
    return tags;
}

+(NSString *) timestamp
{
    return [dateFormatter stringFromDate:[NSDate date]];
}

+(BOOL) sendRequest:(NSMutableURLRequest *)request
{
    NSHTTPURLResponse *httpResponse;
    NSError *requestError;
    NSData *responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&httpResponse error:&requestError];
    if (httpResponse.statusCode != HTTP_OK)
    {
        if (requestError.domain == NSURLErrorDomain)
            return NO;
        
        NSString *responseStr = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
        NSLog(@"Error logging to loggly - %@", responseStr);
    }
    return YES;
}

+(void) sendPendingRequests
{
    pendingRequestsQueued = YES;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(ResendDelayInMinutes * 60 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        pendingRequestsQueued = NO;
        NSMutableArray *sentRequests = [NSMutableArray array];
        for (NSMutableURLRequest *request in pendingRequests)
        {
            BOOL sent = [self sendRequest:request];
            if (sent)
            {
                // Request sent, so remove from list
                [sentRequests addObject:request];
            }
            else
            {
                // Request wasn't sent so stop iterating and wait for a few minutes before trying again
                [self sendPendingRequests];
                break;
            }
        }
        
        // Remove requests that were sent
        [pendingRequests removeObjectsInArray:sentRequests];
    });
}

@end
