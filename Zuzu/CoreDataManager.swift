//
//  CoreDataManager.swift
//  Zuzu
//
//  Created by eechih on 2015/10/21.
//  Copyright © 2015年 Jung-Shuo Pai. All rights reserved.
//

import Foundation
import CoreData

private let Log = Logger.defaultLogger

class CoreDataManager: NSObject {

    let storeName="dev-zuzu01.sqlite"
    let dataModelName="Model"

    var _managedObjectContext: NSManagedObjectContext?=nil
    var _managedObjectModel: NSManagedObjectModel?=nil
    var _persistentStoreCoordinator: NSPersistentStoreCoordinator?=nil

    class var shared: CoreDataManager {
        get {
            struct Static {
                static var instance: CoreDataManager?=nil
                static var token: dispatch_once_t = 0

            }

            dispatch_once(&Static.token) {
                Static.instance=CoreDataManager()
            }
            return Static.instance!
        }
    }

    var managedObjectContext: NSManagedObjectContext {
        if NSThread.isMainThread() {
            if !(_managedObjectContext != nil) {
                let coordinator = self.persistentStoreCoordinator
                if coordinator != NSNull() {
                    _managedObjectContext=NSManagedObjectContext(concurrencyType: NSManagedObjectContextConcurrencyType.MainQueueConcurrencyType)
                    _managedObjectContext!.persistentStoreCoordinator=coordinator
                }
                return _managedObjectContext!
            }

        } else {
            var threadContext: NSManagedObjectContext?=NSThread.currentThread().threadDictionary["NSManagedObjectContext"] as? NSManagedObjectContext
            if threadContext==nil {

                threadContext = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
                threadContext!.parentContext = _managedObjectContext
                threadContext!.name=NSThread.currentThread().description
                NSThread.currentThread().threadDictionary["NSManagedObjectContext"] = threadContext

                NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(CoreDataManager.contextWillSave(_:)), name: NSManagedObjectContextWillSaveNotification, object: threadContext)


            } else {
                Log.debug("using old context")
            }
            return threadContext!


        }
        return _managedObjectContext!
    }

    // Returns the managed object model for the application.
    // If the model doesn't already exist, it is created from the application's model.
    var managedObjectModel: NSManagedObjectModel {

        if !(_managedObjectModel != nil) {
            let modelURL=NSBundle.mainBundle().URLForResource(dataModelName, withExtension: "momd")
            _managedObjectModel=NSManagedObjectModel(contentsOfURL: modelURL!)
        }
        return _managedObjectModel!
    }


    var persistentStoreCoordinator: NSPersistentStoreCoordinator {

        if !(_persistentStoreCoordinator != nil) {
            let storeURL=self.applicationDocumentsDirectory.URLByAppendingPathComponent(storeName)
            //var error:NSError?=nil
            _persistentStoreCoordinator=NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)

            do {
                try _persistentStoreCoordinator!.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: storeURL, options: self.databaseOptions())
            } catch _ as NSError {

                do {
                    try NSFileManager.defaultManager().removeItemAtPath(storeURL.path!)
                    let journalSHMURL = self.applicationDocumentsDirectory.URLByAppendingPathComponent("\(storeName)-shm")
                    try NSFileManager.defaultManager().removeItemAtPath(journalSHMURL.path!)
                    let journalWALURL = self.applicationDocumentsDirectory.URLByAppendingPathComponent("\(storeName)-wal")
                    try NSFileManager.defaultManager().removeItemAtPath(journalWALURL.path!)
                } catch {
                    Log.debug("remove store file error")
                }

                do {
                    try _persistentStoreCoordinator!.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: storeURL, options: self.databaseOptions())
                } catch _ as NSError {
                    //error = error1
                    if(FeatureOption.Collection.enableMain) {
                        abort()
                    } else {
                        Log.debug("\(self) [Core Data] persistentStoreCoordinator error")
                    }
                }
            }
        }
        return _persistentStoreCoordinator!
    }


    // #pragma mark - fetches

    func countForFetchRequest(request: NSFetchRequest) -> Int {
        var count: Int = 0
        self.managedObjectContext.performBlockAndWait {
            var fetchError: NSError?
            count = self.managedObjectContext.countForFetchRequest(request, error: &fetchError)
            if let error = fetchError {
                Log.debug("Warning!! \(error.description)")
            }
        }
        return count
    }

    func executeFetchRequest(request: NSFetchRequest)->Array<AnyObject>? {
        var results: Array<AnyObject>?
        self.managedObjectContext.performBlockAndWait {
            var fetchError: NSError?

            do {
                results=try self.managedObjectContext.executeFetchRequest(request)
            } catch let error as NSError {
                fetchError = error
                results = nil
            } catch {
                fatalError()
            }
            if let error=fetchError {
                Log.debug("Warning!! \(error.description)")
            }
        }
        return results
    }

    func executeFetchRequest(request: NSFetchRequest, completionHandler:(results: Array<AnyObject>?) -> Void) {

        self.managedObjectContext.performBlock() {
            var fetchError: NSError?
            var results: Array<AnyObject>?

            do {
                results=try self.managedObjectContext.executeFetchRequest(request)
            } catch let error as NSError {
                fetchError = error
                results = nil
            } catch {
                fatalError()
            }
            if let error=fetchError {
                Log.debug("Warning!! \(error.description)")
            }

            completionHandler(results: results)

        }
    }

    func save() {
        let context: NSManagedObjectContext = self.managedObjectContext
        if context.hasChanges {
            context.performBlock {

                var saveError: NSError?
                let saved: Bool
                do {
                    try context.save()
                    saved = true
                } catch let error as NSError {
                    saveError = error
                    saved = false
                } catch {
                    fatalError()
                }
                if !saved {
                    if let error = saveError {
                        Log.debug("Warning!! Saving error \(error.description)")
                    }
                }

                if (context.parentContext != nil) {
                    context.parentContext!.performBlockAndWait {
                        var saveError: NSError?
                        let saved: Bool
                        do {
                            try context.parentContext!.save()
                            saved = true
                        } catch let error as NSError {
                            saveError = error
                            saved = false
                        } catch {
                            fatalError()
                        }

                        if !saved {
                            if let error = saveError {
                                Log.debug("Warning!! Saving parent error \(error.description)")
                            }
                        }
                    }
                }

            }
        }

    }


    func contextWillSave(notification: NSNotification) {
        let context: NSManagedObjectContext! = notification.object as! NSManagedObjectContext
        let insertedObjects: NSSet = context.insertedObjects

        if insertedObjects.count != 0 {
            var obtainError: NSError?



            do {
                try context.obtainPermanentIDsForObjects(insertedObjects.allObjects as! [NSManagedObject])

            } catch let error as NSError {
                obtainError = error
            }

            if let error = obtainError {
                Log.debug("Warning!! obtaining ids error \(error.description)")
            }
        }
    }

    func deleteEntity(object: NSManagedObject) {


        object.managedObjectContext?.deleteObject(object)
    }

    func deleteTable(tableName: String) {
        let managedObjectContext=self.managedObjectContext
        let entity=NSEntityDescription.entityForName(tableName, inManagedObjectContext: managedObjectContext)
        let request=NSFetchRequest()
        request.includesPropertyValues=false
        request.entity=entity

        let items=self.executeFetchRequest(request)
        if (items != nil&&items!.count>0) {
            for obj in items! {
                let item = obj as! NSManagedObject
                self.deleteEntity(item)
            }

            self.save()
        }
    }





    // #pragma mark - Application's Documents directory

    // Returns the URL to the application's Documents directory.
    var applicationDocumentsDirectory: NSURL {
        let urls = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)

        //  println(urls[urls.endIndex-1] as NSURL)

        return urls[urls.endIndex-1]
    }

    func databaseOptions() -> Dictionary <String, Bool> {
        var options =  Dictionary<String, Bool>()
        options[NSMigratePersistentStoresAutomaticallyOption] = true
        options[NSInferMappingModelAutomaticallyOption] = true
        return options
    }


}


extension CoreDataManager {

    func get(identifier: NSManagedObjectID) -> AnyObject? {
        return self.managedObjectContext.objectRegisteredForID(identifier)
    }

}
