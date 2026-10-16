"""Apply the file edits (and chmod commands) of contracts to a directory."""
import sys
sys.path.insert(0, '.')
import replay as R
dest = sys.argv[1]
for c in sys.argv[2:]:
    lines = open(c).read().split('\n')
    for it in R.items(R.section(lines, 'Ordered edits')):
        if 'command' in it and not R.inline(it['command']['value']).startswith('chmod'):
            continue
        log = []
        if not R.apply_edit(it, dest, log):
            print('FAILED', c, log)
