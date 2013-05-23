// --------------------------------------------------------------------
//
// ==UserScript==
// @name          qqfile 
// @namespace     http://abbypan.blogspot.com/
// @description   将QQ文件中转站的下载地址批量提取成wget下载的bat文件
// @include       http://*.qq.com/cgi-bin/ftnExs_files*
// @include       https://*.qq.com/cgi-bin/ftnExs_files*
// @copyright     2010+, Abby Pan (http://abbypan.blogspot.com/)
// @resource      qqfile qqfile.js
// @version       0.3
// @author        Abby Pan (abbypan@gmail.com)
// @homepage      http://abbypan.blogspot.com/
//
// ==/UserScript==

addJs("qqfile");

var select_1 = document.getElementById('btn_send1');
addBtn(select_1,'无限提取','btn_genCrackCode1','event_genCrackCode()');
addInput(select_1,'e:\\qqfile.bat','input_genCrackCode1');

function addInput (node, value, id){
    //添加一个输入框
    var add;
    try{
        var str ='<input id="'+id+'" type="text" value="'+ value+'" />';
        add = document.createElement(str);
    }catch(err){
        add = document.createElement('input');
        add.setAttribute('id',id);
        add.setAttribute('type',"text");
        add.setAttribute('value',value);
    
    }
    node.parentNode.insertBefore(add,node.nextSibling);

}

function addBtn (node,value,id,func){
    //添加一个button
    var add;
    try{
    var str ='<input id="'+id+'" onclick="'+func+'" type="button" value="'+value+'" />';
        add = document.createElement(str);
    }catch(err){
        add = document.createElement('input');
        add.setAttribute('id',id);
        add.setAttribute('onclick',func);
        add.setAttribute('type',"button");
        add.setAttribute('value',value);
    
    }
    node.parentNode.insertBefore(add,node.nextSibling);
}

function addJs(js){
var text = GM_getResourceText(js);
var add = document.createElement('script');
add.setAttribute('type',"text/javascript");
add.appendChild(document.createTextNode(text));
document.getElementsByTagName('head')[0].appendChild(add);
}
