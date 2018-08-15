
#import "ViewController.h"
#import "SLWebView.h"

@interface ViewController ()
@property (nonatomic, strong) SLWebView *webView;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self.view addSubview:self.webView];
}

- (SLWebView *)webView{
    if (!_webView) {
        _webView = [[SLWebView alloc] initWithFrame:self.view.bounds];
        _webView.allowsBackForwardNavigationGestures = YES;
        [_webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"https://www.baidu.com"]]];
    }
    return _webView;
}

@end
