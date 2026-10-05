// PostToolUse: 編集した Dart ファイルだけ `dart format` をかける。
// 整形の失敗（構文エラーの途中など）で作業は止めない。
const { execFileSync } = require('node:child_process');

let input = '';
process.stdin.on('data', (chunk) => (input += chunk));
process.stdin.on('end', () => {
  let filePath = '';
  try {
    filePath = JSON.parse(input).tool_input?.file_path ?? '';
  } catch {
    process.exit(0);
  }
  // 生成コードは build_runner の出力のまま残す。
  if (!filePath.endsWith('.dart') || /\.(g|freezed)\.dart$/.test(filePath)) {
    process.exit(0);
  }
  try {
    // Windows の dart は dart.bat なので cmd 経由で呼ぶ（引数のクォートは node に任せる）。
    const [command, args] =
      process.platform === 'win32'
        ? ['cmd', ['/c', 'dart', 'format', filePath]]
        : ['dart', ['format', filePath]];
    execFileSync(command, args, { stdio: 'ignore', timeout: 50000 });
  } catch {
    // 構文エラーなどは analyze / テストで分かる。
  }
  process.exit(0);
});
