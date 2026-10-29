#!/usr/bin/env python3
"""Exercise the generated HTML in Chromium via the optional agent-browser CLI.

Run `moon build --target native`, then `python3 scripts/verify_html.py`.
Screenshots and the tested HTML stay under _build/qa-v012/.
"""
from pathlib import Path
import json
import os
import subprocess

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "_build/qa-v012"
SESSION = "moontrace-release-qa"


def browser(*args, script=None):
    result = subprocess.run(["agent-browser", "--session", SESSION, "--json", *args],
                            input=script, text=True, capture_output=True, timeout=45)
    assert result.returncode == 0, result.stdout + result.stderr
    data = json.loads(result.stdout)
    assert data["success"], data
    return data.get("data", {})


def evaluate(script):
    return browser("eval", "--stdin", script=script)["result"]


def main():
    store = OUT / "browser-traces"
    store.mkdir(parents=True, exist_ok=True)

    def span(id, name, status, parent=None, start=1000, end=1100):
        return dict(id=id, trace_id="qa_fixture", name=name, parent_id=parent,
                    start_time_ms=start, end_time_ms=end, duration_ms=end-start,
                    input="input", output="result", status=status, metadata={}, events=[])

    spans = {
        "root": span("root", "Agent root", "Ok"),
        "search": span("search", "tool.search", "Ok", "root", 1010, 1040),
        "error": span("error", "waste' test' onmouseover='window.pwned=true' data-x='", "Error", "root", 1020, 1080),
        "other": span("other", "parallel root", "Ok", None, 1000, 1050),
    }
    spans["search"]["metadata"] = {"needle": "unique-search-token"}
    spans["error"].update(error_message="provider timeout", metadata={
        "owner": "error-owner", "payload": "<test> <svg onload='window.pwned=true'> & &"})
    fixture = dict(id="qa_fixture", root_span_id="root", start_time_ms=1000,
                   end_time_ms=1100, spans=spans)
    (store / "qa_fixture.json").write_text(json.dumps(fixture))
    env = dict(os.environ, MOONTRACE_DIR=str(store))
    cli = ROOT / "_build/native/debug/build/src/cli/cli.exe"
    (OUT / "trace.html").unlink(missing_ok=True)
    subprocess.run([str(cli), "export", "qa_fixture", str(OUT / "trace.html")], env=env, check=True)
    assert (OUT / "trace.html").is_file(), "export did not create a new HTML file"
    browser("open", (OUT / "trace.html").as_uri())
    assert evaluate("document.querySelectorAll('.span-node').length") == 4
    assert not evaluate("!!window.pwned || !!document.querySelector('svg,[onmouseover]')")
    assert evaluate("[...document.querySelectorAll('.stat-value')].map(n=>n.textContent)") == ["4", "1", "100ms", "240ms"]
    browser("click", '[data-span-id="root"]>.span-header')
    browser("fill", "#trace-search", "error-owner")
    browser("select", "#trace-status", "error")
    state = evaluate("({count:document.getElementById('filter-count').textContent,tree:[...document.querySelectorAll('.span-node:not(.filtered)')].map(n=>n.dataset.spanId),timeline:[...document.querySelectorAll('.timeline-row:not(.filtered)')].map(n=>n.dataset.spanId),body:getComputedStyle(document.querySelector('[data-span-id=error]>.span-body')).display})")
    assert state == dict(count="1 / 4 matching spans", tree=["root", "error"], timeline=["error"], body="block"), state
    browser("fill", "#trace-search", "unique-search-token")
    assert evaluate("document.querySelectorAll('.span-node:not(.filtered),.timeline-row:not(.filtered)').length") == 0
    assert not evaluate("document.getElementById('no-matches').hidden")
    browser("fill", "#trace-search", "")
    browser("select", "#trace-status", "all")
    assert evaluate("getComputedStyle(document.querySelector('[data-span-id=root]>.span-body')).display") == "none"
    # Keyboard operation should restore the tree as well as pointer clicks.
    browser("focus", '[data-span-id="root"]>.span-header')
    browser("press", "Enter")
    assert evaluate("document.querySelector('[data-span-id=root]>.span-header').getAttribute('aria-expanded')") == "true"
    for width, height, name in [(1440, 1000, "desktop"), (390, 844, "mobile"), (320, 740, "small")]:
        browser("set", "viewport", str(width), str(height))
        assert not evaluate("document.documentElement.scrollWidth>innerWidth"), f"horizontal overflow at {width}px"
        browser("screenshot", str(OUT / f"{name}.png"), "--full")
    print("PASS: own-span search/status conjunction; ancestor context; timeline linkage; "
          "empty/reset states; collapse restoration; keyboard toggle; escaped payloads; 1440/390/320px layouts")
    print(f"HTML and screenshots: {OUT}")


if __name__ == "__main__":
    main()
