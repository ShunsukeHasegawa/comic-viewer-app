// PreToolUse: 手で書き換えてはいけないファイルの編集を止める（CLAUDE.md の決まり）。
// 止めるときは exit 2 + stderr（Claude に理由が返る）。
let input = '';
process.stdin.on('data', (chunk) => (input += chunk));
process.stdin.on('end', () => {
  let filePath = '';
  try {
    const payload = JSON.parse(input);
    filePath = payload.tool_input?.file_path ?? payload.tool_input?.notebook_path ?? '';
  } catch {
    process.exit(0); // 読めない入力で作業を止めない
  }
  const normalized = filePath.replace(/\\/g, '/');
  const name = normalized.split('/').pop() ?? '';

  const rules = [
    {
      test: /\.(g|freezed)\.dart$/.test(name),
      reason:
        '生成コード（*.g.dart / *.freezed.dart）は直接編集しない。生成元を直して ' +
        "TMP / TEMP を ASCII にした `dart run build_runner build` で作り直す。",
    },
    {
      test: name === 'google-services.json' || name === 'GoogleService-Info.plist',
      reason:
        'Firebase の設定ファイルは作らない / コミットしない（置き方は README。ユーザーが置く）。',
    },
    {
      test: name === 'key.properties' || /\.(jks|keystore)$/.test(name),
      reason:
        '署名の鍵 / パスワードは作らない（作るのはユーザー。書式は android/key.properties.example）。',
    },
  ];

  const hit = rules.find((rule) => rule.test);
  if (hit) {
    process.stderr.write(`${filePath} は編集できません: ${hit.reason}\n`);
    process.exit(2);
  }
  process.exit(0);
});
