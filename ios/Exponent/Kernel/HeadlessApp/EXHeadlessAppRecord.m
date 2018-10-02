// Copyright 2018-present 650 Industries. All rights reserved.

#import "EXHeadlessAppRecord.h"
#import "EXReactAppManager.h"
#import "EXAppLoader.h"

@interface EXHeadlessAppRecord ()

@property (nonatomic, assign) BOOL isBridgeAlreadyLoading;
@property (nonatomic, strong) void(^callback)(BOOL success, NSError * _Nullable error);

@end


@implementation EXHeadlessAppRecord

@synthesize appManager = _appManager;
@synthesize appLoader = _appLoader;

- (nonnull instancetype)initWithManifestUrl:(NSURL *)manifestUrl
                               initialProps:(NSDictionary *)initialProps
                               fetchTimeout:(NSNumber *)fetchTimeout
                                   callback:(void(^)(BOOL success, NSError * _Nullable error))callback
{
  if (self = [super init]) {
    _callback = callback;
    _isBridgeAlreadyLoading = NO;

    _appManager = [[EXReactAppManager alloc] initWithAppRecord:self initialProps:initialProps];
    [_appManager setIsHeadless:YES];
    [_appManager setDelegate:self];

    _appLoader = [[EXAppLoader alloc] initWithManifestUrl:manifestUrl];

    if (fetchTimeout != nil) {
      [_appLoader setFetchTimeout:[fetchTimeout doubleValue]];
    }

    [_appLoader setDelegate:self];
    [_appLoader requestFromCache];
  }
  return self;
}

- (void)rebuildBridge
{
  if (!_isBridgeAlreadyLoading) {
    _isBridgeAlreadyLoading = YES;
    [_appManager rebuildBridge];
  }
}

- (void)maybeCallCallbackWithSuccess:(BOOL)success error:(nullable NSError *)error
{
  if (_callback != nil) {
    _callback(success, error);
    _callback = nil;
  }
}

# pragma mark - EXAppRecordInterface

- (void)invalidate
{
  [_appManager invalidate];
  _appLoader = nil;
  _appManager = nil;
}

# pragma mark - EXReactAppManagerUIDelegate

- (void)reactAppManager:(EXReactAppManager *)appManager failedToLoadJavaScriptWithError:(NSError *)error
{
  [self maybeCallCallbackWithSuccess:NO error:error];
}

- (void)reactAppManagerIsReadyForLoad:(EXReactAppManager *)appManager
{
  [self maybeCallCallbackWithSuccess:YES error:nil];
}

- (void)reactAppManagerDidInvalidate:(EXReactAppManager *)appManager {}
- (void)reactAppManagerFinishedLoadingJavaScript:(EXReactAppManager *)appManager {}
- (void)reactAppManagerStartedLoadingJavaScript:(EXReactAppManager *)appManager {}

# pragma mark - EXAppLoaderDelegate

- (void)appLoader:(EXAppLoader *)appLoader didLoadOptimisticManifest:(NSDictionary *)manifest
{
  dispatch_async(dispatch_get_main_queue(), ^{
    [self rebuildBridge];
  });
}

- (void)appLoader:(EXAppLoader *)appLoader didFinishLoadingManifest:(NSDictionary *)manifest bundle:(NSData *)data
{
  dispatch_async(dispatch_get_main_queue(), ^{
    [self rebuildBridge];
    [self->_appManager appLoaderFinished];
  });
}

- (void)appLoader:(EXAppLoader *)appLoader didFailWithError:(NSError *)error
{
  if (_appManager.status == kEXReactAppManagerStatusBridgeLoading) {
    [_appManager appLoaderFailedWithError:error];
  }
  [self maybeCallCallbackWithSuccess:NO error:error];
}

- (void)appLoader:(EXAppLoader *)appLoader didLoadBundleWithProgress:(EXLoadingProgress *)progress {}
- (void)appLoader:(EXAppLoader *)appLoader didResolveUpdatedBundleWithManifest:(NSDictionary *)manifest isFromCache:(BOOL)isFromCache error:(NSError *)error {}

@end
