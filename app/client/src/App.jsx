import React, {useState, useEffect, useRef} from 'react';
import axios from 'axios';
function Login({onLogin}){
  const [user,setUser]=useState('admin');
  const [pass,setPass]=useState('admin');
  const [err,setErr]=useState('');
  async function submit(e){
    e.preventDefault();
    try{
      await axios.post('/api/login',{user,pass});
      onLogin();
    }catch(err){
      setErr('Invalid credentials');
    }
  }
  return (
    <div className="login">
      <form onSubmit={submit} className="login-form">
        <h2>Blockra Login</h2>
        <input value={user} onChange={e=>setUser(e.target.value)} placeholder="User" />
        <input type="password" value={pass} onChange={e=>setPass(e.target.value)} placeholder="Password" />
        <button type="submit">Login</button>
        {err && <div className="error">{err}</div>}
      </form>
    </div>
  );
}

function Block({block, onEdit, onRemove}) {
  if(block.type === 'text'){
    return (
      <div className="block text-block" contentEditable onInput={(e)=>onEdit({...block, text: e.target.innerText})}>
        {block.text}
        <button className="remove" onClick={()=>onRemove(block.id)}>x</button>
      </div>
    );
  } else if(block.type === 'image'){
    return (
      <div className="block image-block">
        <img src={block.src} alt="" style={{maxWidth:'100%'}} />
        <button className="remove" onClick={()=>onRemove(block.id)}>x</button>
      </div>
    );
  }
  return null;
}

export default function App(){
  const [blocks, setBlocks] = useState([]);
  const [pages, setPages] = useState([]);
  const [auth, setAuth] = useState(false);
  const fileRef = useRef();

  useEffect(()=>{ checkAuth(); }, []);

  async function checkAuth(){
    try{
      const res = await axios.get('/api/auth');
      setAuth(res.data.authenticated);
      if(res.data.authenticated) fetchPages();
    }catch(e){ setAuth(false); }
  }

  async function fetchPages(){ const res = await axios.get('/api/pages'); setPages(res.data); }

  function addText(){ const id = Date.now(); setBlocks([...blocks, {id, type:'text', text:'Edit me'}]); }
  function addImage(file){ const fd = new FormData(); fd.append('file', file); axios.post('/api/upload', fd).then(res=>{ const id = Date.now(); setBlocks([...blocks, {id, type:'image', src: res.data.url}]); }); }
  function handleDrop(e){ e.preventDefault(); const file = e.dataTransfer.files[0]; if(file) addImage(file); }
  function handleRemove(id){ setBlocks(blocks.filter(b=>b.id!==id)); }
  function handleEdit(updated){ setBlocks(blocks.map(b=>b.id===updated.id?updated:b)); }
  function savePage(){ const name = prompt('Page name','My Page'); axios.post('/api/pages', {name, content: blocks}).then(()=>{ alert('Saved'); fetchPages();}); }
  async function logout(){ await axios.post('/api/logout'); setAuth(false); }

  if(!auth){
    return <Login onLogin={checkAuth} />;
  }

  return (
    <div className="app">
      <header>
        <h1>Blockra — Drag & Drop Site Builder</h1>
        <div className="actions">
          <button onClick={addText}>Add Text</button>
          <button onClick={()=>fileRef.current.click()}>Upload Image</button>
          <input ref={fileRef} type="file" style={{display:'none'}} onChange={(e)=>addImage(e.target.files[0])} />
          <button onClick={savePage}>Save Page</button>
          <button onClick={logout}>Logout</button>
        </div>
      </header>
      <main>
        <aside className="sidebar">
          <h3>Saved Pages</h3>
          <ul>
            {pages.map(p=><li key={p.id}>{p.name}</li>)}
          </ul>
        </aside>
        <section className="canvas" onDragOver={(e)=>e.preventDefault()} onDrop={handleDrop}>
          {blocks.map(b=>(
            <Block key={b.id} block={b} onEdit={handleEdit} onRemove={handleRemove} />
          ))}
          <div className="drop-hint">Drop images here</div>
        </section>
      </main>
    </div>
  );
}
