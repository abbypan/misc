//abstract: collect song on baidu music site
//usage: casperjs baidu_music_collect.js cookie_file music_file

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

var cookie_file = casper.cli.get(0);
var data = fs.read(cookie_file);
phantom.cookies = JSON.parse(data);

var music_file = casper.cli.get(1);
var music_list = read_music_file(music_file);

casper.start('http://music.baidu.com');
casper.each(music_list, function(self, item){
    search_song(item[0],item[1], collect_song);
});
casper.run();


function read_music_file(f) {
//line : title artist
    var music_data = fs.read(f).match(/[^\r\n]+/g);
    var res = new Array();
    for(var m in music_data){
        var info = music_data[m].match(/^(.+?)\s+(.+)$/) 
            || music_data[m].match(/^\s*(\S.*)$/);
        if(!info) continue;
        info.shift();
        res.push(info);
    }
    return res;
}

function search_song (title, artist , callback){
    var key = title;
    if(artist) key +=" "+artist;
    //console.log('search song : ' + key + "\n");

    var music_url = 'http://music.baidu.com';
    casper.thenOpen(music_url);
    casper.wait(1000, function(){
        this.fill('form[action="/search"]', { key : key }, true);
    });

    casper.wait(1000, function(){
        var song_x = artist ? '//a/em[text()="' + artist + '"]//ancestor::div[@class="song-item clearfix"]' : '';
        song_x +="//span[@class='song-title']//a[@title='" + title + "']";
        var collect_x = x(song_x);
        if (this.exists(collect_x)) {
            var id = this.getElementAttribute(collect_x,'href');
            var song_id = id.replace(/#.*/, '').replace(/^.*\//, '');
            console.log('find song '+ key + ' id ' + song_id);
            if(callback) callback(song_id);
        }
    });
}

function collect_song(song_id) {

    casper.then(function(){
        if(!song_id) return;
        var collect_url = 'http://music.baidu.com/song/' + song_id;

        this.thenOpen(collect_url, function(){
            console.log("visit url : " + collect_url);

            var collect_x  = x('//span[text()="收藏"]/parent::span/parent::a');
            if (this.exists(collect_x)) {
                console.log("click collect button : "+song_id);
                this.click(collect_x);
            }

            this.wait(1000, function() {
                var artist = this.getElementAttribute('span[class="author_list"]', 'title')
                var title = this.fetchText('span[class="name"]');
            status = this.fetchText('div[class="song-page-share clearfix"] span span');
            status = status.replace('分享','');
            console.log("song "+ artist + "《 " + title +" 》 : " + status+"\n");
            });
        });
    });
}
