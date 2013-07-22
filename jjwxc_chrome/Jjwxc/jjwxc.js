var JJWXC_QUERY_URL = 'http://www.jjwxc.net/search.php';
var JJWXC_QUERY_TYPE = {
    "作品":"1",    
    "作者":"2",  
    "主角":"4",  
    "配角":"5", 
    "其他":"6"
};

function getGBKEscape(s) {
    var iframe=document.createElement("iframe");  
    iframe.src="about:blank";  
    iframe.setAttribute("style","display:none;visibility:hidden;");  
    document.body.appendChild(iframe);  
    var d=iframe.contentWindow.document;  
    d.charset=d.characterSet="gbk";  
    d.write("<body><a href='?"+s+"'>gbk</a></body>");  
    d.close();  
    var url=d.body.firstChild.href;
    var gbk = url.substr(url.lastIndexOf("?")+1);  
    document.body.removeChild(iframe);
    return gbk;
}

function jjwxc_query_ljj(type){ 
    var func = function(info, tab){
        var t = JJWXC_QUERY_TYPE[type];
        var kw = encodeURIComponent(getGBKEscape(info.selectionText));
        var url = JJWXC_QUERY_URL + '?t=' + t + '&kw=' + kw;
        window.open(url);
    };
    return func;
}

function jjwxc_query_google(info, tab){
    keyword = encodeURIComponent(info.selectionText);
    var num=20;
    var url='http://www.google.com.hk/custom?hl=zh-CN&newwindow=1&client=google-coop-np&cof=AH%3Aleft%3BS%3Ahttp%3A%2F%2Fwww.google.com%2Fcoop%2Fcse%3Fcx%3D002715881505881904928%3Alxsfdlsvzng%3BCX%3A%25E5%25B0%258F%25E8%25AF%25B4drama%3BL%3Ahttp%3A%2F%2Fmy1.photodump.com%2Fbubble7733%2Fpapaf-T.jpg%3BLH%3A98%3BLP%3A1%3BVLC%3A%23551a8b%3BGFNT%3A%23666666%3BDIV%3A%23cccccc%3B&adkw=AELymgXCCBA1xJdtdDsFAhFwECh_DAMPJDAJ4hfZjXU-zTjN8MqejYQvBdivNO4IgqCpVwz8hq4IUd8ZMj8fo2iIMQQDCi9UMzeobo-FUgk9jQIfIyiCNCI&btnG=Google+%E6%90%9C%E7%B4%A2&cx=002715881505881904928%3Alxsfdlsvzng&num='+num+'&q='+keyword;
    window.open(url);
};

var jjwxc_menu = chrome.contextMenus.create({"title": "绿晋江","contexts":["all"]});
var jjwxc_submenu_google = chrome.contextMenus.create({"title": "模糊","parentId":jjwxc_menu,"contexts":["selection"],"onclick":jjwxc_query_google});

for (var type in JJWXC_QUERY_TYPE){
    var func = jjwxc_query_ljj(type);
chrome.contextMenus.create({
        "title": type,
        "parentId":jjwxc_menu,
        "contexts":["selection"],
        "onclick": func 
    });
}
