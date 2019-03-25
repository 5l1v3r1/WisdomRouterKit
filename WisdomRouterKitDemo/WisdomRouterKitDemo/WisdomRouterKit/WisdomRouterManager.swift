//
//  WisdomRouterManager.swift
//  WisdomRouterKitDemo
//
//  Created by jianfeng on 2019/3/15.
//  Copyright © 2019年 All over the sky star. All rights reserved.
//

import UIKit

class WisdomRouterManager: NSObject {
    static let shared = WisdomRouterManager()
    
    private let Dot = "."
    
    private let errorCount: Int = 5
    
    /** 注册控制器值 */
    private(set) var vcClassValue: [String: WisdomRouterRegisterInfo] = [:]
    
    /** 注册模型属性值 */
    private(set) var modelPropertyList: [String: [String]] = [:]
    
    func register(vcClassType: UIViewController.Type) -> WisdomRouterResult {
        let cls = NSStringFromClass(vcClassType)
        let value = cls.components(separatedBy: Dot)
        guard let info = vcClassValue[value.last!] else {
            let newinfo = WisdomRouterRegisterInfo.init(vcClassType: vcClassType)
            vcClassValue[value.last!] = newinfo
            return WisdomRouterResult(vcClassType: vcClassType, info: newinfo)
        }
        return WisdomRouterResult(vcClassType: vcClassType, info: info)
    }
    
    func register(vcClassType: UIViewController.Type, modelName: String, modelClassType: WisdomRouterModel.Type) -> WisdomRouterResult {
        let cls = NSStringFromClass(vcClassType)
        let value = cls.components(separatedBy: Dot)
        if vcClassValue[value.last!] == nil {
            vcClassValue[value.last!] = WisdomRouterRegisterInfo.init(vcClassType: vcClassType)
        }

        let clsM = NSStringFromClass(modelClassType)
        if modelPropertyList[clsM] == nil{
            let propertyList = WisdomRouterManager.propertyList(targetClass: modelClassType)
            modelPropertyList[clsM] = propertyList
        }
        
        var info = vcClassValue[value.last!]!
        if info.modelList.count > 0{
            for obj in info.modelList{
                if obj.modelName == modelName {
                    return WisdomRouterResult(vcClassType: vcClassType, info: info)
                }
            }
        }
        info.add(model: WisdomRouterRegisterModel(modelName: modelName, modelClass: modelClassType))
        vcClassValue[value.last!] = info
        return WisdomRouterResult(vcClassType: vcClassType, info: info)
    }

    @discardableResult
    func register(vcClassType: UIViewController.Type, handerName: String, hander: @escaping WisdomRouterClosure) -> WisdomRouterHanderResult{
        let cls = NSStringFromClass(vcClassType)
        let value = cls.components(separatedBy: Dot)
        if vcClassValue[value.last!] == nil {
            vcClassValue[value.last!] = WisdomRouterRegisterInfo.init(vcClassType: vcClassType)
        }

        var info = vcClassValue[value.last!]!
        if info.handerList.count > 0{
            for obj in info.handerList{
                if obj.handerName == handerName {
                    return WisdomRouterHanderResult(vcClassType: vcClassType, info: info)
                }
            }
        }
        info.add(hander: WisdomRouterRegisterHander(handerName: handerName, handerValue: hander))
        vcClassValue[value.last!] = info
        return WisdomRouterHanderResult(vcClassType: vcClassType, info: info)
    }

    func router(targetVC: String) -> UIViewController{
        if vcClassValue[targetVC] == nil {
            WisdomRouterManager.showError(error: targetVC+"\n未注册\n请检查代码")
            return UIViewController()
        }
        
        guard let vcClassType = vcClassValue[targetVC]!.vcClassType else {
            return UIViewController()
        }
        return vcClassType.init()
    }

