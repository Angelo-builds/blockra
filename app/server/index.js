import express from 'express';
import path from 'path';
import fs from 'fs';
import multer from 'multer';
import Database from 'better-sqlite3';
import session from 'express-session';

const app = express();
const __dirname = path.resolve();
const PORT = process.env.PORT || 3000;

const DB_DIR = '/opt/blockra/data';
const UPLOADS = '/opt/blockra/uploads';
const CONFIG_FILE = '/opt/blockra/config.json';

if (!fs.existsSync(DB_DIR)) fs.mkdirSync(DB_DIR, { recursive: true });
if (!fs.existsSync(UPLOADS)) fs.mkdirSync(UPLOADS, { recursive: true });
if (!fs.existsSync(CONFIG_FILE)) {
  fs.writeFileSync(CONFIG_FILE, JSON.stringify({ user: 'admin', pass: 'admin' }, null, 2));
}

const db = new Database(path.join(DB_DIR, 'blockra.db'));
db.exec(`CREATE TABLE IF NOT EXISTS pages (
  id INTEGER PRIMARY KEY,
  name TEXT,
  content TEXT,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);`);

app.use(express.json({limit: '10mb'}));
app.use(express.urlencoded({extended:true}));
app.use('/uploads', express.static(UPLOADS));
app.use(express.static(path.join(__dirname, 'client', 'dist')));

app.use(session({
  secret: 'blockra-secret-change-me',
  resave: false,
  saveUninitialized: false,
  cookie: { maxAge: 24 * 60 * 60 * 1000 }
}));

function isAuthenticated(req){
  return req.session && req.session.authenticated === true;
}

app.post('/api/login', (req, res) => {
  const { user, pass } = req.body;
  const cfg = JSON.parse(fs.readFileSync(CONFIG_FILE));
  if (user === cfg.user && pass === cfg.pass) {
    req.session.authenticated = true;
    return res.json({ ok: true });
  }
  return res.status(401).json({ error: 'invalid' });
});

app.post('/api/logout', (req,res)=>{
  req.session.destroy(()=>{
    res.json({ok:true});
  });
});

app.get('/api/auth', (req,res)=>{
  res.json({ authenticated: isAuthenticated(req) });
});

app.get('/api/user', (req,res)=>{
  if(!isAuthenticated(req)) return res.status(401).json({error:'unauth'});
  const cfg = JSON.parse(fs.readFileSync(CONFIG_FILE));
  res.json({ user: cfg.user });
});
app.post('/api/user', (req,res)=>{
  if(!isAuthenticated(req)) return res.status(401).json({error:'unauth'});
  const { user, pass } = req.body;
  const cfg = { user, pass };
  fs.writeFileSync(CONFIG_FILE, JSON.stringify(cfg, null, 2));
  res.json({ ok: true });
});

app.use('/api', (req,res,next)=>{
  const open = ['/api/login','/api/auth'];
  if(open.includes(req.path) || isAuthenticated(req)) return next();
  return res.status(401).json({error:'unauth'});
});

const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    cb(null, UPLOADS);
  },
  filename: function (req, file, cb) {
    const fname = Date.now() + '-' + file.originalname.replace(/[^a-zA-Z0-9.\-_]/g, '_');
    cb(null, fname);
  }
});
const upload = multer({ storage: storage });

app.post('/api/upload', upload.single('file'), (req,res)=>{
  if(!req.file) return res.status(400).json({error:'no file'});
  res.json({url:`/uploads/${req.file.filename}`});
});

app.get('/api/pages', (req,res)=>{
  const rows = db.prepare('SELECT id,name,content,created_at FROM pages ORDER BY id DESC').all();
  res.json(rows);
});

app.post('/api/pages', (req,res)=>{
  const {name, content} = req.body;
  const stmt = db.prepare('INSERT INTO pages (name,content) VALUES (?,?)');
  const info = stmt.run(name, JSON.stringify(content));
  res.json({id:info.lastInsertRowid});
});

app.get('/api/pages/:id', (req,res)=>{
  const row = db.prepare('SELECT id,name,content,created_at FROM pages WHERE id = ?').get(req.params.id);
  if(!row) return res.status(404).json({error:'not found'});
  row.content = JSON.parse(row.content);
  res.json(row);
});

app.get('*', (req,res)=>{
  res.sendFile(path.join(__dirname,'client','dist','index.html'));
});

app.listen(PORT, ()=>{
  console.log('Blockra server running on port', PORT);
});
