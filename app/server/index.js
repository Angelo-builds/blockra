import express from 'express';
import path from 'path';
import fs from 'fs';
import multer from 'multer';
import Database from 'better-sqlite3';

const app = express();
const __dirname = path.resolve();
const PORT = process.env.PORT || 3000;

const DB_DIR = '/opt/blockra/data';
const UPLOADS = '/opt/blockra/uploads';
if (!fs.existsSync(DB_DIR)) fs.mkdirSync(DB_DIR, { recursive: true });
if (!fs.existsSync(UPLOADS)) fs.mkdirSync(UPLOADS, { recursive: true });

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

// Multer for image uploads
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

// Fallback to index.html for SPA
app.get('*', (req,res)=>{
  res.sendFile(path.join(__dirname,'client','dist','index.html'));
});

app.listen(PORT, ()=>{
  console.log('Blockra server running on port', PORT);
});
