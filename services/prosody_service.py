"""
Damisola 담당 - 운율 분석 서비스
librosa(+Praat/parselmouth) 기반 피치 · 리듬 · 강세 · 음색(MFCC)을 추출하고
DTW / Cosine 유사도로 원어민 대비 점수를 산출한다.
"""
import json
import os
import tempfile
from pathlib import Path
import numpy as np
import librosa
from fastdtw import fastdtw
from scipy.spatial.distance import euclidean, cosine

# ── 러시아 억양 프로필 로드 ────────────────────────────────────────────
_RUSSIAN_PROFILE_PATH = Path(__file__).parent.parent / "data" / "russian_accent_profile.npy"
_russian_profile: np.ndarray | None = None
_NATIVE_SPEECH_PROFILE_PATH = Path(__file__).parent.parent / "data" / "native_profile.json"
_RUSSIAN_SPEECH_PROFILE_PATH = Path(__file__).parent.parent / "data" / "russian_profile.json"
_native_speech_profile: dict | None = None
_russian_speech_profile: dict | None = None

def _get_russian_profile() -> np.ndarray | None:
    global _russian_profile
    if _russian_profile is None and _RUSSIAN_PROFILE_PATH.exists():
        _russian_profile = np.load(_RUSSIAN_PROFILE_PATH)
    return _russian_profile

# Praat bindings (선택적 의존성)
try:
    import parselmouth  # praat-parselmouth
    PRAAT_AVAILABLE = True
except ImportError:
    PRAAT_AVAILABLE = False

# ── 분석 파라미터 ──────────────────────────────────────────────────────
FRAME_LENGTH = 2048
HOP_LENGTH = 512
FMIN = 75    # Hz - 사람 목소리 최소 주파수
FMAX = 400   # Hz - 사람 목소리 최대 주파수
N_MFCC = 13

# Profile scoring is conservative because app recordings vary by device,
# distance, and room noise. Minimum spreads and capped distances keep one
# unstable feature from dominating the final score.
PROFILE_DISTANCE_CAP = 3.0
PROFILE_STD_FLOORS = {
    "pitch_mean": 20.0,
    "pitch_std": 12.0,
    "pitch_range": 45.0,
    "speech_rate": 2.0,
    "pause_count": 1.5,
    "pause_total_duration": 0.5,
    "voiced_ratio": 0.10,
    "energy_mean": 0.06,
    "energy_std": 0.04,
    "pitch_slope": 0.75,
    "syllable_count": 12.0,
    # 포먼트는 추출기/시간축 정상화 후 원어민 std가 F1~75, F2~82 수준이라
    # 옛 floor(350/500)는 거리를 0으로 눌러버린다. 실제 std보다 약간 낮게 설정.
    "formant_f1_mean": 50.0,
    "formant_f2_mean": 60.0,
}

# 러시아어 억양 감지 임계값
KOREAN_MIN_PITCH_VARIANCE = 500.0
FLAT_PITCH_THRESHOLD = 300.0

# DTW 정규화 거리 기준 (튜닝 대상)
DTW_PITCH_MAX = 150.0    # Hz
DTW_RHYTHM_MAX = 0.5     # seconds (onset 간격)
DTW_STRESS_MAX = 0.1     # RMS amplitude
DTW_FORMANT_NORM_MAX = 1.5   # z-score 단위 — 화자 독립적 정규화 후 DTW 거리 기준

# 말하기 속도 / 쉼표 파라미터
RMS_SILENCE_THRESHOLD = 0.01   # RMS 이하면 묵음으로 판단
MIN_PAUSE_DURATION = 0.15      # 이 초 이상 연속 묵음이어야 pause로 집계


# ── 내부 유틸 ─────────────────────────────────────────────────────────
def _infer_suffix(audio_bytes: bytes) -> str:
    """magic bytes로 컨테이너 포맷 추정."""
    if audio_bytes[:4] == b'\x1a\x45\xdf\xa3':
        return '.webm'
    if len(audio_bytes) > 8 and audio_bytes[4:8] == b'ftyp':
        return '.mp4'
    if audio_bytes[:4] == b'RIFF':
        return '.wav'
    return '.wav'


def _with_tempfile(audio_bytes: bytes) -> str:
    """오디오 바이트를 실제 WAV(16kHz mono)로 변환해 임시 파일로 저장."""
    from pydub import AudioSegment
    suffix = _infer_suffix(audio_bytes)
    src_tmp = tempfile.NamedTemporaryFile(suffix=suffix, delete=False)
    try:
        src_tmp.write(audio_bytes)
        src_tmp.close()
        try:
            audio = AudioSegment.from_file(src_tmp.name)
            original_dBFS = audio.dBFS
            if original_dBFS != float("-inf") and original_dBFS < -20:
                audio = audio.normalize()
                print(f"[Prosody] 음량 정규화 적용 ({original_dBFS:.1f} dBFS → 0 dBFS)")
            audio = audio.set_frame_rate(16000).set_channels(1)
            out_tmp = tempfile.NamedTemporaryFile(suffix=".wav", delete=False)
            audio.export(out_tmp.name, format="wav")
            out_tmp.close()
            return out_tmp.name
        except Exception:
            # 변환 실패 시 원본 바이트를 그대로 저장
            out_tmp = tempfile.NamedTemporaryFile(suffix=".wav", delete=False)
            out_tmp.write(audio_bytes)
            out_tmp.close()
            return out_tmp.name
    finally:
        try:
            os.unlink(src_tmp.name)
        except Exception:
            pass


