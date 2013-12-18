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
var music_id = casper.cli.get(0) ;
var music_url = casper.cli.get(1);

// 音质 0 - 3， 0 最好
var music_level =  casper.cli.get(2) || 0;
// }}}

 //if( utils.isUndefined(music_id) || utils.isUndefined(music_url)  ) return;
 search_list = read_music_file(music_id);
 fs.write(music_url, '', 'w');

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
                var u = song_info[0]["file_list"][music_level];
                var w_str = [ artist, title , u["kbps"], u["format"], u["url"]].join(" ") + "\n";
                console.log(w_str);
                fs.write(music_url, w_str, 'a'); 
            });
        }
    });
    

casper.run();

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