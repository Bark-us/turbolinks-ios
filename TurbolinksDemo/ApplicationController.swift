import UIKit
import WebKit
import Turbolinks

class ApplicationController: UIViewController, WKNavigationDelegate, SessionDelegate, AuthenticationControllerDelegate {
    let accountLocation = NSURL(string: "http://localhost:9292")!
    let webViewProcessPool = WKProcessPool()
    var mainNavigationController: UINavigationController?

    var application: UIApplication {
        return UIApplication.sharedApplication()
    }

    lazy var webViewConfiguration: WKWebViewConfiguration = {
        let bundle = NSBundle.mainBundle()
        let source = try! String(contentsOfURL: bundle.URLForResource("TurbolinksDemo", withExtension: "js")!, encoding: NSUTF8StringEncoding)
        let userScript = WKUserScript(source: source, injectionTime: .AtDocumentEnd, forMainFrameOnly: true)

        let configuration = WKWebViewConfiguration()
        configuration.userContentController.addUserScript(userScript)
        configuration.processPool = self.webViewProcessPool
        return configuration
    }()

    lazy var session: Session = {
        let session = Session(webViewConfiguration: self.webViewConfiguration)
        session.delegate = self
        return session
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        installMainNavigationController()
        presentVisitableForSession(session, atLocation: accountLocation, withAction: .Advance)
    }

    func installMainNavigationController() {
        let mainNavigationController = UINavigationController()
        self.mainNavigationController = mainNavigationController
        addChildViewController(mainNavigationController)
        view.addSubview(mainNavigationController.view)
        mainNavigationController.didMoveToParentViewController(self)
    }

    private func presentVisitableForSession(session: Session, atLocation location: NSURL, withAction action: Action) {
        if let navigationController = mainNavigationController {
            let visitable = visitableForSession(session, atLocation: location)
            let viewController = visitable.viewController

            if action == .Advance {
                navigationController.pushViewController(viewController, animated: true)
            } else if action == .Replace {
                navigationController.popViewControllerAnimated(false)
                navigationController.pushViewController(viewController, animated: false)
            }

            session.visit(visitable)
        }
    }

    private func visitableForSession(session: Session, atLocation location: NSURL) -> Visitable {
        let visitable = WebViewController()
        visitable.location = location
        visitable.visitableDelegate = session
        return visitable
    }

    func presentAuthenticationController() {
        let authenticationController = AuthenticationController()
        authenticationController.accountLocation = accountLocation
        authenticationController.delegate = self
        authenticationController.title = "Sign in"

        let authNavigationController = UINavigationController(rootViewController: authenticationController)
        presentViewController(authNavigationController, animated: true, completion: nil)
    }
    
    // MARK: Error Handling
    
    private func presentAlertForError(error: NSError) {
        let alertController = UIAlertController(title: "Error loading page", message: error.localizedDescription, preferredStyle: .Alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .Default, handler: nil))
        presentViewController(alertController, animated: true, completion: nil)
    }

    // MARK: SessionDelegate

    func session(session: Session, didProposeVisitToLocation location: NSURL, withAction action: Action) {
        presentVisitableForSession(session, atLocation: location, withAction: action)
    }

    func sessionDidStartRequest(session: Session) {
        application.networkActivityIndicatorVisible = true
    }

    func session(session: Session, didFailRequestForVisitable visitable: Visitable, withError error: NSError) {
        print("ERROR: \(error)")
        if error.code == ErrorCode.HTTPFailure.rawValue, let statusCode = error.userInfo["statusCode"] as? Int where statusCode == 401 {
            presentAuthenticationController()
        } else {
            presentAlertForError(error)
        }
    }

    func sessionDidFinishRequest(session: Session) {
        application.networkActivityIndicatorVisible = false
    }

    func sessionDidInitializeWebView(session: Session) {
        session.webView.navigationDelegate = self
    }

    // MARK: AuthenticationControllerDelegate

    func prepareWebViewConfiguration(configuration: WKWebViewConfiguration, forAuthenticationController authenticationController: AuthenticationController) {
        configuration.processPool = webViewProcessPool
    }

    func authenticationControllerDidAuthenticate(authenticationController: AuthenticationController) {
        session.reload()
        dismissViewControllerAnimated(true, completion: nil)
    }

    // MARK: WKNavigationDelegate

    func webView(webView: WKWebView, decidePolicyForNavigationAction navigationAction: WKNavigationAction, decisionHandler: (WKNavigationActionPolicy) -> ()) {
        decisionHandler(WKNavigationActionPolicy.Cancel)

        if let URL = navigationAction.request.URL {
            UIApplication.sharedApplication().openURL(URL)
        }
    }
}