# ── 피처 추출 ─────────────────────────────────────────────────────────
def extract_pitch(audio_bytes: bytes) -> np.ndarray:
    """librosa.pyin 기반 F0 곡선. 무성음은 0."""
    tmp_path = _with_tempfile(audio_bytes)
    try:
        y, sr = librosa.load(tmp_path, sr=None)
        if len(y) == 0:
            return np.array([])
        f0, _, _ = librosa.pyin(
            y, fmin=FMIN, fmax=FMAX, sr=sr,
            frame_length=FRAME_LENGTH, hop_length=HOP_LENGTH,
        )
        pitch = np.nan_to_num(f0, nan=0.0)
        if np.count_nonzero(pitch) > 0:
            return pitch

        # pYIN returns all-zero only for completely silent/unvoiced audio.
        # Use YIN as fallback, masking silent frames with RMS threshold.
        yin = librosa.yin(
            y,
            fmin=FMIN,
            fmax=FMAX,
            sr=sr,
            frame_length=FRAME_LENGTH,
            hop_length=HOP_LENGTH,
        )
        yin_pitch = np.nan_to_num(yin, nan=0.0)
        rms = librosa.feature.rms(y=y, hop_length=HOP_LENGTH)[0]
        if len(rms) == len(yin_pitch):
            yin_pitch[rms <= RMS_SILENCE_THRESHOLD] = 0.0
        return yin_pitch
    finally:
        os.unlink(tmp_path)


def extract_pitch_praat(audio_bytes: bytes) -> np.ndarray:
    """Praat(parselmouth) 기반 F0. librosa 결과 교차 검증용."""
    if not PRAAT_AVAILABLE:
        return np.array([])
    tmp_path = _with_tempfile(audio_bytes)
    try:
        sound = parselmouth.Sound(tmp_path)
        pitch = sound.to_pitch(pitch_floor=FMIN, pitch_ceiling=FMAX)
        values = pitch.selected_array['frequency']
        return np.nan_to_num(values, nan=0.0)
    except Exception:
        return np.array([])
    finally:
        os.unlink(tmp_path)


def _normalize_voiced(arr: np.ndarray) -> np.ndarray:
    """유성 프레임(>0)만 z-score 정규화. 무성(0)은 0으로 유지."""
    voiced = arr[arr > 0]
    if len(voiced) < 3:
        return arr
    mu, sigma = voiced.mean(), voiced.std()
    if sigma < 1e-6:
        return np.zeros_like(arr, dtype=float)
    result = arr.copy().astype(float)
    result[result > 0] = (result[result > 0] - mu) / sigma
    return result


def extract_formant_track(audio_bytes: bytes) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """Praat 기반 프레임별 (times, F1, F2) 트랙. Praat 미설치 시 빈 배열."""
    if not PRAAT_AVAILABLE:
        return np.array([]), np.array([]), np.array([])
    tmp_path = _with_tempfile(audio_bytes)
    try:
        sound = parselmouth.Sound(tmp_path)
        # Praat 표준 설정: 0~5500Hz에서 5개 포먼트를 추정한 뒤 앞의 2개(F1/F2)만 사용.
        # max_number_of_formants=2로 두면 두 극이 전 대역으로 밀려 F1/F2가 비정상적으로
        # 높게(예: F1~2900, F2~4300) 나오므로 반드시 5로 둔다.
        formant = sound.to_formant_burg(
            time_step=HOP_LENGTH / 16000,
            max_number_of_formants=5,
            maximum_formant=5500,
        )
        # formant.xs()가 시간축을 제대로 안 주는 경우가 있어 프레임 번호 → 시간으로 재구성.
        n = formant.get_number_of_frames()
        times = np.array([formant.get_time_from_frame_number(i + 1) for i in range(n)])
        f1 = np.nan_to_num(np.array([formant.get_value_at_time(1, t) for t in times]), nan=0.0)
        f2 = np.nan_to_num(np.array([formant.get_value_at_time(2, t) for t in times]), nan=0.0)
        return times, f1, f2
    except Exception:
        return np.array([]), np.array([]), np.array([])
    finally:
        os.unlink(tmp_path)


def extract_formants(audio_bytes: bytes) -> tuple[np.ndarray, np.ndarray]:
    """F1/F2 프레임 배열만 반환 (시간축 제외)."""
    _, f1, f2 = extract_formant_track(audio_bytes)
    return f1, f2


def extract_hnr_mean(audio_bytes: bytes) -> float | None:
    """평균 HNR(배음대잡음비, dB). 유성 음성은 높고(>5) 소음은 낮음(<0).
    신호가 진짜 '말소리'인지 판단하는 데 사용. Praat 미설치 시 None."""
    if not PRAAT_AVAILABLE:
        return None
    tmp_path = _with_tempfile(audio_bytes)
    try:
        sound = parselmouth.Sound(tmp_path)
        harmonicity = sound.to_harmonicity()
        vals = np.asarray(harmonicity.values).ravel()
        vals = vals[vals > -100]  # -200 = Praat '정의 안 됨' 프레임 제외
        if not len(vals):
            return None
        return round(float(np.mean(vals)), 2)
    except Exception:
        return None
    finally:
        os.unlink(tmp_path)


