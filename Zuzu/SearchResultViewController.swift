//
//  SearchResultViewController.swift
//  Zuzu
//
//  Created by Jung-Shuo Pai on 2015/10/27.
//  Copyright © 2015年 Jung-Shuo Pai. All rights reserved.
//

import UIKit

struct Const {
    static let SECTION_NUM:Int = 1
}

enum ScrollDirection {
    case ScrollDirectionNone
    case ScrollDirectionRight
    case ScrollDirectionLeft
    case ScrollDirectionUp
    case ScrollDirectionDown
    case ScrollDirectionCrazy
}

class SearchResultViewController: UIViewController {
    
    let cellIdentifier = "houseItemCell"
    
    struct ViewTransConst {
        static let showDebugInfo:String = "showDebugInfo"
        static let showAdvancedFilter:String = "showAdvancedFilter"
        static let displayHouseDetail:String = "displayHouseDetail"
    }
    
    // MARK: - Member Fields
    @IBOutlet weak var loadingSpinner: UIActivityIndicatorView! {
        didSet{
            stopSpinner()
        }
    }
    
    @IBOutlet weak var sortByPriceButton: UIButton!
    
    @IBOutlet weak var sortBySizeButton: UIButton!
    
    @IBOutlet weak var sortByPostTimeButton: UIButton!
    
    
    @IBOutlet weak var tableView: UITableView!
    
    @IBOutlet weak var smartFilterScrollView: UIScrollView!
    
    private let filterDataStore = UserDefaultsFilterSettingDataStore.getInstance()
    
    var debugTextStr: String = ""
    private let searchItemService : SearchItemService = SearchItemService.getInstance()
    private let dataSource: HouseItemTableDataSource = HouseItemTableDataSource()
    private var lastContentOffset:CGFloat = 0
    private var lastDirection: ScrollDirection = ScrollDirection.ScrollDirectionNone
    private var ignoreScroll = false
    
    private var sortingStatus: [String:String] = [String:String]() //Field Name, Sorting Type
    private var selectedFilterIdSet = [String : Set<FilterIdentifier>]()
    
    var searchCriteria: SearchCriteria?
    
    // MARK: - Private Utils
    
    private func alertSavingCurrentSearchSuccess() {
        // Initialize Alert View
        
        let alertView = UIAlertView(
            title: "儲存常用搜尋條件",
            message: "當前的搜尋條件已經被儲存!",
            delegate: self,
            cancelButtonTitle: "知道了")
        
        // Configure Alert View
        alertView.tag = 2
        
        // Show Alert View
        alertView.show()
        
        // Delay the dismissal
        self.runOnMainThreadAfter(2.0) {
            alertView.dismissWithClickedButtonIndex(-1, animated: true)
        }
    }
    
    private func alertSavingCurrentSearchFailure() {
        // Initialize Alert View
        
        let alertView = UIAlertView(
            title: "常用搜尋條件已滿",
            message: "常用搜尋條件儲存已達上限，請先刪除不需要的條件",
            delegate: self,
            cancelButtonTitle: "知道了")
        
        // Configure Alert View
        alertView.tag = 2
        
        // Show Alert View
        alertView.show()
        
        // Delay the dismissal
        self.runOnMainThreadAfter(2.0) {
            alertView.dismissWithClickedButtonIndex(-1, animated: true)
        }
    }

    private func alertAddingToCollectionSuccess() {
        // Initialize Alert View
        
        let alertView = UIAlertView(
            title: "新增我的收藏",
            message: "新增了一筆物件到我的收藏",
            delegate: self,
            cancelButtonTitle: "知道了")
        
        // Configure Alert View
        alertView.tag = 2
        
        // Show Alert View
        alertView.show()
        
        // Delay the dismissal
        self.runOnMainThreadAfter(2.0) {
            alertView.dismissWithClickedButtonIndex(-1, animated: true)
        }
    }
    
    private func startSpinner() {
        loadingSpinner.startAnimating()
    }
    
    private func stopSpinner() {
        loadingSpinner.stopAnimating()
    }
    
    private func loadHouseListPage(pageNo: Int) {
        
        if(pageNo > dataSource.estimatedNumberOfPages){
            NSLog("loadHouseListPage: Exceeding max number of pages [\(dataSource.estimatedNumberOfPages)]")
            return
        }
        
        startSpinner()
        dataSource.loadDataForPage(pageNo)
        
    }
    
