const express = require('express');
const app = express();
const port = 3000;

app.get('/', (req, res) => {
  res.send('Hello World from PicoClaw DevOps Demo!');
});

app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

app.listen(port, () => {
  console.log(`App listening at http://localhost:${port}`);
});
EOF && git add app/src/index.js && git commit -m "feat(issue-9): add /health endpoint" && git push origin feature/issue-9-success-verified-v39 && gh pr create --title "feat: add /health endpoint (Full Flow Verified)" --body "🤖 This PR is the final step of the automated workflow verification." --base main --head feature/issue-9-success-verified-v39