def extract_rhythm(audio_bytes: bytes) -> np.ndarray:
    """onset 감지 후 인접 onset 시간 간격(초) 배열 반환."""
    tmp_path = _with_tempfile(audio_bytes)
    try:
        y, sr = librosa.load(tmp_path, sr=None)
        onsets = librosa.onset.onset_detect(
            y=y, sr=sr, units='time', hop_length=HOP_LENGTH,
        )
        if len(onsets) < 2:
            return np.array([])
        return np.diff(onsets)
    finally:
        os.unlink(tmp_path)


def extract_speech_rate(audio_bytes: bytes) -> dict:
    """
    말하기 속도: 음절 수(onset 개수) / 발화 시간(초).
    유성 구간만 기준으로 하여 앞뒤 묵음은 제외.
    """
    tmp_path = _with_tempfile(audio_bytes)
    try:
        y, sr = librosa.load(tmp_path, sr=None)
        total_dur = librosa.get_duration(y=y, sr=sr)

        onsets = librosa.onset.onset_detect(
            y=y, sr=sr, units='time', hop_length=HOP_LENGTH,
        )
        syllable_count = max(len(onsets), 1)

        # 유성 구간(RMS > 임계치) 길이만 발화 시간으로 사용
        rms = librosa.feature.rms(y=y, hop_length=HOP_LENGTH)[0]
        voiced_frames = np.sum(rms > RMS_SILENCE_THRESHOLD)
        voiced_dur = float(voiced_frames * HOP_LENGTH / sr)
        if voiced_dur < 0.1:
            voiced_dur = total_dur  # 전부 묵음이면 전체 길이로 대체

        rate = round(syllable_count / voiced_dur, 2)
        return {"syllable_count": syllable_count, "voiced_duration": round(voiced_dur, 3), "rate": rate}
    finally:
        os.unlink(tmp_path)


def extract_pause_pattern(audio_bytes: bytes) -> dict:
    """
    묵음 구간 감지: RMS < 임계치인 연속 프레임을 pause로 집계.
    Returns: pause_count, pause_durations(초 목록), total_pause_duration
    """
    tmp_path = _with_tempfile(audio_bytes)
    try:
        y, sr = librosa.load(tmp_path, sr=None)
        rms = librosa.feature.rms(y=y, hop_length=HOP_LENGTH)[0]

        frame_dur = HOP_LENGTH / sr
        in_pause = False
        pause_len = 0
        pauses: list[float] = []

        for val in rms:
            if val < RMS_SILENCE_THRESHOLD:
                in_pause = True
                pause_len += 1
            else:
                if in_pause and pause_len * frame_dur >= MIN_PAUSE_DURATION:
                    pauses.append(round(pause_len * frame_dur, 3))
                in_pause = False
                pause_len = 0
        if in_pause and pause_len * frame_dur >= MIN_PAUSE_DURATION:
            pauses.append(round(pause_len * frame_dur, 3))

        return {
            "pause_count": len(pauses),
            "pause_durations": pauses,
            "total_pause_duration": round(sum(pauses), 3),
        }
    finally:
        os.unlink(tmp_path)


def generate_rhythm_feedback(
    user_rate: float,
    ref_rate: float,
    user_pauses: dict,
    ref_pauses: dict,
    rhythm_score: float,
) -> str:
    """말하기 속도·쉼표 비교 기반 한국어 피드백 텍스트 생성."""
    feedbacks: list[str] = []

    if ref_rate > 0:
        ratio = user_rate / ref_rate
        if ratio > 1.25:
            feedbacks.append("조금 천천히 말해봐요! 서두르지 않아도 돼요.")
        elif ratio < 0.75:
            feedbacks.append("조금 더 빠르게 말해봐요! 자신 있게 해봐요!")
        else:
            feedbacks.append("말하기 속도가 딱 맞아요!")

    pause_diff = user_pauses["pause_count"] - ref_pauses["pause_count"]
    if pause_diff > 1:
        feedbacks.append("쉬지 않고 이어서 말해봐요!")
    elif pause_diff < -1:
        feedbacks.append("중간에 잠깐 쉬어봐요!")

    if rhythm_score < 40:
        feedbacks.append("'원어민 발음 듣기' 버튼을 눌러서 다시 들어봐요!")
    elif rhythm_score < 70:
        feedbacks.append("리듬이 거의 맞아요! 조금만 더 하면 완벽해요!")

    return " ".join(feedbacks) if feedbacks else "리듬이 딱 맞아요! 최고예요!"


def extract_energy(audio_bytes: bytes) -> np.ndarray:
    """RMS 에너지 곡선 — 강세 패턴 근사치."""
    tmp_path = _with_tempfile(audio_bytes)
    try:
        y, _ = librosa.load(tmp_path, sr=None)
        return librosa.feature.rms(y=y, hop_length=HOP_LENGTH)[0]
    finally:
        os.unlink(tmp_path)


