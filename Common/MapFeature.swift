//
//  MapFeature.swift
//  TAassets
//
//  Created by Logan Jones on 3/23/18.
//  Copyright © 2018 Logan Jones. All rights reserved.
//

import Foundation


struct MapFeatureInfo {
    
    var name: String
    var footprint: Size2D
    var height: Int
    
    var gafFilename: String
    var primaryGafItemName: String
    var shadowGafItemName: String?
    
    var properties: [String: String]
    
}

extension MapFeatureInfo {
    
    init(name: String, properties: [String: String]) {
        self.name = name
        self.properties = properties
        
        footprint = Size2D(width: Int(properties["footprintx"] ?? "1") ?? 1,
                           height: Int(properties["footprintz"] ?? "1") ?? 1)
        height = Int(properties["height"] ?? "0") ?? 0
        
        gafFilename = properties["filename"] ?? ""
        primaryGafItemName = properties["seqname"] ?? ""
        shadowGafItemName = properties["seqnameshad"]
    }
    
}

extension MapFeatureInfo {
    
    typealias FeatureInfoCollection = [String: MapFeatureInfo]
    
    
    static func collectFeatures(named featureNames: Set<String>, strartingWith planet: String, from filesystem: FileSystem) -> FeatureInfoCollection {
        
        guard let featuresDirectory = filesystem.root[directory: "features"] else { return [:] }
        
        var features: FeatureInfoCollection = [:]
        
        let planetDirectoryName = directoryName(forPlanet: planet)
        if !planetDirectoryName.isEmpty, let planetDirectory = featuresDirectory[directory: planetDirectoryName] {
            let planetFeatures = collectFeatures(named: featureNames, in: planetDirectory, of: filesystem)
            features = planetFeatures
        }
        
        if features.count >= featureNames.count {
            return features
        }
        
        if let allWorldsDirectory = featuresDirectory[directory: "All Worlds"] {
            let allWorldsFeatures = collectFeatures(named: featureNames, in: allWorldsDirectory, of: filesystem)
            features.merge(allWorldsFeatures, uniquingKeysWith: { (a, b) in b })
        }
        
        if features.count >= featureNames.count {
            return features
        }
        
        for directory in featuresDirectory.items.compactMap({ $0.asDirectory() }) {
            guard !FileSystem.compareNames(directory.name, planetDirectoryName) else { continue }
            guard !FileSystem.compareNames(directory.name, "All Worlds") else { continue }
            
            let moreFeatures = collectFeatures(named: featureNames, in: directory, of: filesystem)
            features.merge(moreFeatures, uniquingKeysWith: { (a, b) in b })
            
            if features.count >= featureNames.count {
                return features
            }
        }
        
        return features
    }
    
    static func collectFeatures(named featureNames: Set<String>, from filesystem: FileSystem) -> FeatureInfoCollection {
        let featuresDirectory = filesystem.root[directory: "features"] ?? FileSystem.Directory()
        let features = featuresDirectory.items
            .compactMap { $0.asDirectory() }
            .map { collectFeatures(named: featureNames, in: $0, of: filesystem) }
            .reduce([:]) { $0.merging($1, uniquingKeysWith: { (a, b) in b }) }
        return features
    }
    
    static func collectFeatures(named featureNames: Set<String>, in directory: FileSystem.Directory, of filesystem: FileSystem) -> FeatureInfoCollection {
        let features = directory.items
            .compactMap { $0.asFile() }
            .filter { $0.hasExtension("tdf") }
            .compactMap { try? collectFeatures(named: featureNames, in: $0, of: filesystem) }
            .reduce([:]) { $0.merging($1, uniquingKeysWith: { (a, b) in b }) }
        return features
    }
    
    static func collectFeatures(named featureNames: Set<String>, in tdf: FileSystem.File, of filesystem: FileSystem) throws -> FeatureInfoCollection {
        
        var found = FeatureInfoCollection()
        
        let parser = TdfParser(try filesystem.openFile(tdf))
        while let object = parser.skipToNextObject() {
            if featureNames.contains(object) {
                let info = MapFeatureInfo(name: object, properties: parser.extractObject().properties)
                found[object] = info
            }
            else {
                parser.skipObject()
            }
        }
        
        return found
    }
    
}

private extension MapFeatureInfo {
    
    static func directoryName(forPlanet planet: String) -> String {
        switch planet.lowercased() {
        case "archipelago":
            return "archi"
        case "green planet":
            return "green"
        case "lunar":
            return "moon"
        case "red planet":
            return "mars"
        case "water world":
            return "water"
        default:
            return planet
        }
    }
    
}
