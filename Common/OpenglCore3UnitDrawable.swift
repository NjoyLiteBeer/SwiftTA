//
//  OpenglCore3UnitDrawable.swift
//  SwiftTA macOS
//
//  Created by Logan Jones on 10/4/18.
//  Copyright © 2018 Logan Jones. All rights reserved.
//

import Foundation

#if canImport(OpenGL)
import OpenGL
import OpenGL.GL3
import GLKit
#else
import Cgl
#endif


class OpenglCore3UnitDrawable {
    
    private let program: UnitProgram
    private var modelsTEMP: [UnitTypeId: UnitModel] = [:]
    private var models: [UnitTypeId: Model] = [:]
    
    struct FrameState {
        fileprivate let instances: [UnitTypeId: [Instance]]
        fileprivate init(_ instances: [UnitTypeId: [Instance]]) {
            self.instances = instances
        }
    }
    
    init(_ units: [UnitTypeId: UnitData], sides: [SideInfo], filesystem: FileSystem) throws {
        
        program = try makeProgram()
        
        let textures = ModelTexturePack(loadFrom: filesystem)
        models = units.mapValues { try! Model($0, textures, sides, filesystem) }
        modelsTEMP = units.mapValues { $0.model }
    }
    
    func setupNextFrame(_ viewState: GameViewState) -> FrameState {
        
        let viewportSize = (x: Float(viewState.viewport.size.width), y: Float(viewState.viewport.size.height))
        let viewportPosition = (x: Float(viewState.viewport.origin.x), y: Float(viewState.viewport.origin.y))
        
        return FrameState(buildInstanceList(
            for: viewState.objects,
            projectionMatrix: GLKMatrix4MakeOrtho(0, viewportSize.x, viewportSize.y, 0, -1024, 256),
            viewportPosition: viewportPosition))
    }
    
    func drawFrame(_ frameState: FrameState) {
        
        glActiveTexture(GLenum(GL_TEXTURE0))
        glUseProgram(program.id)
        glUniform1i(program.uniform_texture, 0)
        
        for (unitType, instances) in frameState.instances {
            guard let model = models[unitType] else { continue }
            glBindTexture(GLenum(GL_TEXTURE_2D), model.texture.id)
            glBindVertexArray(model.buffer.vao)
            for instance in instances {
                glUniformGLKMatrix4(program.uniform_vpMatrix, instance.vpMatrix)
                glUniformGLKMatrix3(program.uniform_normalMatrix, instance.normalMatrix)
                glUniformGLKMatrix4(program.uniform_pieces, instance.transformations)
                glDrawArrays(GLenum(GL_TRIANGLES), 0, GLsizei(model.vertexCount))
            }
        }
        
    }
    
    private func buildInstanceList(for objects: [GameViewObject], projectionMatrix: GLKMatrix4, viewportPosition: (x: Float, y: Float)) -> [UnitTypeId: [Instance]] {
        var instances: [UnitTypeId: [Instance]] = [:]
        
        for case let .unit(unit) in objects {
            guard let model = modelsTEMP[unit.type] else { continue }
            
            let viewMatrix = GLKMatrix4MakeTranslation(Float(unit.position.x) - viewportPosition.x, Float(unit.position.y) - viewportPosition.y, 0) * GLKMatrix4.taPerspective
            
            var draw = Instance(pieceCount: unit.pose.pieces.count)
            draw.set(
                vpMatrix: projectionMatrix * viewMatrix,
                normalMatrix: GLKMatrix3(topLeftOf: viewMatrix).inverseTranspose,
                transformations: unit.pose,
                for: model)
            instances[unit.type, default: []].append(draw)
        }
        
        return instances
    }
    
}

// MARK:- Model

private extension OpenglCore3UnitDrawable {
    struct Model {
        var buffer: OpenglVertexBufferResource
        var vertexCount: Int
        var texture: OpenglTextureResource
    }
}