def extract_mfcc(audio_bytes: bytes) -> np.ndarray:
    """MFCC 13차원 평균 벡터 (발음/음색 특징)."""
    tmp_path = _with_tempfile(audio_bytes)
    try:
        y, sr = librosa.load(tmp_path, sr=None)
        mfcc = librosa.feature.mfcc(
            y=y, sr=sr, n_mfcc=N_MFCC, hop_length=HOP_LENGTH,
        )
        return mfcc.mean(axis=1)
    finally:
        os.unlink(tmp_path)


def _get_speech_profiles() -> tuple[dict | None, dict | None]:
    global _native_speech_profile, _russian_speech_profile
    if _native_speech_profile is None and _NATIVE_SPEECH_PROFILE_PATH.exists():
        with open(_NATIVE_SPEECH_PROFILE_PATH, encoding="utf-8") as f:
            _native_speech_profile = json.load(f)
    if _russian_speech_profile is None and _RUSSIAN_SPEECH_PROFILE_PATH.exists():
        with open(_RUSSIAN_SPEECH_PROFILE_PATH, encoding="utf-8") as f:
            _russian_speech_profile = json.load(f)
    return _native_speech_profile, _russian_speech_profile


def _voiced_ratio(pitch: np.ndarray) -> float | None:
    voiced_idx = np.where(pitch > 0)[0]
    if len(voiced_idx) == 0:
        return None
    segment = pitch[voiced_idx[0]: voiced_idx[-1] + 1]
    if len(segment) == 0:
        return None
    return round(float(np.sum(segment > 0) / len(segment)), 4)


def extract_profile_features(audio_bytes: bytes) -> dict:
    pitch = extract_pitch(audio_bytes)
    voiced = pitch[pitch > 0]
    rate_info = extract_speech_rate(audio_bytes)
    pause_info = extract_pause_pattern(audio_bytes)
    energy = extract_energy(audio_bytes)
    mfcc = extract_mfcc(audio_bytes)
    formant_f1, formant_f2 = extract_formants(audio_bytes)
    voiced_f1 = formant_f1[formant_f1 > 0] if len(formant_f1) else np.array([])
    voiced_f2 = formant_f2[formant_f2 > 0] if len(formant_f2) else np.array([])

    pitch_slope = None
    if len(voiced) >= 5:
        target = 50
        x = np.linspace(0, 1, len(voiced))
        y = np.interp(np.linspace(0, 1, target), x, voiced)
        pitch_slope = round(float(np.polyfit(np.arange(target), y, 1)[0]), 4)

    return {
        "mfcc_mean": [round(float(v), 6) for v in mfcc.tolist()] if len(mfcc) else [],
        "pitch_mean": round(float(np.mean(voiced)), 4) if len(voiced) else None,
        "pitch_std": round(float(np.std(voiced)), 4) if len(voiced) else None,
        "pitch_range": round(float(np.max(voiced) - np.min(voiced)), 4) if len(voiced) else None,
        "speech_rate": float(rate_info["rate"]) if rate_info.get("rate") is not None else None,
        "pause_count": int(pause_info.get("pause_count", 0)),
        "pause_total_duration": float(pause_info.get("total_pause_duration", 0.0)),
        "voiced_ratio": _voiced_ratio(pitch),
        # 전체 구간 기준 유성 프레임 비율 (신뢰성 판단용; voiced_ratio는 유성 구간 내부 비율이라 별도).
        "voiced_frame_ratio": round(float(np.mean(pitch > 0)), 4) if len(pitch) else None,
        "hnr_mean": extract_hnr_mean(audio_bytes),  # 신뢰성 판단용 (소음 검출)
        "energy_mean": round(float(np.mean(energy)), 4) if len(energy) else None,
        "energy_std": round(float(np.std(energy)), 4) if len(energy) else None,
        "pitch_slope": pitch_slope,
        "syllable_count": int(rate_info.get("syllable_count", 0)),
        "formant_f1_mean": round(float(np.mean(voiced_f1)), 4) if len(voiced_f1) else None,
        "formant_f2_mean": round(float(np.mean(voiced_f2)), 4) if len(voiced_f2) else None,
    }


def _scalar_profile_distance(value: float | None, profile: dict, name: str) -> float | None:
    if value is None:
        return None
    mean = profile.get(f"{name}_mean")
    std = profile.get(f"{name}_std")
    if mean is None:
        return None
    denom = float(std or 0.0)
    denom = max(denom, PROFILE_STD_FLOORS.get(name, 0.0))
    if denom < 1e-6:
        denom = max(abs(float(mean)), 1.0)
    return min(abs(float(value) - float(mean)) / denom, PROFILE_DISTANCE_CAP)


def _vector_profile_distance(features: dict, profile: dict, name: str) -> float | None:
    user_vec = np.array(features.get(name) or [], dtype=float)
    profile_vec = np.array(profile.get(name) or [], dtype=float)
    if not len(user_vec) or len(user_vec) != len(profile_vec):
        return None
    return float(cosine(user_vec, profile_vec))


