//
//  AmazonClientManager.swift
//  Zuzu
//
//  Created by eechih on 1/1/16.
//  Copyright © 2016 Jung-Shuo Pai. All rights reserved.
//


import Foundation
import AWSCore
import AWSCognito
import AWSS3
import FBSDKCoreKit
import FBSDKLoginKit
import FBSDKShareKit
import SCLAlertView
import ObjectMapper

private let Log = Logger.defaultLogger

/// Notification that is generated when login is done.
let UserLoginNotification = "UserLoginNotification"

class AmazonClientManager : NSObject {
    
    //Share Instance for interacting with the ZuzuStore
    class var sharedInstance: AmazonClientManager {
        struct Singleton {
            static let instance = AmazonClientManager()
        }
        
        return Singleton.instance
    }
    
    private struct AWSConstants {
        static let DEFAULT_SERVICE_REGIONTYPE = AWSRegionType.APNortheast1
        static let COGNITO_REGIONTYPE = AWSRegionType.APNortheast1
        static let COGNITO_IDENTITY_POOL_ID = "ap-northeast-1:7e09fc17-5f4b-49d9-bb50-5ca5a9e34b8a"
        static let PLATFORM_APPLICATION_ARN = "arn:aws:sns:ap-northeast-1:994273935857:app/APNS_SANDBOX/zuzurentals_development"
        static let S3_SERVICE_REGIONTYPE = AWSRegionType.APSoutheast1
        static let S3_COLLECTION_BUCKET = "zuzu.mycollection"
        static let S3_ERROR_BUCKET = "zuzu.error"
    }
    
    //Properties
    private var completionHandler: AWSContinuationBlock?
    
    //Login Managers
    private var fbLoginManager: FBSDKLoginManager?
    private var googleSignIn: GIDSignIn?
    
    //Cognito
    private var credentialsProvider: AWSCognitoCredentialsProvider?
    
    //Login View Controller
    private var loginViewController: UIViewController?
    
    //S3
    private var transferManager: AWSS3TransferManager?
    
    //User Login Data
    var userLoginData: UserData?
    
    private func dumpCredentialProviderInfo() {
        
        Log.info("identityId: \(self.credentialsProvider?.identityId)")
        Log.info("identityPoolId: \(self.credentialsProvider?.identityPoolId)")
        Log.info("logins: \(self.credentialsProvider?.logins)")
        Log.info("accessKey: \(self.credentialsProvider?.accessKey)")
        Log.info("secretKey: \(self.credentialsProvider?.secretKey)")
        Log.info("sessionKey: \(self.credentialsProvider?.sessionKey)")
        Log.info("expiration: \(self.credentialsProvider?.expiration)")
        
    }
    
    private func initializeCredentialsProvider(logins: [NSObject : AnyObject]?) -> AWSTask? {
        Log.info("Initializing Credentials Provider...")
        
        AWSLogger.defaultLogger().logLevel = AWSLogLevel.Verbose
        
        self.credentialsProvider = AWSCognitoCredentialsProvider(regionType: AWSConstants.COGNITO_REGIONTYPE, identityPoolId: AWSConstants.COGNITO_IDENTITY_POOL_ID)
        self.credentialsProvider?.logins = logins
        if logins == nil{
            self.credentialsProvider?.clearKeychain()
        }
        
        Log.info("Credential Provider Status (Initial):")
        self.dumpCredentialProviderInfo()
        
        let configuration = AWSServiceConfiguration(region: AWSConstants.DEFAULT_SERVICE_REGIONTYPE, credentialsProvider: self.credentialsProvider)
        
        AWSServiceManager.defaultServiceManager().defaultServiceConfiguration = configuration
        
        let configurationForS3 = AWSServiceConfiguration(region: AWSConstants.S3_SERVICE_REGIONTYPE, credentialsProvider: self.credentialsProvider)
        
        self.transferManager = AWSS3TransferManager(configuration: configurationForS3, identifier: "S3")
        
        return self.credentialsProvider?.getIdentityId()
    }
    
