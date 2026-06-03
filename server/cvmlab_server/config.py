"""Server configuration loading and models.

Configuration sources, in order of increasing precedence:
  1. defaults defined here
  2. YAML config file (``--config server.yaml``)
  3. environment variables (``CVMLAB_*``)
  4. explicit CLI arguments

The configuration is intentionally read-only at runtime: the server never
rewrites its own config file.
"""

from __future__ import annotations

import os
from pathlib import Path
from typing import List, Optional

import yaml
from pydantic import BaseModel, Field, field_validator


class AllowedRoot(BaseModel):
    """A filesystem root the server is permitted to read from."""

    id: str
    path: str
    label: Optional[str] = None

    @field_validator("id")
    @classmethod
    def _non_empty_id(cls, value: str) -> str:
        if not value or not value.strip():
            raise ValueError("allowed root id must be non-empty")
        return value


class ProjectManifestsConfig(BaseModel):
    enabled: bool = False
    directory: Optional[str] = None


class CustomServerPathsConfig(BaseModel):
    enabled: bool = True


class CacheConfig(BaseModel):
    enabled: bool = True
    directory: str = ".cvmlab-server-cache"
    thumbnails: bool = True
    parsed_projects: bool = True
    max_size_mb: int = 4096


class LogsConfig(BaseModel):
    directory: str = ".cvmlab-server-logs"


class StaticWebConfig(BaseModel):
    enabled: bool = True
    root: str = "../build/web"


class CorsConfig(BaseModel):
    enabled: bool = True
    allowed_origins: List[str] = Field(default_factory=lambda: ["http://localhost:*"])


class ServerConfig(BaseModel):
    host: str = "0.0.0.0"
    port: int = 8080
    api_key: Optional[str] = None
    max_request_body_mb: int = 16

    allowed_roots: List[AllowedRoot] = Field(default_factory=list)
    project_manifests: ProjectManifestsConfig = Field(
        default_factory=ProjectManifestsConfig
    )
    custom_server_paths: CustomServerPathsConfig = Field(
        default_factory=CustomServerPathsConfig
    )
    cache: CacheConfig = Field(default_factory=CacheConfig)
    logs: LogsConfig = Field(default_factory=LogsConfig)
    static_web: StaticWebConfig = Field(default_factory=StaticWebConfig)
    cors: CorsConfig = Field(default_factory=CorsConfig)

    # Resolved directory of the config file, used to resolve relative paths.
    base_dir: str = "."

    @property
    def auth_enabled(self) -> bool:
        return bool(self.api_key)

    def resolve_relative(self, value: str) -> str:
        """Resolve ``value`` relative to the config file directory if needed."""
        path = Path(value)
        if path.is_absolute():
            return str(path)
        return str((Path(self.base_dir) / path).resolve())


def load_config(config_path: Optional[str]) -> ServerConfig:
    """Load configuration from a YAML file plus environment overrides."""
    data: dict = {}
    base_dir = "."
    if config_path:
        path = Path(config_path)
        if not path.exists():
            raise FileNotFoundError(f"Config file not found: {config_path}")
        with path.open("r", encoding="utf-8") as handle:
            loaded = yaml.safe_load(handle) or {}
        if not isinstance(loaded, dict):
            raise ValueError("Config file must contain a YAML mapping at the top level")
        data = loaded
        base_dir = str(path.resolve().parent)

    data = _apply_env_overrides(data)
    data["base_dir"] = base_dir
    return ServerConfig.model_validate(data)


def _apply_env_overrides(data: dict) -> dict:
    """Apply ``CVMLAB_*`` environment variable overrides for scalar settings."""
    env = os.environ
    if "CVMLAB_HOST" in env:
        data["host"] = env["CVMLAB_HOST"]
    if "CVMLAB_PORT" in env:
        data["port"] = int(env["CVMLAB_PORT"])
    if "CVMLAB_API_KEY" in env:
        data["api_key"] = env["CVMLAB_API_KEY"] or None
    return data
