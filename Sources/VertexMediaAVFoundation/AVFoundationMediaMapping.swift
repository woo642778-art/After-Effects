#if canImport(AVFoundation)
@preconcurrency import AVFoundation
import CoreMedia
import CoreVideo
import Foundation
import VertexCore
import VertexMedia

internal enum AVFoundationMediaMapping {
    static func rationalTime(_ time: CMTime) -> RationalTime {
        guard time.isNumeric, time.timescale > 0 else { return .zero }
        return RationalTime(value: time.value, timescale: time.timescale)
    }

    static func cmTime(_ time: RationalTime) -> CMTime {
        CMTime(value: time.value, timescale: time.timescale)
    }

    static func displayedSize(naturalSize: CGSize, preferredTransform: CGAffineTransform) -> VertexSize {
        let rect = CGRect(origin: .zero, size: naturalSize).applying(preferredTransform)
        return VertexSize(width: abs(rect.width), height: abs(rect.height))
    }

    static func rotationDegrees(_ transform: CGAffineTransform) -> Int {
        let degrees = Int((atan2(transform.b, transform.a) * 180 / .pi).rounded())
        return ((degrees % 360) + 360) % 360
    }

    static func codecName(from formatDescription: CMFormatDescription?) -> String {
        guard let formatDescription else { return "unknown" }
        let value = CMFormatDescriptionGetMediaSubType(formatDescription)
        let bytes: [UInt8] = [
            UInt8((value >> 24) & 0xff),
            UInt8((value >> 16) & 0xff),
            UInt8((value >> 8) & 0xff),
            UInt8(value & 0xff)
        ]
        let printable = bytes.allSatisfy { $0 >= 32 && $0 <= 126 }
        return printable ? String(bytes: bytes, encoding: .ascii) ?? "unknown" : String(format: "0x%08X", value)
    }

    static func audioProperties(from formatDescription: CMFormatDescription?) -> (sampleRate: Double, channels: Int) {
        guard let formatDescription,
              let basicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription) else {
            return (0, 0)
        }
        return (basicDescription.pointee.mSampleRate, Int(basicDescription.pointee.mChannelsPerFrame))
    }

    static func colorProperties(from formatDescription: CMFormatDescription?) -> (descriptor: ColorDescriptor?, isHDR: Bool, hasAlpha: Bool) {
        guard let formatDescription,
              let extensions = CMFormatDescriptionGetExtensions(formatDescription) as? [CFString: Any] else {
            return (nil, false, false)
        }

        let primaryValue = extensions[kCMFormatDescriptionExtension_ColorPrimaries] as? String
        let transferValue = extensions[kCMFormatDescriptionExtension_TransferFunction] as? String
        let matrixValue = extensions[kCMFormatDescriptionExtension_YCbCrMatrix] as? String

        let p3D65 = kCVImageBufferColorPrimaries_P3_D65 as String
        let rec2020 = kCVImageBufferColorPrimaries_ITU_R_2020 as String
        let pq = kCVImageBufferTransferFunction_SMPTE_ST_2084_PQ as String
        let hlg = kCVImageBufferTransferFunction_ITU_R_2100_HLG as String
        let sRGB = kCVImageBufferTransferFunction_sRGB as String
        let bt2020 = kCVImageBufferYCbCrMatrix_ITU_R_2020 as String

        let primaries: ColorPrimaries
        if primaryValue == p3D65 {
            primaries = .displayP3
        } else if primaryValue == rec2020 {
            primaries = .rec2020
        } else {
            primaries = .rec709
        }

        let transfer: TransferFunction
        let isHDR: Bool
        if transferValue == pq {
            transfer = .pq
            isHDR = true
        } else if transferValue == hlg {
            transfer = .hlg
            isHDR = true
        } else if transferValue == sRGB {
            transfer = .sRGB
            isHDR = false
        } else {
            transfer = .rec709
            isHDR = false
        }

        let matrix: ColorMatrix = matrixValue == bt2020 ? .bt2020NonConstantLuminance : .bt709
        let hasAlpha = (extensions[kCMFormatDescriptionExtension_ContainsAlphaChannel] as? Bool) ?? false
        let descriptor = ColorDescriptor(
            primaries: primaries,
            transferFunction: transfer,
            matrix: matrix,
            alphaMode: hasAlpha ? .straight : .none
        )
        return (descriptor, isHDR, hasAlpha)
    }

    static func variableFrameRateStatus(nominalFrameRate: Float, minimumFrameDuration: CMTime) -> VariableFrameRateStatus {
        guard nominalFrameRate > 0, minimumFrameDuration.isNumeric, minimumFrameDuration.seconds > 0 else {
            return .unknown
        }
        let maximumRate = 1 / minimumFrameDuration.seconds
        let difference = abs(maximumRate - Double(nominalFrameRate))
        let tolerance = max(0.02, Double(nominalFrameRate) * 0.002)
        return difference <= tolerance ? .constant : .variable
    }
}
#endif
