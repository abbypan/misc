// --------------------------------------------------------------------
//
// ==UserScript==
// @name          weibo_msgbox_expand
// @namespace     http://abbypan.github.io/
// @description   微博消息箱展开
// @include       http://weibo.com/*
// @include       http://www.weibo.com/*
// @copyright     2013+, Abby Pan (http://abbypan.github.io/)
// @version       0.2
// @author        Abby Pan (abbypan@gmail.com)
// @homepage      http://abbypan.github.io/
//
// ==/UserScript==
//

function getElement (xpath) {
    var at = document.evaluate(
            xpath,
            document,
            null,
            XPathResult.UNORDERED_NODE_SNAPSHOT_TYPE,
            null);
    var atA = at.snapshotItem(0);
    return atA;
}

function add_url(box, url, text){
    var t = document.createTextNode(text);

    var at_span = document.createElement("span");
    at_span.setAttribute('class', 'levtxt');
    at_span.setAttribute('style', 'text-align : center;');
    at_span.appendChild(t);

    var at = document.createElement("a");
    at.setAttribute('class', 'S_txt1');
    at.setAttribute('node-type', 'item');
    at.setAttribute('href', url);
    at.appendChild(at_span);

    var at_h3 = document.createElement("h3");
    at_h3.setAttribute('class', 'lev');
    at_h3.appendChild(at);

    box.appendChild(at_h3);
}

var levbox = getElement('//div[@class="lev_Box lev_Box_noborder"]');
add_url(levbox, '/at/weibo?leftnav=1&wvr=6&nofilter=1', '@我');
add_url(levbox, '/comment/inbox?leftnav=1&wvr=6', '评论');
add_url(levbox, '/messages?leftnav=1&wvr=6', '私信');
