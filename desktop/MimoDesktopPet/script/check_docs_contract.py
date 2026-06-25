#!/usr/bin/env python3
"""Keep the public companion docs aligned with the production QA contract."""

from __future__ import annotations

import re
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parents[1]
SCRIPT_DIR = ROOT_DIR / "script"
README = ROOT_DIR / "README.md"
RESEARCH = ROOT_DIR / "docs" / "codex-pets-research.md"
QA_ALL = SCRIPT_DIR / "qa_all.sh"
SCHEMA_CHECK = SCRIPT_DIR / "check_app_server_schema.sh"
LIVE_SMOKE = SCRIPT_DIR / "live_app_server_smoke.py"
LIVE_DIALOGUE_SMOKE = SCRIPT_DIR / "live_mimo_dialogue_smoke.py"
ENERGY_E2E = SCRIPT_DIR / "e2e_autonomous_energy.sh"
CLIENT = ROOT_DIR / "Sources" / "MimoDesktopPet" / "Services" / "CodexAppServerClient.swift"
PROTOCOL = ROOT_DIR / "Sources" / "MimoDesktopPetCore" / "CodexProtocol.swift"
FORMATTER = ROOT_DIR / "Sources" / "MimoDesktopPetCore" / "CodexBubbleFormatter.swift"
DIALOGUE_PROMPT = ROOT_DIR / "Sources" / "MimoDesktopPetCore" / "CodexMimoDialoguePrompt.swift"
SUMMARIZER = ROOT_DIR / "Sources" / "MimoDesktopPetCore" / "CodexSessionSummarizer.swift"
ENERGY = ROOT_DIR / "Sources" / "MimoDesktopPetCore" / "PetAutonomousEnergyController.swift"
ENERGY_TESTS = ROOT_DIR / "Tests" / "MimoDesktopPetCoreTests" / "PetAutonomousEnergyControllerTests.swift"
PERFECT_CUTE_UI_BOARD = ROOT_DIR / "design" / "ui-proposals" / "mimo-perfect-cute-ui-board-05.png"


def fail(message: str) -> None:
    raise SystemExit(message)


def read(path: Path) -> str:
    if not path.is_file():
        fail(f"required file is missing: {path.relative_to(ROOT_DIR)}")
    return path.read_text(encoding="utf-8")


def require_text(path: Path, needles: list[str], *, label: str) -> None:
    text = read(path)
    missing = [needle for needle in needles if needle not in text]
    if missing:
        formatted = "\n".join(f"  - {needle}" for needle in missing)
        fail(f"{label} missing required text in {path.relative_to(ROOT_DIR)}:\n{formatted}")


def require_readme_links() -> None:
    text = read(README)
    targets = re.findall(r"\[[^\]]+\]\(([^)]+)\)", text)
    missing: list[str] = []
    for raw_target in targets:
        target = raw_target.split("#", 1)[0]
        if not target or target.startswith(("http://", "https://", "mailto:")):
            continue
        if "://" in target:
            continue
        path = (README.parent / target).resolve()
        try:
            path.relative_to(ROOT_DIR)
        except ValueError:
            continue
        if not path.exists():
            missing.append(raw_target)
    if missing:
        fail("README.md has broken local link(s): " + ", ".join(missing))


