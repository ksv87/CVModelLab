"""Config parsing and auth (API key + startup gating)."""

from __future__ import annotations

import re
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from cvmlab_server.auth import StartupAborted, check_startup_auth
from cvmlab_server.config import ServerConfig, load_config
from cvmlab_server.main import create_app

from conftest import build_config


def test_load_config_from_yaml(tmp_path: Path) -> None:
    cfg_file = tmp_path / "server.yaml"
    cfg_file.write_text(
        "host: 127.0.0.1\nport: 9000\n"
        "allowed_roots:\n  - id: d\n    path: /tmp\n    label: D\n"
    )
    config = load_config(str(cfg_file))
    assert config.host == "127.0.0.1"
    assert config.port == 9000
    assert config.allowed_roots[0].id == "d"
    assert config.auth_enabled is False


def test_env_override(tmp_path: Path, monkeypatch) -> None:
    cfg_file = tmp_path / "server.yaml"
    cfg_file.write_text("port: 8080\nallowed_roots: []\n")
    monkeypatch.setenv("CVMLAB_PORT", "1234")
    monkeypatch.setenv("CVMLAB_API_KEY", "secret")
    config = load_config(str(cfg_file))
    assert config.port == 1234
    assert config.api_key == "secret"
    assert config.auth_enabled is True


def test_startup_with_api_key_ok(dataset_root: Path) -> None:
    config = build_config(dataset_root, api_key="k")
    check_startup_auth(config)  # should not raise


def test_startup_open_access_noninteractive_refused(dataset_root: Path) -> None:
    config = build_config(dataset_root)
    with pytest.raises(StartupAborted):
        check_startup_auth(config, interactive=False, output_fn=lambda m: None)


def test_startup_open_access_flag_allows(dataset_root: Path) -> None:
    config = build_config(dataset_root)
    check_startup_auth(
        config,
        allow_unauthenticated=True,
        interactive=False,
        output_fn=lambda m: None,
    )


def test_startup_interactive_requires_yes(dataset_root: Path) -> None:
    config = build_config(dataset_root)
    with pytest.raises(StartupAborted):
        check_startup_auth(
            config, interactive=True, input_fn=lambda _: "", output_fn=lambda m: None
        )
    # explicit yes allows
    check_startup_auth(
        config, interactive=True, input_fn=lambda _: "y", output_fn=lambda m: None
    )


def test_api_key_required_when_configured(dataset_root: Path) -> None:
    config = build_config(dataset_root, api_key="topsecret")
    client = TestClient(create_app(config))
    # Every API endpoint requires the key when auth is enabled, including the
    # health and client-config endpoints.
    assert client.get("/api/health").status_code == 401
    assert client.get("/api/config").status_code == 401
    assert client.get("/api/roots").status_code == 401
    # ...and succeed once the key is supplied.
    headers = {"X-CVML-API-Key": "topsecret"}
    assert client.get("/api/health", headers=headers).status_code == 200
    assert client.get("/api/config", headers=headers).status_code == 200
    assert client.get("/api/roots", headers=headers).status_code == 200


def test_every_api_route_requires_key_when_auth_enabled(dataset_root: Path) -> None:
    """Guard: no /api route may be reachable without the key under auth.

    Enumerates the mounted routes so a future router that forgets the auth
    dependency fails this test instead of silently exposing data.
    """
    app = create_app(build_config(dataset_root, api_key="topsecret"))
    client = TestClient(app)
    checked = 0
    for route in app.routes:
        path = getattr(route, "path", "")
        methods = getattr(route, "methods", None)
        if not path.startswith("/api/") or not methods:
            continue
        # Substitute a placeholder for any path parameter so the route matches
        # and auth runs before the handler.
        concrete = re.sub(r"\{[^}]+\}", "x", path)
        for method in ("GET", "POST", "PUT", "DELETE", "PATCH"):
            if method not in methods:
                continue
            response = client.request(method, concrete)
            assert response.status_code == 401, (
                f"{method} {path} returned {response.status_code} without an "
                f"API key; expected 401"
            )
            checked += 1
    assert checked > 0, "no /api routes were checked"


def test_health_and_client_config(client: TestClient) -> None:
    assert client.get("/api/health").json()["status"] == "ok"
    config_body = client.get("/api/config").json()
    assert config_body["auth_required"] is False
    assert config_body["custom_paths_enabled"] is True
