function getFirstMatch(elem, regex){
    var match = elem.match(regex);
    if(!match) return null;
    return match[1];
}

var Floor = new Class({
    initialize: function(fid, time, name, content){
        this.fid = fid;
        this.time = time;
        this.name = name;
        this.content = content;
    },
    floor : function(){
        this.content=this.content.replace(/<span\s+style="display:none">[\w\W]*?<\/span>/ig,"");
        this.content=this.content.replace(/<font[^>]*rgb\(255, 255, 255\)[^>]*>[\w\W]*?<\/font>/ig,"");
        this.content=this.content.replace(/[\s\n]*<br\s*\/?\s*>[\s\n]*/g,"\n").replace(/^\s*(.*?)\s*$/mg,"<p>$1</p>");
        var html='<div class="ftitle"><a name="fid'+this.fid+'">'        +this.fid+' '+this.name+' '+this.time        +'</a></div>'+"\n"        +'<div class="fcontent">'+"\n"        + this.content+"\n"+'</div>';
        //html=html.replace(/<font[^>]*>/ig,"<p>").replace(/<\/font>/ig,"<\/p>").replace(/<\/?strong>/,"");
        html=html.replace(/<font[^>]*>/ig,"").replace(/<\/font>/ig,"").replace(/<\/?strong>/,"");
        html=html.replace(/<p>\s*<\/p>\s*/gi,"");
        var div = new Element('div',{'class' : 'floor'});
        div.set('html',html);
        return div;
    },
    toc : function(){
        var html='<a href="#fid'+this.fid+'">'+this.name+' '+this.time+"</a>";
        var li = new Element('li');
        li.set('html',html);
        return li;
    }
});

var Page = new Class({
    initialize: function(){
        this.url=document.location.href;
        this.charset=document.characterSet;
        this.version = this.getVersion();
        this.baseUrl=this.getBaseUrl();
        this.posterID = this.getUid();
        this.title = this.getTitle();
        this.posterName = this.getPosterName();
        this.posterContent = new Array();
    },
    getVersion : function(){},
    getBaseUrl : function(){},
    getUid : function(){},
    getTitle : function(){}, 
    getPosterName : function () {},
    getPageNum : function(doc){},
    getInfoContainer : function() {},
    refineFloors: function(doc, userID){},
    pageUrl : function(pid,uid){},
    refineContent : function(onlyPoster){
        this.posterContent = new Array();

        var posterID = null;
        if(onlyPoster)  posterID = this.posterID;

        var banner = new Element('p', {id: 'refineInfo'});
        banner.set('style','color:red');
        banner.set('text','正在取第 ');
        banner.inject(this.getInfoContainer(),'before');

        var pageID = new Element('span', {id: 'pageID'});
        pageID.set('text',0);
        banner.adopt(pageID);
        banner.appendText(' 页，共 ');

        var num =this.getPageNum(document);

        var pageNum = new Element('span', {id: 'pageNum'});
        pageNum.set('text',num);
        banner.adopt(pageNum);
        banner.appendText(' 页');

        if(num > 0){
            this.refinePage(posterID);
        }
    },
refinePage: function(uid){
        var pageID = $('pageID').get('text').toInt() + 1;
        var pageNum = $('pageNum').get('text').toInt();

        if(pageID > pageNum){
            $('refineInfo').parentNode.removeChild($('refineInfo'));
            this.genPage();
            return;
        }

    $('pageID').set('text',pageID);

    var url=this.pageUrl(pageID,uid);

    var self=this;
GM_xmlhttpRequest({
  method: "GET",
  url: url,
 'overrideMimeType':"text/html; charset="+self.charset,
  onload: function(res) {
            var page = new Element('div');
            page.innerHTML = res.responseText;
            var num = self.getPageNum(page); 
            if(num !=pageNum)
              $('pageNum').set('text',num);

            var floors=self.refineFloors(page,uid);
            if(floors.length>0){
                self.posterContent.extend(floors);
            }
            self.refinePage(uid);
  },
  onerror : function(res){
            self.refinePage(uid);
  }
}
);
},
setStyle : function(node) {
    var css = ' body { '
+'        font-size: medium;'
+'		font-family: Verdana, Arial, Helvetica, sans-serif;'
+'        margin: .5em 2em .5em 2em;'
+'		line-height:150%;}'
+'	p { text-indent:2em; }'
+'    #banner {font-weight:bold;font-size:x-large;line-height:130%;text-align:center; }'
+'    #banner a {text-decoration:none; }'
+'	.ftitle {'
+'		border-top: .2em solid #ee9b73;'
+'		padding-top: .8em;'
+'margin: 1em 0em 1em 0em;'
+ 'font-weight:bold;'
+'		text-indent:0em;'
+'		font-size:medium;'
+'	}'
+'	ol {'
+'    line-height:150%;'
+'    padding-top:1em;'
+'    border-top:.2em solid #EE9B73;}'
+'	li { margin-left: 2em;}';
    var style = new Element('style');
    style.set('type' , 'text/css');
    style.set('html' , css);
    node.adopt(style);
},
genPage : function(){

    var head = document.getElement('head');
    head.erase('html');

    var title = new Element('title');
    title.set('text',this.title);
    head.adopt(title);
    this.setStyle(head);

    var body = document.getElement('body');
    body.erase('html');
    body.removeProperties('id','onkeydown');

        var banner  = new Element('div',{'id' : 'banner'});
        var html='<a id="url" href="'+this.url+'"><span id="poster">'+this.posterName+'</span>《<span id="title">'+this.title+'</span>》</a>';
        banner.set('html',html);
        body.adopt(banner);

        var toc = new Element('ol',{'id' : 'toc'});
        var content = new Element('div',{'id' : 'content'});
        var addElem = function(item) {
                var f = item.floor();
                content.adopt(f);
                var t = item.toc();
                toc.adopt(t);
        };
        this.posterContent.each(addElem);
        body.adopt(toc);
        body.adopt(content);
},

});

