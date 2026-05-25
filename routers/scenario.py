import json
from pathlib import Path
from fastapi import APIRouter, HTTPException, UploadFile, File, Form
from fastapi.responses import FileResponse
from models.schemas import ProcessResponse, STTResponse, ChatResponse, ProsodyResponse
from services import whisper_service, prosody_service, gemini_service, scoring_service

router = APIRouter(prefix="/scenario", tags=["Scenario"])

DATA_DIR = Path(__file__).parent.parent / "data" / "scenarios"
REF_DIR = Path(__file__).parent.parent / "data" / "references"


@router.get("")
async def list_scenarios():
    """사용 가능한 시나리오 목록 반환."""
    scenarios = []
    for f in DATA_DIR.glob("*.json"):
        with open(f, encoding="utf-8") as fp:
            data = json.load(fp)
        scenarios.append({
            "id": f.stem,
            "title": data.get("title", f.stem),
            "description": data.get("description", ""),
        })
    return {"scenarios": scenarios}


@router.get("/{scenario_id}")
async def get_scenario(scenario_id: str):
    """특정 시나리오의 상세 정보(스크립트) 반환."""
    path = DATA_DIR / f"{scenario_id}.json"
    if not path.exists():
        raise HTTPException(status_code=404, detail=f"시나리오를 찾을 수 없습니다: {scenario_id}")
    with open(path, encoding="utf-8") as f:
        return json.load(f)


@router.get("/{scenario_id}/reference/{turn_index}")
async def get_reference_audio(scenario_id: str, turn_index: int):
    """레퍼런스(원어민) 오디오 파일 반환."""
    ref_path = REF_DIR / scenario_id / f"{turn_index}.wav"
    if not ref_path.exists():
        raise HTTPException(status_code=404, detail="레퍼런스 파일이 없습니다.")
    return FileResponse(ref_path, media_type="audio/wav")


@router.get("/{scenario_id}/opening")
async def get_opening(scenario_id: str):
    """시나리오 시작 시 AI 첫 인사말 반환."""
    return gemini_service.get_opening_message(scenario_id)


@router.post("/{scenario_id}/process", response_model=ProcessResponse)
async def process_turn(
    scenario_id: str,
    audio: UploadFile = File(...),
    history: str = Form(default="[]"),
    turn_index: int = Form(default=0),
):
    """
    메인 파이프라인: 오디오 → STT → 운율분석 → AI 대화 → 점수 반환.
    Flutter 앱에서 한 번의 요청으로 전체 결과를 받아갈 수 있음.

    - audio: 아동이 녹음한 오디오 파일 (wav)
    - history: 이전 대화 기록 JSON 문자열 (선택)
    - turn_index: 현재 대화 턴 번호, 레퍼런스 오디오 매칭에 사용
    """
    audio_bytes = await audio.read()
    if len(audio_bytes) == 0:
        raise HTTPException(status_code=400, detail="빈 오디오 파일입니다.")

    # 1. STT (단어 타임스탬프 포함)
    stt_result = whisper_service.transcribe(audio_bytes, audio.filename or "audio.wav")
    word_timestamps = stt_result.get("words", [])
    word_scores = []
    if word_timestamps:
        try:
            word_scores = prosody_service.score_words(audio_bytes, word_timestamps)
        except Exception as e:
            print(f"[scenario] 단어별 점수 계산 실패: {e}")
    stt = STTResponse(
        text=stt_result["text"],
        language=stt_result["language"],
        words=word_scores,
    )

    # 2. 운율 분석 + 피드백 텍스트
    prosody = None
    total_score = None
    feedback_text = None
    ref_path = REF_DIR / scenario_id / f"{turn_index}.wav"

    ref_bytes = ref_path.read_bytes() if ref_path.exists() else None
    prosody_result = prosody_service.analyze_with_feedback(audio_bytes, ref_bytes)
    try:
        prosody_result.update(prosody_service.analyze_profile_score(audio_bytes))
    except Exception as e:
        print(f"[scenario] profile score calculation failed: {e}")
    feedback_text = prosody_result.get("feedback")

    if prosody_result.get("pitch_contour"):
        score_val = prosody_result.get("score") if prosody_result.get("score") is not None else 0.0
        dtw_val = prosody_result.get("dtw_distance") if prosody_result.get("dtw_distance") is not None else 0.0
        prosody = ProsodyResponse(
            pitch_contour=prosody_result["pitch_contour"],
            ref_pitch_contour=prosody_result.get("ref_pitch_contour") or [],
            score=score_val,
            dtw_distance=dtw_val,
            pitch_score_praat=prosody_result.get("pitch_score_praat"),
            rhythm_score=prosody_result.get("rhythm_score"),
            stress_score=prosody_result.get("stress_score"),
            mfcc_cosine_score=prosody_result.get("mfcc_cosine_score"),
            composite_score=prosody_result.get("composite_score"),
            accent_score=prosody_result.get("accent_score"),
            speech_rate_user=prosody_result.get("speech_rate_user"),
            speech_rate_ref=prosody_result.get("speech_rate_ref"),
            pause_count_user=prosody_result.get("pause_count_user"),
            pause_count_ref=prosody_result.get("pause_count_ref"),
            rhythm_feedback=prosody_result.get("rhythm_feedback"),
            formant_score=prosody_result.get("formant_score"),
            syllable_score=prosody_result.get("syllable_score"),
            syllable_count_user=prosody_result.get("syllable_count_user"),
            syllable_count_ref=prosody_result.get("syllable_count_ref"),
            voiced_ratio_score=prosody_result.get("voiced_ratio_score"),
            pitch_slope_score=prosody_result.get("pitch_slope_score"),
            profile_score=prosody_result.get("profile_score"),
            native_distance=prosody_result.get("native_distance"),
            russian_distance=prosody_result.get("russian_distance"),
            profile_features=prosody_result.get("profile_features"),
            profile_intonation_score=prosody_result.get("profile_intonation_score"),
            profile_rhythm_score=prosody_result.get("profile_rhythm_score"),
            profile_voice_score=prosody_result.get("profile_voice_score"),
            profile_mfcc_score=prosody_result.get("profile_mfcc_score"),
            profile_stress_score=prosody_result.get("profile_stress_score"),
            profile_vowel_score=prosody_result.get("profile_vowel_score"),
            profile_syllable_score=prosody_result.get("profile_syllable_score"),
            profile_slope_score=prosody_result.get("profile_slope_score"),
        )
        if prosody_result.get("profile_score") is not None:
            total_score = prosody_result.get("profile_score")
        elif prosody_result.get("composite_score") is not None:
            total_score = scoring_service.compute_total_score(prosody.composite_score, None)
        elif prosody_result.get("score") is not None:
            total_score = scoring_service.compute_total_score(prosody.score, None)

    # 3. AI 대화
    if not stt.text.strip():
        chat = ChatResponse(
            reply="잘 못 들었어요. 다시 한 번 말해줄래요?",
            hint=None,
        )
    else:
        try:
            history_data = json.loads(history)
        except json.JSONDecodeError:
            raise HTTPException(status_code=400, detail="history 필드가 유효한 JSON이 아닙니다.")
        chat_result = gemini_service.chat(
            scenario=scenario_id,
            user_text=stt.text,
            history=history_data,
            prosody_feedback=feedback_text,
        )
        chat = ChatResponse(**chat_result)

    return ProcessResponse(
        stt=stt,
        prosody=prosody,
        chat=chat,
        total_score=total_score,
        prosody_feedback=feedback_text,
    )
