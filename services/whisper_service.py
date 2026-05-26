"""
STT service.
Supports local Whisper, OpenAI/Groq Whisper APIs, and Google STT.
"""
import io
import math
import os
import re
import tempfile
from pathlib import Path

from config import settings

# 한글 음절/자모 + 공백·숫자·기본 문장부호만 남기고 라틴·키릴 등은 제거.
_NON_KOREAN = re.compile(r'[^가-힣ㄱ-ㅎㅏ-ㅣ0-9\s.,?!~]')
_HANGUL = re.compile(r'[가-힣]')


def _korean_only(text: str) -> str:
    """STT 결과를 한국어로 강제: 비한글 문자를 지우고, 한글이 하나도 없으면 빈 값.

    Whisper는 language='ko'로도 드물게 로마자/키릴을 흘릴 수 있고, 그게 음소 진단·
    화면에 들어가면 깨진다. 한글이 없으면 '못 알아들음'으로 처리하는 게 안전하다.
    """
    if not text:
        return ""
    cleaned = _NON_KOREAN.sub('', text)
    cleaned = re.sub(r'\s+', ' ', cleaned).strip()
    if not _HANGUL.search(cleaned):
        return ""
    return cleaned

_local_model = None
_TOO_QUIET_RMS_THRESHOLD = 8
_TOO_QUIET_DBFS_THRESHOLD = -55.0


def _get_local_model():
    global _local_model
    if _local_model is None:
        import whisper

        print(f"[Whisper] 로컬 모델 로딩 중: {settings.whisper_model_size}")
        _local_model = whisper.load_model(settings.whisper_model_size)
        print("[Whisper] 모델 로딩 완료")
    return _local_model


def transcribe(audio_bytes: bytes, filename: str = "audio.wav") -> dict:
    """
    Return {"text": str, "language": str, "words": list[{"word", "start", "end"}]}.
    """
    mode = settings.whisper_mode
    if mode == "api":
        result = _transcribe_openai_api(audio_bytes, filename)
    elif mode == "google":
        result = _transcribe_google(audio_bytes)
    elif mode == "groq":
        result = _transcribe_groq(audio_bytes, filename)
    else:
        result = _transcribe_local(audio_bytes, filename)

    # 모든 모드 공통: 출력을 한국어로 강제(비한글 제거).
    raw = result.get("text", "")
    result["text"] = _korean_only(raw)
    if raw != result["text"]:
        print(f"[Whisper] 한글 정제: '{raw}' → '{result['text']}'")

    # 단어 목록도 한글 단어만 유지 (채팅 말풍선이 words를 색깔 단어로 렌더링하므로,
    # 여기서 안 거르면 text를 비워도 영어 단어가 화면에 그대로 뜬다).
    words = result.get("words") or []
    result["words"] = [w for w in words if _HANGUL.search(w.get("word", ""))]

    return result


def _real_suffix(audio_bytes: bytes, filename: str) -> str:
    """magic bytes 우선, 그다음 확장자 폴백."""
    if audio_bytes[:4] == b'\x1a\x45\xdf\xa3':
        return '.webm'
    if len(audio_bytes) > 8 and audio_bytes[4:8] == b'ftyp':
        return '.mp4'
    if audio_bytes[:4] == b'RIFF':
        return '.wav'
    return Path(filename).suffix or '.wav'


def _decode_audio(audio_bytes: bytes, filename: str = "audio.wav"):
    from pydub import AudioSegment

    suffix = _real_suffix(audio_bytes, filename)
    tmp = tempfile.NamedTemporaryFile(suffix=suffix, delete=False)
    try:
        tmp.write(audio_bytes)
        tmp.close()
        return AudioSegment.from_file(tmp.name)
    finally:
        try:
            os.unlink(tmp.name)
        except Exception:
            pass


def _audio_level_stats(audio) -> dict:
    return {
        "dBFS": audio.dBFS,
        "max_dBFS": audio.max_dBFS,
        "rms": int(audio.rms),
        "max": int(audio.max),
    }


def _is_effectively_silent(stats: dict) -> bool:
    if stats["rms"] <= _TOO_QUIET_RMS_THRESHOLD:
        return True
    dBFS = stats["dBFS"]
    if dBFS == float("-inf"):
        return True
    return math.isfinite(dBFS) and dBFS < _TOO_QUIET_DBFS_THRESHOLD


def _write_normalized_audio(audio_bytes: bytes, filename: str) -> str:
    """
    Convert uploaded audio into a real 16kHz mono WAV for local Whisper.
    """
    try:
        audio = _decode_audio(audio_bytes, filename)
        original_dBFS = audio.dBFS
        if original_dBFS != float("-inf") and original_dBFS < -20:
            audio = audio.normalize()
            print(f"[Whisper] 음량 정규화 적용 ({original_dBFS:.1f} dBFS → 0 dBFS)")
        audio = audio.set_frame_rate(16000).set_channels(1)
        tmp = tempfile.NamedTemporaryFile(suffix=".wav", delete=False)
        audio.export(tmp.name, format="wav")
        tmp.close()
        return tmp.name
    except Exception as e:
        print(f"[Whisper] 오디오 변환 실패, 원본으로 재시도: {e}")
        fallback_suffix = Path(filename or "audio.wav").suffix or ".wav"
        tmp = tempfile.NamedTemporaryFile(suffix=fallback_suffix, delete=False)
        tmp.write(audio_bytes)
        tmp.close()
        return tmp.name


