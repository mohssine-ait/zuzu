//
//  MainTabViewController.swift
//  Zuzu
//
//  Created by Jung-Shuo Pai on 2015/10/3.
//  Copyright © 2015年 Jung-Shuo Pai. All rights reserved.
//

import UIKit

class MainTabViewController: UITabBarController, UITabBarControllerDelegate {
    
    func configureAmazon() {
        if AmazonClientManager.sharedInstance.isConfigured() {
            UIApplication.sharedApplication().networkActivityIndicatorVisible = true
            
            AmazonClientManager.sharedInstance.resumeSession {
                (task) -> AnyObject! in
                dispatch_async(dispatch_get_main_queue()) {
                    UIApplication.sharedApplication().networkActivityIndicatorVisible = false
                }
                return nil
            }
        } else {
            let missingConfigAlert = UIAlertController(title: "Missing Configuration", message: "Please check Constants.swift and set appropriate values", preferredStyle: .Alert)
            missingConfigAlert.addAction(UIAlertAction(title: "Ok", style: .Default, handler: nil))
            self.presentViewController(missingConfigAlert, animated: true, completion: nil)
        }

    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.configureAmazon()
        
        let searchStoryboard:UIStoryboard = UIStoryboard(name: "SearchStoryboard", bundle: nil)
        let searchViewController:UIViewController = searchStoryboard.instantiateInitialViewController()!
        
        let collectionStoryboard:UIStoryboard = UIStoryboard(name: "MyCollectionStoryboard", bundle: nil)
        let collectionViewController:UIViewController = collectionStoryboard.instantiateInitialViewController()!
        
        let radarStoryboard:UIStoryboard = UIStoryboard(name: "RadarStoryboard", bundle: nil)
        let radarViewController:UIViewController = radarStoryboard.instantiateInitialViewController()!
        
        
        var tabViewControllers = [UIViewController]()
        
        tabViewControllers.append(searchViewController)
        
        if(FeatureOption.Collection.enableMain) {
            tabViewControllers.append(collectionViewController)
        }
        
        if(FeatureOption.Radar.enableMain) {
            tabViewControllers.append(radarViewController)
        }
        
        self.viewControllers = tabViewControllers
        
        self.delegate = self
        
        self.tabBar.hidden = true
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        self.tabBar.hidden = true
    }
    
    func tabBarController(tabBarController: UITabBarController, shouldSelectViewController viewController: UIViewController) -> Bool {
        NSLog("%@ tabBarController", self)
        
        if let sb = viewController.storyboard {
            if let name: String = sb.valueForKey("name") as? String {
                switch name {
                case "MyCollectionStoryboard":
                    
                    UIApplication.sharedApplication().networkActivityIndicatorVisible = true
                    
                    if !AmazonClientManager.sharedInstance.isLoggedIn() {
                        
                        AmazonClientManager.sharedInstance.loginFromView(self) {
                            (task: AWSTask!) -> AnyObject! in
                            dispatch_async(dispatch_get_main_queue()) {
                                UIApplication.sharedApplication().networkActivityIndicatorVisible = false
                            }
                            return nil
                        }
                        
                    }
                    
                default: break
                }
            }
        }
        return true
    }
    
}

extension UITabBarController {
    
    var tabBarHidden: Bool {
        
        set {
            if(FeatureOption.Collection.enableMain || FeatureOption.Radar.enableMain) {
                tabBar.hidden = newValue
            } else {
                tabBar.hidden = true
            }
        }
        
        get {
            return tabBar.hidden
        }
    }
}
