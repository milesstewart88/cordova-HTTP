#import "CordovaHttpPlugin.h"
#import "CDVFile.h"
#import "TextResponseSerializer.h"
#import "AFHTTPSessionManager.h"

@interface CordovaHttpPlugin()

- (void)setRequestHeaders:(NSDictionary*)headers forManager:(AFHTTPSessionManager*)manager;
- (void)setResults:(NSMutableDictionary*)dictionary withTask:(NSURLSessionTask*)task;

@end


@implementation CordovaHttpPlugin {
    AFSecurityPolicy *securityPolicy;
}

- (void)pluginInitialize {
    securityPolicy = [AFSecurityPolicy policyWithPinningMode:AFSSLPinningModeNone];
}

- (void)setRequestHeaders:(NSDictionary*)headers forManager:(AFHTTPSessionManager*)manager {
    manager.requestSerializer = [AFHTTPRequestSerializer serializer];
    [headers enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        [manager.requestSerializer setValue:obj forHTTPHeaderField:key];
    }];
}

- (void)setResults:(NSMutableDictionary*)dictionary withTask:(NSURLSessionTask*)task {
    if (task.response != nil) {
        NSHTTPURLResponse *response = (NSHTTPURLResponse *)task.response;
        [dictionary setObject:[NSNumber numberWithInt:response.statusCode] forKey:@"status"];
        [dictionary setObject:response.allHeaderFields forKey:@"headers"];
    }
}

- (void)setResultsResponse:(NSMutableDictionary*)dictionary withResponse:(NSURLResponse*)urlResponse {
    if (urlResponse != nil) {
        NSHTTPURLResponse *response = (NSHTTPURLResponse *)urlResponse;
        [dictionary setObject:[NSNumber numberWithInt:response.statusCode] forKey:@"status"];
        [dictionary setObject:response.allHeaderFields forKey:@"headers"];
    }
}

- (void)enableSSLPinning:(CDVInvokedUrlCommand*)command {
    bool enable = [[command.arguments objectAtIndex:0] boolValue];
    if (enable) {
        securityPolicy = [AFSecurityPolicy policyWithPinningMode:AFSSLPinningModeCertificate];
    } else {
        securityPolicy = [AFSecurityPolicy policyWithPinningMode:AFSSLPinningModeNone];
    }
    
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)acceptAllCerts:(CDVInvokedUrlCommand*)command {
    CDVPluginResult* pluginResult = nil;
    bool allow = [[command.arguments objectAtIndex:0] boolValue];
    
    securityPolicy.allowInvalidCertificates = allow;
    
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)validateDomainName:(CDVInvokedUrlCommand*)command {
    CDVPluginResult* pluginResult = nil;
    bool validate = [[command.arguments objectAtIndex:0] boolValue];
    
    securityPolicy.validatesDomainName = validate;
    
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

-(void)postGet:(CDVInvokedUrlCommand*)command withType:(NSString*)type {
    NSString *urlStr = [command.arguments objectAtIndex:0];
    NSDictionary *parameters = [command.arguments objectAtIndex:1];
    NSDictionary *headers = [command.arguments objectAtIndex:2];
    
    NSURL *url = [NSURL URLWithString:urlStr];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url
                                                           cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:60.0];
    
    // set up request header
    [request setHTTPMethod:type];
    for(id key in headers) {
        id value = [headers objectForKey:key];
        [request setValue:value forHTTPHeaderField:key];
    }
    
    // set up request body
    NSData *requestData = [NSJSONSerialization dataWithJSONObject:parameters options:NSJSONWritingPrettyPrinted error:nil];
    if ([parameters count] > 0) {
        [request setHTTPBody: requestData];
    }
    
    // Make a connection to the iTunes Store on a background queue.
    NSLog(@"Header: %@", [request allHTTPHeaderFields]);
    NSLog(@"Request body: %@", [[NSString alloc] initWithData:[request HTTPBody] encoding:NSUTF8StringEncoding]);
    
    CordovaHttpPlugin* __weak weakSelf = self;
    [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue]
       completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
           if (connectionError) {
               /* ... Handle error ... */
               NSLog(@"Dictionary: %@", [connectionError localizedDescription] );
               [weakSelf postGet:command withType:type];
           } else {
               NSError *error;
               NSDictionary *jsonResponse = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
               if (!jsonResponse) { /* ... Handle error ...*/
                   CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR];
                   [weakSelf.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
               } else {
                   
                   NSLog(@"Dictionary: %@", [jsonResponse description]);
                   
                   NSLog(@"Response body: %@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
                   
                   NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
                   [self setResultsResponse:dictionary withResponse:response];
                   [dictionary setObject:jsonResponse forKey:@"data"];
                   CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:dictionary];
                   [weakSelf.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
                   /* ... Send a response back to the device ... */
               }
           }
       }];
}

