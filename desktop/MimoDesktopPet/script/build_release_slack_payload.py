#!/usr/bin/env python3
"""Build a Slack Incoming Webhook payload for a published GitHub release."""

from __future__ import annotations

import argparse
from datetime import datetime
import json
import sys
from pathlib import Path
from typing import Any


def fail(message: str) -> None:
    print(f"error: {message}", file=sys.stderr)
    raise SystemExit(1)


def load_json(path: str) -> dict[str, Any]:
    with open(path, "r", encoding="utf-8") as handle:
        data = json.load(handle)
    if not isinstance(data, dict):
        fail(f"expected object JSON in {path}")
    return data


def get_first(mapping: dict[str, Any], *keys: str) -> Any:
    for key in keys:
        value = mapping.get(key)
        if value not in (None, ""):
            return value
    return None


def escape_slack_text(value: str) -> str:
    return value.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def code(value: str) -> str:
    safe_value = escape_slack_text(value).replace("`", "'")
    return f"`{safe_value}`"


def link(url: str, label: str) -> str:
    safe_label = escape_slack_text(label).replace("|", " ")
    return f"<{url}|{safe_label}>"


def human_size(size: Any) -> str | None:
    try:
        size_value = int(size)
    except (TypeError, ValueError):
        return None

    units = ["B", "KB", "MB", "GB"]
    value = float(size_value)
    for unit in units:
        if value < 1024 or unit == units[-1]:
            if unit == "B":
                return f"{int(value)} {unit}"
            return f"{value:.1f} {unit}"
        value /= 1024
    return None


def slack_date(value: str) -> str:
    try:
        normalized = value.removesuffix("Z") + "+00:00" if value.endswith("Z") else value
        timestamp = int(datetime.fromisoformat(normalized).timestamp())
    except ValueError:
        return code(value)
    return f"<!date^{timestamp}^{{date_short_pretty}} {{time}}|{escape_slack_text(value)}>"


def browser_asset_url(release_url: str, tag: str, asset: dict[str, Any]) -> str | None:
    for key in ("browser_download_url", "downloadUrl", "url"):
        value = asset.get(key)
        if isinstance(value, str) and value.startswith("https://github.com/"):
            return value

    name = asset.get("name")
    if isinstance(name, str) and release_url:
        repository_url = release_url.split("/releases/tag/", 1)[0]
        return f"{repository_url}/releases/download/{tag}/{name}"
    return None


def normalize_release(input_json: dict[str, Any]) -> tuple[dict[str, Any], dict[str, Any]]:
    if "release" in input_json:
        release = input_json.get("release")
        repository = input_json.get("repository") or {}
    else:
        release = input_json
        repository = {}

    if not isinstance(release, dict):
        fail("event does not contain a release object")
    if not isinstance(repository, dict):
        repository = {}
    return release, repository


def find_asset(assets: list[Any], suffix: str) -> dict[str, Any] | None:
    for asset in assets:
        if not isinstance(asset, dict):
            continue
        name = asset.get("name")
        if isinstance(name, str) and name.endswith(suffix):
            return asset
    return None