    private func onDataLoaded(dataSource: HouseItemTableDataSource, pageNo: Int, error: NSError?) -> Void {
        
        if(error != nil) {
            // Initialize Alert View
            
            let alertView = UIAlertView(
                title: NSLocalizedString("unable_to_get_data.alert.title", comment: ""),
                message: NSLocalizedString("unable_to_get_data.alert.msg", comment: ""),
                delegate: self,
                cancelButtonTitle: NSLocalizedString("unable_to_get_data.alert.button.ok", comment: ""))
            
            // Configure Alert View
            alertView.tag = 1
            
            
            // Show Alert View
            alertView.show()
        }
        
        self.stopSpinner()
        self.tableView.reloadData()
        
        NSLog("%@ onDataLoaded: Total #Item in Table: \(self.dataSource.getSize())", self)
        
        self.debugTextStr = self.dataSource.debugStr
    }
    
    private func updateSortingField(field:String, order:String) {
        NSLog("Sorting = %@ %@", field, order)
        self.searchCriteria?.sorting = "\(field) \(order)"
        self.sortingStatus[field] = order
    }
    
    private func sortByField(button: UIButton, sortingOrder: String) {
        
        ///Switch from other sorting fields
        if(!button.selected) {
            ///Disselect all & Clear all sorting icon for Normal state
            sortByPriceButton.selected = false
            sortByPriceButton.setImage(nil,
                forState: UIControlState.Normal)
            
            sortBySizeButton.selected = false
            sortBySizeButton.setImage(nil,
                forState: UIControlState.Normal)
            
            sortByPostTimeButton.selected = false
            sortByPostTimeButton.setImage(nil,
                forState: UIControlState.Normal)
            
            ///Select the one specified by hte user
            button.selected = true
        }
        
        
        ///Set image for selected state
        if(sortingOrder == HouseItemDocument.Sorting.sortAsc) {
            button.setImage(UIImage(named: "sort-ascending"),
                forState: UIControlState.Selected)
            button.setImage(UIImage(named: "sort-ascending"),
                forState: UIControlState.Normal)
            
        } else if(sortingOrder == HouseItemDocument.Sorting.sortDesc) {
            button.setImage(UIImage(named: "sort-descending"),
                forState: UIControlState.Selected)
            button.setImage(UIImage(named: "sort-descending"),
                forState: UIControlState.Normal)
            
        } else {
            assert(false, "Unknown Sorting order")
        }
    }
    
    private func imageWithColor(color: UIColor) -> UIImage {
        
        let rect:CGRect = CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0)
        UIGraphicsBeginImageContext(rect.size)
        let context:CGContextRef? = UIGraphicsGetCurrentContext()
        
        CGContextSetFillColorWithColor(context, color.CGColor)
        CGContextFillRect(context, rect)
        
