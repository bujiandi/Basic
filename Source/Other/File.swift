import Foundation

public func ==(lhs:File, rhs:File) -> Bool { return lhs.fullPath == rhs.fullPath }

public struct File : Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    
    // MARK: - CustomDebugStringConvertible
    public var debugDescription: String { return fullPath }
    
    // MARK: - File init
    public init(fullPath:String) {
        set(path: fullPath)
    }
    public init(rootPath:String, fileName:String) {
        set(path: (rootPath as NSString).appendingPathComponent(fileName))
    }
    public init(rootFile:File, fileName:String) {
        set(path: (rootFile.fullPath as NSString).appendingPathComponent(fileName))
    }
    private mutating func set(path:String) {
        self.fullPath = path
    }
    
    public var url:URL { return URL(fileURLWithPath: fullPath) }
    
    // MARK: 文件属性
    private var _fileAttributes:[FileAttributeKey : Any]?
    public var fileAttributes:[FileAttributeKey : Any] { return _fileAttributes ?? [:] }
    
    // MARK: 文件路径
    public var fullPath:String = "" {
        didSet {
            do {
                _fileAttributes = try FileManager.default.attributesOfItem(atPath: fullPath) as [FileAttributeKey : Any]
                
            } catch {}
        }
    }
    
    
    // MARK: - CustomStringConvertible
    public var description: String {
        return fullPath.components(separatedBy: "/").last!
    }
    

    // MARK: 文件大小
    public var fileSize:UInt64 {
        if !isExists { return 0 }
        let size:UInt64 = fileAttributes[.size] as! UInt64
        return size
    }
    
    // MARK: 判断目录中存在指定 1-n个文件名
    public func existsFileName(names:[String]) -> Bool {
        if names.count == 0 { return false }
        var names = names
        let fileManager:FileManager = FileManager.default
        do {
            let fileNames:[String] = try fileManager.contentsOfDirectory(atPath: fullPath)
            for fileName in fileNames {
                if names.count == 0 { break }
                if let index = names.firstIndex(where: { $0 == fileName })  {
                    names.remove(at: index)
                }
            }
            return names.count == 0
        } catch {}
        return false
    }
    
    //删除文件或文件夹
    @discardableResult
    public func deleteFile() -> Bool {
//        let chilerFiles = FileManager.default.subpaths(atPath: fullPath) ?? []
        
        let chilerFiles = self.subFileList //File.subpaths
        
        if chilerFiles.count > 0 {
            for file in chilerFiles where file.isExists {
                try? FileManager.default.removeItem(atPath: file.fullPath)
            }
            return true
        }else{
            do {
                try FileManager.default.removeItem(atPath: fullPath)
                return true
            } catch {}
        }

        return false
    }
    
    // MARK: 创建所有不存在的父路径
    @discardableResult
    public func makeParentDirs() -> Bool {
        let fileManager = FileManager.default
        let parentPath = (fullPath as NSString).deletingLastPathComponent
        var isDirectory:ObjCBool = false
        let isExists = fileManager.fileExists(atPath: parentPath, isDirectory: &isDirectory)
        if !(isExists && isDirectory.boolValue) {
            do {
                try fileManager.createDirectory(atPath: parentPath, withIntermediateDirectories: true, attributes: nil)
            } catch let error {
                print(error)
                return false
            }
        }
        return true
    }
    
    // MARK: 拷贝文件到指定路径 自动创建所有父路径
    @discardableResult
    public func copyToPath(path:String) -> Bool {
        makeParentDirs()
        do {
            try FileManager.default.copyItem(atPath: fullPath, toPath: path)
        } catch let error {
            print(error)
            return false
        }
        return true
    }
    
    // MARK: 移动文件到指定路径 自动创建所有父路径
    @discardableResult
    public func moveToPath(path:String) -> Bool {
        makeParentDirs()
        do {
            try FileManager.default.moveItem(atPath: fullPath, toPath: path)
        } catch let error {
            print(error)
            return false
        }
        return true
    }
    
    // MARK: 文件重命名
    @discardableResult
    public mutating func rename(newFileName:String) -> Bool {
        //print("oldPath:\(fullPath)")
        let parent = (fullPath as NSString).deletingLastPathComponent
        let newPath = (parent as NSString).appendingPathComponent(newFileName)
        //print("newPath:\(newPath)")
        let success = moveToPath(path: newPath)
        if success { self.fullPath = newPath }
        return success
    }

    
    // MARK: 父目录
    public var parentFile:File { return File(fullPath: (fullPath as NSString).deletingLastPathComponent) }
    
    // MARK: 文件名
    public var fileName:String {
        return fullPath.components(separatedBy: "/").last!
    }
    
    
    // MARK: 文件状态
    public var isExecutable:Bool { return FileManager.default.isExecutableFile(atPath: fullPath) }
    public var isDeletable:Bool { return FileManager.default.isDeletableFile(atPath: fullPath) }
    public var isDirectory:Bool {
        var directory:ObjCBool = false
        FileManager.default.fileExists(atPath: fullPath, isDirectory: &directory)
        return directory.boolValue
    }
    public var isExists:Bool { return FileManager.default.fileExists(atPath: fullPath) }
    
    public subscript(subFileName:String) -> File? {
        for file in subFileList where file.fileName == subFileName {
            return file
        }
        return nil
    }
    // MARK: 所有子文件
    public var subFileList:[File] {
        var files:[File] = []
        let fileManager:FileManager = FileManager.default
        do {
            let fileNames:[String] = try fileManager.contentsOfDirectory(atPath: fullPath)
            for fileName in fileNames {
                files.append(File(rootPath: fullPath, fileName: fileName))
//                (fullPath as NSString).deletingPathExtension
            }
            
            
        } catch {}
        return files
    }
    public var fileExtension:String {
        return fileName.components(separatedBy:".").last ?? ""
    }
    public func getFileExtension(exceptionFileExtensions:[String]) -> String {
        for exceptionFileExtension in exceptionFileExtensions where fileName.hasSuffix(exceptionFileExtension) {
            return exceptionFileExtension.hasPrefix(".") ? String(exceptionFileExtension[exceptionFileExtension.index(exceptionFileExtension.startIndex, offsetBy: 1)...]) : exceptionFileExtension
        }
        return fileExtension
    }
    
    // MARK: - 系统默认文件路径
    public static func systemDirectory(pathType:FileManager.SearchPathDirectory, domainMask:FileManager.SearchPathDomainMask = .userDomainMask) -> File {
        let path = NSSearchPathForDirectoriesInDomains(pathType, domainMask, true)[0]
        return File(fullPath: path)
    }
    
    public static var documentDirectory:File { return systemDirectory(pathType: .documentDirectory) }
    public static var downloadDirectory:File { return systemDirectory(pathType: .downloadsDirectory) }
    public static var cacheDirectory:File { return systemDirectory(pathType: .cachesDirectory) }

    public static func homeDirectoryForUser(userName:String) -> File {
        if let path = NSHomeDirectoryForUser(userName) {
            return File(fullPath: path)
        }
        return File(fullPath: NSHomeDirectory())
    }
    public static var homeDirectory:File { return File(fullPath: NSHomeDirectory()) }
    public static var temporaryDirectory:File { return File(fullPath: NSTemporaryDirectory()) }
    public static var openStepRootDirectory:File { return File(fullPath: NSOpenStepRootDirectory()) }
    public static var fullUserName:String { return NSFullUserName() }
    public static var userName:String { return NSUserName() }
}
