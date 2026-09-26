# CorPlayer 音乐播放器

## 项目结构
```
corplayer/
├── website/          # 音乐网站（Flask后端）
│   ├── app.py        # 后端API
│   ├── templates/    # 页面模板
│   │   ├── index.html      # 网站首页
│   │   ├── app_index.html  # APP推荐搜索页
│   │   ├── geshou.html     # 歌手详情页
│   │   └── admin.html      # 后台管理
│   ├── data/         # JSON数据存储
│   ├── uploads/      # 上传文件
│   └── requirements.txt
└── ios/              # iOS客户端
    ├── CorPlayer/    # 源码
    ├── project.yml   # XcodeGen配置
    └── .github/workflows/build.yml  # GitHub Actions编译
```

## 网站部署
```bash
cd website
pip install -r requirements.txt
python3 app.py
```
- 首页: http://localhost:5000/
- APP页: http://localhost:5000/app/index.html
- 后台: http://localhost:5000/admin

## iOS客户端功能
- 底部导航：首页 / 队列 / 我的
- 首页：WKWebView加载 music.asinino.cn/app/index.html
- cormusic:// 协议拦截，自动解析 .core 格式
- 音乐播放器：播放/暂停/上一首/下一首/进度条/歌词
- 播放模式：列表循环/单曲循环/随机播放
- 播放队列管理：添加/移除/排序
- 下载到本地播放
- 本地音乐管理

## .core 格式
```
song.core/
├── config.json   # 歌曲信息（name, singer, album, mp3, cover, lrc）
├── info.mp3      # 音频文件
├── info.png      # 专辑封面
└── info.lrc      # 滚动歌词
```
config.json 可包含 `url` 字段实现云端重定向（递归解析）。

## .cores 格式（合集/专辑/歌单）
```
album.cores/
├── config.json   # 合集信息（type, 歌曲列表）
├── jianjie.txt   # 介绍
├── info.png      # 封面
└── song1.core/   # 多首歌曲
```
