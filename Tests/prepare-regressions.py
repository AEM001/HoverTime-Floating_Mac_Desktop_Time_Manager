#!/usr/bin/env python3
"""Prepare production sources for the remote Swift compiler.

Only OS notifications and UserDefaults are isolated in test copies. Timer and
menu behavior run unchanged. Compile with the project's remote compiler flags,
then run the resulting ARM64 executable on a Mac with a GUI session.
"""
from pathlib import Path
import sys

root = Path(__file__).resolve().parents[1]
out = Path(sys.argv[1])
out.mkdir(parents=True, exist_ok=True)
for source in (root / 'HoverTime').glob('*.swift'):
    if source.name == 'HoverTimeApp.swift':
        continue
    text = source.read_text()
    text = text.replace('UserDefaults.standard', 'UserDefaults(suiteName: "HoverTime.RegressionTests")!')
    if source.name == 'TimerManager.swift':
        for signature, body in [
            ('private func requestNotificationPermission()', 'NotificationSpy.permissionRequests += 1'),
            ('private func sendNotification(title: String, body: String)', 'NotificationSpy.completions += 1'),
        ]:
            start = text.index('{', text.index(signature))
            depth, end = 1, start + 1
            while depth:
                depth += (text[end] == '{') - (text[end] == '}')
                end += 1
            text = text[:start] + '{ ' + body + ' }' + text[end:]
        text += (root / 'Tests/TimerRegressions.swift.inc').read_text()
    if source.name == 'MenuBarView.swift':
        text += (root / 'Tests/MenuRegressions.swift.inc').read_text()
    (out / source.name).write_text(text)
(out / 'RegressionMain.swift').write_text((root / 'Tests/RegressionMain.swift.inc').read_text())
print(out)