def _profile_distance(features: dict, profile: dict) -> tuple[float | None, dict]:
    # mfcc(음색)는 원어민도 낮게 나오고 소음/녹음환경에 흔들려 비중을 낮춤.
    # speech_rate(템포)는 같은 발화에서도 ±10% 속도로 점수를 크게 흔들어 비중을 낮춤.
    weights = {
        "mfcc_mean": 0.10,
        "pitch_std": 0.20,
        "pitch_range": 0.15,
        "speech_rate": 0.10,
        "pause_count": 0.15,
        "voiced_ratio": 0.20,
    }
    parts: dict[str, float] = {}

    parts["mfcc_mean"] = _vector_profile_distance(features, profile, "mfcc_mean")

    for name in ("pitch_std", "pitch_range", "speech_rate", "pause_count", "voiced_ratio"):
        parts[name] = _scalar_profile_distance(features.get(name), profile, name)

    valid = {name: value for name, value in parts.items() if value is not None}
    if not valid:
        return None, {}
    total_weight = sum(weights[name] for name in valid)
    weighted = sum(valid[name] * weights[name] for name in valid) / total_weight
    return round(float(weighted), 4), {k: round(float(v), 4) for k, v in valid.items()}


def _two_axis_score(native_distance: float | None, russian_distance: float | None) -> float | None:
    if native_distance is None or russian_distance is None:
        return None
    total = native_distance + russian_distance
    if total <= 1e-9:
        return 50.0
    return round(max(0.0, min(100.0, (russian_distance / total) * 100.0)), 1)


def _korean_proximity_score(native_distance: float | None, russian_distance: float | None) -> float | None:
    if native_distance is None or russian_distance is None:
        return None

    axis_score = _two_axis_score(native_distance, russian_distance)
    native_score = _native_axis_score(native_distance, max_distance=3.0)
    if axis_score is None or native_score is None:
        return axis_score or native_score

    if russian_distance <= native_distance:
        return axis_score

    # Overall Korean proximity should reward both direction and absolute closeness.
    # Short utterances can be close to both profiles, so pure two-axis scoring is too harsh.
    score = (axis_score * 0.55) + (native_score * 0.45)
    score += min(6.0, (russian_distance - native_distance) * 10.0)
    return round(max(0.0, min(100.0, score)), 1)


def _native_axis_score(distance: float | None, max_distance: float = 4.0) -> float | None:
    if distance is None:
        return None
    if distance < 0:
        return 0.0
    return round(max(0.0, min(100.0, 100.0 - (distance / max_distance) * 100.0)), 1)


def _feature_group_distance(features: dict, profile: dict, names: tuple[str, ...]) -> float | None:
    distances = []
    for name in names:
        distance = _scalar_profile_distance(features.get(name), profile, name)
        if distance is not None:
            distances.append(distance)
    if not distances:
        return None
    return round(float(sum(distances) / len(distances)), 4)


def _profile_subscores(features: dict, native_profile: dict, russian_profile: dict) -> dict:
    native_mfcc_distance = _vector_profile_distance(features, native_profile, "mfcc_mean")
    russian_mfcc_distance = _vector_profile_distance(features, russian_profile, "mfcc_mean")

    intonation_native = _feature_group_distance(features, native_profile, ("pitch_std", "pitch_range"))
    intonation_russian = _feature_group_distance(features, russian_profile, ("pitch_std", "pitch_range"))
    rhythm_native = _feature_group_distance(features, native_profile, ("speech_rate", "pause_count"))
    rhythm_russian = _feature_group_distance(features, russian_profile, ("speech_rate", "pause_count"))
    voice_native = _scalar_profile_distance(features.get("voiced_ratio"), native_profile, "voiced_ratio")
    voice_russian = _scalar_profile_distance(features.get("voiced_ratio"), russian_profile, "voiced_ratio")
    stress_native = _feature_group_distance(features, native_profile, ("energy_mean", "energy_std"))
    vowel_native = _feature_group_distance(features, native_profile, ("formant_f1_mean", "formant_f2_mean"))
    syllable_native = _feature_group_distance(features, native_profile, ("syllable_count",))
    slope_native = _feature_group_distance(features, native_profile, ("pitch_slope",))

    return {
        "profile_intonation_score": _two_axis_score(intonation_native, intonation_russian),
        "profile_rhythm_score": _two_axis_score(rhythm_native, rhythm_russian),
        "profile_voice_score": _two_axis_score(voice_native, voice_russian),
        # 음색(mfcc)은 원어민도 40~60점대로 깎이고 소음에 흔들려 사용자에게 보여주지 않는다.
        # (헤드라인 점수에는 낮은 가중치로만 남겨둠.)
        "profile_mfcc_score": None,
        "profile_stress_score": _native_axis_score(stress_native),
        "profile_vowel_score": _native_axis_score(vowel_native),
        "profile_syllable_score": _native_axis_score(syllable_native),
        "profile_slope_score": _native_axis_score(slope_native),
    }


def _assess_profile_reliability(features: dict) -> tuple[bool, str | None]:
    """녹음 신호가 점수를 줄 만큼 또렷한지 판단. 아니면 점수를 보류(abstain)한다.

    - voiced_ratio가 낮으면 소음/무음이 많아 운율·포먼트가 믿을 수 없음
    - 음절이 거의 안 잡히면 발화가 너무 짧음
    """
    voiced = features.get("voiced_frame_ratio")
    syllables = features.get("syllable_count", 0) or 0
    hnr = features.get("hnr_mean")
    # HNR이 낮으면 배음 구조가 약함 = 말소리가 아니라 소음/잡음
    if hnr is not None and hnr < 2.0:
        return False, "audio_unclear"
    if voiced is None or voiced < 0.35:
        return False, "audio_unclear"
    if syllables < 1:
        return False, "too_short"
    return True, None


