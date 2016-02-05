//
//  RadarCriteria.swift
//  Zuzu
//
//  Created by eechih on 2/2/16.
//  Copyright © 2016 Jung-Shuo Pai. All rights reserved.
//
import Foundation
import ObjectMapper
import SwiftyJSON


private let Log = Logger.defaultLogger

class ZuzuCriteria: NSObject, Mappable {
    
    var userId: String?
    var criteriaId: String?
    var enabled: Bool?
    var expireTime: NSDate?
    var appleProductId: String?
    var criteria: SearchCriteria?
    
    override init() {
    }
    
    required init?(_ map: Map) {
        
    }
    
    // Mappable
    func mapping(map: Map) {
        userId              <-  map["user_id"]
        criteriaId          <-  map["criteria_id"]
        enabled             <-  map["enabled"]
        expireTime          <-  map["expire_time"]
        appleProductId      <-  map["apple_product_id"]
        criteria            <- (map["filters"], criteriaTransform)
    }
    
    
    
    // MARK - Transforms
    
    //
    let criteriaTransform = TransformOf<SearchCriteria, [String: AnyObject]>(fromJSON: { (values: [String: AnyObject]?) -> SearchCriteria? in
            return ZuzuCriteria.criteriaFromJSON(values)
        }, toJSON: { (values: SearchCriteria?) -> [String: AnyObject]? in
            return ZuzuCriteria.criteriaToJSON(values)
    })
    
    
    
    // MARK - Static Functions
    
    static func criteriaFromJSON(JSONDict: [String: AnyObject]?) -> SearchCriteria? {
        
        if let JSONDict = JSONDict, let dataFromString = JSONDict["value"]?.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false) {
            
            let json = JSON(data: dataFromString)
            
            // 地區
            var cities = [City]()
            for (_, cityJson):(String, JSON) in json["city"] {
                
                var regions = [Region]()
                
                if cityJson["regions"].arrayValue.isEmpty {
                    regions.append(Region.allRegions)
                }
                
                for (_, regionJson):(String, JSON) in cityJson["regions"] {
                    regions.append(Region(code: regionJson.intValue, name: ""))
                }
                
                let city = City(code: cityJson["code"].intValue, name: "", regions: regions)
                cities.append(city)
            }
            
            // 用途
            let types = json["purpose_types"]["value"].arrayObject as? [Int]
            
            // 租金範圍
            let price:(Int, Int) = (json["price"]["from"].intValue, json["price"]["to"].intValue)
            
            // 坪數範圍
            let size:(Int, Int) = (json["size"]["from"].intValue, json["size"]["to"].intValue)
            
            Log.debug("cities: \(cities)")
            Log.debug("types: \(types)")
            Log.debug("price: \(price)")
            Log.debug("size: \(size)")
            
            
            // Collect all FilterGroup
            var filterGroups: [FilterGroup] = [FilterGroup]()
            for filterSection in FilterTableViewController.filterSections {
                for filterGroup in filterSection.filterGroups {
                    filterGroups.append(filterGroup)
                }
            }
            
            
            var selectedFilterGroups = [FilterGroup]()
            
            for filterGroup: FilterGroup in filterGroups {
                
                // 排除 "不限" Filter
                let filters = filterGroup.filters.filter({ (filter) -> Bool in
                    return filter.key != "unlimited"
                })
                
                var selectedFilters = [Filter]()
                
                // Type: 附車位, 不要地下室, 不要頂樓加蓋, 可養寵物, 可開伙
                if filterGroup.type == DisplayType.SimpleView {
                    
                    for filter: Filter in filters {
                
                        // Special: 不要地下室
                        if filter.key == "floor" && json["basement"].stringValue == filter.value {
                            selectedFilters.append(filter)
                            continue
                        }
                        
                        if json[filter.key].stringValue == filter.value {
                            selectedFilters.append(filter)
                        }
                    }
                    
                    continue
                }
                
                // Type: 房客性別, 最短租期
                if filterGroup.type == DisplayType.DetailView && filterGroup.choiceType == ChoiceType.SingleChoice {
                    
                    for filter: Filter in filters {
                        if json[filter.key].stringValue == filter.value {
                            selectedFilters.append(filter)
                        }
                    }
                    
                    continue
                }
                
                // Special: 交通站點 (捷運, 公車, 火車, 高鐵)
                if filterGroup.id == "public_trans" {
                    
                    for filter: Filter in filters {
                        if json[filter.key].stringValue == "true" {
                            selectedFilters.append(filter)
                        }
                    }
                    
                    continue
                }
                
                // Type: 型態, 格局, 經辦人, 房客身分, 附傢俱, 附設備, 周邊機能
                if filterGroup.type == DisplayType.DetailView && filterGroup.choiceType == ChoiceType.MultiChoice {
                    
                    if let filterKey = filters.first?.key,
                        let jsonValueArray = json[filterKey]["value"].arrayObject as? [String] {
                            
                            for filter: Filter in filters {
                            
                                // Special: 格局 (5房以上)
                                if filter.key == "num_bedroom" && filter.value == "[5 TO *]" && jsonValueArray.contains("5") {
                                    selectedFilters.append(filter)
                                    continue
                                }
                                
                                if jsonValueArray.contains(filter.value) {
                                    selectedFilters.append(filter)
                                }
                            }
                        
                    }
                }
                
                if selectedFilters.count > 0 {
                    filterGroup.filters = selectedFilters
                    selectedFilterGroups.append(filterGroup)
                }
            }
            
            for filterGroup in selectedFilterGroups {
                Log.debug("filterGroup: \(filterGroup)")
            }
            
            let criteria = SearchCriteria()
            criteria.region = cities
            criteria.types = types
            criteria.price = price
            criteria.size = size
            criteria.filterGroups = selectedFilterGroups
            
            return criteria
        }
        
