//
//  UnitView+OpenglCore33Renderer.swift
//  TAassets
//
//  Created by Logan Jones on 5/17/18.
//  Copyright © 2018 Logan Jones. All rights reserved.
//

import Cocoa
import OpenGL
import OpenGL.GL3
import SwiftTA_Core

class Core33OpenglUnitViewRenderer: OpenglUnitViewRenderer {
    
    static let desiredPixelFormatAttributes: [NSOpenGLPixelFormatAttribute] = [
        UInt32(NSOpenGLPFAAllowOfflineRenderers),
        UInt32(NSOpenGLPFAAccelerated),
        UInt32(NSOpenGLPFADoubleBuffer),
        UInt32(NSOpenGLPFADepthSize), UInt32(24),
        UInt32(NSOpenGLPFAOpenGLProfile), UInt32(NSOpenGLProfileVersion3_2Core),
        0
    ]
    
    private var model: GLBufferedModel?
    private var modelTexture: OpenglTextureResource?
    private var program_unlit: GLuint = 0
    private var program_lighted: GLuint = 0
    
    private var grid: GLWorldSpaceGrid!
    
    private var unitViewProgram = UnitViewPrograms()
    private var gridProgram = GridProgram()
    
    private let taPerspective = Matrix4x4f(
        -1,   0,   0,   0,
         0,   1,   0,   0,
         0,-0.5,   1,   0,
         0,   0,   0,   1
    )
    
    init() {
        
    }
    
    func initializeOpenglState() {
        initScene()

        do { (unitViewProgram, gridProgram) = try makePrograms() }
        catch { print("Shader Initialization Error: \(error)") }

        grid = GLWorldSpaceGrid(size: Size2<Int>(width: 16, height: 16))
    }
    
    func drawFrame(_ viewState: UnitViewState, _ currentTime: Double, _ deltaTime: Double) {
        unitViewProgram.setCurrent(lighted: viewState.lighted)
        drawScene(viewState)
    }
    
    func updateForAnimations(_ model: UnitModel, _ modelInstance: UnitModel.Instance) {
        self.model?.applyChanges(model, modelInstance)
    }
    
    func switchTo(_ instance: UnitModel.Instance, of model: UnitModel, with textureAtlas: UnitTextureAtlas, textureData: Data) {
        self.model = GLBufferedModel(instance, of: model, with: textureAtlas)
        modelTexture = makeTexture(textureAtlas, textureData)
    }
    
    func clear() {
        model = nil
        modelTexture = nil
    }
    
    var hasLoadedModel: Bool {
        return model != nil
    }
    
}

// MARK:- Setup

private extension Core33OpenglUnitViewRenderer {
    
    func makeTexture(_ textureAtlas: UnitTextureAtlas, _ data: Data) -> OpenglTextureResource {
        
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
                $0.baseAddress!)
        }
        
        printGlErrors(prefix: "Model Texture: ")
        return texture
    }
    
    func loadShaderCode(forResource name: String, withExtension ext: String) throws -> String {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else { throw RuntimeError("Neccessary shader file not found.") }
        return try String(contentsOf: url)
    }
    
    func makePrograms() throws -> (UnitViewPrograms, GridProgram) {
        
        let vertexShader = try compileShader(GLenum(GL_VERTEX_SHADER), source: loadShaderCode(forResource: "unit-view.glsl", withExtension: "vert"))
        let fragmentShader = try compileShader(GLenum(GL_FRAGMENT_SHADER), source: loadShaderCode(forResource: "unit-view.glsl", withExtension: "frag"))
        let fragmentShaderLighted = try compileShader(GLenum(GL_FRAGMENT_SHADER), source: loadShaderCode(forResource: "unit-view-lighted.glsl", withExtension: "frag"))
        let unlit = try linkShaders(vertexShader, fragmentShader)
        let lighted = try linkShaders(vertexShader, fragmentShaderLighted)
        
        glDeleteShader(fragmentShaderLighted)
        glDeleteShader(fragmentShader)
        glDeleteShader(vertexShader)
        
        let gridVertexShader = try compileShader(GLenum(GL_VERTEX_SHADER), source: loadShaderCode(forResource: "unit-view-grid.glsl", withExtension: "vert"))
        let gridFragmentShader = try compileShader(GLenum(GL_FRAGMENT_SHADER), source: loadShaderCode(forResource: "unit-view-grid.glsl", withExtension: "frag"))
        let grid = try linkShaders(gridVertexShader, gridFragmentShader)
        
        glDeleteShader(gridFragmentShader)
        glDeleteShader(gridVertexShader)
        
        printGlErrors(prefix: "Shader Programs: ")
        return (UnitViewPrograms(unlit: UnitViewProgram(unlit), lighted: UnitViewProgram(lighted)), GridProgram(grid))
    }
    
}