    func router(targetVC: String, param: WisdomRouterParam) -> UIViewController {
        if vcClassValue[targetVC] == nil {
            WisdomRouterManager.showError(error: targetVC+"\n未注册\n请检查代码")
            return UIViewController()
        }
        guard let vcClassType = vcClassValue[targetVC]!.vcClassType else {
            return UIViewController()
        }
        var error = ""
        let target = vcClassType.init()
        if WisdomRouterManager.hasPropertyList(targetClass: vcClassType, targetParamKey: param.valueTargetKey){
            if param.valueClass == WisdomRouterModel.self {
                error = setPropertyList(targetVC: targetVC, param: param, target: target)
            }else if param.valueClass == WisdomRouterModelList.self {
                error = setListPropertyList(targetVC: targetVC, param: param, target: target)
            }else{
                target.setValue(param.value, forKey: param.valueTargetKey)
            }
        }else{
            error = param.valueTargetKey+"\n属性查找失败\n请检查代码"
        }
        if error.count > errorCount {
            WisdomRouterManager.showError(error: error)
        }
        return target
    }

    func router(targetVC: String, hander: WisdomRouterHander) -> UIViewController {
        if vcClassValue[targetVC] == nil {
            WisdomRouterManager.showError(error: targetVC+"\n未注册\n请检查代码")
            return UIViewController()
        }
        guard let vcClassType = vcClassValue[targetVC]!.vcClassType else {
            return UIViewController()
        }
        var target = vcClassType.init()
        if WisdomRouterManager.hasPropertyList(targetClass: vcClassType, targetParamKey: hander.valueTargetKey){
            let res = setHanderProperty(targetVC: target, target: targetVC, hander: hander)
            target = res.0
            if res.1.count > errorCount {
                WisdomRouterManager.showError(error: res.1)
            }
        }else{
            WisdomRouterManager.showError(error: hander.valueTargetKey+"\nHander查找失败\n请检查代码")
        }
        return target
    }

    func router(targetVC: String, param: WisdomRouterParam, hander: WisdomRouterHander) -> UIViewController {
        if vcClassValue[targetVC] == nil {
            WisdomRouterManager.showError(error: targetVC+"\n未注册\n请检查代码")
            return UIViewController()
        }
        guard let vcClassType = vcClassValue[targetVC]!.vcClassType else {
            return UIViewController()
        }
        var errorStr = ""
        var target = vcClassType.init()
        if WisdomRouterManager.hasPropertyList(targetClass: vcClassType, targetParamKey: hander.valueTargetKey){
            let res = setHanderProperty(targetVC: target, target: targetVC, hander: hander)
            target = res.0
            errorStr = res.1
        }else{
            errorStr = hander.valueTargetKey+"\nHander查找失败\n请检查代码\n"
        }
        
        if WisdomRouterManager.hasPropertyList(targetClass: vcClassType, targetParamKey: param.valueTargetKey){
            if param.valueClass == WisdomRouterModel.self {
                errorStr = errorStr + " \n" + setPropertyList(targetVC: targetVC, param: param, target: target)
            }else if param.valueClass == WisdomRouterModelList.self {
                errorStr = errorStr + " \n" + setListPropertyList(targetVC: targetVC, param: param, target: target)
            }else{
                target.setValue(param.value, forKey: param.valueTargetKey)
            }
        }else{
            errorStr = errorStr + " \n" + param.valueTargetKey+"\n属性查找失败\n请检查代码"
        }
        if errorStr.count > errorCount {
            WisdomRouterManager.showError(error: errorStr)
        }
        return target
    }

    func router(targetVC: String, params: [WisdomRouterParam], handers: [WisdomRouterHander]) -> UIViewController {
        if vcClassValue[targetVC] == nil {
            WisdomRouterManager.showError(error: targetVC+"\n未注册\n请检查代码")
            return UIViewController()
        }
        guard let vcClassType = vcClassValue[targetVC]!.vcClassType else {
            return UIViewController()
        }
        var errorStr = ""
        let target = vcClassType.init()
        
        
        
        
        
        for param in params {
            if WisdomRouterManager.hasPropertyList(targetClass: vcClassType, targetParamKey: param.valueTargetKey){
                if param.valueClass == WisdomRouterModel.self {
                    errorStr = errorStr + " \n" + setPropertyList(targetVC: targetVC, param: param, target: target)
                }else if param.valueClass == WisdomRouterModelList.self {
                    errorStr = errorStr + " \n" + setListPropertyList(targetVC: targetVC, param: param, target: target)
                }else{
                    target.setValue(param.value, forKey: param.valueTargetKey)
                }
            }else{
                errorStr = errorStr  + param.valueTargetKey+"\n属性查找失败\n请检查代码"
            }
        }

        if errorStr.count > errorCount {
            WisdomRouterManager.showError(error: errorStr)
        }
        return target
    }

