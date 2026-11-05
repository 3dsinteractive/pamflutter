const fs = require('fs');
const path = require('path');
const { Marked } = require('marked');
const { markedHighlight } = require('marked-highlight');

const hljs = require('highlight.js');
const { globSync } = require('glob');

// ตั้งค่า Syntax Highlighting สำหรับ Code Blocks
const marked = new Marked(
  markedHighlight({
    emptyLangClass: 'hljs',
    langPrefix: 'hljs language-',
    highlight(code, lang) {
      const language = hljs.getLanguage(lang) ? lang : 'plaintext';
      return hljs.highlight(code, { language }).value;
    },
  })
);
const srcDir = './docs';
const outDir = './dist';

// สร้างโฟลเดอร์ dist
if (!fs.existsSync(outDir)) fs.mkdirSync(outDir, { recursive: true });

// คัดลอกรูปภาพ
const copyDir = (src, dest) => {
  if (!fs.existsSync(src)) return;
  fs.mkdirSync(dest, { recursive: true });
  for (const file of fs.readdirSync(src)) {
    const s = path.join(src, file),
      d = path.join(dest, file);
    fs.statSync(s).isDirectory() ? copyDir(s, d) : fs.copyFileSync(s, d);
  }
};
copyDir('./images', `${outDir}/images`);

const themePath = './node_modules/highlight.js/styles/monokai-sublime.min.css';
const hljsCss = fs.readFileSync(themePath, 'utf8');

const mainCss = fs.readFileSync('./css/style.css', 'utf8');

// เทมเพลต HTML ธรรมดา (มี CSS จัดหน้า + Code Block ในตัว)
const htmlTemplate = (title, content) => `<!DOCTYPE html>
<html lang="th">
<head>
  <meta charset="UTF-8">
  <title>${title}</title>
  <link rel="stylesheet" href="css/style.css">
  <link rel="stylesheet" href="css/github-dark.min.css">
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; line-height: 1.6; margin: 0; display: flex; color: #333; }
    nav { width: 240px; background: #f8f9fa; border-right: 1px solid #e9ecef; height: 100vh; position: sticky; top: 0; padding: 24px 16px; box-sizing: border-box; }
    nav ul { list-style: none; padding: 0; margin: 0; }
    nav li { margin-bottom: 12px; }
    nav a { color: #0066cc; text-decoration: none; font-weight: 500; }
    nav a:hover { text-decoration: underline; }
    main { max-width: 850px; padding: 40px 48px; flex: 1; }
    pre { background: #0d1117; padding: 16px; border-radius: 8px; overflow-x: auto; }
    code { font-family: SFMono-Regular, Consolas, Menlo, monospace; font-size: 14px; }
    img { max-width: 100%; height: auto; border: 1px solid #ddd; border-radius: 6px; margin: 16px 0; }
    table { border-collapse: collapse; width: 100%; margin: 16px 0; }
    th, td { border: 1px solid #dee2e6; padding: 8px 12px; text-align: left; }
    th { background: #f1f3f5; }

    /* Github CSS */
    ${hljsCss}

    /*main css*/
    ${mainCss}
  </style>
</head>
<body>
  <nav>
    <h3>คู่มือ SDK</h3>
    <ul>
      <li><a href="index.html">หน้าแรก</a></li>
      <li><a href="database.html">1. ระบบฐานข้อมูลใน PAM</a></li>
      <li><a href="initialization.html">2. เตรียม Config และเริ่มต้นใช้งาน</a></li>
      <li><a href="consent.html">3. การจัดการความยินยอม</a></li>
      <li><a href="authentication.html">4. การเข้าสู่ระบบและออกจากระบบ</a></li>
      <li><a href="tracking.html">5. การส่ง Event Tracking</a></li>
      <li><a href="push-notification.html">6. Push Notification</a></li>
      <li><a href="app-attention.html">7. App Attention</a></li>
    </ul>
  </nav>
  <main>
    ${content}
  </main>
</body>
</html>`;

// แปลงไฟล์ .md ทั้งหมด
const mdFiles = globSync(`${srcDir}/**/*.md`);
mdFiles.forEach((file) => {
  const raw = fs.readFileSync(file, 'utf8');
  const htmlContent = marked.parse(raw);
  const fileName = path.basename(file, '.md');
  const outFile = path.join(outDir, `${fileName}.html`);

  fs.writeFileSync(outFile, htmlTemplate(fileName, htmlContent));
  console.log(`Generated: ${outFile}`);
});