private extension OpenglCore3UnitDrawable.Model {
    
    init(_ unit: UnitData, _ textures: ModelTexturePack, _ sides: [SideInfo], _ filesystem: FileSystem) throws {
        
        let palette = try Palette.texturePalette(for: unit.info, in: sides, from: filesystem)
        let atlas = UnitTextureAtlas(for: unit.model.textures, from: textures)
        let texture = try makeTexture(atlas, palette, filesystem)
        
        let vertexCount = countVertices(in: unit.model)
        var arrays = VertexArrays(capacity: vertexCount)
        collectVertexAttributes(pieceIndex: unit.model.root, model: unit.model, textures: atlas, vertexArray: &arrays)
        
        let buffer = OpenglVertexBufferResource(bufferCount: 4)
        glBindVertexArray(buffer.vao)
        
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), buffer.vbo[0])
        glBufferData(GLenum(GL_ARRAY_BUFFER), arrays.positions, GLenum(GL_STATIC_DRAW))
        let vertexAttrib: GLuint = 0
        glVertexAttribPointer(vertexAttrib, 3, GLenum(GL_DOUBLE), GLboolean(GL_FALSE), 0, nil)
        glEnableVertexAttribArray(vertexAttrib)
        
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), buffer.vbo[1])
        glBufferData(GLenum(GL_ARRAY_BUFFER), arrays.normals, GLenum(GL_STATIC_DRAW))
        let normalAttrib: GLuint = 1
        glVertexAttribPointer(normalAttrib, 3, GLenum(GL_DOUBLE), GLboolean(GL_FALSE), 0, nil)
        glEnableVertexAttribArray(normalAttrib)
        
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), buffer.vbo[2])
        glBufferData(GLenum(GL_ARRAY_BUFFER), arrays.texCoords, GLenum(GL_STATIC_DRAW))
        let texAttrib: GLuint = 2
        glVertexAttribPointer(texAttrib, 2, GLenum(GL_DOUBLE), GLboolean(GL_FALSE), 0, nil)
        glEnableVertexAttribArray(texAttrib)
        
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), buffer.vbo[3])
        glBufferData(GLenum(GL_ARRAY_BUFFER), arrays.pieceIndices.map { UInt8($0) }, GLenum(GL_STATIC_DRAW))
        let pieceAttrib: GLuint = 3
        glVertexAttribIPointer(pieceAttrib, 1, GLenum(GL_UNSIGNED_BYTE), 0, nil)
        glEnableVertexAttribArray(pieceAttrib)
        
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), 0)
        glBindVertexArray(0)
        
        self.buffer = buffer
        self.vertexCount = vertexCount
        self.texture = texture
    }
    
}

private func countVertices(in model: UnitModel) -> Int {
    return model.primitives.reduce(0) {
        (count, primitive) in
        let num = primitive.indices.count
        return count + (num >= 3 ? (num - 2) * 3 : 0)
    }
}

private func collectVertexAttributes(pieceIndex: UnitModel.Pieces.Index, model: UnitModel, textures: UnitTextureAtlas, vertexArray: inout VertexArrays) {
    
    let piece = model.pieces[pieceIndex]
    
    for primitiveIndex in piece.primitives {
        guard primitiveIndex != model.groundPlate else { continue }
        collectVertexAttributes(primitive: model.primitives[primitiveIndex], pieceIndex: pieceIndex, model: model, textures: textures, vertexArray: &vertexArray)
    }
    
    for child in piece.children {
        collectVertexAttributes(pieceIndex: child, model: model, textures: textures, vertexArray: &vertexArray)
    }
}

