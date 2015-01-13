// Copyright (c) 2009, Abby Pan :: abbypan [at] gmail.com
//
// ==UserScript==
// @name           jjwxc-vip-img2text
// @namespace      http://abbypan.blogspot.com
// @description    将绿晋江VIP章节中的水印图片转换成文字
// @include        http://my.jjwxc.com/*
// @include        http://my.jjwxc.net/*
// ==/UserScript== 

//图片对应的文本
replaceText = {
    '%86%D9%E2':'一',
    '%8A%DE%FB':'这',
    '%87%C5%CB':'天',
    '%85%E3%DB':'点',
    '%8A%CE%D6':'说',
    '%87%C4%D1':'女',
    '%84%E9%F3':'我',
    '%87%F2%C4':'哦',
    '%86%DC%C2':'你',
    '%87%C4%DB':'她',
    '%85%F5%D5':'男',
    '%86%DB%E4':'了',
}; 

//所有的图片对象
var allImg = document.evaluate(
        '//img[@src]',
        document,
        null,
        XPathResult.UNORDERED_NODE_SNAPSHOT_TYPE,
        null); 

//图片地址匹配的正则式
var regex = /gdcv\.php\?c\=(.+)/;  

for(i=0;i<allImg.snapshotLength;i++){
    var thisImg=allImg.snapshotItem(i); 

    var matchs = thisImg.src.match(regex);
    if(matchs != null){
        //建立对应的文本对象
        var text= document.createTextNode(replaceText[matchs[1]]);
        //将当前图片替换为文本
        thisImg.parentNode.replaceChild(text,thisImg);
    }
}
