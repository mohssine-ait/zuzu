//
//  RegionTableViewController.swift
//  Zuzu
//
//  Created by Jung-Shuo Pai on 2015/10/13.
//  Copyright © 2015年 Jung-Shuo Pai. All rights reserved.
//

import UIKit
import SwiftyJSON

class Region: NSObject, NSCoding {
    var code:Int
    var name:String
    
    init(code:Int, name: String) {
        self.code = code
        self.name = name
    }
    
    convenience required init?(coder decoder: NSCoder) {
        let code = decoder.decodeIntegerForKey("code") as Int
        let name = decoder.decodeObjectForKey("name") as? String ?? ""
        
        self.init(code: code, name: name)
    }
    
    override func isEqual(object: AnyObject?) -> Bool {
        return (object as? Region)?.code == code
    }
    
//    override var hashValue : Int {
//        get {
//            return code.hashValue
//        }
//    }
    
    func encodeWithCoder(aCoder: NSCoder) {
        aCoder.encodeInteger(code, forKey:"code")
        aCoder.encodeObject(name, forKey:"name")
    }
    
    override var description: String {
        let string = "Region: code = \(code), name = \(name)"
        return string
    }
}

//func ==(lhs: Region, rhs: Region) -> Bool {
//    return  lhs.hashValue == rhs.hashValue
//}

class City: NSObject, NSCoding {
    var code:Int
    var name:String
    var regions:[Region]
    
    init(code:Int, name: String, regions:[Region]) {
        self.code = code
        self.name = name
        self.regions = regions
    }
    
    convenience required init?(coder decoder: NSCoder) {
        
        let code = decoder.decodeIntegerForKey("code") as Int
        let name = decoder.decodeObjectForKey("name") as? String ?? ""
        let regions = decoder.decodeObjectForKey("regions") as? [Region] ?? [Region]()
        
        self.init(code: code, name: name, regions: regions)
        
        //self.
    }
    
    func encodeWithCoder(aCoder: NSCoder) {
        aCoder.encodeInteger(code, forKey:"code")
        aCoder.encodeObject(name, forKey:"name")
        aCoder.encodeObject(regions, forKey:"regions")
    }
    
    override var description: String {
        let string = "Region: code = \(code), name = \(name)"
        return string
    }
}

protocol RegionTableViewControllerDelegate {
    func onRegionSelectionDone(result: [City])
}

class RegionTableViewController: UITableViewController, CitySelectionViewControllerDelegate {

    var citySelected:Int = 100 //Default value
    var checkedRegions: [Int:[Bool]] = [Int:[Bool]]()//Region selected grouped by city
    var cityRegions = [Int : City]()//City dictionary by city code
    
    var delegate: RegionTableViewControllerDelegate?
    
    let allRegion = Region(code: 0, name: "全區")
    
    private func configureRegionTable() {
        
        //Configure cell height
        tableView.estimatedRowHeight = tableView.rowHeight
        tableView.rowHeight = UITableViewAutomaticDimension
        //tableView.allowsSelection = false
        
    }
    
    func onCitySelected(value: Int) {
        citySelected = value
        
        tableView.reloadData()
    }
    
    // MARK: - View Controller Life Cycel
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.configureRegionTable()
        
        NSLog("viewDidLoad: %@", self)
        
