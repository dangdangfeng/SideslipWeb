#import "SLWebView.h"
#import <UIKit/UIGestureRecognizerSubclass.h>

@implementation SLWebView

@end

#pragma mark - 实现全屏侧滑
static volatile bool g_bUseCustomGestureRecognizer = false;

@interface UIScreenEdgePanGestureRecognizer (SLWebView)
@end

@interface SLWebViewPanGestureRecognizerDelegateProxy : NSProxy<UIGestureRecognizerDelegate>
@property (nonatomic, weak) id target;
- (instancetype)init;
@end

@interface SLWebViewPanGestureRecognizer : UIPanGestureRecognizer {
    BOOL _dragging;
    CGPoint _beginPoint;
    NSDate *_beginDate;
    SLWebViewPanGestureRecognizerDelegateProxy *_delegate;
}
@property (nonatomic) UIRectEdge edges;
@end

@interface SLWebViewScreenEdgePanGestureRecognizer : UIScreenEdgePanGestureRecognizer
@property (nonatomic, weak) id target;
@property (nonatomic) SEL action;
- (UIPanGestureRecognizer *)panGestureRecognizer;
@end

@implementation SLWebView (NavigationGestures)

- (BOOL)allowsBackForwardNavigationGestures {
    return [super allowsBackForwardNavigationGestures];
}

- (void)setAllowsBackForwardNavigationGestures:(BOOL)allowsBackForwardNavigationGestures {
    if (allowsBackForwardNavigationGestures == [super allowsBackForwardNavigationGestures]) {
        return;
    }
    if (allowsBackForwardNavigationGestures) {
        // 拦截 UIScreenEdgePanGestureRecognizer 手势。
        g_bUseCustomGestureRecognizer = true;
    }
    [super setAllowsBackForwardNavigationGestures:allowsBackForwardNavigationGestures];
    if (allowsBackForwardNavigationGestures) {
        // 恢复 UIScreenEdgePanGestureRecognizer 手势。
        g_bUseCustomGestureRecognizer = false;
    }
    for (__kindof UIGestureRecognizer *gestureRecognizer in self.gestureRecognizers) {
        if ([gestureRecognizer isKindOfClass:[SLWebViewScreenEdgePanGestureRecognizer class]]) {
            [self addGestureRecognizer:[gestureRecognizer panGestureRecognizer]];
        }
    }
}

@end

@implementation UIScreenEdgePanGestureRecognizer (SLWebView)

+ (instancetype)alloc {
    // 此处拦截UIScreenEdgePanGestureRecognizer实例化方法
    // 拦截实现可以有两种手段，分别是拦截alloc和initWithTarget:action:方法。
    // 由于尝试hook之后执行报错，考虑到不要覆盖原生的initWithTarget:action:方法，此处采用覆盖alloc的方法实现。
    // 由于影响范围太广，每次拦截完成之后，需要立即恢复，避免影响其它代码执行。
    if (g_bUseCustomGestureRecognizer) {
        return [SLWebViewScreenEdgePanGestureRecognizer allocWithZone:nil];
    }
    return [super allocWithZone:nil];
}

@end

@implementation SLWebViewPanGestureRecognizer

- (instancetype)initWithTarget:(id)target action:(SEL)action {
    if ((self = [super initWithTarget:target action:action])) {
        _delegate = [[SLWebViewPanGestureRecognizerDelegateProxy alloc] init];
    }
    return self;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    [super touchesBegan:touches withEvent:event];
    
    UITouch *touch = [touches anyObject];
    _beginPoint = [touch locationInView:self.view];
    _dragging = NO;
    _beginDate = [NSDate date];
}

// 处理 触发区域 （根据需要修改）
- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    static double ANGLE_TAN_VALUE = tan(30 * M_PI / 180);
    
    [super touchesMoved:touches withEvent:event];
    
    if (_dragging || self.state == UIGestureRecognizerStateFailed)
        return;
    
    const int kDirectionPanThreshold = 5;
    
    UITouch *touch = [touches anyObject];
    CGPoint nowPoint = [touch locationInView:self.view];
    
    int horizontalOffset = nowPoint.x - _beginPoint.x;
    int verticalOffset = nowPoint.y - _beginPoint.y;
    UIRectEdge direction;
    
    if (abs(horizontalOffset) > kDirectionPanThreshold
        || abs(verticalOffset) > kDirectionPanThreshold) {
        double angle;
        if (abs(horizontalOffset) > kDirectionPanThreshold) {
            if (horizontalOffset > 0) {
                direction = UIRectEdgeLeft;
            } else {
                direction = UIRectEdgeRight;
            }
            angle = double(abs(verticalOffset)) / abs(horizontalOffset);
        } else {
            if (verticalOffset > 0) {
                direction = UIRectEdgeTop;
            } else {
                direction = UIRectEdgeBottom;
            }
            angle = double(abs(horizontalOffset)) / abs(verticalOffset);
        }
        
        if ((self.edges & direction) && angle < ANGLE_TAN_VALUE) {
            _dragging = YES;
        } else {
            self.state = UIGestureRecognizerStateFailed;
        }
    } else if ([[NSDate date] timeIntervalSinceDate:_beginDate] > 0.1) {
        self.state = UIGestureRecognizerStateFailed;
    }
    
    // 点击位置在右半边，左侧滑
    if (_beginPoint.x > [UIScreen mainScreen].bounds.size.width/3 && direction == UIRectEdgeLeft) {
        self.state = UIGestureRecognizerStateFailed;
    }
    
    // 点击位置在左半边，右侧滑
    if (_beginPoint.x < [UIScreen mainScreen].bounds.size.width/3 && direction == UIRectEdgeRight) {
        self.state = UIGestureRecognizerStateFailed;
    }
}

- (id<UIGestureRecognizerDelegate>)delegate {
    return [super delegate];
}

- (void)setDelegate:(id<UIGestureRecognizerDelegate>)delegate {
    _delegate.target = delegate;
    [super setDelegate:_delegate];
}

@end

@implementation SLWebViewScreenEdgePanGestureRecognizer

- (instancetype)initWithTarget:(id)target action:(SEL)action {
    if ((self = [super initWithTarget:target action:action])) {
        _target = target;
        _action = action;
    }
    return self;
}

- (UIPanGestureRecognizer *)panGestureRecognizer {
    id target = self.target;
    SEL action = self.action;
    SLWebViewPanGestureRecognizer *recognizer = [[SLWebViewPanGestureRecognizer alloc] initWithTarget:target action:action];
    recognizer.edges = self.edges;
    recognizer.delegate = self.delegate;
    return recognizer;
}

@end

@implementation SLWebViewPanGestureRecognizerDelegateProxy

- (instancetype)init {
    return self;
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
    return [_target methodSignatureForSelector:selector];
}

- (void)forwardInvocation:(NSInvocation *)invocation {
    [invocation invokeWithTarget:_target];
}

- (BOOL)respondsToSelector:(SEL)aSelector {
    return [_target respondsToSelector:aSelector];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    if ([otherGestureRecognizer isKindOfClass:[UIPanGestureRecognizer class]]) {
        return YES;
    }
    return [_target gestureRecognizer:gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:otherGestureRecognizer];
}

@end
