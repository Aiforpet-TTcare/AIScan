import AIScanCore

/// AIScan service environment reserved for internal validation.
@_spi(AIScanDevelopment)
public enum AIScanEnvironment: Sendable {
    case production
    case development
}

extension AIScanEnvironment {
    var coreValue: AISCEnvironment {
        switch self {
        case .production:
            .production
        case .development:
            .development
        }
    }
}

/// 반려동물 종류를 지정하는 공개 호환 타입입니다.
public enum PetType: String, Sendable {
    case dog
    case cat
}

/// 스캔할 신체 부위를 지정하는 공개 호환 타입입니다.
///
/// 세부 피부 부위는 공개 UI와 결과 카탈로그에서는 구분하지만,
/// 보안 Core에는 모두 피부 스캔으로 전달합니다.
public enum PartType: Hashable, Sendable {
    case eye
    case ear
    case belly
    case foot
    case tooth
    case skin

    public var key: String {
        switch self {
        case .eye:
            "EYE"
        case .tooth:
            "TOOTH"
        case .ear, .belly, .foot, .skin:
            "SKIN"
        }
    }

    public var platformPart: String {
        switch self {
        case .eye:
            "eye"
        case .tooth:
            "teeth"
        case .ear, .belly, .foot, .skin:
            "skin"
        }
    }

    public var catalogKey: String {
        switch self {
        case .eye:
            "EYE"
        case .ear:
            "EAR"
        case .belly, .skin:
            "BODY"
        case .foot:
            "FOOT"
        case .tooth:
            "TEETH"
        }
    }

    public var detailKey: String {
        switch self {
        case .eye:
            "EYE"
        case .tooth:
            "TOOTH"
        case .ear:
            "EAR"
        case .belly:
            "BELLY"
        case .skin:
            "SKIN"
        case .foot:
            "FOOT"
        }
    }
}

extension PetType {
    var coreValue: AISCPetType {
        switch self {
        case .dog:
            .dog
        case .cat:
            .cat
        }
    }
}

extension PartType {
    var coreValue: AISCPartType {
        switch self {
        case .eye:
            .eye
        case .tooth:
            .teeth
        case .ear, .belly, .foot, .skin:
            .skin
        }
    }

    var displaySubpart: String? {
        switch self {
        case .ear, .belly, .foot, .skin:
            detailKey
        case .eye, .tooth:
            nil
        }
    }

    var analysisPosition: String? {
        switch self {
        case .ear:
            "ear"
        case .belly:
            "belly"
        case .foot:
            "foot"
        case .eye, .tooth, .skin:
            nil
        }
    }
}
