"""Allowed-roots path resolution — the single security choke-point.

Every endpoint that touches the filesystem MUST resolve its target path
through :class:`PathResolver`. The resolver guarantees that the returned
canonical path stays inside one of the configured allowed roots, rejecting:

* path traversal (``..`` segments),
* absolute paths that escape every allowed root,
* symlinks whose canonical target escapes the allowed root.
"""

from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Optional

from ..config import AllowedRoot, ServerConfig


class PathAccessError(Exception):
    """Raised when a requested path is not permitted."""


@dataclass(frozen=True)
class ResolvedRoot:
    id: str
    label: str
    # Canonical (symlink-resolved) absolute path of the root.
    real_path: str


@dataclass(frozen=True)
class ResolvedPath:
    root_id: str
    # Canonical absolute path on the server filesystem.
    abs_path: str
    # Path relative to the owning allowed root (posix-style, no leading slash).
    rel_path: str


class PathResolver:
    def __init__(self, config: ServerConfig) -> None:
        self._roots: Dict[str, ResolvedRoot] = {}
        for root in config.allowed_roots:
            resolved = self._resolve_root(config, root)
            self._roots[resolved.id] = resolved

    @staticmethod
    def _resolve_root(config: ServerConfig, root: AllowedRoot) -> ResolvedRoot:
        absolute = config.resolve_relative(root.path)
        real = os.path.realpath(absolute)
        return ResolvedRoot(
            id=root.id,
            label=root.label or root.id,
            real_path=real,
        )

    def list_roots(self) -> List[ResolvedRoot]:
        return list(self._roots.values())

    def get_root(self, root_id: str) -> ResolvedRoot:
        root = self._roots.get(root_id)
        if root is None:
            raise PathAccessError(f"Unknown root id: {root_id}")
        return root

    def resolve_within_root(self, root_id: str, rel_path: str) -> ResolvedPath:
        """Resolve ``rel_path`` (relative to ``root_id``) safely."""
        root = self.get_root(root_id)
        candidate = self._normalize_relative(rel_path)
        joined = os.path.join(root.real_path, candidate) if candidate else root.real_path
        real = os.path.realpath(joined)
        if not self._is_within(real, root.real_path):
            raise PathAccessError("Path escapes allowed root")
        return ResolvedPath(
            root_id=root.id,
            abs_path=real,
            rel_path=os.path.relpath(real, root.real_path).replace(os.sep, "/")
            if real != root.real_path
            else "",
        )

    def resolve_absolute(self, abs_path: str) -> ResolvedPath:
        """Validate an absolute server path against all allowed roots.

        Used for manifest entries and custom-paths sessions, where the client
        provides canonical server paths returned earlier by the browser.
        """
        if not os.path.isabs(abs_path):
            raise PathAccessError("Expected an absolute server path")
        real = os.path.realpath(abs_path)
        for root in self._roots.values():
            if self._is_within(real, root.real_path):
                rel = (
                    os.path.relpath(real, root.real_path).replace(os.sep, "/")
                    if real != root.real_path
                    else ""
                )
                return ResolvedPath(root_id=root.id, abs_path=real, rel_path=rel)
        raise PathAccessError("Path is outside every allowed root")

    @staticmethod
    def _normalize_relative(rel_path: Optional[str]) -> str:
        if not rel_path:
            return ""
        # Reject absolute paths and drive letters up front.
        if rel_path.startswith("/") or rel_path.startswith("\\"):
            raise PathAccessError("Absolute paths are not allowed in browse requests")
        pure = PurePosixSafe(rel_path)
        return pure.value

    @staticmethod
    def _is_within(candidate: str, root: str) -> bool:
        if candidate == root:
            return True
        # Compare using os.path.commonpath to avoid prefix-string false positives
        # (e.g. /data/abc vs /data/ab).
        try:
            return os.path.commonpath([candidate, root]) == root
        except ValueError:
            # Different drives on Windows, etc.
            return False


class PurePosixSafe:
    """Normalize a relative path and reject traversal segments."""

    def __init__(self, raw: str) -> None:
        parts: List[str] = []
        for segment in raw.replace("\\", "/").split("/"):
            if segment in ("", "."):
                continue
            if segment == "..":
                raise PathAccessError("Path traversal ('..') is not allowed")
            parts.append(segment)
        self.value = "/".join(parts)