- (void)post:(CDVInvokedUrlCommand*)command {
    [self postGet:command withType:@"POST"];

//    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
//    manager.securityPolicy = securityPolicy;
//    NSString *url = [command.arguments objectAtIndex:0];
//    NSDictionary *parameters = [command.arguments objectAtIndex:1];
//    NSDictionary *headers = [command.arguments objectAtIndex:2];
//    [self setRequestHeaders: headers forManager: manager];
//    
//    CordovaHttpPlugin* __weak weakSelf = self;
//    manager.responseSerializer = [TextResponseSerializer serializer];
//    [manager POST:url parameters:parameters progress:nil success:^(NSURLSessionTask *task, id responseObject) {
//        NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
//        [self setResults: dictionary withTask: task];
//        [dictionary setObject:responseObject forKey:@"data"];
//        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:dictionary];
//        [weakSelf.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
//    } failure:^(NSURLSessionTask *task, NSError *error) {
//        NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
//        [self setResults: dictionary withTask: task];
//        NSString* errResponse = [[NSString alloc] initWithData:(NSData *)error.userInfo[AFNetworkingOperationFailingURLResponseDataErrorKey] encoding:NSUTF8StringEncoding];
//        [dictionary setObject:errResponse forKey:@"error"];
//        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:dictionary];
//        [weakSelf.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
//    }];
}

- (void)get:(CDVInvokedUrlCommand*)command {
    [self postGet:command withType:@"GET"];
    
//    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
//    manager.securityPolicy = securityPolicy;
//    NSString *url = [command.arguments objectAtIndex:0];
//    NSDictionary *parameters = [command.arguments objectAtIndex:1];
//    NSDictionary *headers = [command.arguments objectAtIndex:2];
//    [self setRequestHeaders: headers forManager: manager];
//    
//    CordovaHttpPlugin* __weak weakSelf = self;
//    
//    manager.responseSerializer = [TextResponseSerializer serializer];
//    [manager GET:url parameters:parameters progress:nil success:^(NSURLSessionTask *task, id responseObject) {
//        NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
//        [self setResults: dictionary withTask: task];
//        [dictionary setObject:responseObject forKey:@"data"];
//        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:dictionary];
//        [weakSelf.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
//    } failure:^(NSURLSessionTask *task, NSError *error) {
//        NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
//        [self setResults: dictionary withTask: task];
//        NSString* errResponse = [[NSString alloc] initWithData:(NSData *)error.userInfo[AFNetworkingOperationFailingURLResponseDataErrorKey] encoding:NSUTF8StringEncoding];
//        [dictionary setObject:errResponse forKey:@"error"];
//        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:dictionary];
//        [weakSelf.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
//    }];
}

