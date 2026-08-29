import json
from pathlib import Path

log_path = Path('/tmp/flutter-test-machine.log')
out_path = Path('tool/feature_flutter_test_failures.txt')

tests = {}
errors = {}
failed = []
raw_lines = []

for raw in log_path.read_text(errors='replace').splitlines():
    try:
        event = json.loads(raw)
    except json.JSONDecodeError:
        if raw.strip():
            raw_lines.append(raw.strip())
        continue
    event_type = event.get('type')
    if event_type == 'testStart':
        test = event.get('test') or {}
        tests[test.get('id')] = {
            'name': test.get('name', '<unnamed>'),
            'url': test.get('url', ''),
        }
    elif event_type == 'error':
        test_id = event.get('testID')
        errors.setdefault(test_id, []).append(
            (event.get('error') or '') + '\n' + (event.get('stackTrace') or '')
        )
    elif event_type == 'testDone' and event.get('result') not in ('success', None):
        test_id = event.get('testID')
        if test_id not in failed:
            failed.append(test_id)

lines = []
for test_id in failed:
    info = tests.get(test_id, {'name': f'test id {test_id}', 'url': ''})
    lines.append(f"FAIL: {info['name']}")
    if info['url']:
        lines.append(f"FILE: {info['url']}")
    for error in errors.get(test_id, []):
        lines.extend(error.splitlines()[:40])
    lines.append('---')

if not lines:
    lines.append('No structured failed-test events were parsed.')
    if raw_lines:
        lines.append('Last non-JSON output:')
        lines.extend(raw_lines[-120:])

out_path.write_text('\n'.join(lines[:500]) + '\n')
print(out_path.read_text())