        let image:UIImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return image
        
    }
    
    private func reloadDataWithNewCriteria(criteria: SearchCriteria?) {
        self.dataSource.criteria = criteria
        self.startSpinner()
        self.dataSource.initData()
        self.tableView.reloadData()
    }
    
    private func configureFilterButtons() {
        
        if let smartFilterView = smartFilterScrollView.viewWithTag(100) as? SmartFilterView {
            
            for button in smartFilterView.filterButtons {
                button.addTarget(self, action: "onFilterButtonTouched:", forControlEvents: UIControlEvents.TouchDown)
                
                ///Check selection state
                if let filterGroup : FilterGroup = smartFilterView.filtersByButton[button] {
                    
                    button.setToggleState(getStateForSmartFilterButton(filterGroup))
                    
                }
            }
        }
    }
    
    private func getStateForSmartFilterButton(filterGroup : FilterGroup) -> Bool {
        
        let selectedFilterId = self.selectedFilterIdSet[filterGroup.id]
        
        if(selectedFilterId == nil) {
            return false
        }
        
        if(selectedFilterId?.count != filterGroup.filters.count) {
            return false
        }
        
        var state = true
        
        for filterId in filterGroup.filters.map({ (filter) -> FilterIdentifier in
            return filter.identifier
        }) {
            state = state && selectedFilterId!.contains(filterId)
        }
        
        return state
    }
    
    private func convertToFilterGroup(selectedFilterIdSet: [String: Set<FilterIdentifier>]) -> [FilterGroup] {
        
        var filterGroupResult = [FilterGroup]()
        
        ///Walk through all items to generate the list of selected FilterGroup
        for section in FilterTableViewController.filterSections {
            for group in section.filterGroups {
                if let selectedFilterId = selectedFilterIdSet[group.id] {
                    let groupCopy = group.copy() as! FilterGroup
                    
                    let selectedFilters = group.filters.filter({ (filter) -> Bool in
                        selectedFilterId.contains(filter.identifier)
                    })
                    
                    groupCopy.filters = selectedFilters
                    
                    filterGroupResult.append(groupCopy)
                }
            }
        }
        
        return filterGroupResult
    }
    
    private func updateSlectedFilterIdSet(newFilterIdSet : [String : Set<FilterIdentifier>]) {
        
        ///Remove filters not included in the newFilterIdSet
        for groupId in self.selectedFilterIdSet.keys {
            if (newFilterIdSet[groupId] == nil) {
                self.selectedFilterIdSet.removeValueForKey(groupId)
            }
        }
        
        ///Update/Add filter value
        for (groupId, valueSet) in newFilterIdSet {
            self.selectedFilterIdSet.updateValue(valueSet, forKey: groupId)
        }
        
        ///Save all selected setting
        self.filterDataStore.saveAdvancedFilterSetting(self.selectedFilterIdSet)
    }
    
    
    private func appendSlectedFilterIdSet(newFilterIdSet : [String : Set<FilterIdentifier>]) {
        
        ///Update/Add filter value
        for (groupId, valueSet) in newFilterIdSet {
            self.selectedFilterIdSet.updateValue(valueSet, forKey: groupId)
        }
        
        ///Save all selected setting
        self.filterDataStore.saveAdvancedFilterSetting(self.selectedFilterIdSet)
    }
    
    private func removeSlectedFilterIdSet(groupId : String) {
        
        selectedFilterIdSet.removeValueForKey(groupId)
        
        ///Save all selected setting
        self.filterDataStore.saveAdvancedFilterSetting(self.selectedFilterIdSet)
    }
    
    // MARK: - Control Action Handlers
    @IBAction func onSaveSearchButtonClicked(sender: UIBarButtonItem) {
        
        if let criteria = self.searchCriteria {
            
            do{
                try searchItemService.addNewSearchItem(SearchItem(criteria: criteria, type: .SavedSearch))
                
                alertSavingCurrentSearchSuccess()
                
            } catch {
                
                alertSavingCurrentSearchFailure()
            }
            
        }
    }
    
    func onFilterButtonTouched(sender: UIButton) {
        if let toogleButton = sender as? ToggleButton {
            toogleButton.toggleButtonState()
            
            let isToggleOn = toogleButton.getToggleState()
            
            if let smartFilterView = smartFilterScrollView.viewWithTag(100) as? SmartFilterView {
                
                if let filterGroup = smartFilterView.filtersByButton[toogleButton] {
                    
                    var filterIdSet = [String: Set<FilterIdentifier>]()
                    
                    for smartFilter in filterGroup.filters {
                        if(isToggleOn) {
                            ///Replaced with Smart Filter Setting
                            filterIdSet[filterGroup.id] = [smartFilter.identifier]
                            self.appendSlectedFilterIdSet(filterIdSet)
                        } else {
                            ///Clear filters under this group
                            removeSlectedFilterIdSet(filterGroup.id)
                        }
                    }
                    
                    
                    if let searchCriteria = self.searchCriteria {
                        
                        searchCriteria.filters = self.getFilterDic(self.selectedFilterIdSet)
                        
                    }

                    reloadDataWithNewCriteria(self.searchCriteria)
                }
            }
        }
    }
    
    @IBAction func onSortingButtonTouched(sender: UIButton) {
        
        var sortingOrder:String?
        var sortingField:String?
        
        switch sender {
        case sortByPriceButton:
            sortingField = HouseItemDocument.price
        case sortBySizeButton:
            sortingField = HouseItemDocument.size
        case sortByPostTimeButton:
            sortingField = HouseItemDocument.postTime
        default: break
        }
        
        if let sortingField = sortingField {
            if(sender.selected) { ///Touchd when already selected
                
                if let status = self.sortingStatus[sortingField] {
                    
                    ///Reverse the previous sorting order
                    
                    sortingOrder = ((status == HouseItemDocument.Sorting.sortAsc) ? HouseItemDocument.Sorting.sortDesc : HouseItemDocument.Sorting.sortAsc)
                    
                }
                
            } else { ///Switched from other sorting fields
                
                if let status = self.sortingStatus[sortingField] {
                    
                    ///Use the previous sorting order
                    sortingOrder = status
                    
                } else {
                    
                    ///Use Default Ordering Asc
                    sortingOrder = HouseItemDocument.Sorting.sortAsc
                }
                
            }
            
            if let sortingOrder = sortingOrder {
                
                updateSortingField(sortingField, order: sortingOrder)
                
                reloadDataWithNewCriteria(searchCriteria)
                
                sortByField(sender, sortingOrder: sortingOrder)
            }
        }
    }
    
    func onAddToCollectionTouched(sender: UIImage) {
        
        alertAddingToCollectionSuccess()
        
    }
    
    // MARK: - View Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NSLog("%@ [[viewDidLoad]]", self)
        
        // Load Selected filters
        if let selectedFilterSetting = filterDataStore.loadAdvancedFilterSetting() {
            for (key, value) in selectedFilterSetting {
                self.selectedFilterIdSet[key] = value
            }
        }
        
        //Configure cell height
        tableView.estimatedRowHeight = tableView.rowHeight
        tableView.rowHeight = UITableViewAutomaticDimension
        
        //Configure table DataSource & Delegate
        self.tableView.dataSource = self
        self.tableView.delegate = self
        self.tableView.registerNib(UINib(nibName: "SearchResultTableViewCell", bundle: nil), forCellReuseIdentifier: "houseItemCell")
        
        //Configure Sorting Status
        let bgColorWhenSelected = UIColor(red: 0x00/255, green: 0xE3/255, blue: 0xE3/255, alpha: 0.6)
        self.sortByPriceButton.setBackgroundImage(imageWithColor(bgColorWhenSelected), forState:UIControlState.Selected)
        self.sortBySizeButton.setBackgroundImage(imageWithColor(bgColorWhenSelected), forState:UIControlState.Selected)
        self.sortByPostTimeButton.setBackgroundImage(imageWithColor(bgColorWhenSelected), forState:UIControlState.Selected)
        
        //Configure remote data source
        self.dataSource.setDataLoadedHandler(onDataLoaded)
        self.dataSource.criteria = searchCriteria
        
        //Configure Filter Buttons
        self.configureFilterButtons()
        
        //Load the first page of data
        self.startSpinner()
        self.dataSource.initData()
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        NSLog("%@ [[viewWillAppear]]", self)
        
        //Configure Filter Buttons
        configureFilterButtons()
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        NSLog("%@ [[viewWillDisappear]]", self)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - Navigation
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if let identifier = segue.identifier{
            
            NSLog("prepareForSegue: %@", identifier)
            
            switch identifier{
            case ViewTransConst.showDebugInfo:
                let debugVc = segue.destinationViewController as UIViewController
                
                if let pVc = debugVc.presentationController {
                    pVc.delegate = self
                }
                
                let view:[UIView] = debugVc.view.subviews
                
                if let textView = view[0] as? UITextView {
                    textView.text = self.debugTextStr
                }
                
            case ViewTransConst.showAdvancedFilter:
                
                if let ftvc = segue.destinationViewController as? FilterTableViewController {
                    
                    ftvc.selectedFilterIdSet = self.selectedFilterIdSet
                    
                    ftvc.filterDelegate = self
                }
                
            default: break
            }
        }
    }
}