- (void)head:(CDVInvokedUrlCommand*)command {
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    manager.securityPolicy = securityPolicy;
    NSString *url = [command.arguments objectAtIndex:0];
    NSDictionary *parameters = [command.arguments objectAtIndex:1];
    NSDictionary *headers = [command.arguments objectAtIndex:2];
    [self setRequestHeaders: headers forManager: manager];
    
    CordovaHttpPlugin* __weak weakSelf = self;
    
    manager.responseSerializer = [AFHTTPResponseSerializer serializer];
    [manager HEAD:url parameters:parameters success:^(NSURLSessionTask *task) {
        NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
        [self setResults: dictionary withTask: task];
        // no 'body' for HEAD request, omitting 'data'
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:dictionary];
        [weakSelf.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    } failure:^(NSURLSessionTask *task, NSError *error) {
        NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
        [self setResults: dictionary withTask: task];
        NSString* errResponse = [[NSString alloc] initWithData:(NSData *)error.userInfo[AFNetworkingOperationFailingURLResponseDataErrorKey] encoding:NSUTF8StringEncoding];
        [dictionary setObject:errResponse forKey:@"error"];
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:dictionary];
        [weakSelf.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

- (void)uploadFile:(CDVInvokedUrlCommand*)command {
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    manager.securityPolicy = securityPolicy;
    NSString *url = [command.arguments objectAtIndex:0];
    NSDictionary *parameters = [command.arguments objectAtIndex:1];
    NSDictionary *headers = [command.arguments objectAtIndex:2];
    NSString *filePath = [command.arguments objectAtIndex: 3];
    NSString *name = [command.arguments objectAtIndex: 4];
    
    NSURL *fileURL = [NSURL URLWithString: filePath];
    
    [self setRequestHeaders: headers forManager: manager];
    
    CordovaHttpPlugin* __weak weakSelf = self;
    manager.responseSerializer = [TextResponseSerializer serializer];
    [manager POST:url parameters:parameters constructingBodyWithBlock:^(id<AFMultipartFormData> formData) {
        NSError *error;
        [formData appendPartWithFileURL:fileURL name:name error:&error];
        if (error) {
            NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
            [dictionary setObject:[NSNumber numberWithInt:500] forKey:@"status"];
            [dictionary setObject:@"Could not add file to post body." forKey:@"error"];
            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:dictionary];
            [weakSelf.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
            return;
        }
    } progress:nil success:^(NSURLSessionTask *task, id responseObject) {
        NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
        [self setResults: dictionary withTask: task];
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:dictionary];
        [weakSelf.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    } failure:^(NSURLSessionTask *task, NSError *error) {
        NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
        [self setResults: dictionary withTask: task];
        NSString* errResponse = [[NSString alloc] initWithData:(NSData *)error.userInfo[AFNetworkingOperationFailingURLResponseDataErrorKey] encoding:NSUTF8StringEncoding];
        [dictionary setObject:errResponse forKey:@"error"];
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:dictionary];
        [weakSelf.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}


- (void)downloadFile:(CDVInvokedUrlCommand*)command {
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    manager.securityPolicy = securityPolicy;
    NSString *url = [command.arguments objectAtIndex:0];
    NSDictionary *parameters = [command.arguments objectAtIndex:1];
    NSDictionary *headers = [command.arguments objectAtIndex:2];
    NSString *filePath = [command.arguments objectAtIndex: 3];
   
    [self setRequestHeaders: headers forManager: manager];
    
    if ([filePath hasPrefix:@"file://"]) {
        filePath = [filePath substringFromIndex:7];
    }
    
    CordovaHttpPlugin* __weak weakSelf = self;
    manager.responseSerializer = [AFHTTPResponseSerializer serializer];
    [manager GET:url parameters:parameters progress:nil success:^(NSURLSessionTask *task, id responseObject) {
        /*
         *
         * Licensed to the Apache Software Foundation (ASF) under one
         * or more contributor license agreements.  See the NOTICE file
         * distributed with this work for additional information
         * regarding copyright ownership.  The ASF licenses this file
         * to you under the Apache License, Version 2.0 (the
         * "License"); you may not use this file except in compliance
         * with the License.  You may obtain a copy of the License at
         *
         *   http://www.apache.org/licenses/LICENSE-2.0
         *
         * Unless required by applicable law or agreed to in writing,
         * software distributed under the License is distributed on an
         * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
         * KIND, either express or implied.  See the License for the
         * specific language governing permissions and limitations
         * under the License.
         *
         * Modified by Andrew Stephan for Sync OnSet
         *
        */
        // Download response is okay; begin streaming output to file
        NSString* parentPath = [filePath stringByDeletingLastPathComponent];
        
        // create parent directories if needed
        NSError *error;
        if ([[NSFileManager defaultManager] createDirectoryAtPath:parentPath withIntermediateDirectories:YES attributes:nil error:&error] == NO) {
            NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
            [dictionary setObject:[NSNumber numberWithInt:500] forKey:@"status"];
            if (error) {
                [dictionary setObject:[NSString stringWithFormat:@"Could not create path to save downloaded file: %@", [error localizedDescription]] forKey:@"error"];
            } else {
                [dictionary setObject:@"Could not create path to save downloaded file" forKey:@"error"];
            }
            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:dictionary];
            [weakSelf.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
            return;
        }
        NSData *data = (NSData *)responseObject;
        if (![data writeToFile:filePath atomically:YES]) {
            NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
            [dictionary setObject:[NSNumber numberWithInt:500] forKey:@"status"];
            [dictionary setObject:@"Could not write the data to the given filePath." forKey:@"error"];
            CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:dictionary];
            [weakSelf.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
            return;
        }
   
        id filePlugin = [self.commandDelegate getCommandInstance:@"File"];
        NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
        [self setResults: dictionary withTask: task];
        [dictionary setObject:[filePlugin getDirectoryEntry:filePath isDirectory:NO] forKey:@"file"];
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:dictionary];
        [weakSelf.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    } failure:^(NSURLSessionTask *task, NSError *error) {
        NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
        [self setResults: dictionary withTask: task];
        NSString* errResponse = [[NSString alloc] initWithData:(NSData *)error.userInfo[AFNetworkingOperationFailingURLResponseDataErrorKey] encoding:NSUTF8StringEncoding];
        [dictionary setObject:errResponse forKey:@"error"];
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:dictionary];
        [weakSelf.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

@end
