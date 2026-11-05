#!/usr/bin/env python3
import re
from collections import defaultdict
from pathlib import Path

PROJECT_ROOT = Path("/Users/maochengfang/Documents/LLMProject/1009MultiModuleDemo")
APP_ROOT = PROJECT_ROOT / "1009MultiModuleDemo"
REPORT_DIR = PROJECT_ROOT / "reports" / "dead_code" / "oc"

EXCLUDED_DIR_NAMES = {
    "Pods",
    "build",
    "DerivedData",
    ".git",
    "1009MultiModuleDemoTests",
    "1009MultiModuleDemoUITests",
}

SOURCE_EXTENSIONS = {".h", ".m", ".mm", ".storyboard", ".xib", ".plist"}

HIGH_RISK_PATTERN = re.compile(
    r"NSClassFromString|NSSelectorFromString|performSelector|respondsToSelector|"
    r"objc_msgSend|method_exchangeImplementations|class_getMethodImplementation|"
    r"addTarget\s*:|sendAction\s*:|IBAction|NSNotificationCenter|addObserver|postNotification|"
    r"observeValueForKeyPath|setValue\s*:.*forKey|valueForKey|"
    r"^\s*\+\s*\([^)]*\)\s*load\b|^\s*\+\s*\([^)]*\)\s*initialize\b|"
    r"\bTarget_[A-Za-z0-9_]+\b|\bAction_[A-Za-z0-9_]+\b",
    re.MULTILINE,
)

PROTECTED_FILE_HINTS = (
    "/Router/",
    "/Navigator/",
    "/TargetActor/",
    "/AppDelegate.",
    "/SceneDelegate.",
    "/main.m",
)

PROTECTED_CLASS_RE = re.compile(
    r"^(AppDelegate|SceneDelegate|ViewController|Navigator|Router|RouterEmptyProxy|Target_.*)$"
)

ROUTER_REGISTER_RE = re.compile(
    r"registerProtocol:\s*@protocol\((?P<protocol>[A-Za-z_]\w*)\)\s+impl:\s*\[(?P<impl>self|[A-Za-z_]\w*)\s+class\]"
)
ROUTER_USAGE_RE = re.compile(
    r"sericeForProtocol:\s*@protocol\((?P<protocol>[A-Za-z_]\w*)\)"
)
TARGET_ACTION_CALL_RE = re.compile(
    r'performTarget:\s*@"(?P<target>[A-Za-z_]\w*)"\s+action:\s*@"(?P<action>[A-Za-z_]\w*)"'
)
NAVIGATOR_ALLOWED_ROUTE_RE = re.compile(
    r'@"(?P<target>[A-Za-z_]\w*)/(?P<action>[A-Za-z_]\w*)"'
)
NAVIGATOR_URL_CALL_RE = re.compile(
    r'openURLString:\s*@"[A-Za-z][A-Za-z0-9+.\-]*://(?P<target>[A-Za-z_]\w*)/(?P<action>[A-Za-z_]\w*)'
)

SYSTEM_SELECTOR_PREFIXES = (
    "viewDid",
    "viewWill",
    "application",
    "scene",
    "tableView",
    "collectionView",
    "locationManager",
    "centralManager",
    "peripheral",
    "touches",
    "prepareForSegue",
    "observeValueForKeyPath",
    "Action_",
)

SYSTEM_SELECTORS = {
    "init",
    "dealloc",
    "loadView",
    "viewDidLoad",
    "didReceiveMemoryWarning",
}

IGNORED_METHOD_SELECTORS = {
    "copyWithZone:",
    "mutableCopyWithZone:",
}

METHOD_DECLARATION_BLOCK_RE = re.compile(
    r"^[ \t]*[+-]\s*\([^)]*\)\s*(?:[^;{\n]+(?:\n[ \t]+[^;{\n]+)*)[;{]",
    re.MULTILINE,
)

def is_excluded(path: Path) -> bool:
    return any(part in EXCLUDED_DIR_NAMES for part in path.parts)

def is_protected_file(path: Path) -> bool:
    normalized = str(path).replace("\\", "/")
    return any(hint in normalized for hint in PROTECTED_FILE_HINTS)