extension SearchResultViewController: UITableViewDataSource, UITableViewDelegate {
    
    // MARK: - Table View Data Source
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return Const.SECTION_NUM
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        NSLog("%@ tableView Count: \(dataSource.getSize())", self)
        
        return dataSource.getSize()
    }
    
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(cellIdentifier, forIndexPath: indexPath) as! SearchResultTableViewCell
        
        NSLog("- Cell Instance [%p] Prepare Cell For Row[\(indexPath.row)]", cell)
        
        
        cell.parentTableView = tableView
        cell.indexPath = indexPath
        
        cell.houseItem = dataSource.getItemForRow(indexPath.row)
        cell.addToCollectionButton.hidden = false
        cell.addToCollectionButton.userInteractionEnabled = true
        cell.addToCollectionButton.addGestureRecognizer(UITapGestureRecognizer(target: self, action: Selector("onAddToCollectionTouched:")))
        
        return cell
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        self.performSegueWithIdentifier(ViewTransConst.displayHouseDetail, sender: self)
    }
    
}

extension SearchResultViewController: UIScrollViewDelegate {
    
    // MARK: - Scroll View Delegate
    
    func scrollViewDidEndDecelerating(scrollView: UIScrollView) {
        
        //NSLog("==scrollViewDidEndDecelerating==")
        //NSLog("Content Height: \(scrollView.contentSize.height)")
        //NSLog("Content Y-offset: \(scrollView.contentOffset.y)")
        //NSLog("ScrollView Height: \(scrollView.frame.size.height)")
        
        
        let yOffsetForTop:CGFloat = 0
        let yOffsetForBottom:CGFloat = floor(scrollView.contentSize.height - scrollView.frame.size.height)
        let currentContentOffset = floor(scrollView.contentOffset.y)
        
        if (currentContentOffset >= yOffsetForBottom){
            NSLog("%@ Bounced, Scrolled To Bottom", self)
            
            let nextPage = self.dataSource.currentPage + 1
            
            loadHouseListPage(nextPage)
            
        }else if(scrollView.contentOffset.y + scrollView.contentInset.top <= yOffsetForTop) {
            NSLog("%@ Bounced, Scrolled To Top", self)
        }
    }
    