        ///Load all city regions from json
        if let path = NSBundle.mainBundle().pathForResource("areasInTaiwan", ofType: "json") {
            
            do {
                let jsonData = try NSData(contentsOfFile: path, options: NSDataReadingOptions.DataReadingMappedIfSafe)
                let json = JSON(data: jsonData)
                let cities = json["cities"].arrayValue
                
                NSLog("Cities = %d", cities.count)
                
                for cityJsonObj in cities {
                    //Do something you want
                    let name = cityJsonObj["name"].stringValue
                    let code = cityJsonObj["code"].intValue
                    let regions = cityJsonObj["region"].arrayValue

                    ///Init Region Table data
                    var regionList:[Region] = [Region]()
                    
                    regionList.append(allRegion)///All region
                    
                    for region in regions {
                        if let regionDic = region.dictionary {
                            for key in regionDic.keys {
                                regionList.append(Region(code: regionDic[key]!.intValue, name: key))
                            }
                        }
                    }
                    
                    ///Init selection status for each city
                    checkedRegions[code] = [Bool](count:regionList.count, repeatedValue: false)
                    
                    cityRegions[code] = City(code: code, name: name, regions: regionList)
                }
                
            } catch let error as NSError{
                
                NSLog("Cannot load area json file %@", error)
                
            }
            
            ///Load selected regions
            let userDefaults = NSUserDefaults.standardUserDefaults()
            let data = userDefaults.objectForKey("selectedRegion") as? NSData
            
            if(data != nil) {
                if let selectedCities = NSKeyedUnarchiver.unarchiveObjectWithData(data!) as? [City] {
                
                for city in selectedCities {
                    
                    let selectedRegions = city.regions
                    
                    if(selectedRegions.isEmpty) {
                        checkedRegions[city.code]?[0] = true
                    } else {
                        for region in selectedRegions {
                            if let index = cityRegions[city.code]?.regions.indexOf(region) { ///Region needs to be Equatable
                                checkedRegions[city.code]?[index] = true
                            }
                        }
                    }
                }
                }
                //self.checkedRegions
            }
        }
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        
        NSLog("viewWillDisappear: %@", self)
        var result: [City] = [City]()
        
        for cityCode in checkedRegions.keys {
            
            ///Copy city data
            if let city = cityRegions[cityCode] {
                
                ///Check selected regions
                if let selectionStatus = checkedRegions[cityCode] {
                    
                    let newCity = City(code: city.code, name: city.name, regions: [Region]())
                    var allRegion:Bool = false
                    var selectedRegions:[Region] = [Region]()
                    
                    for (index, status) in selectionStatus.enumerate() {
                        if(status) {
                            if(index == 0) { ///"All Reagion"
                                allRegion = true
                            } else{ ///Not "All Region" items
                                selectedRegions.append(city.regions[index])
                            }
                        }
                    }
                    
                    if(allRegion) {
                        result.append(newCity)
                    } else {
                        if(!selectedRegions.isEmpty) {
                            newCity.regions = selectedRegions
                            result.append(newCity)
                        }
                    }
                    
                    allRegion = false
                }
                
            }
            
        }
        
        delegate?.onRegionSelectionDone(result)
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - Table view delegate
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        
        let row = indexPath.row
        
        
        if let statusForCity = checkedRegions[citySelected]{
            if(statusForCity[row]) {
                checkedRegions[citySelected]![row] = false
            } else {
                checkedRegions[citySelected]![row] = true
                
                if(row == 0){ //Click on "all region"
                    for var index = row+1; index < checkedRegions[citySelected]?.count; ++index {
                        checkedRegions[citySelected]![index] = false
                    }
                    
                    tableView.reloadData() //in order to update other cell's view
                    return
                } else { //Click on other region
                    if(checkedRegions[citySelected]![0]) {
                        checkedRegions[citySelected]![0] = false
                        
                        tableView.reloadData()
                        //tableView.reloadRowsAtIndexPaths([NSIndexPath(forRow: 0, inSection: 0)], withRowAnimation: UITableViewRowAnimation.None)
                    }
                }
            }
        }
        
        tableView.reloadRowsAtIndexPaths([indexPath], withRowAnimation: UITableViewRowAnimation.None)
        
    }
    
    // MARK: - Table view data source
    
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return cityRegions[citySelected]?.regions.count ?? 0
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCellWithIdentifier("regionCell", forIndexPath: indexPath)
        
        let row = indexPath.row
        
        NSLog("- Cell Instance [%p] Prepare Cell For Row[\(indexPath.row)]", cell)
        
        ///Reset for reuse
        cell.accessoryType = UITableViewCellAccessoryType.None
        
        if let statusForCity = checkedRegions[citySelected]{
            if(statusForCity[row]) {
                cell.accessoryType = UITableViewCellAccessoryType.Checkmark
            } else {
                cell.accessoryType = UITableViewCellAccessoryType.None
            }
        }
        
        cell.textLabel?.font = UIFont.preferredFontForTextStyle(UIFontTextStyleHeadline).fontWithSize(20)
        
        if let city = cityRegions[citySelected] {
            cell.textLabel?.text = city.regions[indexPath.row].name
        }
        
        return cell
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        NSLog("prepareForSegue: %@", self)
    }
    
}