    override init() {
        super.init()
    }
    
    // MARK: AppDelegate Handlers
    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        
        // Initialize Google sign-in
        var configureError: NSError?
        GGLContext.sharedInstance().configureWithError(&configureError)
        assert(configureError == nil, "Error configuring Google services: \(configureError)")
        
        GIDSignIn.sharedInstance().delegate = self
        
        // Initialize Facebook sign-in
        return FBSDKApplicationDelegate.sharedInstance().application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    //Sends the appropriate URL based on login provider
    @available(iOS 9.0, *)
    func application(application: UIApplication,
        openURL url: NSURL, options: [String : AnyObject]) -> Bool {
            
            let sourceApplication: String? = options[UIApplicationOpenURLOptionsSourceApplicationKey] as? String
            let annotation: String? = options[UIApplicationOpenURLOptionsAnnotationKey] as? String
            
            if FBSDKApplicationDelegate.sharedInstance().application(application, openURL: url, sourceApplication: sourceApplication, annotation: annotation) {
                return true
            }
            
            if GIDSignIn.sharedInstance().handleURL(url,
                sourceApplication: sourceApplication,
                annotation: annotation) {
                    return true
            }
            return false
    }
    
    @available(iOS, introduced=8.0, deprecated=9.0)
    func application(application: UIApplication,
        openURL url: NSURL, sourceApplication: String?, annotation: AnyObject?) -> Bool {
            
            if FBSDKApplicationDelegate.sharedInstance().application(application, openURL: url, sourceApplication: sourceApplication, annotation: annotation) {
                return true
            }
            
            if GIDSignIn.sharedInstance().handleURL(url,
                sourceApplication: sourceApplication,
                annotation: annotation) {
                    return true
            }
            return false
    }
    
    // MARK: General Login
    
    func isConfigured() -> Bool {
        return !(AWSConstants.COGNITO_IDENTITY_POOL_ID == "YourCognitoIdentityPoolId" || AWSConstants.COGNITO_REGIONTYPE == AWSRegionType.Unknown)
    }
    
    func resumeSession(completionHandler: AWSContinuationBlock) {
        Log.enter()
        
        self.completionHandler = completionHandler
        
        if let provider = UserDefaultsUtils.getLoginProvider() {
            
            switch(provider) {
            case Provider.FB.rawValue:
                self.reloadFBSession()
            case Provider.GOOGLE.rawValue:
                self.reloadGSession()
            default:
                assert(false, "Invalid Provider")
            }
            
        }
        
        Log.exit()
    }
    
    private func completeLogin(logins: [NSObject : AnyObject]?) {
        Log.info("\(logins)")
        
        var task: AWSTask?
        
        if self.credentialsProvider == nil {
            task = self.initializeCredentialsProvider(logins)
            
            Log.info("Task = \(task)")
        } else {
            var merge = [NSObject : AnyObject]()
            
            //Add existing logins
            if let previousLogins = self.credentialsProvider?.logins {
                merge = previousLogins
            }
            
            //Add new logins
            if let unwrappedLogins = logins {
                for (key, value) in unwrappedLogins {
                    merge[key] = value
                }
                
                Log.debug("Add new logins = \(merge)")
                self.credentialsProvider?.logins = merge
            }
            //Force a refresh of credentials to see if merge is necessary
            task = self.credentialsProvider?.refresh()
            Log.info("Task = \(task)")
        }
        
        task?.continueWithBlock {
            (task: AWSTask!) -> AnyObject! in
            
            Log.info("Credential Provider Status After Login:")
            self.dumpCredentialProviderInfo()
            
            if (task.error != nil) {
                assert(false, "Log in failed")
            }
            else{
                //Upload User Data to S3
                if let userData = self.userLoginData {
                    
                    Log.debug("postNotificationName: \(UserLoginNotification)")
                    NSNotificationCenter.defaultCenter().postNotificationName(UserLoginNotification, object: self, userInfo: ["userData": userData])
                    
                    
                    self.uploadUserDataToS3(userData)
                    
                } else {
                    assert(false, "No userData after loggin in")
                    
                    Log.debug("postNotificationName: \(UserLoginNotification)")
                    NSNotificationCenter.defaultCenter().postNotificationName(UserLoginNotification, object: self, userInfo: nil)
                }
            }
            
            return task
            
            }.continueWithBlock(self.completionHandler!)
    }
    
