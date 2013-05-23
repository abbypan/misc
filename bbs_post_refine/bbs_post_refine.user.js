// --------------------------------------------------------------------
//
// ==UserScript==
// @name          BBS_Post_Refine
// @namespace     http://abbypan.blogspot.com/
// @description   论坛帖子内容提炼
// @copyright     2009+, Abby Pan (http://abbypan.blogspot.com/)
// @author        Abby Pan (abbypan@gmail.com)
// @homepage      http://abbypan.blogspot.com/
// @version       0.2
// @include       *thread*
// @require       mootools_greasemonkey.js
// @require       bbs_post.js
// ==/UserScript==
// --------------------------------------------------------------------

//命令菜单
GM_registerMenuCommand('BBS_THREAD_Refine_Poster', function() {refinePost(1)});
GM_registerMenuCommand('BBS_THREAD_Refine_ALL', function() {refinePost()});

function refinePost(isOnlyPoster){
var bbs = null;
var addr = document.location.href;
if(addr.match(/viewthread|thread-\d+-/)){
	bbs = new PageDiscuz();
}

if(!bbs) return;
bbs.refineContent(isOnlyPoster);
}
