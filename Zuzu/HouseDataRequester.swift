//
//  HouseDataRequester.swift
//  Zuzu
//
//  Created by Jung-Shuo Pai on 2015/9/22.
//  Copyright © 2015年 Jung-Shuo Pai. All rights reserved.
//

import Foundation

struct SolrConst {
    struct Server {
        static let SCHEME = "http"
        static let HOST = "ec2-52-76-69-228.ap-southeast-1.compute.amazonaws.com"
        static let PORT = 8983
        static let PATH = "/solr/rhc/select"
    }
    
    struct Query {
        static let MAIN_QUERY = "q"
        static let FILTER_QUERY = "fq"
        static let WRITER_TYPE = "wt"
        static let INDENT = "indent"
        static let START = "start"
        static let ROW = "rows"
    }
    
    struct Filed {
        static let CITY = "city"
        static let REGION = "region"
        static let TYPE = "purpose_type"
        static let PRICE = "price"
        static let SIZE = "size"
    }
    
}

class HouseItem:NSObject, NSCoding {
    
    let id: String
    var title: String
    let price: Int
    let desc: String
    let imgList: [String]?
    
    required init(id: String, title: String, price: Int, desc: String, imgList: [String]?){
        self.id = id
        self.title = title
        self.price = price
        self.desc = desc
        self.imgList = imgList
        super.init()
    }
    
    required convenience init?(coder decoder: NSCoder) {
        
        let id  = decoder.decodeObjectForKey("id") as? String
        let title = decoder.decodeObjectForKey("title") as? String
        let price = decoder.decodeIntegerForKey("price") as Int
        let desc = decoder.decodeObjectForKey("desc") as? String
        let imgList = decoder.decodeObjectForKey("imgList") as? [String]
        
        self.init(
            id: id!,
            title: title!,
            price: price,
            desc: desc!,
            imgList: imgList
        )
    }
    
    func encodeWithCoder(aCoder: NSCoder) {
        aCoder.encodeObject(id, forKey:"id")
        aCoder.encodeObject(title, forKey:"title")
        aCoder.encodeInteger(price, forKey:"price")
        aCoder.encodeObject(desc, forKey:"desc")
        aCoder.encodeObject(imgList, forKey:"imgList")
    }
    
}

public class HouseDataRequester: NSObject, NSURLConnectionDelegate {
    
    private static let requestTimeout = 15.0
    private static let instance = HouseDataRequester()
    
    let urlComp = NSURLComponents()
    var numOfRecord: Int?
    
    public static func getInstance() -> HouseDataRequester{
        return instance
    }
    
    // designated initializer
    public override init() {
        super.init()
        
        urlComp.scheme = SolrConst.Server.SCHEME
        urlComp.host = SolrConst.Server.HOST
        urlComp.port = SolrConst.Server.PORT
        urlComp.path = SolrConst.Server.PATH
    }
    