private func collectVertexAttributes(primitive: UnitModel.Primitive, pieceIndex: UnitModel.Pieces.Index, model: UnitModel, textures: UnitTextureAtlas, vertexArray: inout VertexArrays) {
    
    let vertices = primitive.indices.map({ model.vertices[$0] })
    let texCoords = textures.textureCoordinates(for: primitive.texture)
    
    switch vertices.count {
        
    case Int.min..<0: () // What?
    case 0: () // No Vertices
    case 1: () // A point?
    case 2: () // A line. Often used as a vector for sfx emitters
        
    case 3: // Single Triangle
        // Triangle 0,2,1
        let normal = makeNormal(0,2,1, in: vertices)
        vertexArray.append(
               texCoords.0, vertices[0],
               texCoords.2, vertices[2],
               texCoords.1, vertices[1],
               normal, pieceIndex
        )
        
    case 4: // Single Quad, split into two triangles
        // Triangle 0,2,1
        let normal = makeNormal(0,2,1, in: vertices)
        vertexArray.append(
               texCoords.0, vertices[0],
               texCoords.2, vertices[2],
               texCoords.1, vertices[1],
               normal, pieceIndex
        )
        // Triangle 0,3,2
        vertexArray.append(
               texCoords.0, vertices[0],
               texCoords.3, vertices[3],
               texCoords.2, vertices[2],
               normal, pieceIndex
        )
        
    default: // Polygon with more than 4 sides
        let normal = makeNormal(0,2,1, in: vertices)
        for n in 2 ..< vertices.count {
            vertexArray.append(
                   texCoords.0, vertices[0],
                   texCoords.2, vertices[n],
                   texCoords.1, vertices[n-1],
                   normal, pieceIndex
            )
        }
    }
}

private func makeNormal(_ a: Int, _ b: Int, _ c: Int, in vertices: [Vertex3]) -> Vector3 {
    let v1 = vertices[a]
    let v2 = vertices[b]
    let v3 = vertices[c]
    let u = v2 - v1
    let v = v3 - v1
    return u × v
}

private struct VertexArrays {
    var positions: [Vertex3]
    var normals: [Vector3]
    var texCoords: [Vertex2]
    var pieceIndices: [Int]
    
    init() {
        positions = []
        normals = []
        texCoords = []
        pieceIndices = []
    }
    init(capacity: Int) {
        positions = []
        positions.reserveCapacity(capacity)
        normals = []
        normals.reserveCapacity(capacity)
        texCoords = []
        texCoords.reserveCapacity(capacity)
        pieceIndices = []
        pieceIndices.reserveCapacity(capacity)
    }
    
    mutating func append(_ texCoord1: Vertex2, _ vertex1: Vertex3,
                         _ texCoord2: Vertex2, _ vertex2: Vertex3,
                         _ texCoord3: Vertex2, _ vertex3: Vertex3,
                         _ normal: Vector3,
                         _ pieceIndex: Int) {
        
        positions.append(vertex1)
        texCoords.append(texCoord1)
        normals.append(normal)
        pieceIndices.append(pieceIndex)
        
        positions.append(vertex2)
        texCoords.append(texCoord2)
        normals.append(normal)
        pieceIndices.append(pieceIndex)
        
        positions.append(vertex3)
        texCoords.append(texCoord3)
        normals.append(normal)
        pieceIndices.append(pieceIndex)
    }
    
    mutating func clear() {
        positions = []
        normals = []
        texCoords = []
        pieceIndices = []
    }
}

private func makeTexture(_ textureAtlas: UnitTextureAtlas, _ palette: Palette, _ filesystem: FileSystem) throws -> OpenglTextureResource {
    
    let data = textureAtlas.build(from: filesystem, using: palette)
    
    let texture = OpenglTextureResource()
    glBindTexture(GLenum(GL_TEXTURE_2D), texture.id)
    glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MAG_FILTER), GL_NEAREST)
    glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GL_NEAREST)
    glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_S), GL_REPEAT )
    glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_T), GL_REPEAT )
    
    data.withUnsafeBytes {
        glTexImage2D(
            GLenum(GL_TEXTURE_2D),
            0,
            GLint(GL_RGBA),
            GLsizei(textureAtlas.size.width),
            GLsizei(textureAtlas.size.height),
            0,
            GLenum(GL_RGBA),
            GLenum(GL_UNSIGNED_BYTE),
            $0)
    }
    
    printGlErrors(prefix: "Model Texture: ")
    return texture
}

