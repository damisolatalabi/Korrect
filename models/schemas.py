from pydantic import BaseModel
from typing import Optional


class WordScore(BaseModel):
    word: str
    start: float
    end: float
    score: Optional[float] = None


class STTResponse(BaseModel):
    text: str
    language: str
    words: list[WordScore] = []


class ProsodyResponse(BaseModel):
    pitch_contour: list[float]
    ref_pitch_contour: list[float]
    score: float
    dtw_distance: float
    pitch_score_praat: Optional[float] = None
    rhythm_score: Optional[float] = None
    stress_score: Optional[float] = None
    mfcc_cosine_score: Optional[float] = None
    composite_score: Optional[float] = None
    accent_score: Optional[float] = None
    speech_rate_user: Optional[float] = None
    speech_rate_ref: Optional[float] = None
    pause_count_user: Optional[int] = None
    pause_count_ref: Optional[int] = None
    rhythm_feedback: Optional[str] = None
    formant_score: Optional[float] = None
    syllable_score: Optional[float] = None
    syllable_count_user: Optional[int] = None
    syllable_count_ref: Optional[int] = None
    voiced_ratio_score: Optional[float] = None
    pitch_slope_score: Optional[float] = None
    profile_score: Optional[float] = None
    native_distance: Optional[float] = None
    russian_distance: Optional[float] = None
    profile_features: Optional[dict] = None
    profile_intonation_score: Optional[float] = None
    profile_rhythm_score: Optional[float] = None
    profile_voice_score: Optional[float] = None
    profile_mfcc_score: Optional[float] = None
    profile_stress_score: Optional[float] = None
    profile_vowel_score: Optional[float] = None
    profile_syllable_score: Optional[float] = None
    profile_slope_score: Optional[float] = None


class ChatRequest(BaseModel):
    scenario: str
    user_text: str
    history: list[dict] = []


class ChatResponse(BaseModel):
    reply: str
    hint: Optional[str] = None
    hint_ru: Optional[str] = None


class ProcessResponse(BaseModel):
    stt: STTResponse
    prosody: Optional[ProsodyResponse] = None
    chat: ChatResponse
    total_score: Optional[float] = None
    prosody_feedback: Optional[str] = None