    func loginFromView(theViewController: UIViewController, mode: Int = 1, withCompletionHandler completionHandler: AWSContinuationBlock) {
        Log.enter()

        self.completionHandler = completionHandler
        self.loginViewController = theViewController


       let storyboard = UIStoryboard(name: "RadarStoryboard", bundle: nil)
        if let vc = storyboard.instantiateViewControllerWithIdentifier("RadarPurchaseLoginView") as? RadarPurchaseLoginViewController {
            vc.modalPresentationStyle = .OverCurrentContext
            vc.loginMode = mode
            
            vc.cancelHandler = { () -> Void in
                ///GA Tracker: Login cancelled
                theViewController.trackEventForCurrentScreen(GAConst.Catrgory.Blocking,
                    action: GAConst.Action.Blocking.loginReject)
            }
            
            vc.fbLoginHandler = { () -> Void in
                self.fbLogin(theViewController)
            }
            vc.googleLoginHandler = { () -> Void in
                self.googleLogin(theViewController)
            }
            theViewController.presentViewController(vc, animated: true, completion: nil)
        }
        
        /*let loginAlertView = SCLAlertView()
        loginAlertView.showCloseButton = false
        
        loginAlertView.addButton("Facebook帳號登入") {
            self.fbLogin(theViewController)
        }
        
        loginAlertView.addButton("Google帳號登入") {
            self.googleLogin(theViewController)
        }
        
        loginAlertView.addButton("取消") {
            ///GA Tracker: Login cancelled
            theViewController.trackEventForCurrentScreen(GAConst.Catrgory.Blocking,
                action: GAConst.Action.Blocking.loginReject)
        }
        
        loginAlertView.showNotice(NSLocalizedString("login.title", comment: ""),
            subTitle: NSLocalizedString("login.body", comment: ""), colorStyle: 0x1CD4C6, colorTextButton: 0xFFFFFF)*/
        Log.exit()
        
    }
    
    func logOut(completionHandler: AWSContinuationBlock) {
        
        Log.enter()
        
        if self.isLoggedInWithFacebook() {
            self.fbLogout()
        }
        
        if self.isLoggedInWithGoogle() {
            self.googleLogout()
        }
        
        self.userLoginData = nil
        UserDefaultsUtils.clearLoginProvider()
        
        // Wipe credentials
        self.credentialsProvider?.logins = nil
        AWSCognito.defaultCognito().wipe()
        self.credentialsProvider?.clearCredentials()
        self.credentialsProvider?.clearKeychain()
        
        AWSTask(result: nil).continueWithBlock(completionHandler)
        
        Log.exit()
    }
    
    func isLoggedIn() -> Bool {
        return isLoggedInWithFacebook() || isLoggedInWithGoogle()
    }
    
    // MARK: Facebook Login
    
    func isLoggedInWithFacebook() -> Bool {
        let loggedIn = FBSDKAccessToken.currentAccessToken() != nil
        
        return loggedIn
    }
    
    func reloadFBSession() {
        if let accessToken = FBSDKAccessToken.currentAccessToken() {
            
            Log.info("Reloading Facebook Session: \(accessToken.expirationDate.description)")
            self.completeFBLoginWithUserData()
        }
    }
    
