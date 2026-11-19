'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const http = require('node:http');
const { createHandler } = require('../src/app');

// Démarre le gestionnaire sur un port libre avec de fausses dépendances.
async function serve(deps) {
  const server = http.createServer(createHandler({ version: 'test', ...deps }));
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const base = `http://127.0.0.1:${server.address().port}`;
  return { base, close: () => new Promise((resolve) => server.close(resolve)) };
}

const okDb = { checkDatabase: async () => {}, listProjects: async () => [{ id: 1, name: 'Site vitrine' }] };
const downDb = {
  checkDatabase: async () => { throw new Error('connexion refusee'); },
  listProjects: async () => { throw new Error('connexion refusee'); }
};

test('GET /health renvoie 200 quand la base répond', async () => {
  const app = await serve(okDb);
  const res = await fetch(`${app.base}/health`);
  assert.equal(res.status, 200);
  assert.deepEqual(await res.json(), { status: 'ok', version: 'test', database: 'ok' });
  await app.close();
});

test('GET /health renvoie 503 quand la base est indisponible', async () => {
  const app = await serve(downDb);
  const res = await fetch(`${app.base}/health`);
  assert.equal(res.status, 503);
  assert.equal((await res.json()).database, 'indisponible');
  await app.close();
});

test('GET /api/projects renvoie la liste lue en base', async () => {
  const app = await serve(okDb);
  const res = await fetch(`${app.base}/api/projects`);
  assert.equal(res.status, 200);
  assert.deepEqual(await res.json(), { projects: [{ id: 1, name: 'Site vitrine' }] });
  await app.close();
});

test('une route inconnue renvoie 404', async () => {
  const app = await serve(okDb);
  const res = await fetch(`${app.base}/inconnue`);
  assert.equal(res.status, 404);
  await app.close();
});
