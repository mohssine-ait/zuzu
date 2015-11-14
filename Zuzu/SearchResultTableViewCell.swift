//
//  SearchResultTableViewCell.swift
//  Zuzu
//
//  Created by Jung-Shuo Pai on 2015/9/23.
//  Copyright © 2015年 Jung-Shuo Pai. All rights reserved.
//
import Alamofire
import AlamofireImage
import UIKit
import Foundation

class SearchResultTableViewCell: UITableViewCell {
    
    @IBOutlet weak var houseImg: UIImageView!
    @IBOutlet weak var houseTitle: UILabel!
    @IBOutlet weak var houseTypeAndUsage: UILabel!
    @IBOutlet weak var houseSize: UILabel!
    @IBOutlet weak var houseAddr: UILabel!
    @IBOutlet weak var housePrice: UILabel!
    @IBOutlet weak var addToCollectionButton: UIImageView!
    
    let placeholderImg = UIImage(named: "house_img")
    
    weak var parentTableView: UITableView!
    
    var indexPath: NSIndexPath!
    
    var houseItem: HouseItem? {
        didSet {
            updateUI()
        }
    }
    
    
    var houseItemForCollection: AnyObject? {
        didSet {
            updateUIForCollection()
        }
    }
    
    let textLayer = CATextLayer()
    let titleBackground = CAGradientLayer()
    let infoBackground = CALayer()
    
    private func getTypeString(type: Int) -> String? {
        
        let typeStr:String?
        
        switch type {
        case CriteriaConst.HouseType.BUILDING_WITHOUT_ELEVATOR:
            typeStr = "公寓"
        case CriteriaConst.HouseType.BUILDING_WITH_ELEVATOR:
            typeStr = "電梯大樓"
        case CriteriaConst.HouseType.INDEPENDENT_HOUSE:
            typeStr = "透天厝"
        case CriteriaConst.HouseType.INDEPENDENT_HOUSE_WITH_GARDEN:
            typeStr = "別墅"
        default:
            typeStr = ""
            break
        }
        
        if(typeStr != nil) {
            return typeStr!
        } else {
            return nil
        }
    }
    
    
    private func getUsageString(usage:Int) -> String? {
        
        let usageStr:String?
        
        switch usage {
        case CriteriaConst.PrimaryType.FULL_FLOOR:
            usageStr = "整層住家"
        case CriteriaConst.PrimaryType.HOME_OFFICE:
            usageStr = "住辦"
        case CriteriaConst.PrimaryType.ROOM_NO_TOILET:
            usageStr = "雅房"
        case CriteriaConst.PrimaryType.SUITE_COMMON_AREA:
            usageStr = "分租套房"
        case CriteriaConst.PrimaryType.SUITE_INDEPENDENT:
            usageStr = "獨立套房"
        default:
            usageStr = ""
            break
        }
        
        if(usageStr != nil) {
            return usageStr!
        } else {
            return nil
        }
    }
    
