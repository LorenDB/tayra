// Implement one (or more, sequentially) unfinished Tayra web migration
// features from implement-for-web.md. Each feature is built in its own
// git worktree under the primary Tayra repo so agent work stays isolated.
//
// Args (all optional):
//   repo_path      — primary Tayra git root (default: /home/loren/code/tayra)
//   features_file  — backlog markdown relative to repo_path (default: implement-for-web.md)
//   feature_index  — 0-based index into the backlog table (overrides "next pending")
//   feature_name   — substring match on the Feature column (overrides index if both set)
//   count          — how many features to implement this run (default: 1)
//   dry_run        — if true, select + plan only; do not implement
//
// After each feature the run pauses for human review before the next one
// (when count > 1). Results include the worktree path and branch so you can
// merge or open a PR manually.

let meta = #{
    name: "implement-web-feature",
    description: "Implement the next unimplemented Tayra-for-Funkwhale web feature from implement-for-web.md, one at a time, in a dedicated git worktree",
    when_to_use: "Continuing the Tayra Flutter frontend migration; backlog lives in implement-for-web.md",
    phases: [
        #{ title: "Select", detail: "Pick the next pending feature from the backlog" },
        #{ title: "Plan", detail: "Map Funkwhale surface to Tayra APIs and UI patterns" },
        #{ title: "Implement", detail: "Build the feature in an isolated git worktree" },
        #{ title: "Verify", detail: "Analyze and adversarially review the worktree" },
    ],
};

let selection_schema = #{
    "type": "object",
    "required": ["status", "feature_name", "feature_index", "slug", "where_in_funkwhale", "notes", "is_flutter_work", "rationale"],
    "properties": #{
        "status": #{ "type": "string", "enum": ["selected", "all_done", "not_found"] },
        "feature_name": #{ "type": "string" },
        "feature_index": #{ "type": "integer" },
        "slug": #{ "type": "string" },
        "where_in_funkwhale": #{ "type": "string" },
        "notes": #{ "type": "string" },
        "is_flutter_work": #{ "type": "boolean" },
        "rationale": #{ "type": "string" },
    },
};

let plan_schema = #{
    "type": "object",
    "required": ["summary", "files_to_touch", "api_endpoints", "acceptance_criteria", "risks"],
    "properties": #{
        "summary": #{ "type": "string" },
        "files_to_touch": #{ "type": "array", "items": #{ "type": "string" }, "maxItems": 30 },
        "api_endpoints": #{ "type": "array", "items": #{ "type": "string" }, "maxItems": 20 },
        "acceptance_criteria": #{ "type": "array", "items": #{ "type": "string" }, "maxItems": 12 },
        "risks": #{ "type": "array", "items": #{ "type": "string" }, "maxItems": 8 },
    },
};

let implement_schema = #{
    "type": "object",
    "required": [
        "success", "worktree_path", "branch", "commit_sha", "summary",
        "files_changed", "analyze_ok", "tests_ok", "skipped", "skip_reason"
    ],
    "properties": #{
        "success": #{ "type": "boolean" },
        "worktree_path": #{ "type": "string" },
        "branch": #{ "type": "string" },
        "commit_sha": #{ "type": "string" },
        "summary": #{ "type": "string" },
        "files_changed": #{ "type": "array", "items": #{ "type": "string" }, "maxItems": 40 },
        "analyze_ok": #{ "type": "boolean" },
        "tests_ok": #{ "type": "boolean" },
        "skipped": #{ "type": "boolean" },
        "skip_reason": #{ "type": "string" },
    },
};

let verify_schema = #{
    "type": "object",
    "required": ["approved", "issues", "evidence", "missing_acceptance"],
    "properties": #{
        "approved": #{ "type": "boolean" },
        "issues": #{ "type": "array", "items": #{ "type": "string" }, "maxItems": 12 },
        "evidence": #{ "type": "string" },
        "missing_acceptance": #{ "type": "array", "items": #{ "type": "string" }, "maxItems": 12 },
    },
};

