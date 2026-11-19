'use strict';

// Logique HTTP séparée du serveur : elle reçoit ses dépendances en paramètre,
// ce qui permet de la tester sans base de données (voir test/app.test.js).
function createHandler({ version, checkDatabase, listProjects }) {
  return async function handle(req, res) {
    const send = (status, body) => {
      res.writeHead(status, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify(body));
    };

    if (req.method !== 'GET') {
      return send(405, { error: 'methode non autorisee' });
    }

    if (req.url === '/health') {
      try {
        await checkDatabase();
        return send(200, { status: 'ok', version, database: 'ok' });
      } catch {
        return send(503, { status: 'degraded', version, database: 'indisponible' });
      }
    }

    if (req.url === '/api/projects') {
      try {
        return send(200, { projects: await listProjects() });
      } catch {
        return send(503, { error: 'base indisponible' });
      }
    }

    if (req.url === '/') {
      return send(200, { service: 'websolutions-api', version });
    }

    return send(404, { error: 'route introuvable' });
  };
}

module.exports = { createHandler };