def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        return path.read_text(encoding="utf-8", errors="ignore")

def collect_files():
    files = []
    for path in APP_ROOT.rglob("*"):
        if not path.is_file():
            continue
        if is_excluded(path):
            continue
        if path.suffix not in SOURCE_EXTENSIONS:
            continue
        files.append(path)
    return sorted(files)

def parse_selector(signature: str) -> str:
    signature = signature.split("{", 1)[0].strip()
    parts = re.findall(r"([A-Za-z_]\w*)\s*:", signature)
    if parts:
        return "".join(f"{item}:" for item in parts)
    match = re.match(r"([A-Za-z_]\w*)", signature)
    return match.group(1) if match else ""

def extract_methods(content: str):
    methods = []
    method_re = re.compile(r"^[ \t]*[+-]\s*\([^)]*\)\s*([^{;\n]+)", re.MULTILINE)
    for match in method_re.finditer(content):
        raw_signature = match.group(1).strip()
        selector = parse_selector(raw_signature)
        if selector:
            methods.append((selector, match.start()))
    return methods

def should_skip_selector(selector: str) -> bool:
    if selector in SYSTEM_SELECTORS:
        return True
    return any(selector.startswith(prefix) for prefix in SYSTEM_SELECTOR_PREFIXES)

def search_occurrence_files(name_re: re.Pattern, file_texts):
    hits = set()
    for path, text in file_texts.items():
        if name_re.search(text):
            hits.add(path)
    return hits

def collect_router_registrations(file_texts):
    class_to_protocols = defaultdict(set)
    protocol_to_classes = defaultdict(set)
    for path, text in file_texts.items():
        impl_match = re.search(r"@implementation\s+([A-Za-z_]\w*)", text)
        owner = impl_match.group(1) if impl_match else None
        for match in ROUTER_REGISTER_RE.finditer(text):
            protocol = match.group("protocol")
            impl = owner if match.group("impl") == "self" and owner else match.group("impl")
            if not impl:
                continue
            class_to_protocols[impl].add(protocol)
            protocol_to_classes[protocol].add(impl)
    return class_to_protocols, protocol_to_classes

def collect_router_usage_hits(file_texts):
    protocol_hits = defaultdict(set)
    for path, text in file_texts.items():
        for match in ROUTER_USAGE_RE.finditer(text):
            protocol_hits[match.group("protocol")].add(path)
    return protocol_hits

def collect_target_action_usage(file_texts):
    class_to_actions = defaultdict(set)
    class_to_usage_files = defaultdict(set)
    patterns = (TARGET_ACTION_CALL_RE, NAVIGATOR_ALLOWED_ROUTE_RE, NAVIGATOR_URL_CALL_RE)
    for path, text in file_texts.items():
        for pattern in patterns:
            for match in pattern.finditer(text):
                target_class = f"Target_{match.group('target')}"
                selector = f"Action_{match.group('action')}:"
                class_to_actions[target_class].add(selector)
                class_to_usage_files[target_class].add(path)
    return class_to_actions, class_to_usage_files

def strip_method_declarations(text: str) -> str:
    return METHOD_DECLARATION_BLOCK_RE.sub("", text)

def build_selector_usage_regex(selector: str):
    if ":" in selector:
        first_piece = selector.split(":")[0]
        return re.compile(rf"@selector\s*\(\s*{re.escape(selector)}\s*\)|\[\s*[^\]]+\s+{re.escape(first_piece)}\s*:\s*|\b{re.escape(first_piece)}\s*:")
    return re.compile(rf"@selector\s*\(\s*{re.escape(selector)}\s*\)|\[\s*[^\]]+\s+{re.escape(selector)}\b|\.\s*{re.escape(selector)}\b")