def require_app_server_contract() -> None:
    app_server_terms = [
        "codex app-server daemon start",
        "codex app-server proxy",
        "codex app-server --stdio",
        "initialize",
        "clientInfo",
        "experimentalApi",
        "thread/loaded/list",
        "thread/list",
        "thread/read",
        "thread/start",
        "turn/start",
        "includeTurns",
        "thread/status/changed",
        "turn/started",
        "turn/completed",
        "item/started",
        "item/completed",
    ]
    require_text(README, app_server_terms, label="README app-server contract")
    require_text(RESEARCH, app_server_terms, label="research app-server contract")
    require_text(
        CLIENT,
        [
            '"name": "mimo_desktop_pet"',
            '"experimentalApi": true',
            'method: "thread/loaded/list"',
            'method: "thread/list"',
            'method: "thread/read"',
            'method: "thread/start"',
            'method: "turn/start"',
            '"includeTurns": true',
            "handleNotification(method:",
        ],
        label="Swift app-server client contract",
    )
    require_text(
        LIVE_SMOKE,
        [
            '"name": "mimo_desktop_pet_smoke"',
            '"experimentalApi": True',
            '"thread/loaded/list"',
            '"thread/list"',
            '"thread/read"',
            '"includeTurns": True',
        ],
        label="live smoke protocol contract",
    )
    require_text(
        LIVE_DIALOGUE_SMOKE,
        [
            '"name": "mimo_desktop_pet_dialogue_smoke"',
            '"experimentalApi": True',
            '"thread/start"',
            '"turn/start"',
            '"ephemeral": True',
            '"approvalPolicy": "never"',
            '"sandbox": "read-only"',
            '"sandboxPolicy"',
            '"networkAccess": False',
            "gpt-5.4-mini",
        ],
        label="live Mimo dialogue smoke protocol contract",
    )
    require_text(
        SCHEMA_CHECK,
        [
            'require_pattern "v1/InitializeParams.json" \'"experimentalApi"\'',
            'require_pattern "ClientRequest.json" \'"thread/loaded/list"\'',
            'require_pattern "ClientRequest.json" \'"thread/list"\'',
            'require_pattern "ClientRequest.json" \'"thread/read"\'',
            'require_pattern "ClientRequest.json" \'"thread/start"\'',
            'require_pattern "ClientRequest.json" \'"turn/start"\'',
            "ServerNotification.json",
            "CodexNotificationMethod",
            "CodexIgnoredNotificationMethod",
        ],
        label="schema drift contract",
    )
    require_text(
        PROTOCOL,
        [
            'case threadStatusChanged = "thread/status/changed"',
            'case turnStarted = "turn/started"',
            'case turnCompleted = "turn/completed"',
            'case itemStarted = "item/started"',
            'case itemCompleted = "item/completed"',
            'case agentMessageDelta = "item/agentMessage/delta"',
            'case commandExecutionOutputDelta = "item/commandExecution/outputDelta"',
            'case threadRealtimeTranscriptDelta = "thread/realtime/transcript/delta"',
            'case threadRealtimeOutputAudioDelta = "thread/realtime/outputAudio/delta"',
        ],
        label="Swift notification coverage contract",
    )


def require_mimicry_contract() -> None:
    mimicry_terms = [
        "Codex Pets",
        "Mimo-style report",
        "multi-thread",
        "stacked",
        "speech bubbles",
        "dynamic nearby bubble cloud",
        "unsynchronized drift",
        "workSummary",
        "CodexSessionSummarizer",
        "raw",
        "secret",
        "MimoDesktopPet.productionSurface",
        "Computer Use",
        "Debug Overlay",
        "production",
    ]
    require_text(README, mimicry_terms, label="README mimicry contract")
    require_text(
        README,
        ["design/ui-proposals/mimo-perfect-cute-ui-board-05.png"],
        label="README cute UI proposal contract",
    )
    require_text(
        RESEARCH,
        ["design/ui-proposals/mimo-perfect-cute-ui-board-05.png"],
        label="research cute UI proposal contract",
    )
    if not PERFECT_CUTE_UI_BOARD.is_file():
        fail("cute UI proposal board is missing: design/ui-proposals/mimo-perfect-cute-ui-board-05.png")
    require_text(RESEARCH, mimicry_terms, label="research mimicry contract")
    require_text(
        FORMATTER,
        [
            "primarySpeechSummary",
            "contextDisplaySummary",
            "displayTitleVocabulary",
            "sessionState",
            "mimoSpeech",
            "reportTopic(for:",
            "workSummary",
            "activitySummary(for:",
            "toolSummary(for:",
        ],
        label="bubble formatter contract",
    )
    require_text(
        DIALOGUE_PROMPT,
        [
            "CodexMimoDialoguePrompt",
            "gpt-5.4-mini",
            "Mimo speech request",
            "chat_state",
            "safe_work_topic",
            "sanitizedSpeech",
            "Never use the words スレッド",
        ],
        label="Codex-backed Mimo dialogue contract",
    )
    require_text(
        SUMMARIZER,
        [
            "CodexSessionSummarizer",
            "CodexAmbientTextSafety.isUnsafeForAmbientDisplay",
            "作業内容の説明",
            "進捗の具体説明",
            "吹き出し要約の表示文言",
            "吹き出し要約",
            "複数チャット表示",
            "Codex 連携",
            "Mimo の動き",
        ],
        label="session summarizer contract",
    )


