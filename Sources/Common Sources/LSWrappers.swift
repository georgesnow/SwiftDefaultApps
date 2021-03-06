/*
 * ----------------------------------------------------------------------------
 * "THE BEER-WARE LICENSE" (Revision 42):
 * <g.litenstein@gmail.com> wrote this file. As long as you retain this notice you
 * can do whatever you want with this stuff. If we meet some day, and you think
 * this stuff is worth it, you can buy me a beer in return., Gregorio Litenstein.
 * ----------------------------------------------------------------------------
 */

import AppKit

@_silgen_name("_LSCopySchemesAndHandlerURLs") func LSCopySchemesAndHandlerURLs(_: UnsafeMutablePointer<NSArray?>, _: UnsafeMutablePointer<NSMutableArray?>) -> OSStatus
@_silgen_name("_LSCopyAllApplicationURLs") func LSCopyAllApplicationURLs(_: UnsafeMutablePointer<NSMutableArray?>) -> OSStatus;
@_silgen_name("_UTCopyDeclaredTypeIdentifiers") func UTCopyDeclaredTypeIdentifiers() -> NSArray

/**
 Functions wrapping varied Launch Services tasks to be re-used throughout the application.
 */
class LSWrappers {
    
    /**
     Wrapper for commonly-used errors associated to Launch Services.
     - appNotFound: Application not found at given path/URL.
     - notAnApp: Found item at given path/URL but it is not an application bundle.
     - invalidFileURL: Trying to locate a file with a scheme different from file://
     - invalidScheme: Supplied URL Scheme is malformed or contains invalid characters.
     - deletedApp: An application bundle was found, but it is currently in the Trash.
     - serverErr: Can't communicate with the Launch Services server.
     - incompatibleSys: A valid application bundle was found, but it is not compatible with the current version of macOS.
     - invalidBundle: The specified bundle does not have a valid CFBundlePackageType entry.
     - defaultErr: Unknown error, for cases not covered above.
     */
    internal enum LSErrors:OSStatus {
        case appNotFound = -10814
        case notAnApp = -10811
        case invalidFileURL = 262
        case invalidScheme = -30774
        case deletedApp = -10660
        case serverErr = -10822
        case incompatibleSys = -10825
        case defaultErr = -10810
        case invalidBundle = -67857
        
