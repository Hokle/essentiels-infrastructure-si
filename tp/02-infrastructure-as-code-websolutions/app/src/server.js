'use strict';

const http = require('node:http');
const { Pool } = require('pg');
const { createHandler } = require('./app');

const db = new Pool({
  host: process.env.DB_HOST,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  connectionTimeoutMillis: 2000,
  query_timeout: 2000
});
db.on('error', (error) => console.error(error.message));

const handler = createHandler({
  version: process.env.APP_VERSION || 'dev',
  checkDatabase: () => db.query('SELECT 1'),
  listProjects: async () => (await db.query('SELECT id, name FROM projects ORDER BY id')).rows
});

async function start() {
  await db.query('CREATE TABLE IF NOT EXISTS projects (id integer PRIMARY KEY, name text NOT NULL)');
  await db.query(
    'INSERT INTO projects VALUES ($1, $2), ($3, $4) ON CONFLICT DO NOTHING',
    [1, 'Site vitrine', 2, 'Boutique en ligne']
  );
  http.createServer(handler).listen(3000, '0.0.0.0');
  console.log(`websolutions-api ${process.env.APP_VERSION || 'dev'} a l'ecoute sur 3000`);
}

start().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
