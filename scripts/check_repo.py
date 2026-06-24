#!/usr/bin/env python3
"""Fast, dependency-free Milestone 0 repository checks."""
from __future__ import annotations
import argparse, re, subprocess, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DOCS = ('architecture.md','scope.md','interface_audit.md','reuse_plan.md','module_hierarchy.md','memory_map.md','cache_architecture.md','coherence_protocol.md','bus_protocol.md','lr_sc.md','boot_and_runtime.md','verification_plan.md','performance_plan.md','build_roadmap.md','source_manifest.md','risks_and_open_questions.md')
DIRS = ('rtl/core','rtl/cache','rtl/coherence','rtl/interconnect','rtl/memory','rtl/atomic','rtl/top','rtl/include','tb/unit','tb/coherence','tb/system','tb/assertions','tb/models','tb/common','sw/runtime','sw/linker','sw/tests','sw/workloads','scripts','config','constraints','reports','third_party','docs/architecture_decisions')
LINK = re.compile(r'(?<!!)\[[^]]+\]\(([^)#?]+)')
def tracked():
    p=subprocess.run(['git','ls-files'],cwd=ROOT,text=True,capture_output=True,check=True); return p.stdout.splitlines()
def errors(docs_only=False):
    e=[]
    for f in DOCS:
        if not (ROOT/'docs'/f).is_file(): e.append('missing document: docs/'+f)
    if not docs_only:
        for d in DIRS:
            if not (ROOT/d).is_dir(): e.append('missing directory: '+d)
        for f in ('README.md','AGENTS.md','Makefile','.gitignore','scripts/check_repo.py','scripts/check_milestone.py','scripts/run_milestone.sh','milestones/current.md','milestones/templates/milestone_template.md'):
            if not (ROOT/f).is_file(): e.append('missing file: '+f)
        gitignore=(ROOT/'.gitignore').read_text(encoding='utf-8') if (ROOT/'.gitignore').exists() else ''
        for pattern in ('.codex_runs/', 'reports/current_milestone_report.md'):
            if pattern not in gitignore: e.append('local runner artifact is not ignored: '+pattern)
    for p in ROOT.rglob('*.md'):
        if '.git' in p.parts: continue
        text=p.read_text(encoding='utf-8')
        if p.relative_to(ROOT).as_posix() != 'docs/risks_and_open_questions.md' and re.search(r'\b(TODO|TBD|FIXME)\b',text): e.append('placeholder marker: '+str(p.relative_to(ROOT)))
        for target in LINK.findall(text):
            if '://' not in target and not (p.parent/target).resolve().exists(): e.append('broken link: '+str(p.relative_to(ROOT))+' -> '+target)
    for f in tracked():
        p=ROOT/f
        if p.name=='.DS_Store' or '__pycache__' in p.parts or p.suffix.lower() in {'.vcd','.fst','.wlf','.elf','.hex','.mem','.bin'}: e.append('forbidden tracked artifact: '+f)
        if p.is_file() and p.stat().st_size > 2_000_000: e.append('large tracked artifact: '+f)
        if p.is_dir() and (p/'.git').exists(): e.append('nested repository: '+f)
    for p in ROOT.rglob('.git'):
        if p.parent != ROOT: e.append('nested repository: '+str(p.parent.relative_to(ROOT)))
    manifest=(ROOT/'docs/source_manifest.md').read_text(encoding='utf-8') if (ROOT/'docs/source_manifest.md').exists() else ''
    for d in ('rtl/','tb/','sw/','reports/'):
        if d not in manifest: e.append('source manifest missing category: '+d)
    return e
def main():
    a=argparse.ArgumentParser(); a.add_argument('--docs-only',action='store_true'); a.add_argument('--tree',action='store_true'); ns=a.parse_args()
    if ns.tree:
        for p in sorted(x.relative_to(ROOT) for x in ROOT.iterdir() if x.name!='.git'): print(p)
        return 0
    e=errors(ns.docs_only)
    if e: print('\n'.join(e)); return 1
    print('repository checks: passed'); return 0
if __name__=='__main__': sys.exit(main())
