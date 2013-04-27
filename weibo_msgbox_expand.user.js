// --------------------------------------------------------------------
//
// ==UserScript==
// @name          weibo_msgbox_expand
// @namespace     http://abbypan.github.com/
// @description   微博消息箱展开
// @include       http://www.weibo.com/*
// @include       http://weibo.com/*
// @copyright     2013+, Abby Pan (http://abbypan.github.com/)
// @version       0.1
// @author        Abby Pan (abbypan@gmail.com)
// @homepage      http://abbypan.github.com/
//
// ==/UserScript==
//

function getDivFromA (xpath) {
    var at = document.evaluate(
            xpath,
            document,
            null,
            XPathResult.UNORDERED_NODE_SNAPSHOT_TYPE,
            null);
    var atA = at.snapshotItem(0);
    return atA;
}

function ctlDisplayDiv (xpath, isDisplay) {
    var at = getDivFromA(xpath);
    var atDiv = at.parentNode;
    if(isDisplay){
        at.setAttribute('node-type', 'lev');
        atDiv.setAttribute('style', '');
        atDiv.setAttribute('class', 'lev');
    }else{
        atDiv.setAttribute('style', 'display:none');
    }
    return atDiv;
}

// @
var atDiv = ctlDisplayDiv('//a[@nm="mention_all"]', 1); 

//评论
ctlDisplayDiv('//a[@nm="cmt_all"]', 1); 

//私信
ctlDisplayDiv('//a[@nm="dm"]',1); 

//消息
ctlDisplayDiv('//a[@nm="messagebox_c"]',0);

//收藏
ctlDisplayDiv('//a[@href="/fav?leftnav=1&wvr=5"]',0);

//密友
ctlDisplayDiv('//a[@href="/mymeyou?ismiyou=1&wvr=5&step=2"]',0);