def require_stamina_contract() -> None:
    stamina_terms = [
        "MIMO_AUTONOMOUS_WINDOW_MOVEMENT=1",
        "8s",
        "18-34s",
        "2.4 pt/s",
        "8 pt",
        "stamina",
        "below 50%",
        "MIMO_AUTONOMOUS_DISABLED=1",
        "e2e_autonomous_default_stationary.sh",
        "e2e_autonomous_energy.sh",
    ]
    require_text(README, stamina_terms, label="README stamina contract")
    require_text(
        RESEARCH,
        [
            "default production keeps the desktop panel anchored",
            "MIMO_AUTONOMOUS_WINDOW_MOVEMENT=1",
            "8s",
            "18-34s",
            "2.4 pt/s",
            "8 pt",
            "holds position",
            "rest/idle moments",
            "Fake app-server E2E samples the live window position during autonomous",
        ],
        label="research autonomous motion contract",
    )
    require_text(
        ENERGY,
        [
            "defaultDrainPerSecond",
            "defaultRecoveryPerSecond",
            "fatiguePauseThreshold = 0.5",
            "exhaustedThreshold",
            "shouldPauseForRest",
            "restDuration",
        ],
        label="stamina controller contract",
    )
    require_text(
        SCRIPT_DIR / "e2e_autonomous_default_stationary.sh",
        [
            "MIMO_AUTONOMOUS_INITIAL_REST_SECONDS=0",
            "default production launch moved the window unexpectedly",
            "default production launch had moving samples",
            "default stationary run unexpectedly used movement animation",
            "keeps Mimo anchored unless autonomous window movement is explicitly enabled",
        ],
        label="default stationary E2E contract",
    )
    require_text(
        ENERGY_TESTS,
        [
            "testHighStaminaRunsNearMaximumSpeed",
            "testSpeedFallsAsStaminaDrops",
            "testMovingDrainsAndRestingRecoversStamina",
            "testStaminaBelowHalfCanTriggerMoodRest",
            "testRestDurationAllowsRecoveryToFull",
        ],
        label="stamina unit-test contract",
    )
    require_text(
        ENERGY_E2E,
        [
            "MIMO_AUTONOMOUS_ENERGY_TEST_MODE=1",
            "MIMO_AUTONOMOUS_STAMINA_INITIAL",
            "MIMO_AUTONOMOUS_STAMINA_DRAIN_PER_SECOND",
            "MIMO_AUTONOMOUS_STAMINA_RECOVERY_PER_SECOND",
            "rest",
            "production surface transparent",
        ],
        label="stamina E2E contract",
    )


def require_qa_contract() -> None:
    require_text(
        QA_ALL,
        [
            "desktop/MimoDesktopPet/script/check_docs_contract.py",
            './script/check_docs_contract.py',
            './script/e2e_autonomous_energy.sh',
            './script/check_app_server_schema.sh',
            './script/live_app_server_smoke.py',
            "desktop/MimoDesktopPet/script/live_mimo_dialogue_smoke.py",
            './script/live_app_presentation_smoke.sh',
            './script/check_qa_all_coverage.py',
        ],
        label="canonical QA gate contract",
    )


def main() -> None:
    require_readme_links()
    require_app_server_contract()
    require_mimicry_contract()
    require_stamina_contract()
    require_qa_contract()
    print("Docs contract check passed: README, research notes, protocol, mimicry, stamina, and QA gate are aligned.")


if __name__ == "__main__":
    main()