    /// Hander属性赋值
    private func setHanderProperty(targetVC: UIViewController, target: String,
                                   hander: WisdomRouterHander) -> (UIViewController, String) {
        let registerInfo = vcClassValue[target]!
        for handerInfo in registerInfo.handerList {
            if handerInfo.handerName == hander.valueTargetKey {
                let VC = handerInfo.handerValue(hander.value!,targetVC)
                return (VC, "")
            }
        }
        return (targetVC, hander.valueTargetKey+"\nHander未注册\n请检查代码\n")
    }

    /// model属性赋值
    private func setPropertyList(targetVC: String, param: WisdomRouterParam, target: UIViewController)->String{
        let registerInfo = vcClassValue[targetVC]!
        for modelInfo in registerInfo.modelList {
            if modelInfo.modelName == param.valueTargetKey {
                if let modelClass = modelInfo.modelClass! as? WisdomRouterModel.Type {
                    let model = modelClass.init()
                    let classStr = NSStringFromClass(model.classForCoder)
                    let propertyList = modelPropertyList[classStr] ?? []
                    
                    for property in propertyList {
                        let value = param.keyValue.first![property]
                        model.setValue(value, forKey: property)
                    }
                    target.setValue(model, forKey: modelInfo.modelName)
                    return ""
                }
            }
        }
        return param.valueTargetKey+"\n属性类未注册\n请检查代码\n"
    }

    /// modelList属性赋值
    private func setListPropertyList(targetVC: String, param: WisdomRouterParam, target: UIViewController)->String{
        let registerInfo = vcClassValue[targetVC]!
        for modelInfo in registerInfo.modelList {
            if modelInfo.modelName == param.valueTargetKey {
                
                if let modelClass = modelInfo.modelClass! as? WisdomRouterModel.Type {
                    let classStr = NSStringFromClass(modelClass)
                    let propertyList = modelPropertyList[classStr] ?? []
                    var modelList: [WisdomRouterModel] = []
                    
                    for keyValue in param.keyValue {
                        let model = modelClass.init()
                        
                        for property in propertyList {
                            let value = keyValue[property]
                            model.setValue(value, forKey: property)
                        }
                        modelList.append(model)
                    }
                    target.setValue(modelList, forKey: modelInfo.modelName)
                    return ""
                }
            }
        }
        return param.valueTargetKey+"\n属性类未注册\n请检查代码\n"
    }
    
    class func hasPropertyList(targetClass: AnyClass, targetParamKey: String) -> Bool {
        var count: UInt32 = 0
        let list = class_copyPropertyList(targetClass, &count)
        
        for i in 0..<Int(count) {
            let pty = list?[i]
            let cName = property_getName(pty!)
            let name = String(utf8String: cName)
            if name == targetParamKey{
                free(list)
                return true
            }
        }
        free(list)
        return false
    }
    
    class func propertyList(targetClass: WisdomRouterModel.Type) -> [String] {
        var count: UInt32 = 0
        var nameLsit: [String] = []
        let list = class_copyPropertyList(targetClass.classForCoder(), &count)
        
        for i in 0..<Int(count) {
            let pty = list?[i]
            let cName = property_getName(pty!)
            let name = String(utf8String: cName)
            if name != nil{
                nameLsit.append(name!)
            }
        }
        free(list)
        return nameLsit
    }
    
    class func showError(error: String){
        let label = UILabel()
        label.layer.cornerRadius = 5
        label.layer.masksToBounds = true
        label.backgroundColor = UIColor(white: 0.8, alpha: 0.8)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.text = error
        label.sizeToFit()
        label.textColor = UIColor.red
        UIApplication.shared.keyWindow?.addSubview(label)
        label.center = UIApplication.shared.keyWindow!.center
        
        DispatchQueue.main.asyncAfter(deadline: .now()+8, execute:{
            label.removeFromSuperview()
        })
    }
}
