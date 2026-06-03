"""Evaluation endpoints and AP metrics schema."""

from __future__ import annotations

from fastapi.testclient import TestClient

_AP_KEYS = {
    "evaluator_name",
    "generated_at",
    "ap",
    "ap50",
    "ap75",
    "ap_small",
    "ap_medium",
    "ap_large",
    "ar1",
    "ar10",
    "ar100",
    "ar_small",
    "ar_medium",
    "ar_large",
    "per_class",
    "warnings",
}


def _run_eval(client: TestClient, sid: str) -> dict:
    resp = client.post(
        f"/api/sessions/{sid}/eval/run_1",
        json={"iou_threshold": 0.5, "confidence_threshold": 0.25},
    )
    assert resp.status_code == 200, resp.text
    return resp.json()


def test_eval_compact_shape(client: TestClient, open_custom_session) -> None:
    sid = open_custom_session["session_id"]
    compact = _run_eval(client, sid)
    assert set(compact.keys()) >= {
        "config",
        "overall",
        "per_class",
        "image_summaries",
        "confusion",
        "small_object",
    }
    overall = compact["overall"]
    # img1: pred1 TP (cat), pred2 wrong-class-as-FP under class-aware? It's
    # category 1 predicted over a category-2 GT box -> low_iou/no GT in cat1 -> FP.
    assert overall["total_tp"] == 1
    assert overall["total_images"] == 2
    assert overall["total_gt"] == 3
    # per-class sorted by id
    assert [c["category_id"] for c in compact["per_class"]] == [1, 2]


def test_eval_summary_classes_images(client: TestClient, open_custom_session) -> None:
    sid = open_custom_session["session_id"]
    _run_eval(client, sid)

    summary = client.get(f"/api/sessions/{sid}/eval/run_1/summary").json()
    assert "overall" in summary and "config" in summary

    classes = client.get(f"/api/sessions/{sid}/eval/run_1/classes").json()
    assert "per_class" in classes and "confusion" in classes

    images = client.get(
        f"/api/sessions/{sid}/eval/run_1/images", params={"offset": 0, "limit": 10}
    ).json()
    assert images["total"] == 2
    assert all("file_name" in img for img in images["images"])

    errors = client.get(
        f"/api/sessions/{sid}/eval/run_1/images", params={"filter": "fn"}
    ).json()
    assert errors["total"] >= 1


def test_image_detail(client: TestClient, open_custom_session) -> None:
    sid = open_custom_session["session_id"]
    _run_eval(client, sid)
    detail = client.get(f"/api/sessions/{sid}/eval/run_1/images/1").json()
    assert detail["image"]["file_name"] == "img1.png"
    assert detail["summary"]["gt_count"] == 2
    assert detail["summary"]["pred_count"] == 2
    assert isinstance(detail["matches"], list)
    assert isinstance(detail["ground_truth"], list)


def test_eval_full_payload(client: TestClient, open_custom_session) -> None:
    sid = open_custom_session["session_id"]
    _run_eval(client, sid)
    body = client.get(f"/api/sessions/{sid}/eval/run_1/full").json()
    assert set(body.keys()) == {"eval", "dataset", "predictions", "matches"}
    assert len(body["dataset"]["images"]) == 2
    assert len(body["dataset"]["categories"]) == 2
    assert len(body["dataset"]["annotations"]) == 3
    assert len(body["predictions"]) == 2
    # matches include TP/FP/FN with embedded boxes
    assert any(m["type"] == "truePositive" for m in body["matches"])
    for m in body["matches"]:
        assert "ground_truth" in m and "prediction" in m


def test_ap_metrics_schema(client: TestClient, open_custom_session) -> None:
    sid = open_custom_session["session_id"]
    resp = client.post(f"/api/sessions/{sid}/ap/run_1/run")
    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert _AP_KEYS.issubset(body.keys())
    assert isinstance(body["per_class"], list)
    for entry in body["per_class"]:
        assert {"category_id", "category_name", "ap", "ap50", "ap75", "ar"} <= set(
            entry.keys()
        )


def test_report_data(client: TestClient, open_custom_session) -> None:
    sid = open_custom_session["session_id"]
    body = client.get(f"/api/sessions/{sid}/eval/run_1/report-data").json()
    assert "eval" in body and "overall" in body["eval"]
    assert body["model_run"]["id"] == "run_1"


def test_cache_clear(client: TestClient, open_custom_session) -> None:
    sid = open_custom_session["session_id"]
    _run_eval(client, sid)
    assert client.post("/api/cache/clear").json()["status"] == "cleared"