        return nil
    }
    
    static func criteriaToJSON(criteria: SearchCriteria?) -> [String: AnyObject]? {
        
        if let criteria = criteria {
            
            var JSONDict = [String: AnyObject]()
            
            // 地區
            if let cities = criteria.region {
                var results = [[String: AnyObject]]()
                
                for city: City in cities {
                    
                    var regionCodes = [Int]()
                    for region: Region in city.regions {
                        
                        // Ignore 全區
                        if region.code != 0 {
                            regionCodes.append(region.code)
                        }
                    }
                    
                    results.append(["code": city.code, "regions": regionCodes])
                }
                
                JSONDict["city"] = results
            }
            
            // 用途
            if let purposeTypes = criteria.types {
                JSONDict["purpose_types"] = ["operator": "OR", "value": purposeTypes]
            }
            
            // 租金範圍
            if let (from, to) = criteria.price {
                JSONDict["price"] = ["from": from, "to": to]
            }
            
            // 坪數範圍
            if let (from, to) = criteria.size {
                JSONDict["size"] = ["from": from, "to": to]
            }
            
            
            if let filterGroups = criteria.filterGroups {
                
                for filterGroup: FilterGroup in filterGroups {
                    
                    if let filterKey: String = filterGroup.filters.first?.key,
                        let firstValue = filterGroup.filters.first?.value {
                            
                            // Type: 附車位, 不要地下室, 不要頂樓加蓋, 可養寵物, 可開伙
                            if filterGroup.type == DisplayType.SimpleView {
                                
                                // Special: 不要地下室
                                if filterKey == "floor" {
                                    JSONDict["basement"] = "false"
                                    continue
                                }
                                
                                JSONDict[filterKey] = firstValue
                            }
                            
                            // Type: 房客性別, 最短租期
                            if filterGroup.type == DisplayType.DetailView && filterGroup.choiceType == ChoiceType.SingleChoice {
                                JSONDict[filterKey] = firstValue
                            }
                            
                            // Type: 型態, 格局, 經辦人, 房客身分, 附傢俱, 附設備, 周邊機能, 交通站點
                            if filterGroup.type == DisplayType.DetailView && filterGroup.choiceType == ChoiceType.MultiChoice {
                                if let logicType = filterGroup.logicType?.rawValue {
                                    var values = [String]()
                                    for filter: Filter in filterGroup.filters {
                                        
                                        // 忽略 "不限" Filter
                                        if filter.key == "unlimited" {
                                            continue
                                        }
                                        
                                        // Special: 格局 (5房以上)
                                        if filter.key == "num_bedroom" && filter.value == "[5 TO *]" {
                                            values.append("5")
                                            continue
                                        }
                                        
                                        // Special: 交通站點 (捷運, 公車, 火車, 高鐵)
                                        if ["nearby_mrt", "nearby_bus", "nearby_train", "nearby_thsr"].contains(filter.key) {
                                            JSONDict[filter.key] = "true"
                                            continue
                                        }
                                        
                                        if let value: String = filter.value {
                                            values.append(value)
                                        }
                                    }
                                    
                                    if values.count > 0 {
                                        JSONDict[filterKey] = ["operator":  logicType, "value": values]
                                    }
                                }
                            }
                            
                    }
                }
            }
            
            return JSONDict
        }
        
        return nil
    }
    
}

