#SingleInstance Force 
#NoEnv 

Gui -minimizebox w600 h300  
Gui Margin, 0, 0 
Gui Add, Edit, w540 R20 vQQ, 在此贴上html代码... 
Gui Add, Button, x0 y290 gBtnRunQQ, QQ 
Gui Add, Button, x30 y290 gBtnRunFoxmail, Foxmail 
Gui Add, Button, x90 y290 gBtnRunFS, FS2YOU 
Gui, Show, , 网盘HTML代码转换成论坛代码  
return 

BtnRunFoxmail: 
Gui Submit, NoHide 
Length := Strlen(QQ) 
Left :=1 

Loop { 
    Left := RegExMatch(QQ, "<div style=.. ","",Left) 
    IfEqual %Left%,0 
          break 
    Right :=RegExMatch(QQ, "</div>","",Left) 
    Temp := SubStr(QQ,Left,Right) 

    FileName :=  RegExReplace(Temp, "^.*?;. title=.([^>]*?).>.*$", "$1")   
    Href :=  RegExReplace(Temp, "^.*?event, .([^>]*?)', .*$", "$1")   
    Id :=  RegExReplace(Temp, "^.*?Global.uin ,'(.*?)' .*$", "$1")   
    ;Code = [url=%Href%]%FileName%[/url],提取码：%Id%`n`n%Code% 
    Code = %FileName%`n%Href%`n(提取码：%Id%)`n`n%Code% 

    Left = %Right% + 1 
} 

GuiControl, , QQ, %Code% 
return 

BtnRunQQ: 
Gui Submit, NoHide 
Length := Strlen(QQ) 
Left :=1 

Loop { 
    Left := RegExMatch(QQ, "<div class=.ft_file.>","",Left) 
    IfEqual %Left%,0 
          break 
    Right :=RegExMatch(QQ, "</table>","",Left) 
    Temp := SubStr(QQ,Left,Right) 

    FileName :=  RegExReplace(Temp, "^.*?title=.([^>]*?). class=.fName txtflow.>.*$", "$1")   
    Href :=  RegExReplace(Temp, "^.*?href=.([^>]*?).>直接下载<\/a>.*$", "$1")   
    Id :=  RegExReplace(Temp, "^.*?<span class=.addrtitle.>\(提取码 (.*?)\)<\/span>.*$"
, "$1")   
    ;Code = [url=%Href%]%FileName%[/url],提取码：%Id%`n`n%Code% 
    Code = %FileName%`n%Href%`n(提取码：%Id%)`n`n%Code% 

    Left = %Right% + 1 
} 

GuiControl, , QQ, %Code% 
return 


BtnRunFS: 
Gui Submit, NoHide 
Length := Strlen(QQ) 
Left :=1 

Loop { 
    Left := RegExMatch(QQ, "<tr class=.row5.>","",Left) 
    IfEqual %Left%,0 
          break 
    Right :=RegExMatch(QQ, "</a>\s*</td>","",Left) 
    Temp := SubStr(QQ,Left,Right) 

     Href :=  RegExReplace(Temp, "^.*?href=.(http://www.fs2you.com/[^>]*?).>.*$", "$1")   

     FileName :=  RegExReplace(Temp, "^.*<div style=.overflow: hidden;.>(.*?)</div>.*$", "$1")   
    ;Code = [url=%Href%]%FileName%[/url] 
    Code = %FileName%`n%Href%`n`n%Code% 
    Left = %Right% + 1 
} 

GuiControl, , QQ, %Code% 
return 

GuiClose: 
ExitApp 
