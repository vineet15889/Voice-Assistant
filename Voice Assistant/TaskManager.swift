//
//  TaskManager.swift
//  Voice Assistant
//
//  Created by Vineet Rai on 12/06/22.
//

import Foundation

enum taskList{
    case contact
    case music
    case phone
}

struct Task {
    var isCompleted = false
    var type:taskList?
}

struct ContactTask{
    var firstName:String?
    var laStName:String?
    var phone:Int?
    var task = Task()
    var taskList = ["name", "phone Number"]
}