    func fbLogin(theViewController: UIViewController) {
        
        ///Already signed in
        if FBSDKAccessToken.currentAccessToken() != nil {
            Log.debug("Resume FB Session")
            self.completeFBLogin()
            return
        }
        
        if self.fbLoginManager == nil {
            self.fbLoginManager = FBSDKLoginManager()
        }
        
        Log.debug("Login FB")
        self.fbLoginManager?.logInWithReadPermissions(["public_profile", "email", "user_friends"], fromViewController: theViewController, handler: { (result: FBSDKLoginManagerLoginResult!, error : NSError!) -> Void in
            
            if (error != nil) {
                dispatch_async(dispatch_get_main_queue()) {
                    self.errorAlert("Facebook 登入發生錯誤: " + error.localizedDescription)
                }
                
                ///GA Tracker: Login failed
                theViewController.trackEventForCurrentScreen(GAConst.Catrgory.Blocking,
                    action: GAConst.Action.Blocking.LoginError, label: "\(GAConst.Label.LoginType.Facebook), \(error.userInfo)")
                
                Log.warning("Error: \(error.userInfo)")
                
                self.fbLogout()
                
            } else if result.isCancelled {
                
                ///GA Tracker: Login cancelled
                theViewController.trackEventForCurrentScreen(GAConst.Catrgory.Blocking,
                    action: GAConst.Action.Blocking.LoginCancel, label: GAConst.Label.LoginType.Facebook)
                
                Log.warning("Cancelled")
                
                self.fbLogout()
                
            } else {
                self.completeFBLoginWithUserData()
                
                ///GA Tracker: Login successful
                theViewController.trackEventForCurrentScreen(GAConst.Catrgory.MyCollection,
                    action: GAConst.Action.MyCollection.Login, label: GAConst.Label.LoginType.Facebook)
            }
        })
    }
    
    func completeFBLoginWithUserData(){
        //Query Facebook User Data
        FBSDKGraphRequest.init(graphPath: "me", parameters: ["fields":"id, email, birthday, gender, name, picture.type(large)"]).startWithCompletionHandler { (connection, result, error) -> Void in
            if error == nil {
                
                let loginData = UserData(provider: Provider.FB)
                if let strId: String = result.objectForKey("id") as? String {
                    loginData.id = strId
                }
                if let strEmail: String = result.objectForKey("email") as? String {
                    loginData.email = strEmail
                }
                if let strName: String = result.objectForKey("name") as? String {
                    loginData.name = strName
                }
                if let strGender: String = result.objectForKey("gender") as? String {
                    loginData.gender = strGender
                }
                if let strBirthday: String = result.objectForKey("birthday") as? String {
                    loginData.birthday = strBirthday
                }
                if let strPictureURL: String = result.objectForKey("picture")?.objectForKey("data")?.objectForKey("url") as? String {
                    loginData.pictureUrl = strPictureURL
                }
                
                self.userLoginData = loginData
            } else {
                Log.warning("FBSDKGraphRequest Error: \(error.localizedDescription)")
            }
            
            self.completeFBLogin()
        }
    }
    
    func fbLogout() {
        Log.enter()
        if self.fbLoginManager == nil {
            self.fbLoginManager = FBSDKLoginManager()
        }
        self.fbLoginManager?.logOut()
        Log.exit()
    }
    
    
    private func completeFBLogin() {
        
        UserDefaultsUtils.setLoginProvider(Provider.FB.rawValue)
        
        self.completeLogin(["graph.facebook.com" : FBSDKAccessToken.currentAccessToken().tokenString])
    }
    
    
    // MARK: Google Login
    
    func isLoggedInWithGoogle() -> Bool {
        
        if(self.googleSignIn == nil) {
            self.googleSignIn = GIDSignIn.sharedInstance()
        }
        
        if let _ = self.googleSignIn!.currentUser?.authentication?.accessToken {
            return true
        } else {
            return false
        }
    }
    
    func reloadGSession() {
        
        if(self.googleSignIn == nil) {
            self.googleSignIn = GIDSignIn.sharedInstance()
        }
        
        self.googleSignIn?.signInSilently()
    }
    