// MARK:- Instance

private extension OpenglCore3UnitDrawable {
    struct Instance {
        var vpMatrix: GLKMatrix4
        var normalMatrix: GLKMatrix3
        var transformations: [GLKMatrix4]
    }
}

private let plaformSin: (Double) -> Double = sin
private let plaformCos: (Double) -> Double = cos

private extension OpenglCore3UnitDrawable.Instance {
    
    init(pieceCount: Int) {
        vpMatrix = GLKMatrix4Identity
        normalMatrix = GLKMatrix3Identity
        transformations = [GLKMatrix4](repeating: GLKMatrix4Identity, count: pieceCount)
    }
    
    mutating func set(vpMatrix: GLKMatrix4, normalMatrix: GLKMatrix3, transformations modelInstance: UnitModel.Instance, for model: UnitModel) {
        self.vpMatrix = vpMatrix
        self.normalMatrix = normalMatrix
        OpenglCore3UnitDrawable.Instance.applyPieceTransformations(model: model, instance: modelInstance, transformations: &transformations)
    }
    
    static func applyPieceTransformations(model: UnitModel, instance: UnitModel.Instance, transformations: inout [GLKMatrix4]) {
        applyPieceTransformations(pieceIndex: model.root, p: GLKMatrix4Identity, model: model, instance: instance, transformations: &transformations)
    }
    
    static func applyPieceTransformations(pieceIndex: UnitModel.Pieces.Index, p: GLKMatrix4, model: UnitModel, instance: UnitModel.Instance, transformations: inout [GLKMatrix4]) {
        let piece = model.pieces[pieceIndex]
        let anims = instance.pieces[pieceIndex]
        
        guard !anims.hidden else {
            applyPieceDiscard(pieceIndex: pieceIndex, model: model, transformations: &transformations)
            return
        }
        
        let offset = GLKVector3(piece.offset)
        let move = GLKVector3(anims.move)
        
        let rad2deg = Double.pi / 180
        let sin = GLKVector3( anims.turn.map { plaformSin($0 * rad2deg) } )
        let cos = GLKVector3( anims.turn.map { plaformCos($0 * rad2deg) } )
        
        let t = GLKMatrix4Make(
            cos.y * cos.z,
            (sin.y * cos.x) + (sin.x * cos.y * sin.z),
            (sin.x * sin.y) - (cos.x * cos.y * sin.z),
            0,
            
            -sin.y * cos.z,
            (cos.x * cos.y) - (sin.x * sin.y * sin.z),
            (sin.x * cos.y) + (cos.x * sin.y * sin.z),
            0,
            
            sin.z,
            -sin.x * cos.z,
            cos.x * cos.z,
            0,
            
            offset.x - move.x,
            offset.y - move.z,
            offset.z + move.y,
            1
        )
        
        let pt = GLKMatrix4Multiply(p, t)
        transformations[pieceIndex] = pt
        
        for child in piece.children {
            applyPieceTransformations(pieceIndex: child, p: pt, model: model, instance: instance, transformations: &transformations)
        }
    }
    
    static func applyPieceDiscard(pieceIndex: UnitModel.Pieces.Index, model: UnitModel, transformations: inout [GLKMatrix4]) {
        
        transformations[pieceIndex] = GLKMatrix4MakeTranslation(0, 0, -1000)
        
        let piece = model.pieces[pieceIndex]
        for child in piece.children {
            applyPieceDiscard(pieceIndex: child, model: model, transformations: &transformations)
        }
    }
    
}

// MARK:- Shader Loading

private struct UnitProgram {
    
    let id: GLuint
    
    let uniform_vpMatrix: GLint
    let uniform_normalMatrix: GLint
    let uniform_pieces: GLint
    let uniform_texture: GLint
    
