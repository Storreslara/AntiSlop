import os, shutil, subprocess, sys, tempfile
# usage: mutate.py WORKDIR [names...]  (WORKDIR has eval/abtest/score.py and tests/abtest-score.test.sh)
W = sys.argv[1]
src = open(W + '/eval/abtest/score.py').read()
M = [
 ('p <= ALPHA', 'return p < ALPHA', 'return p <= ALPHA'),
 ('fisher gate > FULL_N', 'if na >= FULL_N:', 'if na > FULL_N:'),
 ('short <= MIN_N', 'if min(na, nb) < MIN_N:', 'if min(na, nb) <= MIN_N:'),
 ('short < 4', 'if min(na, nb) < MIN_N:', 'if min(na, nb) < 4:'),
 ('no unequal check', 'if na != nb:', 'if False:'),
 ('topup or', 'if na < FULL_N and na != MIN_N:', 'if na < FULL_N or na != MIN_N:'),
 ('topup < 9', 'if na < FULL_N and na != MIN_N:', 'if na < FULL_N - 1 and na != MIN_N:'),
 ('topup != 6', 'if na < FULL_N and na != MIN_N:', 'if na < FULL_N and na != MIN_N + 1:'),
 ('bad >= 3', 'if bad(rows_a) >= 2 or bad(rows_b) >= 2:', 'if bad(rows_a) >= 3 or bad(rows_b) >= 3:'),
 ('bad B only', 'if bad(rows_a) >= 2 or bad(rows_b) >= 2:', 'if bad(rows_b) >= 2:'),
 ('bad A only', 'if bad(rows_a) >= 2 or bad(rows_b) >= 2:', 'if bad(rows_a) >= 2:'),
 ('bad summed', 'if bad(rows_a) >= 2 or bad(rows_b) >= 2:', 'if bad(rows_a) + bad(rows_b) >= 2:'),
 ('bad and', 'if bad(rows_a) >= 2 or bad(rows_b) >= 2:', 'if bad(rows_a) >= 2 and bad(rows_b) >= 2:'),
 ('BAD + stalled', 'BAD = ("turn-cap", "timeout", "error")', 'BAD = ("turn-cap", "timeout", "error", "stalled-human")'),
 ('BAD - timeout', 'BAD = ("turn-cap", "timeout", "error")', 'BAD = ("turn-cap", "error")'),
 ('BAD - turn-cap', 'BAD = ("turn-cap", "timeout", "error")', 'BAD = ("timeout", "error")'),
 ('BAD - error', 'BAD = ("turn-cap", "timeout", "error")', 'BAD = ("turn-cap", "timeout")'),
 ('gap1 <= 1', 'if abs(kb - ka) == 1:', 'if abs(kb - ka) <= 1:'),
 ('no gap1 rule', 'if abs(kb - ka) == 1:', 'if False:'),
 ('WIN_B gap 3', 'if kb - ka >= 2:', 'if kb - ka >= 3:'),
 ('WIN_A gap 3', 'if ka - kb >= 2:', 'if ka - kb >= 3:'),
 ('WIN_B > 2', 'if kb - ka >= 2:', 'if kb - ka > 2:'),
 ('WIN_A > 2', 'if ka - kb >= 2:', 'if ka - kb > 2:'),
 ('fisher strict tail', 'if prob(x) <= observed * (1 + 1e-9)', 'if prob(x) < observed'),
 ('fisher winner direction', '("WIN_B" if kb > ka else "WIN_A"), ka, kb, p, "fisher"', '("WIN_B" if kb < ka else "WIN_A"), ka, kb, p, "fisher"'),
 ('fisher p only at N>=10', 'p = fisher_two_sided(ka, na, kb, nb) if na and nb else None', 'p = fisher_two_sided(ka, na, kb, nb) if na >= FULL_N and nb >= FULL_N else None'),
 ('directional no not', 'not p_decisive(p))', 'p_decisive(p))'),
 ('directional no WIN_B', 'out == "WIN_B" and not p_decisive(p)', 'not p_decisive(p)'),
 ('directional no superior', 'directional = bool(verdict == "superior" and ', 'directional = bool('),
 ('edge defects <=', 'and q["defects_median_B"] < q["defects_median_A"]', 'and q["defects_median_B"] <= q["defects_median_A"]'),
 ('edge oos <=', 'and q["out_of_scope_median_B"] < q["out_of_scope_median_A"]', 'and q["out_of_scope_median_B"] <= q["out_of_scope_median_A"]'),
 ('edge no oos', '\n        and q["out_of_scope_median_B"] < q["out_of_scope_median_A"]', ''),
 ('edge no defects', 'and q["defects_median_B"] < q["defects_median_A"]\n', '\n'),
 ('r_tok > 3 to >= 3', 'r_tok > 3', 'r_tok >= 3'),
 ('r_tok <= 2 to < 2', 'r_tok <= 2', 'r_tok < 2'),
 ('r_tok <= 2.5', 'r_tok <= 2', 'r_tok <= 2.5'),
 ('ca all rows', 'ca = [r for r in ra if r["completion_status"] == "complete"]', 'ca = ra'),
 ('cb all rows', 'cb = [r for r in rb if r["completion_status"] == "complete"]', 'cb = rb'),
 ('R mean not median', 'return statistics.median(values) if values else None', 'return statistics.mean(values) if values else None'),
 ('R inverted', 'over[name] = ratio(med(vb), med(va))', 'over[name] = ratio(med(va), med(vb))'),
 ('label any tie', 'if (out == "TIE" and eval_id in COST_EVALS)', 'if (out == "TIE")'),
 ('label any outcome', 'if (out == "TIE" and eval_id in COST_EVALS)', 'if (eval_id in COST_EVALS)'),
 ('stall override off', 'if stalled_b > 0 or out == "WIN_A":', 'if out == "WIN_A":'),
 ('stall >= 2', 'if stalled_b > 0 or out == "WIN_A":', 'if stalled_b > 1 or out == "WIN_A":'),
 ('WIN_A not-superior off', 'if stalled_b > 0 or out == "WIN_A":', 'if stalled_b > 0:'),
 ('inconclusive verdict', 'verdict = "inconclusive"', 'verdict = "mixed"'),
 ('no policy filter', 'in_policy = [r for r in rows if r["model_policy"] == policy]', 'in_policy = list(rows)'),
 ('limited unfiltered', 'limited = [r for r in in_policy if', 'limited = [r for r in rows if'),
 ('no policy-match guard', 'if rows and not in_policy:', 'if False:'),
 ('no usable guard', 'if not used:', 'if False:'),
 ('dropped count 0', '"rows_dropped_other_policy": len(rows) - len(in_policy)', '"rows_dropped_other_policy": 0'),
 ('no empty guard', 'if not rows:\n        print(f"score:', 'if False:\n        print(f"score:'),
 ('empty exit 0', 'refusing to score an empty results file", file=sys.stderr)\n        return 2', 'refusing to score an empty results file", file=sys.stderr)\n        return 0'),
 ('core any', 'all(e2e4) if len(e2e4) == 2 else None', 'any(e2e4) if len(e2e4) == 2 else None'),
 ('core always', 'all(e2e4) if len(e2e4) == 2 else None', 'True'),
 ('core e2 only', 'if e[:3] in ("e02", "e04")]', 'if e[:3] in ("e02",)]'),
 ('validate exit 0', "return 1 if errors else 0", "return 0"),
 ('score errors exit 0', 'print("\\n".join(errors), file=sys.stderr)\n        return 1', 'print("\\n".join(errors), file=sys.stderr)\n        return 0'),
 ('no read guard', 'except (OSError, UnicodeDecodeError) as e:', 'except ZeroDivisionError as e:'),
 ('short reason text', 'f"short N: A={na} B={nb}"', 'f"short N"'),
 # fix2 (validator) mutants
 ('no dup check', 'if rid in seen:', 'if False:'),
 ('dup incl usage-limit', 'if status != "usage-limit" and isinstance(rid, str):', 'if isinstance(rid, str):'),
 ('no run_pass bool', 'if not isinstance(r["run_pass"], bool):', 'if False:'),
 ('no run_pass vs status', 'elif r["run_pass"] and status != "complete":', 'elif False:'),
 ('bool counts ok', 'return isinstance(v, int) and not isinstance(v, bool) and v >= 0', 'return isinstance(v, int) and v >= 0'),
 ('negative counts ok', 'return isinstance(v, int) and not isinstance(v, bool) and v >= 0', 'return isinstance(v, int) and not isinstance(v, bool)'),
 ('no count check', 'if k in r and not is_count(r[k]):', 'if False:'),
 ('no total check', 'if r["tokens_total"] != r["tokens_in"] + r["tokens_out"] + r["tokens_cache_write"]:', 'if False:'),
 ('total adds cache_read', 'r["tokens_in"] + r["tokens_out"] + r["tokens_cache_write"]:', 'r["tokens_in"] + r["tokens_out"] + r["tokens_cache_write"] + r["tokens_cache_read"]:'),
 ('nan measure ok', 'isfinite(v) and v >= 0)', 'v >= 0)'),
 ('neg measure ok', 'isfinite(v) and v >= 0)', 'isfinite(v))'),
 ('no measure check', 'if k in r and not is_measure(r[k]):', 'if False:'),
 ('no object check', 'if not isinstance(r, dict):', 'if False:'),
 ('no str check', 'if k in r and (not isinstance(r[k], str) or not r[k]):', 'if False:'),
 ('no missing check', 'if missing:', 'if False:'),
 ('no status check', 'if status not in STATUSES:', 'if False:'),
 ('no arm check', 'if r.get("arm") not in ("A", "B"):', 'if False:'),
 ('STATUSES + budget', '"usage-limit", "error")', '"usage-limit", "error", "budget")'),
]
work = tempfile.mkdtemp(prefix='mut-')
os.makedirs(work + '/eval/abtest'); os.makedirs(work + '/tests')
shutil.copy(W + '/tests/abtest-score.test.sh', work + '/tests/')
alive = []
only = sys.argv[2:]
n = 0
for name, old, new in M:
    if only and name not in only:
        continue
    if src.count(old) != 1:
        print('SKIP (pattern absent in this state)', name, src.count(old))
        continue
    n += 1
    open(work + '/eval/abtest/score.py', 'w').write(src.replace(old, new))
    r = subprocess.run(['bash', work + '/tests/abtest-score.test.sh'], capture_output=True, text=True)
    state = 'killed' if r.returncode != 0 else 'ALIVE'
    if state == 'ALIVE':
        alive.append(name)
    print(state, name, r.returncode)
print('mutants', n, 'alive', alive)
shutil.rmtree(work)
