//
//  NotificationHouseItem+CoreDataProperties.swift
//  Zuzu
//
//  Created by Ted on 2015/12/21.
//  Copyright © 2015年 Jung-Shuo Pai. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

import Foundation
import CoreData

extension NotificationHouseItem {

    @NSManaged var isRead: Bool
    @NSManaged var notificationTime: NSDate?

}
