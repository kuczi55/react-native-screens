#ifdef RCT_NEW_ARCH_ENABLED
#import <React/RCTFabricComponentsPlugins.h>
#import <React/RCTMountingTransactionObserving.h>
#import <React/RCTSurfaceTouchHandler.h>
#import <React/UIView+React.h>
#import <react/renderer/components/rnscreens/ComponentDescriptors.h>
#import <react/renderer/components/rnscreens/EventEmitters.h>
#import <react/renderer/components/rnscreens/Props.h>
#import <react/renderer/components/rnscreens/RCTComponentViewHelpers.h>
#else
#import <React/RCTBridge.h>
#import <React/RCTRootContentView.h>
#import <React/RCTShadowView.h>
#import <React/RCTTouchHandler.h>
#import <React/RCTUIManager.h>
#import <React/RCTUIManagerUtils.h>
#endif // RCT_NEW_ARCH_ENABLED
//
#import "RNSScreen.h"
#import "RNSScreenSplit.h"
#import "RNSScreenStackAnimator.h"
#import "RNSScreenStackHeaderConfig.h"
#import "RNSScreenWindowTraits.h"

#ifdef RCT_NEW_ARCH_ENABLED
namespace react = facebook::react;
#endif // RCT_NEW_ARCH_ENABLED

@interface RNSScreenSplitView () <
    UISplitViewControllerDelegate
#ifdef RCT_NEW_ARCH_ENABLED
    ,
    RCTMountingTransactionObserving
#endif
    >

@end

@implementation RNSSplitViewController

@end

@implementation RNSScreenSplitView {
  UISplitViewController *_controller;
  NSMutableArray<RNSScreenView *> *_reactSubviews;
  BOOL _invalidated;
  BOOL _hasLayout;
  __weak RNSScreenSplitManager *_manager;
#ifdef RCT_NEW_ARCH_ENABLED
  UIView *_snapshot;
#endif
}

#ifdef RCT_NEW_ARCH_ENABLED
- (instancetype)initWithFrame:(CGRect)frame
{
  if (self = [super initWithFrame:frame]) {
    static const auto defaultProps = std::make_shared<const react::RNSScreenSplitProps>();
    _props = defaultProps;
    [self initCommonProps];
  }

  return self;
}
#endif // RCT_NEW_ARCH_ENABLED

- (instancetype)initWithManager:(RNSScreenSplitManager *)manager
{
  if (self = [super init]) {
    _hasLayout = NO;
    _invalidated = NO;
    _manager = manager;
    [self initCommonProps];
  }
  return self;
}

- (void)initCommonProps
{
  _reactSubviews = [NSMutableArray new];
  _controller = [RNSSplitViewController new];
  _controller.delegate = self;
  // we have to initialize viewControllers with a non empty array for
  // largeTitle header to render in the opened state. If it is empty
  // the header will render in collapsed state which is perhaps a bug
  // in UIKit but ¯\_(ツ)_/¯
  [_controller setViewControllers:@[ [UIViewController new] ]];
}

#pragma mark - Common

- (NSArray<UIView *> *)reactSubviews
{
  return _reactSubviews;
}

- (void)maybeAddToParentAndUpdateContainer
{
  BOOL wasScreenMounted = _controller.parentViewController != nil;
#ifdef RCT_NEW_ARCH_ENABLED
  BOOL isScreenReadyForShowing = self.window;
#else
  BOOL isScreenReadyForShowing = self.window && _hasLayout;
#endif
  if (!isScreenReadyForShowing && !wasScreenMounted) {
    // We wait with adding to parent controller until the stack is mounted and has its initial
    // layout done.
    // If we add it before layout, some of the items (specifically items from the navigation bar),
    // won't be able to position properly. Also the position and size of such items, even if it
    // happens to change, won't be properly updated (this is perhaps some internal issue of UIKit).
    // If we add it when window is not attached, some of the view transitions will be bloced (i.e.
    // modal transitions) and the internal view controler's state will get out of sync with what's
    // on screen without us knowing.
    return;
  }
  [self updateContainer];
  if (!wasScreenMounted) {
    // when stack hasn't been added to parent VC yet we do two things:
    // 1) we run updateContainer (the one above) – we do this because we want push view controllers to
    // be installed before the VC is mounted. If we do that after it is added to parent the push
    // updates operations are going to be blocked by UIKit.
    // 2) we add navigation VS to parent – this is needed for the VC lifecycle events to be dispatched
    // properly
    // 3) we again call updateContainer – this time we do this to open modal controllers. Modals
    // won't open in (1) because they require navigator to be added to parent. We handle that case
    // gracefully in setModalViewControllers and can retry opening at any point.
    [self reactAddControllerToClosestParent:_controller];
    [self updateContainer];
  }
}

