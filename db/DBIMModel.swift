//
//  DBModel.swift
//  MyGoPlus
//
//  Created by Joe Lo on 2017/10/3.
//  Copyright © 2017年 mygo. All rights reserved.
//

import UIKit
import RealmSwift

public class DBObject:Object
{
    dynamic var id = -1
    override public static func primaryKey() -> String? {
        return "id"
    }
    
    func identifyId() -> String{ return "" }
    open class func identifyIdKey() -> String { return "" }

    
}
public class DBContact:DBObject {
    public enum SearchCondition
    {
        case all
        case identifyId(String)
        case uid(String)
        case uidWithoutContactId(String)
        case checkContactInfo(String)
        case name(String)
    }
    dynamic var contactId = ""
    dynamic var name = ""
    dynamic var avatorPath = ""
    dynamic var uid = ""
    dynamic var lastMessage = ""
    dynamic var lastMessageTimestamp = ""
    dynamic var readTime = ""
    dynamic var avatorMD5 = ""
    dynamic var unreadMessageCount = 0
    var hasUnreadMessage:Bool?
    {
        get
        {
            if lastMessageTimestamp.count > 0
            {
                guard let last = Double(lastMessageTimestamp) else {return nil}
                guard let read = Double(readTime) else {return true} //無讀取時間, 有最後訊息時間, 回應true
                return read < last
            }
            else
            {
                return nil
            }
        }
    }
    convenience init(contactId:String, name:String, avator:UIImage? = nil) {
        self.init()
        self.contactId = contactId
        self.name = name
        if let unwarpAvator = avator
        {
            self.setAvator(image: unwarpAvator)
        }
    }
    convenience init(uid:String, name:String, avator:UIImage? = nil) {
        self.init()
        self.uid = uid
        self.name = name
        if let unwarpAvator = avator
        {
            self.setAvator(image: unwarpAvator)
        }
    }
    public func avator()-> UIImage?
    {
        let path = DBManager.DocumentsPath() + avatorPath
        return UIImage(contentsOfFile: path)
    }
    public func setAvator(image:UIImage)
    {
        let path = DBManager.LocalPath(by: .image(path: ""))
        if let imageData = UIImagePNGRepresentation(image)
        {
            DBManager.WriteFile(path: path, data: imageData)
            avatorPath = path.components(separatedBy: DBManager.FilesFolder).last!
        }
    }

    public class func Search(realm:Realm,type:DBContact.SearchCondition) -> Results<DBContact>
    {
        var condition:String
        switch type {
        case .all:
            condition = "contactId != ''"
        case .identifyId(let cid):
            condition = "contactId = '\(cid)'"
        case .name(let name):
            condition = "name = '\(name)'"
        case let .checkContactInfo(cid):
            condition = "contactId = '\(cid)' AND name = ''"
        case let .uid(uid):
            condition = "uid = '\(uid)'"
        case let .uidWithoutContactId(uid):
            condition = "uid = '\(uid)' AND contactId = ''"
        }
        
        let results = realm.objects(self).filter(condition)

        return results
    }

    override func identifyId() -> String
    {
        return contactId
    }
    override open class func identifyIdKey() -> String
    {
        return "contactId"
    }
}

public class DBMessage:DBObject {

    public enum SearchCondition
    {
        case text(String)
        case identifyId(String)
        case timestamp(String,String)
        case contactId(String)
        case isOutGoing(Bool)
    }
    public enum contantType
    {
        case text(String) //0 message
        case image(path:String) //1 filePath
        case video(path:String) //2 filePath
        case voice(path:String,duration:Int) //3 filePath
    }
    dynamic var type = -1
    dynamic var messageId = ""
    dynamic var content = ""
    dynamic var timestamp = ""
    dynamic var sessionId = ""
    dynamic var contactId = ""
    dynamic var duration = 0
    dynamic var isOutGoing = true

