baidu_music_collect
=================
把 本地硬盘保存的音乐文件(flac/mp3)信息 导入 百度音乐 收藏，省得私人音乐频道猜来猜去


* 用法示例

假设脚本位于 d:\software\script\baidu_music，其中 

baidu_login.txt 为登录用户名及密码

baidu_music.txt 为希望收藏的音乐，一行一首歌，歌名在前（必填），歌手在后（可不填）

```
d:

cd d:\software\script\baidu_music

perl baidu_music.pl

```
![baidu_music.png](baidu_music.png)


* 问题

目前 artist 匹配较严，如果查"水晶 任贤齐"，取回结果为"水晶 任贤齐/徐怀珏"，是不做收藏的


** 安装 phantomjs

** 安装 casperjs

**  安装 perl

windows版本可选用：http://strawberryperl.com/
