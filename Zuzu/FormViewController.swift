//
//  InputEmailViewController.swift
//  Zuzu
//
//Copyright © LAP Inc. All rights reserved
//

import UIKit
import SCLAlertView

enum FormMode {
    case Login
    case Register
}

class FormViewController: UIViewController {
    
    struct  Message {
        struct Login {
            static let modalTitle = "登入豬豬快租"
            
            struct Email {
                static let mainTitle = "登入帳號"
                static let subTitle = "享受更多、更好的服務"
            }
            
            struct Password {
                static let mainTitle = "歡迎你回來！"
                static let subTitle = "請輸入密碼登入"
            }
            
            struct ExistingSocial {
                static let mainTitle = "歡迎你回來！"
                static let subTitle = "帳號已經存在\n請直接使用GOOGLE 或 FACEBOOK 登入"
            }
            
            struct Existing {
                static let mainTitle = "歡迎你回來！"
                static let subTitle = "帳號已經存在，請輸入密碼登入"
            }
        }
        
        
        struct Register {
            static let modalTitle = "註冊豬豬快租"
            
            struct Email {
                static let mainTitle = "註冊新帳號"
                static let subTitle = "享受更多、更好的服務"
            }
            
            struct Password {
                static let mainTitle = "歡迎加入豬豬快租"
                static let subTitle = "為你的帳號選擇一組密碼"
            }
            
            struct NonExisting {
                static let mainTitle = "您還不是會員"
                static let subTitle = "選擇一組密碼後，立即成為會員"
            }
        }
    }
    
    private var emailFormView:EmailFormView?
    
    private var passwordFormView:PasswordFormView?
    
    private var continueSocialLoginView: ContinueSocialLoginView?
    
    private var userAccount: String?
    
    /// Passed in params
    var formMode:FormMode = .Login
    
    @IBOutlet weak var modalTitle: UILabel!
    
    @IBOutlet weak var privacyAgreementImage: UIImageView! {
        
        didSet{
            privacyAgreementImage.image = UIImage(named: "comment-check-outline")?.imageWithRenderingMode(.AlwaysTemplate)
        }
        
    }
    
