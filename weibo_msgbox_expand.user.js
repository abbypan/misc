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


function displayDiv (xpath) {
    var at = getDivFromA(xpath);
    var atDiv = at.parentNode;

    at.setAttribute('node-type', 'lev');
    atDiv.setAttribute('style', '');
    atDiv.setAttribute('class', 'lev');

    return atDiv;
}

function noDisplayDiv (xpath) {
    var at = getDivFromA(xpath);
    var atDiv = at.parentNode;
    atDiv.setAttribute('style', 'display:none');
    return atDiv;
}

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

// @
displayDiv('//a[@nm="mention_all"]'); 

//评论
displayDiv('//a[@nm="cmt_all"]'); 

//私信
displayDiv('//a[@nm="dm"]'); 

//消息
noDisplayDiv('//a[@nm="messagebox_c"]');

//收藏
noDisplayDiv('//a[@href="/fav?leftnav=1&wvr=5"]');

//密友
noDisplayDiv('//a[@href="/mymeyou?ismiyou=1&wvr=5&step=2"]');