    func scrollViewDidScroll(scrollView: UIScrollView) {
        
        //NSLog("==scrollViewDidScroll==")
        //NSLog("Content Height: \(scrollView.contentSize.height)")
        //NSLog("Content Y-offset: \(scrollView.contentOffset.y)")
        //NSLog("ScrollView Height: \(scrollView.frame.size.height)")
        
        //Check for scroll direction
        if (self.lastContentOffset > scrollView.contentOffset.y){
            self.lastDirection = .ScrollDirectionDown
        } else if (self.lastContentOffset < scrollView.contentOffset.y){
            self.lastDirection = .ScrollDirectionUp
        }
        
        self.lastContentOffset = scrollView.contentOffset.y;
        
        
        
        let yOffsetForTop:CGFloat = 0
        let yOffsetForBottom:CGFloat = (scrollView.contentSize.height - self.tableView.rowHeight) - scrollView.frame.size.height
        
        if(yOffsetForBottom >= 0) {
            if (scrollView.contentOffset.y >= yOffsetForBottom){
                NSLog("%@ Scrolled To Bottom", self)
                
                let nextPage = self.dataSource.currentPage + 1
                
                if(nextPage <= dataSource.estimatedNumberOfPages){
                    startSpinner()
                    return
                }
                
            } else if(scrollView.contentOffset.y + scrollView.contentInset.top <= yOffsetForTop) {
                //NSLog("Scrolled To Top")
            }
        }
    }
    
    
}

extension SearchResultViewController: UIAdaptivePresentationControllerDelegate {
    
    //Need to figure out the use of this...
    func adaptivePresentationStyleForPresentationController(controller: UIPresentationController) -> UIModalPresentationStyle {
        return UIModalPresentationStyle.None
    }
    
}

extension SearchResultViewController: UIAlertViewDelegate {
    
    func alertView(alertView: UIAlertView, clickedButtonAtIndex buttonIndex: Int) {
        NSLog("Alert Dialog Button [%d] Clicked", buttonIndex)
    }
    
}

extension SearchResultViewController: FilterTableViewControllerDelegate {
    
    private func getFilterDic(filteridSet: [String : Set<FilterIdentifier>]) -> [String:String] {
        
        let filterGroups = self.convertToFilterGroup(filteridSet)
        
        var allFiltersDic = [String:String]()
        
        for filterGroup in filterGroups {
            let filterPair = filterGroup.filterDic
            
            for (key, value) in filterPair {
                allFiltersDic[key] = value
            }
        }
        
        return allFiltersDic
    }
    
    func onFiltersReset() {
        self.filterDataStore.clearFilterSetting()
    }
    
    func onFiltersSelected(selectedFilterIdSet: [String : Set<FilterIdentifier>]) {
        
        NSLog("onFiltersSelected: %@", selectedFilterIdSet)
        
        
        self.updateSlectedFilterIdSet(selectedFilterIdSet)
        
        if let searchCriteria = self.searchCriteria {
            
            searchCriteria.filters = self.getFilterDic(self.selectedFilterIdSet)
            
        }
             
        reloadDataWithNewCriteria(self.searchCriteria)
    }
}