def analyze_profile_score(audio_bytes: bytes) -> dict:
    native_profile, russian_profile = _get_speech_profiles()
    if native_profile is None or russian_profile is None:
        return {}

    features = extract_profile_features(audio_bytes)
    reliable, reason = _assess_profile_reliability(features)
    native_distance, native_parts = _profile_distance(features, native_profile)
    russian_distance, russian_parts = _profile_distance(features, russian_profile)
    subscores = _profile_subscores(features, native_profile, russian_profile)

    return {
        "profile_score": _korean_proximity_score(native_distance, russian_distance),
        "profile_reliable": reliable,
        "profile_reliability_reason": reason,
        "native_distance": native_distance,
        "russian_distance": russian_distance,
        "profile_features": features,
        **subscores,
        "profile_distance_parts": {
            "native": native_parts,
            "russian": russian_parts,
        },
    }


# ── 러시아어 억양 감지 (기존) ─────────────────────────────────────────
def detect_russian_accent(pitch: np.ndarray) -> dict:
    voiced = pitch[pitch > 0]
    if len(voiced) < 10:
        return {
            "is_russian_pattern": False,
            "pitch_variance": 0.0,
            "feedback": "조금 더 길게 말해봐요! 다시 한번 해볼까요?",
        }

    variance = float(np.var(voiced))
    is_flat = variance < FLAT_PITCH_THRESHOLD

    if is_flat:
        feedback = (
            "목소리를 위아래로 움직여봐요! "
            "'안녕하세요'처럼 높았다가 낮아지는 게 한국어예요."
        )
    else:
        feedback = "목소리 높낮이가 정말 좋아요! 잘하고 있어요!"

    return {
        "is_russian_pattern": is_flat,
        "pitch_variance": round(variance, 2),
        "feedback": feedback,
    }


# ── 점수 계산 ─────────────────────────────────────────────────────────
def _dtw_score(user_seq: np.ndarray, ref_seq: np.ndarray, max_norm: float) -> dict:
    """공통 DTW 유사도 → 0~100 정규화."""
    if len(user_seq) == 0 or len(ref_seq) == 0:
        return {"score": 0.0, "dtw_distance": 0.0}
    distance, _ = fastdtw(
        user_seq.reshape(-1, 1),
        ref_seq.reshape(-1, 1),
        dist=euclidean,
    )
    norm = distance / max(len(user_seq), len(ref_seq))
    score = max(0.0, 100.0 - (norm / max_norm) * 100.0)
    return {"score": round(score, 1), "dtw_distance": round(norm, 4)}


def compute_score(user_pitch: np.ndarray, ref_pitch: np.ndarray) -> dict:
    """피치 DTW 점수 (하위호환 이름 유지)."""
    return _dtw_score(user_pitch, ref_pitch, DTW_PITCH_MAX)


def compute_rhythm_score(user_intervals: np.ndarray, ref_intervals: np.ndarray) -> dict:
    return _dtw_score(user_intervals, ref_intervals, DTW_RHYTHM_MAX)


def compute_stress_score(user_energy: np.ndarray, ref_energy: np.ndarray) -> dict:
    return _dtw_score(user_energy, ref_energy, DTW_STRESS_MAX)


def compute_mfcc_cosine(user_mfcc: np.ndarray, ref_mfcc: np.ndarray) -> dict:
    """MFCC 평균 벡터 간 cosine 유사도 → 0~100."""
    if len(user_mfcc) == 0 or len(ref_mfcc) == 0:
        return {"score": 0.0, "cosine_distance": 0.0}
    dist = float(cosine(user_mfcc, ref_mfcc))  # 0~2
    sim = 1.0 - dist                            # -1~1
    score = max(0.0, min(100.0, (sim + 1.0) / 2.0 * 100.0))
    return {"score": round(score, 1), "cosine_distance": round(dist, 4)}


def compute_two_sided_accent_score(user_mfcc: np.ndarray, native_mfcc: np.ndarray) -> float | None:
    """
    원어민 MFCC와 러시아 억양 프로필 MFCC 사이에서 사용자 위치를 0~100으로 환산.
    100 = 원어민에 가까움, 0 = 러시아 억양에 가까움.
    러시아 프로필이 없으면 None 반환.
    """
    russian_profile = _get_russian_profile()
    if russian_profile is None or len(user_mfcc) == 0 or len(native_mfcc) == 0:
        return None

    d_native = float(cosine(user_mfcc, native_mfcc))
    d_russian = float(cosine(user_mfcc, russian_profile))
    total = d_native + d_russian
    if total == 0:
        return 50.0
    score = (d_russian / total) * 100.0
    return round(score, 1)