// MARK:- Rendering

private extension Core33OpenglUnitViewRenderer {
    
    func initScene() {
        glEnable(GLenum(GL_CULL_FACE))
        glEnable(GLenum(GL_DEPTH_TEST))
        glEnable(GLenum(GL_LINE_SMOOTH))
        glEnable(GLenum(GL_POLYGON_SMOOTH))
        glHint(GLenum(GL_LINE_SMOOTH_HINT), GLenum(GL_NICEST))
        glHint(GLenum(GL_POLYGON_SMOOTH_HINT), GLenum(GL_NICEST))
        glBlendFunc(GLenum(GL_SRC_ALPHA), GLenum(GL_ONE_MINUS_SRC_ALPHA))
        glEnable(GLenum(GL_BLEND))
        glTexEnvf(GLenum(GL_TEXTURE_ENV), GLenum(GL_TEXTURE_ENV_MODE), GLfloat(GL_MODULATE))
    }
    
    func drawScene(_ viewState: UnitViewState) {
        
        glViewport(0, 0, GLsizei(viewState.viewportSize.width), GLsizei(viewState.viewportSize.height))
        
        glClearColor(1, 1, 1, 1)
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT))
        
        let projection = Matrix4x4f.ortho(0, viewState.sceneSize.width, viewState.sceneSize.height, 0, -1024, 256)
        
        let sceneCentering = Matrix4x4f.translation(viewState.sceneSize.width / 2, viewState.sceneSize.height / 2, 0)
        let sceneView = (sceneCentering * .taPerspective) * Matrix4x4f.rotation(radians: -viewState.rotateZ * (Float.pi / 180.0), axis: Vector3f(0, 0, 1))
        
        drawGrid(viewState, projection, sceneView)
        drawUnit(viewState, projection, sceneView)
        
        glBindVertexArray(0)
        glUseProgram(0)
    }
    
    func drawGrid(_ viewState: UnitViewState, _ projection: Matrix4x4f, _ sceneView: Matrix4x4f) {
        let view = sceneView * Matrix4x4f.translation(Float(-grid.size.width / 2), Float(-grid.size.height / 2), 0)
        
        let model = Matrix4x4f.translation(0, Float(viewState.movement), -0.5)
        
        glUseProgram(gridProgram.id)
        glUniform4x4(gridProgram.uniform_model, model)
        glUniform4x4(gridProgram.uniform_view, view)
        glUniform4x4(gridProgram.uniform_projection, projection)
        glUniform4(gridProgram.uniform_objectColor, Vector4f(0.9, 0.9, 0.9, 1))
        
        grid.draw()
    }
    
    func drawUnit(_ viewState: UnitViewState, _ projection: Matrix4x4f, _ sceneView: Matrix4x4f) {
        glUseProgram(unitViewProgram.current.id)
        glUniform4x4(unitViewProgram.current.uniform_model, Matrix4x4f.identity)
        glUniform4x4(unitViewProgram.current.uniform_view, sceneView)
        glUniform4x4(unitViewProgram.current.uniform_projection, projection)
        if let transformations = model?.transformations {
            glUniform4x4(unitViewProgram.current.uniform_pieces, transformations)
        }
        
        let lightPosition = Vector3f(50, 50, 100)
        let viewPosition = Vector3f(viewState.sceneSize.width / 2, viewState.sceneSize.height / 2, 0)
        glUniform3(unitViewProgram.current.uniform_lightPosition, lightPosition)
        glUniform3(unitViewProgram.current.uniform_viewPosition, viewPosition)
        
        glActiveTexture(GLenum(GL_TEXTURE0));
        glBindTexture(GLenum(GL_TEXTURE_2D), modelTexture?.id ?? 0);
        glUniform1i(unitViewProgram.current.uniform_texture, 0);
        
        switch viewState.drawMode {
        case .solid:
            glUniform4(unitViewProgram.current.uniform_objectColor, viewState.textured ? Vector4f(0, 0, 0, 0) : Vector4f(0.95, 0.85, 0.80, 1))
            model?.drawFilled()
        case .wireframe:
            glUniform4(unitViewProgram.current.uniform_objectColor, Vector4f(0.4, 0.35, 0.3, 1))
            model?.drawWireframe()
        case .outlined:
            glUniform4(unitViewProgram.current.uniform_objectColor, viewState.textured ? Vector4f(0, 0, 0, 0) : Vector4f(0.95, 0.85, 0.80, 1))
            
            glEnable(GLenum(GL_POLYGON_OFFSET_FILL))
            glPolygonOffset(1.0, 1.0)
            model?.drawFilled()
            glDisable(GLenum(GL_POLYGON_OFFSET_FILL))
            
            glUniform4(unitViewProgram.current.uniform_objectColor, viewState.textured ? Vector4f(0.95, 0.85, 0.80, 1) : Vector4f(0.4, 0.35, 0.3, 1))
            model?.drawWireframe()
        }
    }
    
}

