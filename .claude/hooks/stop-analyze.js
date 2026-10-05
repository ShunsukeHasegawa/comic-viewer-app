// Stop: lib / test に未コミットの変更があれば、終える前に `flutter analyze` を流す。
// 問題があれば exit 2 で作業を続けさせる（CLAUDE.md: 警告ゼロ）。
//
// - 前回通ったときと同じ変更なら流さない（何もしていない会話の終わりで待たせない）。
// - 直してもらった後に同じ変更のまま止まろうとしたら、ループさせずに終えさせる。
const { spawnSync } = require('node:child_process');
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');

const root = process.env.CLAUDE_PROJECT_DIR || process.cwd();
const stampDir = path.join(root, '.dart_tool');
const passStamp = path.join(stampDir, 'claude-analyze-pass');
const failStamp = path.join(stampDir, 'claude-analyze-fail');

const git = (...args) =>
  spawnSync('git', args, { cwd: root, encoding: 'utf8' }).stdout ?? '';
const read = (file) => {
  try {
    return fs.readFileSync(file, 'utf8');
  } catch {
    return '';
  }
};
const write = (file, value) => {
  try {
    fs.mkdirSync(stampDir, { recursive: true });
    fs.writeFileSync(file, value);
  } catch {}
};

let input = '';
process.stdin.on('data', (chunk) => (input += chunk));
process.stdin.on('end', () => {
  let continuing = false;
  try {
    continuing = JSON.parse(input).stop_hook_active === true;
  } catch {}

  if (git('status', '--porcelain', '--', 'lib', 'test').trim() === '') {
    process.exit(0);
  }

  // 変更内容（差分 + 未追跡ファイルの更新時刻）の指紋。
  const untracked = git('ls-files', '--others', '--exclude-standard', '--', 'lib', 'test')
    .split('\n')
    .filter(Boolean)
    .map((file) => {
      try {
        return `${file}:${fs.statSync(path.join(root, file)).mtimeMs}`;
      } catch {
        return file;
      }
    })
    .join('\n');
  const fingerprint = crypto
    .createHash('sha1')
    .update(git('diff', 'HEAD', '--', 'lib', 'test'))
    .update(untracked)
    .digest('hex');

  if (read(passStamp) === fingerprint) process.exit(0);
  if (continuing && read(failStamp) === fingerprint) process.exit(0);

  const [command, args] =
    process.platform === 'win32'
      ? ['cmd', ['/c', 'flutter', 'analyze', '--no-pub']]
      : ['flutter', ['analyze', '--no-pub']];
  const result = spawnSync(command, args, {
    cwd: root,
    encoding: 'utf8',
    timeout: 170000,
  });

  if (result.status === 0) {
    write(passStamp, fingerprint);
    process.exit(0);
  }
  if (result.status === null) process.exit(0); // 時間切れなどは止めない

  write(failStamp, fingerprint);
  const issues = `${result.stdout ?? ''}${result.stderr ?? ''}`
    .split('\n')
    .filter((line) => /^\s*(error|warning|info)\s+[•-]\s/.test(line))
    .slice(0, 40)
    .join('\n');
  process.stderr.write(
    'flutter analyze で問題が出ています（CLAUDE.md: 警告ゼロ）。直してから終えてください。' +
      '今回の作業と無関係な変更が原因なら、直さずにそのことをユーザーに伝えて終えてください。\n' +
      `${issues}\n`,
  );
  process.exit(2);
});
