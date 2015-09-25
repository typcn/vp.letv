
window.sendToPlugin = function(data){
    var request = new XMLHttpRequest();
    request.open('POST', 'http://localhost:23330/pluginCall', true);
    request.setRequestHeader('Content-Type', 'application/json');
    request.send(JSON.stringify(data));
}

window.setMsg = function(text){
    document.getElementById("player").innerHTML = '<div class="player_html5"><div class="picture" style="height:100%"><div style="line-height:460px;"><span style="font-size:18px">' + text + '</span></div></div></div>';
}
setTimeout(function(){
    var str = window.location.href;
    var re = /v_show\/id_(.*)\.html/;
    var m = str.match(re);
    if(m && m.length == 2){
        window.ykvid = m[1];
        setMsg('<a href="javascript:getVideoAddr()">立即播放</a>');
    }
},500);

window.getVideoAddr = function(){
    setMsg('<a href="#">正在解析视频地址</a>');
    youkuParser(ykvid,function(d){
        if(!d || d.length < 1){
            setMsg('<a href="#">解析失败，返回内容为空</a>');
        }else{
            var str = "请选择画质: ";
            window.videoAddr = d;
            for(var i =0;i < d.length;i++){
                str +='<a href="javascript:invokePlayer('+i+')">' + d[i][0] + '</a> ';
            }
            setMsg(str);
        }
    });
}

window.invokePlayer = function(i){
    var vaddr = window.videoAddr[i][1];
    sendToPlugin({ action:'youku-playvideo', data:vaddr });
}

window.log = console.log;