# ── 단어별 점수 ───────────────────────────────────────────────────────
def compute_pitch_slope_score(user_pitch: np.ndarray, ref_pitch: np.ndarray) -> dict:
    """피치 방향성(기울기) 유사도 — Pearson 상관계수 → 0~100."""
    user_voiced = user_pitch[user_pitch > 0]
    ref_voiced = ref_pitch[ref_pitch > 0]
    if len(user_voiced) < 5 or len(ref_voiced) < 5:
        return {"score": None}
    target = 50
    u = np.interp(np.linspace(0, 1, target), np.linspace(0, 1, len(user_voiced)), user_voiced)
    r = np.interp(np.linspace(0, 1, target), np.linspace(0, 1, len(ref_voiced)), ref_voiced)
    corr = float(np.corrcoef(u, r)[0, 1])
    if np.isnan(corr):
        return {"score": None}
    score = max(0.0, min(100.0, (corr + 1.0) / 2.0 * 100.0))
    return {"score": round(score, 1)}


def compute_voiced_ratio_score(user_pitch: np.ndarray, ref_pitch: np.ndarray) -> dict:
    """유성 구간 비율 유사도 — 원어민 대비 발성 명료도.
    앞뒤 묵음을 제거한 발화 구간 안에서만 비율을 비교해 녹음 길이 영향을 없앤다.
    """
    def _ratio_in_speech(pitch: np.ndarray) -> float | None:
        voiced_idx = np.where(pitch > 0)[0]
        if len(voiced_idx) == 0:
            return None
        segment = pitch[voiced_idx[0]: voiced_idx[-1] + 1]
        return float(np.sum(segment > 0) / len(segment))

    if len(user_pitch) == 0 or len(ref_pitch) == 0:
        return {"score": None}
    user_ratio = _ratio_in_speech(user_pitch)
    ref_ratio = _ratio_in_speech(ref_pitch)
    if user_ratio is None or ref_ratio is None:
        return {"score": None}
    diff = abs(user_ratio - ref_ratio)
    score = max(0.0, min(100.0, 100.0 - diff * 150.0))
    return {"score": round(score, 1)}


def score_words(audio_bytes: bytes, words: list[dict]) -> list[dict]:
    """
    Whisper 단어 타임스탬프 기준으로 각 단어 구간의 피치 분산을 계산해
    0~100 점수 반환 (높을수록 한국어다운 억양 변화).
    """
    if not words:
        return []
    pitch = extract_pitch(audio_bytes)
    if len(pitch) == 0:
        return [{"word": w["word"], "start": w["start"], "end": w["end"], "score": None} for w in words]

    # 단어 구간별 포먼트(F1/F2) 평균을 위해 시간축 포함 트랙을 한 번만 추출.
    f_times, f1_track, f2_track = extract_formant_track(audio_bytes)

    frames_per_sec = 16000 / HOP_LENGTH  # librosa.load(sr=None) → wav가 16kHz면 31.25
    results = []
    for w in words:
        s = max(0, int(w["start"] * frames_per_sec))
        e = min(len(pitch), int(w["end"] * frames_per_sec))
        slice_ = pitch[s:e]
        voiced = slice_[slice_ > 0]
        if len(voiced) < 3:
            score = None
        else:
            variance = float(np.var(voiced))
            score = round(min(100.0, max(0.0, variance / 5.0)), 1)

        # 이 단어 시간 구간 안의 유성 프레임 포먼트만 평균 → 진짜 '단어별' F1/F2.
        f1_mean = f2_mean = None
        if len(f_times):
            mask = (f_times >= w["start"]) & (f_times <= w["end"])
            wf1 = f1_track[mask]
            wf2 = f2_track[mask]
            wf1 = wf1[wf1 > 0]
            wf2 = wf2[wf2 > 0]
            if len(wf1):
                f1_mean = round(float(np.mean(wf1)), 1)
            if len(wf2):
                f2_mean = round(float(np.mean(wf2)), 1)

        results.append({
            "word": w["word"],
            "start": round(w["start"], 3),
            "end": round(w["end"], 3),
            "score": score,
            "formant_f1": f1_mean,
            "formant_f2": f2_mean,
        })
    return results