- (void)reactAddControllerToClosestParent:(UIViewController *)controller
{
  if (!controller.parentViewController) {
    UIView *parentView = (UIView *)self.reactSuperview;
    while (parentView) {
      if (parentView.reactViewController) {
        [parentView.reactViewController addChildViewController:controller];
        [self addSubview:controller.view];
        [controller didMoveToParentViewController:parentView.reactViewController];
        ;
        break;
      }
      parentView = (UIView *)parentView.reactSuperview;
    }
    return;
  }
}

- (void)setPushViewControllers:(NSArray<UIViewController *> *)controllers
{
  // when there is no change we return immediately
  if ([_controller.viewControllers isEqualToArray:controllers]) {
    return;
  }

  // if view controller is not yet attached to window we skip updates now and run them when view
  // is attached
  if (self.window == nil) {
    return;
  }

  [_controller setViewControllers:controllers];
}

- (void)updateContainer
{
  NSMutableArray<UIViewController *> *splitControllers = [NSMutableArray new];
  for (RNSScreenView *screen in _reactSubviews) {
    if (!screen.dismissed && screen.controller != nil) {
      [splitControllers addObject:screen.controller];
    }
  }

  [self setPushViewControllers:splitControllers];
}

- (void)layoutSubviews
{
  [super layoutSubviews];
  _controller.view.frame = self.bounds;
}

- (void)dismissOnReload
{
#ifdef RCT_NEW_ARCH_ENABLED
#else
  dispatch_async(dispatch_get_main_queue(), ^{
    [self invalidate];
  });
#endif // RCT_NEW_ARCH_ENABLED
}

- (void)markChildUpdated
{
  // do nothing
}

- (void)didUpdateChildren
{
  // do nothing
}

- (UIViewController *)reactViewController
{
  return _controller;
}

- (void)insertReactSubview:(RNSScreenView *)subview atIndex:(NSInteger)atIndex
{
  if (![subview isKindOfClass:[RNSScreenView class]]) {
    RCTLogError(@"ScreenStack only accepts children of type Screen");
    return;
  }
  subview.reactSuperview = self;
  [_reactSubviews insertObject:subview atIndex:atIndex];
}

- (void)removeReactSubview:(RNSScreenView *)subview
{
  subview.reactSuperview = nil;
  [_reactSubviews removeObject:subview];
}

- (void)didUpdateReactSubviews
{
  // we need to wait until children have their layout set. At this point they don't have the layout
  // set yet, however the layout call is already enqueued on ui thread. Enqueuing update call on the
  // ui queue will guarantee that the update will run after layout.
  dispatch_async(dispatch_get_main_queue(), ^{
    self->_hasLayout = YES;
    [self maybeAddToParentAndUpdateContainer];
  });
}

#ifdef RCT_NEW_ARCH_ENABLED
#pragma mark - Fabric specific