    @IBOutlet weak var privacyAgreement: UILabel! {
        didSet {
            
            privacyAgreement.userInteractionEnabled = true
            let tap = UITapGestureRecognizer(target: self, action: #selector(FormViewController.onPrivacyAgreementTouched(_:)))
            privacyAgreement.addGestureRecognizer(tap)
        }
    }
    
    @IBOutlet weak var formContainerView: UIView!
    
    @IBOutlet weak var mainTitleLabel: UILabel!
    
    @IBOutlet weak var subTitleLabel: UILabel!
    
    @IBOutlet weak var backButton: UIButton!{
        didSet {
            backButton.setImage(UIImage(named: "back_arrow_n")?.imageWithRenderingMode(.AlwaysTemplate), forState: UIControlState.Normal)
            backButton.tintColor = UIColor.whiteColor()
            
            backButton.addTarget(self, action: #selector(FormViewController.onBackButtonTouched(_:)), forControlEvents: UIControlEvents.TouchDown)
        }
    }
    
    // MARK: - Private Utils
    
    private func alertRegisterFailure() {
        
        let alertView = SCLAlertView()
        
        let subTitle = "由於系統錯誤，暫時無法註冊，請您稍後再試，或者嘗試其他註冊方式，謝謝！"
        
        alertView.showInfo("註冊失敗", subTitle: subTitle, closeButtonTitle: "知道了", colorStyle: 0xFFB6C1, colorTextButton: 0xFFFFFF)
    }
    
    private func alertLoginFailure() {
        
        let alertView = SCLAlertView()
        
        let subTitle = "由於系統錯誤，暫時無法登入，請您稍後再試，或者嘗試其他登入方式，謝謝！"
        
        alertView.showInfo("登入失敗", subTitle: subTitle, closeButtonTitle: "知道了", colorStyle: 0xFFB6C1, colorTextButton: 0xFFFFFF)
    }
    
    private func setupUIForLogin() {
        self.modalTitle.text = Message.Login.modalTitle
        self.mainTitleLabel.text = Message.Login.Email.mainTitle
        self.subTitleLabel.text = Message.Login.Email.subTitle
        
        emailFormView = EmailFormView(frame: self.formContainerView.bounds)
        emailFormView?.delegate = self
        
        if let emailFormView = emailFormView {
            emailFormView.formMode = .Login
            emailFormView.autoresizingMask = UIViewAutoresizing.FlexibleWidth.union(UIViewAutoresizing.FlexibleHeight)
            self.formContainerView.addSubview(emailFormView)
        }
    }
    
    private func registerToLogin() {
        
        self.formMode = .Login
        
        self.modalTitle.text = Message.Login.modalTitle
        self.mainTitleLabel.text = Message.Login.Existing.mainTitle
        self.subTitleLabel.text = Message.Login.Existing.subTitle
        
        emailFormView?.removeFromSuperview()
        
        passwordFormView = PasswordFormView(formMode: .Login, frame: self.formContainerView.bounds)
        passwordFormView?.delegate = self
        
        if let passwordFormView = passwordFormView{
            passwordFormView.autoresizingMask = UIViewAutoresizing.FlexibleWidth.union(UIViewAutoresizing.FlexibleHeight)
            self.formContainerView.addSubview(passwordFormView)
        }
    }
    
    private func continueLogin() {
        self.modalTitle.text = Message.Login.modalTitle
        self.mainTitleLabel.text = Message.Login.Password.mainTitle
        self.subTitleLabel.text = Message.Login.Password.subTitle
        
        emailFormView?.removeFromSuperview()
        
        passwordFormView = PasswordFormView(formMode: .Login, frame: self.formContainerView.bounds)
        passwordFormView?.delegate = self
        
        if let passwordFormView = passwordFormView{
            passwordFormView.autoresizingMask = UIViewAutoresizing.FlexibleWidth.union(UIViewAutoresizing.FlexibleHeight)
            self.formContainerView.addSubview(passwordFormView)
        }
    }
    
    private func setupUIForRegister() {
        self.modalTitle.text = Message.Register.modalTitle
        self.mainTitleLabel.text = Message.Register.Email.mainTitle
        self.subTitleLabel.text = Message.Register.Email.subTitle
        
        emailFormView = EmailFormView(frame: self.formContainerView.bounds)
        emailFormView?.delegate = self
        
        if let emailFormView = emailFormView {
            emailFormView.formMode = .Register
            emailFormView.autoresizingMask = UIViewAutoresizing.FlexibleWidth.union(UIViewAutoresizing.FlexibleHeight)
            self.formContainerView.addSubview(emailFormView)
        }
    }
    
    private func loginToRegister() {
        
        self.formMode = .Register
        
        self.modalTitle.text = Message.Register.modalTitle
        self.mainTitleLabel.text = Message.Register.NonExisting.mainTitle
        self.subTitleLabel.text = Message.Register.NonExisting.subTitle
        
        emailFormView?.removeFromSuperview()
        
        passwordFormView = PasswordFormView(formMode: .Register, frame: self.formContainerView.bounds)
        passwordFormView?.delegate = self
        
        if let passwordFormView = passwordFormView{
            passwordFormView.autoresizingMask = UIViewAutoresizing.FlexibleWidth.union(UIViewAutoresizing.FlexibleHeight)
            self.formContainerView.addSubview(passwordFormView)
        }
        
    }
    
    private func continueRegister() {
        self.modalTitle.text = Message.Register.modalTitle
        self.mainTitleLabel.text = Message.Register.Password.mainTitle
        self.subTitleLabel.text = Message.Register.Password.subTitle
        
        emailFormView?.removeFromSuperview()
        
        passwordFormView = PasswordFormView(formMode: .Register, frame: self.formContainerView.bounds)
        passwordFormView?.delegate = self
        
        if let passwordFormView = passwordFormView{
            passwordFormView.autoresizingMask = UIViewAutoresizing.FlexibleWidth.union(UIViewAutoresizing.FlexibleHeight)
            self.formContainerView.addSubview(passwordFormView)
        }
    }
    
    private func continueSocialLogin() {
        self.modalTitle.text = Message.Login.modalTitle
        self.mainTitleLabel.text = Message.Login.ExistingSocial.mainTitle
        self.subTitleLabel.text = Message.Login.ExistingSocial.subTitle
        
        emailFormView?.removeFromSuperview()
        
        continueSocialLoginView = ContinueSocialLoginView(frame: self.formContainerView.bounds)
        continueSocialLoginView?.delegate = self
        
        if let continueSocialLoginView = continueSocialLoginView {
            continueSocialLoginView.formMode = .Register
            continueSocialLoginView.autoresizingMask = UIViewAutoresizing.FlexibleWidth.union(UIViewAutoresizing.FlexibleHeight)
            self.formContainerView.addSubview(continueSocialLoginView)
        }
    }
    
    // MARK: - Action Handlers
    func onBackButtonTouched(sender: UIButton) {
        
        self.dismissViewControllerAnimated(true) { () -> Void in
        }
        
    }
    
    func onPrivacyAgreementTouched(sender:UITapGestureRecognizer) {
        
        let privacyUrl = "https://zuzurentals.wordpress.com/zuzu-rentals-privacy-policy/"
        
        ///Open by Facebook App
        if let url = NSURL(string: privacyUrl) {
            
            if (UIApplication.sharedApplication().canOpenURL(url)) {
                
                UIApplication.sharedApplication().openURL(url)
                
            }
        }
        
        
    }
    
    // MARK: - View Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        switch(self.formMode) {
        case .Login:
            setupUIForLogin()
        case .Register:
            setupUIForRegister()
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
}

// MARK: - EmailFormDelegate
extension FormViewController: EmailFormDelegate {
    
    func onEmailEntered(email:String?) {
        
        LoadingSpinner.shared.setDimBackground(true)
        LoadingSpinner.shared.setGraceTime(0.6)
        LoadingSpinner.shared.setMinShowTime(1.0)
        LoadingSpinner.shared.setOpacity(0.8)
        LoadingSpinner.shared.setText("處理中")
        LoadingSpinner.shared.startOnView(self.view)
        
        // Check user type
        if let email = email {
            
            self.userAccount = email
            
            ZuzuWebService.sharedInstance.checkEmail(email) { (emailExisted, provider, error) in
                
                LoadingSpinner.shared.stop()
                
                if let _ = error {
                    
                    switch(self.formMode) {
                    case .Login:
                        self.alertLoginFailure()
                    case .Register:
                        self.alertRegisterFailure()
                    }
                    
                    return
                }
                
                if(emailExisted) {
                    
                    if let provider = provider where provider != Provider.ZUZU.rawValue {
                        
                        // Existing socail login user
                        self.continueSocialLogin()
                        
                    } else {
                        
                        switch(self.formMode) {
                        case .Login:
                            self.continueLogin()
                        case .Register:
                            /// Go to login with custom message
                            self.registerToLogin()
                        }
                        
                    }
                    
                } else {
                    
                    switch(self.formMode) {
                    case .Login:
                        /// Go to register with custom message
                        self.loginToRegister()
                    case .Register:
                        self.continueRegister()
                    }
                }
            }
        }
        
        // Existing login user
        
        
        // New user
        
    }
}

// MARK: - PasswordFormDelegate
extension FormViewController: PasswordFormDelegate {
    
    func onPasswordEntered(password:String?) {
        
        switch(self.formMode) {
        case .Login:
            break
        //self.continueLogin()
        case .Register:
            
            let user = ZuzuUser()
            user.email = self.userAccount
            
            LoadingSpinner.shared.setDimBackground(true)
            LoadingSpinner.shared.setImmediateAppear(true)
            LoadingSpinner.shared.setOpacity(0.8)
            LoadingSpinner.shared.setText("註冊中")
            LoadingSpinner.shared.startOnView(self.view)
            
            if let password = password, email = user.email {
                ZuzuWebService.sharedInstance.registerUser(user, password: password, handler: { (userId, error) in
                    
                    if let _ = error {
                        
                        LoadingSpinner.shared.stop()
                        
                        self.alertRegisterFailure()
                        
                        return
                    }
                    
                    LoadingSpinner.shared.setText("登入中")
                    
                    ZuzuWebService.sharedInstance.loginByEmail(email, password: password, handler: { (userToken, error) in
                        
                        LoadingSpinner.shared.stop()
                        
                        // Finish register
                        dismissModalStack(self, animated: true, completionBlock: nil)
                    })
                    
                })
            }
        }
    }
}

// MARK: - SocialLoginDelegate
extension FormViewController: SocialLoginDelegate {
    
    func onContinue() {
        
        /// Back to common login form
        self.dismissViewControllerAnimated(true) { () -> Void in
        }
    }
}


func dismissModalStack(viewController: UIViewController, animated: Bool, completionBlock: (() -> Void)?) {
    if viewController.presentingViewController != nil {
        var vc = viewController.presentingViewController!
        while (vc.presentingViewController != nil) {
            vc = vc.presentingViewController!
        }
        vc.dismissViewControllerAnimated(animated, completion: nil)
        
        if let c = completionBlock {
            c()
        }
    }
}


