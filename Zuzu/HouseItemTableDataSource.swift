//
//  TableDataSource.swift
//  Zuzu
//
//  Created by Jung-Shuo Pai on 2015/10/8.
//  Copyright © 2015年 Jung-Shuo Pai. All rights reserved.
//

import Foundation


//
//  LazyDataSource.swift
//  Zuzu
//
//  Created by Jung-Shuo Pai on 2015/9/29.
//  Copyright © 2015年 Jung-Shuo Pai. All rights reserved.
//

import Foundation

/**
The class is developed in a rush, need to refactor to a more common module

1) highly coupled with other modules, can not work as standalone library
2) It might block UI a little bit when loading data from storage
*/

private let Log = Logger.defaultLogger

public class HouseItemTableDataSource {
    
    struct Const {
        static let adDisplayPageInterval = 2
        static let savePagePrefix = "page"
        static let startPage = 1
        static let pageSize = 10
    }
    
    var debugStr: String {
        
        get {
            let pageInfo = "Total Result: \(estimatedTotalResults)\n"
                + "Items Per Page: \(Const.pageSize)\n"
                + "Last Page No: \(self.currentPage)\n"
                + "Total Items in Table: \(self.getSize())\n"
            
            
            
            let criteriaInfo = "\n[Criteria]\n"
                + "<Keyword>: \(self.criteria?.keyword)\n"
                + "<Type>: \(self.criteria?.types)\n"
                + "<Price>: \(self.criteria?.price)\n"
                + "<Size>: \(self.criteria?.size)\n"
            //                + "<City>: \(self.criteria?)\n"
            //                + "<Region>: \(self.criteria?.size)\n"
            
            
            let host = HouseDataRequester.getInstance().urlComp.host ?? ""
            let port = HouseDataRequester.getInstance().urlComp.port ?? 0
            let path = HouseDataRequester.getInstance().urlComp.path ?? ""
            let query = HouseDataRequester.getInstance().urlComp.query ?? ""
            
            let queryInfo = "\n[Last HTTP Request]\n"
                + "<Host>: \n\(host) \n"
                + "<Port>: \(port) \n"
                + "<Path>: \(path) \n"
                + "<Query>: \n\(query) \n"
            
            let urlInfo = "\n[Full URL]\n"
                + "\(HouseDataRequester.getInstance().urlComp.URL ?? nil)"
            
            return pageInfo + criteriaInfo + queryInfo + urlInfo
        }
    }
    
    var criteria:SearchCriteria?
    private var loadStartTime: NSDate?
    var loadingDuration: Double?
    
    private var isLoadingData = false
    
    //Paging Info
    var currentPage: Int {
        
        get {
            return calculateNumOfPages(cachedData.count)
        }
        
    }
    
    var isDisplayADs: Bool = true
    
    //Total Number of items
    var estimatedTotalResults:Int = 0
    
    //Cache Data
    private var cachedData = [HouseItem]()
    
    private var onDataLoaded: ((dataSource: HouseItemTableDataSource, pageNo:Int, error: NSError?) -> Void)?
    
    // Designated initializer
    public init() {
        
        // A/B Testing flags
        if let tagContainer = AppDelegate.tagContainer {
            let showADString = tagContainer.stringForKey(TagConst.showADs)
            
            Log.debug("Tag Container = \(tagContainer.containerId), isDefault = \(tagContainer.isDefault()), showADString = \(showADString)")
            
            if(showADString == "y") {
                
                isDisplayADs = true
                
            } else if(showADString == "n"){
                
                isDisplayADs = false
                
            } else {
                
                Log.debug("Tag Container = \(tagContainer.containerId), No Value for Key: \(TagConst.showADs)")
            }
            
        }
    }
    
    //** MARK: - APIs
    
    //Load some pages for display
    func initData(){
        //Remove previous data for initial data fetching
        cachedData.removeAll()
        
        loadStartTime = NSDate()
        loadRemoteData(Const.startPage)
    }
    
    func getItemForRow(row:Int) -> HouseItem{
        if(row > 0 && row < cachedData.count) {
            return cachedData[row] //index within memory cache
        } else {
            assert(false, "Cannot access house item: \(row). Total count: \(cachedData.count)")
        }
    }
    
    func getSize() -> Int{
        return cachedData.count
    }
    
    func loadDataForPage(pageNo: Int) {
        if(isLoadingData) {
            Log.debug("loadDataForPage: Duplicate page request for [\(pageNo)]")
            return
        }
        
        loadStartTime = NSDate()
        loadRemoteData(pageNo)
    }
    
    func setDataLoadedHandler(handler: (dataSource: HouseItemTableDataSource, pageNo:Int, error: NSError?) -> Void) {
        onDataLoaded = handler
    }
    
    //** MARK: - Callback Functions
    
    func appendDataForPage(pageNo:Int, data: [HouseItem]) -> Void {
        
        cachedData.appendContentsOf(data)
    }
    
    
    //** MARK: - Private Functions
    
    private func loadRemoteData(pageNo:Int){
        let requester = HouseDataRequester.getInstance()
        let start = getStartIndexFromPageNo(pageNo)
        var row = Const.pageSize
        
        ///Check if need to add an Ad item
        
        if(self.isDisplayADs) {
            if(pageNo % Const.adDisplayPageInterval == 0) {
                row -= 1 // Leave 1 for Ad
            }
        }
        
        if criteria == nil {
            return
        }
        
        isLoadingData = true
        
        Log.debug("loadRemoteData: pageNo = \(pageNo)")
        
        requester.searchByCriteria(criteria!, start: start, row: row) { (totalNum, result, facetResult, error) -> Void in
            
            if let result = result {
                self.appendDataForPage(pageNo, data: result)
                
                /// Add ADs when there is some data
                if(result.count > 0) {
                    ///Check if need to add an Ad item
                    if(self.isDisplayADs) {
                        if(pageNo % Const.adDisplayPageInterval == 0) {
                            //Time to add one Ad cell
                            let adItem = HouseItem.Builder(id: "Ad").addTitle("").addPrice(0).addSize(0).build()
                            
                            let lastIndex = self.cachedData.endIndex - 1
                            self.cachedData.insert(adItem, atIndex: lastIndex)
                        }
                    }
                    
                }
            }
            
            self.estimatedTotalResults = totalNum
            
            if let loadStartTime = self.loadStartTime {
                let loadEndTime = NSDate()
                self.loadingDuration = loadEndTime.timeIntervalSinceDate(loadStartTime)
            }
            
            //Callback to table
            self.onDataLoaded!(dataSource: self, pageNo: pageNo, error: error)
            
            self.isLoadingData = false
        }
        
    }
    
    private func getStartIndexFromPageNo(pageNo: Int) -> Int{
        assert(pageNo > 0, "pageNo should start at 1")
        
        return (pageNo - 1) * Const.pageSize
    }
    
    private func calculateNumOfPages(numOfItems:Int) -> Int{
        return Int(ceil(Double(numOfItems) / Double(Const.pageSize)))
    }
    
}