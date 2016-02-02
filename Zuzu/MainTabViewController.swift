//
//  MainTabViewController.swift
//  Zuzu
//
//  Created by Jung-Shuo Pai on 2015/10/3.
//  Copyright © 2015年 Jung-Shuo Pai. All rights reserved.
//

import UIKit

class MainTabViewController: UITabBarController, UITabBarControllerDelegate {
    
    struct MainTabConstants {
        static let SEARCH_TAB_INDEX = 0
        static let COLLECTION_TAB_INDEX = 1
        static let RADAR_TAB_INDEX = 2
        static let NOTIFICATION_TAB_INDEX = 3
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        AmazonClientManager.sharedInstance.resumeSession { (task) -> AnyObject! in
            dispatch_async(dispatch_get_main_queue()) {
            }
            return nil
        }
        
        let searchStoryboard:UIStoryboard = UIStoryboard(name: "SearchStoryboard", bundle: nil)
        let searchViewController:UIViewController = searchStoryboard.instantiateInitialViewController()!
        
        let collectionStoryboard:UIStoryboard = UIStoryboard(name: "MyCollectionStoryboard", bundle: nil)
        let collectionViewController:UIViewController = collectionStoryboard.instantiateInitialViewController()!
        
        let radarStoryboard:UIStoryboard = UIStoryboard(name: "RadarStoryboard", bundle: nil)
        let radarViewController:UIViewController = radarStoryboard.instantiateInitialViewController()!

        let notificationStoryboard:UIStoryboard = UIStoryboard(name: "NotificationStoryboard", bundle: nil)
        let notificationViewController:UIViewController = notificationStoryboard.instantiateInitialViewController()!
 
        var tabViewControllers = [UIViewController]()
        
        tabViewControllers.append(searchViewController)
        
        if(FeatureOption.Collection.enableMain) {
            tabViewControllers.append(collectionViewController)
        }
        
        if(FeatureOption.Radar.enableMain) {
            tabViewControllers.append(radarViewController)
            tabViewControllers.append(notificationViewController)
        }
        
        self.viewControllers = tabViewControllers
        
        self.delegate = self
        
        self.initTabBar()
        
        
        
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        //self.tabBar.hidden = true
    }
    
    func tabBarController(tabBarController: UITabBarController, shouldSelectViewController viewController: UIViewController) -> Bool {
        //NSLog("%@ tabBarController", self)
        
        
        if let sb = viewController.storyboard {
            if let name: String = sb.valueForKey("name") as? String {
                switch name {
                case "MyCollectionStoryboard":
                    fallthrough
                case "RadarStoryboard":
                    if !AmazonClientManager.sharedInstance.isLoggedIn() {
                        AmazonClientManager.sharedInstance.loginFromView(self) {
                            (task: AWSTask!) -> AnyObject! in
                            return nil
                        }
                        return false
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
            if(newValue) {
                tabBar.hidden = newValue
            } else {
                if(FeatureOption.Collection.enableMain || FeatureOption.Radar.enableMain) {
                    tabBar.hidden = newValue
                }
            }
        }
        
        get {
            return tabBar.hidden
        }
    }
    
    func initTabBar() -> Void {
        
        if(FeatureOption.Collection.enableMain || FeatureOption.Radar.enableMain) {
            tabBar.hidden = false
        } else {
            tabBar.hidden = true
        }
        
    }
}
