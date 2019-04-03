//
//  DBManager.swift
//  MyGoPlus
//
//  Created by Joe Lo on 2017/10/3.
//  Copyright © 2017年 mygo. All rights reserved.
//

import UIKit
import RealmSwift

final class DBManager {
    private init(){}
    static var FilesFolder = "/tmp/"
    static var RealmFileName = "IMDatabase.realm"
    static let currentVersion = 3
    static var realm: Realm {
        get {
            if _realm == nil
            {
                do {
                    configRealm()
                    _realm = try Realm.init(fileURL:URL(fileURLWithPath: DocumentsPath()+RealmFileName))
                }
                catch {
                    print("Could not access database: ", error)
                }
            }
            return _realm!
        }
    }
    static var _realm:Realm?
    
    public class func write(writeClosure: () -> ()) {
        do {
            try realm.write {
                writeClosure()
            }
        } catch {
            print("Could not write to database: ", error)
        }
    }
    static let config = Realm.Configuration(
        // Set the new schema version. This must be greater than the previously used
        // version (if you've never set a schema version before, the version is 0).
        schemaVersion: UInt64(currentVersion),
        
        // Set the block which will be called automatically when opening a Realm with
        // a schema version lower than the one set above
        migrationBlock: { migration, oldSchemaVersion in
            // We haven’t migrated anything yet, so oldSchemaVersion == 0
            if (oldSchemaVersion < currentVersion) {
                // Nothing to do!
                // Realm will automatically detect new properties and removed properties
                // And will update the schema on disk automatically
            }

    })
    static func configRealm()
    {
        Realm.Configuration.defaultConfiguration = config
    }
}
// MARK: - IM function
extension DBManager
{
    class func SearchContacts(condition:DBContact.SearchCondition = .all) -> Results<DBContact>
    {
        return DBContact.Search(realm: realm, type:condition)
    }
//    class func addDefaultCustomService(withId contactId:String)
//    {
//        guard DBContact.Search(realm: realm, type: .identifyId(contactId)).count == 0
//            else {return}
//        let defaultService = DBContact(contactId:contactId, name: "Customer Service")
//        write{
//            realm.updateOrNew(defaultService,update:true)
//        }
//    }
    
    class func SearchMessages(condition:DBMessage.SearchCondition) -> [DBMessage]
    {
        let textMessages:Results<DBMessageText> = DBMessage.Search(realm: realm, type: condition)
        var combinedArray = [DBMessage]()
        textMessages.forEach{combinedArray.append($0)}

        switch condition {
        case .text(_):
            break
        default:
        let imageMessages:Results<DBMessageImage> = DBMessage.Search(realm: realm, type: condition)
        let videoMessages:Results<DBMessageVideo> = DBMessage.Search(realm: realm, type: condition)
        let voiceMessages:Results<DBMessageVoice> = DBMessage.Search(realm: realm, type: condition)
        imageMessages.forEach{combinedArray.append($0)}
        videoMessages.forEach{combinedArray.append($0)}
        voiceMessages.forEach{combinedArray.append($0)}
        }

        return combinedArray
    }
    class func array<T>(from results:Results<T>)->[T]
    {
        return Array(results)
    }
    //會依序找 imid及 uid 更新, 若沒有就新增
    class func addContact(newContact:DBContact)
    {
        if newContact.identifyId().characters.count > 0
        {
            let foundContacts = DBContact.Search(realm: realm, type: .identifyId(newContact.identifyId()))
            if let foundContact = foundContacts.first
            {
                newContact.id = foundContact.id
            }
        }
        else
            if newContact.uid.characters.count > 0
        {
            let foundContacts = DBContact.Search(realm: realm, type: .uid(newContact.uid))
            if let foundContact = foundContacts.first
            {
                newContact.id = foundContact.id
            }
        }
        write{
            realm.updateOrNew(newContact)
        }
    }
    
    class func addMessage(newMessage:DBMessage)
    {
        
        if newMessage.messageId.characters.count > 0
        {
            if let foundMessage = DBManager.SearchMessages(condition: .identifyId(newMessage.identifyId())).first
            {
                newMessage.id = foundMessage.id
            }
        }