    func searchByCriteria(keyword: String?,
        area: [City]?,
        price: (Int, Int)?,
        size: (Int, Int)?,
        types: [Int]?,
        start: Int,
        row: Int,
        handler: (totalNum: Int?, result: [HouseItem], error: NSError?) -> Void) {
            
            var queryitems:[NSURLQueryItem] = []
            var mainQueryStr:String = "*:*"
            
            // Add query string
            if let keywordStr = keyword{
                if(keywordStr.characters.count > 0) {
                    let escapedStr = StringUtils.escapeForSolrString(keywordStr)
                    mainQueryStr = "title:\(escapedStr) OR desc:\(escapedStr)"
                }
            }
            
            // Region
            if let selectedCity = area {
                
                var areaConditionStr: [String] = [String]()
                
                let allCities = selectedCity.filter({ (city: City) -> Bool in
                    return city.regions.contains(Region.allRegions)
                })
                
                if(allCities.count > 0) {
                    let allCitiesStr = allCities.map({ (city) -> String in
                        return "\(city.code)"
                    }).joinWithSeparator(" OR ")
                    
                    areaConditionStr.append("\(SolrConst.Filed.CITY):(\(allCitiesStr))")
                }
                
                
                let allRegions = selectedCity.filter({ (city: City) -> Bool in
                    return !city.regions.contains(Region.allRegions)
                })
                
                if(allRegions.count > 0) {
                    let allRegionsStr = allRegions.map({ (region) -> String in
                        return "\(region.code)"
                    }).joinWithSeparator(" OR ")
                    
                    areaConditionStr.append("\(SolrConst.Filed.REGION):(\(allRegionsStr))")
                }
                
                queryitems.append( NSURLQueryItem(
                    name: SolrConst.Query.FILTER_QUERY,
                    value:areaConditionStr.joinWithSeparator(" OR "))
                )
            }
            
            // Purpose Type
            if let typeList = types {
                
                for (index, type) in typeList.enumerate() {
                    if(index == 0) {
                        mainQueryStr += " AND \(SolrConst.Filed.TYPE):( \(type)"
                    } else {
                        mainQueryStr += " OR \(type)"
                    }
                    
                    if(index == typeList.count - 1) {
                        mainQueryStr += " )"
                    }
                }
                
            }
            
            queryitems.append(NSURLQueryItem(name: SolrConst.Query.MAIN_QUERY, value: mainQueryStr))
            
            // Price
            if let priceRange = price {
                
                var priceFrom = "\(priceRange.0)"
                var priceTo = "\(priceRange.1)"
                
                if(priceRange.0 == CriteriaConst.Bound.LOWER_ANY) {
                    priceFrom = "*"
                } else if(priceRange.1 == CriteriaConst.Bound.UPPER_ANY) {
                    priceTo = "*"
                }
                
                queryitems.append(
                    NSURLQueryItem(name: SolrConst.Query.FILTER_QUERY, value: "\(SolrConst.Filed.PRICE):[\(priceFrom) TO \(priceTo)]"))
            }
            
            // Size
            if let sizeRange = size {
                
                var sizeFrom = "\(sizeRange.0)"
                var sizeTo = "\(sizeRange.1)"
                
                if(sizeRange.0 == CriteriaConst.Bound.LOWER_ANY) {
                    sizeFrom = "*"
                } else if(sizeRange.1 == CriteriaConst.Bound.UPPER_ANY) {
                    sizeTo = "*"
                }
                
                queryitems.append(
                    NSURLQueryItem(name: SolrConst.Query.FILTER_QUERY, value: "\(SolrConst.Filed.SIZE):[\(sizeFrom) TO \(sizeTo)]"))
            }
            
            queryitems.append(NSURLQueryItem(name: SolrConst.Query.WRITER_TYPE, value: "json"))
            queryitems.append(NSURLQueryItem(name: SolrConst.Query.INDENT, value: "true"))
            queryitems.append(NSURLQueryItem(name: SolrConst.Query.START, value: "\(start)"))
            queryitems.append(NSURLQueryItem(name: SolrConst.Query.ROW, value: "\(row)"))
            
            urlComp.queryItems = queryitems
            
            performSearch(urlComp, handler: handler)
    }
    
    private func performSearch(urlComp: NSURLComponents,
        handler: (totalNum: Int?, result: [HouseItem], error: NSError?) -> Void){
            
            var houseList = [HouseItem]()
            
            if let fullURL = urlComp.URL {
                
                print("fullURL: \(fullURL.absoluteString)")
                
                let request = NSMutableURLRequest(URL: fullURL)
                request.timeoutInterval = HouseDataRequester.requestTimeout
                
                request.HTTPMethod = "GET"
                
                NSURLConnection.sendAsynchronousRequest(
                    request, queue: NSOperationQueue.mainQueue()){
                        (response: NSURLResponse?, data: NSData?, error: NSError?) -> Void in
                        do {
                            if(error != nil){
                                NSLog("HTTP request error = %ld, desc = %@", error!.code, error!.localizedDescription)
                                handler(totalNum: 0, result: houseList, error: error)
                                return
                            }
                            
                            if(data == nil) {
                                NSLog("HTTP no data")
                                return
                            }
                            
                            let jsonResult = try NSJSONSerialization.JSONObjectWithData(data!, options: NSJSONReadingOptions.MutableContainers) as! Dictionary<String, AnyObject>
                            
                            //NSLog("\(jsonResult)")
                            
                            if let response = jsonResult["response"] as? Dictionary<String, AnyObject> {
                                let itemList = response["docs"] as! Array<Dictionary<String, AnyObject>>
                                
                                self.numOfRecord = response["numFound"] as? Int
                                
                                for house in itemList {
                                    let id = house["id"]  as! String
                                    let title = house["title"] as! String
                                    let price = house["price"] as? Int ?? 0
                                    let desc = (house["desc"]  as? String ?? "")
                                    let imgList = house["img"] as? [String]
                                    
                                    NSLog("houseItem: \(id)")
                                    
                                    houseList.append(HouseItem(id: id, title: title, price: price, desc: desc, imgList: imgList))
                                }
                                
                                handler(totalNum: self.numOfRecord, result: houseList, error: nil)
                            } else {
                                assert(false, "Solr response error:\n \(jsonResult)")
                            }
                            
                        }catch let error as NSError{
                            handler(totalNum: 0, result: houseList, error: error)
                            NSLog("JSON parsing error = \(error)")
                        }
                }
                
            }
    }
}