def main():
    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    files = collect_files()
    file_texts = {path: read_text(path) for path in files}
    search_texts = {path: strip_method_declarations(text) for path, text in file_texts.items()}
    class_to_router_protocols, protocol_to_router_classes = collect_router_registrations(file_texts)
    protocol_usage_hits = collect_router_usage_hits(file_texts)
    class_to_target_actions, class_to_target_usage_files = collect_target_action_usage(file_texts)

    dynamic_risk_hits = []
    risky_files = set()

    for path, text in file_texts.items():
        for idx, line in enumerate(text.splitlines(), start=1):
            if HIGH_RISK_PATTERN.search(line):
                dynamic_risk_hits.append(f"{path}:{idx}: {line.strip()}")
                risky_files.add(path)

    (REPORT_DIR / "oc_dynamic_risk_hits.txt").write_text(
        "\n".join(dynamic_risk_hits) + ("\n" if dynamic_risk_hits else ""),
        encoding="utf-8",
    )

    interface_files = defaultdict(set)
    implementation_files = defaultdict(set)

    for path, text in file_texts.items():
        if path.suffix not in {".h", ".m", ".mm"}:
            continue
        for cls in re.findall(r"@interface\s+([A-Za-z_]\w*)", text):
            interface_files[cls].add(path)
        for cls in re.findall(r"@implementation\s+([A-Za-z_]\w*)", text):
            implementation_files[cls].add(path)

    high_confidence_class_candidates = []
    review_class_candidates = []
    runtime_unreachable_class_candidates = []

    all_classes = sorted(set(interface_files) | set(implementation_files))
    for cls in all_classes:
        own_files = interface_files[cls] | implementation_files[cls]
        if not own_files:
            continue
        if cls in class_to_target_usage_files:
            review_class_candidates.append(
                f"{cls}\n  own_files: {', '.join(sorted(str(p) for p in own_files))}\n  target_actions: {', '.join(sorted(class_to_target_actions[cls]))}\n  target_usage_hits: {len(class_to_target_usage_files[cls])}\n  hit_files: {', '.join(sorted(str(p) for p in class_to_target_usage_files[cls])[:8])}\n"
            )
            continue
        if PROTECTED_CLASS_RE.match(cls):
            continue
        if any(is_protected_file(f) for f in own_files):
            continue
        if any(f in risky_files for f in own_files):
            continue

        registered_protocols = sorted(class_to_router_protocols.get(cls, set()))
        router_usage_files = sorted({
            str(path)
            for proto in registered_protocols
            for path in protocol_usage_hits.get(proto, set())
        })
        if registered_protocols and router_usage_files:
            review_class_candidates.append(
                f"{cls}\n  own_files: {', '.join(sorted(str(p) for p in own_files))}\n  router_protocols: {', '.join(registered_protocols)}\n  router_usage_hits: {len(router_usage_files)}\n  hit_files: {', '.join(router_usage_files[:8])}\n"
            )
            continue

        name_re = re.compile(rf"\b{re.escape(cls)}\b")
        hit_files = search_occurrence_files(name_re, file_texts)

        external_hits = sorted(str(p) for p in hit_files if p not in own_files)
        own_list = sorted(str(p) for p in own_files)

        if not external_hits:
            candidate_text = (
                f"{cls}\n  own_files: {', '.join(own_list)}\n  external_hits: 0\n"
            )
            high_confidence_class_candidates.append(candidate_text)
            runtime_unreachable_class_candidates.append(
                candidate_text.rstrip() + "  heuristic: no router/target-action/dynamic-risk/external-hit found\n"
            )
        else:
            review_class_candidates.append(
                f"{cls}\n  own_files: {', '.join(own_list)}\n  external_hits: {len(external_hits)}\n  hit_files: {', '.join(external_hits[:8])}\n"
            )

    (REPORT_DIR / "oc_class_candidates_high_confidence.txt").write_text(
        "\n".join(high_confidence_class_candidates),
        encoding="utf-8",
    )
    (REPORT_DIR / "oc_class_candidates_review.txt").write_text(
        "\n".join(review_class_candidates),
        encoding="utf-8",
    )
    (REPORT_DIR / "oc_runtime_unreachable_classes.txt").write_text(
        "\n".join(runtime_unreachable_class_candidates),
        encoding="utf-8",
    )

    router_registered_lines = []
    for protocol in sorted(protocol_to_router_classes):
        impls = sorted(protocol_to_router_classes[protocol])
        usage_files = sorted(str(path) for path in protocol_usage_hits.get(protocol, set()))
        router_registered_lines.append(
            f"{protocol}\n  impls: {', '.join(impls)}\n  usage_hits: {len(usage_files)}\n  hit_files: {', '.join(usage_files[:8])}\n"
        )
    (REPORT_DIR / "oc_router_registered_services.txt").write_text(
        "\n".join(router_registered_lines),
        encoding="utf-8",
    )

    target_action_lines = []
    for cls in sorted(class_to_target_actions):
        usage_files = sorted(str(path) for path in class_to_target_usage_files[cls])
        target_action_lines.append(
            f"{cls}\n  actions: {', '.join(sorted(class_to_target_actions[cls]))}\n  usage_hits: {len(usage_files)}\n  hit_files: {', '.join(usage_files[:8])}\n"
        )
    (REPORT_DIR / "oc_target_action_routes.txt").write_text(
        "\n".join(target_action_lines),
        encoding="utf-8",
    )

    method_candidates = []
    runtime_unreachable_method_candidates = []
    for path, text in file_texts.items():
        if path.suffix not in {".m", ".mm"}:
            continue
        if is_protected_file(path) or path in risky_files:
            continue

        impl_match = re.search(r"@implementation\s+([A-Za-z_]\w*)", text)
        owner = impl_match.group(1) if impl_match else path.stem
        if PROTECTED_CLASS_RE.match(owner):
            continue
        if owner in class_to_router_protocols:
            continue

        sibling_header = path.with_suffix(".h")
        sibling_text = file_texts.get(sibling_header, "")

        for selector, _ in extract_methods(text):
            if should_skip_selector(selector) or selector in IGNORED_METHOD_SELECTORS:
                continue
            if ":" not in selector and len(selector) < 8:
                continue

            selector_re = build_selector_usage_regex(selector)
            usage_hits = []
            for candidate_path, candidate_text in search_texts.items():
                if candidate_path == sibling_header and selector in sibling_text:
                    continue
                if selector_re.search(candidate_text):
                    usage_hits.append(str(candidate_path))

            if not usage_hits:
                candidate_text = (
                    f"{owner} -> {selector}\n  file: {path}\n  heuristic: no usage hit found after stripping declarations\n"
                )
                method_candidates.append(candidate_text)
                runtime_unreachable_method_candidates.append(
                    candidate_text.rstrip() + "  runtime_filter: selector is not a known system callback and file has no dynamic-risk marker\n"
                )

    (REPORT_DIR / "oc_method_candidates.txt").write_text(
        "\n".join(method_candidates),
        encoding="utf-8",
    )
    (REPORT_DIR / "oc_runtime_unreachable_methods.txt").write_text(
        "\n".join(runtime_unreachable_method_candidates),
        encoding="utf-8",
    )

    summary = "\n".join([
        f"project_root: {PROJECT_ROOT}",
        f"app_root: {APP_ROOT}",
        f"scanned_file_count: {len(files)}",
        f"dynamic_risk_hits: {REPORT_DIR / 'oc_dynamic_risk_hits.txt'}",
        f"class_candidates_high_confidence: {REPORT_DIR / 'oc_class_candidates_high_confidence.txt'}",
        f"class_candidates_review: {REPORT_DIR / 'oc_class_candidates_review.txt'}",
        f"runtime_unreachable_classes: {REPORT_DIR / 'oc_runtime_unreachable_classes.txt'}",
        f"router_registered_services: {REPORT_DIR / 'oc_router_registered_services.txt'}",
        f"target_action_routes: {REPORT_DIR / 'oc_target_action_routes.txt'}",
        f"method_candidates: {REPORT_DIR / 'oc_method_candidates.txt'}",
        f"runtime_unreachable_methods: {REPORT_DIR / 'oc_runtime_unreachable_methods.txt'}",
        "warning: Objective-C output is candidate-only; verify router/notification/KVC/KVO/system callback paths before deletion",
        "project_specific_protection: Router/Navigator/TargetActor/AppDelegate/SceneDelegate/main.m are excluded from direct candidate output",
    ]) + "\n"

    (REPORT_DIR / "summary.txt").write_text(summary, encoding="utf-8")
    print(f"[oc-dead-code] Summary written to: {REPORT_DIR / 'summary.txt'}")

if __name__ == "__main__":
    main()