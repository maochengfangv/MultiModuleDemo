#!/usr/bin/env python3
import os
import re
import shutil
import subprocess
from pathlib import Path

PROJECT_ROOT = Path("/Users/maochengfang/Documents/LLMProject/1009MultiModuleDemo")
REPORT_DIR = PROJECT_ROOT / "reports" / "dead_code" / "swift"
SCHEME = os.environ.get("SCHEME", "1009MultiModuleDemo")
TARGET = os.environ.get("TARGET", SCHEME)

EXCLUDED_DIR_NAMES = {
    "Pods",
    "build",
    "DerivedData",
    ".git",
    "1009MultiModuleDemoTests",
    "1009MultiModuleDemoUITests",
}

RISK_PATTERN = re.compile(
    r"@objc|@objcMembers|\bdynamic\b|#selector\s*\(|Selector\s*\(",
    re.MULTILINE,
)
TOP_LEVEL_FUNC_RE = re.compile(r"^func\s+([A-Za-z_]\w*)\s*\(", re.MULTILINE)

def is_excluded(path: Path) -> bool:
    return any(part in EXCLUDED_DIR_NAMES for part in path.parts)

def collect_swift_files():
    files = []
    for path in PROJECT_ROOT.rglob("*.swift"):
        if is_excluded(path):
            continue
        files.append(path)
    return sorted(files)

def write_text(path: Path, content: str):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")

def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        return path.read_text(encoding="utf-8", errors="ignore")

def collect_top_level_function_candidates(swift_files):
    file_texts = {path: read_text(path) for path in swift_files}
    candidates = []
    for path, text in file_texts.items():
        if RISK_PATTERN.search(text):
            continue
        for match in TOP_LEVEL_FUNC_RE.finditer(text):
            name = match.group(1)
            name_re = re.compile(rf"\b{re.escape(name)}\b")
            hit_count = sum(len(name_re.findall(candidate_text)) for candidate_text in file_texts.values())
            if hit_count == 1:
                line_no = text[:match.start()].count("\n") + 1
                candidates.append(f"{path}:{line_no}: top-level function '{name}()' has no reference hit")
    return candidates

def detect_build_target():
    workspace = PROJECT_ROOT / "1009MultiModuleDemo.xcworkspace"
    project = PROJECT_ROOT / "1009MultiModuleDemo.xcodeproj"
    if workspace.exists():
        return ("workspace", workspace)
    return ("project", project)

def run_command(cmd, cwd: Path):
    return subprocess.run(
        cmd,
        cwd=str(cwd),
        text=True,
        capture_output=True,
    )

def main():
    REPORT_DIR.mkdir(parents=True, exist_ok=True)

    swift_files = collect_swift_files()
    inventory_path = REPORT_DIR / "swift_file_inventory.txt"
    write_text(
        inventory_path,
        "\n".join(str(p) for p in swift_files) + ("\n" if swift_files else ""),
    )

    risk_hits = []
    for file_path in swift_files:
        content = read_text(file_path)
        for idx, line in enumerate(content.splitlines(), start=1):
            if RISK_PATTERN.search(line):
                risk_hits.append(f"{file_path}:{idx}: {line.strip()}")

    risk_path = REPORT_DIR / "swift_dynamic_risk_hits.txt"
    write_text(risk_path, "\n".join(risk_hits) + ("\n" if risk_hits else ""))

    fallback_candidates = collect_top_level_function_candidates(swift_files)
    fallback_path = REPORT_DIR / "swift_top_level_candidates.txt"
    write_text(fallback_path, "\n".join(fallback_candidates) + ("\n" if fallback_candidates else ""))

    summary_lines = [
        f"project_root: {PROJECT_ROOT}",
        f"scheme: {SCHEME}",
        f"target: {TARGET}",
        f"swift_file_count: {len(swift_files)}",
        f"inventory: {inventory_path}",
        f"risk_hits: {risk_path}",
    ]

    if not swift_files:
        summary_lines.extend([
            "periphery_status: skipped",
            "reason: no app-side Swift source files found in this repository",
            "note: current project is Objective-C centric; this script remains reusable when Swift files are added later",
        ])
        write_text(REPORT_DIR / "summary.txt", "\n".join(summary_lines) + "\n")
        print(f"[swift-dead-code] No Swift files found. Summary written to: {REPORT_DIR / 'summary.txt'}")
        return

    periphery = shutil.which("periphery")
    if not periphery:
        summary_lines.extend([
            "periphery_status: missing",
            "install_hint: brew install peripheryapp/periphery/periphery",
        ])
        write_text(REPORT_DIR / "summary.txt", "\n".join(summary_lines) + "\n")
        print("[swift-dead-code] periphery not found. Install with:")
        print("brew install peripheryapp/periphery/periphery")
        print(f"[swift-dead-code] Summary written to: {REPORT_DIR / 'summary.txt'}")
        return

    build_type, build_path = detect_build_target()
    raw_report = REPORT_DIR / "periphery_raw_report.txt"

    cmd = [
        periphery,
        "scan",
        f"--{build_type}",
        str(build_path),
        "--schemes",
        SCHEME,
        "--targets",
        TARGET,
        "--format",
        "xcode",
        "--verbose",
        "--disable-update-check",
    ]

    result = run_command(cmd, PROJECT_ROOT)
    combined_output = (result.stdout or "") + ("\n" if result.stdout and result.stderr else "") + (result.stderr or "")
    write_text(raw_report, combined_output)

    candidate_lines = []
    for line in combined_output.splitlines():
        if line.startswith(str(PROJECT_ROOT)) and ": warning:" in line:
            candidate_lines.append(line)

    candidate_path = REPORT_DIR / "swift_unused_candidates.txt"
    write_text(candidate_path, "\n".join(candidate_lines) + ("\n" if candidate_lines else ""))

    summary_lines.extend([
        f"periphery_status: exit_code_{result.returncode}",
        f"raw_report: {raw_report}",
        f"candidate_report: {candidate_path}",
        f"fallback_report: {fallback_path}",
        "warning: periphery output is a candidate set; review @objc/dynamic/selector-based call sites before deletion",
        "fallback_note: top-level fallback is heuristic-only and should be manually verified before deletion",
    ])
    write_text(REPORT_DIR / "summary.txt", "\n".join(summary_lines) + "\n")

    print(f"[swift-dead-code] Raw report: {raw_report}")
    print(f"[swift-dead-code] Candidate report: {candidate_path}")
    print(f"[swift-dead-code] Summary: {REPORT_DIR / 'summary.txt'}")

if __name__ == "__main__":
    main()