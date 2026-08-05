import Foundation

public enum ColorPrimaries: String, Codable, CaseIterable, Sendable {
    case rec709
    case displayP3
    case rec2020
    case acesAP1
}

public enum TransferFunction: String, Codable, CaseIterable, Sendable {
    case linear
    case sRGB
    case rec709
    case pq
    case hlg
}

public enum ColorMatrix: String, Codable, CaseIterable, Sendable {
    case identity
    case bt709
    case bt2020NonConstantLuminance
}

public enum AlphaMode: String, Codable, CaseIterable, Sendable {
    case none
    case straight
    case premultiplied
}

public struct ColorDescriptor: Codable, Equatable, Hashable, Sendable {
    public let primaries: ColorPrimaries
    public let transferFunction: TransferFunction
    public let matrix: ColorMatrix
    public let alphaMode: AlphaMode

    public init(
        primaries: ColorPrimaries,
        transferFunction: TransferFunction,
        matrix: ColorMatrix,
        alphaMode: AlphaMode
    ) {
        self.primaries = primaries
        self.transferFunction = transferFunction
        self.matrix = matrix
        self.alphaMode = alphaMode
    }

    public static func rec709SDR(alphaMode: AlphaMode = .none) -> ColorDescriptor {
        ColorDescriptor(primaries: .rec709, transferFunction: .rec709, matrix: .bt709, alphaMode: alphaMode)
    }

    public static func displayP3SDR(alphaMode: AlphaMode = .none) -> ColorDescriptor {
        ColorDescriptor(primaries: .displayP3, transferFunction: .sRGB, matrix: .identity, alphaMode: alphaMode)
    }

    public static func rec2020PQ(alphaMode: AlphaMode = .none) -> ColorDescriptor {
        ColorDescriptor(primaries: .rec2020, transferFunction: .pq, matrix: .bt2020NonConstantLuminance, alphaMode: alphaMode)
    }
}
