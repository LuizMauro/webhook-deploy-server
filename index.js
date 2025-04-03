const express = require("express");
const bodyParser = require("body-parser");
const { exec } = require("child_process");
const cors = require("cors");

const app = express();
app.use(
  cors({
    origin: "*",
  })
);
const PORT = 4000;

app.use(bodyParser.json());

app.post("/webhook", (req, res) => {
  const repoName = req.body.repository.name;
  const cloneUrl = req.body.repository.clone_url;

  console.log(`🔥 Push detectado no repo: ${repoName}`);

  exec(`bash ./deploy.sh ${repoName} ${cloneUrl}`, (err, stdout, stderr) => {
    if (err) {
      console.error("Erro:", stderr);
      return res.status(500).send("Erro no deploy");
    }
    console.log(stdout);
    res.send("🚀 Deploy em andamento...");
  });
});

app.listen(PORT, () => {
  console.log(`🎧 Webhook escutando na porta ${PORT}`);
});
