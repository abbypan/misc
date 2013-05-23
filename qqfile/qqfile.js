//---------------------------------------------------//
//全局变量
var fileInfo;
var currentID;

//---------------------------------------------------//
//无限下载模式
var ReqDownloadUrl = new QMAjaxRequest;
ReqDownloadUrl.method = "GET";
ReqDownloadUrl.onComplete = ReqDownloadUrlSuccess;
ReqDownloadUrl.onError = ReqDownloadUrlError;
function ReqDownloadUrlSuccess(xml) {
    var adl = xml.responseText.split("|");

    if (adl[0] != "error" && xml.responseText.indexOf("http://") == 0) {
        var iK = adl[0];
        var ail = adl[1];
        iK = iK.replace(/#/g, "_");
        fileInfo[currentID].cmd=genDownloadCmd(fileInfo[currentID], iK, ail);
    }
    ReqDownloadUrlProcess();
}

function ReqDownloadUrlError(xml) {
    ReqDownloadUrlProcess();
}

function ReqDownloadUrlProcess() {
    currentID++;

    if (currentID >= fileInfo.length) {
        getCrackCode();
        return;
    }

    var f = fileInfo[currentID];
    document.getElementById('crackInfo').innerHTML = "正在生成 " + f.fname + " 的无限提取地址......";

    ReqDownloadUrl.url = "/cgi-bin/ftnGetDownload?sid=" + top.GetSid() + "&t=exs_ftn_getfiledownload&fid=" + f.fid + "&code=" + f.code + "&k=" + f.key + "&groupid=" + "&r=" + Math.random();
    ReqDownloadUrl.send();
}
//---------------------------------------------------//
//消息处理
function getCrackCode() {
    //最终处理函数，将下载指令写入文件，将文件消息写入剪贴板
     filePath = document.getElementById('input_genCrackCode1').value;

     var fileCmd=genCmd(fileInfo);
     saveTextFile(filePath, fileCmd);

     var n_reg = new RegExp('([^\\\\\\\/]+)$');
     var m = filePath.match(n_reg);
     var fileName=m[1];

     var fileMsg=genMsg(fileName,fileInfo);
     alert(fileMsg);
     copyToClipboard(fileMsg);

    var crackInfo = document.getElementById('crackInfo');
    crackInfo.parentNode.removeChild(crackInfo);
}

function genMsg(fileName,info){
//最后输出消息
    var msg = "解压附件，执行其中的"+fileName+"即可自动下载以下"+ info.length + "个文件：\n";
    for (var i=0;i<info.length;i++)
    {
        var j=i+1;
    msg+=  j + " : "+info[i].fname+", "+info[i].fsize+"\n";  
    }
    return msg;
}


function genCmd(info){
//下载文件的指令
    var cmd=""; 
    for (var i=0;i<info.length;i++)
    {
    cmd+=  info[i].cmd+"\r\n";  
    }
    return cmd;
}
//---------------------------------------------------//
function event_genCrackCode() {
    //无限下载模式
    var length = getSelectedFileInfo();
    if (length == 0) return;
    currentID = -1;
    var crackInfo = document.createElement('span');
    crackInfo.setAttribute('id', 'crackInfo');
    crackInfo.setAttribute('style', 'color:red');
    //var info = isFoxmail ? document.getElementById('count_download').parentNode: document.getElementsByTagName('tr')[0];
    var info = document.getElementsByTagName('tr')[0];
    info.appendChild(crackInfo);
    ReqDownloadUrlProcess();
}
//---------------------------------------------------//
function genDownloadCmd(f, url, code) {
//生成单个文件下载信息
    url = encodeURI(url);
    url = url.replace(/%26/g,'&');

    var ref= "http://m348.mail.qq.com/cgi-bin/frame_html?sid=" ;

   // var cmd = 'wget -c --referer="'+ ref + '" --header="Cookie: FTN5K='+ code + '" "'+ url + '" -O "' + f.fname + '"';
 var cmd = 'curl -C - -H "Referer:'+ ref + '" -H "Cookie: FTN5K='+ code +
	    '" "'+ url + '" -o "' + f.fname + '"';
    return cmd;
}
//---------------------------------------------------//
//function event_genNormalCode() {
    ////提取码模式
    //var length = getSelectedFileInfo();
    //if (length == 0) return;
    //var normalUrl = 'http://mail.' + mailType + '.com/cgi-bin/ftnExs_download?t=exs_ftn_download&';
    //fileCode = "";
    //fileMsg = "成功拷贝提取码地址至剪贴板，包含文件如下：\n";

    //for (var i = 0; i < length; i++) {
        //var f = fileInfo[i];
        //var url = normalUrl + 'k=' + f.key + '&code=' + f.code;
        //genFileCode(f, url);
    //}

    //copyToClipboard(fileCode, fileMsg);
//}
//---------------------------------------------------//
function getSelectedFileInfo() {
    //取出选中的文件的信息
    fileInfo = new Array();

    var _file = S(ftData.container.fileList).getElementsByTagName("input");

    for (var i = 0; i < _file.length; i++) {
        if (_file[i].type == "checkbox" && _file[i].name == "fid" && _file[i].checked) {
            var children = _file[i].parentNode.parentNode.getElementsByTagName('td');
           var first_td = children[2].getElementsByTagName('a')[0];
            if(first_td.getAttribute("onclick")){
             var clickInfo =    first_td.getAttribute("onclick").split("'");
            fileInfo.push({
            fname : clickInfo[3],

                fsize: children[3].innerHTML.replace(/^\s+/, "").replace(/\s+$/, ""),
                fid :  clickInfo[1].replace(/#/g,"%23"),

                code : clickInfo[5],

              key: clickInfo[7],

            });
        }        
        else {
                         var clickInfo =    first_td.getAttribute("href").split(/[?&=]/);
               var fidinfo = children[2].getElementsByTagName('a')[1].getAttribute("onclick").split("'");
                   var fname = children[2].getElementsByTagName('div')[0].getAttribute("title");
            fileInfo.push({
            fname : fname,
 fid :  fidinfo[1].replace(/#/g,"%23"),
                fsize: children[3].innerHTML.replace(/^\s+/, "").replace(/\s+$/, ""),
               

                code : clickInfo[6],

              key: clickInfo[2],

            });

        }
        }
    }
    return fileInfo.length;
}
//---------------------------------------------------//
function copyToClipboard(msg) {
    //把txt拷贝到剪贴板，并弹出msg
    if (window.clipboardData) {
        window.clipboardData.clearData();
        window.clipboardData.setData("Text", msg);
    } else if (navigator.userAgent.indexOf("Opera") != -1) {
        window.location = msg;
    } else if (window.netscape) {
        try {
            netscape.security.PrivilegeManager.enablePrivilege("UniversalXPConnect");
        } catch(e) {
            alert("被浏览器拒绝！\n请在浏览器地址栏输入'about:config'并回车\n然后将'signed.applets.codebase_principal_support'设置为'true'");
        }
        var clip = Components.classes['@mozilla.org/widget/clipboard;1'].createInstance(Components.interfaces.nsIClipboard);
        if (!clip) return;
        var trans = Components.classes['@mozilla.org/widget/transferable;1'].createInstance(Components.interfaces.nsITransferable);
        if (!trans) return;
        trans.addDataFlavor('text/unicode');
        var str = new Object();
        var len = new Object();
        str = Components.classes["@mozilla.org/supports-string;1"].createInstance(Components.interfaces.nsISupportsString);
        var copytext = msg;
        str.data = copytext;
        trans.setTransferData("text/unicode", str, copytext.length * 2);
        var clipid = Components.interfaces.nsIClipboard;
        if (!clip) return false;
        clip.setData(trans, null, clipid.kGlobalClipboard);
        //alert(msg);
    }
}
//---------------------------------------------------//
function saveTextFile(path, content)
{ 
//保存文件的函数

try
{
netscape.security.PrivilegeManager.enablePrivilege('UniversalXPConnect');
}
catch (e) {
    alert("失败，请打开about:config，将signed.applets.codebase_principal_support设置为true"); return 0;
}

  var file = Components.classes["@mozilla.org/file/local;1"]
                    .createInstance(Components.interfaces.nsILocalFile);
                file.initWithPath( path );
                if ( file.exists() == false ) {
                    //alert( "Creating file... " );
                    file.create( Components.interfaces.nsIFile.NORMAL_FILE_TYPE, 420 );
                }
                var outputStream = Components.classes["@mozilla.org/network/file-output-stream;1"]
                    .createInstance( Components.interfaces.nsIFileOutputStream );


                outputStream.init( file, 0x04 | 0x08 | 0x20, 420, 0 );

                 var converter = Components.classes["@mozilla.org/intl/scriptableunicodeconverter"]
                                .createInstance(Components.interfaces.nsIScriptableUnicodeConverter);
                //converter.charset = 'UTF-8';
                converter.charset = 'GBK';

                var convSource = converter.ConvertFromUnicode(content);
                var result = outputStream.write( convSource, convSource.length );
                outputStream.close();
}
