baidu_music_collect
=================
把指定 音乐列表 导入 百度音乐 收藏，省得私人音乐频道猜来猜去

用法示例
--------

假设脚本位于 d:\baidu_music，其中 

- someusr 为用户名，somepasswd 为密码
- cookie.txt 为存放该用户cookie的文件名
- music.txt 为希望收藏的音乐，一行一首，歌名在前（必填），歌手在后（可不填）

```
d:

cd d:\baidu_music

casperjs baidu_login.js someusr somepasswd cookie.txt

casperjs baidu_music_collect.js cookie.txt music.txt
```
![baidu_music.png](baidu_music.png)


问题
----

目前 artist 匹配较严，如果查"水晶 任贤齐"，取回结果为"水晶 任贤齐/徐怀珏"，是不做收藏的


安装 phantomjs
--------------

http://phantomjs.org/

windows下需要把 phantomjs 目录加入PATH环境变量

安装 casperjs
-------------

http://casperjs.org/

windows下需要把 casperjs/batchbin 目录加入PATH环境变量
