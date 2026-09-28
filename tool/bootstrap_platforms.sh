#!/usr/bin/env bash
set -euo pipefail

# Generate native wrappers in a temporary directory on the hosted CI runner so
# Flutter never overwrites the Dart sources in this repository.
generated="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/chat-niu-platforms"
rm -rf "$generated"
flutter create \
  --platforms=android,ios \
  --org=com.chatniu \
  --project-name=chat_niu \
  "$generated"
cp -a "$generated/android" .
cp -a "$generated/ios" .

python3 - <<'PY'
from pathlib import Path
import xml.etree.ElementTree as ET

ET.register_namespace('android', 'http://schemas.android.com/apk/res/android')
manifest = Path('android/app/src/main/AndroidManifest.xml')
if manifest.exists():
    tree = ET.parse(manifest)
    root = tree.getroot()
    android = '{http://schemas.android.com/apk/res/android}'
    existing = {item.get(android + 'name') for item in root.findall('uses-permission')}
    for permission in ('android.permission.RECORD_AUDIO', 'android.permission.INTERNET'):
        if permission not in existing:
            ET.SubElement(root, 'uses-permission', {android + 'name': permission})
    if root.find('queries') is None:
        queries = ET.Element('queries')
        intent = ET.SubElement(queries, 'intent')
        ET.SubElement(intent, 'action', {android + 'name': 'android.speech.RecognitionService'})
        root.insert(0, queries)
    tree.write(manifest, encoding='utf-8', xml_declaration=True)

plist = Path('ios/Runner/Info.plist')
if plist.exists():
    text = plist.read_text()
    additions = '''\n\t<key>NSMicrophoneUsageDescription</key>\n\t<string>需要使用麦克风将语音转换为聊天文字。</string>\n\t<key>NSSpeechRecognitionUsageDescription</key>\n\t<string>需要语音识别权限以支持语音输入。</string>'''
    if 'NSMicrophoneUsageDescription' not in text:
        text = text.replace('</dict>', additions + '\n</dict>')
    plist.write_text(text)
PY