var PageDiscuz = new Class({
    Extends : Page,

   //initialize: function(){
         //this.parent();
   //},
   getVersion : function() {
        var version = document.getElement('meta[name="generator"]').get('content');
        if(version.match(/ 7\./)) return 7;
        return 6; 
   },
    getBaseUrl :function() {
        var url=getFirstMatch(this.url, /^(http.*tid=[0-9]+)/);
        if(!url){
           var domain =  getFirstMatch(this.url, /^(http.*\/)thread-/);
           var tid =   getFirstMatch(this.url, /thread-([0-9]+)/);
           url = domain + 'viewthread.php?tid=' + tid;
        }
             return url;
    },
    getUid: function (href) {  
        if(!href){
            var class = this.version == 7 ? '.postinfo' : '.postauthor';
            href= document.getElement(class).getElement('a').getAttribute('href');
        }
        var m=href.match(/(author|u)id[=-]([0-9]+)/);
        return m.length>1?m[2]:null;
    },
    getTitle : function(){
       var t = document.getElement('.title');
       if(!t)
        t=document.getElement('h1');
       return t.get('text');
    },
    getPosterName : function () {
        var class = this.version == 7 ? '.postinfo': '.postauthor';
        var name = document.getElement(class).getElement('a').get('text');
        return name;
    },
    getPageNum: function (doc){
        var pages=doc.getElement('div[class=pages]');
        if(!pages) return 1;

        if(this.version == 7){
            var num = pages.lastChild.previousSibling.innerHTML;
            return getFirstMatch(num,/(\d+)/).toInt();
        }

        var last = pages.lastChild;

        if(last.innerHTML.match(/^\d+$/)){
            var href = last.getAttribute('href');
            if(!href || href.match(/thread/))
                return last.innerHTML.toInt();
            return 1;
        }
   
        for(var i=0;i<2;i++){ 
        last = last.previousSibling;
        var num = getFirstMatch(last.innerHTML,/(\d+)$/);
        if(num) return num.toInt();
        }
        
    },
   getInfoContainer : function(){
        return $('nav');
   },
    refineFloors : function (doc, userID){
        var floors=[];

    if(this.version == 6) {
           var msgs = doc.getElements('div[class="t_msgfont"]');
           var times = doc.getElements('.postinfo');
           var authors = doc.getElements('.postauthor');
           var num = msgs.length;

            for(var i=0; i < num; i++){
                var j = 2*i;
                var author = authors[j].getElement('a[id^=userinfo]');
                var  uid = getFirstMatch(author.get('href'),/uid-(\d+)/);
                if( userID && (userID != uid) )
                    continue;
                var name = author.get('text');
                var fid = times[i].getElement('strong').get('text');
                var time = times[i].get('text').match(/(\d+-\d+-\d+ \d+:\d+)/)[1];
                var content = msgs[i].innerHTML;
                var floor = new Floor(fid, time, name, content);
                floors.push(floor);
            }
        }else{
        var msgs = doc.getElements('.t_msgfont');
        var infos= doc.getElements('.postinfo');
        var num = msgs.length;

        for(var i=0; i < num; i++){
            var j = 2*i;
            var link=infos[j].getElement('a');
            var uid = this.getUid(link.getAttribute('href'));
            if( userID && (userID != uid) )
                continue;
            var name = link.innerHTML;
            var tmp = infos[j+1]; 
            var time = tmp.getElement('em[id^=authorposton]').innerHTML.replace(/^.*? /,'');
            var fid=tmp.getElement('strong');
            fid=fid.get('text');
            var content=msgs[i].innerHTML;
            var floor = new Floor(fid, time, name, content);
            floors.push(floor);
        }
    }

   return floors;
},
    pageUrl : function(pid,uid){
        var url = this.baseUrl + '&page='+pid;
        if(uid)  url+='&authorid='+uid;
        return url;
    }
});