        write{
            realm.updateOrNew(newMessage)
        }
    }
    enum ContactProperty
    {
        case uid(String)
        case contactId(String)
        case lastMessage(message:String, timestamp:String)
        case readTime(String)
        case name(String)
        case avatorPath(path:String)
        case avator(UIImage)
        case avatorMD5(String)
    }
    enum DependentId
    {
        case uid(String)
        case contactId(String)
    }
    class func UpdateContact(searchId:DependentId, properties:[ContactProperty])
    {
        guard properties.count > 0
            else {return}
        var contacts:[DBContact]
        switch searchId {
        case let .contactId(contactId):
            let unwarpContacts = Array(DBContact.Search(realm: DBManager.realm, type: .identifyId(contactId)))
            if unwarpContacts.count > 0
            {
                contacts = unwarpContacts
            }
            else
            {
                contacts = [DBContact.init(contactId: contactId, name: "")]
            }
        case let .uid(uid):
            let unwarpContacts = Array(DBContact.Search(realm: DBManager.realm, type: .uid(uid)))
            if  unwarpContacts.count > 0
            {
                contacts = unwarpContacts
            }
            else
            {
                contacts = [DBContact.init(uid:uid, name: "")]
            }
//        default:
//            break
        }
        write{
            for contact in contacts
            {
            properties.forEach{
                switch $0 {
                case let .uid(uid):
                    contact.uid = uid
                case let .lastMessage(message:message, timestamp:timestamp):
                    if let newValue = Double(timestamp),
                        let oldValue = Double(contact.lastMessageTimestamp),
                        newValue > oldValue
                    {
                        contact.unreadMessageCount += 1
                    }
                    else
                    {
                        contact.unreadMessageCount = 0
                    }
                    contact.lastMessage = message
                    contact.lastMessageTimestamp = timestamp

                case let .readTime(time):
                    contact.readTime = time
                    if let hasUnread = contact.hasUnreadMessage,
                        hasUnread == false
                    {
                        contact.unreadMessageCount = 0
                    }
                case let .name(name):
                    contact.name = name
                case let .avatorPath(path):
                    contact.avatorPath = path
                case let .avator(image):
                    contact.setAvator(image:image)
                case let .contactId(contactId):
                    contact.contactId = contactId
                case let .avatorMD5(md5):
                    contact.avatorMD5 = md5
                }
            }
            realm.updateOrNew(contact)
            }
        }
    }
    public class func UpdateSelfAvator()
    {
        MygoClientManager.sharedInstance.getAvator(completeHandler: { (success, image) in
            if success
            {
                let path = DBManager.DocumentsPath() + "myAvator.png"
                if let unwarpImage = image,
                    let data = UIImagePNGRepresentation(unwarpImage)
                {
                    DBManager.WriteFile(path: path, data: data, completion: {
                        IMDefault.UserAvatorPath = path
                    })
                }
            }
        })
    }
    public class func SearchOrNewContactWithIds(contactId:String, uid:String) -> DBContact
    {
        if let contact = DBManager.SearchContacts(condition: DBContact.SearchCondition.identifyId(contactId)).first
        {
            write {
                contact.uid = uid
            }
            return contact
        }
        else if let contact = DBManager.SearchContacts(condition: DBContact.SearchCondition.uidWithoutContactId(uid)).first
        {
            write {
                contact.contactId = contactId
            }
            return contact
        }
        else
        {
            let contact = DBContact.init()
            contact.contactId = contactId
            contact.uid = uid
            addContact(newContact: contact)
            
            return contact
        }
    }
    class func GetUnreadMessageCount() -> Int
    {
        return SearchContacts().reduce(0){ $0 + $1.unreadMessageCount }
    }
    class func IncrementID<T:Object>(_ type:T.Type) -> Int {
        guard let primaryKey = type.primaryKey()
            else {return -1}
        let key = (realm.objects(type).max(ofProperty: primaryKey) as Int? ?? 0) + 1
        return key
    }
    class func DocumentsPath() -> String {
        let filesPath = "\(NSHomeDirectory())/Documents\(FilesFolder)"
        print("===== file path:\n\(filesPath)")
        
        do {
            try FileManager.default.createDirectory(atPath: filesPath, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("Error creating directory: \(error.localizedDescription)")
        }
        return filesPath
    }

    class func WriteFile(path:String,data:Data,completion:(()->())? = nil)
    {
        do {
            try data.write(to: URL(fileURLWithPath: path))
            
        } catch {
            print("write file error")
        }
        completion?()
    }
    // App/Documents/(($name.)type.timeinterval)
    class func LocalPath(by type:DBMessage.contantType? = nil) -> String
    {
        var path = DocumentsPath()
        if let unwarppedType = type
        {
            switch unwarppedType
            {
            case let .text(name):
                path += ((name.characters.count > 0 ? name + "." : "")
                    + "\(Date.timeIntervalSinceReferenceDate)"
                    + ".txt")
            case let .image(name):
                path += ((name.characters.count > 0 ? name + "." : "")
                    + "\(Date.timeIntervalSinceReferenceDate)"
                    + ".png")
            case let .voice(name,_):
                path += ((name.characters.count > 0 ? name + "." : "")
                    + "\(Date.timeIntervalSinceReferenceDate)"
                    + ".m4a")
            case let .video(name):
                path += ((name.characters.count > 0 ? name + "." : "")
                    + "\(Date.timeIntervalSinceReferenceDate)"
                    + ".mp4")
                //        default:
                //            break
            }
        }
        return path
    }
    public class func deleteAll()
    {
        do {
            try FileManager.default.removeItem(atPath: DBManager.DocumentsPath())
            }
            catch{
                print("delete Documents folder failes:\n \(error)")
            }
        write {
            realm.deleteAll()
        }
    }
}


