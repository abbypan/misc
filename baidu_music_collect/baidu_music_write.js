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

var callback_info = {
    xspf : music_xspf_callback, 
    wget : music_wget_callback 
};

casper.start('http://music.baidu.com');

// cli {{{
var music_url = casper.cli.get(0);
var music_dst = casper.cli.get(1);
var dst_file_type = casper.cli.get(2) || 'xspf';
// }}}


 //if( utils.isUndefined(music_url) ) return;

// write dst file {{{
casper.then(function(){
 if( utils.isUndefined(music_url) ) return;
  write_music_file(music_url, music_dst, callback_info[dst_file_type]);
});
// }}}

casper.run();

function music_xspf_callback(){
    return {
        head : '<?xml version="1.0" encoding="UTF-8"?>' +
'<playlist version="1" xmlns="http://xspf.org/ns/0/">' + 
    '<trackList>', 
        tail : '</trackList></playlist>', 
        item : function(m){
            return [ "<track>", 
                "<location>" + m[4]  + "</location>", 
                "<title>" + m[1]  + "</title>", 
                "<creator>" + m[0]  + "</creator>", 
                "</track>"].join("\n");        
        }
    }
}

function music_wget_callback(){
    return function(m){ 
    return [ 'wget' , '-c', '"' + m[4] + '"', 
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
    var dst_str = (callback.head || '') + "\n" + dst.join("\n") + "\n" + (callback.tail || '') ;
    fs.write(dst_file, dst_str, 'w');
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
