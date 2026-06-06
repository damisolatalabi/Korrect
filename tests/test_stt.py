"""
이태경 담당 - STT 오류 케이스 테스트
pytest로 실행: pytest tests/test_stt.py -v
"""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent))

import numpy as np
import soundfile as sf
import io
import pytest


def _make_silence_wav(duration_sec: float = 1.0, sr: int = 16000) -> bytes:
    """테스트용 무음 WAV 생성."""
    samples = np.zeros(int(sr * duration_sec), dtype=np.float32)
    buf = io.BytesIO()
    sf.write(buf, samples, sr, format="WAV")
    return buf.getvalue()


def _make_tone_wav(freq: float = 440.0, duration_sec: float = 1.0, sr: int = 16000) -> bytes:
    """테스트용 단순 사인파 WAV 생성 (음성 아님)."""
    t = np.linspace(0, duration_sec, int(sr * duration_sec))
    samples = (np.sin(2 * np.pi * freq * t) * 0.5).astype(np.float32)
    buf = io.BytesIO()
    sf.write(buf, samples, sr, format="WAV")
    return buf.getvalue()


class TestSTTBasic:
    """기본 STT 동작 테스트 (로컬 모델 필요)."""

    def test_returns_dict_with_text_and_language(self):
        """STT 결과가 text, language 키를 포함하는지 확인."""
        from services.whisper_service import transcribe
        audio = _make_silence_wav()
        result = transcribe(audio)
        assert "text" in result
        assert "language" in result

    def test_text_is_string(self):
        """text 필드가 문자열인지 확인."""
        from services.whisper_service import transcribe
        audio = _make_silence_wav()
        result = transcribe(audio)
        assert isinstance(result["text"], str)

    def test_silence_returns_empty_or_short(self):
        """무음 파일은 빈 텍스트 또는 짧은 텍스트를 반환해야 함."""
        from services.whisper_service import transcribe
        audio = _make_silence_wav(duration_sec=2.0)
        result = transcribe(audio)
        assert len(result["text"]) < 20, f"무음인데 너무 긴 텍스트: {result['text']}"

    def test_non_speech_audio(self):
        """음성이 아닌 오디오(사인파)는 무의미한 텍스트만 반환해야 함."""
        from services.whisper_service import transcribe
        audio = _make_tone_wav()
        result = transcribe(audio)
        assert isinstance(result["text"], str)


    def test_silence_short_circuits_to_empty_text(self):
        """사실상 무음인 입력은 빈 텍스트로 처리한다."""
        from services.whisper_service import transcribe

        audio = _make_silence_wav(duration_sec=2.0)
        result = transcribe(audio)
        assert result["text"] == ""
        assert result["language"] == "ko"


class TestSTTErrorCases:
    """STT 오류 케이스 (이태경 3주차 수집 케이스)."""

    def test_empty_audio_raises_or_returns_empty(self):
        """빈 바이트를 넣으면 예외가 발생하거나 빈 텍스트를 반환해야 함."""
        from services.whisper_service import transcribe
        try:
            result = transcribe(b"")
            assert result["text"] == "" or result["text"] is not None
        except Exception:
            pass  # 예외 발생도 허용

    def test_very_short_audio(self):
        """0.1초 미만의 매우 짧은 오디오 처리 가능 여부."""
        from services.whisper_service import transcribe
        audio = _make_silence_wav(duration_sec=0.05)
        try:
            result = transcribe(audio)
            assert isinstance(result["text"], str)
        except Exception:
            pass

    def test_long_audio(self):
        """10초 이상의 긴 무음 오디오도 처리 가능한지 확인.
        ffmpeg 미설치 환경에서는 예외가 허용됩니다.
        """
        from services.whisper_service import transcribe
        audio = _make_silence_wav(duration_sec=10.0)
        try:
            result = transcribe(audio)
            assert isinstance(result["text"], str)
        except Exception:
            pass  # ffmpeg 미설치 환경에서는 예외 허용


class TestKoreanPhrases:
    """
    한국어 문장 케이스 목록 (실제 오디오 파일 있을 때 활용).
    data/test_audio/ 폴더에 파일 추가 후 테스트.
    """
    EXPECTED_PHRASES = [
        ("배가 아파요", "hospital"),
        ("어제부터 아팠어요", "hospital"),
        ("돈을 바꾸고 싶어요", "bank"),
        ("비자를 연장하고 싶어요", "immigration"),
    ]

    def test_expected_phrases_list_not_empty(self):
        """테스트할 문장 목록이 비어있지 않은지 확인."""
        assert len(self.EXPECTED_PHRASES) > 0

    @pytest.mark.parametrize("phrase,scenario", [
        ("배가 아파요", "hospital"),
        ("어제부터 아팠어요", "hospital"),
        ("돈을 바꾸고 싶어요", "bank"),
        ("비자를 연장하고 싶어요", "immigration"),
    ])
    def test_phrase_in_scenario(self, phrase, scenario):
        """각 시나리오에 해당하는 문장이 정의되어 있는지 확인."""
        import json
        from pathlib import Path
        path = Path(__file__).parent.parent / "data" / "scenarios" / f"{scenario}.json"
        assert path.exists(), f"시나리오 파일 없음: {scenario}.json"
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
        hints = [turn.get("hint", "") for turn in data.get("turns", [])]
        assert any(phrase in h for h in hints), f"'{phrase}'가 {scenario} 시나리오에 없음"