    func googleLogin(theViewController: UIViewController) {
        
        if(self.googleSignIn == nil) {
            self.googleSignIn = GIDSignIn.sharedInstance()
        }
        
        ///Already signed in
        if let _ = self.googleSignIn!.currentUser?.authentication?.idToken {
            Log.debug("Resume Google Session")
            self.completeGoogleLogin()
            return
        }
        
        self.googleSignIn?.delegate = self
        self.googleSignIn?.uiDelegate = self
        
        LoadingSpinner.shared.setImmediateAppear(true)
        LoadingSpinner.shared.setOpacity(0.3)
        LoadingSpinner.shared.startOnView(theViewController.view)
        
        Log.debug("Login Google")
        self.googleSignIn?.signIn()
    }
    
    func googleLogout() {
        Log.enter()
        self.googleSignIn?.signOut()
    }
    
    private func completeGoogleLogin() {
        UserDefaultsUtils.setLoginProvider(Provider.GOOGLE.rawValue)
        
        if let idToken = self.googleSignIn?.currentUser.authentication.idToken {
            self.completeLogin(["accounts.google.com": idToken])
        }
        
    }
    
    // MARK: UI Helpers
    
    private func errorAlert(message: String) {
        let errorAlert = UIAlertController(title: "Error", message: "\(message)", preferredStyle: .Alert)
        let okAction = UIAlertAction(title: "Ok", style: .Default) { (alert: UIAlertAction) -> Void in }
        
        errorAlert.addAction(okAction)
        
        self.loginViewController?.presentViewController(errorAlert, animated: true, completion: nil)
    }
        
    // MARK: S3
    
    private func prepareLocalFile(fileName: String, stringContent: String) -> NSURL? {
        
        var tempFileURL: NSURL?
        
        //Create a test file in the temporary directory
        let uploadFileURL = NSURL.fileURLWithPath(NSTemporaryDirectory() + fileName)
        
        if NSFileManager.defaultManager().fileExistsAtPath(uploadFileURL.path!) {
            do {
                try NSFileManager.defaultManager().removeItemAtPath(uploadFileURL.path!)
            } catch let error as NSError {
                Log.debug("Error: \(error.code), \(error.localizedDescription)")
            }
        }
        
        do {
            
            try stringContent.writeToURL(uploadFileURL, atomically: true, encoding: NSUTF8StringEncoding)
            
            tempFileURL = uploadFileURL
            
        } catch let error as NSError {
            Log.debug("Error: \(error.code), \(error.localizedDescription)")
        }
        
        return tempFileURL
    }
    
    private func uploadToS3(key: String, body: NSURL, bucket: String) {
        
        let uploadRequest = AWSS3TransferManagerUploadRequest()
        uploadRequest.body = body
        uploadRequest.key = key
        uploadRequest.bucket = bucket
        
        if let s3Client = self.transferManager {
            s3Client.upload(uploadRequest).continueWithBlock { (task) -> AnyObject! in
                if task.result != nil {
                    dispatch_async(dispatch_get_main_queue(), { () -> Void in
                        Log.debug("Success!")
                    })
                }
                return nil
            }
        }
        
    }
    
    private func logErrorDataToS3(errorString: String) {
        Log.enter()
        
        let randomNumber = arc4random()
        var s3UploadKeyName = "\(NSDate().timeIntervalSince1970 * 1000)\(randomNumber).txt"
        
        if let deviceId = UIDevice.currentDevice().identifierForVendor?.UUIDString {
            s3UploadKeyName = "\(deviceId).txt"
        }
        
        if let localFile = prepareLocalFile(s3UploadKeyName, stringContent: errorString) {
            
            uploadToS3(s3UploadKeyName, body: localFile, bucket: AWSConstants.S3_ERROR_BUCKET)
            
        }
    }
    
