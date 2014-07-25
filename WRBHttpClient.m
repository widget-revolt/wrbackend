//
//  WRBHttpClient.m
//
//  Copyright (c) 2014 Widget Revolt LLC.  All rights reserved
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.



#import "WRBHttpClient.h"
#import "WRBackend.h"

#if WRB_USE_AFNETWORKING20
	//VOID
#else
	#import "AFJSONRequestOperation.h"
#endif

#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag
#endif

static WRBHttpClient *_sharedWRBHttpClient = nil;

static NSString* _WRBHttpClient_protocol = @"http://";
static NSString* _WRBHttpClient_server = @"localhost:8080";

@implementation WRBHttpClient

//===========================================================
+ (void) setProtocol:(NSString*)protocol address:(NSString*)address
{
	_WRBHttpClient_protocol = [[NSString alloc] initWithString:protocol];// make copy and retain (forever)
	_WRBHttpClient_server = [[NSString alloc] initWithString:address];// make copy and retain (forever)
}

//===========================================================
+ (WRBHttpClient*) sharedManager
{
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
		
		NSString* serverAddress = _WRBHttpClient_server;
		NSString* httpProtocol = _WRBHttpClient_protocol;

		
		NSString* baseUrlString = [NSString stringWithFormat:@"%@%@", httpProtocol, serverAddress];
		NSURL* baseUrl = [NSURL URLWithString:baseUrlString];
		
        _sharedWRBHttpClient = [[WRBHttpClient alloc] initWithBaseURL:baseUrl];
    });
    
    return _sharedWRBHttpClient;
}
//===========================================================
- (id)initWithBaseURL:(NSURL *)url {
    self = [super initWithBaseURL:url];
    if (!self) {
        return nil;
    }
    
#if WRB_USE_AFNETWORKING20
	//VOID
#else
	
	// AFNetwork 1 requires that we set the default response serializer
[self registerHTTPOperationClass:[AFJSONRequestOperation class]];
    
    // Accept HTTP Header; see http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.1
	[self setDefaultHeader:@"Accept" value:@"application/json"];
#endif
    
    return self;
}

@end