    private func addImageOverlay() {
        
        ///Gradient layer
        let gradientColors = [UIColor.grayColor().colorWithAlphaComponent(0.3).CGColor, UIColor.clearColor().CGColor]
        let gradientLocations = [0.0, 0.25,1.0]
        titleBackground.frame = houseImg.bounds
        titleBackground.colors = gradientColors
        titleBackground.locations = gradientLocations
        
        houseImg.layer.addSublayer(titleBackground)
        
        let infoHeight = self.contentView.bounds.width * (200/1441)
        let newOrigin = CGPoint(x: houseImg.bounds.origin.x,
            y: houseImg.bounds.origin.y + houseImg.bounds.height - infoHeight)
        
        infoBackground.frame = CGRect(origin: newOrigin,
            size: CGSize(width: houseImg.bounds.width, height: infoHeight))
        
        infoBackground.backgroundColor = UIColor.blackColor().colorWithAlphaComponent(0.3).CGColor
        
        houseImg.layer.addSublayer(infoBackground)
        
        ///Text Layer
        //        let textMargin = CGFloat(8.0)
        //        let newOrigin = CGPoint(x: houseImg.bounds.origin.x + textMargin, y: houseImg.bounds.origin.y + textMargin)
        //        textLayer.frame = CGRect(origin: newOrigin,
        //            size: CGSize(width: houseImg.bounds.width - 2 * textMargin, height: houseImg.bounds.height))
        //
        //        textLayer.string = title
        //        textLayer.fontSize = 24.0
        //        let fontName: CFStringRef = UIFont.boldSystemFontOfSize(20).fontName//"Noteworthy-Light"
        //        textLayer.font = CTFontCreateWithName(fontName, 24.0, nil)
        //        //textLayer.backgroundColor = UIColor.blackColor().colorWithAlphaComponent(0.2).CGColor
        //        textLayer.foregroundColor = UIColor.whiteColor().CGColor
        //        textLayer.wrapped = false
        //        textLayer.alignmentMode = kCAAlignmentLeft
        //        textLayer.contentsScale = UIScreen.mainScreen().scale
        //
        //        houseImg.layer.addSublayer(textLayer)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        // Reset any existing information
        houseTitle.text = nil
        houseAddr.text = nil
        houseTypeAndUsage.text = nil
        houseSize.text = nil
        housePrice.text = nil
        addToCollectionButton.image = UIImage(named: "Heart_n")
        
        // Cancel image loading operation
        houseImg.af_cancelImageRequest()
        houseImg.layer.removeAllAnimations()
        houseImg.image = nil
        
        NSLog("\n")
        NSLog("- Cell Instance [%p] Reset Data For Current Row[\(indexPath.row)]", self)
        
    }
    
    func updateUI() {
        
        // load new information (if any)
        if let houseItem = self.houseItem {
            houseTitle.text = houseItem.title
            houseAddr.text = houseItem.addr
            
            if let houseTypeStr = self.getTypeString(houseItem.houseType) {
                if let purposeTypeStr = self.getUsageString(houseItem.purposeType) {
                    houseTypeAndUsage.text = "\(houseTypeStr)/\(purposeTypeStr)"
                } else {
                    houseTypeAndUsage.text = "\(houseTypeStr)"
                }
            } else {
                if let purposeTypeStr = self.getUsageString(houseItem.purposeType) {
                    houseTypeAndUsage.text = "\(purposeTypeStr)"
                }
            }
            
            houseSize.text = String(format: "%d 坪", houseItem.size)
            housePrice.text = String(houseItem.price)
            houseImg.image = placeholderImg
            
            if let imageURLList = houseItem.imgList {
                if let firstURL = NSURL(string: imageURLList[0]) {
                    
                    let size = houseImg.frame.size
                    
                    NSLog("    <Start> Loading Img for Row[\(indexPath.row)]")
                    
                    houseImg.af_setImageWithURL(firstURL, placeholderImage: placeholderImg, filter: AspectScaledToFillSizeFilter(size: size), imageTransition: .CrossDissolve(0.2))
                        { (request, response, result) -> Void in
                            NSLog("    <End> Loading Img for Row = [\(self.indexPath.row)], status = \(response?.statusCode)")
                            NSLog("    <URL> %@", firstURL)
                    }
                }
            }
            
            self.addImageOverlay()
        }
    }
    
    
    
    func updateUIForCollection() {
        
        // load new information (if any)
        if let item = self.houseItemForCollection {
            
            self.houseTitle.text = item.valueForKey("title") as? String
            self.housePrice.text = item.valueForKey("price") as? String
            self.houseAddr.text = item.valueForKey("addr") as? String
            
            self.houseImg.image = placeholderImg
            
            if item.valueForKey("img")?.count > 0 {
                if let imgUrl = item.valueForKey("img")?[0] as? String {
                    let size = self.houseImg.frame.size
                    
                    self.houseImg.af_setImageWithURL(NSURL(string: imgUrl)!, placeholderImage: placeholderImg, filter: AspectScaledToFillSizeFilter(size: size), imageTransition: .CrossDissolve(0.2)) { (request, response, result) -> Void in
                        
                        NSLog("    <End> Loading Img for Row = [\(self.indexPath.row)], status = \(response?.statusCode)")
                    }
                }
            }
            
            self.addImageOverlay()
        }
    }
    
}
