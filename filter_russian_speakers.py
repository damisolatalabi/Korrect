"""
러시아어 모국어 화자 데이터 필터링 스크립트
motherTongue == "러시아어" 인 JSON + WAV 파일을 output 폴더로 복사
"""
import json
import shutil
from pathlib import Path

LABEL_DIR = Path(r"E:\131.인공지능 학습을 위한 외국인 한국어 발화 음성 데이터\01.데이터_new_20220719\2.Validation\라벨링데이터\6. 기타")
WAV_DIR   = Path(r"E:\131.인공지능 학습을 위한 외국인 한국어 발화 음성 데이터\01.데이터_new_20220719\2.Validation\원천데이터\VS_6. 기타")
OUTPUT_DIR = Path(r"E:\russian_speakers")

def main():
    copied = 0
    missing_wav = 0

    for json_path in LABEL_DIR.rglob("*.json"):
        try:
            data = json.loads(json_path.read_text(encoding="utf-8"))
        except Exception:
            continue

        mother_tongue = data.get("skill_info", {}).get("motherTongue", "")
        if mother_tongue != "러시아어":
            continue

        # 하위 폴더 구조 유지 (예: 1. 한국일반/)
        subfolder = json_path.parent.name
        out_sub = OUTPUT_DIR / subfolder
        out_sub.mkdir(parents=True, exist_ok=True)

        # JSON 복사
        shutil.copy2(json_path, out_sub / json_path.name)

        # WAV 복사
        wav_path = WAV_DIR / subfolder / (json_path.stem + ".wav")
        if wav_path.exists():
            shutil.copy2(wav_path, out_sub / wav_path.name)
            copied += 1
        else:
            print(f"[WAV 없음] {wav_path}")
            missing_wav += 1

    print(f"\n완료: {copied}개 복사, WAV 누락 {missing_wav}개")
    print(f"출력 경로: {OUTPUT_DIR}")

if __name__ == "__main__":
    main()