// MARK:- Shader Program Helpers

private struct UnitViewPrograms {
    let unlit: UnitViewProgram
    let lighted: UnitViewProgram
    
    var current: UnitViewProgram
    
    init(unlit: UnitViewProgram, lighted: UnitViewProgram) {
        self.unlit = unlit
        self.lighted = lighted
        current = unlit
    }
    
    init() {
        self.unlit = UnitViewProgram()
        self.lighted = UnitViewProgram()
        current = UnitViewProgram()
    }
    
    mutating func setCurrent(lighted: Bool) {
        current = lighted ? self.lighted : unlit
    }
}

private struct UnitViewProgram {
    
    let id: GLuint
    
    let uniform_model: GLint
    let uniform_view: GLint
    let uniform_projection: GLint
    let uniform_pieces: GLint
    let uniform_lightPosition: GLint
    let uniform_viewPosition: GLint
    let uniform_texture: GLint
    let uniform_objectColor: GLint
    
    init(_ program: GLuint) {
        id = program
        uniform_model = glGetUniformLocation(program, "model")
        uniform_view = glGetUniformLocation(program, "view")
        uniform_projection = glGetUniformLocation(program, "projection")
        uniform_pieces = glGetUniformLocation(program, "pieces")
        uniform_lightPosition = glGetUniformLocation(program, "lightPosition")
        uniform_viewPosition = glGetUniformLocation(program, "viewPosition")
        uniform_texture = glGetUniformLocation(program, "colorTexture")
        uniform_objectColor = glGetUniformLocation(program, "objectColor")
    }
    
    init() {
        id = 0
        uniform_model = -1
        uniform_view = -1
        uniform_projection = -1
        uniform_pieces = -1
        uniform_lightPosition = -1
        uniform_viewPosition = -1
        uniform_texture = -1
        uniform_objectColor = -1
    }
    
