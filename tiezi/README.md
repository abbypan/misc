帖子处理
========

## discuz_to_html.pl 

从mysql后台将discuz论坛的贴子批量导出为html

配置 discuz_to_html.pl 中 config 部分，直接perl执行即可

## tiezi_discuz_cjj.pl

下载CJJ的帖子
站点：CJJ, discuz 6 左右的版本
用法：./tiezi_discuz_cjj.pl -s http://xxx.xxx.xxx -u username -p password
注：停止更新

## tiezi_hjj.pl

下载红晋江的帖子

红晋江 http://bbs.jjwxc.net

在tiezi目录下执行 perl tiezi_hjj.pl -h

注：功能移入 Novel::Robot

## discuz_load_html.pl

将下载的帖子导入discuz，自动新建帐号

例子：将帖子author-subject.html的内容导入版块3(fid=3)

1、在LoadThread目录下配置SiteConfig.pm

2、在tiezi目录下执行 perl discuz_load_html.pl 3 author-subject.html


## discuz_backup_attach.pl

有mysql帐号，无ftp帐号，备份discuz论坛附件

例子：备份论坛附件到dest_backup_dir目录

1、在LoadThread目录下配置SiteConfig.pm

2、在tiezi目录下执行 perl backup_discuz_forum_attach.pl dest_backup_dir

## 安装

discuz_to_html.pl : cpanm SimpleDBI Encode::Locale Novel::Robot::Packer

其他pl : cpanm HTML::Template::Expr Date::Calc Teng

windows环境下：需要用到mkdir和curl
mkdir win32版本：http://unxutils.sourceforge.net/
curl win32版本：http://curl.haxx.se/latest.cgi?curl=win32-nossl