    init(_ program: GLuint) {
        id = program
        uniform_vpMatrix = glGetUniformLocation(program, "vpMatrix")
        uniform_normalMatrix = glGetUniformLocation(program, "normalMatrix")
        uniform_pieces = glGetUniformLocation(program, "pieces")
        uniform_texture = glGetUniformLocation(program, "colorTexture")
    }
    
    init() {
        id = 0
        uniform_vpMatrix = -1
        uniform_normalMatrix = -1
        uniform_pieces = -1
        uniform_texture = -1
    }
    
    static var unset: UnitProgram { return UnitProgram() }
    
}

private func makeProgram() throws -> UnitProgram {
    
    let vertexShader = try compileShader(GLenum(GL_VERTEX_SHADER), source: vertexShaderCode)
    let fragmentShader = try compileShader(GLenum(GL_FRAGMENT_SHADER), source: fragmentShaderCode)
    let program = try linkShaders(vertexShader, fragmentShader)
    
    glDeleteShader(fragmentShader)
    glDeleteShader(vertexShader)
    
    printGlErrors(prefix: "Shader Programs: ")
    return UnitProgram(program)
}

private let vertexShaderCode: String = """
    #version 330 core

    layout (location = 0) in vec3 in_position;
    layout (location = 1) in vec3 in_normal;
    layout (location = 2) in vec2 in_texture;
    layout (location = 3) in uint in_offset;

    out vec3 fragment_position_m;
    out vec3 fragment_normal;
    smooth out vec2 fragment_texture;

    uniform mat4 vpMatrix;
    uniform mat3 normalMatrix;
    uniform mat4 pieces[40];

    void main(void) {
        vec4 position = pieces[in_offset] * vec4(in_position, 1.0);
        gl_Position = vpMatrix * position;
        fragment_position_m = vec3(position);
        fragment_normal = normalMatrix * in_normal;
        fragment_texture = in_texture;
    }
    """

private let fragmentShaderCode: String = """
    #version 330 core
    precision highp float;

    smooth in vec2 fragment_texture;

    out vec4 out_color;

    uniform sampler2D colorTexture;

    void main(void) {
        out_color = texture(colorTexture, fragment_texture);
    }
    """
//private let fragmentShaderCode: String = """
//    #version 330 core
//    precision highp float;
//
//    in vec3 fragment_position_m;
//    in vec3 fragment_normal;
//    smooth in vec2 fragment_texture;
//
//    out vec4 out_color;
//
//    uniform sampler2D colorTexture;
//    uniform vec3 lightPosition;
//    uniform vec3 viewPosition;
//    uniform vec4 objectColor;
//
//    void main(void) {
//
//        vec3 lightColor = vec3(1.0, 1.0, 1.0);
//
//        // ambient
//        float ambientStrength = 0.6;
//        vec3 ambient = ambientStrength * lightColor;
//
//        // diffuse
//        float diffuseStrength = 0.4;
//        vec3 norm = normalize(fragment_normal);
//        vec3 lightDir = normalize(lightPosition - fragment_position_m);
//        float diff = max(dot(norm, lightDir), 0.0);
//        vec3 diffuse = diffuseStrength * diff * lightColor;
//
//        // specular
//        float specularStrength = 0.1;
//        vec3 viewDir = normalize(viewPosition - fragment_position_m);
//        vec3 reflectDir = reflect(-lightDir, norm);
//        float spec = pow(max(dot(viewDir, reflectDir), 0.0), 32);
//        vec3 specular = specularStrength * spec * lightColor;
//
//        // all together now
//        vec4 lightContribution = vec4(ambient + diffuse + specular, 1.0);
//
//        if (objectColor.a == 0.0) {
//            out_color = lightContribution * texture(colorTexture, fragment_texture);
//        }
//        else {
//            out_color = lightContribution * objectColor;
//        }
//
//    }
//    """
