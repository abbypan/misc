//abstract: login baidu with usr & passwd, write cookie to file
//usage: casperjs baidu_login.js someusr somepasswd cookie_file


var x = require('casper').selectXPath;
var fs = require('fs');
var system = require('system');
var utils = require('utils');

var casper = require('casper').create({
    //{logLevel: 'debug', verbose: true}, 
    pageSettings: {
        loadImages:  false,        
    loadPlugins: false  // not load NPAPI plugins (Flash, Silverlight, ...)
    }
}
);
casper.userAgent('Mozilla/5.0 (Windows NT 6.1; Win64; x64; rv:18.0) Gecko/20130119 Firefox/18.0');

casper.start('http://music.baidu.com');

// cli {{{
var usr = casper.cli.get("usr");
var passwd = casper.cli.get("passwd");
var cookie = casper.cli.get("cookie");
var music_search = casper.cli.get("music");
var music_id = casper.cli.get("id") ;
var music_url = casper.cli.get("url");
var music_wget = casper.cli.get("wget");
var music_playlist = casper.cli.get("playlist") ;
var level = casper.cli.get("level");
// }}}

// login {{{
casper.then(function(){
    if( utils.isUndefined(usr) || utils.isUndefined(passwd) ) return;

    console.log("begin login : "+usr);
    var login_url = 'https://passport.baidu.com/v2/?login&amp;tpl=mn&amp;u=http%3A%2F%2Fwww.baidu.com%2F';
    this.open(login_url)
        .thenClick('#pass-user-login')
        .thenEvaluate(function(usr,passwd) {
        document.querySelector('#TANGRAM__3__userName').setAttribute('value', usr);
        document.querySelector('#TANGRAM__3__password').setAttribute('value', passwd);
    }, { 'usr' : usr, 'passwd' : passwd })
        .thenClick('#TANGRAM__3__submit')
    .wait(1000, function () {
        console.log("finish login : "+usr);
    });
});
// }}}

// write_cookie {{{
casper.then(function () {
    if( utils.isUndefined(usr) ||  utils.isUndefined(passwd) ||  utils.isUndefined(cookie) ) return;
    console.log("write cookie file : " + cookie);
    var cookie_str = JSON.stringify(phantom.cookies);
    fs.write(cookie,cookie_str, 'w');
});
// }}}

// read_cookie {{{
casper.then(function () {
    if ( ! (utils.isUndefined(usr) &&  utils.isUndefined(passwd)) ||  utils.isUndefined(cookie) ) return;
    console.log("read cookie file : " + cookie);
    var data = fs.read(cookie);
    phantom.cookies = JSON.parse(data);
});
// }}}

// search for song id {{{
var search_list = new Array();
casper.then(function(){
 if( utils.isUndefined(music_search) || utils.isUndefined(music_id)  ) return;
 search_list = read_music_file(music_search);
 fs.write(music_id, '', 'w');
});
casper.eachThen(search_list, function(item){
        var title = item.data[0];
        var artist = item.data[1];
        var key = title;
        if(artist) key +=" "+artist;
        console.log("search song: " + key);

        this.thenOpen('http://music.baidu.com')
        .wait(1000, function(){
            this.fill('form[action="/search"]', { key : key }, true);
        })
        .wait(1000, function(){
            var song_x = artist ? '//a/em[text()="' + artist + '"]//ancestor::div[@class="song-item clearfix"]' : '';
            song_x +="//span[@class='song-title']//a[@title='" + title + "']";
            var song_xp = x(song_x);
            var artist_xp = x('//span[@class="author_list"]');
            if (this.exists(song_xp)) {
                var id = this.getElementAttribute(song_xp,'href');
                var song_id = id.replace(/#.*/, '').replace(/^.*\//, '');
                var artist = this.getElementAttribute(artist_xp, 'title');
                console.log('find song: '+ key + ' id ' + song_id);
                fs.write(music_id,[ artist, title, song_id , "\n"].join(" "), 'a'); 
            } 
        });
    });
    
// }}}


// search for song url {{{
var id_list = new Array();
casper.then(function(){
 if( utils.isUndefined(music_id) || utils.isUndefined(music_url)  ) return;
 search_list = read_music_file(music_id);
 fs.write(music_url, '', 'w');
});
casper.eachThen(read_music_file(music_id), function(item){
        var artist = item.data[0];
        var title = item.data[1];
        var song_id = item.data[2];
        console.log("ask url : " + artist + ',' + title + ',' + song_id);
        var url = 'http://musicmini.baidu.com/app/link/getLinks.php?linkType=1&isLogin=1&clientVer=8.2.10.23&isHq=1&songAppend=&isCloud=0&hasMV=1&songId=' +
        song_id +    '&songTitle=' + title + '&songArtist=' + artist;
       
        if(song_id){
            this.thenOpen(url, function(){
                var song_info = eval(this.getHTML('body'));
                var u = song_info[0]["file_list"][0];
                var w_str = [ artist, title , u["kbps"], u["format"], u["url"]].join(" ") + "\n";
                console.log(w_str);
                fs.write(music_url, w_str, 'a'); 
            });
        }
    });
    
// }}}

// write dst file {{{
casper.then(function(){
 if( utils.isUndefined(music_url) ) return;
 write_music_file(music_url, music_wget, music_wget_callback);
 write_music_file(music_url, music_playlist, music_playlist_callback);
});
// }}}

casper.run();
function music_playlist_callback(){
    return {
        head : 'head', 
        tail : 'tail', 
        item : function(m){
            [ 'wget' , '-c', '"' + m[4] + '"', 
                '-O', '"' + m[0]+'-'+m[1]+'.'+m[3] + '"' ].join(' ');
        }
    }
}

function music_wget_callback(){
    return function(m){ 
    [ 'wget' , '-c', '"' + m[4] + '"', 
        '-O', '"' + m[0]+'-'+m[1]+'.'+m[3] + '"' ].join(' ');
    }
}

function write_music_file(music_url, dst_file, cb){
    if( utils.isUndefined(dst_file) ) return;
    var callback = cb();
    var src = read_music_file(music_url);
    var dst = new Array();
    var map_cb = callback.item || callback;
    for(var i in src){
        var s = map_cb(src[i]);
        dst.push(s);
    }
    fs.write(dst_file, (callback.head || '') 
             + dst.join("\n") + 
                (callback.tail || ''), 'w');
}

function read_music_file(f) {
    var music_data = fs.read(f).match(/[^\r\n]+/g);
    var res = new Array();
    for(var m in music_data){
        var info = music_data[m].split(/\s+/g);
        if(!info) continue;
        res.push(info);
    }
    return res;
}
