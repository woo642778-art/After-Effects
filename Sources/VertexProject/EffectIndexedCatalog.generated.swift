import Foundation

public struct EffectIndexedCatalogEntry: Equatable, Sendable, Identifiable {
    public let id: String
    public let product: String
    public let category: String
    public let name: String

    public init(id: String, product: String, category: String, name: String) {
        self.id = id
        self.product = product
        self.category = category
        self.name = name
    }

    public var implementedType: ProjectEffectType? {
        guard product == "Adobe After Effects" else { return nil }
        return ProjectEffectDescriptorRegistry.all.first {
            $0.displayName.compare(name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }?.type
    }

    public var status: EffectCompatibilityStatus {
        if let type = implementedType {
            return type.isNativePixelEffect ? .nativeImplemented : .aiImplemented
        }
        switch product {
        case "Extensions":
            return .workflowExtension
        case "Scripts":
            return .scriptCommand
        case "BCC obsolete / legacy", "Maxon legacy Keying Suite 11":
            return .legacyReference
        default:
            return .cleanRoomPlanned
        }
    }

    public var isImplemented: Bool {
        status == .nativeImplemented || status == .aiImplemented
    }
}

public enum EffectIndexedCatalog {
    public static let entries: [EffectIndexedCatalogEntry] = {
        rawCatalog.split(separator: "\n", omittingEmptySubsequences: true).compactMap { row in
            let parts = row.split(separator: "\t", omittingEmptySubsequences: false)
            guard parts.count == 4 else { return nil }
            return EffectIndexedCatalogEntry(
                id: String(parts[0]),
                product: String(parts[1]),
                category: String(parts[2]),
                name: String(parts[3])
            )
        }
    }()