def build_payload(
    release: dict[str, Any],
    repository: dict[str, Any],
    repository_name: str | None,
    repository_url: str | None,
) -> dict[str, Any]:
    if bool(get_first(release, "draft", "isDraft")):
        fail("release is still a draft; Slack deploy notification is only for published releases")
    if bool(get_first(release, "prerelease", "isPrerelease")):
        fail("release is a prerelease; Slack deploy notification is only for stable releases")

    tag = get_first(release, "tag_name", "tagName")
    if not isinstance(tag, str):
        fail("release tag is missing")

    release_name = get_first(release, "name") or f"Mimo Desktop Pet {tag}"
    release_url = get_first(release, "html_url", "url")
    if not isinstance(release_url, str):
        fail("release URL is missing")

    assets = release.get("assets") or []
    if not isinstance(assets, list):
        fail("release assets must be a list")

    dmg_asset = find_asset(assets, ".dmg")
    if not dmg_asset:
        fail("release does not contain a .dmg asset")

    dmg_name = get_first(dmg_asset, "name")
    if not isinstance(dmg_name, str):
        fail("DMG asset name is missing")

    dmg_url = browser_asset_url(release_url, tag, dmg_asset)
    if not dmg_url:
        fail("DMG browser download URL is missing")

    checksum_asset = find_asset(assets, ".dmg.sha256") or find_asset(assets, ".sha256")
    checksum_url = browser_asset_url(release_url, tag, checksum_asset) if checksum_asset else None

    repository_name = repository_name or get_first(repository, "full_name", "name_with_owner") or "biwakonbu/mimo-codex-pets"
    repository_url = repository_url or get_first(repository, "html_url", "url")
    if not isinstance(repository_url, str):
        repository_url = f"https://github.com/{repository_name}"

    size = human_size(dmg_asset.get("size"))
    digest = get_first(dmg_asset, "digest")
    checksum_text = ""
    if isinstance(digest, str) and digest.startswith("sha256:"):
        checksum_text = f"SHA-256 {code(digest.removeprefix('sha256:'))}"
    elif checksum_url:
        checksum_text = f"Checksum {link(checksum_url, 'download .sha256')}"

    published_at = get_first(release, "published_at", "publishedAt")
    target = get_first(release, "target_commitish", "targetCommitish")

    details = []
    if size:
        details.append(f"DMG {code(dmg_name)} ({size})")
    else:
        details.append(f"DMG {code(dmg_name)}")
    if checksum_text:
        details.append(checksum_text)
    if isinstance(published_at, str):
        details.append(f"Published {slack_date(published_at)}")
    if isinstance(target, str):
        details.append(f"Target {code(target)}")

    return {
        "text": f"Mimo Desktop Pet {tag} デプロイ成功",
        "unfurl_links": False,
        "unfurl_media": False,
        "blocks": [
            {
                "type": "header",
                "text": {
                    "type": "plain_text",
                    "text": f"Mimo Desktop Pet {tag} デプロイ成功",
                    "emoji": False,
                },
            },
            {
                "type": "section",
                "text": {
                    "type": "mrkdwn",
                    "text": (
                        f"*{escape_slack_text(str(release_name))}* を GitHub Releases に公開しました。\n"
                        "公証済みの macOS DMG をインストールできます。"
                    ),
                },
            },
            {
                "type": "section",
                "fields": [
                    {"type": "mrkdwn", "text": f"*Version*\n{code(tag)}"},
                    {"type": "mrkdwn", "text": "*Status*\n`公開済み`"},
                    {"type": "mrkdwn", "text": f"*Release*\n{link(release_url, 'Release を開く')}"},
                    {"type": "mrkdwn", "text": f"*Repository*\n{link(repository_url, str(repository_name))}"},
                ],
            },
            {
                "type": "actions",
                "elements": [
                    {
                        "type": "button",
                        "text": {"type": "plain_text", "text": "DMG をダウンロード", "emoji": False},
                        "url": dmg_url,
                        "style": "primary",
                    },
                    {
                        "type": "button",
                        "text": {"type": "plain_text", "text": "Release を開く", "emoji": False},
                        "url": release_url,
                    },
                    {
                        "type": "button",
                        "text": {"type": "plain_text", "text": "Repository", "emoji": False},
                        "url": repository_url,
                    },
                ],
            },
            {
                "type": "context",
                "elements": [
                    {
                        "type": "mrkdwn",
                        "text": " | ".join(details),
                    }
                ],
            },
        ],
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--event-path", help="GitHub release event JSON path")
    source.add_argument("--release-json", help="gh release view JSON path")
    parser.add_argument("--repository", help="repository name, e.g. owner/repo")
    parser.add_argument("--repository-url", help="repository browser URL")
    parser.add_argument("--output", required=True, help="output Slack payload JSON path")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    input_path = args.event_path or args.release_json
    release, repository = normalize_release(load_json(input_path))
    payload = build_payload(release, repository, args.repository, args.repository_url)

    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
