#!/usr/bin/env python3
"""Offline integration checks. Run after `moon build --target native`.

Python is a development/CI dependency only, never a MoonTrace runtime dependency.
"""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import json
import os
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / "_build/native/debug/build"
AGENT = BUILD / "examples/research_agent/research_agent.exe"
CLI = BUILD / "src/cli/cli.exe"


def execute(program, env, *args, expected=0):
    result = subprocess.run([str(program), *args], env=env, text=True,
                            capture_output=True, timeout=45)
    assert result.returncode == expected, result.stdout + result.stderr
    return result.stdout


def main():
    with tempfile.TemporaryDirectory(prefix="moontrace-integration-") as directory:
        store = Path(directory) / "nested" / "traces"
        env = dict(os.environ, MOONTRACE_DIR=str(store))
        # A fresh process must not restart trace IDs or lose another writer's index.
        with ThreadPoolExecutor(max_workers=8) as pool:
            outputs = list(pool.map(lambda _: execute(AGENT, env), range(16)))
        ids = [line.split()[2] for output in outputs for line in output.splitlines()
               if line.startswith("Trace saved:")]
        assert len(ids) == len(set(ids)) == 48
        files = list(store.glob("trace_*.json"))
        traces = [json.loads(path.read_text()) for path in files]
        assert len(traces) == 48
        assert all(t["start_time_ms"] > 1_700_000_000_000 for t in traces)
        assert all(t["id"] in ids and len(t["spans"]) == 6 for t in traces)
        assert all(isinstance(t["root_span_id"], str) for t in traces)
        assert set(execute(CLI, env, "ids").splitlines()) == set(ids)
        assert not list(store.glob("*.tmp-*"))
        (store / "index.json").write_text("{corrupt index")
        listing = execute(CLI, env, "list")
        assert all(id in listing for id in ids)
        assert "Recovered 48 traces" in execute(CLI, env, "repair")
        assert len(json.loads((store / "index.json").read_text())) == 48
        assert all(isinstance(s["start_time_ms"], int) and isinstance(s["root_span_name"], str)
                   for s in json.loads((store / "index.json").read_text()))
        ok = [t for t in traces if all(s["status"] == "Ok" for s in t["spans"].values())]
        failed = [t for t in traces if any(s["status"] == "Error" for s in t["spans"].values())]
        execute(CLI, env, "regress", ok[0]["id"], ok[1]["id"])
        execute(CLI, env, "regress", ok[0]["id"], ok[1]["id"], "--check-output")
        execute(CLI, env, "regress", ok[0]["id"], failed[0]["id"], expected=1)
        execute(CLI, env, "regress", ok[0]["id"], "missing", expected=2)
        execute(CLI, env, "export", failed[0]["id"], str(Path(directory) / "trace.html"))
        html = (Path(directory) / "trace.html").read_text()
        assert "Metadata" in html and "Events" in html and "filterTrace" in html
        assert "Elapsed duration" in html and "Cumulative span time" in html
        execute(BUILD / "examples/replay_agent/replay_agent.exe", env)
        execute(BUILD / "examples/concurrent_agent/concurrent_agent.exe", env)
        assert len(list(store.glob("trace_*.json"))) == 52
        print("PASS: 16 processes / 48 unique snapshots; corrupt-index recovery; "
              "regression exit codes; HTML export; offline replay; concurrent Agent sessions")


if __name__ == "__main__":
    main()