        init(value: OSStatus) {
            switch value {
            case -10814: self = .appNotFound
            case -30774: self = .invalidScheme
            case -10811: self = .notAnApp
            case 262: self = .invalidFileURL
            case -10660: self = .deletedApp
            case -10822: self = .serverErr
            case -10825: self = .incompatibleSys
            case -67857: self = .invalidBundle
            default: self = .defaultErr
            }
            
        }
        /**
         Print a user-readable error message for each error code.
         
         - Parameter argument:
         app: The application specified by the user, which could conceivably be a URL, a file-path, a bundle identifier or even a display name.
         content: This is only used in the case the user supplies a malformed URL Scheme.
         
         - Returns: Human-readable error message specifying the problem, or unknown error if the problem is something not accounted for here.
         */
        func print(argument: (app: String, content: String)) -> String {
            switch self {
            case .notAnApp: return "\(argument.app) is not a valid application."
            case .appNotFound: return "No application found for \(argument.app)"
            case .invalidScheme: return "\(argument.content) is not a valid URL Scheme."
            case .invalidFileURL: return "\(argument.app) is not a valid filesystem URL."
            case .deletedApp: return "\(argument.app) cannot be accessed because it is in the Trash."
            case .serverErr: return "There was an error trying to communicate with the Launch Services Server."
            case .incompatibleSys: return "\(argument.app) is not compatible with the currently installed version of macOS."
            case .invalidBundle: return "\(argument.app) is not a valid Package."
            case .defaultErr: return "An unknown error has occurred."
            }
        }
    }
    /**
     Groups functions dealing with UTIs.
     */
    class UTType {
        /**
         Copies a list of file-extensions for a given UTI.
         - Parameter inUTI: A Uniform Type Identifier.
         - Returns: An array of strings corresponding to file-extensions for that UTI, or nil.
         */
        static func copyExtensionsFor(_ inUTI: String) -> [String]? {
            if let result = (UTTypeCopyAllTagsWithClass(inUTI as CFString, kUTTagClassFilenameExtension)?.takeRetainedValue()) {
                if let extensions = result as? [String] {
                    return extensions
                }
                else { return nil }
            }
            else { return nil }
        }
        /**
         Copies the bundle identifier of the application currently registered as the default handler for a given UTI.
         - Parameter inUTI: A Uniform Type Identifier.
         - Parameter inRoles: The specified Launch Services Role to query. Can correspond to "Editor", "Viewer", "Shell" or "None". By default, we are only concerned with viewers and editors (in that order).
         - Returns: The Bundle identifier or POSIX path of an application, or nil if no valid handler was found.
         */
        static func copyDefaultHandler (_ inUTI:String, inRoles: LSRolesMask = [LSRolesMask.viewer,LSRolesMask.editor], asPath: Bool = true) -> String? {
            if let value = LSCopyDefaultRoleHandlerForContentType(inUTI as CFString, inRoles) {
                let handlerID = value.takeRetainedValue() as String
                if (asPath == true) {
                    if let handlerURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: handlerID) {
                        return handlerURL.path
                    }
                    else { return nil }
                }
                else { return handlerID }
            }
            else { return nil }
        }
        /**
         Creates a list of all currently registered handlers for a given UTI.
         - Parameter inUTI: A Uniform Type Identifier.
         - Parameter inRoles: The specified Launch Services Role to query. Can correspond to "Editor", "Viewer", "Shell" or "None". By default, we are only concerned with viewers and editors (in that order).
         - Returns: An array of strings corresponding to the Bundle identifiers or POSIX paths of all currently registered handlers, or nil of none were found.
         */
        static func copyAllHandlers (_ inUTI:String, inRoles: LSRolesMask = [LSRolesMask.viewer,LSRolesMask.editor], asPath: Bool = true) -> Array<String>? {
            var handlers: Array<String> = []
            if let value = LSCopyAllRoleHandlersForContentType(inUTI as CFString, inRoles) {
                let handlerIDs = (value.takeRetainedValue() as! Array<String>)
                if (asPath == true) {
                    for handlerID in handlerIDs {
                        if let handlerURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: handlerID) {
                            handlers.append(handlerURL.path)
                        }
                    }
                }
                else { return handlerIDs }
            }
            else { return nil }
            return (handlers.isEmpty ? nil : handlers)
        }
        /**
         Creates a keyed dictionary of all currently-registered UTIs and their default handler. Excludes abstract entries like references to physical devices and such things we have no use for.
         - Returns: A dictionary with UTIs as keys and bundle identifiers as values.
         */
        static func copyAllUTIs () -> [String:String] {
            let UTIs = (UTCopyDeclaredTypeIdentifiers() as! Array<String>).filter() { UTTypeConformsTo($0 as CFString,"public.item" as CFString) || UTTypeConformsTo($0 as CFString,"public.content" as CFString)} // Ignore UTIs belonging to devices and such.
            var handlers:Array<String> = []
            for UTI in UTIs {
                if let handler = UTType.copyDefaultHandler(UTI) {
                    handlers.append(handler)
                }
                else {
                    handlers.append("No application set.")
                }
            }
            
            return Dictionary.init (keys: UTIs, values: handlers)
        }
        /**
         Changes the default handler for a given UTI.
         - See Also: `enum LSErrors` above.
         - Parameters:
         - inContent: A Uniform Type Identifier.
         - inBundleID: A bundle-identifier referring to a valid application bundle. Specifying "None" will disable the default handler for that UTI.
         - inRoles: The specified Launch Services Role to modify. Can correspond to "Editor", "Viewer", "Shell" or "None".
         - Returns: A status-code. `0` on success, or a value corresponding to various possible errors.
         */
        static func setDefaultHandler (_ inContent: String, _ inBundleID: String, _ inRoles: LSRolesMask = LSRolesMask.all) -> OSStatus {
            var retval: OSStatus = 0
            if (LSWrappers.isAppInstalled(withBundleID: inBundleID) == true) {
                retval = LSSetDefaultRoleHandlerForContentType(inContent as CFString, inRoles, inBundleID as CFString)
            }
            else { retval = kLSApplicationNotFoundErr }
            return retval
        }
    }
    /**
     Groups functions dealing with URL Schemes.
     */
    class Schemes {
        /**
         Traverses Info dictionaries of possible handlers for an URL Scheme and gets a display name, if available.
         - Parameter inScheme: An URL Scheme.
         - Returns: A display name, or `nil` if none was found.
         */
        static func getNameForScheme (_ inScheme: String) -> String? {
            var schemeName: String? = nil
            if let handlers = Schemes.copyAllHandlers(inScheme) {
                
                for handler in handlers {
                    
                    if let schemeDicts = (Bundle(path:handler)?.infoDictionary?["CFBundleURLTypes"] as? [[String:AnyObject]]) {
                        
                        for schemeDict in (schemeDicts.filter() { (($0["CFBundleURLSchemes"] as? [String])?.contains() {$0.caseInsensitiveCompare(inScheme) == .orderedSame}) == true } ) {
                            if let name = (schemeDict["CFBundleURLName"] as? String) {
                                
                                schemeName = name
                                return schemeName
                                
                            }
                            else { schemeName = nil }
                            
                        }
                    }
                }
                
            }
            return schemeName
        }
        /**
         Creates a list of all currently registered URL Schemes and their default handler.
         - Returns: A dictionary with URL Schemes as keys and bundle identifiers as values.
         */
        static func copySchemesAndHandlers() -> [String:String]? {
            var schemes_array: NSArray?
            var apps_array: NSMutableArray?
            if (LSCopySchemesAndHandlerURLs(&schemes_array, &apps_array) == 0) {
                if let URLArray = (apps_array! as NSArray) as? [URL] {
                    if let pathsArray = convertAppURLsToPaths(URLArray) {
                        
                        let schemesHandlers = Dictionary.init (keys: schemes_array as! [String], values: pathsArray)
                        return schemesHandlers
                    }
                    else { return nil }
                    
                }
                    
                else { return nil }
            }
            else { return nil }
        }
        /**
         Copies the bundle identifier of the application currently registered as the default handler for a given URL Scheme.
         - Parameter inScheme: A valid URL Scheme.
         - Returns: The Bundle identifier or POSIX path of an application, or nil if no valid handler was found.
         */
        static func copyDefaultHandler (_ inScheme:String, asPath: Bool = true) -> String? {
            
            if let value = LSCopyDefaultHandlerForURLScheme(inScheme as CFString) {
                let handlerID = value.takeRetainedValue() as String
                if (asPath == true) {
                    if let handlerURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: handlerID) {
                        return handlerURL.path
                    }
                    else { return nil }
                }
                else { return handlerID }
            }
            else { return nil }
        }
        /**
         Creates a list of all currently registered handlers for a given URL Scheme.
         - Parameter inScheme: A valid URL Scheme.
         - Returns: An array of strings corresponding to the Bundle identifiers or POSIX paths of all currently registered handlers, or nil of none were found.
         */
        static func copyAllHandlers (_ inScheme:String, asPath: Bool = true) -> Array<String>? {
            
            var handlers: Array<String> = []
            if let value = LSCopyAllHandlersForURLScheme(inScheme as CFString) {
                let handlerIDs = (value.takeRetainedValue() as! Array<String>)
                if (asPath == true) {
                    for handlerID in handlerIDs {
                        if let handlerURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: handlerID) {
                            handlers.append(handlerURL.path)
                        }
                    }
                }
                else { return handlerIDs }
            }
            else { return nil }
            return (handlers.isEmpty ? nil : handlers)
        }
        /**
         Changes the default handler for a given URL Scheme.
         - See Also: `enum LSErrors` above.
         - Parameters:
         - inScheme: A valid URL Scheme.
         - inBundleID: A bundle-identifier referring to a valid application bundle. Specifying "None" will disable the default handler for that URL Scheme.
         - Returns: A status-code. `0` on success, or a value corresponding to various possible errors.
         */
        static func setDefaultHandler (_ inScheme: String, _ inBundleID: String) -> OSStatus {
            var retval: OSStatus = kLSUnknownErr
            if let matches = inScheme =~ /"\\A[a-zA-Z][a-zA-Z0-9.+-]+$" {
                if (matches == true) {
                    if (LSWrappers.isAppInstalled(withBundleID:inBundleID) == true) {
                        retval = LSSetDefaultHandlerForURLScheme((inScheme as CFString), (inBundleID as CFString))
                    }
                    else { retval = kLSApplicationNotFoundErr }
                }
                else { retval = Int32(kURLUnsupportedSchemeError) }
            }
            else { retval = Int32(kURLUnsupportedSchemeError) }
            return retval
        }
    }
    
    /**
     Creates a list of all currently registered applications.
     - Returns: An array of strings corresponding to the paths of all applications currently registered with Launch Services.
     */
    static func copyAllApps () -> Array<String>? {
        var apps: NSMutableArray?
        if (LSCopyAllApplicationURLs(&apps) == 0) {
            if let appURLs = (apps! as NSArray) as? [URL] {
                if let pathsArray = convertAppURLsToPaths(appURLs) {
                    
                    return pathsArray
                    
                }
                else { return nil }
            }
            else { return nil }
        }
        else { return nil }
    }
    /**
     Checks whether a given application is registered with Launch Services.
     - Parameter withBundleID: A bundle identifier.
     - Returns: `true` if the bundle identifier is registered with Launch Services as an application, `false` otherwise.
     */
    static func isAppInstalled (withBundleID: String) -> Bool {
        let temp = withBundleID as CFString
        
        if (LSCopyApplicationURLsForBundleIdentifier(temp,nil)?.takeRetainedValue() as NSArray?) != nil {
            return true
        }
        else {
            return false
        }
    }
    /**
     Performs a myriad of sanity checks on user input corresponding to a possible application. The main purpose of this function is to make sure we're passing a value as sane as possible to the setHandler functions.
     - See Also: `enum LSErrors` above.
     - Parameter inParam: The application to locate. It might correspond to a file-system URL, a POSIX path, a display name, a bundle identifier, or "None".
     - Parameter outBundleID: This parameter is populated with a bundle identifier if a valid application bundle corresponding to the input parameter was found.
     - Returns: A status-code. `0` on success, or a value corresponding to various possible errors.
     */
    static func getBundleID (_ inParam: String, outBundleID: inout String?) -> OSStatus {
        outBundleID = nil
        var errCode = OSStatus()
        let filemanager = FileManager.default
        if (inParam == "None") { // None is a valid value for our dummy application.
            outBundleID = "cl.fail.lordkamina.ThisAppDoesNothing"
            return 0
        }
        if NSWorkspace.shared.absolutePathForApplication(withBundleIdentifier: inParam) != nil  { // Check whether we have a valid Bundle ID for an application.
            outBundleID = inParam
            return 0
        }
        else if let appPath = NSWorkspace.shared.fullPath(forApplication: inParam) { // Or an application designed by name
            if let bundle = Bundle(path:appPath) {
                if let type = bundle.getType(outError: &errCode) {
                    if (type == "APPL" || type == "FNDR") {
                        if let _ = bundle.bundleIdentifier {
                            outBundleID = bundle.bundleIdentifier
                            return 0
                        }
                        else { return kLSNotAnApplicationErr }
                    }
                    else { return kLSNotAnApplicationErr }
                }
                else { return errCode }
            }
            if (filemanager.fileExists(atPath: inParam) == true) { return kLSNotAnApplicationErr }
            else { return kLSApplicationNotFoundErr }
        }
            
        else {
            if let bundle = Bundle(path: inParam) { // Is it a valid bundle path?
                if let type = bundle.getType(outError: &errCode) {
                    if (type == "APPL") {
                        if let _ = bundle.bundleIdentifier {
                            outBundleID = bundle.bundleIdentifier
                            return 0
                        }
                        else { return kLSNotAnApplicationErr }
                    }
                    else { return kLSNotAnApplicationErr }
                }
                else { return errCode }
            }
            else {
                if (filemanager.fileExists(atPath: inParam) == true) { // Maybe it's a valid file path, but not an app bundle?
                    return kLSNotAnApplicationErr
                }
                if let url = URL(string: inParam) { // Let's fallback to an URL.
                    if (url.path != "") {
                        if (url.isFileURL == true) {
                            if (filemanager.fileExists(atPath: url.path) == true) { //Is it a valid app URL?
                                if let bundle = Bundle(url: url) {
                                    if let type = bundle.getType(outError: &errCode) {
                                        if (type == "APPL") {
                                            outBundleID = bundle.bundleIdentifier!
                                            return 0
                                        }
                                        else { return kLSNotAnApplicationErr }
                                    }
                                    else { return errCode }
                                }
                                else { return kLSNotAnApplicationErr } // Maybe it's a valid file URL, but not an app bundle?
                            }
                            else {
                                return kLSApplicationNotFoundErr
                            } // No application found at this location.
                        }
                        else { return kLSNotAnApplicationErr }
                    }
                    else {
                        if (url.isFileURL == false) { return Int32(NSFileReadUnsupportedSchemeError) }
                    }
                }
                else {
                    return kLSNotAnApplicationErr
                }
            }
        }
        return kLSUnknownErr
    }
    /**
     Creates a list of UTIs and URL Schemes an application claims to be able to handle.
     - Note: We perform little if any sanity checks in this function because it is not intended to be exposed to user input.
     - Parameter inApp: A POSIX path corresponding to a valid application bundle.
     - Returns: A dictionary of sets containing a list of strings corresponding to URL Schemes and Uniform Type Identifiers listed in CFBundleURLTypes and CFBundleDocumentTypes respectively.
     */
    static func copySchemesAndUTIsForApp (_ inApp: String) -> [String:[String:Set<String>]]? {
        var handledUrlSchemes: [String:Set<String>] = ["Viewer":[]]
        var handledUTIs: [String:Set<String>] = ["Editor":[],"Viewer":[],"Shell":[]]
        var handledTypes: [String:[String:Set<String>]] = [:]
        if let infoDict = Bundle(path: inApp)?.infoDictionary {
            guard ((infoDict["CFBundlePackageType"] as? String) == "APPL") else { return nil }
            if let schemeDicts = (infoDict["CFBundleURLTypes"] as? [[String:AnyObject]]) {
                for schemeDict in schemeDicts {
                    if let schemesArray = (schemeDict["CFBundleURLSchemes"] as? [String]) {
                        handledUrlSchemes["Viewer"]!.formUnion(schemesArray)
                    }
                }
            }
            if let utiDicts = (infoDict["CFBundleDocumentTypes"] as? [[String:AnyObject]]) {
                var utiArray: [String] = []
                for utiDict in utiDicts.filter({ ($0["CFBundleTypeRole"] as? String == "Editor" || $0["CFBundleTypeRole"] as? String == "Viewer" || $0["CFBundleTypeRole"] as? String == "Shell" || $0["CFBundleTypeRole"] == nil) }) {
                    let typeRole = utiDict["CFBundleTypeRole"] as? String ?? "Viewer"
                    if let utiArray = (utiDict["LSItemContentTypes"] as? [String]) {
                        handledUTIs[typeRole]!.formUnion(utiArray)
                    }
                    else if let fileExtArray = (utiDict["CFBundleTypeExtensions"] as? [String]) {
                        for fileExt in fileExtArray {
                            if let newUTI = (UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, fileExt as CFString, "public.content" as CFString)?.takeRetainedValue() as String?) {
                                
                                if ((!UTTypeIsDynamic(newUTI as CFString)) && (handledUTIs[typeRole]!.index(of:newUTI) == nil)) {
                                    utiArray.append(newUTI)
                                }
                            }
                        }
                    }
                    handledUTIs[typeRole]!.formUnion(utiArray)
                }
            }
        }
        handledTypes["URLs"] = !handledUrlSchemes.isEmpty ? handledUrlSchemes : [:]
        handledTypes["UTIs"] = !handledUTIs.isEmpty ? handledUTIs : [:]
        return handledTypes
    }
}