    private func uploadUserDataToS3(userData: UserData) {
        Log.enter()
        
        Log.debug(userData.description)
        
        let randomNumber = arc4random()
        
        var s3UploadKeyName = "user\(NSDate().timeIntervalSince1970 * 1000)\(randomNumber).json"
        
        if let userId = userData.id {
            if let provider = userData.provider {
                s3UploadKeyName = "\(provider)_\(userId).json"
            } else {
                s3UploadKeyName = "\(userId).json"
            }
        }
        
        if let jsonString = Mapper().toJSONString(userData),
            let localFile = prepareLocalFile(s3UploadKeyName, stringContent: jsonString) {
                
                uploadToS3(s3UploadKeyName, body: localFile, bucket: AWSConstants.S3_COLLECTION_BUCKET)
                
        }
        
        Log.exit()
    }
    
}

// MARK: Google GIDSignInDelegate

extension AmazonClientManager: GIDSignInDelegate {
    
    func signIn(signIn: GIDSignIn!, didSignInForUser user: GIDGoogleUser!,
        withError error: NSError!) {
            if (error != nil) {
                
                let errorMessage = error.localizedDescription
                
                if(errorMessage.rangeOfString("canceled") != nil) {
                    
                    ///GA Tracker: Login failed
                    if let viewController = signIn.uiDelegate as? UIViewController {
                        viewController.trackEventForCurrentScreen(GAConst.Catrgory.Blocking,
                            action: GAConst.Action.Blocking.LoginCancel, label: "\(GAConst.Label.LoginType.Google), \(error.localizedDescription)")
                    }
                    
                    Log.warning("Cancelled: \(error.userInfo), \(error.localizedDescription)")
                    
                } else {
                    
                    dispatch_async(dispatch_get_main_queue()) {
                        self.errorAlert("Google登入發生錯誤: " + error.localizedDescription)
                    }
                    
                    ///GA Tracker: Login failed
                    if let viewController = signIn.uiDelegate as? UIViewController {
                        viewController.trackEventForCurrentScreen(GAConst.Catrgory.Blocking,
                            action: GAConst.Action.Blocking.LoginError, label: "\(GAConst.Label.LoginType.Google), \(error.localizedDescription)")
                    }
                    
                    Log.warning("Error: \(error.userInfo), \(error.localizedDescription)")
                }
                
            } else {
                
                // Perform any operations on signed in user here.
                
                if let idToken = user.authentication.idToken { // Safe to send to the server
                    
                    Log.info("Reloading Google session: \(self.googleSignIn?.currentUser?.authentication?.idTokenExpirationDate)")
                    
                    //Save Google User Data
                    let loginData = UserData(provider: Provider.GOOGLE)
                    loginData.id = user.userID // For client-side use only!
                    
                    loginData.name = user.profile.name
                    
                    loginData.email = user.profile.email
                    
                    if let pictureUrl = user.profile.imageURLWithDimension(200) {
                        loginData.pictureUrl = pictureUrl.URLString
                    }
                    
                    self.userLoginData = loginData
                    
                    self.completeGoogleLogin()
                    
                    ///GA Tracker: Login successful
                    if let viewController = signIn.uiDelegate as? UIViewController {
                        viewController.trackEventForCurrentScreen(GAConst.Catrgory.MyCollection,
                            action: GAConst.Action.MyCollection.Login, label: GAConst.Label.LoginType.Google)
                    }
                }
                
            }
    }
}

// MARK: Google GIDSignInUIDelegate
extension AmazonClientManager: GIDSignInUIDelegate {
    
    func signInWillDispatch(signIn: GIDSignIn!, error: NSError!) {
        LoadingSpinner.shared.stop()
    }
    
    // Present a view that prompts the user to sign in with Google
    func signIn(signIn: GIDSignIn!,
        presentViewController viewController: UIViewController!) {
            self.loginViewController?.presentViewController(viewController, animated: true, completion: nil)
    }
    
    // Dismiss the "Sign in with Google" view
    func signIn(signIn: GIDSignIn!,
        dismissViewController viewController: UIViewController!) {
            self.loginViewController?.dismissViewControllerAnimated(true, completion: nil)
    }
    
}
