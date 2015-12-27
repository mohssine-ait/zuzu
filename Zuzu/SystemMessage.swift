//
//  System.swift
//  Zuzu
//
//  Created by 李桄瑋 on 2015/12/25.
//  Copyright © 2015年 Jung-Shuo Pai. All rights reserved.
//

import Foundation

struct SystemMessage {
    
    struct INFO{
        static let EMPTY_NOTIFICATIONS = "尚無任何通知物件\n\n不妨嘗試在租屋雷達頁，設定符合需求的通知條件"
        static let EMPTY_COLLECTTIONS = "尚無任何儲存的收藏物件\n\n不妨嘗試在搜尋結果頁，把有興趣的租屋物件儲存起來"
        static let EMPTY_SAVED_SEARCH = "尚無任何儲存的\"常用搜尋\"\n\n不妨嘗試在搜尋結果頁，把當前搜尋條件儲存起來"
        static let EMPTY_HISTORICAL_SEARCH = "尚無任何\"搜尋紀錄\"\n\n日後任何的搜尋紀錄，都會記錄在這邊，方便查找"
    }
 
    struct ALERT{
    }
    
    struct ERROR{
    }
}