    public static func search(_ query: String) -> [EffectIndexedCatalogEntry] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return entries }
        return entries.filter { entry in
            entry.name.localizedCaseInsensitiveContains(normalized)
                || entry.category.localizedCaseInsensitiveContains(normalized)
                || entry.product.localizedCaseInsensitiveContains(normalized)
        }
    }

    private static let rawCatalog = """
0000	Adobe After Effects	3D Channel	3D Channel Extract
0001	Adobe After Effects	3D Channel	Cryptomatte
0002	Adobe After Effects	3D Channel	Depth Matte
0003	Adobe After Effects	3D Channel	Depth of Field
0004	Adobe After Effects	3D Channel	Extractor
0005	Adobe After Effects	3D Channel	Fog 3D
0006	Adobe After Effects	3D Channel	ID Matte
0007	Adobe After Effects	3D Channel	IDentifier
0008	Adobe After Effects	Audio	Backwards
0009	Adobe After Effects	Audio	Bass & Treble
0010	Adobe After Effects	Audio	Delay
0011	Adobe After Effects	Audio	Flange & Chorus
0012	Adobe After Effects	Audio	High-Low Pass
0013	Adobe After Effects	Audio	Modulator
0014	Adobe After Effects	Audio	Parametric EQ
0015	Adobe After Effects	Audio	Reverb
0016	Adobe After Effects	Audio	Stereo Mixer
0017	Adobe After Effects	Audio	Tone
0018	Adobe After Effects	Blur & Sharpen	Bilateral Blur
0019	Adobe After Effects	Blur & Sharpen	Camera Lens Blur
0020	Adobe After Effects	Blur & Sharpen	Camera-Shake Deblur
0021	Adobe After Effects	Blur & Sharpen	CC Cross Blur
0022	Adobe After Effects	Blur & Sharpen	CC Radial Blur
0023	Adobe After Effects	Blur & Sharpen	CC Radial Fast Blur
0024	Adobe After Effects	Blur & Sharpen	CC Vector Blur
0025	Adobe After Effects	Blur & Sharpen	Channel Blur
0026	Adobe After Effects	Blur & Sharpen	Compound Blur
0027	Adobe After Effects	Blur & Sharpen	Directional Blur
0028	Adobe After Effects	Blur & Sharpen	Fast Box Blur
0029	Adobe After Effects	Blur & Sharpen	Gaussian Blur
0030	Adobe After Effects	Blur & Sharpen	Radial Blur
0031	Adobe After Effects	Blur & Sharpen	Sharpen
0032	Adobe After Effects	Blur & Sharpen	Smart Blur
0033	Adobe After Effects	Blur & Sharpen	Unsharp Mask
0034	Adobe After Effects	Boris FX Mocha	Mocha AE
0035	Adobe After Effects	Channel	Arithmetic
0036	Adobe After Effects	Channel	Blend
0037	Adobe After Effects	Channel	Calculations
0038	Adobe After Effects	Channel	CC Composite
0039	Adobe After Effects	Channel	Channel Combiner
0040	Adobe After Effects	Channel	Compound Arithmetic
0041	Adobe After Effects	Channel	Invert
0042	Adobe After Effects	Channel	Minimax
0043	Adobe After Effects	Channel	Remove Color Matting
0044	Adobe After Effects	Channel	Set Channels
0045	Adobe After Effects	Channel	Set Matte
0046	Adobe After Effects	Channel	Shift Channels
0047	Adobe After Effects	Channel	Solid Composite
0048	Adobe After Effects	CINEMA 4D	CINEWARE
0049	Adobe After Effects	Color Correction	Auto Color
0050	Adobe After Effects	Color Correction	Auto Contrast
0051	Adobe After Effects	Color Correction	Auto Levels
0052	Adobe After Effects	Color Correction	Black & White
0053	Adobe After Effects	Color Correction	Brightness & Contrast
0054	Adobe After Effects	Color Correction	Broadcast Colors
0055	Adobe After Effects	Color Correction	CC Color Neutralizer
0056	Adobe After Effects	Color Correction	CC Color Offset
0057	Adobe After Effects	Color Correction	CC Kernel
0058	Adobe After Effects	Color Correction	CC Toner
0059	Adobe After Effects	Color Correction	Change Color
0060	Adobe After Effects	Color Correction	Change to Color
0061	Adobe After Effects	Color Correction	Channel Mixer
0062	Adobe After Effects	Color Correction	Color Balance
0063	Adobe After Effects	Color Correction	Color Balance (HLS)
0064	Adobe After Effects	Color Correction	Color Link
0065	Adobe After Effects	Color Correction	Color Stabilizer
0066	Adobe After Effects	Color Correction	Colorama
0067	Adobe After Effects	Color Correction	Curves
0068	Adobe After Effects	Color Correction	Equalize
0069	Adobe After Effects	Color Correction	Exposure
0070	Adobe After Effects	Color Correction	Gamma/Pedestal/Gain
0071	Adobe After Effects	Color Correction	Hue/Saturation
0072	Adobe After Effects	Color Correction	Leave Color
0073	Adobe After Effects	Color Correction	Levels
0074	Adobe After Effects	Color Correction	Levels (Individual Controls)
0075	Adobe After Effects	Color Correction	Lumetri Color
0076	Adobe After Effects	Color Correction	Photo Filter
0077	Adobe After Effects	Color Correction	PS Arbitrary Map
0078	Adobe After Effects	Color Correction	Selective Color
0079	Adobe After Effects	Color Correction	Shadow/Highlight
0080	Adobe After Effects	Color Correction	Tint
0081	Adobe After Effects	Color Correction	Tritone
0082	Adobe After Effects	Color Correction	Vibrance
0083	Adobe After Effects	Color Correction	Video Limiter
0084	Adobe After Effects	Distort	Bezier Warp
0085	Adobe After Effects	Distort	Bulge
0086	Adobe After Effects	Distort	CC Bend It
0087	Adobe After Effects	Distort	CC Bender
0088	Adobe After Effects	Distort	CC Blobbylize
0089	Adobe After Effects	Distort	CC Flo Motion
0090	Adobe After Effects	Distort	CC Griddler
0091	Adobe After Effects	Distort	CC Lens
0092	Adobe After Effects	Distort	CC Page Turn
0093	Adobe After Effects	Distort	CC Power Pin
0094	Adobe After Effects	Distort	CC Ripple Pulse
0095	Adobe After Effects	Distort	CC Slant
0096	Adobe After Effects	Distort	CC Smear
0097	Adobe After Effects	Distort	CC Split
0098	Adobe After Effects	Distort	CC Split 2
0099	Adobe After Effects	Distort	CC Tiler
0100	Adobe After Effects	Distort	Corner Pin
0101	Adobe After Effects	Distort	Detail-preserving Upscale
0102	Adobe After Effects	Distort	Displacement Map
0103	Adobe After Effects	Distort	Liquify
0104	Adobe After Effects	Distort	Magnify
0105	Adobe After Effects	Distort	Mesh Warp
0106	Adobe After Effects	Distort	Mirror
0107	Adobe After Effects	Distort	Offset
0108	Adobe After Effects	Distort	Optics Compensation
0109	Adobe After Effects	Distort	Polar Coordinates
0110	Adobe After Effects	Distort	Reshape
0111	Adobe After Effects	Distort	Ripple
0112	Adobe After Effects	Distort	Rolling Shutter Repair
0113	Adobe After Effects	Distort	Smear
0114	Adobe After Effects	Distort	Spherize
0115	Adobe After Effects	Distort	Transform
0116	Adobe After Effects	Distort	Turbulent Displace
0117	Adobe After Effects	Distort	Twirl
0118	Adobe After Effects	Distort	Warp
0119	Adobe After Effects	Distort	Warp Stabilizer
0120	Adobe After Effects	Distort	Wave Warp
0121	Adobe After Effects	Expression Controls	3D Point Control
0122	Adobe After Effects	Expression Controls	Angle Control
0123	Adobe After Effects	Expression Controls	Checkbox Control
0124	Adobe After Effects	Expression Controls	Color Control
0125	Adobe After Effects	Expression Controls	Dropdown Menu Control
0126	Adobe After Effects	Expression Controls	Layer Control
0127	Adobe After Effects	Expression Controls	Point Control
0128	Adobe After Effects	Expression Controls	Slider Control
0129	Adobe After Effects	Generate	4-Color Gradient
0130	Adobe After Effects	Generate	Advanced Lightning
0131	Adobe After Effects	Generate	Audio Spectrum
0132	Adobe After Effects	Generate	Audio Waveform
0133	Adobe After Effects	Generate	Beam
0134	Adobe After Effects	Generate	CC Glue Gun
0135	Adobe After Effects	Generate	CC Light Burst 2.5
0136	Adobe After Effects	Generate	CC Light Rays
0137	Adobe After Effects	Generate	CC Light Sweep
0138	Adobe After Effects	Generate	CC Threads
0139	Adobe After Effects	Generate	Cell Pattern
0140	Adobe After Effects	Generate	Checkerboard
0141	Adobe After Effects	Generate	Circle
0142	Adobe After Effects	Generate	Ellipse
0143	Adobe After Effects	Generate	Eyedropper Fill
0144	Adobe After Effects	Generate	Fill
0145	Adobe After Effects	Generate	Fractal
0146	Adobe After Effects	Generate	Gradient Ramp
0147	Adobe After Effects	Generate	Grid
0148	Adobe After Effects	Generate	Lens Flare
0149	Adobe After Effects	Generate	Paint Bucket
0150	Adobe After Effects	Generate	Radio Waves
0151	Adobe After Effects	Generate	Scribble
0152	Adobe After Effects	Generate	Stroke
0153	Adobe After Effects	Generate	Vegas
0154	Adobe After Effects	Generate	Write-on
0155	Adobe After Effects	Immersive Video	VR Blur
0156	Adobe After Effects	Immersive Video	VR Chromatic Aberrations
0157	Adobe After Effects	Immersive Video	VR Color Gradients
0158	Adobe After Effects	Immersive Video	VR Converter
0159	Adobe After Effects	Immersive Video	VR De-Noise
0160	Adobe After Effects	Immersive Video	VR Digital Glitch
0161	Adobe After Effects	Immersive Video	VR Fractal Noise
0162	Adobe After Effects	Immersive Video	VR Glow
0163	Adobe After Effects	Immersive Video	VR Plane to Sphere
0164	Adobe After Effects	Immersive Video	VR Rotate Sphere
0165	Adobe After Effects	Immersive Video	VR Sharpen
0166	Adobe After Effects	Immersive Video	VR Sphere to Plane
0167	Adobe After Effects	Keying	Advanced Spill Suppressor
0168	Adobe After Effects	Keying	CC Simple Wire Removal
0169	Adobe After Effects	Keying	Color Difference Key
0170	Adobe After Effects	Keying	Color Range
0171	Adobe After Effects	Keying	Difference Matte
0172	Adobe After Effects	Keying	Extract
0173	Adobe After Effects	Keying	Inner/Outer Key
0174	Adobe After Effects	Keying	Key Cleaner
0175	Adobe After Effects	Keying	Keylight (1.2)
0176	Adobe After Effects	Keying	Linear Color Key
0177	Adobe After Effects	Matte	Matte Choker
0178	Adobe After Effects	Matte	Mocha shape
0179	Adobe After Effects	Matte	Refine Hard Matte
0180	Adobe After Effects	Matte	Refine Soft Matte
0181	Adobe After Effects	Matte	Simple Choker
0182	Adobe After Effects	Noise & Grain	Add Grain
0183	Adobe After Effects	Noise & Grain	Dust & Scratches
0184	Adobe After Effects	Noise & Grain	Fractal Noise
0185	Adobe After Effects	Noise & Grain	Match Grain
0186	Adobe After Effects	Noise & Grain	Median
0187	Adobe After Effects	Noise & Grain	Median (Legacy)
0188	Adobe After Effects	Noise & Grain	Noise
0189	Adobe After Effects	Noise & Grain	Noise Alpha
0190	Adobe After Effects	Noise & Grain	Noise HLS
0191	Adobe After Effects	Noise & Grain	Noise HLS Auto
0192	Adobe After Effects	Noise & Grain	Remove Grain
0193	Adobe After Effects	Noise & Grain	Turbulent Noise
0194	Adobe After Effects	Obsolete	Basic 3D
0195	Adobe After Effects	Obsolete	Basic Text
0196	Adobe After Effects	Obsolete	Color Key
0197	Adobe After Effects	Obsolete	Gaussian Blur (Legacy)
0198	Adobe After Effects	Obsolete	Lightning
0199	Adobe After Effects	Obsolete	Luma Key
0200	Adobe After Effects	Obsolete	Path Text
0201	Adobe After Effects	Obsolete	Reduce Interlace Flicker
0202	Adobe After Effects	Obsolete	Spill Suppressor
0203	Adobe After Effects	Perspective	3D Camera Tracker
0204	Adobe After Effects	Perspective	3D Glasses
0205	Adobe After Effects	Perspective	Bevel Alpha
0206	Adobe After Effects	Perspective	Bevel Edges
0207	Adobe After Effects	Perspective	CC Cylinder
0208	Adobe After Effects	Perspective	CC Environment
0209	Adobe After Effects	Perspective	CC Sphere
0210	Adobe After Effects	Perspective	CC Spotlight
0211	Adobe After Effects	Perspective	Drop Shadow
0212	Adobe After Effects	Perspective	Radial Shadow
0213	Adobe After Effects	Simulation	Card Dance
0214	Adobe After Effects	Simulation	Caustics
0215	Adobe After Effects	Simulation	CC Ball Action
0216	Adobe After Effects	Simulation	CC Bubbles
0217	Adobe After Effects	Simulation	CC Drizzle
0218	Adobe After Effects	Simulation	CC Hair
0219	Adobe After Effects	Simulation	CC Mr. Mercury
0220	Adobe After Effects	Simulation	CC Particle Systems II
0221	Adobe After Effects	Simulation	CC Particle World
0222	Adobe After Effects	Simulation	CC Pixel Polly
0223	Adobe After Effects	Simulation	CC Rainfall
0224	Adobe After Effects	Simulation	CC Scatterize
0225	Adobe After Effects	Simulation	CC Snowfall
0226	Adobe After Effects	Simulation	CC Star Burst
0227	Adobe After Effects	Simulation	Foam
0228	Adobe After Effects	Simulation	Particle Playground
0229	Adobe After Effects	Simulation	Shatter
0230	Adobe After Effects	Simulation	Wave World
0231	Adobe After Effects	Stylize	Brush Strokes
0232	Adobe After Effects	Stylize	Cartoon
0233	Adobe After Effects	Stylize	CC Block Load
0234	Adobe After Effects	Stylize	CC Burn Film
0235	Adobe After Effects	Stylize	CC Glass
0236	Adobe After Effects	Stylize	CC HexTile
0237	Adobe After Effects	Stylize	CC Kaleida
0238	Adobe After Effects	Stylize	CC Mr. Smoothie
0239	Adobe After Effects	Stylize	CC Plastic
0240	Adobe After Effects	Stylize	CC RepeTile
0241	Adobe After Effects	Stylize	CC Threshold
0242	Adobe After Effects	Stylize	CC Threshold RGB
0243	Adobe After Effects	Stylize	CC Vignette
0244	Adobe After Effects	Stylize	Color Emboss
0245	Adobe After Effects	Stylize	Emboss
0246	Adobe After Effects	Stylize	Find Edges
0247	Adobe After Effects	Stylize	Glow
0248	Adobe After Effects	Stylize	Mosaic
0249	Adobe After Effects	Stylize	Motion Tile
0250	Adobe After Effects	Stylize	Posterize
0251	Adobe After Effects	Stylize	Roughen Edges
0252	Adobe After Effects	Stylize	Scatter
0253	Adobe After Effects	Stylize	Strobe Light
0254	Adobe After Effects	Stylize	Texturize
0255	Adobe After Effects	Stylize	Threshold
0256	Adobe After Effects	Text	Numbers
0257	Adobe After Effects	Text	Timecode
0258	Adobe After Effects	Time	CC Force Motion Blur
0259	Adobe After Effects	Time	CC Wide Time
0260	Adobe After Effects	Time	Echo
0261	Adobe After Effects	Time	Pixel Motion Blur
0262	Adobe After Effects	Time	Posterize Time
0263	Adobe After Effects	Time	Time Difference
0264	Adobe After Effects	Time	Time Displacement
0265	Adobe After Effects	Time	Timewarp
0266	Adobe After Effects	Transition	Block Dissolve
0267	Adobe After Effects	Transition	Card Wipe
0268	Adobe After Effects	Transition	CC Glass Wipe
0269	Adobe After Effects	Transition	CC Grid Wipe
0270	Adobe After Effects	Transition	CC Image Wipe
0271	Adobe After Effects	Transition	CC Jaws
0272	Adobe After Effects	Transition	CC Light Wipe
0273	Adobe After Effects	Transition	CC Line Sweep
0274	Adobe After Effects	Transition	CC Radial ScaleWipe
0275	Adobe After Effects	Transition	CC Scale Wipe
0276	Adobe After Effects	Transition	CC Twister
0277	Adobe After Effects	Transition	CC WarpoMatic
0278	Adobe After Effects	Transition	Gradient Wipe
0279	Adobe After Effects	Transition	Iris Wipe
0280	Adobe After Effects	Transition	Linear Wipe
0281	Adobe After Effects	Transition	Radial Wipe
0282	Adobe After Effects	Transition	Venetian Blinds
0283	Adobe After Effects	Utility	Apply Color LUT
0284	Adobe After Effects	Utility	CC Overbrights
0285	Adobe After Effects	Utility	Cineon Converter
0286	Adobe After Effects	Utility	Color Profile Converter
0287	Adobe After Effects	Utility	Grow Bounds
0288	Adobe After Effects	Utility	HDR Compander
0289	Adobe After Effects	Utility	HDR Highlight Compression
0290	Boris FX Continuum	3D Objects	BCC 3D Extruded Image Shatter
0291	Boris FX Continuum	3D Objects	BCC 3D Image Shatter
0292	Boris FX Continuum	3D Objects	BCC 3D Image Shatter 2D
0293	Boris FX Continuum	3D Objects	BCC 3D Text
0294	Boris FX Continuum	3D Objects	BCC 3D Text Extrude
0295	Boris FX Continuum	3D Objects	BCC 3D Text Extrude Auto
0296	Boris FX Continuum	3D Objects	BCC 3D Text Extrude Contour
0297	Boris FX Continuum	3D Objects	BCC 3D Text Extrude Shatter
0298	Boris FX Continuum	3D Objects	BCC 3D Text Refract
0299	Boris FX Continuum	3D Objects	BCC 3D Text Shatter
0300	Boris FX Continuum	3D Objects	BCC 3D Text Type On
0301	Boris FX Continuum	3D Objects	BCC Extruded EPS
0302	Boris FX Continuum	3D Objects	BCC Extruded Spline
0303	Boris FX Continuum	3D Objects	BCC Extruded Text
0304	Boris FX Continuum	3D Objects	BCC Extruded Text 2D
0305	Boris FX Continuum	3D Objects	BCC Layer Deformer
0306	Boris FX Continuum	3D Objects	BCC Layer Deformer 2D
0307	Boris FX Continuum	3D Objects	BCC Particle Array 3D
0308	Boris FX Continuum	3D Objects	BCC Particle Array 3D 2D
0309	Boris FX Continuum	3D Objects	BCC Particle Array 3D Auto
0310	Boris FX Continuum	3D Objects	BCC Particle Emitter 3D
0311	Boris FX Continuum	3D Objects	BCC Particle Emitter 3D 2D
0312	Boris FX Continuum	3D Objects	BCC Particle Emitter 3D Auto
0313	Boris FX Continuum	Art Looks	BCC Cartoon Look
0314	Boris FX Continuum	Art Looks	BCC Charcoal Sketch
0315	Boris FX Continuum	Art Looks	BCC Halftone
0316	Boris FX Continuum	Art Looks	BCC Pencil Sketch
0317	Boris FX Continuum	Art Looks	BCC Watercolor
0318	Boris FX Continuum	Blur & Sharpen	BCC Alpha Process
0319	Boris FX Continuum	Blur & Sharpen	BCC Anti-Alias
0320	Boris FX Continuum	Blur & Sharpen	BCC Blur
0321	Boris FX Continuum	Blur & Sharpen	BCC Blur Channels
0322	Boris FX Continuum	Blur & Sharpen	BCC Blur Edges
0323	Boris FX Continuum	Blur & Sharpen	BCC Box Blur
0324	Boris FX Continuum	Blur & Sharpen	BCC Chroma Key Studio
0325	Boris FX Continuum	Blur & Sharpen	BCC Deinterlace
0326	Boris FX Continuum	Blur & Sharpen	BCC Directional Blur
0327	Boris FX Continuum	Blur & Sharpen	BCC Fast Lens Blur
0328	Boris FX Continuum	Blur & Sharpen	BCC Gaussian Blur
0329	Boris FX Continuum	Blur & Sharpen	BCC Lens Blur
0330	Boris FX Continuum	Blur & Sharpen	BCC Motion Blur
0331	Boris FX Continuum	Blur & Sharpen	BCC Motion Key
0332	Boris FX Continuum	Blur & Sharpen	BCC Motion Trail
0333	Boris FX Continuum	Blur & Sharpen	BCC Optical Stabilizer
0334	Boris FX Continuum	Blur & Sharpen	BCC Pyramid Blur
0335	Boris FX Continuum	Blur & Sharpen	BCC Radial Blur
0336	Boris FX Continuum	Blur & Sharpen	BCC Sharpen
0337	Boris FX Continuum	Blur & Sharpen	BCC Smart Blur
0338	Boris FX Continuum	Blur & Sharpen	BCC Soften
0339	Boris FX Continuum	Blur & Sharpen	BCC Unsharp Mask
0340	Boris FX Continuum	Color & Tone	BCC 3 Way Color Grade
0341	Boris FX Continuum	Color & Tone	BCC Auto Contrast
0342	Boris FX Continuum	Color & Tone	BCC Auto Levels
0343	Boris FX Continuum	Color & Tone	BCC Black and White
0344	Boris FX Continuum	Color & Tone	BCC Brightness Contrast
0345	Boris FX Continuum	Color & Tone	BCC Color Balance
0346	Boris FX Continuum	Color & Tone	BCC Color Correction
0347	Boris FX Continuum	Color & Tone	BCC Color Match
0348	Boris FX Continuum	Color & Tone	BCC Colorize
0349	Boris FX Continuum	Color & Tone	BCC Correct Selected Color
0350	Boris FX Continuum	Color & Tone	BCC Cross Process
0351	Boris FX Continuum	Color & Tone	BCC Curves
0352	Boris FX Continuum	Color & Tone	BCC Film Process
0353	Boris FX Continuum	Color & Tone	BCC Gamma
0354	Boris FX Continuum	Color & Tone	BCC HSL
0355	Boris FX Continuum	Color & Tone	BCC Hue Sat Lightness
0356	Boris FX Continuum	Color & Tone	BCC Levels Gamma
0357	Boris FX Continuum	Color & Tone	BCC Match Color
0358	Boris FX Continuum	Color & Tone	BCC Safe Colors
0359	Boris FX Continuum	Color & Tone	BCC Selective Color
0360	Boris FX Continuum	Color & Tone	BCC Temperature Tint
0361	Boris FX Continuum	Color & Tone	BCC Three Way Color Grade
0362	Boris FX Continuum	Color & Tone	BCC Tint
0363	Boris FX Continuum	Color & Tone	BCC Tritone
0364	Boris FX Continuum	Color & Tone	BCC Video Legalizer
0365	Boris FX Continuum	Color & Tone	BCC Vibrance
0366	Boris FX Continuum	Color & Tone	BCC White Balance
0367	Boris FX Continuum	Distort	BCC Bump Map
0368	Boris FX Continuum	Distort	BCC Corner Pin
0369	Boris FX Continuum	Distort	BCC Displacement Map
0370	Boris FX Continuum	Distort	BCC Fast Lens Blur
0371	Boris FX Continuum	Distort	BCC Lens Correction
0372	Boris FX Continuum	Distort	BCC Magnify
0373	Boris FX Continuum	Distort	BCC Mesh Warp
0374	Boris FX Continuum	Distort	BCC Page Turn
0375	Boris FX Continuum	Distort	BCC Pin Art 3D
0376	Boris FX Continuum	Distort	BCC Polar Displacement
0377	Boris FX Continuum	Distort	BCC Polar Coordinates
0378	Boris FX Continuum	Distort	BCC Ripple
0379	Boris FX Continuum	Distort	BCC Smear
0380	Boris FX Continuum	Distort	BCC Sphere
0381	Boris FX Continuum	Distort	BCC Swirl
0382	Boris FX Continuum	Distort	BCC Turbulence
0383	Boris FX Continuum	Distort	BCC Twirl
0384	Boris FX Continuum	Distort	BCC Wave
0385	Boris FX Continuum	Distort	BCC Warp
0386	Boris FX Continuum	Effects	BCC Alpha Spotlight
0387	Boris FX Continuum	Effects	BCC Burnt Film
0388	Boris FX Continuum	Effects	BCC Cartoon Look
0389	Boris FX Continuum	Effects	BCC Caustics
0390	Boris FX Continuum	Effects	BCC Chroma Key
0391	Boris FX Continuum	Effects	BCC Chroma Key Studio
0392	Boris FX Continuum	Effects	BCC Clouds
0393	Boris FX Continuum	Effects	BCC Composite
0394	Boris FX Continuum	Effects	BCC Damaged TV
0395	Boris FX Continuum	Effects	BCC Digital Noise
0396	Boris FX Continuum	Effects	BCC Film Damage
0397	Boris FX Continuum	Effects	BCC Film Glow
0398	Boris FX Continuum	Effects	BCC Fire
0399	Boris FX Continuum	Effects	BCC Fog
0400	Boris FX Continuum	Effects	BCC Glow
0401	Boris FX Continuum	Effects	BCC Grunge
0402	Boris FX Continuum	Effects	BCC Light Sweep
0403	Boris FX Continuum	Effects	BCC Lightning
0404	Boris FX Continuum	Effects	BCC Lens Flare 3D
0405	Boris FX Continuum	Effects	BCC Lens Flare
0406	Boris FX Continuum	Effects	BCC Magic Sharp
0407	Boris FX Continuum	Effects	BCC Optical Diffusion
0408	Boris FX Continuum	Effects	BCC Particle Illusion
0409	Boris FX Continuum	Effects	BCC Pixel Fixer
0410	Boris FX Continuum	Effects	BCC Prism
0411	Boris FX Continuum	Effects	BCC Rays
0412	Boris FX Continuum	Effects	BCC Reflection
0413	Boris FX Continuum	Effects	BCC Scanline
0414	Boris FX Continuum	Effects	BCC Spotlight
0415	Boris FX Continuum	Effects	BCC Star Matte
0416	Boris FX Continuum	Effects	BCC Stars
0417	Boris FX Continuum	Effects	BCC Tile Mosaic
0418	Boris FX Continuum	Effects	BCC TV Damage
0419	Boris FX Continuum	Effects	BCC Video Glitch
0420	Boris FX Continuum	Film Style	BCC Deinterlace
0421	Boris FX Continuum	Film Style	BCC Film Damage
0422	Boris FX Continuum	Film Style	BCC Film Grain
0423	Boris FX Continuum	Film Style	BCC Film Glow
0424	Boris FX Continuum	Film Style	BCC Film Process
0425	Boris FX Continuum	Film Style	BCC Match Grain
0426	Boris FX Continuum	Film Style	BCC Optical Diffusion
0427	Boris FX Continuum	Film Style	BCC Scanline
0428	Boris FX Continuum	Key & Blend	BCC Alpha Process
0429	Boris FX Continuum	Key & Blend	BCC Chroma Key
0430	Boris FX Continuum	Key & Blend	BCC Chroma Key Studio
0431	Boris FX Continuum	Key & Blend	BCC Composite
0432	Boris FX Continuum	Key & Blend	BCC Light Wrap
0433	Boris FX Continuum	Key & Blend	BCC Linear Color Key
0434	Boris FX Continuum	Key & Blend	BCC Matte Choker
0435	Boris FX Continuum	Key & Blend	BCC Primatte Studio
0436	Boris FX Continuum	Key & Blend	BCC Spill Remover
0437	Boris FX Continuum	Lights	BCC Alpha Spotlight
0438	Boris FX Continuum	Lights	BCC Film Glow
0439	Boris FX Continuum	Lights	BCC Glow
0440	Boris FX Continuum	Lights	BCC Light Sweep
0441	Boris FX Continuum	Lights	BCC Lightning
0442	Boris FX Continuum	Lights	BCC Lens Flare
0443	Boris FX Continuum	Lights	BCC Lens Flare 3D
0444	Boris FX Continuum	Lights	BCC Rays
0445	Boris FX Continuum	Lights	BCC Spotlight
0446	Boris FX Continuum	Lights	BCC Stage Light
0447	Boris FX Continuum	Lights	BCC Volumetric Lighting
0448	Boris FX Continuum	Noise Reduction	BCC DV Fixer
0449	Boris FX Continuum	Noise Reduction	BCC DeNoise
0450	Boris FX Continuum	Noise Reduction	BCC Digital Noise
0451	Boris FX Continuum	Noise Reduction	BCC Flicker Fixer
0452	Boris FX Continuum	Noise Reduction	BCC Match Grain
0453	Boris FX Continuum	Noise Reduction	BCC Pixel Fixer
0454	Boris FX Continuum	Particles	BCC Organic Strands
0455	Boris FX Continuum	Particles	BCC Particle Array 3D
0456	Boris FX Continuum	Particles	BCC Particle Emitter 3D
0457	Boris FX Continuum	Particles	BCC Particle Illusion
0458	Boris FX Continuum	Particles	BCC Rain
0459	Boris FX Continuum	Particles	BCC Snow
0460	Boris FX Continuum	Particles	BCC Sparks
0461	Boris FX Continuum	Particles	BCC Stars
0462	Boris FX Continuum	Perspective	BCC 3D Extruded Image Shatter
0463	Boris FX Continuum	Perspective	BCC 3D Image Shatter
0464	Boris FX Continuum	Perspective	BCC 3D Image Shatter 2D
0465	Boris FX Continuum	Perspective	BCC 3D Text
0466	Boris FX Continuum	Perspective	BCC 3D Text Extrude
0467	Boris FX Continuum	Perspective	BCC 3D Text Extrude Auto
0468	Boris FX Continuum	Perspective	BCC 3D Text Extrude Contour
0469	Boris FX Continuum	Perspective	BCC 3D Text Extrude Shatter
0470	Boris FX Continuum	Perspective	BCC 3D Text Refract
0471	Boris FX Continuum	Perspective	BCC 3D Text Shatter
0472	Boris FX Continuum	Perspective	BCC 3D Text Type On
0473	Boris FX Continuum	Perspective	BCC Corner Pin
0474	Boris FX Continuum	Perspective	BCC Extruded EPS
0475	Boris FX Continuum	Perspective	BCC Extruded Spline
0476	Boris FX Continuum	Perspective	BCC Extruded Text
0477	Boris FX Continuum	Perspective	BCC Extruded Text 2D
0478	Boris FX Continuum	Perspective	BCC Layer Deformer
0479	Boris FX Continuum	Perspective	BCC Layer Deformer 2D
0480	Boris FX Continuum	Perspective	BCC Lens Correction
0481	Boris FX Continuum	Perspective	BCC Magnify
0482	Boris FX Continuum	Perspective	BCC Particle Array 3D
0483	Boris FX Continuum	Perspective	BCC Particle Array 3D 2D
0484	Boris FX Continuum	Perspective	BCC Particle Array 3D Auto
0485	Boris FX Continuum	Perspective	BCC Particle Emitter 3D
0486	Boris FX Continuum	Perspective	BCC Particle Emitter 3D 2D
0487	Boris FX Continuum	Perspective	BCC Particle Emitter 3D Auto
0488	Boris FX Continuum	Perspective	BCC Pin Art 3D
0489	Boris FX Continuum	Perspective	BCC Sphere
0490	Boris FX Continuum	Restoration	BCC DV Fixer
0491	Boris FX Continuum	Restoration	BCC DeNoise
0492	Boris FX Continuum	Restoration	BCC Flicker Fixer
0493	Boris FX Continuum	Restoration	BCC Magic Sharp
0494	Boris FX Continuum	Restoration	BCC Match Grain
0495	Boris FX Continuum	Restoration	BCC Optical Stabilizer
0496	Boris FX Continuum	Restoration	BCC Pixel Fixer
0497	Boris FX Continuum	Stylize	BCC Burnt Film
0498	Boris FX Continuum	Stylize	BCC Cartoon Look
0499	Boris FX Continuum	Stylize	BCC Caustics
0500	Boris FX Continuum	Stylize	BCC Charcoal Sketch
0501	Boris FX Continuum	Stylize	BCC Damaged TV
0502	Boris FX Continuum	Stylize	BCC Film Damage
0503	Boris FX Continuum	Stylize	BCC Film Grain
0504	Boris FX Continuum	Stylize	BCC Film Glow
0505	Boris FX Continuum	Stylize	BCC Fire
0506	Boris FX Continuum	Stylize	BCC Fog
0507	Boris FX Continuum	Stylize	BCC Glow
0508	Boris FX Continuum	Stylize	BCC Grunge
0509	Boris FX Continuum	Stylize	BCC Halftone
0510	Boris FX Continuum	Stylize	BCC Lens Flare
0511	Boris FX Continuum	Stylize	BCC Lightning
0512	Boris FX Continuum	Stylize	BCC Optical Diffusion
0513	Boris FX Continuum	Stylize	BCC Pencil Sketch
0514	Boris FX Continuum	Stylize	BCC Prism
0515	Boris FX Continuum	Stylize	BCC Rays
0516	Boris FX Continuum	Stylize	BCC Reflection
0517	Boris FX Continuum	Stylize	BCC Scanline
0518	Boris FX Continuum	Stylize	BCC Tile Mosaic
0519	Boris FX Continuum	Stylize	BCC TV Damage
0520	Boris FX Continuum	Stylize	BCC Video Glitch
0521	Boris FX Continuum	Stylize	BCC Watercolor
0522	Boris FX Continuum	Temporal	BCC Deinterlace
0523	Boris FX Continuum	Temporal	BCC Flicker Fixer
0524	Boris FX Continuum	Temporal	BCC Motion Blur
0525	Boris FX Continuum	Temporal	BCC Motion Key
0526	Boris FX Continuum	Temporal	BCC Motion Trail
0527	Boris FX Continuum	Temporal	BCC Optical Stabilizer
0528	Boris FX Continuum	Text	BCC 3D Text
0529	Boris FX Continuum	Text	BCC 3D Text Extrude
0530	Boris FX Continuum	Text	BCC 3D Text Extrude Auto
0531	Boris FX Continuum	Text	BCC 3D Text Extrude Contour
0532	Boris FX Continuum	Text	BCC 3D Text Extrude Shatter
0533	Boris FX Continuum	Text	BCC 3D Text Refract
0534	Boris FX Continuum	Text	BCC 3D Text Shatter
0535	Boris FX Continuum	Text	BCC 3D Text Type On
0536	Boris FX Continuum	Text	BCC Extruded Text
0537	Boris FX Continuum	Text	BCC Extruded Text 2D
0538	Boris FX Continuum	Transitions	BCC 3D Extruded Image Shatter
0539	Boris FX Continuum	Transitions	BCC 3D Image Shatter
0540	Boris FX Continuum	Transitions	BCC 3D Image Shatter 2D
0541	Boris FX Continuum	Transitions	BCC 3D Text Extrude Shatter
0542	Boris FX Continuum	Transitions	BCC 3D Text Shatter
0543	Boris FX Continuum	Transitions	BCC Burnt Film
0544	Boris FX Continuum	Transitions	BCC Damaged TV
0545	Boris FX Continuum	Transitions	BCC Film Damage
0546	Boris FX Continuum	Transitions	BCC Lens Flare
0547	Boris FX Continuum	Transitions	BCC Lightning
0548	Boris FX Continuum	Transitions	BCC Page Turn
0549	Boris FX Continuum	Transitions	BCC Particle Illusion
0550	Boris FX Continuum	Transitions	BCC Pixel Fixer
0551	Boris FX Continuum	Transitions	BCC Prism
0552	Boris FX Continuum	Transitions	BCC Rays
0553	Boris FX Continuum	Transitions	BCC Reflection
0554	Boris FX Continuum	Transitions	BCC Tile Mosaic
0555	Boris FX Continuum	Transitions	BCC TV Damage
0556	Boris FX Continuum	Transitions	BCC Video Glitch
0557	Boris FX Continuum	Warp	BCC Bump Map
0558	Boris FX Continuum	Warp	BCC Corner Pin
0559	Boris FX Continuum	Warp	BCC Displacement Map
0560	Boris FX Continuum	Warp	BCC Lens Correction
0561	Boris FX Continuum	Warp	BCC Magnify
0562	Boris FX Continuum	Warp	BCC Mesh Warp
0563	Boris FX Continuum	Warp	BCC Page Turn
0564	Boris FX Continuum	Warp	BCC Polar Displacement
0565	Boris FX Continuum	Warp	BCC Ripple
0566	Boris FX Continuum	Warp	BCC Smear
0567	Boris FX Continuum	Warp	BCC Sphere
0568	Boris FX Continuum	Warp	BCC Swirl
0569	Boris FX Continuum	Warp	BCC Turbulence
0570	Boris FX Continuum	Warp	BCC Twirl
0571	Boris FX Continuum	Warp	BCC Wave
0572	Boris FX Continuum	Warp	BCC Warp
0573	Boris FX Continuum	Utilities	BCC Alpha Process
0574	Boris FX Continuum	Utilities	BCC Composite
0575	Boris FX Continuum	Utilities	BCC Deinterlace
0576	Boris FX Continuum	Utilities	BCC DV Fixer
0577	Boris FX Continuum	Utilities	BCC Match Grain
0578	Boris FX Continuum	Utilities	BCC Optical Stabilizer
0579	Boris FX Continuum	Utilities	BCC Pixel Fixer
0580	Boris FX Continuum	Utilities	BCC Safe Colors
0581	Boris FX Continuum	Utilities	BCC Video Legalizer
0582	Boris FX Continuum	VR	BCC VR Blur
0583	Boris FX Continuum	VR	BCC VR Converter
0584	Boris FX Continuum	VR	BCC VR Flicker Fixer
0585	Boris FX Continuum	VR	BCC VR Glow
0586	Boris FX Continuum	VR	BCC VR Sharpen
0587	Boris FX Continuum	VR	BCC VR Warp
0588	Boris FX Continuum	VR	BCC VR Wiggle
0589	Boris FX Continuum	VR	BCC VR Zoom
0590	Boris FX Continuum	VR	BCC VR Z-Blur
0591	Boris FX Continuum	VR	BCC VR Z-Defocus
0592	Boris FX Continuum	VR	BCC VR Z-Fog
0593	Boris FX Continuum	VR	BCC VR Z-Glow
0594	Boris FX Continuum	VR	BCC VR Z-Key
0595	Boris FX Continuum	VR	BCC VR Z-Mask
0596	Boris FX Continuum	VR	BCC VR Z-Matte
0597	Boris FX Continuum	VR	BCC VR Z-Slice
0598	Boris FX Continuum	VR	BCC VR Z-Transform
0599	Boris FX Continuum	VR	BCC VR Z-Warp
0600	Boris FX Continuum	VR	BCC VR Z-Wave
0601	Boris FX Continuum	VR	BCC VR Z-Wiggle
0602	Boris FX Continuum	VR	BCC VR Z-Zoom
0603	Boris FX Continuum	VR	BCC VR Z-Zoom Blur
0604	Boris FX Continuum	VR	BCC VR Z-Zoom Defocus
0605	Boris FX Continuum	VR	BCC VR Z-Zoom Fog
0606	Boris FX Continuum	VR	BCC VR Z-Zoom Glow
0607	Boris FX Continuum	VR	BCC VR Z-Zoom Key
0608	Boris FX Continuum	VR	BCC VR Z-Zoom Mask
0609	Boris FX Continuum	VR	BCC VR Z-Zoom Matte
0610	Boris FX Continuum	VR	BCC VR Z-Zoom Slice
0611	Boris FX Continuum	VR	BCC VR Z-Zoom Transform
0612	Boris FX Continuum	VR	BCC VR Z-Zoom Warp
0613	Boris FX Continuum	VR	BCC VR Z-Zoom Wave
0614	Boris FX Continuum	VR	BCC VR Z-Zoom Wiggle
0615	Boris FX Continuum	VR	BCC VR Z-Zoom Zoom
0616	Boris FX Continuum	VR	BCC VR Z-Zoom Zoom Blur
0617	Boris FX Continuum	VR	BCC VR Z-Zoom Zoom Defocus
0618	Boris FX Continuum	VR	BCC VR Z-Zoom Zoom Fog
0619	Boris FX Continuum	VR	BCC VR Z-Zoom Zoom Glow
0620	Boris FX Continuum	VR	BCC VR Z-Zoom Zoom Key
0621	Boris FX Continuum	VR	BCC VR Z-Zoom Zoom Mask
0622	BCC obsolete / legacy	Legacy	BCC Alpha Keyer
0623	BCC obsolete / legacy	Legacy	BCC Artists Poster
0624	BCC obsolete / legacy	Legacy	BCC Auto Contrast Legacy
0625	BCC obsolete / legacy	Legacy	BCC Auto Levels Legacy
0626	BCC obsolete / legacy	Legacy	BCC Blur Legacy
0627	BCC obsolete / legacy	Legacy	BCC Blur Channels Legacy
0628	BCC obsolete / legacy	Legacy	BCC Blur Edges Legacy
0629	BCC obsolete / legacy	Legacy	BCC Box Blur Legacy
0630	BCC obsolete / legacy	Legacy	BCC Brightness Contrast Legacy
0631	BCC obsolete / legacy	Legacy	BCC Cartooner
0632	BCC obsolete / legacy	Legacy	BCC Chroma Key Legacy
0633	BCC obsolete / legacy	Legacy	BCC Color Balance Legacy
0634	BCC obsolete / legacy	Legacy	BCC Color Correction Legacy
0635	BCC obsolete / legacy	Legacy	BCC Colorize Legacy
0636	BCC obsolete / legacy	Legacy	BCC Composite Legacy
0637	BCC obsolete / legacy	Legacy	BCC Deinterlace Legacy
0638	BCC obsolete / legacy	Legacy	BCC DeNoise Legacy
0639	BCC obsolete / legacy	Legacy	BCC Diffusion
0640	BCC obsolete / legacy	Legacy	BCC Directional Blur Legacy
0641	BCC obsolete / legacy	Legacy	BCC Displacement Map Legacy
0642	BCC obsolete / legacy	Legacy	BCC DV Fixer Legacy
0643	BCC obsolete / legacy	Legacy	BCC Film Damage Legacy
0644	BCC obsolete / legacy	Legacy	BCC Film Grain Legacy
0645	BCC obsolete / legacy	Legacy	BCC Film Glow Legacy
0646	BCC obsolete / legacy	Legacy	BCC Film Process Legacy
0647	BCC obsolete / legacy	Legacy	BCC Fire Legacy
0648	BCC obsolete / legacy	Legacy	BCC Flicker Fixer Legacy
0649	BCC obsolete / legacy	Legacy	BCC Fog Legacy
0650	BCC obsolete / legacy	Legacy	BCC Gamma Legacy
0651	BCC obsolete / legacy	Legacy	BCC Gaussian Blur Legacy
0652	BCC obsolete / legacy	Legacy	BCC Glow Legacy
0653	BCC obsolete / legacy	Legacy	BCC HSL Legacy
0654	BCC obsolete / legacy	Legacy	BCC Hue Sat Lightness Legacy
0655	BCC obsolete / legacy	Legacy	BCC Lens Blur Legacy
0656	BCC obsolete / legacy	Legacy	BCC Lens Flare Legacy
0657	BCC obsolete / legacy	Legacy	BCC Levels Gamma Legacy
0658	BCC obsolete / legacy	Legacy	BCC Light Sweep Legacy
0659	BCC obsolete / legacy	Legacy	BCC Lightning Legacy
0660	BCC obsolete / legacy	Legacy	BCC Linear Color Key Legacy
0661	BCC obsolete / legacy	Legacy	BCC Magnify Legacy
0662	BCC obsolete / legacy	Legacy	BCC Match Grain Legacy
0663	BCC obsolete / legacy	Legacy	BCC Matte Choker Legacy
0664	BCC obsolete / legacy	Legacy	BCC Motion Blur Legacy
0665	BCC obsolete / legacy	Legacy	BCC Motion Trail Legacy
0666	BCC obsolete / legacy	Legacy	BCC Optical Diffusion Legacy
0667	BCC obsolete / legacy	Legacy	BCC Optical Stabilizer Legacy
0668	BCC obsolete / legacy	Legacy	BCC Page Turn Legacy
0669	BCC obsolete / legacy	Legacy	BCC Particle Emitter 3D Legacy
0670	BCC obsolete / legacy	Legacy	BCC Pixel Fixer Legacy
0671	BCC obsolete / legacy	Legacy	BCC Polar Coordinates Legacy
0672	BCC obsolete / legacy	Legacy	BCC Primatte Legacy
0673	BCC obsolete / legacy	Legacy	BCC Prism Legacy
0674	BCC obsolete / legacy	Legacy	BCC Radial Blur Legacy
0675	BCC obsolete / legacy	Legacy	BCC Rays Legacy
0676	BCC obsolete / legacy	Legacy	BCC Reflection Legacy
0677	BCC obsolete / legacy	Legacy	BCC Ripple Legacy
0678	BCC obsolete / legacy	Legacy	BCC Safe Colors Legacy
0679	BCC obsolete / legacy	Legacy	BCC Scanline Legacy
0680	BCC obsolete / legacy	Legacy	BCC Sharpen Legacy
0681	BCC obsolete / legacy	Legacy	BCC Smear Legacy
0682	BCC obsolete / legacy	Legacy	BCC Snow Legacy
0683	BCC obsolete / legacy	Legacy	BCC Soften Legacy
0684	BCC obsolete / legacy	Legacy	BCC Sphere Legacy
0685	BCC obsolete / legacy	Legacy	BCC Spill Remover Legacy
0686	BCC obsolete / legacy	Legacy	BCC Spotlight Legacy
0687	BCC obsolete / legacy	Legacy	BCC Stars Legacy
0688	BCC obsolete / legacy	Legacy	BCC Swirl Legacy
0689	BCC obsolete / legacy	Legacy	BCC Temperature Tint Legacy
0690	BCC obsolete / legacy	Legacy	BCC Three Way Color Grade Legacy
0691	BCC obsolete / legacy	Legacy	BCC Tile Mosaic Legacy
0692	BCC obsolete / legacy	Legacy	BCC Tint Legacy
0693	BCC obsolete / legacy	Legacy	BCC Tritone Legacy
0694	BCC obsolete / legacy	Legacy	BCC Turbulence Legacy
0695	BCC obsolete / legacy	Legacy	BCC TV Damage Legacy
0696	BCC obsolete / legacy	Legacy	BCC Twirl Legacy
0697	BCC obsolete / legacy	Legacy	BCC Unsharp Mask Legacy
0698	BCC obsolete / legacy	Legacy	BCC Vibrance Legacy
0699	BCC obsolete / legacy	Legacy	BCC Video Glitch Legacy
0700	BCC obsolete / legacy	Legacy	BCC Video Legalizer Legacy
0701	BCC obsolete / legacy	Legacy	BCC Warp Legacy
0702	BCC obsolete / legacy	Legacy	BCC Watercolor Legacy
0703	BCC obsolete / legacy	Legacy	BCC White Balance Legacy
0704	BCC obsolete / legacy	Legacy	BCC Zoom Blur Legacy
0705	BCC obsolete / legacy	Legacy	BCC 3D Text Legacy
0706	BCC obsolete / legacy	Legacy	BCC Extruded Text Legacy
0707	BCC obsolete / legacy	Legacy	BCC Particle Array Legacy
0708	BCC obsolete / legacy	Legacy	BCC Particle Illusion Legacy
0709	BCC obsolete / legacy	Legacy	BCC Rain Legacy
0710	BCC obsolete / legacy	Legacy	BCC Sparks Legacy
0711	BCC obsolete / legacy	Legacy	BCC Chroma Key Studio Legacy
0712	BCC obsolete / legacy	Legacy	BCC Color Match Legacy
0713	BCC obsolete / legacy	Legacy	BCC Curves Legacy
0714	BCC obsolete / legacy	Legacy	BCC Match Color Legacy
0715	BCC obsolete / legacy	Legacy	BCC Selective Color Legacy
0716	BCC obsolete / legacy	Legacy	BCC Bump Map Legacy
0717	BCC obsolete / legacy	Legacy	BCC Lens Correction Legacy
0718	BCC obsolete / legacy	Legacy	BCC Mesh Warp Legacy
0719	BCC obsolete / legacy	Legacy	BCC Burnt Film Legacy
0720	BCC obsolete / legacy	Legacy	BCC Cartoon Look Legacy
0721	BCC obsolete / legacy	Legacy	BCC Caustics Legacy
0722	BCC obsolete / legacy	Legacy	BCC Digital Noise Legacy
0723	BCC obsolete / legacy	Legacy	BCC Grunge Legacy
0724	BCC obsolete / legacy	Legacy	BCC Halftone Legacy
0725	BCC obsolete / legacy	Legacy	BCC Pencil Sketch Legacy
0726	BCC obsolete / legacy	Legacy	BCC Chroma Key Studio Obsolete
0727	BCC obsolete / legacy	Legacy	BCC Particle Emitter Obsolete
0728	BCC obsolete / legacy	Legacy	BCC Particle Array Obsolete
0729	Boris FX Sapphire	Blur & Sharpen	S_Blur
0730	Boris FX Sapphire	Blur & Sharpen	S_BlurChannels
0731	Boris FX Sapphire	Blur & Sharpen	S_BlurDirectional
0732	Boris FX Sapphire	Blur & Sharpen	S_BlurMoCurves
0733	Boris FX Sapphire	Blur & Sharpen	S_BlurMotion
0734	Boris FX Sapphire	Blur & Sharpen	S_BlurMotionCurves
0735	Boris FX Sapphire	Blur & Sharpen	S_BlurMotionNoise
0736	Boris FX Sapphire	Blur & Sharpen	S_BlurShape
0737	Boris FX Sapphire	Blur & Sharpen	S_BlurSpot
0738	Boris FX Sapphire	Blur & Sharpen	S_BlurSpotShape
0739	Boris FX Sapphire	Blur & Sharpen	S_DefocusPrism
0740	Boris FX Sapphire	Blur & Sharpen	S_RackDefocus
0741	Boris FX Sapphire	Blur & Sharpen	S_RackDefocusComp
0742	Boris FX Sapphire	Blur & Sharpen	S_RackDefocusCompAuto
0743	Boris FX Sapphire	Blur & Sharpen	S_Sharpen
0744	Boris FX Sapphire	Blur & Sharpen	S_SharpenEdges
0745	Boris FX Sapphire	Blur & Sharpen	S_ZBlur
0746	Boris FX Sapphire	Blur & Sharpen	S_ZDefocus
0747	Boris FX Sapphire	Color & Tone	S_BandPass
0748	Boris FX Sapphire	Color & Tone	S_ChannelSwitcher
0749	Boris FX Sapphire	Color & Tone	S_ColorFuse
0750	Boris FX Sapphire	Color & Tone	S_ColorFuseComp
0751	Boris FX Sapphire	Color & Tone	S_ColorFuseCompAuto
0752	Boris FX Sapphire	Color & Tone	S_ColorFuseMask
0753	Boris FX Sapphire	Color & Tone	S_ColorFuseMatte
0754	Boris FX Sapphire	Color & Tone	S_ColorFuseMulti
0755	Boris FX Sapphire	Color & Tone	S_ColorFuseWipe
0756	Boris FX Sapphire	Color & Tone	S_ColorFuseWipeComp
0757	Boris FX Sapphire	Color & Tone	S_ColorFuseWipeCompAuto
0758	Boris FX Sapphire	Color & Tone	S_Convolve
0759	Boris FX Sapphire	Color & Tone	S_ConvolveComp
0760	Boris FX Sapphire	Color & Tone	S_ConvolveCompAuto
0761	Boris FX Sapphire	Color & Tone	S_ConvolveMask
0762	Boris FX Sapphire	Color & Tone	S_ConvolveMatte
0763	Boris FX Sapphire	Color & Tone	S_ConvolveMulti
0764	Boris FX Sapphire	Color & Tone	S_ConvolveWipe
0765	Boris FX Sapphire	Color & Tone	S_ConvolveWipeComp
0766	Boris FX Sapphire	Color & Tone	S_ConvolveWipeCompAuto
0767	Boris FX Sapphire	Color & Tone	S_DuoTone
0768	Boris FX Sapphire	Color & Tone	S_EdgeColorize
0769	Boris FX Sapphire	Color & Tone	S_EdgeColorizeComp
0770	Boris FX Sapphire	Color & Tone	S_EdgeColorizeMask
0771	Boris FX Sapphire	Color & Tone	S_EdgeColorizeMatte
0772	Boris FX Sapphire	Color & Tone	S_EdgeColorizeMulti
0773	Boris FX Sapphire	Color & Tone	S_EdgeColorizeWipe
0774	Boris FX Sapphire	Color & Tone	S_EdgeFlash
0775	Boris FX Sapphire	Color & Tone	S_EdgeFlashComp
0776	Boris FX Sapphire	Color & Tone	S_EdgeFlashMask
0777	Boris FX Sapphire	Color & Tone	S_EdgeFlashMatte
0778	Boris FX Sapphire	Color & Tone	S_EdgeFlashMulti
0779	Boris FX Sapphire	Color & Tone	S_EdgeFlashWipe
0780	Boris FX Sapphire	Color & Tone	S_FilmEffect
0781	Boris FX Sapphire	Color & Tone	S_FilmEffectComp
0782	Boris FX Sapphire	Color & Tone	S_FilmEffectMask
0783	Boris FX Sapphire	Color & Tone	S_FilmEffectMatte
0784	Boris FX Sapphire	Color & Tone	S_FilmEffectMulti
0785	Boris FX Sapphire	Color & Tone	S_FilmEffectWipe
0786	Boris FX Sapphire	Color & Tone	S_Gradient
0787	Boris FX Sapphire	Color & Tone	S_GradientComp
0788	Boris FX Sapphire	Color & Tone	S_GradientCompAuto
0789	Boris FX Sapphire	Color & Tone	S_GradientMask
0790	Boris FX Sapphire	Color & Tone	S_GradientMatte
0791	Boris FX Sapphire	Color & Tone	S_GradientMulti
0792	Boris FX Sapphire	Color & Tone	S_GradientWipe
0793	Boris FX Sapphire	Color & Tone	S_GradientWipeComp
0794	Boris FX Sapphire	Color & Tone	S_GradientWipeCompAuto
0795	Boris FX Sapphire	Color & Tone	S_Grid
0796	Boris FX Sapphire	Color & Tone	S_GridComp
0797	Boris FX Sapphire	Color & Tone	S_GridCompAuto
0798	Boris FX Sapphire	Color & Tone	S_GridMask
0799	Boris FX Sapphire	Color & Tone	S_GridMatte
0800	Boris FX Sapphire	Color & Tone	S_GridMulti
0801	Boris FX Sapphire	Color & Tone	S_GridWipe
0802	Boris FX Sapphire	Color & Tone	S_GridWipeComp
0803	Boris FX Sapphire	Color & Tone	S_GridWipeCompAuto
0804	Boris FX Sapphire	Color & Tone	S_HalfTone
0805	Boris FX Sapphire	Color & Tone	S_HalfToneComp
0806	Boris FX Sapphire	Color & Tone	S_HalfToneMask
0807	Boris FX Sapphire	Color & Tone	S_HalfToneMatte
0808	Boris FX Sapphire	Color & Tone	S_HalfToneMulti
0809	Boris FX Sapphire	Color & Tone	S_HalfToneWipe
0810	Boris FX Sapphire	Color & Tone	S_Hotspots
0811	Boris FX Sapphire	Color & Tone	S_HotspotsComp
0812	Boris FX Sapphire	Color & Tone	S_HotspotsMask
0813	Boris FX Sapphire	Color & Tone	S_HotspotsMatte
0814	Boris FX Sapphire	Color & Tone	S_HotspotsMulti
0815	Boris FX Sapphire	Color & Tone	S_HotspotsWipe
0816	Boris FX Sapphire	Color & Tone	S_LumaComp
0817	Boris FX Sapphire	Color & Tone	S_LumaCompAuto
0818	Boris FX Sapphire	Color & Tone	S_LumaMask
0819	Boris FX Sapphire	Color & Tone	S_LumaMatte
0820	Boris FX Sapphire	Color & Tone	S_LumaMulti
0821	Boris FX Sapphire	Color & Tone	S_LumaWipe
0822	Boris FX Sapphire	Color & Tone	S_LumaWipeComp
0823	Boris FX Sapphire	Color & Tone	S_LumaWipeCompAuto
0824	Boris FX Sapphire	Color & Tone	S_MatteOps
0825	Boris FX Sapphire	Color & Tone	S_MatteOpsComp
0826	Boris FX Sapphire	Color & Tone	S_MatteOpsMask
0827	Boris FX Sapphire	Color & Tone	S_MatteOpsMatte
0828	Boris FX Sapphire	Color & Tone	S_MatteOpsMulti
0829	Boris FX Sapphire	Color & Tone	S_MatteOpsWipe
0830	Boris FX Sapphire	Color & Tone	S_Monochrome
0831	Boris FX Sapphire	Color & Tone	S_MonochromeComp
0832	Boris FX Sapphire	Color & Tone	S_MonochromeMask
0833	Boris FX Sapphire	Color & Tone	S_MonochromeMatte
0834	Boris FX Sapphire	Color & Tone	S_MonochromeMulti
0835	Boris FX Sapphire	Color & Tone	S_MonochromeWipe
0836	Boris FX Sapphire	Color & Tone	S_Solarize
0837	Boris FX Sapphire	Color & Tone	S_SolarizeComp
0838	Boris FX Sapphire	Color & Tone	S_SolarizeMask
0839	Boris FX Sapphire	Color & Tone	S_SolarizeMatte
0840	Boris FX Sapphire	Color & Tone	S_SolarizeMulti
0841	Boris FX Sapphire	Color & Tone	S_SolarizeWipe
0842	Boris FX Sapphire	Color & Tone	S_Tint
0843	Boris FX Sapphire	Color & Tone	S_TintComp
0844	Boris FX Sapphire	Color & Tone	S_TintMask
0845	Boris FX Sapphire	Color & Tone	S_TintMatte
0846	Boris FX Sapphire	Color & Tone	S_TintMulti
0847	Boris FX Sapphire	Color & Tone	S_TintWipe
0848	Boris FX Sapphire	Distort	S_Distort
0849	Boris FX Sapphire	Distort	S_DistortBlur
0850	Boris FX Sapphire	Distort	S_DistortChroma
0851	Boris FX Sapphire	Distort	S_DistortChromaComp
0852	Boris FX Sapphire	Distort	S_DistortChromaCompAuto
0853	Boris FX Sapphire	Distort	S_DistortChromaMask
0854	Boris FX Sapphire	Distort	S_DistortChromaMatte
0855	Boris FX Sapphire	Distort	S_DistortChromaMulti
0856	Boris FX Sapphire	Distort	S_DistortChromaWipe
0857	Boris FX Sapphire	Distort	S_DistortRGB
0858	Boris FX Sapphire	Distort	S_DistortRGBComp
0859	Boris FX Sapphire	Distort	S_DistortRGBCompAuto
0860	Boris FX Sapphire	Distort	S_DistortRGBMask
0861	Boris FX Sapphire	Distort	S_DistortRGBMatte
0862	Boris FX Sapphire	Distort	S_DistortRGBMulti
0863	Boris FX Sapphire	Distort	S_DistortRGBWipe
0864	Boris FX Sapphire	Distort	S_DistortWarp
0865	Boris FX Sapphire	Distort	S_DistortWarpComp
0866	Boris FX Sapphire	Distort	S_DistortWarpCompAuto
0867	Boris FX Sapphire	Distort	S_DistortWarpMask
0868	Boris FX Sapphire	Distort	S_DistortWarpMatte
0869	Boris FX Sapphire	Distort	S_DistortWarpMulti
0870	Boris FX Sapphire	Distort	S_DistortWarpWipe
0871	Boris FX Sapphire	Distort	S_Kaleido
0872	Boris FX Sapphire	Distort	S_KaleidoComp
0873	Boris FX Sapphire	Distort	S_KaleidoMask
0874	Boris FX Sapphire	Distort	S_KaleidoMatte
0875	Boris FX Sapphire	Distort	S_KaleidoMulti
0876	Boris FX Sapphire	Distort	S_KaleidoWipe
0877	Boris FX Sapphire	Distort	S_LensDistort
0878	Boris FX Sapphire	Distort	S_LensDistortComp
0879	Boris FX Sapphire	Distort	S_LensDistortCompAuto
0880	Boris FX Sapphire	Distort	S_LensDistortMask
0881	Boris FX Sapphire	Distort	S_LensDistortMatte
0882	Boris FX Sapphire	Distort	S_LensDistortMulti
0883	Boris FX Sapphire	Distort	S_LensDistortWipe
0884	Boris FX Sapphire	Distort	S_Shake
0885	Boris FX Sapphire	Distort	S_ShakeComp
0886	Boris FX Sapphire	Distort	S_ShakeMask
0887	Boris FX Sapphire	Distort	S_ShakeMatte
0888	Boris FX Sapphire	Distort	S_ShakeMulti
0889	Boris FX Sapphire	Distort	S_ShakeWipe
0890	Boris FX Sapphire	Distort	S_Swirl
0891	Boris FX Sapphire	Distort	S_SwirlComp
0892	Boris FX Sapphire	Distort	S_SwirlMask
0893	Boris FX Sapphire	Distort	S_SwirlMatte
0894	Boris FX Sapphire	Distort	S_SwirlMulti
0895	Boris FX Sapphire	Distort	S_SwirlWipe
0896	Boris FX Sapphire	Distort	S_WarpChroma
0897	Boris FX Sapphire	Distort	S_WarpChromaComp
0898	Boris FX Sapphire	Distort	S_WarpChromaCompAuto
0899	Boris FX Sapphire	Distort	S_WarpChromaMask
0900	Boris FX Sapphire	Distort	S_WarpChromaMatte
0901	Boris FX Sapphire	Distort	S_WarpChromaMulti
0902	Boris FX Sapphire	Distort	S_WarpChromaWipe
0903	Boris FX Sapphire	Effects	S_Aurora
0904	Boris FX Sapphire	Effects	S_AuroraComp
0905	Boris FX Sapphire	Effects	S_AuroraMask
0906	Boris FX Sapphire	Effects	S_AuroraMatte
0907	Boris FX Sapphire	Effects	S_AuroraMulti
0908	Boris FX Sapphire	Effects	S_AuroraWipe
0909	Boris FX Sapphire	Effects	S_Clouds
0910	Boris FX Sapphire	Effects	S_CloudsComp
0911	Boris FX Sapphire	Effects	S_CloudsMask
0912	Boris FX Sapphire	Effects	S_CloudsMatte
0913	Boris FX Sapphire	Effects	S_CloudsMulti
0914	Boris FX Sapphire	Effects	S_CloudsWipe
0915	Boris FX Sapphire	Effects	S_DigitalDamage
0916	Boris FX Sapphire	Effects	S_DigitalDamageComp
0917	Boris FX Sapphire	Effects	S_DigitalDamageMask
0918	Boris FX Sapphire	Effects	S_DigitalDamageMatte
0919	Boris FX Sapphire	Effects	S_DigitalDamageMulti
0920	Boris FX Sapphire	Effects	S_DigitalDamageWipe
0921	Boris FX Sapphire	Effects	S_Dissolve
0922	Boris FX Sapphire	Effects	S_DissolveBlur
0923	Boris FX Sapphire	Effects	S_DissolveBlurComp
0924	Boris FX Sapphire	Effects	S_DissolveBlurMask
0925	Boris FX Sapphire	Effects	S_DissolveBlurMatte
0926	Boris FX Sapphire	Effects	S_DissolveBlurMulti
0927	Boris FX Sapphire	Effects	S_DissolveBlurWipe
0928	Boris FX Sapphire	Effects	S_DissolveBubble
0929	Boris FX Sapphire	Effects	S_DissolveBubbleComp
0930	Boris FX Sapphire	Effects	S_DissolveBubbleMask
0931	Boris FX Sapphire	Effects	S_DissolveBubbleMatte
0932	Boris FX Sapphire	Effects	S_DissolveBubbleMulti
0933	Boris FX Sapphire	Effects	S_DissolveBubbleWipe
0934	Boris FX Sapphire	Effects	S_DissolveDefocus
0935	Boris FX Sapphire	Effects	S_DissolveDefocusComp
0936	Boris FX Sapphire	Effects	S_DissolveDefocusMask
0937	Boris FX Sapphire	Effects	S_DissolveDefocusMatte
0938	Boris FX Sapphire	Effects	S_DissolveDefocusMulti
0939	Boris FX Sapphire	Effects	S_DissolveDefocusWipe
0940	Boris FX Sapphire	Effects	S_DissolveDigital
0941	Boris FX Sapphire	Effects	S_DissolveDigitalComp
0942	Boris FX Sapphire	Effects	S_DissolveDigitalMask
0943	Boris FX Sapphire	Effects	S_DissolveDigitalMatte
0944	Boris FX Sapphire	Effects	S_DissolveDigitalMulti
0945	Boris FX Sapphire	Effects	S_DissolveDigitalWipe
0946	Boris FX Sapphire	Effects	S_DissolveDistort
0947	Boris FX Sapphire	Effects	S_DissolveDistortComp
0948	Boris FX Sapphire	Effects	S_DissolveDistortMask
0949	Boris FX Sapphire	Effects	S_DissolveDistortMatte
0950	Boris FX Sapphire	Effects	S_DissolveDistortMulti
0951	Boris FX Sapphire	Effects	S_DissolveDistortWipe
0952	Boris FX Sapphire	Effects	S_DissolveEdgeRays
0953	Boris FX Sapphire	Effects	S_DissolveEdgeRaysComp
0954	Boris FX Sapphire	Effects	S_DissolveEdgeRaysMask
0955	Boris FX Sapphire	Effects	S_DissolveEdgeRaysMatte
0956	Boris FX Sapphire	Effects	S_DissolveEdgeRaysMulti
0957	Boris FX Sapphire	Effects	S_DissolveEdgeRaysWipe
0958	Boris FX Sapphire	Effects	S_DissolveGlare
0959	Boris FX Sapphire	Effects	S_DissolveGlareComp
0960	Boris FX Sapphire	Effects	S_DissolveGlareMask
0961	Boris FX Sapphire	Effects	S_DissolveGlareMatte
0962	Boris FX Sapphire	Effects	S_DissolveGlareMulti
0963	Boris FX Sapphire	Effects	S_DissolveGlareWipe
0964	Boris FX Sapphire	Effects	S_DissolveGlow
0965	Boris FX Sapphire	Effects	S_DissolveGlowComp
0966	Boris FX Sapphire	Effects	S_DissolveGlowMask
0967	Boris FX Sapphire	Effects	S_DissolveGlowMatte
0968	Boris FX Sapphire	Effects	S_DissolveGlowMulti
0969	Boris FX Sapphire	Effects	S_DissolveGlowWipe
0970	Boris FX Sapphire	Effects	S_DissolveLuma
0971	Boris FX Sapphire	Effects	S_DissolveLumaComp
0972	Boris FX Sapphire	Effects	S_DissolveLumaMask
0973	Boris FX Sapphire	Effects	S_DissolveLumaMatte
0974	Boris FX Sapphire	Effects	S_DissolveLumaMulti
0975	Boris FX Sapphire	Effects	S_DissolveLumaWipe
0976	Boris FX Sapphire	Effects	S_DissolvePixelSort
0977	Boris FX Sapphire	Effects	S_DissolvePixelSortComp
0978	Boris FX Sapphire	Effects	S_DissolvePixelSortMask
0979	Boris FX Sapphire	Effects	S_DissolvePixelSortMatte
0980	Boris FX Sapphire	Effects	S_DissolvePixelSortMulti
0981	Boris FX Sapphire	Effects	S_DissolvePixelSortWipe
0982	Boris FX Sapphire	Effects	S_DissolveRays
0983	Boris FX Sapphire	Effects	S_DissolveRaysComp
0984	Boris FX Sapphire	Effects	S_DissolveRaysMask
0985	Boris FX Sapphire	Effects	S_DissolveRaysMatte
0986	Boris FX Sapphire	Effects	S_DissolveRaysMulti
0987	Boris FX Sapphire	Effects	S_DissolveRaysWipe
0988	Boris FX Sapphire	Effects	S_DissolveShake
0989	Boris FX Sapphire	Effects	S_DissolveShakeComp
0990	Boris FX Sapphire	Effects	S_DissolveShakeMask
0991	Boris FX Sapphire	Effects	S_DissolveShakeMatte
0992	Boris FX Sapphire	Effects	S_DissolveShakeMulti
0993	Boris FX Sapphire	Effects	S_DissolveShakeWipe
0994	Boris FX Sapphire	Effects	S_DissolveStatic
0995	Boris FX Sapphire	Effects	S_DissolveStaticComp
0996	Boris FX Sapphire	Effects	S_DissolveStaticMask
0997	Boris FX Sapphire	Effects	S_DissolveStaticMatte
0998	Boris FX Sapphire	Effects	S_DissolveStaticMulti
0999	Boris FX Sapphire	Effects	S_DissolveStaticWipe
1000	Boris FX Sapphire	Effects	S_DissolveTiles
1001	Boris FX Sapphire	Effects	S_DissolveTilesComp
1002	Boris FX Sapphire	Effects	S_DissolveTilesMask
1003	Boris FX Sapphire	Effects	S_DissolveTilesMatte
1004	Boris FX Sapphire	Effects	S_DissolveTilesMulti
1005	Boris FX Sapphire	Effects	S_DissolveTilesWipe
1006	Boris FX Sapphire	Effects	S_DissolveVortex
1007	Boris FX Sapphire	Effects	S_DissolveVortexComp
1008	Boris FX Sapphire	Effects	S_DissolveVortexMask
1009	Boris FX Sapphire	Effects	S_DissolveVortexMatte
1010	Boris FX Sapphire	Effects	S_DissolveVortexMulti
1011	Boris FX Sapphire	Effects	S_DissolveVortexWipe
1012	Boris FX Sapphire	Lights	S_EdgeRays
1013	Boris FX Sapphire	Lights	S_EdgeRaysComp
1014	Boris FX Sapphire	Lights	S_EdgeRaysMask
1015	Boris FX Sapphire	Lights	S_EdgeRaysMatte
1016	Boris FX Sapphire	Lights	S_EdgeRaysMulti
1017	Boris FX Sapphire	Lights	S_EdgeRaysWipe
1018	Boris FX Sapphire	Lights	S_Glare
1019	Boris FX Sapphire	Lights	S_GlareComp
1020	Boris FX Sapphire	Lights	S_GlareMask
1021	Boris FX Sapphire	Lights	S_GlareMatte
1022	Boris FX Sapphire	Lights	S_GlareMulti
1023	Boris FX Sapphire	Lights	S_GlareWipe
1024	Boris FX Sapphire	Lights	S_Glow
1025	Boris FX Sapphire	Lights	S_GlowComp
1026	Boris FX Sapphire	Lights	S_GlowMask
1027	Boris FX Sapphire	Lights	S_GlowMatte
1028	Boris FX Sapphire	Lights	S_GlowMulti
1029	Boris FX Sapphire	Lights	S_GlowWipe
1030	Boris FX Sapphire	Lights	S_LensFlare
1031	Boris FX Sapphire	Lights	S_LensFlareComp
1032	Boris FX Sapphire	Lights	S_LensFlareMask
1033	Boris FX Sapphire	Lights	S_LensFlareMatte
1034	Boris FX Sapphire	Lights	S_LensFlareMulti
1035	Boris FX Sapphire	Lights	S_LensFlareWipe
1036	Boris FX Sapphire	Lights	S_LightLeak
1037	Boris FX Sapphire	Lights	S_LightLeakComp
1038	Boris FX Sapphire	Lights	S_LightLeakMask
1039	Boris FX Sapphire	Lights	S_LightLeakMatte
1040	Boris FX Sapphire	Lights	S_LightLeakMulti
1041	Boris FX Sapphire	Lights	S_LightLeakWipe
1042	Boris FX Sapphire	Lights	S_Rays
1043	Boris FX Sapphire	Lights	S_RaysComp
1044	Boris FX Sapphire	Lights	S_RaysMask
1045	Boris FX Sapphire	Lights	S_RaysMatte
1046	Boris FX Sapphire	Lights	S_RaysMulti
1047	Boris FX Sapphire	Lights	S_RaysWipe
1048	Boris FX Sapphire	Lights	S_Zap
1049	Boris FX Sapphire	Lights	S_ZapComp
1050	Boris FX Sapphire	Lights	S_ZapMask
1051	Boris FX Sapphire	Lights	S_ZapMatte
1052	Boris FX Sapphire	Lights	S_ZapMulti
1053	Boris FX Sapphire	Lights	S_ZapWipe
1054	Boris FX Sapphire	Noise & Grain	S_Grain
1055	Boris FX Sapphire	Noise & Grain	S_GrainComp
1056	Boris FX Sapphire	Noise & Grain	S_GrainMask
1057	Boris FX Sapphire	Noise & Grain	S_GrainMatte
1058	Boris FX Sapphire	Noise & Grain	S_GrainMulti
1059	Boris FX Sapphire	Noise & Grain	S_GrainWipe
1060	Boris FX Sapphire	Noise & Grain	S_Grunge
1061	Boris FX Sapphire	Noise & Grain	S_GrungeComp
1062	Boris FX Sapphire	Noise & Grain	S_GrungeMask
1063	Boris FX Sapphire	Noise & Grain	S_GrungeMatte
1064	Boris FX Sapphire	Noise & Grain	S_GrungeMulti
1065	Boris FX Sapphire	Noise & Grain	S_GrungeWipe
1066	Boris FX Sapphire	Noise & Grain	S_Noise
1067	Boris FX Sapphire	Noise & Grain	S_NoiseComp
1068	Boris FX Sapphire	Noise & Grain	S_NoiseMask
1069	Boris FX Sapphire	Noise & Grain	S_NoiseMatte
1070	Boris FX Sapphire	Noise & Grain	S_NoiseMulti
1071	Boris FX Sapphire	Noise & Grain	S_NoiseWipe
1072	Boris FX Sapphire	Render	S_Clouds
1073	Boris FX Sapphire	Render	S_CloudsComp
1074	Boris FX Sapphire	Render	S_CloudsMask
1075	Boris FX Sapphire	Render	S_CloudsMatte
1076	Boris FX Sapphire	Render	S_CloudsMulti
1077	Boris FX Sapphire	Render	S_CloudsWipe
1078	Boris FX Sapphire	Render	S_Gradient
1079	Boris FX Sapphire	Render	S_GradientComp
1080	Boris FX Sapphire	Render	S_GradientMask
1081	Boris FX Sapphire	Render	S_GradientMatte
1082	Boris FX Sapphire	Render	S_GradientMulti
1083	Boris FX Sapphire	Render	S_GradientWipe
1084	Boris FX Sapphire	Render	S_Grid
1085	Boris FX Sapphire	Render	S_GridComp
1086	Boris FX Sapphire	Render	S_GridMask
1087	Boris FX Sapphire	Render	S_GridMatte
1088	Boris FX Sapphire	Render	S_GridMulti
1089	Boris FX Sapphire	Render	S_GridWipe
1090	Boris FX Sapphire	Render	S_Sparkles
1091	Boris FX Sapphire	Render	S_SparklesComp
1092	Boris FX Sapphire	Render	S_SparklesMask
1093	Boris FX Sapphire	Render	S_SparklesMatte
1094	Boris FX Sapphire	Render	S_SparklesMulti
1095	Boris FX Sapphire	Render	S_SparklesWipe
1096	Boris FX Sapphire	Render	S_Stars
1097	Boris FX Sapphire	Render	S_StarsComp
1098	Boris FX Sapphire	Render	S_StarsMask
1099	Boris FX Sapphire	Render	S_StarsMatte
1100	Boris FX Sapphire	Render	S_StarsMulti
1101	Boris FX Sapphire	Render	S_StarsWipe
1102	Boris FX Sapphire	Stylize	S_Cartoon
1103	Boris FX Sapphire	Stylize	S_CartoonComp
1104	Boris FX Sapphire	Stylize	S_CartoonMask
1105	Boris FX Sapphire	Stylize	S_CartoonMatte
1106	Boris FX Sapphire	Stylize	S_CartoonMulti
1107	Boris FX Sapphire	Stylize	S_CartoonWipe
1108	Boris FX Sapphire	Stylize	S_Etching
1109	Boris FX Sapphire	Stylize	S_EtchingComp
1110	Boris FX Sapphire	Stylize	S_EtchingMask
1111	Boris FX Sapphire	Stylize	S_EtchingMatte
1112	Boris FX Sapphire	Stylize	S_EtchingMulti
1113	Boris FX Sapphire	Stylize	S_EtchingWipe
1114	Boris FX Sapphire	Stylize	S_HalfTone
1115	Boris FX Sapphire	Stylize	S_HalfToneComp
1116	Boris FX Sapphire	Stylize	S_HalfToneMask
1117	Boris FX Sapphire	Stylize	S_HalfToneMatte
1118	Boris FX Sapphire	Stylize	S_HalfToneMulti
1119	Boris FX Sapphire	Stylize	S_HalfToneWipe
1120	Boris FX Sapphire	Stylize	S_Mosaic
1121	Boris FX Sapphire	Stylize	S_MosaicComp
1122	Boris FX Sapphire	Stylize	S_MosaicMask
1123	Boris FX Sapphire	Stylize	S_MosaicMatte
1124	Boris FX Sapphire	Stylize	S_MosaicMulti
1125	Boris FX Sapphire	Stylize	S_MosaicWipe
1126	Boris FX Sapphire	Stylize	S_Posterize
1127	Boris FX Sapphire	Stylize	S_PosterizeComp
1128	Boris FX Sapphire	Stylize	S_PosterizeMask
1129	Boris FX Sapphire	Stylize	S_PosterizeMatte
1130	Boris FX Sapphire	Stylize	S_PosterizeMulti
1131	Boris FX Sapphire	Stylize	S_PosterizeWipe
1132	Boris FX Sapphire	Temporal	S_Echo
1133	Boris FX Sapphire	Temporal	S_EchoComp
1134	Boris FX Sapphire	Temporal	S_EchoMask
1135	Boris FX Sapphire	Temporal	S_EchoMatte
1136	Boris FX Sapphire	Temporal	S_EchoMulti
1137	Boris FX Sapphire	Temporal	S_EchoWipe
1138	Boris FX Sapphire	Temporal	S_FlickerRemove
1139	Boris FX Sapphire	Temporal	S_FlickerRemoveComp
1140	Boris FX Sapphire	Temporal	S_FlickerRemoveMask
1141	Boris FX Sapphire	Temporal	S_FlickerRemoveMatte
1142	Boris FX Sapphire	Temporal	S_FlickerRemoveMulti
1143	Boris FX Sapphire	Temporal	S_FlickerRemoveWipe
1144	Boris FX Sapphire	Temporal	S_MotionBlur
1145	Boris FX Sapphire	Temporal	S_MotionBlurComp
1146	Boris FX Sapphire	Temporal	S_MotionBlurMask
1147	Boris FX Sapphire	Temporal	S_MotionBlurMatte
1148	Boris FX Sapphire	Temporal	S_MotionBlurMulti
1149	Boris FX Sapphire	Temporal	S_MotionBlurWipe
1150	Boris FX Sapphire	Temporal	S_TimeDisplace
1151	Boris FX Sapphire	Temporal	S_TimeDisplaceComp
1152	Boris FX Sapphire	Temporal	S_TimeDisplaceMask
1153	Boris FX Sapphire	Temporal	S_TimeDisplaceMatte
1154	Boris FX Sapphire	Temporal	S_TimeDisplaceMulti
1155	Boris FX Sapphire	Temporal	S_TimeDisplaceWipe
1156	Boris FX Sapphire	Transitions	S_WipeBlobs
1157	Boris FX Sapphire	Transitions	S_WipeBlobsComp
1158	Boris FX Sapphire	Transitions	S_WipeBlobsMask
1159	Boris FX Sapphire	Transitions	S_WipeBlobsMatte
1160	Boris FX Sapphire	Transitions	S_WipeBlobsMulti
1161	Boris FX Sapphire	Transitions	S_WipeBlobsWipe
1162	Boris FX Sapphire	Transitions	S_WipeBubble
1163	Boris FX Sapphire	Transitions	S_WipeBubbleComp
1164	Boris FX Sapphire	Transitions	S_WipeBubbleMask
1165	Boris FX Sapphire	Transitions	S_WipeBubbleMatte
1166	Boris FX Sapphire	Transitions	S_WipeBubbleMulti
1167	Boris FX Sapphire	Transitions	S_WipeBubbleWipe
1168	Boris FX Sapphire	Transitions	S_WipeChecker
1169	Boris FX Sapphire	Transitions	S_WipeCheckerComp
1170	Boris FX Sapphire	Transitions	S_WipeCheckerMask
1171	Boris FX Sapphire	Transitions	S_WipeCheckerMatte
1172	Boris FX Sapphire	Transitions	S_WipeCheckerMulti
1173	Boris FX Sapphire	Transitions	S_WipeCheckerWipe
1174	Boris FX Sapphire	Transitions	S_WipeCircle
1175	Boris FX Sapphire	Transitions	S_WipeCircleComp
1176	Boris FX Sapphire	Transitions	S_WipeCircleMask
1177	Boris FX Sapphire	Transitions	S_WipeCircleMatte
1178	Boris FX Sapphire	Transitions	S_WipeCircleMulti
1179	Boris FX Sapphire	Transitions	S_WipeCircleWipe
1180	Boris FX Sapphire	Transitions	S_WipeClouds
1181	Boris FX Sapphire	Transitions	S_WipeCloudsComp
1182	Boris FX Sapphire	Transitions	S_WipeCloudsMask
1183	Boris FX Sapphire	Transitions	S_WipeCloudsMatte
1184	Boris FX Sapphire	Transitions	S_WipeCloudsMulti
1185	Boris FX Sapphire	Transitions	S_WipeCloudsWipe
1186	Boris FX Sapphire	Transitions	S_WipeDots
1187	Boris FX Sapphire	Transitions	S_WipeDotsComp
1188	Boris FX Sapphire	Transitions	S_WipeDotsMask
1189	Boris FX Sapphire	Transitions	S_WipeDotsMatte
1190	Boris FX Sapphire	Transitions	S_WipeDotsMulti
1191	Boris FX Sapphire	Transitions	S_WipeDotsWipe
1192	Boris FX Sapphire	Transitions	S_WipeDoubleWedge
1193	Boris FX Sapphire	Transitions	S_WipeDoubleWedgeComp
1194	Boris FX Sapphire	Transitions	S_WipeDoubleWedgeMask
1195	Boris FX Sapphire	Transitions	S_WipeDoubleWedgeMatte
1196	Boris FX Sapphire	Transitions	S_WipeDoubleWedgeMulti
1197	Boris FX Sapphire	Transitions	S_WipeDoubleWedgeWipe
1198	Boris FX Sapphire	Transitions	S_WipeFourWedges
1199	Boris FX Sapphire	Transitions	S_WipeFourWedgesComp
1200	Boris FX Sapphire	Transitions	S_WipeFourWedgesMask
1201	Boris FX Sapphire	Transitions	S_WipeFourWedgesMatte
1202	Boris FX Sapphire	Transitions	S_WipeFourWedgesMulti
1203	Boris FX Sapphire	Transitions	S_WipeFourWedgesWipe
1204	Boris FX Sapphire	Transitions	S_WipeLine
1205	Boris FX Sapphire	Transitions	S_WipeLineComp
1206	Boris FX Sapphire	Transitions	S_WipeLineMask
1207	Boris FX Sapphire	Transitions	S_WipeLineMatte
1208	Boris FX Sapphire	Transitions	S_WipeLineMulti
1209	Boris FX Sapphire	Transitions	S_WipeLineWipe
1210	Boris FX Sapphire	Transitions	S_WipePixelate
1211	Boris FX Sapphire	Transitions	S_WipePixelateComp
1212	Boris FX Sapphire	Transitions	S_WipePixelateMask
1213	Boris FX Sapphire	Transitions	S_WipePixelateMatte
1214	Boris FX Sapphire	Transitions	S_WipePixelateMulti
1215	Boris FX Sapphire	Transitions	S_WipePixelateWipe
1216	Boris FX Sapphire	Transitions	S_WipePlasma
1217	Boris FX Sapphire	Transitions	S_WipePlasmaComp
1218	Boris FX Sapphire	Transitions	S_WipePlasmaMask
1219	Boris FX Sapphire	Transitions	S_WipePlasmaMatte
1220	Boris FX Sapphire	Transitions	S_WipePlasmaMulti
1221	Boris FX Sapphire	Transitions	S_WipePlasmaWipe
1222	Boris FX Sapphire	Transitions	S_WipePointalize
1223	Boris FX Sapphire	Transitions	S_WipePointalizeComp
1224	Boris FX Sapphire	Transitions	S_WipePointalizeMask
1225	Boris FX Sapphire	Transitions	S_WipePointalizeMatte
1226	Boris FX Sapphire	Transitions	S_WipePointalizeMulti
1227	Boris FX Sapphire	Transitions	S_WipePointalizeWipe
1228	Boris FX Sapphire	Transitions	S_WipeRectangle
1229	Boris FX Sapphire	Transitions	S_WipeRectangleComp
1230	Boris FX Sapphire	Transitions	S_WipeRectangleMask
1231	Boris FX Sapphire	Transitions	S_WipeRectangleMatte
1232	Boris FX Sapphire	Transitions	S_WipeRectangleMulti
1233	Boris FX Sapphire	Transitions	S_WipeRectangleWipe
1234	Boris FX Sapphire	Transitions	S_WipeRings
1235	Boris FX Sapphire	Transitions	S_WipeRingsComp
1236	Boris FX Sapphire	Transitions	S_WipeRingsMask
1237	Boris FX Sapphire	Transitions	S_WipeRingsMatte
1238	Boris FX Sapphire	Transitions	S_WipeRingsMulti
1239	Boris FX Sapphire	Transitions	S_WipeRingsWipe
1240	Boris FX Sapphire	Transitions	S_WipeStar
1241	Boris FX Sapphire	Transitions	S_WipeStarComp
1242	Boris FX Sapphire	Transitions	S_WipeStarMask
1243	Boris FX Sapphire	Transitions	S_WipeStarMatte
1244	Boris FX Sapphire	Transitions	S_WipeStarMulti
1245	Boris FX Sapphire	Transitions	S_WipeStarWipe
1246	Boris FX Sapphire	Transitions	S_WipeStripes
1247	Boris FX Sapphire	Transitions	S_WipeStripesComp
1248	Boris FX Sapphire	Transitions	S_WipeStripesMask
1249	Boris FX Sapphire	Transitions	S_WipeStripesMatte
1250	Boris FX Sapphire	Transitions	S_WipeStripesMulti
1251	Boris FX Sapphire	Transitions	S_WipeStripesWipe
1252	Boris FX Sapphire	Transitions	S_WipeTiles
1253	Boris FX Sapphire	Transitions	S_WipeTilesComp
1254	Boris FX Sapphire	Transitions	S_WipeTilesMask
1255	Boris FX Sapphire	Transitions	S_WipeTilesMatte
1256	Boris FX Sapphire	Transitions	S_WipeTilesMulti
1257	Boris FX Sapphire	Transitions	S_WipeTilesWipe
1258	Boris FX Sapphire	Transitions	S_WipeWedge
1259	Boris FX Sapphire	Transitions	S_WipeWedgeComp
1260	Boris FX Sapphire	Transitions	S_WipeWedgeMask
1261	Boris FX Sapphire	Transitions	S_WipeWedgeMatte
1262	Boris FX Sapphire	Transitions	S_WipeWedgeMulti
1263	Boris FX Sapphire	Transitions	S_WipeWedgeWipe
1264	Boris FX Sapphire	Transitions	S_WipeWires
1265	Boris FX Sapphire	Transitions	S_WipeWiresComp
1266	Boris FX Sapphire	Transitions	S_WipeWiresMask
1267	Boris FX Sapphire	Transitions	S_WipeWiresMatte
1268	Boris FX Sapphire	Transitions	S_WipeWiresMulti
1269	Boris FX Sapphire	Transitions	S_WipeWiresWipe
1270	Maxon Red Giant + Universe	Blur & Sharpen	Chromatic Blur
1271	Maxon Red Giant + Universe	Blur & Sharpen	Chromatic Glow
1272	Maxon Red Giant + Universe	Blur & Sharpen	Compound Blur
1273	Maxon Red Giant + Universe	Blur & Sharpen	Defocus
1274	Maxon Red Giant + Universe	Blur & Sharpen	Fast Blur
1275	Maxon Red Giant + Universe	Blur & Sharpen	Glow
1276	Maxon Red Giant + Universe	Blur & Sharpen	Radial Blur
1277	Maxon Red Giant + Universe	Blur & Sharpen	Sharpen
1278	Maxon Red Giant + Universe	Blur & Sharpen	Soft Contrast
1279	Maxon Red Giant + Universe	Color & Tone	3-Way Color Corrector
1280	Maxon Red Giant + Universe	Color & Tone	Color Balance
1281	Maxon Red Giant + Universe	Color & Tone	Colorista IV
1282	Maxon Red Giant + Universe	Color & Tone	Colorista V
1283	Maxon Red Giant + Universe	Color & Tone	Cosmo II
1284	Maxon Red Giant + Universe	Color & Tone	Film
1285	Maxon Red Giant + Universe	Color & Tone	FilmConvert Nitrate
1286	Maxon Red Giant + Universe	Color & Tone	Looks
1287	Maxon Red Giant + Universe	Color & Tone	Mojo II
1288	Maxon Red Giant + Universe	Color & Tone	Renoiser
1289	Maxon Red Giant + Universe	Color & Tone	Skin Tone
1290	Maxon Red Giant + Universe	Color & Tone	Supercomp
1291	Maxon Red Giant + Universe	Color & Tone	Vibrance
1292	Maxon Red Giant + Universe	Color & Tone	Vignette
1293	Maxon Red Giant + Universe	Color & Tone	Warm/Cool
1294	Maxon Red Giant + Universe	Distort	Chromatic Aberration
1295	Maxon Red Giant + Universe	Distort	Chromatic Displacement
1296	Maxon Red Giant + Universe	Distort	Displacement
1297	Maxon Red Giant + Universe	Distort	Heatwave
1298	Maxon Red Giant + Universe	Distort	Lens Distortion
1299	Maxon Red Giant + Universe	Distort	Mirage
1300	Maxon Red Giant + Universe	Distort	Optical Glow Distortion
1301	Maxon Red Giant + Universe	Distort	Turbulence
1302	Maxon Red Giant + Universe	Distort	Warp
1303	Maxon Red Giant + Universe	Distort	Warp Pins
1304	Maxon Red Giant + Universe	Effects	Chromatic Aberration
1305	Maxon Red Giant + Universe	Effects	Chromatic Glow
1306	Maxon Red Giant + Universe	Effects	Film Damage
1307	Maxon Red Giant + Universe	Effects	Finisher
1308	Maxon Red Giant + Universe	Effects	Glitch
1309	Maxon Red Giant + Universe	Effects	Glow
1310	Maxon Red Giant + Universe	Effects	Holomatrix
1311	Maxon Red Giant + Universe	Effects	Knoll Light Factory
1312	Maxon Red Giant + Universe	Effects	Lens Distortion
1313	Maxon Red Giant + Universe	Effects	Light Leak
1314	Maxon Red Giant + Universe	Effects	Long Shadow
1315	Maxon Red Giant + Universe	Effects	MisFire
1316	Maxon Red Giant + Universe	Effects	Retrograde Carousel
1317	Maxon Red Giant + Universe	Effects	Retrograde Jitter
1318	Maxon Red Giant + Universe	Effects	Retrograde VHS
1319	Maxon Red Giant + Universe	Effects	Spot Clone Tracker
1320	Maxon Red Giant + Universe	Effects	Supercomp
1321	Maxon Red Giant + Universe	Effects	Uni.Aberration
1322	Maxon Red Giant + Universe	Effects	Uni.Finisher
1323	Maxon Red Giant + Universe	Effects	Uni.Glitch
1324	Maxon Red Giant + Universe	Effects	Uni.Glow
1325	Maxon Red Giant + Universe	Effects	Uni.Holomatrix
1326	Maxon Red Giant + Universe	Effects	Uni.Knoll Light Factory EZ
1327	Maxon Red Giant + Universe	Effects	Uni.Lens Distortion
1328	Maxon Red Giant + Universe	Effects	Uni.Light Leak
1329	Maxon Red Giant + Universe	Effects	Uni.Long Shadow
1330	Maxon Red Giant + Universe	Effects	Uni.Retrograde
1331	Maxon Red Giant + Universe	Effects	Uni.Spot Clone Tracker
1332	Maxon Red Giant + Universe	Generate	Electrify
1333	Maxon Red Giant + Universe	Generate	Fractal Background
1334	Maxon Red Giant + Universe	Generate	Grid
1335	Maxon Red Giant + Universe	Generate	Heatwave
1336	Maxon Red Giant + Universe	Generate	Holomatrix
1337	Maxon Red Giant + Universe	Generate	Line
1338	Maxon Red Giant + Universe	Generate	Noise
1339	Maxon Red Giant + Universe	Generate	Shape
1340	Maxon Red Giant + Universe	Generate	Texturize
1341	Maxon Red Giant + Universe	Generate	Turbulence
1342	Maxon Red Giant + Universe	Key & Blend	Chroma Key
1343	Maxon Red Giant + Universe	Key & Blend	Key Correct
1344	Maxon Red Giant + Universe	Key & Blend	Key Cleaner
1345	Maxon Red Giant + Universe	Key & Blend	Light Wrap
1346	Maxon Red Giant + Universe	Key & Blend	Primatte Keyer
1347	Maxon Red Giant + Universe	Key & Blend	Supercomp
1348	Maxon Red Giant + Universe	Lights	Electrify
1349	Maxon Red Giant + Universe	Lights	Glow
1350	Maxon Red Giant + Universe	Lights	Knoll Light Factory
1351	Maxon Red Giant + Universe	Lights	Light Leak
1352	Maxon Red Giant + Universe	Lights	Long Shadow
1353	Maxon Red Giant + Universe	Lights	Optical Glow
1354	Maxon Red Giant + Universe	Lights	Shadow
1355	Maxon Red Giant + Universe	Noise & Grain	Denoiser III
1356	Maxon Red Giant + Universe	Noise & Grain	Film Grain
1357	Maxon Red Giant + Universe	Noise & Grain	Noise
1358	Maxon Red Giant + Universe	Noise & Grain	Renoiser
1359	Maxon Red Giant + Universe	Particles	Form
1360	Maxon Red Giant + Universe	Particles	Mir
1361	Maxon Red Giant + Universe	Particles	Particular
1362	Maxon Red Giant + Universe	Particles	Shine
1363	Maxon Red Giant + Universe	Particles	Starglow
1364	Maxon Red Giant + Universe	Particles	Tao
1365	Maxon Red Giant + Universe	Render	Electrify
1366	Maxon Red Giant + Universe	Render	Fractal Background
1367	Maxon Red Giant + Universe	Render	Grid
1368	Maxon Red Giant + Universe	Render	Holomatrix
1369	Maxon Red Giant + Universe	Render	Line
1370	Maxon Red Giant + Universe	Render	Mir
1371	Maxon Red Giant + Universe	Render	Particular
1372	Maxon Red Giant + Universe	Render	Shape
1373	Maxon Red Giant + Universe	Render	Shine
1374	Maxon Red Giant + Universe	Render	Starglow
1375	Maxon Red Giant + Universe	Render	Tao
1376	Maxon Red Giant + Universe	Stylize	Chromatic Aberration
1377	Maxon Red Giant + Universe	Stylize	Film Damage
1378	Maxon Red Giant + Universe	Stylize	Glitch
1379	Maxon Red Giant + Universe	Stylize	Glow
1380	Maxon Red Giant + Universe	Stylize	Holomatrix
1381	Maxon Red Giant + Universe	Stylize	Retrograde Carousel
1382	Maxon Red Giant + Universe	Stylize	Retrograde Jitter
1383	Maxon Red Giant + Universe	Stylize	Retrograde VHS
1384	Maxon Red Giant + Universe	Stylize	Texturize
1385	Maxon Red Giant + Universe	Text	Long Shadow
1386	Maxon Red Giant + Universe	Text	Texturize
1387	Maxon Red Giant + Universe	Transitions	Carousel
1388	Maxon Red Giant + Universe	Transitions	Chromatic Aberration
1389	Maxon Red Giant + Universe	Transitions	Chromatic Glow
1390	Maxon Red Giant + Universe	Transitions	Displacement
1391	Maxon Red Giant + Universe	Transitions	Dissolve
1392	Maxon Red Giant + Universe	Transitions	Glitch
1393	Maxon Red Giant + Universe	Transitions	Glow
1394	Maxon Red Giant + Universe	Transitions	Holomatrix
1395	Maxon Red Giant + Universe	Transitions	Light Leak
1396	Maxon Red Giant + Universe	Transitions	Line
1397	Maxon Red Giant + Universe	Transitions	Long Shadow
1398	Maxon Red Giant + Universe	Transitions	Motion Blur
1399	Maxon Red Giant + Universe	Transitions	Retrograde Carousel
1400	Maxon Red Giant + Universe	Transitions	Retrograde Jitter
1401	Maxon Red Giant + Universe	Transitions	Retrograde VHS
1402	Maxon Red Giant + Universe	Transitions	Shape
1403	Maxon Red Giant + Universe	Transitions	Turbulence
1404	Maxon Red Giant + Universe	Utilities	Finisher
1405	Maxon Red Giant + Universe	Utilities	Supercomp
1406	Maxon Red Giant + Universe	Utilities	Uni.Finisher
1407	Maxon Red Giant + Universe	Utilities	Uni.Spot Clone Tracker
1408	Video Copilot	3D Model	Element 3D
1409	Video Copilot	Lights	Optical Flares
1410	Video Copilot	Render	Saber
1411	Video Copilot	Render	VC Color Vibrance
1412	Video Copilot	Utility Workflow	FX Console
1413	Video Copilot	Utility Workflow	ORBX
1414	Video Copilot	Utility Workflow	VC Reflect
1415	Video Copilot	Utility Workflow	Video Copilot Plugin Manager
1416	Video Copilot	Utility Workflow	Video Copilot Presets
1417	RE:Vision Effects	Blur & Sharpen	DE:Noise
1418	RE:Vision Effects	Blur & Sharpen	DE:Noise Frames
1419	RE:Vision Effects	Blur & Sharpen	DE:Noise Sharpen
1420	RE:Vision Effects	Blur & Sharpen	ReelSmart Motion Blur
1421	RE:Vision Effects	Blur & Sharpen	ReelSmart Motion Blur Pro
1422	RE:Vision Effects	Blur & Sharpen	ReelSmart Motion Blur Vectors
1423	RE:Vision Effects	Effects	DE:Flicker
1424	RE:Vision Effects	Effects	DE:Flicker Auto Levels
1425	RE:Vision Effects	Effects	DE:Flicker High Speed
1426	RE:Vision Effects	Effects	DE:Flicker Rolling Bands
1427	RE:Vision Effects	Effects	DE:Flicker Timelapse
1428	RE:Vision Effects	Effects	DE:Flicker Wide Area
1429	RE:Vision Effects	Effects	DEFlicker
1430	RE:Vision Effects	Effects	Effections
1431	RE:Vision Effects	Effects	PV Feather
1432	RE:Vision Effects	Effects	RE:Fill
1433	RE:Vision Effects	Effects	Shade Shape
1434	RE:Vision Effects	Restoration	DE:Noise
1435	RE:Vision Effects	Restoration	DE:Noise Frames
1436	RE:Vision Effects	Restoration	DE:Noise Sharpen
1437	RE:Vision Effects	Temporal	FieldsKit
1438	RE:Vision Effects	Temporal	ReelSmart Motion Blur
1439	RE:Vision Effects	Temporal	ReelSmart Motion Blur Pro
1440	RE:Vision Effects	Temporal	ReelSmart Motion Blur Vectors
1441	RE:Vision Effects	Temporal	Twixtor
1442	RE:Vision Effects	Temporal	Twixtor Pro
1443	RE:Vision Effects	Temporal	Twixtor Vectors In
1444	RE:Vision Effects	Temporal	Twixtor Vectors Out
1445	RE:Vision Effects	Utilities	FieldsKit
1446	RE:Vision Effects	Utilities	Video Gogh
1447	Neat Video	Restoration	Reduce Noise v6
1448	Rowbyte	Blur & Sharpen	Deep Glow
1449	Rowbyte	Blur & Sharpen	Fast Bokeh Pro
1450	Rowbyte	Blur & Sharpen	Fast Lens Blur
1451	Rowbyte	Blur & Sharpen	Fast Optical Flow
1452	Rowbyte	Blur & Sharpen	Fast Sharpen
1453	Rowbyte	Effects	Deep Glow
1454	Rowbyte	Effects	Dot Pixels
1455	Rowbyte	Effects	Fast Bokeh Pro
1456	Rowbyte	Effects	Fast Lens Blur
1457	Rowbyte	Effects	Fast Optical Flow
1458	Rowbyte	Effects	Fast Sharpen
1459	Rowbyte	Effects	Plexus
1460	Rowbyte	Effects	Separate RGB
1461	Rowbyte	Effects	Superluminal Stardust
1462	Rowbyte	Particles	Plexus
1463	Rowbyte	Particles	Superluminal Stardust
1464	Rowbyte	Temporal	Fast Optical Flow
1465	Plugin Everything	Animation Tools	Time Bend
1466	Plugin Everything	Color & Tone	Lumetri Color Manager
1467	Plugin Everything	Distort	Displacer Pro
1468	Plugin Everything	Distort	Glitchify
1469	Plugin Everything	Distort	Goo
1470	Plugin Everything	Effects	Better Bokeh
1471	Plugin Everything	Effects	Deep Glow 2
1472	Plugin Everything	Effects	Deep Halation
1473	Plugin Everything	Effects	Deep Heat
1474	Plugin Everything	Effects	Deep Melt
1475	Plugin Everything	Effects	Deep Scatter
1476	Plugin Everything	Effects	Deep Warp
1477	Plugin Everything	Effects	Ditherer
1478	Plugin Everything	Effects	Displacer Pro
1479	Plugin Everything	Effects	Glitchify
1480	Plugin Everything	Effects	Goo
1481	Plugin Everything	Effects	Hand Drawn
1482	Plugin Everything	Effects	Halftone Pro
1483	Plugin Everything	Effects	Shadow Studio 3
1484	Plugin Everything	Lights	Deep Glow 2
1485	Plugin Everything	Noise & Grain	Deep Scatter
1486	Plugin Everything	Stylize	Deep Halation
1487	Plugin Everything	Stylize	Deep Heat
1488	Plugin Everything	Stylize	Deep Melt
1489	Plugin Everything	Stylize	Ditherer
1490	Plugin Everything	Stylize	Glitchify
1491	Plugin Everything	Stylize	Hand Drawn
1492	Boris FX workflow tools	Keying	Mocha Pro
1493	Boris FX workflow tools	Keying	Primatte Studio
1494	Boris FX workflow tools	Keying	Silhouette Paint
1495	Boris FX workflow tools	Keying	Silhouette Roto
1496	Boris FX workflow tools	Keying	Silhouette RotoPaint
1497	Boris FX workflow tools	Keying	Silhouette RotoPaint Pro
1498	Boris FX workflow tools	Restoration	Mocha Pro Remove Module
1499	Boris FX workflow tools	Restoration	Optics 2026
1500	Boris FX workflow tools	Tracking	Mocha Pro
1501	Boris FX workflow tools	Tracking	Mocha Pro Camera Solve
1502	Boris FX workflow tools	Tracking	Mocha Pro Insert Module
1503	Boris FX workflow tools	Tracking	Mocha Pro Lens Module
1504	Boris FX workflow tools	Tracking	Mocha Pro Mesh Tracking
1505	Boris FX workflow tools	Tracking	Mocha Pro PowerMesh
1506	Boris FX workflow tools	Tracking	Mocha Pro Remove Module
1507	Boris FX workflow tools	Tracking	Mocha Pro Stabilize Module
1508	Boris FX workflow tools	Tracking	Mocha Pro Track Module
1509	Boris FX workflow tools	Utilities	Mocha Pro
1510	Boris FX workflow tools	Utilities	Optics 2026
1511	Boris FX workflow tools	Utilities	Silhouette Paint
1512	Boris FX workflow tools	Utilities	Silhouette Roto
1513	Boris FX workflow tools	Utilities	Silhouette RotoPaint
1514	Maxon legacy Keying Suite 11	Keying	Key Correct
1515	Maxon legacy Keying Suite 11	Keying	Key Correct Pro
1516	Maxon legacy Keying Suite 11	Keying	Key Cleaner
1517	Maxon legacy Keying Suite 11	Keying	Key Cleaner Pro
1518	Maxon legacy Keying Suite 11	Keying	Keylight
1519	Maxon legacy Keying Suite 11	Keying	Primatte Keyer
1520	Maxon legacy Keying Suite 11	Keying	Primatte Keyer Pro
1521	Maxon legacy Keying Suite 11	Keying	Spill Killer
1522	Maxon legacy Keying Suite 11	Keying	Spill Killer Pro
1523	Maxon legacy Keying Suite 11	Keying	Supercomp Keyer
1524	Maxon legacy Keying Suite 11	Keying	Supercomp Keyer Pro
1525	Maxon legacy Keying Suite 11	Keying	Wire/Rig Removal
1526	Maxon legacy Keying Suite 11	Keying	Wire/Rig Removal Pro
1527	Maxon legacy Keying Suite 11	Keying	Keying Suite 11 Complete
1528	Maxon legacy Keying Suite 11	Keying	Keying Suite 11 Legacy
1529	Maxon legacy Keying Suite 11	Keying	Keying Suite 11 Matte Tools
1530	Maxon legacy Keying Suite 11	Keying	Keying Suite 11 Spill Tools
1531	Maxon legacy Keying Suite 11	Keying	Keying Suite 11 Edge Tools
1532	Maxon legacy Keying Suite 11	Keying	Keying Suite 11 Color Tools
1533	Maxon legacy Keying Suite 11	Keying	Keying Suite 11 Utility Tools
1534	Maxon legacy Keying Suite 11	Keying	Keying Suite 11 Deprecated
1535	BAO Plugins	Animation Tools	BAO Bones
1536	BAO Plugins	Animation Tools	BAO Boa
1537	BAO Plugins	Animation Tools	BAO Dynamic Comp
1538	BAO Plugins	Animation Tools	BAO Dynamic Text
1539	BAO Plugins	Animation Tools	BAO Mask Avenger
1540	BAO Plugins	Animation Tools	BAO Mask Brush
1541	BAO Plugins	Animation Tools	BAO Motion Pack
1542	BAO Plugins	Animation Tools	BAO Shape Layer Tools
1543	BAO Plugins	Animation Tools	BAO Snake
1544	BAO Plugins	Animation Tools	BAO Supercomp
1545	Mettle	3D Objects	Flux
1546	Mettle	3D Objects	FreeForm Pro
1547	Mettle	3D Objects	Mantra V2
1548	Mettle	3D Objects	ShapeShifter AE
1549	Crossphere	Distort	Crossphere Lens
1550	Crossphere	Distort	Crossphere Polar
1551	Crossphere	Distort	Crossphere Refract
1552	Crossphere	Distort	Crossphere Sphere
1553	Crossphere	Distort	Crossphere Twist
1554	Crossphere	Distort	Crossphere Warp
1555	Crossphere	Distort	Crossphere Zoom
1556	ProductionCrate	3D Objects	3D Extrude
1557	ProductionCrate	3D Objects	3D Extrude Advanced
1558	ProductionCrate	3D Objects	3D Text
1559	ProductionCrate	3D Objects	3D Text Extrude
1560	ProductionCrate	3D Objects	3D Text Shatter
1561	ProductionCrate	3D Objects	Model Loader
1562	ProductionCrate	3D Objects	Model Renderer
1563	ProductionCrate	3D Objects	Particle 3D
1564	ProductionCrate	Effects	Action Distortion
1565	ProductionCrate	Effects	Ash
1566	ProductionCrate	Effects	Blood
1567	ProductionCrate	Effects	Dust
1568	ProductionCrate	Effects	Electricity
1569	ProductionCrate	Effects	Explosion
1570	ProductionCrate	Effects	Fire
1571	ProductionCrate	Effects	Fog
1572	ProductionCrate	Effects	Glitch
1573	ProductionCrate	Effects	Glow
1574	ProductionCrate	Effects	Heat Distortion
1575	ProductionCrate	Effects	Impact
1576	ProductionCrate	Effects	Lens Flare
1577	ProductionCrate	Effects	Lightning
1578	ProductionCrate	Effects	Magic
1579	ProductionCrate	Effects	Particles
1580	ProductionCrate	Effects	Smoke
1581	ProductionCrate	Effects	Sparks
1582	ProductionCrate	Effects	Stylized Energy
1583	ProductionCrate	Effects	Water
1584	ProductionCrate	Effects	Weather
1585	ProductionCrate	Key & Blend	Keying Assets
1586	ProductionCrate	Lights	Lens Flare
1587	ProductionCrate	Lights	Light Leak
1588	ProductionCrate	Particles	Particle 3D
1589	ProductionCrate	Particles	Particles
1590	ProductionCrate	Render	3D Text
1591	ProductionCrate	Render	Model Renderer
1592	ElementSupply Co	Stylize	Low Poly
1593	ElementSupply Co	Stylize	Low Poly FX
1594	Zaebects	Animation Tools	Cartoon Moblur
1595	Zaebects	Animation Tools	Datamosh
1596	Zaebects	Animation Tools	LottieFiles AE
1597	Zaebects	Animation Tools	Motion Tools Pro
1598	Zaebects	Animation Tools	TextExploder
1599	Zaebects	Animation Tools	TextFlex
1600	Zaebects	Animation Tools	Texturize
1601	Zaebects	Animation Tools	Type
1602	Pixel Sorter Studio	Effects	Pixel Sorter Studio
1603	Pixel Sorter Studio	Effects	Pixel Sorter Studio 2
1604	Pixel Sorter Studio	Effects	Pixel Sorter Studio 3
1605	Pixel Sorter Studio	Effects	Pixel Sorter Studio Edge
1606	Pixel Sorter Studio	Effects	Pixel Sorter Studio Glitch
1607	Pixel Sorter Studio	Effects	Pixel Sorter Studio Lines
1608	Pixel Sorter Studio	Effects	Pixel Sorter Studio Masks
1609	Pixel Sorter Studio	Effects	Pixel Sorter Studio Noise
1610	Pixel Sorter Studio	Effects	Pixel Sorter Studio Pro
1611	Pixel Sorter Studio	Effects	Pixel Sorter Studio RGB
1612	Pixel Sorter Studio	Effects	Pixel Sorter Studio Trails
1613	Pixel Sorter Studio	Effects	Pixel Sorter Studio Transitions
1614	Pixel Sorter Studio	Effects	Pixel Sorter Studio Warp
1615	Satori	Stylize	Blocky
1616	Satori	Stylize	Cell Shader
1617	Satori	Stylize	Halftone
1618	Satori	Stylize	Line Art
1619	Satori	Stylize	Low Poly
1620	Satori	Stylize	Pixelate
1621	Satori	Stylize	Posterize
1622	Satori	Stylize	Sketch
1623	Satori	Stylize	Toon
1624	Irrealix	Generate	Bezier Noise
1625	Irrealix	Generate	Cell Noise
1626	Irrealix	Generate	Cloud Noise
1627	Irrealix	Generate	Flow Noise
1628	Irrealix	Generate	Fractal Noise
1629	Irrealix	Generate	Gradient Noise
1630	Irrealix	Generate	Grid Noise
1631	Irrealix	Generate	Perlin Noise
1632	Irrealix	Generate	Simplex Noise
1633	Irrealix	Generate	Turbulence Noise
1634	Irrealix	Generate	Voronoi Noise
1635	AndrewYang	Generate	Abstract Lines
1636	AndrewYang	Generate	Fractal Lines
1637	AndrewYang	Generate	Grid Lines
1638	AndrewYang	Generate	Motion Lines
1639	AndrewYang	Generate	Wave Lines
1640	BGRA Entertainment	Stylize	Analog Damage
1641	BGRA Entertainment	Stylize	Digital Damage
1642	Dragoy	Stylize	Cartoonizer
1643	Dragoy	Stylize	Painterly
1644	Blace Plugins	Animation Tools	Auto Crop
1645	Blace Plugins	Animation Tools	Auto Fill
1646	Blace Plugins	Animation Tools	Auto Frame
1647	Blace Plugins	Animation Tools	Auto Resize
1648	Blace Plugins	Animation Tools	Auto Scale
1649	Blace Plugins	Animation Tools	Auto Track
1650	Blace Plugins	Animation Tools	Batch Replace
1651	Blace Plugins	Animation Tools	Comp Setter
1652	Blace Plugins	Animation Tools	Layer Selector
1653	Blace Plugins	Animation Tools	Mask Helper
1654	Blace Plugins	Animation Tools	Motion Helper
1655	Blace Plugins	Animation Tools	Precomp Helper
1656	Blace Plugins	Animation Tools	Render Helper
1657	Blace Plugins	Animation Tools	Sequence Helper
1658	Blace Plugins	Animation Tools	Text Helper
1659	Blace Plugins	Animation Tools	Time Helper
1660	Blace Plugins	Animation Tools	Transform Helper
1661	Blace Plugins	Animation Tools	Utility Helper
1662	Blace Plugins	Animation Tools	Version Helper
1663	Blace Plugins	Animation Tools	Workflow Helper
1664	Blace Plugins	Animation Tools	Workspace Helper
1665	FilmConvert	Color & Tone	CineMatch
1666	FilmConvert	Color & Tone	FilmConvert Nitrate
1667	FilmConvert	Color & Tone	FilmConvert Pro
1668	FilmConvert	Color & Tone	Halation
1669	AutoKroma	Utilities	AfterCodecs
1670	AutoKroma	Utilities	BRAW Studio
1671	AutoKroma	Utilities	Influx
1672	AutoKroma	Utilities	PlumePack
1673	BASKL	Animation Tools	Auto Crop
1674	BASKL	Animation Tools	Auto Resize
1675	BASKL	Animation Tools	Batch Render
1676	BASKL	Animation Tools	Comp Manager
1677	BASKL	Animation Tools	Expression Helper
1678	BASKL	Animation Tools	Layer Manager
1679	BASKL	Animation Tools	Motion Helper
1680	BASKL	Animation Tools	Preset Manager
1681	BASKL	Animation Tools	Render Manager
1682	BASKL	Animation Tools	Utility Pack
1683	Vimager	Effects	Chromatic Aberration
1684	Vimager	Effects	Film Damage
1685	Vimager	Effects	Glitch
1686	Vimager	Effects	Glow
1687	Vimager	Effects	Halation
1688	Vimager	Effects	Light Leak
1689	Vimager	Effects	Noise
1690	Vimager	Effects	VHS
1691	Frischluft	Blur & Sharpen	fl Depth of Field
1692	Frischluft	Blur & Sharpen	fl Lenscare
1693	Frischluft	Blur & Sharpen	fl Lenscare Out of Focus
1694	Frischluft	Blur & Sharpen	fl Lenscare Pro
1695	Frischluft	Blur & Sharpen	fl Lenscare Refocus
1696	Frischluft	Blur & Sharpen	fl Lenscare Z-Depth
1697	Frischluft	Blur & Sharpen	fl Lenscare Z-Defocus
1698	Frischluft	Blur & Sharpen	fl Lenscare Z-Glow
1699	Frischluft	Blur & Sharpen	fl Lenscare Z-Lens
1700	Frischluft	Blur & Sharpen	fl Lenscare Z-Refocus
1701	Other requested / notable	Animation Tools	EaseCopy
1702	Other requested / notable	Animation Tools	EaseCopy Plus
1703	Other requested / notable	Animation Tools	Motion 4
1704	Other requested / notable	Animation Tools	Motion 4 Pro
1705	Other requested / notable	Animation Tools	Motion Tools
1706	Other requested / notable	Animation Tools	Motion Tools Pro
1707	Other requested / notable	Animation Tools	Flow
1708	Other requested / notable	Animation Tools	Flow Pro
1709	Other requested / notable	Effects	Composite Brush
1710	Other requested / notable	Effects	Deep Glow
1711	Other requested / notable	Effects	Deep Glow 2
1712	Other requested / notable	Effects	Displacer Pro
1713	Other requested / notable	Effects	Glitchify
1714	Other requested / notable	Effects	Goo
1715	Other requested / notable	Effects	Halftone Pro
1716	Other requested / notable	Effects	Shadow Studio
1717	Other requested / notable	Effects	Shadow Studio 3
1718	Other requested / notable	Keying	Composite Brush
1719	Other requested / notable	Keying	Primatte Keyer
1720	Other requested / notable	Keying	Primatte Studio
1721	Other requested / notable	Tracking	Mocha Pro
1722	Other requested / notable	Tracking	Spot Clone Tracker
1723	Other requested / notable	Utilities	FX Console
1724	Other requested / notable	Utilities	Mocha Pro
1725	Other requested / notable	Utilities	Optics 2026
1726	Other requested / notable	Utilities	Silhouette RotoPaint
1727	Extensions	Asset Browser	Aescript imgPaster V1
1728	Extensions	Automation Workflow	Aescripts Bodymovin v5.12.0
1729	Extensions	Project Workflow	Aescripts Manager 2026
1730	Extensions	Project Workflow	Aescripts Manager App
1731	Extensions	Motion Easing	Aescripts Motion v4.3.3
1732	Extensions	Project Workflow	Aescripts Ray Dynamic Color v2.5.10
1733	Extensions	Motion Easing	Aescripts Rift v1.4.0
1734	Extensions	Motion Easing	Aescripts Sequence Layers v1.2.2
1735	Extensions	Shape Tool	Aescripts Shape Monkey v1.2.8
1736	Extensions	Text Tool	Aescripts TextExploder v3.0.002
1737	Extensions	Text Tool	Aescripts TextFlex v1.0
1738	Extensions	Text Tool	Aescripts Type v1.5.2
1739	Extensions	Project Workflow	Aescripts Ukramedia Smart Bundle
1740	Extensions	Motion Easing	Aescripts Universal Audio v1.6.95
1741	Extensions	Motion Easing	Aescripts Vybe v1.01
1742	Extensions	Asset Browser	AEJuice Pack Manager v4.8.4
1743	Extensions	Project Workflow	BeatEdit v2.3.3
1744	Extensions	Animation Workflow	Boombox v1.0.4
1745	Extensions	Automation Workflow	ButtCapper v1.4.1
1746	Extensions	Project Workflow	Color Locker v1.0.0
1747	Extensions	Asset Browser	CompCode v1.1.0
1748	Extensions	Automation Workflow	DUIK Bassel v17.1.6
1749	Extensions	Project Workflow	EaseCopy v1.0.5
1750	Extensions	Project Workflow	Flow v1.4.2
1751	Extensions	Asset Browser	Font Manager v1.2.5
1752	Extensions	Project Workflow	FX Console v1.0.5
1753	Extensions	Project Workflow	Joysticks n Sliders v1.7.9
1754	Extensions	Automation Workflow	Keystone v2.0.3
1755	Extensions	Project Workflow	Lazy 2 v2.4.1
1756	Extensions	Project Workflow	Motion 4 v4.1.2
1757	Extensions	Project Workflow	Overlord v2.1.0
1758	Extensions	Project Workflow	Paste Multiple Keyframes v1.2.3
1759	Extensions	Project Workflow	PenPal v1.0.2
1760	Extensions	Project Workflow	Projector v1.0.4
1761	Extensions	Project Workflow	Quick Delete & Reset v2.1
1762	Extensions	Project Workflow	Ray Dynamic Color 2 v2.5.10
1763	Extensions	Project Workflow	Reach AEssential Kit v1.9.5
1764	Extensions	Project Workflow	React v1.0.1
1765	Extensions	Project Workflow	Rift v1.4.0
1766	Extensions	Animation Workflow	Sequence Layers v1.2.2
1767	Extensions	Shape Tool	Shape Monkey v1.2.8
1768	Extensions	Project Workflow	SwissKnife v1.1.7
1769	Extensions	Text Tool	Text Animator Suite
1770	Extensions	Text Tool	TextExploder v3.0.002
1771	Extensions	Text Tool	TextFlex v1.0
1772	Extensions	Text Tool	textoevo2
1773	Extensions	Text Tool	Type v1.5.2
1774	Extensions	Asset Browser	Ukramedia Smart Bundle
1775	Extensions	Project Workflow	Universal Audio v1.6.95
1776	Extensions	Project Workflow	Vybe v1.01
1777	Scripts	3D Camera	3DfyPro
1778	Scripts	Project Tool	AE Global Renamer
1779	Scripts	Project Tool	AE Nudge 2
1780	Scripts	Project Tool	Anchor Sniper
1781	Scripts	Project Tool	Auto Crop
1782	Scripts	Text Tool	AutoFill
1783	Scripts	Project Tool	Auto Resize
1784	Scripts	Keyframe Tool	BeatGrid
1785	Scripts	3D Camera	Camera Rig
1786	Scripts	Project Tool	Comp Setter
1787	Scripts	Design Generator	CompCode
1788	Scripts	Typography	Font Manager
1789	Scripts	Project Tool	FX Console
1790	Scripts	Motion Easing	Flow v1.4.2
1791	Scripts	Motion Easing	Lazy 2 v2.4.1
1792	Scripts	Motion Easing	Motion 4 v4.1.2
1793	Scripts	Design Generator	MOGRT Maker
1794	Scripts	Path Shape	Mask Avenger
1795	Scripts	Text Tool	MonkeyWords v1.1
1796	Scripts	Design Generator	MazeFX v1.32
1797	Scripts	Path Shape	Motion Path Pro v1.0
1798	Scripts	Path Shape	Origami v1.4.0
1799	Scripts	Design Generator	Polka Dots Maker v1.2
1800	Scripts	Utility Workflow	Quick Delete & Reset 2.1
1801	Scripts	Layer Management	Rapid Reel Composer
1802	Scripts	Color	Ray Dynamic Color 2 v2.5.10
1803	Scripts	Utility Workflow	Reach AEssential Kit v1.9.5
1804	Scripts	Audio Sync	React v1.0.1
1805	Scripts	Design Generator	Splash v1.03
1806	Scripts	Path Shape	Super Lines 1.4.7
1807	Scripts	Utility Workflow	SwissKnife 1.1.7
1808	Scripts	Text Tool	Text Animator Suite
1809	Scripts	Text Tool	TextExploder v3.0.002
1810	Scripts	Text Tool	TextFlex 1.0
1811	Scripts	Text Tool	textoevo2
1812	Scripts	Text Tool	Type 1.5.2
1813	Scripts	Utility Workflow	Ukramedia Smart Bundle
1814	Scripts	Audio Sync	Universal Audio v1.6.95
1815	Scripts	Motion Easing	Vybe 1.01
"""
}