    static var unset: UnitViewProgram { return UnitViewProgram() }
    
}

private struct GridProgram {
    
    let id: GLuint
    
    let uniform_model: GLint
    let uniform_view: GLint
    let uniform_projection: GLint
    let uniform_objectColor: GLint
    
    init(_ program: GLuint) {
        id = program
        uniform_model = glGetUniformLocation(program, "model")
        uniform_view = glGetUniformLocation(program, "view")
        uniform_projection = glGetUniformLocation(program, "projection")
        uniform_objectColor = glGetUniformLocation(program, "objectColor")
    }
    
    init() {
        id = 0
        uniform_model = -1
        uniform_view = -1
        uniform_projection = -1
        uniform_objectColor = -1
    }
    
}

// MARK:- Model

private class GLBufferedModel {
    
    private let vao: GLuint
    private let vbo: [GLuint]
    private let elementCount: Int
    
    private let vaoOutline: GLuint
    private let vboOutline: [GLuint]
    private let elementCountOutline: Int
    
    private(set) var transformations: [Matrix4x4f]
    
    init(_ instance: UnitModel.Instance, of model: UnitModel, with textures: UnitTextureAtlas? = nil) {
        
        var buffers = Buffers()
        GLBufferedModel.collectVertexAttributes(pieceIndex: model.root, model: model, textures: textures, buffers: &buffers)
        elementCount = buffers.vertices.count
        
        var vao: GLuint = 0
        glGenVertexArrays(1, &vao)
        glBindVertexArray(vao)
        self.vao = vao
        
        var vbo = [GLuint](repeating: 0, count: 4)
        glGenBuffers(GLsizei(vbo.count), &vbo)
        
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), vbo[0])
        glBufferData(GLenum(GL_ARRAY_BUFFER), buffers.vertices, GLenum(GL_STATIC_DRAW))
        let vertexAttrib: GLuint = 0
        glVertexAttribPointer(vertexAttrib, 3, GLenum(GL_DOUBLE), GLboolean(GL_FALSE), 0, nil)
        glEnableVertexAttribArray(vertexAttrib)
        
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), vbo[1])
        glBufferData(GLenum(GL_ARRAY_BUFFER), buffers.normals, GLenum(GL_STATIC_DRAW))
        let normalAttrib: GLuint = 1
        glVertexAttribPointer(normalAttrib, 3, GLenum(GL_DOUBLE), GLboolean(GL_FALSE), 0, nil)
        glEnableVertexAttribArray(normalAttrib)
        
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), vbo[2])
        glBufferData(GLenum(GL_ARRAY_BUFFER), buffers.texCoords, GLenum(GL_STATIC_DRAW))
        let texAttrib: GLuint = 2
        glVertexAttribPointer(texAttrib, 2, GLenum(GL_DOUBLE), GLboolean(GL_FALSE), 0, nil)
        glEnableVertexAttribArray(texAttrib)
        
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), vbo[3])
        glBufferData(GLenum(GL_ARRAY_BUFFER), buffers.pieceIndices.map { UInt8($0) }, GLenum(GL_STATIC_DRAW))
        let pieceAttrib: GLuint = 3
        glVertexAttribIPointer(pieceAttrib, 1, GLenum(GL_UNSIGNED_BYTE), 0, nil)
        glEnableVertexAttribArray(pieceAttrib)
        
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), 0)
        glBindVertexArray(0)
        
        self.vbo = vbo
        printGlErrors(prefix: "Model Geometry: ")
        
        buffers.clear()
        GLBufferedModel.collectOutlines(pieceIndex: model.root, model: model, buffers: &buffers)
        elementCountOutline = buffers.vertices.count
        
        var vao2: GLuint = 0
        glGenVertexArrays(1, &vao2)
        glBindVertexArray(vao2)
        self.vaoOutline = vao2
        
        var vbo2 = [GLuint](repeating: 0, count: 2)
        glGenBuffers(GLsizei(vbo2.count), &vbo2)
        
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), vbo2[0])
        glBufferData(GLenum(GL_ARRAY_BUFFER), buffers.vertices, GLenum(GL_STATIC_DRAW))
        glVertexAttribPointer(vertexAttrib, 3, GLenum(GL_DOUBLE), GLboolean(GL_FALSE), 0, nil)
        glEnableVertexAttribArray(vertexAttrib)
        
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), vbo2[1])
        glBufferData(GLenum(GL_ARRAY_BUFFER), buffers.pieceIndices.map { UInt8($0) }, GLenum(GL_STATIC_DRAW))
        glVertexAttribIPointer(pieceAttrib, 1, GLenum(GL_UNSIGNED_BYTE), 0, nil)
        glEnableVertexAttribArray(pieceAttrib)
        
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), 0)
        glBindVertexArray(0)
        
        self.vboOutline = vbo2
        printGlErrors(prefix: "Model Outline: ")
        
        self.transformations = [Matrix4x4f](repeating: Matrix4x4f.identity, count: instance.pieces.count)
    }
    
    deinit {
        var vbo = self.vbo
        glDeleteBuffers(GLsizei(vbo.count), &vbo)
        
        var vao = self.vao
        glDeleteVertexArrays(1, &vao)
        
        var vbo2 = self.vboOutline
        glDeleteBuffers(GLsizei(vbo.count), &vbo2)
        
        var vao2 = self.vaoOutline
        glDeleteVertexArrays(1, &vao2)
    }
    
    func drawFilled() {
        glBindVertexArray(vao)
        glDrawArrays(GLenum(GL_TRIANGLES), 0, GLsizei(elementCount))
    }
    
    func drawWireframe() {
        glBindVertexArray(vaoOutline)
        glDrawArrays(GLenum(GL_LINES), 0, GLsizei(elementCountOutline))
    }
    
    func applyChanges(_ model: UnitModel, _ modelInstance: UnitModel.Instance) {
        GLBufferedModel.applyPieceTransformations(model: model, instance: modelInstance, transformations: &transformations)
    }
    
    private static func collectVertexAttributes(pieceIndex: UnitModel.Pieces.Index, model: UnitModel, textures: UnitTextureAtlas?, buffers: inout Buffers) {
        
        let piece = model.pieces[pieceIndex]
        
        for primitiveIndex in piece.primitives {
            guard primitiveIndex != model.groundPlate else { continue }
            collectVertexAttributes(primitive: model.primitives[primitiveIndex], pieceIndex: pieceIndex, model: model, textures: textures, buffers: &buffers)
        }
        
        for child in piece.children {
            //let lineage = parents + [pieceIndex]
            collectVertexAttributes(pieceIndex: child, model: model, textures: textures, buffers: &buffers)
        }
    }
    
    private static func collectVertexAttributes(primitive: UnitModel.Primitive, pieceIndex: UnitModel.Pieces.Index, model: UnitModel, textures: UnitTextureAtlas?, buffers: inout Buffers) {
        
        let vertices = primitive.indices.map({ model.vertices[$0] })
        let texCoords = textures?.textureCoordinates(for: primitive.texture) ?? (Vertex2f.zero, Vertex2f.zero, Vertex2f.zero, Vertex2f.zero)
        
        switch vertices.count {
            
        case Int.min..<0: () // What?
        case 0: () // No Vertices
        case 1: () // A point?
        case 2: () // A line. Often used as a vector for sfx emitters
            
        case 3: // Single Triangle
            // Triangle 0,2,1
            let normal = makeNormal(0,2,1, in: vertices)
            buffers.append(
                texCoords.0, vertices[0],
                texCoords.2, vertices[2],
                texCoords.1, vertices[1],
                normal, pieceIndex
            )
            
        case 4: // Single Quad, split into two triangles
            // Triangle 0,2,1
            let normal = makeNormal(0,2,1, in: vertices)
            buffers.append(
                texCoords.0, vertices[0],
                texCoords.2, vertices[2],
                texCoords.1, vertices[1],
                normal, pieceIndex
            )
            // Triangle 0,3,2
            buffers.append(
                texCoords.0, vertices[0],
                texCoords.3, vertices[3],
                texCoords.2, vertices[2],
                normal, pieceIndex
            )
            
        default: // Polygon with more than 4 sides
            let normal = makeNormal(0,2,1, in: vertices)
            for n in 2 ..< vertices.count {
                buffers.append(
                    texCoords.0, vertices[0],
                    texCoords.2, vertices[n],
                    texCoords.1, vertices[n-1],
                    normal, pieceIndex
                )
            }
        }
    }
    
    private static func collectOutlines(pieceIndex: UnitModel.Pieces.Index, model: UnitModel, buffers: inout Buffers) {
        
        let piece = model.pieces[pieceIndex]
        
        for primitiveIndex in piece.primitives {
            guard primitiveIndex != model.groundPlate else { continue }
            let primitive = model.primitives[primitiveIndex]
            let vertices = primitive.indices.map({ model.vertices[$0] })
            for n in 1 ..< vertices.count {
                buffers.vertices.append(vertices[n-1])
                buffers.vertices.append(vertices[n])
                buffers.pieceIndices.append(pieceIndex)
                buffers.pieceIndices.append(pieceIndex)
            }
            let n = vertices.count - 1
            buffers.vertices.append(vertices[n])
            buffers.vertices.append(vertices[0])
            buffers.pieceIndices.append(pieceIndex)
            buffers.pieceIndices.append(pieceIndex)
        }
        
        for child in piece.children {
            collectOutlines(pieceIndex: child, model: model, buffers: &buffers)
        }
    }
    
    private static func makeNormal(_ a: Int, _ b: Int, _ c: Int, in vertices: [Vertex3f]) -> Vector3f {
        let v1 = vertices[a]
        let v2 = vertices[b]
        let v3 = vertices[c]
        let u = v2 - v1
        let v = v3 - v1
        return u × v
    }
    
    private struct Buffers {
        var vertices: [Vertex3f]
        var normals: [Vector3f]
        var texCoords: [Vertex2f]
        var pieceIndices: [Int]
        
        init() {
            vertices = []
            normals = []
            texCoords = []
            pieceIndices = []
        }
        
        mutating func append(_ texCoord1: Vertex2f, _ vertex1: Vertex3f,
                             _ texCoord2: Vertex2f, _ vertex2: Vertex3f,
                             _ texCoord3: Vertex2f, _ vertex3: Vertex3f,
                             _ normal: Vector3f,
                             _ pieceIndex: Int) {
            
            vertices.append(vertex1)
            texCoords.append(texCoord1)
            normals.append(normal)
            pieceIndices.append(pieceIndex)
            
            vertices.append(vertex2)
            texCoords.append(texCoord2)
            normals.append(normal)
            pieceIndices.append(pieceIndex)
            
            vertices.append(vertex3)
            texCoords.append(texCoord3)
            normals.append(normal)
            pieceIndices.append(pieceIndex)
        }
        
        mutating func clear() {
            vertices = []
            normals = []
            texCoords = []
            pieceIndices = []
        }
    }
    
    static func applyPieceTransformations(model: UnitModel, instance: UnitModel.Instance, transformations: inout [Matrix4x4f]) {
        applyPieceTransformations(pieceIndex: model.root, p: Matrix4x4f.identity, model: model, instance: instance, transformations: &transformations)
    }
    
    static func applyPieceTransformations(pieceIndex: UnitModel.Pieces.Index, p: Matrix4x4f, model: UnitModel, instance: UnitModel.Instance, transformations: inout [Matrix4x4f]) {
        let piece = model.pieces[pieceIndex]
        let anims = instance.pieces[pieceIndex]
        
        guard !anims.hidden else {
            applyPieceDiscard(pieceIndex: pieceIndex, model: model, transformations: &transformations)
            return
        }
        
        let offset = Vector3f(piece.offset)
        let move = Vector3f(anims.move)
        
        let rad2deg = GameFloat.pi / 180
        let sin = Vector3f( anims.turn.map { Darwin.sin($0 * rad2deg) } )
        let cos = Vector3f( anims.turn.map { Darwin.cos($0 * rad2deg) } )
        
        let t = Matrix4x4f(
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
        
        let pt = p * t
        transformations[pieceIndex] = pt
        
        for child in piece.children {
            applyPieceTransformations(pieceIndex: child, p: pt, model: model, instance: instance, transformations: &transformations)
        }
    }
    
    static func applyPieceDiscard(pieceIndex: UnitModel.Pieces.Index, model: UnitModel, transformations: inout [Matrix4x4f]) {
        
        transformations[pieceIndex] = Matrix4x4f.translation(0, 0, -1000)
        
        let piece = model.pieces[pieceIndex]
        for child in piece.children {
            applyPieceDiscard(pieceIndex: child, model: model, transformations: &transformations)
        }
    }
    
}

