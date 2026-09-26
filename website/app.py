#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
CorPlayer 音乐网站后端
运行: python3 app.py
"""
import os
import json
import uuid
import shutil
from flask import Flask, render_template, request, jsonify, send_from_directory, redirect, url_for
from werkzeug.utils import secure_filename

app = Flask(__name__)
app.config['MAX_CONTENT_LENGTH'] = 100 * 1024 * 1024  # 100MB

DATA_DIR = os.path.join(os.path.dirname(__file__), 'data')
UPLOAD_DIR = os.path.join(os.path.dirname(__file__), 'uploads')
os.makedirs(DATA_DIR, exist_ok=True)
os.makedirs(UPLOAD_DIR, exist_ok=True)

# ========== 数据存储 ==========
def load_json(filename):
    path = os.path.join(DATA_DIR, filename)
    if os.path.exists(path):
        with open(path, 'r', encoding='utf-8') as f:
            return json.load(f)
    return []

def save_json(filename, data):
    path = os.path.join(DATA_DIR, filename)
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

def get_singers(): return load_json('singers.json')
def save_singers(d): save_json('singers.json', d)
def get_songs(): return load_json('songs.json')
def save_songs(d): save_json('songs.json', d)
def get_playlists(): return load_json('playlists.json')
def save_playlists(d): save_json('playlists.json', d)

# 初始化示例数据
if not os.path.exists(os.path.join(DATA_DIR, 'singers.json')):
    save_singers([
        {"id": "s1", "name": "周杰伦", "avatar": "/uploads/zhoujielun/info.png", "intro": "华语流行天王"},
        {"id": "s2", "name": "林俊杰", "avatar": "/uploads/linjunjie/info.png", "intro": "新加坡创作歌手"},
    ])
if not os.path.exists(os.path.join(DATA_DIR, 'songs.json')):
    save_songs([
        {"id": "song1", "name": "晴天", "singer": "周杰伦", "album": "叶惠美", "cover": "", "mp3_url": "", "lrc_url": "", "duration": 269},
        {"id": "song2", "name": "七里香", "singer": "周杰伦", "album": "七里香", "cover": "", "mp3_url": "", "lrc_url": "", "duration": 299},
        {"id": "song3", "name": "江南", "singer": "林俊杰", "album": "第二天堂", "cover": "", "mp3_url": "", "lrc_url": "", "duration": 248},
    ])
if not os.path.exists(os.path.join(DATA_DIR, 'playlists.json')):
    save_playlists([
        {"id": "p1", "name": "热门推荐", "cover": "", "intro": "编辑精选热门歌曲", "songs": ["song1", "song2", "song3"]},
    ])

# ========== 页面路由 ==========
@app.route('/')
def index():
    return render_template('index.html')

@app.route('/app/index.html')
def app_index():
    return render_template('app_index.html')

@app.route('/app/')
def app_root():
    return redirect('/app/index.html')

@app.route('/geshou.html')
def geshou():
    singer_name = request.args.get('', '')
    return render_template('geshou.html', singer_name=singer_name)

@app.route('/admin')
def admin():
    return render_template('admin.html')

# ========== API: 歌手 ==========
@app.route('/api/singers')
def api_singers():
    return jsonify(get_singers())

@app.route('/api/singer/<name>')
def api_singer_detail(name):
    singers = get_singers()
    singer = next((s for s in singers if s['name'] == name), None)
    if not singer:
        return jsonify({"error": "歌手不存在"}), 404
    songs = [s for s in get_songs() if s['singer'] == name]
    return jsonify({**singer, "songs": songs})

@app.route('/api/singer', methods=['POST'])
def api_add_singer():
    data = request.json or request.form
    name = data.get('name', '').strip()
    if not name:
        return jsonify({"error": "歌手名不能为空"}), 400
    singers = get_singers()
    if any(s['name'] == name for s in singers):
        return jsonify({"error": "歌手已存在"}), 400
    singer = {
        "id": str(uuid.uuid4())[:8],
        "name": name,
        "avatar": data.get('avatar', ''),
        "intro": data.get('intro', '')
    }
    singers.append(singer)
    save_singers(singers)
    return jsonify(singer)

@app.route('/api/singer/<sid>', methods=['DELETE'])
def api_delete_singer(sid):
    singers = get_singers()
    singers = [s for s in singers if s['id'] != sid]
    save_singers(singers)
    return jsonify({"ok": True})

@app.route('/api/singer/<sid>', methods=['PUT'])
def api_update_singer(sid):
    data = request.json
    singers = get_singers()
    for s in singers:
        if s['id'] == sid:
            s.update({k: v for k, v in data.items() if k in ['name', 'avatar', 'intro']})
            break
    save_singers(singers)
    return jsonify({"ok": True})

# ========== API: 歌曲 ==========
@app.route('/api/songs')
def api_songs():
    singer = request.args.get('singer')
    songs = get_songs()
    if singer:
        songs = [s for s in songs if s['singer'] == singer]
    return jsonify(songs)

@app.route('/api/song', methods=['POST'])
def api_add_song():
    data = request.json or request.form
    name = data.get('name', '').strip()
    singer = data.get('singer', '').strip()
    if not name or not singer:
        return jsonify({"error": "歌名和歌手不能为空"}), 400
    songs = get_songs()
    song = {
        "id": str(uuid.uuid4())[:8],
        "name": name,
        "singer": singer,
        "album": data.get('album', ''),
        "cover": data.get('cover', ''),
        "mp3_url": data.get('mp3_url', ''),
        "lrc_url": data.get('lrc_url', ''),
        "duration": int(data.get('duration', 0))
    }
    songs.append(song)
    save_songs(songs)
    return jsonify(song)

@app.route('/api/song/<sid>', methods=['DELETE'])
def api_delete_song(sid):
    songs = get_songs()
    songs = [s for s in songs if s['id'] != sid]
    save_songs(songs)
    return jsonify({"ok": True})

# ========== API: 歌单 ==========
@app.route('/api/playlists')
def api_playlists():
    return jsonify(get_playlists())

@app.route('/api/playlist/<pid>')
def api_playlist_detail(pid):
    playlists = get_playlists()
    pl = next((p for p in playlists if p['id'] == pid), None)
    if not pl:
        return jsonify({"error": "歌单不存在"}), 404
    songs = get_songs()
    pl_songs = [s for s in songs if s['id'] in pl.get('songs', [])]
    return jsonify({**pl, "song_list": pl_songs})

@app.route('/api/playlist', methods=['POST'])
def api_add_playlist():
    data = request.json or request.form
    name = data.get('name', '').strip()
    if not name:
        return jsonify({"error": "歌单名不能为空"}), 400
    playlists = get_playlists()
    pl = {
        "id": str(uuid.uuid4())[:8],
        "name": name,
        "cover": data.get('cover', ''),
        "intro": data.get('intro', ''),
        "songs": data.get('songs', [])
    }
    playlists.append(pl)
    save_playlists(playlists)
    return jsonify(pl)

@app.route('/api/playlist/<pid>', methods=['DELETE'])
def api_delete_playlist(pid):
    playlists = get_playlists()
    playlists = [p for p in playlists if p['id'] != pid]
    save_playlists(playlists)
    return jsonify({"ok": True})

# ========== API: 搜索 ==========
@app.route('/api/search')
def api_search():
    q = request.args.get('q', '').strip()
    stype = request.args.get('type', 'all')  # all, song, singer
    if not q:
        return jsonify({"songs": [], "singers": []})
    songs = get_songs()
    singers = get_singers()
    result = {"songs": [], "singers": []}
    if stype in ['all', 'song']:
        result['songs'] = [s for s in songs if q in s['name'] or q in s['singer']]
    if stype in ['all', 'singer']:
        result['singers'] = [s for s in singers if q in s['name']]
    return jsonify(result)

# ========== API: 热门 ==========
@app.route('/api/hot')
def api_hot():
    songs = get_songs()
    return jsonify(songs[:20])

# ========== API: .core 格式生成 ==========
@app.route('/api/core/<song_id>')
def api_get_core(song_id):
    """生成标准.core格式的JSON描述（供APP下载）"""
    songs = get_songs()
    song = next((s for s in songs if s['id'] == song_id), None)
    if not song:
        return jsonify({"error": "歌曲不存在"}), 404
    base_url = request.host_url.rstrip('/')
    core = {
        "name": song['name'],
        "singer": song['singer'],
        "album": song.get('album', ''),
        "type": "song",
        "mp3": song.get('mp3_url', ''),
        "cover": song.get('cover', ''),
        "lrc": song.get('lrc_url', ''),
        "duration": song.get('duration', 0)
    }
    return jsonify(core)

# ========== 文件上传 ==========
@app.route('/upload', methods=['POST'])
def upload():
    if 'file' not in request.files:
        return jsonify({"error": "没有文件"}), 400
    f = request.files['file']
    if f.filename == '':
        return jsonify({"error": "没有选择文件"}), 400
    category = request.form.get('category', 'misc')
    save_dir = os.path.join(UPLOAD_DIR, category)
    os.makedirs(save_dir, exist_ok=True)
    filename = secure_filename(f.filename)
    filepath = os.path.join(save_dir, filename)
    f.save(filepath)
    return jsonify({"url": f"/uploads/{category}/{filename}"})

@app.route('/uploads/<path:filename>')
def serve_upload(filename):
    return send_from_directory(UPLOAD_DIR, filename)

# ========== 静态文件 ==========
@app.route('/static/<path:filename>')
def serve_static(filename):
    return send_from_directory('static', filename)

if __name__ == '__main__':
    print("=" * 50)
    print("CorPlayer 音乐网站启动")
    print("首页: http://localhost:5000/")
    print("APP页: http://localhost:5000/app/index.html")
    print("后台: http://localhost:5000/admin")
    print("=" * 50)
    app.run(host='0.0.0.0', port=5000, debug=True)