    var localDateString:String
    {
        get
        {
            return dateString(from: timestamp)
        }
    }
    func dateString(from timestamp:String) -> String
    {
        let timeInterval = (Double(timestamp) ?? 0.0) / 1000.0
        let formatter = DateFormatter()
        formatter.dateFormat = "yy-M-d HH:mm"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: Date.init(timeIntervalSince1970: timeInterval))
    }
    convenience init(type:contantType,messageId:String = "",timestamp:String = String(Date().timeIntervalSince1970),contactId:String ,sessionId:String = "",isOutGoing:Bool) {
        self.init()
        self.messageId = messageId
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.contactId = contactId
        self.isOutGoing = isOutGoing
        switch type {
        case .text(let text):
            self.type = 0
            self.content = text
        case .image(let path):
            self.type = 1
            self.content = path
        case .video(let path):
            self.type = 2
            self.content = path
        case .voice(let path,let duration):
            self.type = 3
            self.content = path
            self.duration = Int(duration)
        }
    }
    public class func SearchPredicate(type:SearchCondition) -> String
    {
        var condition = ""
        switch type {
        case let .text(text):
            condition = "content contains '\(text)'"
        case let .timestamp(time1,time2):
            if let doubleTime1 = Double(time1),
                let doubleTime2 = Double(time2)
            {
                let timeMax = String(max(doubleTime1, doubleTime2))
                let timeMin = String(min(doubleTime1, doubleTime2))
                condition = "timestamp.doubleValue >= '\(timeMin)'.doubleValue AND timestamp.doubleValue <= '\(timeMax)'.doubleValue"
            }
            
        case let .identifyId(iid):
            let iidKey = identifyIdKey()
            condition = "\(iidKey) = '\(iid)'"
        case let .contactId(cid):
            condition = "contactId = '\(cid)'"
        default:
            break
        }
        return condition
    }
    public class func Search<T:DBMessage>(realm:Realm,type:SearchCondition) -> Results<T>
    {
        let condition = SearchPredicate(type: type)
            return realm.objects(T.self).filter(condition)
    }
    override func identifyId() -> String {
        return messageId
    }
    override open class func identifyIdKey() -> String
    {
        return "messageId"
    }
}
class DBMessageText:DBMessage
{
    convenience init(text:String,messageId:String = "",timestamp: String, contactId: String, sessionId: String, isOutGoing: Bool)
    {
        self.init(type: .text(text), messageId: messageId, timestamp: timestamp, contactId: contactId, sessionId: sessionId, isOutGoing: isOutGoing)
    }
}
class DBMessageImage:DBMessage
{
    dynamic var thumbnailPath = ""
    dynamic var displayName = ""
    convenience init(path:String,messageId:String = "", thumbnailPath:String, displayName:String, timestamp: String, contactId: String, sessionId: String, isOutGoing: Bool)
    {
        self.init(type: .image(path: path), messageId: messageId, timestamp: timestamp, contactId: contactId, sessionId: sessionId, isOutGoing: isOutGoing)
        self.thumbnailPath = thumbnailPath
        self.displayName = displayName
    }
}
class DBMessageVoice:DBMessage
{
    dynamic var displayName = ""
    convenience init(path:String,messageId:String = "", displayName:String,timestamp: String, contactId: String, sessionId: String, isOutGoing: Bool, duration: Int)
    {
        self.init(type: .voice(path: path,duration: duration), messageId: messageId, timestamp: timestamp, contactId: contactId, sessionId: sessionId, isOutGoing: isOutGoing)
        self.displayName = displayName
    }

}
class DBMessageVideo:DBMessage
{
    dynamic var thumbnailPath = ""
    dynamic var displayName = ""
    convenience init(path:String,messageId:String = "",thumbnailPath:String, displayName:String, timestamp: String, contactId: String, sessionId: String, isOutGoing: Bool)
    {
        self.init(type: .video(path: path), messageId: messageId, timestamp: timestamp, contactId: contactId, sessionId: sessionId, isOutGoing: isOutGoing)
        self.thumbnailPath = thumbnailPath
        self.displayName = displayName
    }

}
extension Realm
{
    public func updateOrNew(_ object:Object,update:Bool = true)
    {
        if let dbobject = object as? DBObject
        {
            if dbobject.id == -1
            {
                dbobject.id = DBManager.IncrementID(type(of: object))
            }
        }
        add(object, update: update)
    }
}