def _transcribe_local(audio_bytes: bytes, filename: str) -> dict:
    debug_suffix = Path(filename or "audio.wav").suffix or ".wav"
    debug_path = os.path.join(tempfile.gettempdir(), f"korrect_last_recording{debug_suffix}")
    with open(debug_path, "wb") as f:
        f.write(audio_bytes)
    print(f"[Whisper] 입력 파일 크기: {len(audio_bytes)}B")
    print(f"[Whisper] 디버깅용 복사본: {debug_path}")

    try:
        level_stats = _audio_level_stats(_decode_audio(audio_bytes, filename))
        print(
            "[Whisper] 원본 레벨 "
            f"(dBFS={level_stats['dBFS']:.1f}, max_dBFS={level_stats['max_dBFS']:.1f}, "
            f"rms={level_stats['rms']}, max={level_stats['max']})"
        )
        if _is_effectively_silent(level_stats):
            print("[Whisper] 입력이 사실상 무음 수준이라 STT를 건너뜁니다")
            return {"text": "", "language": "ko", "words": []}
    except Exception as e:
        print(f"[Whisper] 입력 레벨 분석 실패, 계속 진행합니다: {e}")

    model = _get_local_model()
    tmp_path = _write_normalized_audio(audio_bytes, filename)
    try:
        use_word_ts = os.environ.get("WHISPER_WORD_TIMESTAMPS", "1") == "1"
        # condition_on_previous_text=False: 짧은 발화에서의 환각(앞 문맥 반복) 완화.
        try:
            result = model.transcribe(
                tmp_path,
                language="ko",
                word_timestamps=use_word_ts,
                condition_on_previous_text=False,
            )
        except Exception as e:
            print(f"[Whisper] word_timestamps 실패, 재시도: {e}")
            result = model.transcribe(
                tmp_path, language="ko", condition_on_previous_text=False
            )

        text = result["text"].strip()
        print(f"[Whisper] 인식 결과: '{text}' (language={result.get('language')})")
        words: list[dict] = []
        for seg in result.get("segments", []):
            for w in seg.get("words", []) or []:
                words.append(
                    {
                        "word": w.get("word", "").strip(),
                        "start": float(w.get("start", 0.0)),
                        "end": float(w.get("end", 0.0)),
                    }
                )
        return {
            "text": text,
            "language": result.get("language", "ko"),
            "words": words,
        }
    finally:
        os.unlink(tmp_path)


def _transcribe_openai_api(audio_bytes: bytes, filename: str) -> dict:
    from openai import OpenAI

    client = OpenAI(api_key=settings.openai_api_key)
    audio_file = io.BytesIO(audio_bytes)
    audio_file.name = filename

    transcript = client.audio.transcriptions.create(
        model="whisper-1",
        file=audio_file,
        language="ko",
        response_format="verbose_json",
        timestamp_granularities=["word"],
    )
    return {
        "text": transcript.text.strip(),
        "language": "ko",
        "words": _extract_words(transcript),
    }


def _transcribe_groq(audio_bytes: bytes, filename: str) -> dict:
    from openai import OpenAI

    client = OpenAI(
        api_key=settings.groq_api_key,
        base_url="https://api.groq.com/openai/v1",
    )
    audio_file = io.BytesIO(audio_bytes)
    audio_file.name = filename

    transcript = client.audio.transcriptions.create(
        model="whisper-large-v3-turbo",
        file=audio_file,
        language="ko",
        response_format="verbose_json",
        timestamp_granularities=["word"],
    )
    return {
        "text": transcript.text.strip(),
        "language": "ko",
        "words": _extract_words(transcript),
    }


def _extract_words(transcript) -> list[dict]:
    words_raw = getattr(transcript, "words", None) or []
    return [
        {
            "word": (getattr(w, "word", "") or "").strip(),
            "start": float(getattr(w, "start", 0.0)),
            "end": float(getattr(w, "end", 0.0)),
        }
        for w in words_raw
    ]


def _transcribe_google(audio_bytes: bytes) -> dict:
    from google.cloud import speech

    if settings.google_credentials_path:
        os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = settings.google_credentials_path

    client = speech.SpeechClient()
    audio = speech.RecognitionAudio(content=audio_bytes)
    config = speech.RecognitionConfig(
        encoding=speech.RecognitionConfig.AudioEncoding.LINEAR16,
        sample_rate_hertz=16000,
        language_code="ko-KR",
        enable_automatic_punctuation=True,
    )
    response = client.recognize(config=config, audio=audio)
    text = " ".join(
        result.alternatives[0].transcript
        for result in response.results
        if result.alternatives
    )
    return {
        "text": text.strip(),
        "language": "ko",
        "words": [],
    }


def compare_stt_modes(audio_bytes: bytes) -> dict:
    results = {}

    try:
        results["local"] = _transcribe_local(audio_bytes, "compare.wav")
    except Exception as e:
        results["local"] = {"error": str(e)}

    if settings.openai_api_key:
        try:
            results["api"] = _transcribe_openai_api(audio_bytes, "compare.wav")
        except Exception as e:
            results["api"] = {"error": str(e)}

    return results