// ── Args ────────────────────────────────────────────────────────────────

let repo_path = "/home/loren/code/tayra";
let features_file = "implement-for-web.md";
let count = 1;
let dry_run = false;
let want_index = ();
let want_name = ();

if args != () {
    if args.repo_path != () && args.repo_path != "" {
        repo_path = args.repo_path;
    }
    if args.features_file != () && args.features_file != "" {
        features_file = args.features_file;
    }
    if args.count != () {
        count = args.count;
    }
    if args.dry_run != () {
        dry_run = args.dry_run;
    }
    if args.feature_index != () {
        want_index = args.feature_index;
    }
    if args.feature_name != () && args.feature_name != "" {
        want_name = args.feature_name;
    }
}

if count < 1 { count = 1; }
if count > 5 {
    pause("verification", "args.count is capped at 5 per run to keep agent budget safe; pass a smaller count.");
}

let features_path = repo_path + "/" + features_file;
let results = [];
let n = 0;

while n < count {
    // ── Select ──────────────────────────────────────────────────────────
    phase("Select");
    log("Selecting feature " + (n + 1).to_string() + "/" + count.to_string() + " from " + features_path);

    let select_prompt = "";
    select_prompt += "You are selecting the next unfinished web-migration feature for the Tayra Flutter app.\n";
    select_prompt += "PRIMARY TAYRA REPO: " + repo_path + "\n";
    select_prompt += "BACKLOG FILE (absolute): " + features_path + "\n\n";
    select_prompt += "REQUIRED TOOL USE:\n";
    select_prompt += "1. Read the backlog file with read_file (absolute path above). Do not invent the list.\n";
    select_prompt += "2. Parse the markdown table of features in document order (top to bottom).\n";
    select_prompt += "3. A feature is DONE if its Feature cell is struck through, starts with DONE/✅, or the row is under a Completed section.\n";
    select_prompt += "4. Otherwise it is PENDING.\n\n";
    select_prompt += "SELECTION RULES (apply in order):\n";
    if want_name != () {
        select_prompt += "- User requested feature_name substring: " + want_name + " — select the first matching PENDING row (case-insensitive).\n";
        select_prompt += "  If none match, status=not_found.\n";
    } else if want_index != () {
        select_prompt += "- User requested feature_index=" + want_index.to_string() + " (0-based among ALL table rows, including done).\n";
        select_prompt += "  If out of range, status=not_found. Prefer that row even if already done (report is_flutter_work accordingly).\n";
    } else {
        select_prompt += "- Select the first PENDING row from the top of the table.\n";
        select_prompt += "- If every row is done, status=all_done with empty feature_name.\n";
    }
    select_prompt += "\nFor the selected feature:\n";
    select_prompt += "- feature_index: 0-based index in the full table (not only pending).\n";
    select_prompt += "- slug: lowercase kebab-case short id derived from the name (e.g. web-splash, library-admin).\n";
    select_prompt += "- is_flutter_work: true if this needs Flutter/Dart/web client code in Tayra.\n";
    select_prompt += "  false only when the backlog explicitly says it stays on Django/allauth/CLI with no Flutter UI needed\n";
    select_prompt += "  (e.g. third-party OAuth authorize still served by allauth). Still SELECT it if it is first pending;\n";
    select_prompt += "  the implement phase may mark it done with a docs-only note rather than UI.\n";
    select_prompt += "- rationale: one sentence why this row was chosen.\n";
    select_prompt += "Return ONLY the structured object matching the schema.\n";

    let sel = agent(select_prompt, #{
        label: "select-" + n.to_string(),
        capability_mode: "read-only",
        output_schema: selection_schema,
    });

    if sel == () || !sel.success || sel.output == () {
        // pause is terminal for this condition (resume re-fires); start a new run to retry.
        pause("infra", "Feature selection agent failed. Start a new run to retry, or pass args.feature_name / args.feature_index.");
    }

    let s = sel.output;
    if s.status == "all_done" {
        log("Backlog is empty — all features marked done.");
        complete(#{
            summary: "All features in implement-for-web.md are already done.",
            results: results,
        });
    }
    if s.status == "not_found" {
        pause("verification", "Requested feature was not found in the backlog. Adjust args.feature_name or args.feature_index and start a new run.");
    }

    log("Selected: [" + s.feature_index.to_string() + "] " + s.feature_name + " (slug=" + s.slug + ")");

    // Clear explicit pick after first feature so subsequent iterations take next pending
    want_index = ();
    want_name = ();

    // ── Plan ────────────────────────────────────────────────────────────
    phase("Plan");

    let plan_prompt = "";
    plan_prompt += "Plan a minimal, production-quality implementation of ONE Tayra web-migration feature.\n\n";
    plan_prompt += "FEATURE: " + s.feature_name + "\n";
    plan_prompt += "WHERE IN FUNKWHALE: " + s.where_in_funkwhale + "\n";
    plan_prompt += "NOTES: " + s.notes + "\n";
    plan_prompt += "IS_FLUTTER_WORK: " + s.is_flutter_work.to_string() + "\n";
    plan_prompt += "PRIMARY TAYRA REPO: " + repo_path + "\n";
    plan_prompt += "FUNKWHALE-TAYRA monorepo (API reference / Vue remnants / nginx): /home/loren/code/funkwhale-tayra\n\n";
    plan_prompt += "REQUIRED RESEARCH (use tools; do not answer from memory):\n";
    plan_prompt += "1. Read " + repo_path + "/AGENTS.md for code style (package imports only, Riverpod, AppTheme, go_router).\n";
    plan_prompt += "2. Explore existing patterns under " + repo_path + "/lib/ (router, auth, screens, API client).\n";
    plan_prompt += "3. Check " + repo_path + "/schema.yml for relevant API endpoints.\n";
    plan_prompt += "4. If useful, search /home/loren/code/funkwhale-tayra for related server routes or old Vue manage views.\n";
    plan_prompt += "5. Read " + features_path + " row context and " + repo_path + "/doc/web-deferred-features.md if present.\n\n";
    plan_prompt += "PLANNING RULES:\n";
    plan_prompt += "- Prefer the smallest change that delivers the user-visible feature on web (and native if natural).\n";
    plan_prompt += "- Match existing Tayra patterns (features/*_screen.dart, providers, AppTheme, go_router routes).\n";
    plan_prompt += "- For pure HTML/bootstrap web loading UX (e.g. WASM splash), web/index.html is in scope.\n";
    plan_prompt += "- For admin surfaces, gate on staff/permissions if the API exposes them; do not invent auth bypasses.\n";
    plan_prompt += "- If is_flutter_work is false, plan a docs-only completion: mark backlog done + short note in web-deferred-features if needed.\n";
    plan_prompt += "- List concrete files_to_touch (absolute or repo-relative), API endpoints, acceptance criteria, and risks.\n";
    plan_prompt += "Return the structured plan object.\n";

    let plan_res = agent(plan_prompt, #{
        label: "plan-" + s.slug,
        capability_mode: "read-only",
        output_schema: plan_schema,
    });

    if plan_res == () || !plan_res.success || plan_res.output == () {
        pause("infra", "Planning agent failed for " + s.feature_name + ". Start a new run to retry.");
    }

    let plan = plan_res.output;
    log("Plan: " + plan.summary);

    if dry_run {
        log("dry_run=true — skipping implement/verify for " + s.feature_name);
        results.push(#{
            feature: s.feature_name,
            slug: s.slug,
            dry_run: true,
            plan: plan,
        });
        n += 1;
        if n < count {
            await_user("user", "Dry-run planned " + s.feature_name + ". Resume for the next feature, or stop.");
        }
        continue;
    }

    // ── Implement (own git worktree) ────────────────────────────────────
    phase("Implement");

    let impl_prompt = "";
    impl_prompt += "Implement ONE feature for the Tayra Flutter app (Funkwhale web frontend migration).\n\n";
    impl_prompt += "FEATURE: " + s.feature_name + "\n";
    impl_prompt += "SLUG: " + s.slug + "\n";
    impl_prompt += "WHERE IN FUNKWHALE: " + s.where_in_funkwhale + "\n";
    impl_prompt += "NOTES: " + s.notes + "\n";
    impl_prompt += "IS_FLUTTER_WORK: " + s.is_flutter_work.to_string() + "\n";
    impl_prompt += "PRIMARY TAYRA REPO: " + repo_path + "\n";
    impl_prompt += "BACKLOG FILE: " + features_path + "\n\n";
    impl_prompt += "PLAN SUMMARY: " + plan.summary + "\n";
    impl_prompt += "ACCEPTANCE CRITERIA:\n";
    if plan.acceptance_criteria != () {
        for c in plan.acceptance_criteria {
            impl_prompt += "- " + c + "\n";
        }
    }
    impl_prompt += "SUGGESTED FILES:\n";
    if plan.files_to_touch != () {
        for f in plan.files_to_touch {
            impl_prompt += "- " + f + "\n";
        }
    }
    impl_prompt += "\n═══ GIT WORKTREE (MANDATORY) ═══\n";
    impl_prompt += "All edits MUST happen inside a dedicated git worktree of the primary Tayra repo.\n";
    impl_prompt += "Do NOT modify " + repo_path + " working tree directly, and do NOT edit\n";
    impl_prompt += "/home/loren/code/funkwhale-tayra/tayra (submodule) for this task.\n\n";
    impl_prompt += "Setup (run via shell):\n";
    impl_prompt += "1. SLUG=" + s.slug + "\n";
    impl_prompt += "2. WT=/home/loren/code/tayra-wt-" + s.slug + "\n";
    impl_prompt += "3. BRANCH=feature/web-" + s.slug + "\n";
    impl_prompt += "4. If WT already exists: reuse it (git -C WT status). If branch exists, check it out in WT.\n";
    impl_prompt += "5. Else create:\n";
    impl_prompt += "   git -C " + repo_path + " fetch origin 2>/dev/null || true\n";
    impl_prompt += "   git -C " + repo_path + " worktree add -b feature/web-" + s.slug + " /home/loren/code/tayra-wt-" + s.slug + " HEAD\n";
    impl_prompt += "6. Confirm with: git -C $WT rev-parse --show-toplevel && git -C $WT branch --show-current\n\n";
    impl_prompt += "═══ IMPLEMENTATION ═══\n";
    impl_prompt += "Work ONLY under the worktree path. Follow " + repo_path + "/AGENTS.md (also present in WT):\n";
    impl_prompt += "- package:tayra/... imports only (never relative)\n";
    impl_prompt += "- Riverpod providers, go_router routes, AppTheme constants\n";
    impl_prompt += "- File naming *_screen.dart / *_provider.dart; section dividers\n";
    impl_prompt += "- Hand-written models in lib/core/api/models.dart when needed\n";
    impl_prompt += "- Match existing screen/provider style in lib/features/\n\n";
    impl_prompt += "If is_flutter_work is false: do NOT build UI. Update the backlog to mark the feature DONE\n";
    impl_prompt += "with a short note that it remains server-side, and optionally align doc/web-deferred-features.md.\n";
    impl_prompt += "Commit that docs-only change on the feature branch.\n\n";
    impl_prompt += "If is_flutter_work is true: implement the feature fully enough to meet acceptance criteria.\n";
    impl_prompt += "Wire routes, navigation entry points (settings/menu) if users need to reach it, and API calls.\n";
    impl_prompt += "Update " + features_file + " in the worktree: mark this feature DONE (prefix Feature cell with ✅ or strike-through)\n";
    impl_prompt += "so the next workflow run skips it.\n\n";
    impl_prompt += "QUALITY GATES (run in worktree):\n";
    impl_prompt += "  dart format lib/ test/ 2>/dev/null || dart format lib/\n";
    impl_prompt += "  flutter analyze\n";
    impl_prompt += "  flutter test   # if you added tests; otherwise run existing tests if feasible\n\n";
    impl_prompt += "COMMIT on the feature branch in the worktree (not master):\n";
    impl_prompt += "  git add -A && git commit -m \"feat(web): " + s.feature_name + "\"\n";
    impl_prompt += "Do NOT push, force-push, or merge to master.\n\n";
    impl_prompt += "Return structured output with worktree_path, branch, commit_sha (or empty), files_changed,\n";
    impl_prompt += "analyze_ok, tests_ok, success, skipped, skip_reason, and a short summary.\n";
    impl_prompt += "If setup fails, set success=false and explain in summary; leave worktree_path empty if none created.\n";

    let impl = agent(impl_prompt, #{
        label: "implement-" + s.slug,
        capability_mode: "all",
        isolation_worktree: true,
        output_schema: implement_schema,
    });

    if impl == () || !impl.success || impl.output == () {
        pause("infra", "Implement agent failed for " + s.feature_name + ". Start a new run to retry.");
    }

    let im = impl.output;
    log("Implement: success=" + im.success.to_string() + " worktree=" + im.worktree_path + " analyze_ok=" + im.analyze_ok.to_string());

    if im.skipped == true {
        results.push(#{
            feature: s.feature_name,
            slug: s.slug,
            skipped: true,
            skip_reason: im.skip_reason,
            worktree_path: im.worktree_path,
            branch: im.branch,
            summary: im.summary,
        });
        n += 1;
        if n < count {
            await_user("user", "Feature " + s.feature_name + " was skipped (" + im.skip_reason + "). Resume for next, or stop.");
        }
        continue;
    }

    if im.success != true || im.worktree_path == () || im.worktree_path == "" {
        await_user("verification", "Implementation did not succeed for " + s.feature_name + ": " + im.summary + ". Fix in the worktree if any, then resume to continue the backlog (or stop).");
        results.push(#{
            feature: s.feature_name,
            slug: s.slug,
            success: false,
            summary: im.summary,
            worktree_path: im.worktree_path,
            branch: im.branch,
        });
        n += 1;
        continue;
    }

    // ── Verify ──────────────────────────────────────────────────────────
    phase("Verify");

    let ver_prompt = "";
    ver_prompt += "Adversarially verify that the feature was implemented correctly in the git worktree.\n";
    ver_prompt += "You MUST inspect the actual worktree files with tools — do not trust the implementer summary alone.\n\n";
    ver_prompt += "FEATURE: " + s.feature_name + "\n";
    ver_prompt += "WORKTREE: " + im.worktree_path + "\n";
    ver_prompt += "BRANCH: " + im.branch + "\n";
    ver_prompt += "COMMIT: " + im.commit_sha + "\n";
    ver_prompt += "IMPLEMENTER SUMMARY: " + im.summary + "\n\n";
    ver_prompt += "ACCEPTANCE CRITERIA TO CHECK:\n";
    if plan.acceptance_criteria != () {
        for c in plan.acceptance_criteria {
            ver_prompt += "- " + c + "\n";
        }
    }
    ver_prompt += "\nREQUIRED CHECKS:\n";
    ver_prompt += "1. Shell: git -C " + im.worktree_path + " status -sb && git -C " + im.worktree_path + " log -1 --oneline && git -C " + im.worktree_path + " diff HEAD~1 --stat 2>/dev/null || git -C " + im.worktree_path + " diff --stat\n";
    ver_prompt += "2. Read the changed Dart/HTML files under the worktree; confirm they match AGENTS.md style.\n";
    ver_prompt += "3. Confirm implement-for-web.md marks this feature done (if implementer claimed success).\n";
    ver_prompt += "4. Confirm no edits leaked to " + repo_path + " main worktree (git -C " + repo_path + " status -sb should not show the feature's new files as unstaged work from this task).\n";
    ver_prompt += "5. If analyze_ok was claimed false, approved must be false unless issues are purely pre-existing.\n\n";
    ver_prompt += "Set approved=true ONLY with concrete evidence from files you read.\n";
    ver_prompt += "Default approved=false when uncertain. List issues and missing_acceptance explicitly.\n";
    ver_prompt += "evidence must quote paths and what you observed.\n";

    let ver = agent(ver_prompt, #{
        label: "verify-" + s.slug,
        capability_mode: "read-only",
        output_schema: verify_schema,
    });

    let approved = false;
    let ver_issues = [];
    let ver_evidence = "";
    if ver != () && ver.success && ver.output != () {
        approved = ver.output.approved == true;
        if ver.output.issues != () { ver_issues = ver.output.issues; }
        if ver.output.evidence != () { ver_evidence = ver.output.evidence; }
    } else {
        log("Verify agent failed or returned no output — treating as not approved (fail closed).");
        ver_evidence = "verifier unavailable";
    }

    log("Verify approved=" + approved.to_string() + " for " + s.feature_name);

    results.push(#{
        feature: s.feature_name,
        slug: s.slug,
        success: im.success,
        approved: approved,
        worktree_path: im.worktree_path,
        branch: im.branch,
        commit_sha: im.commit_sha,
        files_changed: im.files_changed,
        analyze_ok: im.analyze_ok,
        tests_ok: im.tests_ok,
        summary: im.summary,
        verify_evidence: ver_evidence,
        verify_issues: ver_issues,
        plan_summary: plan.summary,
    });

    let report = "";
    report += "# Feature: " + s.feature_name + "\n\n";
    report += "- Worktree: `" + im.worktree_path + "`\n";
    report += "- Branch: `" + im.branch + "`\n";
    report += "- Commit: `" + im.commit_sha + "`\n";
    report += "- Analyze OK: " + im.analyze_ok.to_string() + "\n";
    report += "- Verifier approved: " + approved.to_string() + "\n";
    report += "- Summary: " + im.summary + "\n\n";
    report += "Merge when ready (from primary repo):\n";
    report += "```bash\n";
    report += "git -C " + repo_path + " merge " + im.branch + "\n";
    report += "# or: open a PR from " + im.branch + "\n";
    report += "# cleanup: git -C " + repo_path + " worktree remove " + im.worktree_path + "\n";
    report += "```\n";
    write_scratch_file("feature-" + s.slug + ".md", report);

    if !approved {
        await_user(
            "verification",
            "Verifier did not approve " + s.feature_name + ". Worktree: " + im.worktree_path +
            ". Issues: " + json_encode(ver_issues) +
            ". Inspect/fix, then resume to continue the backlog or stop."
        );
    } else if n + 1 < count {
        await_user(
            "user",
            "Completed " + s.feature_name + " in " + im.worktree_path +
            " (branch " + im.branch + "). Merge if you want it on master, then resume for the next feature."
        );
    }

    n += 1;
}

// ── Final ───────────────────────────────────────────────────────────────

let done_path = write_scratch_file("implement-web-feature-results.json", json_encode(results));
complete(#{
    summary: "Processed " + results.len().to_string() + " feature(s) from " + features_file,
    results_path: done_path,
    results: results,
    repo_path: repo_path,
    merge_hint: "Each result has worktree_path + branch. Merge branches into the primary Tayra repo when satisfied.",
});
