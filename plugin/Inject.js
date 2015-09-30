window.sendToPlugin = function(data){
    var request = new XMLHttpRequest();
    request.open('POST', 'http://localhost:23330/pluginCall', true);
    request.setRequestHeader('Content-Type', 'application/json');
    request.send(JSON.stringify(data));
}

window.setMsg = function(){
    $("#fla_box_con").html('<div id="fla_box_p"> <div id="fla_box" style="width: 1121px; height: 474px; background: rgb(0, 0, 0);"><div style="width:1121px;height:474px;margin:auto; background:#000;overflow:hidden;"><div style="text-align:center; color:#aaa; line-height:20px; font-size:24px; padding-top:120px"><br><br><br><a href="javascript:showPlayWindow()" style="color:#fff">立即播放</a></div></div></div><a class="player_bg" href="javascript:;" style="display: none;"><img src="http://i0.letvimg.com/lc02_img/201505/28/15/45/ico_bg.png"></a><a class="ico_close" href="javascript:;" style="display: none;"></a></div>');
}


window.showPlayWindow = function(){
    sendToPlugin({ action:'letv-playvideo', data:window.levid });
}

if(!window.ins){
    window.ins = setInterval(function(){
        var str = window.location.href;
        var re = /\/(\d+).html/;
        var m = str.match(re);
        if(m && m.length == 2){
            window.levid = m[1];
            setMsg();
            try{
                $('.juji_grid ul li a').unbind("click");
                $('.juji_grid ul li a').click(function(e){
                    window.location.href = window.location.href.replace(levid, e.delegateTarget.dataset.vid);
                });
            }catch(e){

            }
        }
        if(!window.loadTimes){
            window.loadTimes = 1;
        }else if(window.loadTime > 15){
            clearInterval(ins);
        }else{
            window.loadTimes++;
        }
    },500);
}