# ── 통합 분석 ─────────────────────────────────────────────────────────
def analyze(user_audio_bytes: bytes, ref_audio_bytes: bytes) -> dict:
    """
    사용자 ↔ 원어민 오디오를 네 가지 관점에서 비교:
    피치(F0) · 리듬(onset 간격 + 말하기 속도 + 쉼표) · 강세(RMS) · 음색(MFCC cosine).
    Praat 피치는 설치돼 있으면 교차검증 값으로 함께 반환.
    """
    user_pitch = extract_pitch(user_audio_bytes)
    ref_pitch = extract_pitch(ref_audio_bytes)
    user_rhythm = extract_rhythm(user_audio_bytes)
    ref_rhythm = extract_rhythm(ref_audio_bytes)
    user_energy = extract_energy(user_audio_bytes)
    ref_energy = extract_energy(ref_audio_bytes)
    user_mfcc = extract_mfcc(user_audio_bytes)
    ref_mfcc = extract_mfcc(ref_audio_bytes)

    user_rate_info = extract_speech_rate(user_audio_bytes)
    ref_rate_info = extract_speech_rate(ref_audio_bytes)
    user_pause_info = extract_pause_pattern(user_audio_bytes)
    ref_pause_info = extract_pause_pattern(ref_audio_bytes)

    pitch_result = compute_score(user_pitch, ref_pitch)
    rhythm_result = compute_rhythm_score(user_rhythm, ref_rhythm)
    stress_result = compute_stress_score(user_energy, ref_energy)
    mfcc_result = compute_mfcc_cosine(user_mfcc, ref_mfcc)

    pitch_score_praat = None
    formant_score_val = None
    if PRAAT_AVAILABLE:
        up = extract_pitch_praat(user_audio_bytes)
        rp = extract_pitch_praat(ref_audio_bytes)
        pitch_score_praat = compute_score(up, rp)["score"]
        user_f1, user_f2 = extract_formants(user_audio_bytes)
        ref_f1, ref_f2 = extract_formants(ref_audio_bytes)
        if len(user_f1) > 0 and len(ref_f1) > 0:
            f1_score = _dtw_score(
                _normalize_voiced(user_f1), _normalize_voiced(ref_f1), DTW_FORMANT_NORM_MAX
            )["score"]
            f2_score = _dtw_score(
                _normalize_voiced(user_f2), _normalize_voiced(ref_f2), DTW_FORMANT_NORM_MAX
            )["score"]
            formant_score_val = round((f1_score + f2_score) / 2, 1)

    # 음절 수 비교 (speech_rate에서 이미 계산된 syllable_count 재사용)
    user_syllable = user_rate_info["syllable_count"]
    ref_syllable = ref_rate_info["syllable_count"]
    syllable_score_val = round(
        min(user_syllable, ref_syllable) / max(user_syllable, ref_syllable) * 100.0, 1
    ) if ref_syllable > 0 else None

    voiced_result = compute_voiced_ratio_score(user_pitch, ref_pitch)
    slope_result = compute_pitch_slope_score(user_pitch, ref_pitch)

    composite = round(
        (pitch_result["score"] + rhythm_result["score"]
         + stress_result["score"] + mfcc_result["score"]) / 4.0,
        1,
    )

    accent_score = compute_two_sided_accent_score(user_mfcc, ref_mfcc)

    rhythm_feedback = generate_rhythm_feedback(
        user_rate=user_rate_info["rate"],
        ref_rate=ref_rate_info["rate"],
        user_pauses=user_pause_info,
        ref_pauses=ref_pause_info,
        rhythm_score=rhythm_result["score"],
    )

    return {
        "pitch_contour": user_pitch.tolist(),
        "ref_pitch_contour": ref_pitch.tolist(),
        "score": pitch_result["score"],
        "dtw_distance": pitch_result["dtw_distance"],
        "pitch_score_praat": pitch_score_praat,
        "rhythm_score": rhythm_result["score"],
        "stress_score": stress_result["score"],
        "mfcc_cosine_score": mfcc_result["score"],
        "composite_score": composite,
        "accent_score": accent_score,
        "speech_rate_user": user_rate_info["rate"],
        "speech_rate_ref": ref_rate_info["rate"],
        "pause_count_user": user_pause_info["pause_count"],
        "pause_count_ref": ref_pause_info["pause_count"],
        "rhythm_feedback": rhythm_feedback,
        "formant_score": formant_score_val,
        "syllable_score": syllable_score_val,
        "syllable_count_user": user_syllable,
        "syllable_count_ref": ref_syllable,
        "voiced_ratio_score": voiced_result["score"],
        "pitch_slope_score": slope_result["score"],
    }


def analyze_with_feedback(user_audio_bytes: bytes, ref_audio_bytes: bytes = None) -> dict:
    """
    피치 분석 + 러시아어 억양 감지 + 피드백 텍스트.
    ref_audio_bytes가 있으면 전체 유사도(analyze)도 함께 계산.
    """
    user_pitch = extract_pitch(user_audio_bytes)
    accent_info = detect_russian_accent(user_pitch)

    result = {
        "pitch_contour": user_pitch.tolist(),
        "pitch_variance": accent_info["pitch_variance"],
        "is_russian_pattern": accent_info["is_russian_pattern"],
        "feedback": accent_info["feedback"],
        "score": None,
        "dtw_distance": None,
        "ref_pitch_contour": [],
        "pitch_score_praat": None,
        "rhythm_score": None,
        "stress_score": None,
        "mfcc_cosine_score": None,
        "composite_score": None,
        "accent_score": None,
        "speech_rate_user": None,
        "speech_rate_ref": None,
        "pause_count_user": None,
        "pause_count_ref": None,
        "rhythm_feedback": None,
        "formant_score": None,
        "syllable_score": None,
        "syllable_count_user": None,
        "syllable_count_ref": None,
        "voiced_ratio_score": None,
        "pitch_slope_score": None,
    }

    if ref_audio_bytes:
        full = analyze(user_audio_bytes, ref_audio_bytes)
        for key in (
            "score", "dtw_distance", "ref_pitch_contour",
            "pitch_score_praat", "rhythm_score", "stress_score",
            "mfcc_cosine_score", "composite_score", "accent_score",
            "speech_rate_user", "speech_rate_ref",
            "pause_count_user", "pause_count_ref", "rhythm_feedback",
            "formant_score", "syllable_score", "syllable_count_user",
            "syllable_count_ref", "voiced_ratio_score", "pitch_slope_score",
        ):
            result[key] = full[key]

    return result