- (void)mountChildComponentView:(UIView<RCTComponentViewProtocol> *)childComponentView index:(NSInteger)index
{
  if (![childComponentView isKindOfClass:[RNSScreenView class]]) {
    RCTLogError(@"ScreenStack only accepts children of type Screen");
    return;
  }

  RCTAssert(
      childComponentView.reactSuperview == nil,
      @"Attempt to mount already mounted component view. (parent: %@, child: %@, index: %@, existing parent: %@)",
      self,
      childComponentView,
      @(index),
      @([childComponentView.superview tag]));

  [_reactSubviews insertObject:(RNSScreenView *)childComponentView atIndex:index];
  ((RNSScreenView *)childComponentView).reactSuperview = self;
  dispatch_async(dispatch_get_main_queue(), ^{
    [self maybeAddToParentAndUpdateContainer];
  });
}

- (void)unmountChildComponentView:(UIView<RCTComponentViewProtocol> *)childComponentView index:(NSInteger)index
{
  RNSScreenView *screenChildComponent = (RNSScreenView *)childComponentView;
  // We should only do a snapshot of a screen that is on the top.
  // We also check `_presentedModals` since if you push 2 modals, second one is not a "child" of _controller.
  // Also, when dissmised with a gesture, the screen already is not under the window, so we don't need to apply
  // snapshot.
  if (screenChildComponent.window != nil && screenChildComponent == _controller.viewControllers.firstObject.view) {
    [screenChildComponent.controller setViewToSnapshot:_snapshot];
  }

  RCTAssert(
      screenChildComponent.reactSuperview == self,
      @"Attempt to unmount a view which is mounted inside different view. (parent: %@, child: %@, index: %@)",
      self,
      screenChildComponent,
      @(index));
  RCTAssert(
      (_reactSubviews.count > index) && [_reactSubviews objectAtIndex:index] == childComponentView,
      @"Attempt to unmount a view which has a different index. (parent: %@, child: %@, index: %@, actual index: %@, tag at index: %@)",
      self,
      screenChildComponent,
      @(index),
      @([_reactSubviews indexOfObject:screenChildComponent]),
      @([[_reactSubviews objectAtIndex:index] tag]));
  screenChildComponent.reactSuperview = nil;
  [_reactSubviews removeObject:screenChildComponent];
  [screenChildComponent removeFromSuperview];
  dispatch_async(dispatch_get_main_queue(), ^{
    [self maybeAddToParentAndUpdateContainer];
  });
}

- (void)takeSnapshot
{
  _snapshot = [_controller.viewControllers.firstObject.view snapshotViewAfterScreenUpdates:NO];
}

- (void)mountingTransactionWillMount:(react::MountingTransaction const &)transaction
                withSurfaceTelemetry:(react::SurfaceTelemetry const &)surfaceTelemetry
{
  for (auto &mutation : transaction.getMutations()) {
    if (mutation.type == react::ShadowViewMutation::Type::Remove && mutation.parentShadowView.componentName != nil &&
        strcmp(mutation.parentShadowView.componentName, "RNSScreenSplit") == 0) {
      [self takeSnapshot];
      return;
    }
  }
}

- (void)prepareForRecycle
{
  [super prepareForRecycle];
  _reactSubviews = [NSMutableArray new];
  [_controller willMoveToParentViewController:nil];
  [_controller removeFromParentViewController];
  [_controller setViewControllers:@[ [UIViewController new] ]];
}

+ (react::ComponentDescriptorProvider)componentDescriptorProvider
{
  return react::concreteComponentDescriptorProvider<react::RNSScreenSplitComponentDescriptor>();
}
#else
#pragma mark - Paper specific

- (void)invalidate
{
  _invalidated = YES;
  [_controller willMoveToParentViewController:nil];
  [_controller removeFromParentViewController];
}

#endif // RCT_NEW_ARCH_ENABLED

@end

#ifdef RCT_NEW_ARCH_ENABLED
Class<RCTComponentViewProtocol> RNSScreenSplitCls(void)
{
  return RNSScreenSplitView.class;
}
#endif

@implementation RNSScreenSplitManager

RCT_EXPORT_MODULE()

- (UIView *)view
{
  return [[RNSScreenSplitView alloc] initWithManager:self];
}

@end
