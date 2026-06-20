import Foundation

public struct PetManifest: Codable, Equatable, Sendable {
    public let id: String
    public let displayName: String
    public let description: String
    public let spritesheetPath: String

    public init(id: String, displayName: String, description: String, spritesheetPath: String) {
        self.id = id
        self.displayName = displayName
        self.description = description
        self.spritesheetPath = spritesheetPath
    }
}

public struct PetPackageLocation: Equatable, Sendable {
    public let directory: URL
    public let manifestURL: URL
    public let spritesheetURL: URL

    public init(directory: URL, manifestURL: URL, spritesheetURL: URL) {
        self.directory = directory
        self.manifestURL = manifestURL
        self.spritesheetURL = spritesheetURL
    }
}

public enum PetAssetLocator {
    public enum LocateError: Error, Equatable {
        case packageNotFound
        case invalidManifest(URL)
        case missingSpritesheet(URL)
    }

    public static func findMimoPackage(
        startingAt startPath: String = FileManager.default.currentDirectoryPath,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default
    ) throws -> PetPackageLocation {
        for candidate in candidateDirectories(startingAt: startPath, environment: environment) {
            if let package = try? validatePackage(at: candidate, fileManager: fileManager) {
                return package
            }
        }
        throw LocateError.packageNotFound
    }

    public static func validatePackage(
        at directory: URL,
        fileManager: FileManager = .default
    ) throws -> PetPackageLocation {
        let manifestURL = directory.appendingPathComponent("pet.json")
        guard fileManager.fileExists(atPath: manifestURL.path) else {
            throw LocateError.invalidManifest(manifestURL)
        }

        let manifestData = try Data(contentsOf: manifestURL)
        let manifest = try JSONDecoder().decode(PetManifest.self, from: manifestData)
        let spritesheetURL = directory.appendingPathComponent(manifest.spritesheetPath)
        guard fileManager.fileExists(atPath: spritesheetURL.path) else {
            throw LocateError.missingSpritesheet(spritesheetURL)
        }

        return PetPackageLocation(directory: directory, manifestURL: manifestURL, spritesheetURL: spritesheetURL)
    }

    public static func candidateDirectories(
        startingAt startPath: String,
        environment: [String: String]
    ) -> [URL] {
        var candidates: [URL] = []

        if let explicit = environment["MIMO_PET_PACKAGE_DIR"], !explicit.isEmpty {
            candidates.append(URL(fileURLWithPath: explicit, isDirectory: true))
        }

        if let resourceURL = Bundle.main.resourceURL {
            candidates.append(resourceURL.appendingPathComponent("pets/mimo", isDirectory: true))
        }

        var current = URL(fileURLWithPath: startPath, isDirectory: true).standardizedFileURL
        for _ in 0..<8 {
            candidates.append(current.appendingPathComponent("pets/mimo", isDirectory: true))
            current.deleteLastPathComponent()
        }

        if let home = environment["HOME"], !home.isEmpty {
            candidates.append(URL(fileURLWithPath: home, isDirectory: true).appendingPathComponent(".codex/pets/mimo", isDirectory: true))
        }

        var seen = Set<String>()
        return candidates.filter { url in
            let path = url.standardizedFileURL.path
            if seen.contains(path) {
                return false
            }
            seen.insert(path)
            return true
        }
    }
}