// MARK:- Grid

private class GLWorldSpaceGrid {
    
    let size: CGSize
    let spacing: Double
    
    private let vao: GLuint
    private let vbo: [GLuint]
    private let elementCount: Int
    
    init(size: Size2<Int>, gridSpacing: Int = UnitViewState.gridSize) {
        
        var vertices = [Vertex3f](repeating: .zero, count: (size.width * 2) + (size.height * 2) + (size.area * 4) )
        do {
            var n = 0
            let addLine: (Vertex3f, Vertex3f) -> () = { (a, b) in vertices[n] = a; vertices[n+1] = b; n += 2 }
            let makeVert: (Int, Int) -> Vertex3f = { (w, h) in Vertex3(x: GameFloat(w * gridSpacing), y: GameFloat(h * gridSpacing), z: 0) }
            
            for h in 0..<size.height {
                for w in 0..<size.width {
                    if h == 0 { addLine(makeVert(w,h), makeVert(w+1,h)) }
                    addLine(makeVert(w+1,h), makeVert(w+1,h+1))
                    addLine(makeVert(w+1,h+1), makeVert(w,h+1))
                    if w == 0 { addLine(makeVert(w,h+1), makeVert(w,h)) }
                }
            }
            
            elementCount = n
        }
        
        /* 3x3
         +--+--+--+       2 + 2 + 2
         |  |  |  |   2 + 4 + 4 + 4
         +--+--+--+
         |  |  |  |   2 + 4 + 4 + 4
         +--+--+--+
         |  |  |  |   2 + 4 + 4 + 4
         +--+--+--+
         */
        
        var vao: GLuint = 0
        glGenVertexArrays(1, &vao)
        glBindVertexArray(vao)
        self.vao = vao
        
        var vbo = [GLuint](repeating: 0, count: 1)
        glGenBuffers(GLsizei(vbo.count), &vbo)
        
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), vbo[0])
        glBufferData(GLenum(GL_ARRAY_BUFFER), vertices, GLenum(GL_STATIC_DRAW))
        let vertexAttrib: GLuint = 0
        glVertexAttribPointer(vertexAttrib, 3, GLenum(GL_GAMEFLOAT), GLboolean(GL_FALSE), 0, nil)
        glEnableVertexAttribArray(vertexAttrib)
        
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), 0)
        glBindVertexArray(0)
        
        self.vbo = vbo
        self.size = CGSize(size * gridSpacing)
        self.spacing = Double(gridSpacing)
    }
    
    func draw() {
        glBindVertexArray(vao)
        glDrawArrays(GLenum(GL_LINES), 0, GLsizei(elementCount))
    }
    
}
