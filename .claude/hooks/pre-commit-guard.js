// PreToolUse（Bash / PowerShell）: `git commit` の前に、CI で落ちる取りこぼしを止める。
// - dart format の差分が残っている
// - 生成元（part '*.g.dart' / '*.freezed.dart' を持つファイル）を変えたのに
//   build_runner を回していない（生成元が .dart_tool/build/asset_graph.json より新しい）
const { spawnSync } = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');

const root = process.env.CLAUDE_PROJECT_DIR || process.cwd();
const git = (...args) =>
  spawnSync('git', args, { cwd: root, encoding: 'utf8' }).stdout ?? '';

let input = '';
process.stdin.on('data', (chunk) => (input += chunk));
process.stdin.on('end', () => {
  let command = '';
  try {
    command = JSON.parse(input).tool_input?.command ?? '';
  } catch {
    process.exit(0);
  }
  if (!/\bgit\b[^|;&\n]*\bcommit\b/.test(command)) process.exit(0);

  const problems = [];

  // 1. 整形漏れ
  const [fmt, fmtArgs] =
    process.platform === 'win32'
      ? ['cmd', ['/c', 'dart', 'format', '--output=none', '--set-exit-if-changed', 'lib', 'test']]
      : ['dart', ['format', '--output=none', '--set-exit-if-changed', 'lib', 'test']];
  const format = spawnSync(fmt, fmtArgs, { cwd: root, encoding: 'utf8', timeout: 60000 });
  if (format.status === 1) {
    const changed = (format.stdout ?? '')
      .split('\n')
      .filter((line) => line.startsWith('Changed '))
      .join('\n');
    problems.push(`dart format の差分が残っています。\`dart format .\` を実行してください。\n${changed}`);
  }

  // 2. 生成コードの再生成漏れ
  const graph = path.join(root, '.dart_tool', 'build', 'asset_graph.json');
  if (fs.existsSync(graph)) {
    const builtAt = fs.statSync(graph).mtimeMs;
    const changed = [
      ...git('diff', '--name-only', 'HEAD').split('\n'),
      ...git('ls-files', '--others', '--exclude-standard').split('\n'),
    ].filter((file) => file.endsWith('.dart') && !/\.(g|freezed)\.dart$/.test(file));
    const stale = [...new Set(changed)].filter((file) => {
      const full = path.join(root, file);
      try {
        const source = fs.readFileSync(full, 'utf8');
        return (
          /^part\s+'[^']+\.(g|freezed)\.dart';/m.test(source) &&
          fs.statSync(full).mtimeMs > builtAt
        );
      } catch {
        return false;
      }
    });
    if (stale.length > 0) {
      problems.push(
        '生成元が最後の build_runner より新しいままです（CI の再生成で差分が出ます）。' +
          "`TMP='C:\\Temp\\claude-dart' TEMP='C:\\Temp\\claude-dart' dart run build_runner build` " +
          `を実行し、生成コードも含めてコミットしてください。\n${stale.join('\n')}`,
      );
    }
  }

  if (problems.length > 0) {
    process.stderr.write(`コミットを止めました。\n\n${problems.join('\n\n')}\n`);
    process.exit(2);
  }
  process.exit(0);
});
