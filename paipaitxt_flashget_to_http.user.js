// PaiPaiTXT 
// version 0.1 
// 2009-03-18 
// Copyright (c) 2009, AbbyPan 
// -------------------------------------------------------------------- 
// 
// ==UserScript== 
// @name          PaiPaiTXT 
// @namespace     http://abbypan.blogspot.com/ 
// @description   Convert flashget:// To http:// 
// @include       http://www.paipaitxt.com/* 
// ==/UserScript== 

var allLinks, thisLink, flashget; 

allLinks = document.evaluate( 
        "//a[@href='javascript:void(0);']", 
        document, 
        null, 
        XPathResult.ORDERED_NODE_SNAPSHOT_TYPE, 
        null); 


for (var i = 0; i < allLinks.snapshotLength; i++) { 
    thisLink = allLinks.snapshotItem(i); 
    flashget = thisLink.getAttribute('fg'); 
    flashget = decode_flashget(flashget); 
    thisLink.setAttribute('href', flashget); 
    thisLink.setAttribute('onClick', flashget); 
    thisLink.setAttribute('oncontextmenu', flashget); 

} 

function decode_flashget(src){ 
    //来源：http://www.cnblogs.com/mier001/archive/2009/02/01/1381891.html 
    var str; 
    str=src.replace(/flashget:\/\//i,"").replace(/\&.*$/,""); 
        str = decode_base64(str); 
    return str.replace(/\[\/?flashget\]/ig,""); 

} 

function decode_base64(src){ 
    //来源：http://bbs.bccn.net/thread-107182-1-1.html 
    var deKey= new Array( 
            -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 
            -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 
            -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 62, -1, -1, -1, 63, 
            52, 53, 54, 55, 56, 57, 58, 59, 60, 61, -1, -1, -1, -1, -1, -1, 
            -1, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 
            15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, -1, -1, -1, -1, -1, 
            -1, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 
            41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, -1, -1, -1, -1, -1 
            ); 

    //用一个数组来存放解码后的字符。 
    var str=new Array(); 
    var ch1, ch2, ch3, ch4; 
    var pos=0; 
    //过滤非法字符，并去掉'='。 
    src=src.replace(/[^A-Za-z0-9\+\/]/g, ''); 
    //decode the source string in partition of per four characters. 
    while(pos+4<=src.length){ 
        ch1=deKey[src.charCodeAt(pos++)]; 
        ch2=deKey[src.charCodeAt(pos++)]; 
        ch3=deKey[src.charCodeAt(pos++)]; 
        ch4=deKey[src.charCodeAt(pos++)]; 
        str.push(
                String.fromCharCode( 
                    (ch1<<2&0xff)+(ch2>>4), (ch2<<4&0xff)+(ch3>>2), (ch3<<6&0xff)+ch4)
                ); 
    } 
    //给剩下的字符进行解码。 
    if(pos+1<src.length){ 
        ch1=deKey[src.charCodeAt(pos++)]; 
        ch2=deKey[src.charCodeAt(pos++)]; 
        if(pos<src.length){ 
            ch3=deKey[src.charCodeAt(pos)]; 
            str.push(
                    String.fromCharCode((ch1<<2&0xff)+(ch2>>4), (ch2<<4&0xff)+(ch3>>2))
                    ); 
        }else{ 
            str.push(String.fromCharCode((ch1<<2&0xff)+(ch2>>4))); 
        } 
    } 
    //组合各解码后的字符，连成一个字符串。 
    return str.join(''); 
} 
