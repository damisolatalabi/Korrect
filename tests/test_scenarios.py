"""
이태경 담당 - 시나리오 데이터 및 API 엔드포인트 테스트
pytest로 실행: pytest tests/test_scenarios.py -v
"""
import sys
import json
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent))

import pytest
from fastapi.testclient import TestClient
from main import app

client = TestClient(app)

SCENARIOS = ["hospital", "bank", "immigration", "school", "restaurant", "mart"]
DATA_DIR = Path(__file__).parent.parent / "data" / "scenarios"


class TestScenarioData:
    """시나리오 JSON 파일 데이터 유효성 테스트."""

    @pytest.mark.parametrize("scenario_id", SCENARIOS)
    def test_scenario_file_exists(self, scenario_id):
        """시나리오 JSON 파일이 존재하는지 확인."""
        path = DATA_DIR / f"{scenario_id}.json"
        assert path.exists(), f"{scenario_id}.json 파일 없음"

    @pytest.mark.parametrize("scenario_id", SCENARIOS)
    def test_scenario_has_required_fields(self, scenario_id):
        """시나리오에 필수 필드가 있는지 확인."""
        with open(DATA_DIR / f"{scenario_id}.json", encoding="utf-8") as f:
            data = json.load(f)
        assert "id" in data
        assert "title" in data
        assert "turns" in data
        assert isinstance(data["turns"], list)
        assert len(data["turns"]) > 0

    @pytest.mark.parametrize("scenario_id", SCENARIOS)
    def test_each_turn_has_required_fields(self, scenario_id):
        """각 턴에 필수 필드가 있는지 확인."""
        with open(DATA_DIR / f"{scenario_id}.json", encoding="utf-8") as f:
            data = json.load(f)
        for turn in data["turns"]:
            assert "index" in turn, f"턴에 index 없음: {turn}"
            assert "speaker" in turn, f"턴에 speaker 없음: {turn}"
            assert "text" in turn, f"턴에 text 없음: {turn}"


class TestScenarioAPI:
    """시나리오 API 엔드포인트 테스트."""

    def test_list_scenarios(self):
        """시나리오 목록 API 정상 동작 확인."""
        response = client.get("/api/scenario")
        assert response.status_code == 200
        data = response.json()
        assert "scenarios" in data
        assert len(data["scenarios"]) == len(SCENARIOS)

    @pytest.mark.parametrize("scenario_id", SCENARIOS)
    def test_get_scenario_detail(self, scenario_id):
        """시나리오 상세 API 정상 동작 확인."""
        response = client.get(f"/api/scenario/{scenario_id}")
        assert response.status_code == 200
        data = response.json()
        assert data["id"] == scenario_id

    def test_get_nonexistent_scenario(self):
        """존재하지 않는 시나리오는 404 반환."""
        response = client.get("/api/scenario/nonexistent")
        assert response.status_code == 404

    @pytest.mark.parametrize("scenario_id", SCENARIOS)
    def test_get_opening_message(self, scenario_id):
        """시나리오 시작 메시지 API 정상 동작 확인."""
        response = client.get(f"/api/scenario/{scenario_id}/opening")
        assert response.status_code == 200
        data = response.json()
        assert "reply" in data
        assert isinstance(data["reply"], str)
        assert len(data["reply"]) > 0

    def test_health_check(self):
        """헬스 체크 엔드포인트 확인."""
        response = client.get("/health")
        assert response.status_code == 200
        assert response.json()["status"] == "healthy"
