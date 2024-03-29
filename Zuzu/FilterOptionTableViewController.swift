//
//  FilterOptionTableViewController.swift
//  Zuzu
//
//  Created by Jung-Shuo Pai on 2015/11/4.
//  Copyright © 2015年 Jung-Shuo Pai. All rights reserved.
//

import UIKit

private let Log = Logger.defaultLogger

protocol FilterOptionTableViewControllerDelegate {

    func onFiltersSelected(group: String, filterIdSet: Set<FilterIdentifier>)

}

class FilterOptionTableViewController: UITableViewController {

    static let cellHeight = 55 * getCurrentScale()

    var filterOptionDelegate: FilterOptionTableViewControllerDelegate?

    var selectedFilterIds = Set<FilterIdentifier>()

    var filterOptions: FilterGroup!

    var nolimitCell: Int?

    override func viewDidLoad() {
        super.viewDidLoad()

        nolimitCell = filterOptions.filters.indexOf({ (filter) -> Bool in
            return (filter.key == Filter.defaultKeyUnlimited)
        })

        //Remove extra cells when the table height is smaller than the screen
        tableView.tableFooterView = UIView(frame: CGRect.zero)


        // Uncomment the following line to preserve selection between presentations
        self.clearsSelectionOnViewWillAppear = false


        self.tableView.registerNib(UINib(nibName: "SimpleFilterTableViewCell", bundle: nil), forCellReuseIdentifier: "simpleFilterTableCell")
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        Log.enter()

        //Google Analytics Tracker
        self.trackScreen()
    }

    override func willMoveToParentViewController(parent: UIViewController?) {
        super.willMoveToParentViewController(parent)

        if(parent == nil) {
            self.filterOptionDelegate?.onFiltersSelected(filterOptions.id, filterIdSet: self.selectedFilterIds)
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filterOptions.filters.count
    }

    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let currentFilterIdentifier = filterOptions.filters[indexPath.row].identifier
        let choiceType: ChoiceType! = filterOptions.choiceType

        Log.debug("didSelectRowAtIndexPath \(indexPath)")

        ///The user selects unlimited option
        if(nolimitCell == indexPath.row) {
            selectedFilterIds.removeAll()
            tableView.reloadData()
            return
        }

        ///The user selects other options

        if(choiceType == .SingleChoice) {
            //Clear all selection before selecting other choices
            selectedFilterIds.removeAll()
            tableView.reloadData()
        }


        ///Toggle Check /Unchecked state
        if(selectedFilterIds.contains(currentFilterIdentifier)) {
            selectedFilterIds.remove(currentFilterIdentifier)
        } else {
            selectedFilterIds.insert(currentFilterIdentifier)
        }

        ///Refresh unlimited cell
        if let unlimitIndex = nolimitCell {
            let unlimitIndexPath = NSIndexPath(forRow: unlimitIndex, inSection: 0)
            tableView.reloadRowsAtIndexPaths([unlimitIndexPath], withRowAnimation: UITableViewRowAnimation.None)
        }

        ///Refresh selected cell
        tableView.reloadRowsAtIndexPaths([indexPath], withRowAnimation: UITableViewRowAnimation.None)
    }

    override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return FilterOptionTableViewController.cellHeight
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let currentFilter = filterOptions.filters[indexPath.row]

        let cell = tableView.dequeueReusableCellWithIdentifier("simpleFilterTableCell", forIndexPath: indexPath) as! FilterTableViewCell

        if(nolimitCell == indexPath.row) {
            ///For unlimited cell, check if not filter selected
            if(selectedFilterIds.isEmpty) {
                cell.filterCheckMark.image = UIImage(named: "checked_green")
            } else {
                cell.filterCheckMark.image = UIImage(named: "uncheck")?.imageWithRenderingMode(UIImageRenderingMode.AlwaysTemplate)
                cell.filterCheckMark.tintColor = UIColor.grayColor()
            }
        } else {
            ///For other cells
            if(selectedFilterIds.contains(currentFilter.identifier)) {
                cell.filterCheckMark.image = UIImage(named: "checked_green")
            } else {
                cell.filterCheckMark.image = UIImage(named: "uncheck")?.imageWithRenderingMode(UIImageRenderingMode.AlwaysTemplate)
                cell.filterCheckMark.tintColor = UIColor.grayColor()
            }
        }

        cell.simpleFilterLabel.text = currentFilter.label

        return cell
    }

}
